package com.kelimio.api.courseauthoring

import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.NotFoundProblem
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Service
internal class SubsequentCourseDraftService(
    private val repository: SubsequentCourseDraftRepository,
    private val idempotencyService: IdempotencyService,
    private val outbox: TransactionalOutbox,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
    @Value("\${KELIMIO_ENVIRONMENT}") private val environment: String,
    @Value("\${KELIMIO_LOCAL_COURSE_AUTHORING_ENABLED:false}") private val enabled: Boolean,
) {
    @Transactional
    fun create(
        user: AppUser,
        courseId: UUID,
        idempotencyKey: UUID,
        request: CreateLocalCourseRevisionRequest,
    ): SubsequentCourseDraftResult {
        if (environment.trim().lowercase() !in setOf("local", "test") || !enabled) {
            throw NotFoundProblem("Local course authoring is not enabled.")
        }
        val canonicalRequest = "$courseId|${request.baseReleaseId}"
        val lookup = idempotencyService.lockAndFind(
            user.id,
            OPERATION,
            idempotencyKey,
            canonicalRequest,
        )
        lookup.resourceId?.let { releaseId ->
            return repository.result(releaseId, user.id, created = false)
                ?: throw ConflictProblem("The idempotent course revision no longer exists.")
        }

        val course = repository.lockCourse(courseId)
            ?.takeIf { it.ownerUserId == user.id }
            ?: throw NotFoundProblem("Course was not found.")
        if (course.publicationStatus !in setOf("PUBLISHED", "HIDDEN")) {
            throw ConflictProblem("Only a published or hidden course can create a later release.")
        }
        if (course.activeReleaseId != request.baseReleaseId) {
            throw ConflictProblem("The active course release changed before authoring began.")
        }
        if (repository.hasUnpublishedDraft(courseId, request.baseReleaseId)) {
            throw ConflictProblem("This active release already has an unpublished authored draft.")
        }
        val source = repository.source(courseId, request.baseReleaseId)
            ?: throw ConflictProblem("The active release has no eligible typed-cloze revision for the local authoring proof.")
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val command = CreateSubsequentCourseDraftCommand(
            commandId = idempotencyKey,
            ownerUserId = user.id,
            source = source,
            contentChangeSetId = UUID.randomUUID(),
            draftReleaseId = UUID.randomUUID(),
            questionRevisionId = UUID.randomUUID(),
            testRevisionId = UUID.randomUUID(),
            outboxEventId = UUID.randomUUID(),
            occurredAt = now,
            correlationId = correlationIdProvider.current(),
        )
        repository.createDraft(command)
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = command.outboxEventId,
                aggregateType = "course",
                aggregateId = courseId,
                eventType = "content.release-draft-created.v1",
                schemaVersion = 1,
                payload = mapOf(
                    "eventId" to command.outboxEventId,
                    "courseId" to courseId,
                    "baseReleaseId" to source.baseReleaseId,
                    "draftReleaseId" to command.draftReleaseId,
                    "contentChangeSetId" to command.contentChangeSetId,
                    "changedQuestionId" to source.changedQuestionId,
                    "previousQuestionRevisionId" to source.previousQuestionRevisionId,
                    "questionRevisionId" to command.questionRevisionId,
                    "releaseRevision" to command.releaseRevision,
                ),
                correlationId = command.correlationId,
                occurredAt = now,
            ),
        )
        repository.insertCommit(command)
        idempotencyService.record(
            user.id,
            OPERATION,
            idempotencyKey,
            lookup.fingerprint,
            command.draftReleaseId,
        )
        return checkNotNull(repository.result(command.draftReleaseId, user.id, created = true))
    }

    private companion object {
        const val OPERATION = "development.create-course-revision"
    }
}
