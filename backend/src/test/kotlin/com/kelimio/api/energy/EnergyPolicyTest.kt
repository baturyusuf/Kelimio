package com.kelimio.api.energy

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.OffsetDateTime
import java.time.ZoneOffset
import kotlin.random.Random

class EnergyPolicyTest {
    private val anchor = OffsetDateTime.of(2026, 7, 21, 0, 0, 0, 0, ZoneOffset.UTC)

    @Test
    fun `energy regenerates once per complete four-hour period`() {
        val current = EnergyState(balance = 1, regenerationAnchorAt = anchor, version = 0)

        val beforePeriod = EnergyPolicy.regenerate(current, anchor.plusHours(3).plusMinutes(59))
        val afterTwoPeriods = EnergyPolicy.regenerate(current, anchor.plusHours(9))

        assertThat(beforePeriod.regenerated).isZero()
        assertThat(afterTwoPeriods.regenerated).isEqualTo(2)
        assertThat(afterTwoPeriods.state.balance).isEqualTo(3)
        assertThat(afterTwoPeriods.state.regenerationAnchorAt).isEqualTo(anchor.plusHours(8))
    }

    @Test
    fun `regeneration never exceeds five and discards banked time at the cap`() {
        val result = EnergyPolicy.regenerate(
            EnergyState(balance = 4, regenerationAnchorAt = anchor, version = 3),
            anchor.plusDays(3),
        )

        assertThat(result.regenerated).isEqualTo(1)
        assertThat(result.state.balance).isEqualTo(5)
        assertThat(result.state.regenerationAnchorAt).isEqualTo(anchor.plusDays(3))
    }

    @Test
    fun `random elapsed periods always preserve energy bounds`() {
        repeat(500) { seed ->
            val random = Random(seed)
            val balance = random.nextInt(0, 6)
            val elapsedHours = random.nextLong(0, 500)
            val result = EnergyPolicy.regenerate(
                EnergyState(balance, anchor, 0),
                anchor.plusHours(elapsedHours),
            )

            assertThat(result.state.balance).isBetween(balance, 5)
            assertThat(result.regenerated).isEqualTo(result.state.balance - balance)
        }
    }
}
