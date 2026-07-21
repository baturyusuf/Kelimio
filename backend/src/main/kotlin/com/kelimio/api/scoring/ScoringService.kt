package com.kelimio.api.scoring

import org.springframework.stereotype.Service
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Service
class ScoringService(
    private val repository: ScoringRepository,
    private val clock: Clock,
) {
    fun applyMastery(
        userId: UUID,
        questionRevisionId: UUID,
        correct: Boolean,
    ): AppliedScore {
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        repository.lockUserScore(userId)
        val current = repository.ensureAndLockMastery(userId, questionRevisionId, now)
        val change = ScoringPolicy.evaluate(current, correct)
        repository.updateMastery(userId, questionRevisionId, change.newState, now)
        return AppliedScore(
            change = change,
            occurredAt = now,
            lifetimeScore = repository.lifetimeScore(userId) + change.lifetimeDelta,
        )
    }

    fun appendEvent(
        userId: UUID,
        attemptId: UUID,
        submissionId: UUID,
        questionRevisionId: UUID,
        applied: AppliedScore,
    ) {
        repository.appendScoreEvent(
            userId,
            attemptId,
            submissionId,
            questionRevisionId,
            applied.change,
            applied.occurredAt,
        )
    }
}

data class AppliedScore(
    val change: ScoreChange,
    val occurredAt: OffsetDateTime,
    val lifetimeScore: Long,
)
