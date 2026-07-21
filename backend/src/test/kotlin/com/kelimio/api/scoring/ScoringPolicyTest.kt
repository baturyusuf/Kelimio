package com.kelimio.api.scoring

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import kotlin.random.Random

class ScoringPolicyTest {
    @Test
    fun `first encounter correct awards sixty active and lifetime points`() {
        val result = ScoringPolicy.evaluate(MasteryState(0, 0, 0), correct = true)

        assertThat(result.activeDelta).isEqualTo(60)
        assertThat(result.lifetimeDelta).isEqualTo(60)
        assertThat(result.newState.activeScore).isEqualTo(60)
    }

    @Test
    fun `wrong then three correct answers reaches sixty in twenty point steps`() {
        var state = MasteryState(0, 0, 0)
        val deltas = mutableListOf<Int>()
        listOf(false, true, true, true).forEach { correct ->
            val change = ScoringPolicy.evaluate(state, correct)
            deltas += change.activeDelta
            state = change.newState
        }

        assertThat(deltas).containsExactly(0, 20, 20, 20)
        assertThat(state.activeScore).isEqualTo(60)
    }

    @Test
    fun `correct answer after active mastery awards only twelve lifetime points`() {
        val result = ScoringPolicy.evaluate(MasteryState(60, 4, 3), correct = true)

        assertThat(result.activeDelta).isZero()
        assertThat(result.lifetimeDelta).isEqualTo(12)
        assertThat(result.newState.activeScore).isEqualTo(60)
    }

    @Test
    fun `random answer histories preserve scoring invariants`() {
        repeat(250) { seed ->
            val random = Random(seed)
            var state = MasteryState(0, 0, 0)
            repeat(200) {
                val correct = random.nextBoolean()
                val before = state
                val change = ScoringPolicy.evaluate(state, correct)
                state = change.newState

                assertThat(state.activeScore).isIn(0, 20, 40, 60)
                assertThat(state.activeScore).isGreaterThanOrEqualTo(before.activeScore)
                assertThat(change.lifetimeDelta).isIn(0, 12, 20, 60)
                if (!correct) {
                    assertThat(change.activeDelta).isZero()
                    assertThat(change.lifetimeDelta).isZero()
                }
            }
        }
    }
}
