package com.kelimio.api.learningsession

import com.fasterxml.jackson.annotation.JsonIgnore
import com.fasterxml.jackson.annotation.JsonInclude
import com.kelimio.api.energy.EnergySnapshot
import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.language.InvalidTypedAnswerException
import com.kelimio.api.language.TypedAnswerPolicy
import com.kelimio.api.web.UnprocessableProblem
import jakarta.validation.Valid
import jakarta.validation.constraints.AssertTrue
import jakarta.validation.constraints.NotNull
import org.springframework.http.CacheControl
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.GetMapping
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
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
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
    ): ResponseEntity<SubmitAnswerResponse> {
        val answer = request.toSubmittedAnswer()
        return noStore(
            learningSessionService.submitAnswer(
                user = currentUserService.requireCompleted(jwt),
                attemptId = attemptId,
                submissionId = request.submissionId,
                questionRevisionId = request.questionRevisionId,
                answer = answer,
                idempotencyKey = idempotencyKey,
            ).toResponse(),
        )
    }

    @GetMapping("/attempts/{attemptId}/answers/{submissionId}")
    fun getRecordedAnswer(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable attemptId: UUID,
        @PathVariable submissionId: UUID,
    ): ResponseEntity<SubmitAnswerResponse> =
        noStore(
            learningSessionService.getRecordedAnswer(
                currentUserService.requireCompleted(jwt),
                attemptId,
                submissionId,
            ).toResponse(),
        )

    @PostMapping("/attempts/{attemptId}/finish")
    fun finishAttempt(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable attemptId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
    ): FinishAttemptResponse =
        learningSessionService.finishAttempt(currentUserService.requireCompleted(jwt), attemptId, idempotencyKey).toResponse()
}

class SubmitAnswerRequest(
    @field:NotNull val submissionId: UUID,
    @field:NotNull val questionRevisionId: UUID,
    val selectedOptionId: UUID? = null,
    val typedAnswer: String? = null,
    @field:Valid val matches: List<MatchingSelectionRequest?>? = null,
) {
    @get:JsonIgnore
    @get:AssertTrue(message = "Exactly one answer form is required")
    val hasExactlyOneAnswer: Boolean
        get() = listOf(selectedOptionId, typedAnswer, matches).count { it != null } == 1

    fun toSubmittedAnswer(): SubmittedAnswer {
        selectedOptionId?.let { return SubmittedAnswer.Option(it) }
        typedAnswer?.let { value ->
            try {
                TypedAnswerPolicy.validateRawEnvelope(value)
            } catch (_: InvalidTypedAnswerException) {
                throw UnprocessableProblem("The typed answer is invalid.")
            }
            return SubmittedAnswer.TypedText(value)
        }
        val edges = checkNotNull(matches).map { selection ->
            val value = selection
                ?: throw UnprocessableProblem("The matching answer must be a complete bijection.")
            SubmittedMatch(value.targetItemId, value.supportItemId)
        }
        val targetIds = edges.map { it.targetItemId }
        val supportIds = edges.map { it.supportItemId }
        if (
            edges.size !in MatchingAnswerReplayDigest.MIN_EDGES..MatchingAnswerReplayDigest.MAX_EDGES ||
            targetIds.toSet().size != edges.size ||
            supportIds.toSet().size != edges.size ||
            targetIds.toSet().intersect(supportIds.toSet()).isNotEmpty()
        ) {
            throw UnprocessableProblem("The matching answer must be a complete bijection.")
        }
        return SubmittedAnswer.Matching(edges)
    }

    override fun toString(): String =
        "SubmitAnswerRequest(submissionId=$submissionId, questionRevisionId=$questionRevisionId, " +
            "selectedOptionId=[REDACTED], typedAnswer=[REDACTED], matches=[REDACTED])"
}

data class MatchingSelectionRequest(
    @field:NotNull val targetItemId: UUID,
    @field:NotNull val supportItemId: UUID,
) {
    override fun toString(): String = "MatchingSelectionRequest([REDACTED])"
}

data class StartAttemptResponse(
    val id: UUID,
    val testId: UUID,
    val testRevisionId: UUID,
    val supportLanguage: String,
    val state: String,
    val questions: List<AttemptQuestionResponse>,
    val startedAt: OffsetDateTime,
)

data class AttemptQuestionResponse(
    val questionId: UUID,
    val questionRevisionId: UUID,
    val type: String,
    @get:JsonInclude(JsonInclude.Include.ALWAYS)
    val prompt: String?,
    val position: Int,
    val options: List<AttemptOptionResponse>,
    val targetItems: List<MatchingItemResponse>,
    val supportItems: List<MatchingItemResponse>,
)

data class AttemptOptionResponse(
    val id: UUID,
    val text: String,
)

data class MatchingItemResponse(
    val id: UUID,
    val text: String,
)

data class SubmitAnswerResponse(
    val submissionId: UUID,
    val correct: Boolean,
    val correctOptionId: UUID?,
    val correctAnswerText: String?,
    val correctMatches: List<CorrectMatchResponse>?,
    val activeScoreDelta: Int,
    val lifetimeScoreDelta: Int,
    val activeQuestionScore: Int,
    val lifetimeScore: Long,
    val energy: EnergySnapshot,
    val attemptState: String,
) {
    override fun toString(): String =
        "SubmitAnswerResponse(submissionId=$submissionId, correct=$correct, " +
            "feedback=[REDACTED], " +
            "activeScoreDelta=$activeScoreDelta, lifetimeScoreDelta=$lifetimeScoreDelta, " +
            "activeQuestionScore=$activeQuestionScore, lifetimeScore=$lifetimeScore, " +
            "energy=$energy, attemptState=$attemptState)"
}

data class CorrectMatchResponse(
    val targetItemId: UUID,
    val supportItemId: UUID,
) {
    override fun toString(): String = "CorrectMatchResponse([REDACTED])"
}

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
    supportLanguage = supportLanguage,
    state = status,
    questions = questions.map { question ->
        AttemptQuestionResponse(
            questionId = question.questionId,
            questionRevisionId = question.questionRevisionId,
            type = question.type.apiValue,
            prompt = question.prompt,
            position = question.position,
            options = question.options.map { AttemptOptionResponse(it.id, it.text) },
            targetItems = question.targetItems.map { MatchingItemResponse(it.id, it.text) },
            supportItems = question.supportItems.map { MatchingItemResponse(it.id, it.text) },
        )
    },
    startedAt = startedAt,
)

private fun SubmitAnswerResult.toResponse() = SubmitAnswerResponse(
    submissionId = submissionId,
    correct = correct,
    correctOptionId = correctOptionId,
    correctAnswerText = correctAnswerText,
    correctMatches = correctMatches?.map { CorrectMatchResponse(it.targetItemId, it.supportItemId) },
    activeScoreDelta = activeScoreDelta,
    lifetimeScoreDelta = lifetimeScoreDelta,
    activeQuestionScore = activeQuestionScore,
    lifetimeScore = lifetimeScore,
    energy = energy,
    attemptState = attemptStatus,
)

private fun FinishAttemptResult.toResponse() = FinishAttemptResponse(
    attemptId,
    status,
    correctCount,
    totalQuestions,
    correctRatio,
    finishedAt,
)

private fun <T> noStore(body: T): ResponseEntity<T> =
    ResponseEntity.ok()
        .cacheControl(CacheControl.noStore())
        .body(body)
