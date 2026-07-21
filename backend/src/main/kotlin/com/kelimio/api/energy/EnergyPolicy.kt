package com.kelimio.api.energy

import java.time.Duration
import java.time.OffsetDateTime

data class EnergyState(
    val balance: Int,
    val regenerationAnchorAt: OffsetDateTime,
    val version: Long,
)

data class RegeneratedEnergy(
    val state: EnergyState,
    val regenerated: Int,
)

object EnergyPolicy {
    const val MAX_ENERGY = 5
    val REGENERATION_PERIOD: Duration = Duration.ofHours(4)

    fun regenerate(
        current: EnergyState,
        now: OffsetDateTime,
    ): RegeneratedEnergy {
        require(current.balance in 0..MAX_ENERGY) { "Energy balance is outside bounds" }
        if (current.balance == MAX_ENERGY || !now.isAfter(current.regenerationAnchorAt)) {
            return RegeneratedEnergy(current, 0)
        }

        val elapsedPeriods = Duration.between(current.regenerationAnchorAt, now).toHours() / REGENERATION_PERIOD.toHours()
        if (elapsedPeriods <= 0) {
            return RegeneratedEnergy(current, 0)
        }

        val gained = minOf(MAX_ENERGY - current.balance, elapsedPeriods.toInt())
        val reachedMaximum = current.balance + gained == MAX_ENERGY
        val nextAnchor = if (reachedMaximum) {
            now
        } else {
            current.regenerationAnchorAt.plus(REGENERATION_PERIOD.multipliedBy(elapsedPeriods))
        }
        return RegeneratedEnergy(
            state = current.copy(
                balance = current.balance + gained,
                regenerationAnchorAt = nextAnchor,
                version = current.version + 1,
            ),
            regenerated = gained,
        )
    }
}
