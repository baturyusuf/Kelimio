package com.kelimio.api.learningsession

import com.kelimio.api.catalog.LearningQuestionType
import com.kelimio.api.catalog.MatchingQuestionSource
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
    val supportLanguage: String,
    val passThreshold: BigDecimal,
    val startedAt: OffsetDateTime,
    val finishedAt: OffsetDateTime?,
    val shuffleSeed: Long,
)

data class ManifestQuestion(
    val questionId: UUID,
    val questionRevisionId: UUID,
    val type: LearningQuestionType,
    val prompt: String?,
    val options: List<ManifestOption>,
    val typedAnswer: TypedAnswerSource?,
    val matching: MatchingQuestionSource?,
    val targetItems: List<MatchingItem>,
    val supportItems: List<MatchingItem>,
    val supportLanguage: String,
    val position: Int,
) {
    override fun toString(): String =
        "ManifestQuestion(questionId=$questionId, questionRevisionId=$questionRevisionId, " +
            "type=$type, prompt=[REDACTED], options=[REDACTED], matching=[REDACTED], " +
            "targetItems=[REDACTED], supportItems=[REDACTED], supportLanguage=$supportLanguage, " +
            "position=$position)"
}

data class MatchingItem(
    val id: UUID,
    val text: String,
) {
    override fun toString(): String = "MatchingItem([REDACTED])"
}

data class CorrectMatch(
    val targetItemId: UUID,
    val supportItemId: UUID,
) {
    override fun toString(): String = "CorrectMatch([REDACTED])"
}

data class ManifestOption(
    val id: UUID,
    val text: String,
    val correct: Boolean,
    val position: Int,
) {
    override fun toString(): String =
        "ManifestOption(id=$id, text=[REDACTED], correct=[REDACTED], position=$position)"
}

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
    val matchingAnswerSalt: ByteArray?,
    val matchingAnswerDigest: ByteArray?,
    val matchingReplayKeyVersion: String?,
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
) {
    override fun toString(): String =
        "StoredAnswer(submissionId=$submissionId, attemptId=$attemptId, userId=$userId, " +
            "questionRevisionId=$questionRevisionId, answerKind=$answerKind, answerEvidence=[REDACTED], " +
            "correct=$correct, activeScoreDelta=$activeScoreDelta, lifetimeScoreDelta=$lifetimeScoreDelta, " +
            "activeQuestionScore=$activeQuestionScore, lifetimeScore=$lifetimeScore, " +
            "energyBalanceAfter=$energyBalanceAfter, energyUnlimited=$energyUnlimited, " +
            "energyNextRegenerationAt=$energyNextRegenerationAt, attemptStatusAfter=$attemptStatusAfter, " +
            "submittedAt=$submittedAt)"
}

data class StartAttemptResult(
    val attemptId: UUID,
    val testId: UUID,
    val testRevisionId: UUID,
    val supportLanguage: String,
    val status: String,
    val questions: List<ManifestQuestion>,
    val startedAt: OffsetDateTime,
)

data class SubmitAnswerResult(
    val submissionId: UUID,
    val correct: Boolean,
    val correctOptionId: UUID?,
    val correctAnswerText: String?,
    val correctMatches: List<CorrectMatch>?,
    val activeScoreDelta: Int,
    val lifetimeScoreDelta: Int,
    val activeQuestionScore: Int,
    val lifetimeScore: Long,
    val energy: EnergySnapshot,
    val attemptStatus: String,
) {
    override fun toString(): String =
        "SubmitAnswerResult(submissionId=$submissionId, correct=$correct, feedback=[REDACTED], " +
            "activeScoreDelta=$activeScoreDelta, lifetimeScoreDelta=$lifetimeScoreDelta, " +
            "activeQuestionScore=$activeQuestionScore, lifetimeScore=$lifetimeScore, " +
            "energy=$energy, attemptStatus=$attemptStatus)"
}

sealed interface SubmittedAnswer {
    data class Option(val selectedOptionId: UUID) : SubmittedAnswer {
        override fun toString(): String = "Option([REDACTED])"
    }

    class TypedText(val value: String) : SubmittedAnswer {
        override fun toString(): String = "TypedText([REDACTED])"
    }

    class Matching(val matches: List<SubmittedMatch>) : SubmittedAnswer {
        override fun toString(): String = "Matching([REDACTED])"
    }
}

class SubmittedMatch(
    val targetItemId: UUID,
    val supportItemId: UUID,
) {
    override fun toString(): String = "SubmittedMatch([REDACTED])"
}

internal data class AnswerEvaluation(
    val answerKind: String,
    val selectedOptionId: UUID?,
    val typedAnswerSalt: ByteArray?,
    val typedAnswerDigest: ByteArray?,
    val typedMatchOrdinal: Int?,
    val matchingAnswerSalt: ByteArray?,
    val matchingAnswerDigest: ByteArray?,
    val matchingReplayKeyVersion: String?,
    val correct: Boolean,
) {
    override fun toString(): String =
        "AnswerEvaluation(answerKind=$answerKind, answerEvidence=[REDACTED], correct=$correct)"
}

data class FinishAttemptResult(
    val attemptId: UUID,
    val status: String,
    val correctCount: Int,
    val totalQuestions: Int,
    val correctRatio: BigDecimal,
    val finishedAt: OffsetDateTime,
)
