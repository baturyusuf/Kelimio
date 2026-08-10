package com.kelimio.api.energy

import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Service
class EnergyService(
    private val repository: EnergyRepository,
    private val clock: Clock,
) {
    @Transactional
    fun current(userId: UUID): EnergySnapshot {
        val decision = decide(userId, wrongAnswer = false, consumesEnergy = true)
        appendEvents(userId, null, null, decision.mutations)
        return decision.snapshot
    }

    fun applyForAnswer(
        userId: UUID,
        wrongAnswer: Boolean,
        consumesEnergy: Boolean,
    ): EnergyDecision = decide(userId, wrongAnswer, consumesEnergy)

    @Transactional
    fun creditRewardedAd(userId: UUID, requestedAmount: Int): RewardedEnergyCredit {
        require(requestedAmount in 1..20)
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val initialized = repository.ensureAndLock(userId, now)
        val mutations = mutableListOf<EnergyMutation>()
        if (initialized.created) {
            mutations += EnergyMutation("ACCOUNT_INITIALIZED", 5, 0, 5, now)
        }
        val regenerated = EnergyPolicy.regenerate(initialized.state, now)
        var state = regenerated.state
        if (regenerated.regenerated > 0) {
            mutations += EnergyMutation(
                type = "LAZY_REGENERATED",
                delta = regenerated.regenerated,
                balanceBefore = initialized.state.balance,
                balanceAfter = state.balance,
                occurredAt = now,
            )
            repository.update(userId, state)
        }
        val before = state.balance
        val credited = minOf(requestedAmount, EnergyPolicy.MAX_ENERGY - before)
        if (credited > 0) {
            state = state.copy(
                balance = before + credited,
                regenerationAnchorAt = now,
                version = state.version + 1,
            )
            repository.update(userId, state)
        }
        mutations += EnergyMutation("REWARDED_AD_CREDIT", credited, before, state.balance, now)
        appendEvents(userId, null, null, mutations)
        return RewardedEnergyCredit(
            credited = credited,
            snapshot = EnergySnapshot(
                balance = state.balance,
                maximum = EnergyPolicy.MAX_ENERGY,
                unlimited = false,
                nextRegenerationAt = state.regenerationAnchorAt.plus(EnergyPolicy.REGENERATION_PERIOD)
                    .takeIf { state.balance < EnergyPolicy.MAX_ENERGY },
                asOf = now,
            ),
        )
    }

    fun appendEvents(
        userId: UUID,
        attemptId: UUID?,
        submissionId: UUID?,
        mutations: List<EnergyMutation>,
    ) {
        mutations.forEach { mutation ->
            val answerScoped = mutation.type == "WRONG_ANSWER_DEBIT"
            repository.appendEvent(
                userId,
                attemptId.takeIf { answerScoped },
                submissionId.takeIf { answerScoped },
                mutation,
            )
        }
    }

    private fun decide(
        userId: UUID,
        wrongAnswer: Boolean,
        consumesEnergy: Boolean,
    ): EnergyDecision {
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val initialized = repository.ensureAndLock(userId, now)
        val mutations = mutableListOf<EnergyMutation>()
        if (initialized.created) {
            mutations += EnergyMutation("ACCOUNT_INITIALIZED", 5, 0, 5, now)
        }

        val regenerated = EnergyPolicy.regenerate(initialized.state, now)
        var state = regenerated.state
        if (regenerated.regenerated > 0) {
            mutations += EnergyMutation(
                type = "LAZY_REGENERATED",
                delta = regenerated.regenerated,
                balanceBefore = initialized.state.balance,
                balanceAfter = state.balance,
                occurredAt = now,
            )
            repository.update(userId, state)
        }

        var interrupted = false
        if (consumesEnergy && wrongAnswer) {
            if (state.balance == 0) {
                interrupted = true
            } else {
                val before = state.balance
                val anchor = if (before == EnergyPolicy.MAX_ENERGY) now else state.regenerationAnchorAt
                state = state.copy(balance = before - 1, regenerationAnchorAt = anchor, version = state.version + 1)
                repository.update(userId, state)
                mutations += EnergyMutation("WRONG_ANSWER_DEBIT", -1, before, state.balance, now)
            }
        }

        return EnergyDecision(
            snapshot = EnergySnapshot(
                balance = state.balance,
                maximum = EnergyPolicy.MAX_ENERGY,
                unlimited = !consumesEnergy,
                nextRegenerationAt = state.regenerationAnchorAt.plus(EnergyPolicy.REGENERATION_PERIOD)
                    .takeIf { state.balance < EnergyPolicy.MAX_ENERGY },
                asOf = now,
            ),
            interrupted = interrupted,
            mutations = mutations,
        )
    }
}

data class EnergyMutation(
    val type: String,
    val delta: Int,
    val balanceBefore: Int,
    val balanceAfter: Int,
    val occurredAt: OffsetDateTime,
)

data class EnergySnapshot(
    val balance: Int,
    val maximum: Int,
    val unlimited: Boolean,
    val nextRegenerationAt: OffsetDateTime?,
    val asOf: OffsetDateTime,
)

data class EnergyDecision(
    val snapshot: EnergySnapshot,
    val interrupted: Boolean,
    val mutations: List<EnergyMutation>,
)


data class RewardedEnergyCredit(
    val credited: Int,
    val snapshot: EnergySnapshot,
)
