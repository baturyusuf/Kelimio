package com.kelimio.api.catalog

import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.language.InvalidLanguageTagException
import com.kelimio.api.language.LanguageTagNormalizer
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.teacher.TeacherAccessService
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.ForbiddenProblem
import com.kelimio.api.web.NotFoundProblem
import com.kelimio.api.web.UnprocessableProblem
import jakarta.validation.Valid
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import org.jooq.DSLContext
import org.springframework.http.CacheControl
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.stereotype.Repository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Base64
import java.util.HexFormat
import java.util.UUID

@RestController
@RequestMapping("/v1")
internal class CourseInvitationController(
    private val currentUserService: CurrentUserService,
    private val service: CourseInvitationService,
) {
    @PostMapping("/teacher/courses/{courseId}/invitations")
    fun create(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
        @Valid @RequestBody request: CreateCourseInvitationRequest,
    ): ResponseEntity<CourseInvitationCreatedResponse> = ResponseEntity.status(HttpStatus.CREATED)
        .cacheControl(CacheControl.noStore())
        .body(service.create(jwt, currentUserService.requireCompleted(jwt), courseId, request))

    @PostMapping("/course-invitations/{token}/accept")
    fun accept(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable token: String,
        @Valid @RequestBody request: AcceptCourseInvitationRequest,
    ): ResponseEntity<CourseInvitationAcceptedResponse> = ResponseEntity.ok()
        .cacheControl(CacheControl.noStore())
        .body(service.accept(currentUserService.requireCompleted(jwt), token, request))
}

internal data class CreateCourseInvitationRequest(
    @field:Min(1) @field:Max(100) val maxUses: Int = 1,
    @field:Min(1) @field:Max(720) val expiresInHours: Int = 168,
)

internal data class CourseInvitationCreatedResponse(
    val id: UUID,
    val courseId: UUID,
    val token: String,
    val maxUses: Int,
    val expiresAt: OffsetDateTime,
)

internal data class AcceptCourseInvitationRequest(val supportLanguage: String)

internal data class CourseInvitationAcceptedResponse(
    val courseId: UUID,
    val enrollmentId: UUID,
    val supportLanguage: String,
    val acceptedAt: OffsetDateTime,
)

@Service
internal class CourseInvitationService(
    private val repository: CourseInvitationRepository,
    private val teacherAccessService: TeacherAccessService,
    private val languageTagNormalizer: LanguageTagNormalizer,
    private val outbox: TransactionalOutbox,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
) {
    @Transactional
    fun create(jwt: Jwt, user: AppUser, courseId: UUID, request: CreateCourseInvitationRequest): CourseInvitationCreatedResponse {
        teacherAccessService.requireAuthorized(jwt, user)
        val course = repository.lockOwnedCourse(courseId, user.id) ?: throw NotFoundProblem("Course was not found.")
        if (course.visibility != "PRIVATE") throw ConflictProblem("Invitations are only required for private courses.")
        if (course.accessType != "FREE") throw ConflictProblem("Paid course access requires a verified store entitlement.")
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val token = newToken()
        val response = repository.create(courseId, user.id, hash(token), request.maxUses, now, now.plusHours(request.expiresInHours.toLong()))
        return response.copy(token = token)
    }

    @Transactional
    fun accept(user: AppUser, token: String, request: AcceptCourseInvitationRequest): CourseInvitationAcceptedResponse {
        if (!TOKEN_PATTERN.matches(token)) throw NotFoundProblem("Invitation was not found.")
        val language = try { languageTagNormalizer.normalize(request.supportLanguage) } catch (_: InvalidLanguageTagException) {
            throw UnprocessableProblem("supportLanguage is not a supported BCP 47 language tag.")
        }
        val invitation = repository.lock(hash(token)) ?: throw NotFoundProblem("Invitation was not found.")
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        if (invitation.revokedAt != null || invitation.expiresAt <= now) throw ConflictProblem("Invitation expired or was revoked.")
        if (!repository.supportsLanguage(invitation.courseId, language)) throw UnprocessableProblem("The course does not support this language.")
        repository.existingAcceptance(invitation.id, user.id)?.let { return it }
        if (invitation.usedCount >= invitation.maxUses) throw ConflictProblem("Invitation has no remaining uses.")
        val enrollment = repository.enroll(invitation.courseId, user.id, language, now)
        val correlationId = correlationIdProvider.current()
        val response = repository.accept(invitation.id, user.id, enrollment.id, invitation.courseId, language, now, correlationId)
        val eventId = UUID.randomUUID()
        outbox.appendRecorded(RecordedOutboxEvent(eventId, "course-invitation", invitation.id, "course.invitation-accepted.v1", 1, mapOf("eventId" to eventId, "invitationId" to invitation.id, "courseId" to invitation.courseId, "userId" to user.id, "enrollmentId" to enrollment.id), correlationId, now))
        return response
    }

    private fun newToken(): String = ByteArray(32).also(SecureRandom()::nextBytes).let { Base64.getUrlEncoder().withoutPadding().encodeToString(it) }
    private fun hash(token: String): String = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.toByteArray(Charsets.UTF_8)))
    private companion object { val TOKEN_PATTERN = Regex("^[A-Za-z0-9_-]{43}$") }
}

internal data class InvitationCourse(val visibility: String, val accessType: String)
internal data class InvitationRecord(val id: UUID, val courseId: UUID, val maxUses: Int, val usedCount: Int, val expiresAt: OffsetDateTime, val revokedAt: OffsetDateTime?)
internal data class InvitationEnrollment(val id: UUID)

@Repository
internal class CourseInvitationRepository(private val dsl: DSLContext) {
    fun lockOwnedCourse(courseId: UUID, ownerId: UUID): InvitationCourse? = dsl.fetchOne("select visibility, access_type from course where id = ? and owner_user_id = ? and publication_status in ('PUBLISHED','HIDDEN') for update", courseId, ownerId)?.let { InvitationCourse(it.get("visibility", String::class.java)!!, it.get("access_type", String::class.java)!!) }
    fun create(courseId: UUID, ownerId: UUID, tokenHash: String, maxUses: Int, now: OffsetDateTime, expiresAt: OffsetDateTime): CourseInvitationCreatedResponse {
        val id = UUID.randomUUID()
        dsl.execute("insert into course_invitation(id, course_id, created_by_user_id, token_sha256, max_uses, expires_at, created_at) values (?, ?, ?, ?, ?, cast(? as timestamptz), cast(? as timestamptz))", id, courseId, ownerId, tokenHash, maxUses, expiresAt, now)
        return CourseInvitationCreatedResponse(id, courseId, "", maxUses, expiresAt)
    }
    fun lock(tokenHash: String): InvitationRecord? = dsl.fetchOne("select id, course_id, max_uses, used_count, expires_at, revoked_at from course_invitation where token_sha256 = ? for update", tokenHash)?.let { InvitationRecord(it.get("id", UUID::class.java)!!, it.get("course_id", UUID::class.java)!!, it.get("max_uses", Int::class.java)!!, it.get("used_count", Int::class.java)!!, it.get("expires_at", OffsetDateTime::class.java)!!, it.get("revoked_at", OffsetDateTime::class.java)) }
    fun supportsLanguage(courseId: UUID, language: String): Boolean =
        dsl.fetchOne(
            "select exists(select 1 from course_support_language where course_id = ? and language_code = ?) as found",
            courseId,
            language,
        )?.get("found", Boolean::class.java) == true
    fun existingAcceptance(invitationId: UUID, userId: UUID): CourseInvitationAcceptedResponse? = dsl.fetchOne("select acceptance.enrollment_id, invitation.course_id, enrollment.support_language, acceptance.accepted_at from course_invitation_acceptance acceptance join course_invitation invitation on invitation.id = acceptance.invitation_id join enrollment on enrollment.id = acceptance.enrollment_id where acceptance.invitation_id = ? and acceptance.user_id = ?", invitationId, userId)?.let { CourseInvitationAcceptedResponse(it.get("course_id", UUID::class.java)!!, it.get("enrollment_id", UUID::class.java)!!, it.get("support_language", String::class.java)!!, it.get("accepted_at", OffsetDateTime::class.java)!!) }
    fun enroll(courseId: UUID, userId: UUID, language: String, now: OffsetDateTime): InvitationEnrollment {
        val id = UUID.randomUUID()
        dsl.execute("insert into enrollment(id, course_id, user_id, support_language, status, enrolled_at) values (?, ?, ?, ?, 'ACTIVE', cast(? as timestamptz)) on conflict (course_id, user_id) do update set support_language = excluded.support_language, status = 'ACTIVE'", id, courseId, userId, language, now)
        val actual = dsl.fetchOne("select id from enrollment where course_id = ? and user_id = ?", courseId, userId)!!.get("id", UUID::class.java)!!
        return InvitationEnrollment(actual)
    }
    fun accept(invitationId: UUID, userId: UUID, enrollmentId: UUID, courseId: UUID, language: String, now: OffsetDateTime, correlationId: String): CourseInvitationAcceptedResponse {
        dsl.execute("insert into course_invitation_acceptance(invitation_id, user_id, enrollment_id, accepted_at, correlation_id) values (?, ?, ?, cast(? as timestamptz), ?)", invitationId, userId, enrollmentId, now, correlationId)
        check(dsl.execute("update course_invitation set used_count = used_count + 1 where id = ? and used_count < max_uses", invitationId) == 1)
        return CourseInvitationAcceptedResponse(courseId, enrollmentId, language, now)
    }
}
