package com.kelimio.api.learningsession

import com.kelimio.api.catalog.LearningQuestionType
import com.kelimio.api.catalog.TypedAnswerSource
import com.kelimio.api.energy.EnergySnapshot
import java.math.BigDecimal
import java.time.OffsetDateTime
import java.util.UUID

data class AttemptAggregate(
    val id: UUID,
    val userId: UUID,
    val courseId: UUID,
    val testRevisionId: UUID,
    val testId: UUID,
    val status: String,
    val totalQuestions: Int,
    val answeredCount: Int,
    val correctCount: Int,
    val courseAccessType: String,
    val passThreshold: BigDecimal,
    val startedAt: OffsetDateTime,
    val finishedAt: OffsetDateTime?,
    val shuffleSeed: Long,
)

data class ManifestQuestion(
    val questionId: UUID,
    val questionRevisionId: UUID,
    val type: LearningQuestionType,
    val prompt: String,
    val options: List<ManifestOption>,
    val typedAnswer: TypedAnswerSource?,
    val position: Int,
)

data class ManifestOption(
    val id: UUID,
    val text: String,
    val correct: Boolean,
    val position: Int,
)

data class StoredAnswer(
    val submissionId: UUID,
    val attemptId: UUID,
    val userId: UUID,
    val questionRevisionId: UUID,
    val answerKind: String,
    val selectedOptionId: UUID?,
    val typedAnswerSalt: ByteArray?,
    val typedAnswerDigest: ByteArray?,
    val typedMatchOrdinal: Int?,
    val correct: Boolean,
    val activeScoreDelta: Int,
    val lifetimeScoreDelta: Int,
    val activeQuestionScore: Int,
    val lifetimeScore: Long,
    val energyBalanceAfter: Int,
    val energyUnlimited: Boolean,
    val energyNextRegenerationAt: OffsetDateTime?,
    val attemptStatusAfter: String,
    val submittedAt: OffsetDateTime,
)

data class StartAttemptResult(
    val attemptId: UUID,
    val testId: UUID,
    val testRevisionId: UUID,
    val status: String,
    val questions: List<ManifestQuestion>,
    val startedAt: OffsetDateTime,
)

data class SubmitAnswerResult(
    val submissionId: UUID,
    val correct: Boolean,
    val correctOptionId: UUID?,
    val correctAnswerText: String?,
    val activeScoreDelta: Int,
    val lifetimeScoreDelta: Int,
    val activeQuestionScore: Int,
    val lifetimeScore: Long,
    val energy: EnergySnapshot,
    val attemptStatus: String,
)

sealed interface SubmittedAnswer {
    data class Option(val selectedOptionId: UUID) : SubmittedAnswer

    class TypedText(val value: String) : SubmittedAnswer {
        override fun toString(): String = "TypedText([REDACTED])"
    }
}

data class FinishAttemptResult(
    val attemptId: UUID,
    val status: String,
    val correctCount: Int,
    val totalQuestions: Int,
    val correctRatio: BigDecimal,
    val finishedAt: OffsetDateTime,
)
