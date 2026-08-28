package com.kelimio.api.courseeditor

import jakarta.validation.Valid
import jakarta.validation.constraints.DecimalMax
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.Size
import java.math.BigDecimal
import java.time.OffsetDateTime
import java.util.UUID

internal data class FullCourseEditorDocument(
    val courseId: UUID,
    val activeReleaseId: UUID,
    val releaseRevision: Int,
    val name: String,
    val description: String?,
    val visibility: String,
    val targetLanguage: String,
    val defaultSupportLanguage: String,
    val supportLanguages: List<String>,
    val levels: List<CourseEditorLevel>,
)

internal data class SaveFullCourseEditorDraftRequest(
    val baseReleaseId: UUID,
    @field:Size(min = 1, max = 160)
    val name: String,
    @field:Size(min = 1, max = 2000)
    val description: String?,
    val visibility: String,
    @field:Valid
    @field:Size(min = 1, max = 100)
    val levels: List<CourseEditorLevel>,
)

internal data class CourseEditorLevel(
    val id: UUID?,
    @field:Size(min = 1, max = 2000)
    val title: String,
    @field:Valid
    @field:Size(min = 1, max = 100)
    val units: List<CourseEditorUnit>,
)

internal data class CourseEditorUnit(
    val id: UUID?,
    @field:Size(min = 1, max = 2000)
    val title: String,
    @field:Valid
    @field:Size(min = 1, max = 100)
    val topics: List<CourseEditorTopic>,
)

internal data class CourseEditorTopic(
    val id: UUID?,
    @field:Size(min = 1, max = 2000)
    val title: String,
    @field:Valid
    @field:Size(min = 1, max = 100)
    val tests: List<CourseEditorTest>,
)

internal data class CourseEditorTest(
    val id: UUID?,
    @field:Size(min = 1, max = 160)
    val title: String,
    @field:DecimalMin("0.50")
    @field:DecimalMax("1.00")
    val passThreshold: BigDecimal,
    @field:Valid
    @field:Size(min = 1, max = 500)
    val questions: List<CourseEditorQuestion>,
)

internal data class CourseEditorQuestion(
    val id: UUID?,
    val type: String,
    @field:Size(min = 1, max = 1000)
    val prompt: String?,
    @field:Size(min = 1, max = 500)
    val correctAnswer: String?,
    @field:Size(min = 1, max = 500)
    val alternativeCorrectAnswer: String?,
    val translations: Map<String, String> = emptyMap(),
    @field:Valid
    @field:Size(max = 4)
    val options: List<CourseEditorOption> = emptyList(),
    @field:Valid
    @field:Size(max = 6)
    val matchingPairs: List<CourseEditorMatchingPair> = emptyList(),
) {
    override fun toString(): String =
        "CourseEditorQuestion(id=$id, type=$type, prompt=[REDACTED], correctAnswer=[REDACTED], " +
            "alternativeCorrectAnswer=[REDACTED], translations=[REDACTED], options=[REDACTED], " +
            "matchingPairs=[REDACTED])"
}

internal data class CourseEditorOption(
    @field:Size(min = 1, max = 500)
    val text: String,
    val correct: Boolean,
    val translations: Map<String, String> = emptyMap(),
) {
    override fun toString(): String = "CourseEditorOption([REDACTED])"
}

internal data class CourseEditorMatchingPair(
    @field:Size(min = 1, max = 500)
    val targetText: String,
    val translations: Map<String, String>,
) {
    override fun toString(): String = "CourseEditorMatchingPair([REDACTED])"
}

internal data class FullCourseEditorDraftResponse(
    val courseId: UUID,
    val baseReleaseId: UUID,
    val contentChangeSetId: UUID,
    val draftReleaseId: UUID,
    val releaseRevision: Int,
    val questionCount: Int,
    val requiredClientCapabilities: List<String>,
    val createdAt: OffsetDateTime,
    val created: Boolean,
)

internal data class FullCourseEditorCourseState(
    val courseId: UUID,
    val ownerUserId: UUID,
    val activeReleaseId: UUID,
    val releaseRevision: Int,
    val publicationStatus: String,
    val name: String,
    val description: String?,
    val visibility: String,
    val targetLanguage: String,
    val defaultSupportLanguage: String,
    val supportLanguages: List<String>,
)

internal data class FullCourseEditorCommitCommand(
    val commandId: UUID,
    val ownerUserId: UUID,
    val course: FullCourseEditorCourseState,
    val request: SaveFullCourseEditorDraftRequest,
    val contentChangeSetId: UUID,
    val draftReleaseId: UUID,
    val outboxEventId: UUID,
    val documentSha256: String,
    val createdAt: OffsetDateTime,
    val correlationId: String,
)
