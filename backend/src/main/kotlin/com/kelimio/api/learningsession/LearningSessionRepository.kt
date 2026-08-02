package com.kelimio.api.learningsession

import com.kelimio.api.catalog.LearningQuestionType
import com.kelimio.api.catalog.MatchingPairSource
import com.kelimio.api.catalog.MatchingQuestionSource
import com.kelimio.api.catalog.TypedAnswerSource
import com.kelimio.api.persistence.AnswerSubmissions
import com.kelimio.api.persistence.AttemptEvents
import com.kelimio.api.persistence.AttemptManifest
import com.kelimio.api.persistence.Attempts
import com.kelimio.api.persistence.QuestionRevisionOptions
import com.kelimio.api.persistence.QuestionRevisionMatchingPairs
import com.kelimio.api.persistence.QuestionRevisionMatchingTranslations
import com.kelimio.api.persistence.QuestionRevisions
import com.kelimio.api.persistence.StreakDays
import com.kelimio.api.persistence.TestRevisions
import org.jooq.DSLContext
import org.jooq.JSONB
import org.springframework.stereotype.Repository
import java.math.BigDecimal
import java.time.LocalDate
import java.time.OffsetDateTime
import java.util.UUID

@Repository
class LearningSessionRepository(
    private val dsl: DSLContext,
) {
    fun createAttempt(
        attemptId: UUID,
        userId: UUID,
        courseId: UUID,
        courseReleaseId: UUID,
        courseAccessType: String,
        testRevisionId: UUID,
        supportLanguage: String,
        shuffleSeed: Long,
        totalQuestions: Int,
        now: OffsetDateTime,
    ) {
        dsl.insertInto(Attempts.TABLE)
            .columns(
                Attempts.ID,
                Attempts.USER_ID,
                Attempts.COURSE_ID,
                Attempts.COURSE_RELEASE_ID,
                Attempts.COURSE_ACCESS_TYPE,
                Attempts.TEST_REVISION_ID,
                Attempts.SUPPORT_LANGUAGE,
                Attempts.STATUS,
                Attempts.SHUFFLE_SEED,
                Attempts.TOTAL_QUESTIONS,
                Attempts.ANSWERED_COUNT,
                Attempts.CORRECT_COUNT,
                Attempts.STARTED_AT,
                Attempts.VERSION,
            )
            .values(
                attemptId,
                userId,
                courseId,
                courseReleaseId,
                courseAccessType,
                testRevisionId,
                supportLanguage,
                "IN_PROGRESS",
                shuffleSeed,
                totalQuestions,
                0,
                0,
                now,
                0L,
            )
            .execute()
    }

    fun addManifestQuestion(
        attemptId: UUID,
        testRevisionId: UUID,
        courseId: UUID,
        questionRevisionId: UUID,
        position: Int,
    ) {
        dsl.insertInto(AttemptManifest.TABLE)
            .columns(
                AttemptManifest.ATTEMPT_ID,
                AttemptManifest.TEST_REVISION_ID,
                AttemptManifest.COURSE_ID,
                AttemptManifest.QUESTION_REVISION_ID,
                AttemptManifest.POSITION,
            )
            .values(attemptId, testRevisionId, courseId, questionRevisionId, position)
            .execute()
    }

    fun lockAttempt(
        attemptId: UUID,
        userId: UUID,
    ): AttemptAggregate? =
        dsl.select(
            Attempts.ID,
            Attempts.USER_ID,
            Attempts.COURSE_ID,
            Attempts.COURSE_RELEASE_ID,
            Attempts.TEST_REVISION_ID,
            TestRevisions.TEST_ID,
            Attempts.STATUS,
            Attempts.TOTAL_QUESTIONS,
            Attempts.ANSWERED_COUNT,
            Attempts.CORRECT_COUNT,
            Attempts.COURSE_ACCESS_TYPE,
            Attempts.SUPPORT_LANGUAGE,
            TestRevisions.PASS_THRESHOLD,
            Attempts.STARTED_AT,
            Attempts.FINISHED_AT,
            Attempts.SHUFFLE_SEED,
        ).from(Attempts.TABLE)
            .join(TestRevisions.TABLE)
            .on(TestRevisions.ID.eq(Attempts.TEST_REVISION_ID))
            .where(Attempts.ID.eq(attemptId))
            .and(Attempts.USER_ID.eq(userId))
            .forUpdate()
            .fetchOne {
                AttemptAggregate(
                    id = it.get(Attempts.ID)!!,
                    userId = it.get(Attempts.USER_ID)!!,
                    courseId = it.get(Attempts.COURSE_ID)!!,
                    testRevisionId = it.get(Attempts.TEST_REVISION_ID)!!,
                    testId = it.get(TestRevisions.TEST_ID)!!,
                    status = it.get(Attempts.STATUS)!!,
                    totalQuestions = it.get(Attempts.TOTAL_QUESTIONS)!!,
                    answeredCount = it.get(Attempts.ANSWERED_COUNT)!!,
                    correctCount = it.get(Attempts.CORRECT_COUNT)!!,
                    courseAccessType = it.get(Attempts.COURSE_ACCESS_TYPE)!!,
                    supportLanguage = it.get(Attempts.SUPPORT_LANGUAGE)!!,
                    passThreshold = it.get(TestRevisions.PASS_THRESHOLD)!!,
                    startedAt = it.get(Attempts.STARTED_AT)!!,
                    finishedAt = it.get(Attempts.FINISHED_AT),
                    shuffleSeed = it.get(Attempts.SHUFFLE_SEED)!!,
                )
            }

    fun findManifestQuestion(
        attemptId: UUID,
        questionRevisionId: UUID,
    ): ManifestQuestion? =
        dsl.select(
            QuestionRevisions.QUESTION_ID,
            QuestionRevisions.ID,
            QuestionRevisions.TYPE,
            QuestionRevisions.PROMPT,
            QuestionRevisions.CORRECT_ANSWER,
            QuestionRevisions.ALTERNATIVE_CORRECT_ANSWER,
            QuestionRevisions.ANSWER_MATCH_POLICY,
            QuestionRevisions.ANSWER_MATCH_LANGUAGE,
            QuestionRevisions.CORRECT_ANSWER_MATCH_KEY,
            QuestionRevisions.ALTERNATIVE_ANSWER_MATCH_KEY,
            QuestionRevisions.MATCHING_POLICY,
            QuestionRevisions.MATCHING_LABEL_POLICY,
            QuestionRevisions.MATCHING_ORDER_POLICY,
            QuestionRevisions.MATCHING_TARGET_LANGUAGE,
            Attempts.SUPPORT_LANGUAGE,
            AttemptManifest.POSITION,
        ).from(AttemptManifest.TABLE)
            .join(QuestionRevisions.TABLE)
            .on(QuestionRevisions.ID.eq(AttemptManifest.QUESTION_REVISION_ID))
            .join(Attempts.TABLE)
            .on(Attempts.ID.eq(AttemptManifest.ATTEMPT_ID))
            .where(AttemptManifest.ATTEMPT_ID.eq(attemptId))
            .and(AttemptManifest.QUESTION_REVISION_ID.eq(questionRevisionId))
            .fetchOne {
                val type = LearningQuestionType.fromStorageCode(it.get(QuestionRevisions.TYPE)!!)
                ManifestQuestion(
                    questionId = it.get(QuestionRevisions.QUESTION_ID)!!,
                    questionRevisionId = it.get(QuestionRevisions.ID)!!,
                    type = type,
                    prompt = it.get(QuestionRevisions.PROMPT),
                    options = findOptions(questionRevisionId),
                    typedAnswer = mapTypedAnswer(it, type),
                    matching = mapMatchingAnswer(
                        it,
                        type,
                        questionRevisionId,
                        it.get(Attempts.SUPPORT_LANGUAGE)!!,
                    ),
                    targetItems = emptyList(),
                    supportItems = emptyList(),
                    supportLanguage = it.get(Attempts.SUPPORT_LANGUAGE)!!,
                    position = it.get(AttemptManifest.POSITION)!!,
                )
            }

    fun findManifestQuestions(attemptId: UUID): List<ManifestQuestion> =
        dsl.select(
            QuestionRevisions.QUESTION_ID,
            QuestionRevisions.ID,
            QuestionRevisions.TYPE,
            QuestionRevisions.PROMPT,
            QuestionRevisions.CORRECT_ANSWER,
            QuestionRevisions.ALTERNATIVE_CORRECT_ANSWER,
            QuestionRevisions.ANSWER_MATCH_POLICY,
            QuestionRevisions.ANSWER_MATCH_LANGUAGE,
            QuestionRevisions.CORRECT_ANSWER_MATCH_KEY,
            QuestionRevisions.ALTERNATIVE_ANSWER_MATCH_KEY,
            QuestionRevisions.MATCHING_POLICY,
            QuestionRevisions.MATCHING_LABEL_POLICY,
            QuestionRevisions.MATCHING_ORDER_POLICY,
            QuestionRevisions.MATCHING_TARGET_LANGUAGE,
            Attempts.SUPPORT_LANGUAGE,
            AttemptManifest.POSITION,
        ).from(AttemptManifest.TABLE)
            .join(QuestionRevisions.TABLE)
            .on(QuestionRevisions.ID.eq(AttemptManifest.QUESTION_REVISION_ID))
            .join(Attempts.TABLE)
            .on(Attempts.ID.eq(AttemptManifest.ATTEMPT_ID))
            .where(AttemptManifest.ATTEMPT_ID.eq(attemptId))
            .orderBy(AttemptManifest.POSITION.asc())
            .fetch {
                val revisionId = it.get(QuestionRevisions.ID)!!
                val type = LearningQuestionType.fromStorageCode(it.get(QuestionRevisions.TYPE)!!)
                ManifestQuestion(
                    questionId = it.get(QuestionRevisions.QUESTION_ID)!!,
                    questionRevisionId = revisionId,
                    type = type,
                    prompt = it.get(QuestionRevisions.PROMPT),
                    options = findOptions(revisionId),
                    typedAnswer = mapTypedAnswer(it, type),
                    matching = mapMatchingAnswer(
                        it,
                        type,
                        revisionId,
                        it.get(Attempts.SUPPORT_LANGUAGE)!!,
                    ),
                    targetItems = emptyList(),
                    supportItems = emptyList(),
                    supportLanguage = it.get(Attempts.SUPPORT_LANGUAGE)!!,
                    position = it.get(AttemptManifest.POSITION)!!,
                )
            }

    fun findOption(
        questionRevisionId: UUID,
        optionId: UUID,
    ): ManifestOption? =
        dsl.select(
            QuestionRevisionOptions.ID,
            QuestionRevisionOptions.TEXT,
            QuestionRevisionOptions.IS_CORRECT,
            QuestionRevisionOptions.POSITION,
        ).from(QuestionRevisionOptions.TABLE)
            .where(QuestionRevisionOptions.QUESTION_REVISION_ID.eq(questionRevisionId))
            .and(QuestionRevisionOptions.ID.eq(optionId))
            .fetchOne {
                ManifestOption(
                    id = it.get(QuestionRevisionOptions.ID)!!,
                    text = it.get(QuestionRevisionOptions.TEXT)!!,
                    correct = it.get(QuestionRevisionOptions.IS_CORRECT)!!,
                    position = it.get(QuestionRevisionOptions.POSITION)!!,
                )
            }

    fun findCorrectOptionId(questionRevisionId: UUID): UUID =
        dsl.select(QuestionRevisionOptions.ID)
            .from(QuestionRevisionOptions.TABLE)
            .where(QuestionRevisionOptions.QUESTION_REVISION_ID.eq(questionRevisionId))
            .and(QuestionRevisionOptions.IS_CORRECT.isTrue)
            .fetchOne(QuestionRevisionOptions.ID)
            ?: error("Question revision has no correct option")

    fun findPrimaryCorrectAnswer(questionRevisionId: UUID): String =
        dsl.select(QuestionRevisions.CORRECT_ANSWER)
            .from(QuestionRevisions.TABLE)
            .where(QuestionRevisions.ID.eq(questionRevisionId))
            .and(QuestionRevisions.TYPE.eq(LearningQuestionType.TYPED_CLOZE.storageCode))
            .fetchOne(QuestionRevisions.CORRECT_ANSWER)
            ?: error("Typed-cloze revision has no primary correct answer")

    fun findAnswerBySubmissionId(submissionId: UUID): StoredAnswer? =
        answerSelect()
            .where(AnswerSubmissions.SUBMISSION_ID.eq(submissionId))
            .fetchOne { mapAnswer(it) }

    fun findAnswerForOwner(
        attemptId: UUID,
        submissionId: UUID,
        userId: UUID,
    ): StoredAnswer? =
        answerSelect()
            .where(AnswerSubmissions.ATTEMPT_ID.eq(attemptId))
            .and(AnswerSubmissions.SUBMISSION_ID.eq(submissionId))
            .and(AnswerSubmissions.USER_ID.eq(userId))
            .fetchOne { mapAnswer(it) }

    fun findAnswerForQuestion(
        attemptId: UUID,
        questionRevisionId: UUID,
    ): StoredAnswer? =
        answerSelect()
            .where(AnswerSubmissions.ATTEMPT_ID.eq(attemptId))
            .and(AnswerSubmissions.QUESTION_REVISION_ID.eq(questionRevisionId))
            .fetchOne { mapAnswer(it) }

    fun insertAnswer(
        result: StoredAnswer,
    ) {
        dsl.insertInto(AnswerSubmissions.TABLE)
            .columns(
                AnswerSubmissions.SUBMISSION_ID,
                AnswerSubmissions.ATTEMPT_ID,
                AnswerSubmissions.USER_ID,
                AnswerSubmissions.QUESTION_REVISION_ID,
                AnswerSubmissions.SELECTED_OPTION_ID,
                AnswerSubmissions.ANSWER_KIND,
                AnswerSubmissions.TYPED_ANSWER_SALT,
                AnswerSubmissions.TYPED_ANSWER_DIGEST,
                AnswerSubmissions.TYPED_MATCH_ORDINAL,
                AnswerSubmissions.MATCHING_ANSWER_SALT,
                AnswerSubmissions.MATCHING_ANSWER_DIGEST,
                AnswerSubmissions.MATCHING_REPLAY_KEY_VERSION,
                AnswerSubmissions.IS_CORRECT,
                AnswerSubmissions.ACTIVE_DELTA,
                AnswerSubmissions.LIFETIME_DELTA,
                AnswerSubmissions.ACTIVE_QUESTION_SCORE,
                AnswerSubmissions.LIFETIME_SCORE,
                AnswerSubmissions.ENERGY_AFTER,
                AnswerSubmissions.ENERGY_UNLIMITED,
                AnswerSubmissions.ENERGY_NEXT_REGENERATION_AT,
                AnswerSubmissions.ATTEMPT_STATUS_AFTER,
                AnswerSubmissions.SUBMITTED_AT,
            )
            .values(
                result.submissionId,
                result.attemptId,
                result.userId,
                result.questionRevisionId,
                result.selectedOptionId,
                result.answerKind,
                result.typedAnswerSalt,
                result.typedAnswerDigest,
                result.typedMatchOrdinal?.toShort(),
                result.matchingAnswerSalt,
                result.matchingAnswerDigest,
                result.matchingReplayKeyVersion,
                result.correct,
                result.activeScoreDelta.toShort(),
                result.lifetimeScoreDelta.toShort(),
                result.activeQuestionScore.toShort(),
                result.lifetimeScore,
                result.energyBalanceAfter.toShort(),
                result.energyUnlimited,
                result.energyNextRegenerationAt,
                result.attemptStatusAfter,
                result.submittedAt,
            )
            .execute()
    }

    fun recordAnswerOnAttempt(
        attemptId: UUID,
        correct: Boolean,
        statusAfter: String,
        now: OffsetDateTime,
    ) {
        val update = dsl.update(Attempts.TABLE)
            .set(Attempts.ANSWERED_COUNT, Attempts.ANSWERED_COUNT.plus(1))
            .set(Attempts.CORRECT_COUNT, Attempts.CORRECT_COUNT.plus(if (correct) 1 else 0))
            .set(Attempts.STATUS, statusAfter)
            .set(Attempts.VERSION, Attempts.VERSION.plus(1L))
        if (statusAfter == "INTERRUPTED_ENERGY") {
            update.set(Attempts.FINISHED_AT, now)
        }
        check(update.where(Attempts.ID.eq(attemptId)).execute() == 1) {
            "Attempt answer update did not affect exactly one row"
        }
    }

    fun countAnswerFacts(attemptId: UUID): Int =
        dsl.selectCount()
            .from(AnswerSubmissions.TABLE)
            .where(AnswerSubmissions.ATTEMPT_ID.eq(attemptId))
            .fetchOne(0, Int::class.java) ?: 0

    fun completeAttempt(
        attemptId: UUID,
        status: String,
        now: OffsetDateTime,
    ) {
        val updated = dsl.update(Attempts.TABLE)
            .set(Attempts.STATUS, status)
            .set(Attempts.FINISHED_AT, now)
            .set(Attempts.VERSION, Attempts.VERSION.plus(1L))
            .where(Attempts.ID.eq(attemptId))
            .and(Attempts.STATUS.eq("IN_PROGRESS"))
            .execute()
        check(updated == 1) { "Attempt completion did not affect exactly one row" }
    }

    fun appendAttemptEvent(
        attemptId: UUID,
        submissionId: UUID?,
        eventType: String,
        payload: JSONB,
        now: OffsetDateTime,
    ) {
        dsl.insertInto(AttemptEvents.TABLE)
            .columns(
                AttemptEvents.ID,
                AttemptEvents.ATTEMPT_ID,
                AttemptEvents.SUBMISSION_ID,
                AttemptEvents.EVENT_TYPE,
                AttemptEvents.PAYLOAD,
                AttemptEvents.OCCURRED_AT,
            )
            .values(UUID.randomUUID(), attemptId, submissionId, eventType, payload, now)
            .execute()
    }

    fun recordStreakDay(
        userId: UUID,
        localDate: LocalDate,
        timeZone: String,
        attemptId: UUID,
        now: OffsetDateTime,
    ) {
        dsl.insertInto(StreakDays.TABLE)
            .columns(
                StreakDays.USER_ID,
                StreakDays.LOCAL_DATE,
                StreakDays.TIME_ZONE,
                StreakDays.ATTEMPT_ID,
                StreakDays.CREATED_AT,
            )
            .values(userId, localDate, timeZone, attemptId, now)
            .onConflict(StreakDays.USER_ID, StreakDays.LOCAL_DATE)
            .doNothing()
            .execute()
    }

    private fun findOptions(questionRevisionId: UUID): List<ManifestOption> =
        dsl.select(
            QuestionRevisionOptions.ID,
            QuestionRevisionOptions.TEXT,
            QuestionRevisionOptions.IS_CORRECT,
            QuestionRevisionOptions.POSITION,
        ).from(QuestionRevisionOptions.TABLE)
            .where(QuestionRevisionOptions.QUESTION_REVISION_ID.eq(questionRevisionId))
            .orderBy(QuestionRevisionOptions.POSITION.asc())
            .fetch {
                ManifestOption(
                    id = it.get(QuestionRevisionOptions.ID)!!,
                    text = it.get(QuestionRevisionOptions.TEXT)!!,
                    correct = it.get(QuestionRevisionOptions.IS_CORRECT)!!,
                    position = it.get(QuestionRevisionOptions.POSITION)!!,
                )
            }

    private fun answerSelect() =
        dsl.select(
            AnswerSubmissions.SUBMISSION_ID,
            AnswerSubmissions.ATTEMPT_ID,
            AnswerSubmissions.USER_ID,
            AnswerSubmissions.QUESTION_REVISION_ID,
            AnswerSubmissions.SELECTED_OPTION_ID,
            AnswerSubmissions.ANSWER_KIND,
            AnswerSubmissions.TYPED_ANSWER_SALT,
            AnswerSubmissions.TYPED_ANSWER_DIGEST,
            AnswerSubmissions.TYPED_MATCH_ORDINAL,
            AnswerSubmissions.MATCHING_ANSWER_SALT,
            AnswerSubmissions.MATCHING_ANSWER_DIGEST,
            AnswerSubmissions.MATCHING_REPLAY_KEY_VERSION,
            AnswerSubmissions.IS_CORRECT,
            AnswerSubmissions.ACTIVE_DELTA,
            AnswerSubmissions.LIFETIME_DELTA,
            AnswerSubmissions.ACTIVE_QUESTION_SCORE,
            AnswerSubmissions.LIFETIME_SCORE,
            AnswerSubmissions.ENERGY_AFTER,
            AnswerSubmissions.ENERGY_UNLIMITED,
            AnswerSubmissions.ENERGY_NEXT_REGENERATION_AT,
            AnswerSubmissions.ATTEMPT_STATUS_AFTER,
            AnswerSubmissions.SUBMITTED_AT,
        ).from(AnswerSubmissions.TABLE)

    private fun mapAnswer(record: org.jooq.Record): StoredAnswer =
        StoredAnswer(
            submissionId = record.get(AnswerSubmissions.SUBMISSION_ID)!!,
            attemptId = record.get(AnswerSubmissions.ATTEMPT_ID)!!,
            userId = record.get(AnswerSubmissions.USER_ID)!!,
            questionRevisionId = record.get(AnswerSubmissions.QUESTION_REVISION_ID)!!,
            answerKind = record.get(AnswerSubmissions.ANSWER_KIND)!!,
            selectedOptionId = record.get(AnswerSubmissions.SELECTED_OPTION_ID),
            typedAnswerSalt = record.get(AnswerSubmissions.TYPED_ANSWER_SALT),
            typedAnswerDigest = record.get(AnswerSubmissions.TYPED_ANSWER_DIGEST),
            typedMatchOrdinal = record.get(AnswerSubmissions.TYPED_MATCH_ORDINAL)?.toInt(),
            matchingAnswerSalt = record.get(AnswerSubmissions.MATCHING_ANSWER_SALT),
            matchingAnswerDigest = record.get(AnswerSubmissions.MATCHING_ANSWER_DIGEST),
            matchingReplayKeyVersion = record.get(AnswerSubmissions.MATCHING_REPLAY_KEY_VERSION),
            correct = record.get(AnswerSubmissions.IS_CORRECT)!!,
            activeScoreDelta = record.get(AnswerSubmissions.ACTIVE_DELTA)!!.toInt(),
            lifetimeScoreDelta = record.get(AnswerSubmissions.LIFETIME_DELTA)!!.toInt(),
            activeQuestionScore = record.get(AnswerSubmissions.ACTIVE_QUESTION_SCORE)!!.toInt(),
            lifetimeScore = record.get(AnswerSubmissions.LIFETIME_SCORE)!!,
            energyBalanceAfter = record.get(AnswerSubmissions.ENERGY_AFTER)!!.toInt(),
            energyUnlimited = record.get(AnswerSubmissions.ENERGY_UNLIMITED)!!,
            energyNextRegenerationAt = record.get(AnswerSubmissions.ENERGY_NEXT_REGENERATION_AT),
            attemptStatusAfter = record.get(AnswerSubmissions.ATTEMPT_STATUS_AFTER)!!,
            submittedAt = record.get(AnswerSubmissions.SUBMITTED_AT)!!,
        )

    private fun mapTypedAnswer(
        record: org.jooq.Record,
        type: LearningQuestionType,
    ): TypedAnswerSource? =
        if (type == LearningQuestionType.TYPED_CLOZE) {
            TypedAnswerSource(
                primaryAnswerText = record.get(QuestionRevisions.CORRECT_ANSWER)!!,
                alternativeAnswerText = record.get(QuestionRevisions.ALTERNATIVE_CORRECT_ANSWER),
                policyVersion = record.get(QuestionRevisions.ANSWER_MATCH_POLICY)!!,
                languageTag = record.get(QuestionRevisions.ANSWER_MATCH_LANGUAGE)!!,
                primaryMatchKey = record.get(QuestionRevisions.CORRECT_ANSWER_MATCH_KEY)!!,
                alternativeMatchKey = record.get(QuestionRevisions.ALTERNATIVE_ANSWER_MATCH_KEY),
            )
        } else {
            null
        }

    private fun mapMatchingAnswer(
        record: org.jooq.Record,
        type: LearningQuestionType,
        questionRevisionId: UUID,
        supportLanguage: String,
    ): MatchingQuestionSource? =
        if (type == LearningQuestionType.MATCHING) {
            MatchingQuestionSource(
                policyVersion = record.get(QuestionRevisions.MATCHING_POLICY)!!,
                labelPolicyVersion = record.get(QuestionRevisions.MATCHING_LABEL_POLICY)!!,
                orderPolicyVersion = record.get(QuestionRevisions.MATCHING_ORDER_POLICY)!!,
                targetLanguage = record.get(QuestionRevisions.MATCHING_TARGET_LANGUAGE)!!,
                pairs = findMatchingPairs(questionRevisionId, supportLanguage),
            )
        } else {
            null
        }

    private fun findMatchingPairs(
        questionRevisionId: UUID,
        supportLanguage: String,
    ): List<MatchingPairSource> =
        dsl.select(
            QuestionRevisionMatchingPairs.TARGET_ITEM_ID,
            QuestionRevisionMatchingPairs.TARGET_TEXT,
            QuestionRevisionMatchingTranslations.SUPPORT_ITEM_ID,
            QuestionRevisionMatchingTranslations.SUPPORT_TEXT,
            QuestionRevisionMatchingPairs.POSITION,
        ).from(QuestionRevisionMatchingPairs.TABLE)
            .join(QuestionRevisionMatchingTranslations.TABLE)
            .on(
                QuestionRevisionMatchingTranslations.QUESTION_REVISION_ID
                    .eq(QuestionRevisionMatchingPairs.QUESTION_REVISION_ID),
            )
            .and(
                QuestionRevisionMatchingTranslations.TARGET_ITEM_ID
                    .eq(QuestionRevisionMatchingPairs.TARGET_ITEM_ID),
            )
            .and(QuestionRevisionMatchingTranslations.COURSE_ID.eq(QuestionRevisionMatchingPairs.COURSE_ID))
            .where(QuestionRevisionMatchingPairs.QUESTION_REVISION_ID.eq(questionRevisionId))
            .and(QuestionRevisionMatchingTranslations.SUPPORT_LANGUAGE.eq(supportLanguage))
            .orderBy(QuestionRevisionMatchingPairs.POSITION.asc())
            .fetch {
                MatchingPairSource(
                    targetItemId = it.get(QuestionRevisionMatchingPairs.TARGET_ITEM_ID)!!,
                    targetText = it.get(QuestionRevisionMatchingPairs.TARGET_TEXT)!!,
                    supportItemId = it.get(QuestionRevisionMatchingTranslations.SUPPORT_ITEM_ID)!!,
                    supportText = it.get(QuestionRevisionMatchingTranslations.SUPPORT_TEXT)!!,
                    position = it.get(QuestionRevisionMatchingPairs.POSITION)!!,
                )
            }
}
