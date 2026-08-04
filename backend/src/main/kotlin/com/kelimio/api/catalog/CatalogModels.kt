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
    MULTIPLE_CHOICE_CLOZE("B", "MULTIPLE_CHOICE_CLOZE"),
    TYPED_CLOZE("C", "TYPED_CLOZE"),
    MATCHING("D", "MATCHING");

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
    val prompt: String?,
    val options: List<QuestionOptionSource>,
    val typedAnswer: TypedAnswerSource?,
    val matching: MatchingQuestionSource?,
    val position: Int,
) {
    override fun toString(): String =
        "AttemptQuestionSource(questionId=$questionId, questionRevisionId=$questionRevisionId, " +
            "type=$type, prompt=[REDACTED], options=[REDACTED], typedAnswer=[REDACTED], " +
            "matching=[REDACTED], position=$position)"
}

data class MatchingQuestionSource(
    val policyVersion: String,
    val labelPolicyVersion: String,
    val orderPolicyVersion: String,
    val targetLanguage: String,
    val pairs: List<MatchingPairSource>,
) {
    override fun toString(): String = "MatchingQuestionSource([REDACTED])"
}

data class MatchingPairSource(
    val targetItemId: UUID,
    val targetText: String,
    val supportItemId: UUID,
    val supportText: String,
    val position: Int,
) {
    override fun toString(): String = "MatchingPairSource([REDACTED])"
}

data class TypedAnswerSource(
    val primaryAnswerText: String,
    val alternativeAnswerText: String?,
    val policyVersion: String,
    val languageTag: String,
    val primaryMatchKey: String,
    val alternativeMatchKey: String?,
) {
    override fun toString(): String = "TypedAnswerSource([REDACTED])"
}

data class QuestionOptionSource(
    val id: UUID,
    val text: String,
    val correct: Boolean,
    val position: Int,
) {
    override fun toString(): String =
        "QuestionOptionSource(id=$id, text=[REDACTED], correct=[REDACTED], position=$position)"
}
