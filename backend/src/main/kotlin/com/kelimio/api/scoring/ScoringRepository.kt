package com.kelimio.api.scoring

import com.kelimio.api.persistence.QuestionMasteries
import com.kelimio.api.persistence.ScoreEvents
import org.jooq.DSLContext
import org.jooq.impl.DSL.coalesce
import org.jooq.impl.DSL.inline
import org.jooq.impl.DSL.sum
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.util.UUID

@Repository
class ScoringRepository(
    private val dsl: DSLContext,
) {
    fun lockUserScore(userId: UUID) {
        dsl.fetch("select pg_advisory_xact_lock(hashtextextended(?, 0))", "score:$userId")
    }

    fun ensureAndLockMastery(
        userId: UUID,
        questionRevisionId: UUID,
        now: OffsetDateTime,
    ): MasteryState {
        dsl.insertInto(QuestionMasteries.TABLE)
            .columns(
                QuestionMasteries.USER_ID,
                QuestionMasteries.QUESTION_REVISION_ID,
                QuestionMasteries.ACTIVE_SCORE,
                QuestionMasteries.ENCOUNTER_COUNT,
                QuestionMasteries.CORRECT_COUNT,
                QuestionMasteries.VERSION,
                QuestionMasteries.LAST_ANSWERED_AT,
            )
            .values(userId, questionRevisionId, 0.toShort(), 0, 0, 0L, now)
            .onConflict(QuestionMasteries.USER_ID, QuestionMasteries.QUESTION_REVISION_ID)
            .doNothing()
            .execute()

        return dsl.select(
            QuestionMasteries.ACTIVE_SCORE,
            QuestionMasteries.ENCOUNTER_COUNT,
            QuestionMasteries.CORRECT_COUNT,
        ).from(QuestionMasteries.TABLE)
            .where(QuestionMasteries.USER_ID.eq(userId))
            .and(QuestionMasteries.QUESTION_REVISION_ID.eq(questionRevisionId))
            .forUpdate()
            .fetchOne {
                MasteryState(
                    activeScore = it.get(QuestionMasteries.ACTIVE_SCORE)!!.toInt(),
                    encounterCount = it.get(QuestionMasteries.ENCOUNTER_COUNT)!!,
                    correctCount = it.get(QuestionMasteries.CORRECT_COUNT)!!,
                )
            } ?: error("Mastery row was not available after initialization")
    }

    fun updateMastery(
        userId: UUID,
        questionRevisionId: UUID,
        state: MasteryState,
        now: OffsetDateTime,
    ) {
        val updated = dsl.update(QuestionMasteries.TABLE)
            .set(QuestionMasteries.ACTIVE_SCORE, state.activeScore.toShort())
            .set(QuestionMasteries.ENCOUNTER_COUNT, state.encounterCount)
            .set(QuestionMasteries.CORRECT_COUNT, state.correctCount)
            .set(QuestionMasteries.VERSION, QuestionMasteries.VERSION.plus(1L))
            .set(QuestionMasteries.LAST_ANSWERED_AT, now)
            .where(QuestionMasteries.USER_ID.eq(userId))
            .and(QuestionMasteries.QUESTION_REVISION_ID.eq(questionRevisionId))
            .execute()
        check(updated == 1) { "Mastery update did not affect exactly one row" }
    }

    fun appendScoreEvent(
        userId: UUID,
        attemptId: UUID,
        submissionId: UUID,
        questionRevisionId: UUID,
        change: ScoreChange,
        now: OffsetDateTime,
    ) {
        dsl.insertInto(ScoreEvents.TABLE)
            .columns(
                ScoreEvents.ID,
                ScoreEvents.USER_ID,
                ScoreEvents.ATTEMPT_ID,
                ScoreEvents.SUBMISSION_ID,
                ScoreEvents.QUESTION_REVISION_ID,
                ScoreEvents.ACTIVE_DELTA,
                ScoreEvents.LIFETIME_DELTA,
                ScoreEvents.OCCURRED_AT,
            )
            .values(
                UUID.randomUUID(),
                userId,
                attemptId,
                submissionId,
                questionRevisionId,
                change.activeDelta.toShort(),
                change.lifetimeDelta.toShort(),
                now,
            )
            .execute()
    }

    fun lifetimeScore(userId: UUID): Long =
        dsl.select(coalesce(sum(ScoreEvents.LIFETIME_DELTA.cast(Long::class.java)), inline(0L)))
            .from(ScoreEvents.TABLE)
            .where(ScoreEvents.USER_ID.eq(userId))
            .fetchOne(0, Long::class.java) ?: 0L
}
