package com.kelimio.api.account

import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.web.CorrelationIdProvider
import org.jooq.DSLContext
import org.springframework.beans.factory.ObjectProvider
import org.springframework.http.CacheControl
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.stereotype.Repository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@RestController
@RequestMapping("/v1/me")
internal class AccountLifecycleController(
    private val currentUserService: CurrentUserService,
    private val service: AccountLifecycleService,
) {
    @GetMapping("/export")
    fun export(@AuthenticationPrincipal jwt: Jwt): ResponseEntity<AccountExportResponse> =
        ResponseEntity.ok().cacheControl(CacheControl.noStore())
            .body(service.export(currentUserService.requireCompleted(jwt)))

    @PostMapping("/deletion-requests")
    fun requestDeletion(
        @AuthenticationPrincipal jwt: Jwt,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
    ): ResponseEntity<AccountDeletionResponse> {
        val response = service.requestDeletion(currentUserService.requireCompleted(jwt), jwt, idempotencyKey)
        return ResponseEntity.status(if (response.created) HttpStatus.CREATED else HttpStatus.OK)
            .cacheControl(CacheControl.noStore()).body(response)
    }

    @GetMapping("/deletion-requests")
    fun deletionRequests(
        @AuthenticationPrincipal jwt: Jwt,
    ): ResponseEntity<List<AccountDeletionResponse>> =
        ResponseEntity.ok().cacheControl(CacheControl.noStore())
            .body(service.deletionRequests(currentUserService.requireCompleted(jwt)))

    @PostMapping("/deletion-requests/{requestId}/cancel")
    fun cancelDeletion(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable requestId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
    ): ResponseEntity<AccountDeletionResponse> {
        val response = service.cancelDeletion(
            currentUserService.requireCompleted(jwt),
            requestId,
            idempotencyKey,
        )
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(response)
    }

    @GetMapping("/legal-consents")
    fun consents(@AuthenticationPrincipal jwt: Jwt): ResponseEntity<List<LegalConsentResponse>> =
        ResponseEntity.ok().cacheControl(CacheControl.noStore())
            .body(service.consents(currentUserService.requireCompleted(jwt)))
}

internal data class AccountExportResponse(
    val generatedAt: OffsetDateTime,
    val profile: AccountExportProfile,
    val enrollments: List<Map<String, Any?>>,
    val completedAttempts: List<Map<String, Any?>>,
    val scoreEvents: List<Map<String, Any?>>,
    val legalConsents: List<LegalConsentResponse>,
)

internal data class AccountExportProfile(
    val id: UUID,
    val email: String?,
    val displayName: String,
    val username: String?,
    val appLocale: String,
    val activeTargetLanguage: String,
    val preferredSupportLanguage: String?,
    val timeZone: String,
)

internal data class AccountDeletionResponse(
    val id: UUID,
    val status: String,
    val requestedAt: OffsetDateTime,
    val scheduledFor: OffsetDateTime,
    val created: Boolean,
)

internal data class LegalConsentResponse(
    val documentId: String,
    val documentVersion: String,
    val action: String,
    val occurredAt: OffsetDateTime,
)

@Service
internal class AccountLifecycleService(
    private val repository: AccountLifecycleRepository,
    private val idempotencyService: IdempotencyService,
    private val outbox: TransactionalOutbox,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
    private val cognitoSessionService: ObjectProvider<CognitoSessionService>,
) {
    @Transactional(readOnly = true)
    fun export(user: AppUser): AccountExportResponse = repository.export(user, clock)

    @Transactional(readOnly = true)
    fun consents(user: AppUser): List<LegalConsentResponse> = repository.consents(user.id)

    @Transactional(readOnly = true)
    fun deletionRequests(user: AppUser): List<AccountDeletionResponse> =
        repository.deletions(user.id)

    @Transactional
    fun requestDeletion(user: AppUser, jwt: Jwt, idempotencyKey: UUID): AccountDeletionResponse {
        val lookup = idempotencyService.lockAndFind(user.id, "account.request-deletion", idempotencyKey, "request")
        lookup.resourceId?.let { return repository.deletion(it, created = false) }
        repository.existingDeletion(user.id)?.let { existing ->
            idempotencyService.record(user.id, "account.request-deletion", idempotencyKey, lookup.fingerprint, existing.id)
            return existing.copy(created = false)
        }
        val sessions = cognitoSessionService.ifAvailable
            ?: throw com.kelimio.api.web.ServiceUnavailableProblem(
                "Account deletion is unavailable until managed session revocation is configured.",
            )
        sessions.revokeAll(user.id, jwt)
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val response = repository.createDeletion(user.id, now, now.plusDays(7), correlationIdProvider.current())
        val eventId = UUID.randomUUID()
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "account",
                aggregateId = user.id,
                eventType = "account.deletion-requested.v1",
                schemaVersion = 1,
                payload = mapOf("eventId" to eventId, "userId" to user.id, "requestId" to response.id, "scheduledFor" to response.scheduledFor),
                correlationId = correlationIdProvider.current(),
                occurredAt = now,
            ),
        )
        idempotencyService.record(user.id, "account.request-deletion", idempotencyKey, lookup.fingerprint, response.id)
        return response
    }

    @Transactional
    fun cancelDeletion(user: AppUser, requestId: UUID, idempotencyKey: UUID): AccountDeletionResponse {
        val operation = "account.cancel-deletion"
        val lookup = idempotencyService.lockAndFind(user.id, operation, idempotencyKey, requestId.toString())
        lookup.resourceId?.let { return repository.deletion(it, created = false) }
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val response = repository.cancelDeletion(user.id, requestId, now)
        val eventId = UUID.randomUUID()
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "account",
                aggregateId = user.id,
                eventType = "account.deletion-cancelled.v1",
                schemaVersion = 1,
                payload = mapOf(
                    "eventId" to eventId,
                    "userId" to user.id,
                    "requestId" to requestId,
                    "cancelledAt" to now,
                ),
                correlationId = correlationIdProvider.current(),
                occurredAt = now,
            ),
        )
        idempotencyService.record(user.id, operation, idempotencyKey, lookup.fingerprint, response.id)
        return response
    }
}

@Repository
internal class AccountLifecycleRepository(private val dsl: DSLContext) {
    fun export(user: AppUser, clock: Clock) = AccountExportResponse(
        generatedAt = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC),
        profile = AccountExportProfile(user.id, user.email, user.displayName, user.username, user.appLocale, user.activeTargetLanguage, user.preferredSupportLanguage, user.timeZone),
        enrollments = rows("select course_id, support_language, status, enrolled_at from enrollment where user_id = ? order by enrolled_at", user.id),
        completedAttempts = rows("select id, course_id, test_revision_id, status, answered_count, correct_count, total_questions, started_at, finished_at from test_attempt where user_id = ? and status in ('COMPLETED_PASS','COMPLETED_FAIL') order by finished_at", user.id),
        scoreEvents = rows("select id, attempt_id, active_delta, lifetime_delta, occurred_at from score_event where user_id = ? order by occurred_at", user.id),
        legalConsents = consents(user.id),
    )

    private fun rows(sql: String, userId: UUID): List<Map<String, Any?>> = dsl.fetch(sql, userId).map { record ->
        record.fields().associate { field -> field.name to record.get(field) }
    }

    fun consents(userId: UUID): List<LegalConsentResponse> = dsl.fetch(
        "select document_id, document_version, action, occurred_at from legal_consent_fact where user_id = ? order by occurred_at",
        userId,
    ).map { LegalConsentResponse(it.get("document_id", String::class.java)!!, it.get("document_version", String::class.java)!!, it.get("action", String::class.java)!!, it.get("occurred_at", OffsetDateTime::class.java)!!) }

    fun existingDeletion(userId: UUID): AccountDeletionResponse? = dsl.fetchOne(
        "select id, status, requested_at, scheduled_for from account_deletion_request where user_id = ? and status = 'PENDING'",
        userId,
    )?.toDeletion(false)

    fun deletions(userId: UUID): List<AccountDeletionResponse> = dsl.fetch(
        "select id, status, requested_at, scheduled_for from account_deletion_request where user_id = ? order by requested_at desc limit 20",
        userId,
    ).map { it.toDeletion(false) }

    fun deletion(id: UUID, created: Boolean): AccountDeletionResponse = checkNotNull(
        dsl.fetchOne("select id, status, requested_at, scheduled_for from account_deletion_request where id = ?", id),
    ).toDeletion(created)

    fun createDeletion(userId: UUID, requestedAt: OffsetDateTime, scheduledFor: OffsetDateTime, correlationId: String): AccountDeletionResponse {
        val id = UUID.randomUUID()
        dsl.execute(
            "insert into account_deletion_request(id, user_id, status, requested_at, scheduled_for, correlation_id) values (?, ?, 'PENDING', cast(? as timestamptz), cast(? as timestamptz), ?)",
            id, userId, requestedAt, scheduledFor, correlationId,
        )
        return AccountDeletionResponse(id, "PENDING", requestedAt, scheduledFor, true)
    }

    fun cancelDeletion(userId: UUID, requestId: UUID, cancelledAt: OffsetDateTime): AccountDeletionResponse {
        val updated = dsl.execute(
            "update account_deletion_request set status = 'CANCELLED', cancelled_at = cast(? as timestamptz) where id = ? and user_id = ? and status = 'PENDING' and scheduled_for > cast(? as timestamptz)",
            cancelledAt,
            requestId,
            userId,
            cancelledAt,
        )
        if (updated != 1) {
            throw com.kelimio.api.web.ConflictProblem(
                "Only a pending deletion request inside its recovery window can be cancelled.",
            )
        }
        return deletion(requestId, created = false)
    }

    private fun org.jooq.Record.toDeletion(created: Boolean) = AccountDeletionResponse(
        id = get("id", UUID::class.java)!!,
        status = get("status", String::class.java)!!,
        requestedAt = get("requested_at", OffsetDateTime::class.java)!!,
        scheduledFor = get("scheduled_for", OffsetDateTime::class.java)!!,
        created = created,
    )
}
