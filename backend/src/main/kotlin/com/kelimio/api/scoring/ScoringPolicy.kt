package com.kelimio.api.scoring

data class MasteryState(
    val activeScore: Int,
    val encounterCount: Int,
    val correctCount: Int,
)

data class ScoreChange(
    val activeDelta: Int,
    val lifetimeDelta: Int,
    val newState: MasteryState,
)

object ScoringPolicy {
    fun evaluate(
        current: MasteryState,
        correct: Boolean,
    ): ScoreChange {
        require(current.activeScore in setOf(0, 20, 40, 60)) { "Unsupported mastery score" }
        require(current.encounterCount >= 0) { "Encounter count cannot be negative" }
        require(current.correctCount in 0..current.encounterCount) { "Correct count is invalid" }

        val activeDelta: Int
        val lifetimeDelta: Int
        if (!correct) {
            activeDelta = 0
            lifetimeDelta = 0
        } else if (current.encounterCount == 0) {
            activeDelta = 60
            lifetimeDelta = 60
        } else if (current.activeScore < 60) {
            activeDelta = 20
            lifetimeDelta = 20
        } else {
            activeDelta = 0
            lifetimeDelta = 12
        }

        return ScoreChange(
            activeDelta = activeDelta,
            lifetimeDelta = lifetimeDelta,
            newState = MasteryState(
                activeScore = current.activeScore + activeDelta,
                encounterCount = current.encounterCount + 1,
                correctCount = current.correctCount + if (correct) 1 else 0,
            ),
        )
    }
}
