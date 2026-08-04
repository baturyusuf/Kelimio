package com.kelimio.api.courseauthoring

import java.time.OffsetDateTime
import java.util.UUID

data class CreateLocalCourseRevisionRequest(
    val baseReleaseId: UUID,
)

data class CreateLocalCourseEditorDraftRequest(
    val baseReleaseId: UUID,
    val questionRevisionId: UUID,
    val editedPrompt: String,
)

data class LocalCourseEditorSnapshot(
    val courseId: UUID,
    val courseName: String,
    val activeReleaseId: UUID,
    val releaseRevision: Int,
    val levelTitle: String,
    val unitTitle: String,
    val topicTitle: String,
    val testId: UUID,
    val testTitle: String,
    val questionId: UUID,
    val questionRevisionId: UUID,
    val questionRevision: Int,
    val prompt: String,
)

internal data class LocalCourseEditorDocument(
    val snapshot: LocalCourseEditorSnapshot,
    val entityTag: String,
)

data class SubsequentCourseDraftResult(
    val courseId: UUID,
    val baseReleaseId: UUID,
    val contentChangeSetId: UUID,
    val draftReleaseId: UUID,
    val releaseRevision: Int,
    val changedQuestionId: UUID,
    val previousQuestionRevisionId: UUID,
    val questionRevisionId: UUID,
    val changedTestId: UUID,
    val previousTestRevisionId: UUID,
    val testRevisionId: UUID,
    val createdAt: OffsetDateTime,
    val created: Boolean,
)

internal data class CourseAuthoringCourseState(
    val courseId: UUID,
    val ownerUserId: UUID,
    val publicationStatus: String,
    val activeReleaseId: UUID?,
)

internal data class CourseAuthoringSource(
    val courseId: UUID,
    val baseReleaseId: UUID,
    val nextReleaseRevision: Int,
    val changedQuestionId: UUID,
    val previousQuestionRevisionId: UUID,
    val previousQuestionRevision: Int,
    val nextQuestionRevision: Int,
    val previousPrompt: String,
    val changedTestId: UUID,
    val previousTestRevisionId: UUID,
    val previousTestRevision: Int,
    val nextTestRevision: Int,
)

internal data class CreateSubsequentCourseDraftCommand(
    val commandId: UUID,
    val ownerUserId: UUID,
    val source: CourseAuthoringSource,
    val contentChangeSetId: UUID,
    val draftReleaseId: UUID,
    val questionRevisionId: UUID,
    val testRevisionId: UUID,
    val outboxEventId: UUID,
    val editedPrompt: String,
    val occurredAt: OffsetDateTime,
    val correlationId: String,
) {
    val releaseRevision: Int = source.nextReleaseRevision
}
