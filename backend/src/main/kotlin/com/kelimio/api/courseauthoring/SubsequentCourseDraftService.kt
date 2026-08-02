package com.kelimio.api.courseauthoring

import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.NotFoundProblem
import com.kelimio.api.web.UnprocessableProblem
import org.springframework.beans.factory.annotation.Value
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
internal class SubsequentCourseDraftService(
    private val repository: SubsequentCourseDraftRepository,
    private val idempotencyService: IdempotencyService,
    private val outbox: TransactionalOutbox,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
    @Value("\${KELIMIO_ENVIRONMENT}") private val environment: String,
    @Value("\${KELIMIO_LOCAL_COURSE_AUTHORING_ENABLED:false}") private val enabled: Boolean,
) {
    @Transactional(readOnly = true)
    fun editor(user: AppUser, courseId: UUID): LocalCourseEditorDocument {
        requireEnabled()
        repository.course(courseId)
            ?.takeIf { it.ownerUserId == user.id }
            ?: throw NotFoundProblem("Course was not found.")
        val snapshot = repository.editorSnapshot(courseId)
            ?: throw ConflictProblem("The active release has no editable typed-cloze question.")
        return LocalCourseEditorDocument(
            snapshot = snapshot,
            entityTag = LocalCourseEditorEntityTag.from(
                snapshot.courseId,
                snapshot.activeReleaseId,
                snapshot.questionRevisionId,
            ),
        )
    }

    @Transactional
    fun create(
        user: AppUser,
        courseId: UUID,
        idempotencyKey: UUID,
        request: CreateLocalCourseRevisionRequest,
    ): SubsequentCourseDraftResult = createInternal(
        user = user,
        courseId = courseId,
        idempotencyKey = idempotencyKey,
        baseReleaseId = request.baseReleaseId,
        expectedQuestionRevisionId = null,
        ifMatch = null,
        canonicalRequest = "$courseId|${request.baseReleaseId}",
    ) { source ->
        "${source.previousPrompt} [yerel revizyon ${source.nextReleaseRevision}]"
    }

    @Transactional
    fun createEdited(
        user: AppUser,
        courseId: UUID,
        idempotencyKey: UUID,
        ifMatch: String,
        request: CreateLocalCourseEditorDraftRequest,
    ): SubsequentCourseDraftResult = createInternal(
        user = user,
        courseId = courseId,
        idempotencyKey = idempotencyKey,
        baseReleaseId = request.baseReleaseId,
        expectedQuestionRevisionId = request.questionRevisionId,
        ifMatch = ifMatch,
        canonicalRequest = "$courseId|${request.baseReleaseId}|${request.questionRevisionId}|${request.editedPrompt}",
    ) { request.editedPrompt }

    private fun createInternal(
        user: AppUser,
        courseId: UUID,
        idempotencyKey: UUID,
        baseReleaseId: UUID,
        expectedQuestionRevisionId: UUID?,
        ifMatch: String?,
        canonicalRequest: String,
        editedPrompt: (CourseAuthoringSource) -> String,
    ): SubsequentCourseDraftResult {
        requireEnabled()
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
        if (course.activeReleaseId != baseReleaseId) {
            throw ConflictProblem("The active course release changed before authoring began.")
        }
        if (repository.hasUnpublishedDraft(courseId, baseReleaseId)) {
            throw ConflictProblem("This active release already has an unpublished authored draft.")
        }
        val source = repository.source(
            courseId,
            baseReleaseId,
            expectedQuestionRevisionId,
        )
            ?: throw ConflictProblem("The active release has no eligible typed-cloze revision for the local authoring proof.")
        if (expectedQuestionRevisionId != null && source.previousQuestionRevisionId != expectedQuestionRevisionId) {
            throw ConflictProblem("The editable question revision changed before the draft was saved.")
        }
        if (ifMatch != null && ifMatch != LocalCourseEditorEntityTag.from(
                source.courseId,
                source.baseReleaseId,
                source.previousQuestionRevisionId,
            )
        ) {
            throw ConflictProblem("The course editor version changed before the draft was saved.")
        }
        val prompt = editedPrompt(source)
        validateEditedPrompt(prompt, source.previousPrompt)
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
            editedPrompt = prompt,
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

    private fun requireEnabled() {
        if (environment.trim().lowercase() !in setOf("local", "test") || !enabled) {
            throw NotFoundProblem("Local course authoring is not enabled.")
        }
    }

    private fun validateEditedPrompt(prompt: String, previousPrompt: String) {
        if (prompt.isBlank() || prompt.length > 1000 || prompt == previousPrompt ||
            prompt.windowed(CLOZE_MARKER.length).count { it == CLOZE_MARKER } != 1
        ) {
            throw UnprocessableProblem(
                "The edited typed-cloze prompt must be changed, contain exactly one --- marker, and use at most 1000 characters.",
            )
        }
    }

    private companion object {
        const val OPERATION = "development.create-course-revision"
        const val CLOZE_MARKER = "---"
    }
}

internal object LocalCourseEditorEntityTag {
    fun from(courseId: UUID, releaseId: UUID, questionRevisionId: UUID): String {
        val canonical = "kelimio.course-editor.v1|$courseId|$releaseId|$questionRevisionId"
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(canonical.toByteArray(StandardCharsets.UTF_8))
        return "\"${HexFormat.of().formatHex(digest)}\""
    }
}
