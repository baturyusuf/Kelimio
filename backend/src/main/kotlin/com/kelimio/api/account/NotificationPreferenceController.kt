package com.kelimio.api.account

import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.CorrelationIdProvider
import jakarta.validation.Valid
import org.jooq.DSLContext
import org.jooq.JSONB
import org.springframework.http.CacheControl
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.stereotype.Repository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.time.Clock
import java.time.LocalTime
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@RestController
@RequestMapping("/v1/me/notification-preferences")
internal class NotificationPreferenceController(
    private val currentUserService: CurrentUserService,
    private val service: NotificationPreferenceService,
) {
    @GetMapping
    fun get(@AuthenticationPrincipal jwt: Jwt): ResponseEntity<NotificationPreferenceResponse> =
        noStore(service.get(currentUserService.requireCompleted(jwt)))

    @PutMapping
    fun update(
        @AuthenticationPrincipal jwt: Jwt,
        @Valid @RequestBody request: UpdateNotificationPreferenceRequest,
    ): ResponseEntity<NotificationPreferenceResponse> =
        noStore(service.update(currentUserService.requireCompleted(jwt), request))

    private fun <T> noStore(body: T): ResponseEntity<T> = ResponseEntity.ok()
        .cacheControl(CacheControl.noStore())
        .body(body)
}

internal data class UpdateNotificationPreferenceRequest(
    val expectedVersion: Long,
    val learningReminders: Boolean,
    val courseUpdates: Boolean,
    val productAnnouncements: Boolean,
    val pushEnabled: Boolean,
    val emailEnabled: Boolean,
    val quietHoursStart: LocalTime?,
    val quietHoursEnd: LocalTime?,
)

internal data class NotificationPreferenceResponse(
    val learningReminders: Boolean,
    val courseUpdates: Boolean,
    val productAnnouncements: Boolean,
    val pushEnabled: Boolean,
    val emailEnabled: Boolean,
    val pushAvailable: Boolean,
    val emailAvailable: Boolean,
    val quietHoursStart: LocalTime?,
    val quietHoursEnd: LocalTime?,
    val version: Long,
    val updatedAt: OffsetDateTime?,
)

@Service
internal class NotificationPreferenceService(
    private val repository: NotificationPreferenceRepository,
    private val outbox: TransactionalOutbox,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
) {
    @Transactional(readOnly = true)
    fun get(user: AppUser): NotificationPreferenceResponse = repository.get(user.id)

    @Transactional
    fun update(user: AppUser, request: UpdateNotificationPreferenceRequest): NotificationPreferenceResponse {
        if ((request.quietHoursStart == null) != (request.quietHoursEnd == null)) {
            throw ConflictProblem("Quiet hours require both start and end times.")
        }
        if (request.pushEnabled && !repository.pushAvailable()) {
            throw ConflictProblem("Push notifications require provider configuration.")
        }
        if (request.emailEnabled && !repository.emailAvailable()) {
            throw ConflictProblem("Email notifications require a verified production sender.")
        }
        repository.lockUser(user.id)
        val previous = repository.get(user.id)
        if (previous.version != request.expectedVersion) {
            throw ConflictProblem("Notification preferences changed on another device.")
        }
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val version = previous.version + 1
        val changed = repository.save(user.id, request, version, now)
        if (changed.isEmpty()) return previous
        val correlationId = correlationIdProvider.current()
        repository.appendEvent(user.id, version, changed, correlationId, now)
        val eventId = UUID.randomUUID()
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "notification-preference",
                aggregateId = user.id,
                eventType = "notification.preference-updated.v1",
                schemaVersion = 1,
                payload = mapOf("eventId" to eventId, "userId" to user.id, "version" to version, "changedFields" to changed),
                correlationId = correlationId,
                occurredAt = now,
            ),
        )
        return repository.get(user.id)
    }
}

@Repository
internal class NotificationPreferenceRepository(
    private val dsl: DSLContext,
    @org.springframework.beans.factory.annotation.Value("\${KELIMIO_PUSH_ENABLED:false}")
    private val configuredPush: Boolean,
    @org.springframework.beans.factory.annotation.Value("\${KELIMIO_EMAIL_ENABLED:false}")
    private val configuredEmail: Boolean,
) {
    fun pushAvailable() = configuredPush
    fun emailAvailable() = configuredEmail

    fun lockUser(userId: UUID) {
        checkNotNull(dsl.fetchOne("select id from app_user where id = ? for update", userId))
    }

    fun get(userId: UUID): NotificationPreferenceResponse = dsl.fetchOne(
        """
        select learning_reminders, course_updates, product_announcements, push_enabled, email_enabled,
               quiet_hours_start, quiet_hours_end, version, updated_at
          from notification_preference where user_id = ?
        """.trimIndent(),
        userId,
    )?.let {
        NotificationPreferenceResponse(
            learningReminders = it.get("learning_reminders", Boolean::class.java)!!,
            courseUpdates = it.get("course_updates", Boolean::class.java)!!,
            productAnnouncements = it.get("product_announcements", Boolean::class.java)!!,
            pushEnabled = it.get("push_enabled", Boolean::class.java)!!,
            emailEnabled = it.get("email_enabled", Boolean::class.java)!!,
            pushAvailable = configuredPush,
            emailAvailable = configuredEmail,
            quietHoursStart = it.get("quiet_hours_start", LocalTime::class.java),
            quietHoursEnd = it.get("quiet_hours_end", LocalTime::class.java),
            version = it.get("version", Long::class.java)!!,
            updatedAt = it.get("updated_at", OffsetDateTime::class.java),
        )
    } ?: NotificationPreferenceResponse(true, true, false, false, false, configuredPush, configuredEmail, null, null, 0, null)

    fun save(userId: UUID, request: UpdateNotificationPreferenceRequest, version: Long, now: OffsetDateTime): List<String> {
        val previous = get(userId)
        val changed = buildList {
            if (previous.learningReminders != request.learningReminders) add("learningReminders")
            if (previous.courseUpdates != request.courseUpdates) add("courseUpdates")
            if (previous.productAnnouncements != request.productAnnouncements) add("productAnnouncements")
            if (previous.pushEnabled != request.pushEnabled) add("pushEnabled")
            if (previous.emailEnabled != request.emailEnabled) add("emailEnabled")
            if (previous.quietHoursStart != request.quietHoursStart || previous.quietHoursEnd != request.quietHoursEnd) add("quietHours")
        }
        if (changed.isEmpty()) return emptyList()
        dsl.execute(
            """
            insert into notification_preference(user_id, learning_reminders, course_updates, product_announcements,
                push_enabled, email_enabled, quiet_hours_start, quiet_hours_end, version, updated_at)
            values (?, ?, ?, ?, ?, ?, ?, ?, ?, cast(? as timestamptz))
            on conflict (user_id) do update set learning_reminders=excluded.learning_reminders,
                course_updates=excluded.course_updates, product_announcements=excluded.product_announcements,
                push_enabled=excluded.push_enabled, email_enabled=excluded.email_enabled,
                quiet_hours_start=excluded.quiet_hours_start, quiet_hours_end=excluded.quiet_hours_end,
                version=excluded.version, updated_at=excluded.updated_at
            """.trimIndent(), userId, request.learningReminders, request.courseUpdates, request.productAnnouncements,
            request.pushEnabled, request.emailEnabled, request.quietHoursStart, request.quietHoursEnd, version, now,
        )
        return changed
    }

    fun appendEvent(userId: UUID, version: Long, fields: List<String>, correlationId: String, now: OffsetDateTime) {
        dsl.execute(
            "insert into notification_preference_event(id, user_id, version, changed_fields, correlation_id, occurred_at) values (?, ?, ?, ?, ?, cast(? as timestamptz))",
            UUID.randomUUID(), userId, version, JSONB.valueOf(fields.joinToString(prefix = "[\"", postfix = "\"]", separator = "\",\"")), correlationId, now,
        )
    }
}
