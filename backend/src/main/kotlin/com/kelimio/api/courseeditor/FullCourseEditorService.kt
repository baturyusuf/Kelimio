package com.kelimio.api.courseeditor

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.teacher.TeacherAccessService
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.NotFoundProblem
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.HexFormat
import java.util.UUID

@Service
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
internal class FullCourseEditorService(
    private val repository: FullCourseEditorRepository,
    private val teacherAccessService: TeacherAccessService,
    private val idempotencyService: IdempotencyService,
    private val outbox: TransactionalOutbox,
    private val objectMapper: ObjectMapper,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
) {
    @Transactional(readOnly = true)
    fun document(jwt: Jwt, user: AppUser, courseId: UUID): FullCourseEditorSnapshot {
        teacherAccessService.requireAuthorized(jwt, user)
        val course = course(courseId, user.id)
        return snapshot(course)
    }

    @Transactional
    fun createDraft(
        jwt: Jwt,
        user: AppUser,
        courseId: UUID,
        idempotencyKey: UUID,
        ifMatch: String,
        request: SaveFullCourseEditorDraftRequest,
    ): FullCourseEditorDraftResponse {
        teacherAccessService.requireAuthorized(jwt, user)
        val unlocked = course(courseId, user.id)
        val current = repository.document(unlocked)
        val normalized = FullCourseEditorValidator.normalizeAndValidate(request, unlocked, current)
        val canonicalJson = objectMapper.writeValueAsString(normalized)
        val lookup = idempotencyService.lockAndFind(
            user.id,
            OPERATION,
            idempotencyKey,
            "$courseId|$ifMatch|$canonicalJson",
        )
        lookup.resourceId?.let { releaseId ->
            return repository.result(releaseId, user.id, created = false)
                ?: throw ConflictProblem("The idempotent course draft no longer exists.")
        }

        if (!repository.lockCourse(courseId, user.id)) throw NotFoundProblem("Course was not found.")
        val locked = course(courseId, user.id)
        if (locked.publicationStatus !in setOf("PUBLISHED", "HIDDEN")) {
            throw ConflictProblem("Only a published or hidden course can be edited.")
        }
        if (locked.activeReleaseId != normalized.baseReleaseId) {
            throw ConflictProblem("The active release changed before the draft was saved.")
        }
        val lockedSnapshot = snapshot(locked)
        if (ifMatch != lockedSnapshot.entityTag) {
            throw ConflictProblem("The course editor version changed before the draft was saved.")
        }
        if (repository.hasOpenDraft(courseId)) {
            throw ConflictProblem("Publish or abandon the existing draft before creating another draft.")
        }
        FullCourseEditorValidator.normalizeAndValidate(normalized, locked, lockedSnapshot.document)

        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val correlationId = correlationIdProvider.current()
        val eventId = UUID.randomUUID()
        val command = FullCourseEditorCommitCommand(
            commandId = idempotencyKey,
            ownerUserId = user.id,
            course = locked,
            request = normalized,
            contentChangeSetId = UUID.randomUUID(),
            draftReleaseId = UUID.randomUUID(),
            outboxEventId = eventId,
            documentSha256 = sha256(canonicalJson),
            createdAt = now,
            correlationId = correlationId,
        )
        val response = repository.createDraft(command)
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "course",
                aggregateId = courseId,
                eventType = "content.full-course-draft-created.v1",
                schemaVersion = 1,
                payload = mapOf(
                    "eventId" to eventId,
                    "courseId" to courseId,
                    "baseReleaseId" to locked.activeReleaseId,
                    "draftReleaseId" to response.draftReleaseId,
                    "contentChangeSetId" to response.contentChangeSetId,
                    "releaseRevision" to response.releaseRevision,
                    "questionCount" to response.questionCount,
                    "requiredClientCapabilities" to response.requiredClientCapabilities,
                    "documentSha256" to command.documentSha256,
                ),
                correlationId = correlationId,
                occurredAt = now,
            ),
        )
        idempotencyService.record(
            user.id,
            OPERATION,
            idempotencyKey,
            lookup.fingerprint,
            response.draftReleaseId,
        )
        return response
    }

    private fun course(courseId: UUID, ownerUserId: UUID): FullCourseEditorCourseState =
        repository.courseState(courseId, ownerUserId)
            ?: throw NotFoundProblem("Course was not found.")

    private fun snapshot(course: FullCourseEditorCourseState): FullCourseEditorSnapshot =
        FullCourseEditorSnapshot(
            document = repository.document(course),
            entityTag = FullCourseEditorEntityTag.from(
                course.courseId,
                course.activeReleaseId,
                course.releaseRevision,
            ),
        )

    private fun sha256(value: String): String = HexFormat.of().formatHex(
        MessageDigest.getInstance("SHA-256").digest(value.toByteArray(StandardCharsets.UTF_8)),
    )

    private companion object {
        const val OPERATION = "teacher.full-course-draft"
    }
}

internal data class FullCourseEditorSnapshot(
    val document: FullCourseEditorDocument,
    val entityTag: String,
)

internal object FullCourseEditorEntityTag {
    fun from(courseId: UUID, releaseId: UUID, releaseRevision: Int): String {
        val canonical = "kelimio.full-course-editor.v1|$courseId|$releaseId|$releaseRevision"
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(canonical.toByteArray(StandardCharsets.UTF_8))
        return "\"${HexFormat.of().formatHex(digest)}\""
    }
}
