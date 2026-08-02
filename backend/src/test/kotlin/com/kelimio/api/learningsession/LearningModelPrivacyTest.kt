package com.kelimio.api.learningsession

import com.kelimio.api.catalog.AttemptQuestionSource
import com.kelimio.api.catalog.LearningQuestionType
import com.kelimio.api.catalog.MatchingPairSource
import com.kelimio.api.catalog.MatchingQuestionSource
import com.kelimio.api.catalog.QuestionOptionSource
import com.kelimio.api.catalog.TypedAnswerSource
import com.kelimio.api.energy.EnergySnapshot
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.math.BigDecimal
import java.time.OffsetDateTime
import java.util.UUID

class LearningModelPrivacyTest {
    @Test
    fun `authoritative answer material is redacted throughout model diagnostics`() {
        val targetId = UUID.randomUUID()
        val supportId = UUID.randomUUID()
        val targetText = "private-target-${UUID.randomUUID()}"
        val supportText = "private-support-${UUID.randomUUID()}"
        val typedText = "private-typed-${UUID.randomUUID()}"
        val typedKey = "private-key-${UUID.randomUUID()}"
        val pair = MatchingPairSource(targetId, targetText, supportId, supportText, 1)
        val matching = MatchingQuestionSource(
            policyVersion = MatchingAnswerReplayDigest.POLICY_VERSION,
            labelPolicyVersion = "matching-label-v1",
            orderPolicyVersion = MatchingOrderPolicy.VERSION,
            targetLanguage = "tr",
            pairs = listOf(pair),
        )
        val typed = TypedAnswerSource(typedText, null, "typed-answer-v1", "tr", typedKey, null)
        val option = QuestionOptionSource(UUID.randomUUID(), supportText, true, 1)
        val source = AttemptQuestionSource(
            questionId = UUID.randomUUID(),
            questionRevisionId = UUID.randomUUID(),
            type = LearningQuestionType.MATCHING,
            prompt = null,
            options = listOf(option),
            typedAnswer = typed,
            matching = matching,
            position = 1,
        )
        val manifest = ManifestQuestion(
            questionId = source.questionId,
            questionRevisionId = source.questionRevisionId,
            type = source.type,
            prompt = null,
            options = listOf(ManifestOption(option.id, option.text, option.correct, option.position)),
            typedAnswer = typed,
            matching = matching,
            targetItems = listOf(MatchingItem(targetId, targetText)),
            supportItems = listOf(MatchingItem(supportId, supportText)),
            supportLanguage = "en",
            position = 1,
        )

        listOf(
            pair,
            matching,
            typed,
            option,
            source,
            manifest.options.first(),
            manifest.targetItems.first(),
            manifest.supportItems.first(),
            manifest,
        ).forEach { value ->
            assertThat(value.toString())
                .contains("[REDACTED]")
                .doesNotContain(targetText)
                .doesNotContain(supportText)
                .doesNotContain(typedText)
                .doesNotContain(typedKey)
                .doesNotContain(supportId.toString())
        }
    }

    @Test
    fun `stored matching evidence and post-commit mapping are redacted in diagnostics`() {
        val now = OffsetDateTime.parse("2026-08-02T00:00:00Z")
        val targetId = UUID.randomUUID()
        val supportId = UUID.randomUUID()
        val salt = ByteArray(MatchingAnswerReplayDigest.SALT_BYTES) { 0x2a }
        val digest = ByteArray(MatchingAnswerReplayDigest.DIGEST_BYTES) { 0x5b }
        val keyVersion = "private-key-version-${UUID.randomUUID()}"
        val stored = StoredAnswer(
            submissionId = UUID.randomUUID(),
            attemptId = UUID.randomUUID(),
            userId = UUID.randomUUID(),
            questionRevisionId = UUID.randomUUID(),
            answerKind = "MATCHING",
            selectedOptionId = null,
            typedAnswerSalt = null,
            typedAnswerDigest = null,
            typedMatchOrdinal = null,
            matchingAnswerSalt = salt,
            matchingAnswerDigest = digest,
            matchingReplayKeyVersion = keyVersion,
            correct = true,
            activeScoreDelta = 60,
            lifetimeScoreDelta = 60,
            activeQuestionScore = 60,
            lifetimeScore = 60,
            energyBalanceAfter = 5,
            energyUnlimited = false,
            energyNextRegenerationAt = null,
            attemptStatusAfter = "IN_PROGRESS",
            submittedAt = now,
        )
        val result = SubmitAnswerResult(
            submissionId = stored.submissionId,
            correct = true,
            correctOptionId = null,
            correctAnswerText = null,
            correctMatches = listOf(CorrectMatch(targetId, supportId)),
            activeScoreDelta = 60,
            lifetimeScoreDelta = 60,
            activeQuestionScore = 60,
            lifetimeScore = 60,
            energy = EnergySnapshot(5, 5, false, null, now),
            attemptStatus = "IN_PROGRESS",
        )
        val evaluation = AnswerEvaluation(
            answerKind = "MATCHING",
            selectedOptionId = null,
            typedAnswerSalt = null,
            typedAnswerDigest = null,
            typedMatchOrdinal = null,
            matchingAnswerSalt = salt,
            matchingAnswerDigest = digest,
            matchingReplayKeyVersion = keyVersion,
            correct = true,
        )

        assertThat(stored.toString())
            .contains("answerEvidence=[REDACTED]")
            .doesNotContain("matchingAnswerSalt")
            .doesNotContain("matchingAnswerDigest")
            .doesNotContain("matchingReplayKeyVersion")
            .doesNotContain(keyVersion)
        assertThat(result.toString())
            .contains("feedback=[REDACTED]")
            .doesNotContain(targetId.toString())
            .doesNotContain(supportId.toString())
        assertThat(result.correctMatches!!.single().toString())
            .contains("[REDACTED]")
            .doesNotContain(targetId.toString())
            .doesNotContain(supportId.toString())
        assertThat(evaluation.toString())
            .contains("answerEvidence=[REDACTED]")
            .doesNotContain("matchingAnswerSalt")
            .doesNotContain("matchingAnswerDigest")
            .doesNotContain("matchingReplayKeyVersion")
            .doesNotContain(keyVersion)
    }

    @Suppress("unused")
    private val compileGuard = BigDecimal.ZERO
}
