package com.kelimio.api.coursepublication

import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.annotation.JsonProperty
import jakarta.validation.constraints.Pattern
import java.time.OffsetDateTime
import java.util.UUID

enum class CourseReleaseOperation {
    INITIAL_PUBLICATION,
    PUBLICATION,
    ROLLBACK,
}

data class ActivateCourseReleaseRequest(
    @param:JsonProperty(value = "expectedActiveReleaseId", required = true)
    val expectedActiveReleaseId: UUID?,
    @field:Pattern(regexp = "^[0-9a-f]{64}$")
    val impactBindingSha256: String,
)

data class CourseReleaseImpactResponse(
    val courseId: UUID,
    val targetReleaseId: UUID,
    @get:JsonInclude(JsonInclude.Include.ALWAYS)
    val expectedActiveReleaseId: UUID?,
    val sourceChangeSetId: UUID,
    val operation: CourseReleaseOperation,
    val releaseRevision: Int,
    val targetQuestionCount: Int,
    val unchangedQuestionCount: Int,
    val changedQuestionCount: Int,
    val addedQuestionCount: Int,
    val removedQuestionCount: Int,
    val affectedEnrollmentCount: Int,
    val requiredClientCapabilities: List<String>,
    val impactBindingSha256: String,
)

data class CourseReleaseActivationResponse(
    val activationId: UUID,
    val courseId: UUID,
    val releaseId: UUID,
    @get:JsonInclude(JsonInclude.Include.ALWAYS)
    val previousReleaseId: UUID?,
    val sourceChangeSetId: UUID,
    val operation: CourseReleaseOperation,
    val releaseRevision: Int,
    val questionCount: Int,
    val requiredClientCapabilities: List<String>,
    val coursePublicationStatus: String,
    val reprojectionStatus: String,
    val activatedAt: OffsetDateTime,
    val created: Boolean,
)

data class CourseReleaseCourseState(
    val id: UUID,
    val ownerUserId: UUID,
    val publicationStatus: String,
    val activeReleaseId: UUID?,
    val activeReleaseRevision: Int?,
)

data class CourseReleaseTargetState(
    val id: UUID,
    val courseId: UUID,
    val revision: Int,
    val status: String,
    val sourceChangeSetId: UUID?,
)

data class CourseReleaseQuestionRef(
    val questionId: UUID,
    val questionRevisionId: UUID,
)

data class CourseReleaseImpactState(
    val course: CourseReleaseCourseState,
    val target: CourseReleaseTargetState,
    val currentQuestions: List<CourseReleaseQuestionRef>,
    val targetQuestions: List<CourseReleaseQuestionRef>,
    val requiredClientCapabilities: List<String>,
    val affectedEnrollmentCount: Int,
)

data class CourseReleaseActivationRecord(
    val activationId: UUID,
    val courseId: UUID,
    val releaseId: UUID,
    val previousReleaseId: UUID?,
    val sourceChangeSetId: UUID,
    val operation: CourseReleaseOperation,
    val releaseRevision: Int,
    val questionCount: Int,
    val requiredClientCapabilities: List<String>,
    val coursePublicationStatus: String,
    val reprojectionStatus: String,
    val activatedAt: OffsetDateTime,
)
