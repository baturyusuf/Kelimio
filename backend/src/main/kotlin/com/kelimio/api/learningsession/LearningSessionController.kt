package com.kelimio.api.learningsession

import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.energy.EnergySnapshot
import jakarta.validation.Valid
import jakarta.validation.constraints.NotNull
import org.springframework.http.HttpStatus
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import java.math.BigDecimal
import java.time.OffsetDateTime
import java.util.UUID

@RestController
@RequestMapping("/v1")
class LearningSessionController(
    private val currentUserService: CurrentUserService,
    private val learningSessionService: LearningSessionService,
) {
    @PostMapping("/tests/{testId}/attempts")
    @ResponseStatus(HttpStatus.CREATED)
    fun startAttempt(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable testId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
    ): StartAttemptResponse =
        learningSessionService.startAttempt(currentUserService.requireCompleted(jwt), testId, idempotencyKey).toResponse()

    @PostMapping("/attempts/{attemptId}/answers")
    fun submitAnswer(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable attemptId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
        @Valid @RequestBody request: SubmitAnswerRequest,
    ): SubmitAnswerResponse =
        learningSessionService.submitAnswer(
            user = currentUserService.requireCompleted(jwt),
            attemptId = attemptId,
            submissionId = request.submissionId,
            questionRevisionId = request.questionRevisionId,
            selectedOptionId = request.selectedOptionId,
            idempotencyKey = idempotencyKey,
        ).toResponse()

    @PostMapping("/attempts/{attemptId}/finish")
    fun finishAttempt(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable attemptId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
    ): FinishAttemptResponse =
        learningSessionService.finishAttempt(currentUserService.requireCompleted(jwt), attemptId, idempotencyKey).toResponse()
}

data class SubmitAnswerRequest(
    @field:NotNull val submissionId: UUID,
    @field:NotNull val questionRevisionId: UUID,
    @field:NotNull val selectedOptionId: UUID,
)

data class StartAttemptResponse(
    val id: UUID,
    val testId: UUID,
    val testRevisionId: UUID,
    val state: String,
    val questions: List<AttemptQuestionResponse>,
    val startedAt: OffsetDateTime,
)

data class AttemptQuestionResponse(
    val questionId: UUID,
    val questionRevisionId: UUID,
    val type: String,
    val prompt: String,
    val position: Int,
    val options: List<AttemptOptionResponse>,
)

data class AttemptOptionResponse(
    val id: UUID,
    val text: String,
)

data class SubmitAnswerResponse(
    val submissionId: UUID,
    val correct: Boolean,
    val correctOptionId: UUID,
    val activeScoreDelta: Int,
    val lifetimeScoreDelta: Int,
    val activeQuestionScore: Int,
    val lifetimeScore: Long,
    val energy: EnergySnapshot,
    val attemptState: String,
)

data class FinishAttemptResponse(
    val attemptId: UUID,
    val state: String,
    val correctCount: Int,
    val questionCount: Int,
    val correctRatio: BigDecimal,
    val completedAt: OffsetDateTime,
)

private fun StartAttemptResult.toResponse() = StartAttemptResponse(
    id = attemptId,
    testId = testId,
    testRevisionId = testRevisionId,
    state = status,
    questions = questions.map { question ->
        AttemptQuestionResponse(
            questionId = question.questionId,
            questionRevisionId = question.questionRevisionId,
            type = question.type.apiValue,
            prompt = question.prompt,
            position = question.position,
            options = question.options.map { AttemptOptionResponse(it.id, it.text) },
        )
    },
    startedAt = startedAt,
)

private fun SubmitAnswerResult.toResponse() = SubmitAnswerResponse(
    submissionId,
    correct,
    correctOptionId,
    activeScoreDelta,
    lifetimeScoreDelta,
    activeQuestionScore,
    lifetimeScore,
    energy,
    attemptStatus,
)

private fun FinishAttemptResult.toResponse() = FinishAttemptResponse(
    attemptId,
    status,
    correctCount,
    totalQuestions,
    correctRatio,
    finishedAt,
)
