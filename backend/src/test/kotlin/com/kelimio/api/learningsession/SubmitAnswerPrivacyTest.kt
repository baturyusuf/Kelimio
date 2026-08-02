package com.kelimio.api.learningsession

import com.kelimio.api.energy.EnergySnapshot
import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.web.UnprocessableProblem
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.catchThrowable
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.verifyNoInteractions
import org.springframework.boot.test.system.CapturedOutput
import org.springframework.boot.test.system.OutputCaptureExtension
import org.springframework.security.oauth2.jwt.Jwt
import java.time.OffsetDateTime
import java.util.UUID

@ExtendWith(OutputCaptureExtension::class)
class SubmitAnswerPrivacyTest {
    @Test
    fun `request and domain answer string forms redact typed text`() {
        val sensitiveAnswer = "private-answer-${UUID.randomUUID()}"
        val request = SubmitAnswerRequest(
            submissionId = UUID.randomUUID(),
            questionRevisionId = UUID.randomUUID(),
            typedAnswer = sensitiveAnswer,
        )

        assertThat(request.hasExactlyOneAnswer).isTrue()
        assertThat(request.toString())
            .contains("typedAnswer=[REDACTED]")
            .doesNotContain(sensitiveAnswer)
        assertThat(request.toSubmittedAnswer().toString())
            .contains("[REDACTED]")
            .doesNotContain(sensitiveAnswer)
    }

    @Test
    fun `response string form redacts option and typed answer keys`() {
        val optionKey = UUID.randomUUID()
        val typedKey = "private-answer-key-${UUID.randomUUID()}"
        val response = SubmitAnswerResponse(
            submissionId = UUID.randomUUID(),
            correct = true,
            correctOptionId = optionKey,
            correctAnswerText = typedKey,
            activeScoreDelta = 60,
            lifetimeScoreDelta = 60,
            activeQuestionScore = 60,
            lifetimeScore = 60,
            energy = EnergySnapshot(
                balance = 5,
                maximum = 5,
                unlimited = false,
                nextRegenerationAt = null,
                asOf = OffsetDateTime.parse("2026-08-02T00:00:00Z"),
            ),
            attemptState = "IN_PROGRESS",
        )

        assertThat(response.toString())
            .contains("correctOptionId=[REDACTED]")
            .contains("correctAnswerText=[REDACTED]")
            .doesNotContain(optionKey.toString())
            .doesNotContain(typedKey)
    }

    @Test
    fun `request rejects missing or overlapping answer forms`() {
        val submissionId = UUID.randomUUID()
        val questionRevisionId = UUID.randomUUID()

        assertThat(
            SubmitAnswerRequest(
                submissionId = submissionId,
                questionRevisionId = questionRevisionId,
            ).hasExactlyOneAnswer,
        ).isFalse()
        assertThat(
            SubmitAnswerRequest(
                submissionId = submissionId,
                questionRevisionId = questionRevisionId,
                selectedOptionId = UUID.randomUUID(),
                typedAnswer = "answer",
            ).hasExactlyOneAnswer,
        ).isFalse()
    }

    @Test
    fun `controller rejects invalid typed envelopes before identity or transactional service work`(output: CapturedOutput) {
        val currentUserService = mock(CurrentUserService::class.java)
        val learningSessionService = mock(LearningSessionService::class.java)
        val controller = LearningSessionController(currentUserService, learningSessionService)
        val sensitiveInvalidAnswer = "private-answer-${UUID.randomUUID()}\u202E"
        val invalidAnswers = listOf(
            "   ",
            "a".repeat(501),
            "line\nbreak",
            sensitiveInvalidAnswer,
        )

        invalidAnswers.forEach { invalidAnswer ->
            val thrown = catchThrowable {
                controller.submitAnswer(
                    jwt = mock(Jwt::class.java),
                    attemptId = UUID.randomUUID(),
                    idempotencyKey = UUID.randomUUID(),
                    request = SubmitAnswerRequest(
                        submissionId = UUID.randomUUID(),
                        questionRevisionId = UUID.randomUUID(),
                        typedAnswer = invalidAnswer,
                    ),
                )
            }
            assertThat(thrown)
                .isInstanceOf(UnprocessableProblem::class.java)
                .hasMessage("The typed answer is invalid.")
            assertThat(thrown.message).doesNotContain(invalidAnswer)
        }

        verifyNoInteractions(currentUserService, learningSessionService)
        assertThat(output.out).doesNotContain(sensitiveInvalidAnswer)
        assertThat(output.err).doesNotContain(sensitiveInvalidAnswer)
    }
}
