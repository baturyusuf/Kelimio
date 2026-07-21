package com.kelimio.api.learningsession

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.catalog.LearningContentQuery
import com.kelimio.api.energy.EnergyService
import com.kelimio.api.energy.EnergySnapshot
import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.outbox.OutboxRepository
import com.kelimio.api.scoring.ScoringService
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.ForbiddenProblem
import com.kelimio.api.web.NotFoundProblem
import com.kelimio.api.web.UnprocessableProblem
import org.jooq.JSONB
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal
import java.math.RoundingMode
import java.security.SecureRandom
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.Collections
import java.util.Random
import java.util.UUID

@Service
class LearningSessionService(
    private val learningContentQuery: LearningContentQuery,
    private val repository: LearningSessionRepository,
    private val scoringService: ScoringService,
    private val energyService: EnergyService,
    private val outboxRepository: OutboxRepository,
    private val idempotencyService: IdempotencyService,
    private val objectMapper: ObjectMapper,
    private val clock: Clock,
) {
    private val secureRandom = SecureRandom()

    @Transactional
    fun startAttempt(
        user: AppUser,
        testId: UUID,
        idempotencyKey: UUID,
    ): StartAttemptResult {
        val lookup = idempotencyService.lockAndFind(
            user.id,
            "learning.start-attempt",
            idempotencyKey,
            testId.toString(),
        )
        lookup.resourceId?.let { return replayStart(user, it) }
        val context = learningContentQuery.findActiveTest(testId)
            ?: throw NotFoundProblem("Test was not found.")
        if (!learningContentQuery.hasActiveEnrollment(context.courseId, user.id)) {
            throw ForbiddenProblem("An active course enrollment is required.")
        }
        if (context.courseAccessType != "FREE") {
            throw ForbiddenProblem("Paid-course learning is disabled until a verified entitlement is available.")
        }

        val sourceQuestions = learningContentQuery.findAttemptQuestions(context.testRevisionId)
        if (sourceQuestions.isEmpty()) {
            throw ConflictProblem("The active test revision contains no questions.")
        }
        sourceQuestions.forEach { source ->
            if (source.type != "A" || source.options.size != 4 || source.options.count { it.correct } != 1) {
                throw ConflictProblem("The active test revision contains an invalid A question.")
            }
        }

        val shuffleSeed = secureRandom.nextLong()
        val shuffled = sourceQuestions.toMutableList()
        Collections.shuffle(shuffled, Random(shuffleSeed))
        val responseQuestions = shuffled.mapIndexed { index, source ->
            val options = source.options.map {
                ManifestOption(it.id, it.text, it.correct, it.position)
            }.toMutableList()
            Collections.shuffle(options, Random(shuffleSeed xor source.questionRevisionId.hashCode().toLong()))
            ManifestQuestion(
                questionId = source.questionId,
                questionRevisionId = source.questionRevisionId,
                type = source.type,
                prompt = source.prompt,
                options = options,
                position = index + 1,
            )
        }

        val attemptId = UUID.randomUUID()
        val now = now()
        repository.createAttempt(
            attemptId,
            user.id,
            context.courseId,
            context.courseReleaseId,
            context.courseAccessType,
            context.testRevisionId,
            shuffleSeed,
            responseQuestions.size,
            now,
        )
        responseQuestions.forEach {
            repository.addManifestQuestion(
                attemptId,
                context.testRevisionId,
                context.courseId,
                it.questionRevisionId,
                it.position,
            )
        }
        repository.appendAttemptEvent(
            attemptId,
            null,
            "STARTED",
            json(mapOf("testRevisionId" to context.testRevisionId, "totalQuestions" to responseQuestions.size)),
            now,
        )
        outboxRepository.append(
            "test-attempt",
            attemptId,
            "learning.attempt-started.v1",
            mapOf(
                "userId" to user.id,
                "courseId" to context.courseId,
                "courseReleaseId" to context.courseReleaseId,
                "testRevisionId" to context.testRevisionId,
                "totalQuestions" to responseQuestions.size,
            ),
        )
        idempotencyService.record(
            user.id,
            "learning.start-attempt",
            idempotencyKey,
            lookup.fingerprint,
            attemptId,
        )
        return StartAttemptResult(
            attemptId,
            testId,
            context.testRevisionId,
            "IN_PROGRESS",
            responseQuestions,
            now,
        )
    }

    @Transactional
    fun submitAnswer(
        user: AppUser,
        attemptId: UUID,
        submissionId: UUID,
        questionRevisionId: UUID,
        selectedOptionId: UUID,
        idempotencyKey: UUID,
    ): SubmitAnswerResult {
        val lookup = idempotencyService.lockAndFind(
            user.id,
            "learning.submit-answer",
            idempotencyKey,
            "$attemptId|$submissionId|$questionRevisionId|$selectedOptionId",
        )
        lookup.resourceId?.let { resourceId ->
            val stored = repository.findAnswerBySubmissionId(resourceId)
                ?: throw ConflictProblem("The idempotent answer fact no longer exists.")
            return replay(stored, user, attemptId, questionRevisionId, selectedOptionId)
        }
        repository.findAnswerBySubmissionId(submissionId)?.let {
            val response = replay(it, user, attemptId, questionRevisionId, selectedOptionId)
            idempotencyService.record(
                user.id,
                "learning.submit-answer",
                idempotencyKey,
                lookup.fingerprint,
                submissionId,
            )
            return response
        }

        val attempt = repository.lockAttempt(attemptId, user.id)
            ?: throw NotFoundProblem("Attempt was not found.")
        repository.findAnswerBySubmissionId(submissionId)?.let {
            val response = replay(it, user, attemptId, questionRevisionId, selectedOptionId)
            idempotencyService.record(
                user.id,
                "learning.submit-answer",
                idempotencyKey,
                lookup.fingerprint,
                submissionId,
            )
            return response
        }
        if (attempt.status != "IN_PROGRESS") {
            throw ConflictProblem("The attempt is not accepting answers.")
        }

        val manifestQuestion = repository.findManifestQuestion(attemptId, questionRevisionId)
            ?: throw UnprocessableProblem("The question does not belong to this attempt manifest.")
        if (manifestQuestion.position != attempt.answeredCount + 1) {
            throw ConflictProblem("Answers must follow the server-issued attempt order.")
        }
        val selectedOption = repository.findOption(questionRevisionId, selectedOptionId)
            ?: throw UnprocessableProblem("The selected option does not belong to the question.")
        repository.findAnswerForQuestion(attemptId, questionRevisionId)?.let {
            throw ConflictProblem("The question was already answered with another submissionId.")
        }

        val correct = selectedOption.correct
        val energyDecision = energyService.applyForAnswer(
            userId = user.id,
            wrongAnswer = !correct,
            consumesEnergy = attempt.courseAccessType == "FREE",
        )
        val appliedScore = scoringService.applyMastery(user.id, questionRevisionId, correct)
        val statusAfter = if (energyDecision.interrupted) "INTERRUPTED_ENERGY" else "IN_PROGRESS"
        val now = now()
        val stored = StoredAnswer(
            submissionId = submissionId,
            attemptId = attemptId,
            userId = user.id,
            questionRevisionId = questionRevisionId,
            selectedOptionId = selectedOptionId,
            correct = correct,
            activeScoreDelta = appliedScore.change.activeDelta,
            lifetimeScoreDelta = appliedScore.change.lifetimeDelta,
            activeQuestionScore = appliedScore.change.newState.activeScore,
            lifetimeScore = appliedScore.lifetimeScore,
            energyBalanceAfter = energyDecision.snapshot.balance,
            energyUnlimited = energyDecision.snapshot.unlimited,
            energyNextRegenerationAt = energyDecision.snapshot.nextRegenerationAt,
            attemptStatusAfter = statusAfter,
            submittedAt = now,
        )
        repository.insertAnswer(stored)
        scoringService.appendEvent(user.id, attemptId, submissionId, questionRevisionId, appliedScore)
        energyService.appendEvents(user.id, attemptId, submissionId, energyDecision.mutations)
        repository.recordAnswerOnAttempt(attemptId, correct, statusAfter, now)
        repository.appendAttemptEvent(
            attemptId,
            submissionId,
            "ANSWER_RECORDED",
            json(
                mapOf(
                    "questionRevisionId" to questionRevisionId,
                    "correct" to correct,
                    "activeScoreDelta" to appliedScore.change.activeDelta,
                    "lifetimeScoreDelta" to appliedScore.change.lifetimeDelta,
                    "energyBalance" to energyDecision.snapshot.balance,
                ),
            ),
            now,
        )
        if (energyDecision.interrupted) {
            repository.appendAttemptEvent(attemptId, submissionId, "INTERRUPTED_ENERGY", json(emptyMap()), now)
        }
        outboxRepository.append(
            "test-attempt",
            attemptId,
            "learning.answer-recorded.v1",
            mapOf(
                "userId" to user.id,
                "courseId" to attempt.courseId,
                "questionRevisionId" to questionRevisionId,
                "submissionId" to submissionId,
                "correct" to correct,
                "activeScoreDelta" to appliedScore.change.activeDelta,
                "lifetimeScoreDelta" to appliedScore.change.lifetimeDelta,
                "energyBalance" to energyDecision.snapshot.balance,
                "attemptStatus" to statusAfter,
            ),
        )
        idempotencyService.record(
            user.id,
            "learning.submit-answer",
            idempotencyKey,
            lookup.fingerprint,
            submissionId,
        )
        return result(stored, repository.findCorrectOptionId(questionRevisionId))
    }

    @Transactional
    fun finishAttempt(
        user: AppUser,
        attemptId: UUID,
        idempotencyKey: UUID,
    ): FinishAttemptResult {
        val lookup = idempotencyService.lockAndFind(
            user.id,
            "learning.finish-attempt",
            idempotencyKey,
            attemptId.toString(),
        )
        lookup.resourceId?.let {
            if (it != attemptId) {
                throw ConflictProblem("Idempotency-Key refers to another attempt.")
            }
        }
        val attempt = repository.lockAttempt(attemptId, user.id)
            ?: throw NotFoundProblem("Attempt was not found.")
        if (attempt.status == "COMPLETED_PASS" || attempt.status == "COMPLETED_FAIL") {
            if (lookup.resourceId == null) {
                idempotencyService.record(
                    user.id,
                    "learning.finish-attempt",
                    idempotencyKey,
                    lookup.fingerprint,
                    attemptId,
                )
            }
            return finishedResult(attempt)
        }
        if (attempt.status == "INTERRUPTED_ENERGY") {
            throw ConflictProblem("An energy-interrupted attempt cannot be completed.")
        }
        val factCount = repository.countAnswerFacts(attemptId)
        if (factCount != attempt.totalQuestions || attempt.answeredCount != attempt.totalQuestions) {
            throw ConflictProblem("Every question must be answered before finishing the attempt.")
        }

        val ratio = ratio(attempt.correctCount, attempt.totalQuestions)
        val status = if (ratio >= attempt.passThreshold) "COMPLETED_PASS" else "COMPLETED_FAIL"
        val now = now()
        repository.completeAttempt(attemptId, status, now)
        val zone = runCatching { ZoneId.of(user.timeZone) }.getOrDefault(ZoneOffset.UTC)
        repository.recordStreakDay(user.id, now.atZoneSameInstant(zone).toLocalDate(), zone.id, attemptId, now)
        repository.appendAttemptEvent(
            attemptId,
            null,
            status,
            json(mapOf("correctCount" to attempt.correctCount, "totalQuestions" to attempt.totalQuestions)),
            now,
        )
        outboxRepository.append(
            "test-attempt",
            attemptId,
            "learning.attempt-finished.v1",
            mapOf(
                "userId" to user.id,
                "courseId" to attempt.courseId,
                "status" to status,
                "correctCount" to attempt.correctCount,
                "totalQuestions" to attempt.totalQuestions,
            ),
        )
        idempotencyService.record(
            user.id,
            "learning.finish-attempt",
            idempotencyKey,
            lookup.fingerprint,
            attemptId,
        )
        return FinishAttemptResult(attemptId, status, attempt.correctCount, attempt.totalQuestions, ratio, now)
    }

    private fun replay(
        stored: StoredAnswer,
        user: AppUser,
        attemptId: UUID,
        questionRevisionId: UUID,
        selectedOptionId: UUID,
    ): SubmitAnswerResult {
        if (
            stored.userId != user.id ||
            stored.attemptId != attemptId ||
            stored.questionRevisionId != questionRevisionId ||
            stored.selectedOptionId != selectedOptionId
        ) {
            throw ConflictProblem("submissionId was already used for a different command.")
        }
        return result(stored, repository.findCorrectOptionId(questionRevisionId))
    }

    private fun result(
        stored: StoredAnswer,
        correctOptionId: UUID,
    ) = SubmitAnswerResult(
        submissionId = stored.submissionId,
        correct = stored.correct,
        correctOptionId = correctOptionId,
        activeScoreDelta = stored.activeScoreDelta,
        lifetimeScoreDelta = stored.lifetimeScoreDelta,
        activeQuestionScore = stored.activeQuestionScore,
        lifetimeScore = stored.lifetimeScore,
        energy = EnergySnapshot(
            balance = stored.energyBalanceAfter,
            maximum = 5,
            unlimited = stored.energyUnlimited,
            nextRegenerationAt = stored.energyNextRegenerationAt,
            asOf = stored.submittedAt,
        ),
        attemptStatus = stored.attemptStatusAfter,
    )

    private fun replayStart(
        user: AppUser,
        attemptId: UUID,
    ): StartAttemptResult {
        val attempt = repository.lockAttempt(attemptId, user.id)
            ?: throw ConflictProblem("The idempotent attempt no longer exists.")
        val questions = repository.findManifestQuestions(attemptId).map { question ->
            val options = question.options.toMutableList()
            Collections.shuffle(
                options,
                Random(attempt.shuffleSeed xor question.questionRevisionId.hashCode().toLong()),
            )
            question.copy(options = options)
        }
        return StartAttemptResult(
            attemptId = attempt.id,
            testId = attempt.testId,
            testRevisionId = attempt.testRevisionId,
            status = "IN_PROGRESS",
            questions = questions,
            startedAt = attempt.startedAt,
        )
    }

    private fun finishedResult(attempt: AttemptAggregate): FinishAttemptResult =
        FinishAttemptResult(
            attemptId = attempt.id,
            status = attempt.status,
            correctCount = attempt.correctCount,
            totalQuestions = attempt.totalQuestions,
            correctRatio = ratio(attempt.correctCount, attempt.totalQuestions),
            finishedAt = attempt.finishedAt ?: error("Completed attempt has no finished timestamp"),
        )

    private fun ratio(
        correct: Int,
        total: Int,
    ): BigDecimal = BigDecimal(correct).divide(BigDecimal(total), 4, RoundingMode.HALF_UP)

    private fun now(): OffsetDateTime = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)

    private fun json(payload: Map<String, Any?>): JSONB = JSONB.valueOf(objectMapper.writeValueAsString(payload))
}
