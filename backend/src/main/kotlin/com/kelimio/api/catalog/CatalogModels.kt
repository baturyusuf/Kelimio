package com.kelimio.api.catalog

import java.math.BigDecimal
import java.time.OffsetDateTime
import java.util.UUID

data class CourseSummary(
    val id: UUID,
    val name: String,
    val description: String?,
    val targetLanguage: String,
    val defaultSupportLanguage: String,
    val supportLanguages: List<String>,
    val accessType: String,
    val visibility: String,
    val ownerDisplayName: String,
    val releaseId: UUID,
    val enrolled: Boolean,
)

data class CourseTestSummary(
    val id: UUID,
    val revisionId: UUID,
    val title: String,
    val position: Int,
    val questionCount: Int,
)

data class CourseDetails(
    val course: CourseSummary,
    val tests: List<CourseTestSummary>,
)

data class EnrollmentResult(
    val id: UUID,
    val courseId: UUID,
    val supportLanguage: String,
    val status: String,
    val created: Boolean,
    val enrolledAt: OffsetDateTime,
)

data class TestContext(
    val testId: UUID,
    val testRevisionId: UUID,
    val courseId: UUID,
    val courseReleaseId: UUID,
    val courseAccessType: String,
    val passThreshold: BigDecimal,
)

enum class LearningQuestionType(
    val storageCode: String,
    val apiValue: String,
) {
    WORD_MULTIPLE_CHOICE("A", "WORD_MULTIPLE_CHOICE"),
    MULTIPLE_CHOICE_CLOZE("B", "MULTIPLE_CHOICE_CLOZE");

    companion object {
        fun fromStorageCode(storageCode: String): LearningQuestionType =
            entries.singleOrNull { it.storageCode == storageCode }
                ?: error("Unsupported stored learning question type")
    }
}

data class AttemptQuestionSource(
    val questionId: UUID,
    val questionRevisionId: UUID,
    val type: LearningQuestionType,
    val prompt: String,
    val options: List<QuestionOptionSource>,
    val position: Int,
)

data class QuestionOptionSource(
    val id: UUID,
    val text: String,
    val correct: Boolean,
    val position: Int,
)
