package com.kelimio.api.learningsession

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.catalog.LearningContentQuery
import com.kelimio.api.catalog.LearningQuestionType
import com.kelimio.api.catalog.QuestionOptionSource
import com.kelimio.api.catalog.TypedAnswerSource
import com.kelimio.api.energy.EnergyService
import com.kelimio.api.energy.EnergySnapshot
import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.language.InvalidTypedAnswerException
import com.kelimio.api.language.TypedAnswerPolicy
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
            val valid = when (source.type) {
                LearningQuestionType.WORD_MULTIPLE_CHOICE ->
                    source.typedAnswer == null && source.options.isValidMultipleChoiceOptions()

                LearningQuestionType.MULTIPLE_CHOICE_CLOZE ->
                    source.typedAnswer == null &&
                        source.prompt.hasExactlyOneClozeMarker() &&
                        source.options.isValidMultipleChoiceOptions()

                LearningQuestionType.TYPED_CLOZE ->
                    source.prompt.hasExactlyOneClozeMarker() &&
                        source.options.isEmpty() &&
                        source.typedAnswer?.isValidTypedAnswerMaterial() == true
            }
            if (!valid) {
                throw ConflictProblem("The active test revision contains an invalid question.")
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
                typedAnswer = source.typedAnswer,
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
        answer: SubmittedAnswer,
        idempotencyKey: UUID,
    ): SubmitAnswerResult {
        val lookup = idempotencyService.lockAndFind(
            user.id,
            "learning.submit-answer",
            idempotencyKey,
            structuralAnswerFingerprint(attemptId, submissionId, questionRevisionId, answer),
        )
        lookup.resourceId?.let { resourceId ->
            val stored = repository.findAnswerBySubmissionId(resourceId)
                ?: throw ConflictProblem("The idempotent answer fact no longer exists.")
            return replay(stored, user, attemptId, questionRevisionId, answer)
        }
        repository.findAnswerBySubmissionId(submissionId)?.let {
            val response = replay(it, user, attemptId, questionRevisionId, answer)
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
            val response = replay(it, user, attemptId, questionRevisionId, answer)
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
        repository.findAnswerForQuestion(attemptId, questionRevisionId)?.let {
            throw ConflictProblem("The question was already answered with another submissionId.")
        }

        val evaluation = evaluateAnswer(attemptId, submissionId, manifestQuestion, answer)
        val correct = evaluation.correct
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
            answerKind = evaluation.answerKind,
            selectedOptionId = evaluation.selectedOptionId,
            typedAnswerSalt = evaluation.typedAnswerSalt,
            typedAnswerDigest = evaluation.typedAnswerDigest,
            typedMatchOrdinal = evaluation.typedMatchOrdinal,
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
        return result(stored)
    }

    @Transactional(readOnly = true)
    fun getRecordedAnswer(
        user: AppUser,
        attemptId: UUID,
        submissionId: UUID,
    ): SubmitAnswerResult {
        val stored = repository.findAnswerForOwner(attemptId, submissionId, user.id)
            ?: throw NotFoundProblem("Recorded answer was not found.")
        return result(stored)
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
        answer: SubmittedAnswer,
    ): SubmitAnswerResult {
        if (
            stored.userId != user.id ||
            stored.attemptId != attemptId ||
            stored.questionRevisionId != questionRevisionId ||
            !answerMatchesStored(stored, answer)
        ) {
            throw ConflictProblem("submissionId was already used for a different command.")
        }
        return result(stored)
    }

    private fun result(stored: StoredAnswer) = SubmitAnswerResult(
        submissionId = stored.submissionId,
        correct = stored.correct,
        correctOptionId = if (stored.answerKind == ANSWER_KIND_OPTION) {
            repository.findCorrectOptionId(stored.questionRevisionId)
        } else {
            null
        },
        correctAnswerText = if (stored.answerKind == ANSWER_KIND_TYPED_TEXT) {
            repository.findPrimaryCorrectAnswer(stored.questionRevisionId)
        } else {
            null
        },
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

    private fun answerMatchesStored(
        stored: StoredAnswer,
        answer: SubmittedAnswer,
    ): Boolean =
        when (answer) {
            is SubmittedAnswer.Option ->
                stored.answerKind == ANSWER_KIND_OPTION &&
                    stored.selectedOptionId == answer.selectedOptionId

            is SubmittedAnswer.TypedText -> {
                if (stored.answerKind != ANSWER_KIND_TYPED_TEXT) return false
                val salt = stored.typedAnswerSalt ?: return false
                val expectedDigest = stored.typedAnswerDigest ?: return false
                val material = repository.findManifestQuestion(stored.attemptId, stored.questionRevisionId)
                    ?.typedAnswer ?: return false
                val canonical = try {
                    TypedAnswerPolicy.canonicalize(
                        answer.value,
                        material.languageTag,
                        material.policyVersion,
                    )
                } catch (_: InvalidTypedAnswerException) {
                    return false
                }
                val actualDigest = TypedAnswerReplayDigest.compute(
                    salt,
                    stored.attemptId,
                    stored.submissionId,
                    stored.questionRevisionId,
                    material.policyVersion,
                    canonical,
                )
                TypedAnswerReplayDigest.matches(expectedDigest, actualDigest)
            }
        }

    private fun evaluateAnswer(
        attemptId: UUID,
        submissionId: UUID,
        question: ManifestQuestion,
        answer: SubmittedAnswer,
    ): AnswerEvaluation =
        when (answer) {
            is SubmittedAnswer.Option -> {
                if (question.type == LearningQuestionType.TYPED_CLOZE) {
                    throw UnprocessableProblem("The submitted answer form does not match the question.")
                }
                val selectedOption = repository.findOption(question.questionRevisionId, answer.selectedOptionId)
                    ?: throw UnprocessableProblem("The selected option does not belong to the question.")
                AnswerEvaluation(
                    answerKind = ANSWER_KIND_OPTION,
                    selectedOptionId = answer.selectedOptionId,
                    typedAnswerSalt = null,
                    typedAnswerDigest = null,
                    typedMatchOrdinal = null,
                    correct = selectedOption.correct,
                )
            }

            is SubmittedAnswer.TypedText -> {
                if (question.type != LearningQuestionType.TYPED_CLOZE) {
                    throw UnprocessableProblem("The submitted answer form does not match the question.")
                }
                val material = question.typedAnswer
                    ?: throw ConflictProblem("The active question revision is invalid.")
                val canonical = try {
                    TypedAnswerPolicy.canonicalize(
                        answer.value,
                        material.languageTag,
                        material.policyVersion,
                    )
                } catch (_: InvalidTypedAnswerException) {
                    throw UnprocessableProblem("The typed answer is invalid.")
                }
                val matchOrdinal = when (canonical) {
                    material.primaryMatchKey -> TYPED_MATCH_PRIMARY
                    material.alternativeMatchKey -> TYPED_MATCH_ALTERNATIVE
                    else -> TYPED_MATCH_NONE
                }
                val salt = ByteArray(TypedAnswerReplayDigest.SALT_BYTES).also(secureRandom::nextBytes)
                AnswerEvaluation(
                    answerKind = ANSWER_KIND_TYPED_TEXT,
                    selectedOptionId = null,
                    typedAnswerSalt = salt,
                    typedAnswerDigest = TypedAnswerReplayDigest.compute(
                        salt,
                        attemptId,
                        submissionId,
                        question.questionRevisionId,
                        material.policyVersion,
                        canonical,
                    ),
                    typedMatchOrdinal = matchOrdinal,
                    correct = matchOrdinal != TYPED_MATCH_NONE,
                )
            }
        }

    private fun structuralAnswerFingerprint(
        attemptId: UUID,
        submissionId: UUID,
        questionRevisionId: UUID,
        answer: SubmittedAnswer,
    ): String =
        when (answer) {
            is SubmittedAnswer.Option ->
                "$attemptId|$submissionId|$questionRevisionId|$ANSWER_KIND_OPTION|${answer.selectedOptionId}"

            is SubmittedAnswer.TypedText ->
                "$attemptId|$submissionId|$questionRevisionId|$ANSWER_KIND_TYPED_TEXT"
        }

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

    private fun String.hasExactlyOneClozeMarker(): Boolean =
        windowed(CLOZE_MARKER.length).count { it == CLOZE_MARKER } == 1

    private fun List<QuestionOptionSource>.isValidMultipleChoiceOptions(): Boolean =
        size == 4 && count { it.correct } == 1

    private fun TypedAnswerSource.isValidTypedAnswerMaterial(): Boolean =
        try {
            val primaryKey = TypedAnswerPolicy.canonicalize(primaryAnswerText, languageTag, policyVersion)
            val alternativeKey = alternativeAnswerText?.let { answer ->
                TypedAnswerPolicy.canonicalize(answer, languageTag, policyVersion)
            }
            primaryKey == primaryMatchKey &&
                alternativeKey == alternativeMatchKey &&
                (alternativeKey == null || alternativeKey != primaryKey)
        } catch (_: InvalidTypedAnswerException) {
            false
        }

    private data class AnswerEvaluation(
        val answerKind: String,
        val selectedOptionId: UUID?,
        val typedAnswerSalt: ByteArray?,
        val typedAnswerDigest: ByteArray?,
        val typedMatchOrdinal: Int?,
        val correct: Boolean,
    )

    private companion object {
        const val CLOZE_MARKER = "---"
        const val ANSWER_KIND_OPTION = "OPTION"
        const val ANSWER_KIND_TYPED_TEXT = "TYPED_TEXT"
        const val TYPED_MATCH_NONE = 0
        const val TYPED_MATCH_PRIMARY = 1
        const val TYPED_MATCH_ALTERNATIVE = 2
    }
}
