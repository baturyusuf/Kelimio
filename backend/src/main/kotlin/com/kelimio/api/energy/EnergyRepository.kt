package com.kelimio.api.energy

import com.kelimio.api.persistence.EnergyAccounts
import com.kelimio.api.persistence.EnergyEvents
import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.util.UUID

@Repository
class EnergyRepository(
    private val dsl: DSLContext,
) {
    fun ensureAndLock(
        userId: UUID,
        now: OffsetDateTime,
    ): InitializedEnergy {
        val created = dsl.insertInto(EnergyAccounts.TABLE)
            .columns(
                EnergyAccounts.USER_ID,
                EnergyAccounts.BALANCE,
                EnergyAccounts.ANCHOR_AT,
                EnergyAccounts.VERSION,
            )
            .values(userId, EnergyPolicy.MAX_ENERGY.toShort(), now, 0L)
            .onConflict(EnergyAccounts.USER_ID)
            .doNothing()
            .execute() == 1

        val state = dsl.select(
            EnergyAccounts.BALANCE,
            EnergyAccounts.ANCHOR_AT,
            EnergyAccounts.VERSION,
        ).from(EnergyAccounts.TABLE)
            .where(EnergyAccounts.USER_ID.eq(userId))
            .forUpdate()
            .fetchOne {
                EnergyState(
                    balance = it.get(EnergyAccounts.BALANCE)!!.toInt(),
                    regenerationAnchorAt = it.get(EnergyAccounts.ANCHOR_AT)!!,
                    version = it.get(EnergyAccounts.VERSION)!!,
                )
            } ?: error("Energy row was not available after initialization")
        return InitializedEnergy(state, created)
    }

    fun update(
        userId: UUID,
        state: EnergyState,
    ) {
        val updated = dsl.update(EnergyAccounts.TABLE)
            .set(EnergyAccounts.BALANCE, state.balance.toShort())
            .set(EnergyAccounts.ANCHOR_AT, state.regenerationAnchorAt)
            .set(EnergyAccounts.VERSION, state.version)
            .where(EnergyAccounts.USER_ID.eq(userId))
            .execute()
        check(updated == 1) { "Energy update did not affect exactly one row" }
    }

    fun appendEvent(
        userId: UUID,
        attemptId: UUID?,
        submissionId: UUID?,
        mutation: EnergyMutation,
    ) {
        dsl.insertInto(EnergyEvents.TABLE)
            .columns(
                EnergyEvents.ID,
                EnergyEvents.USER_ID,
                EnergyEvents.ATTEMPT_ID,
                EnergyEvents.SUBMISSION_ID,
                EnergyEvents.EVENT_TYPE,
                EnergyEvents.DELTA,
                EnergyEvents.BALANCE_BEFORE,
                EnergyEvents.BALANCE_AFTER,
                EnergyEvents.OCCURRED_AT,
            )
            .values(
                UUID.randomUUID(),
                userId,
                attemptId,
                submissionId,
                mutation.type,
                mutation.delta.toShort(),
                mutation.balanceBefore.toShort(),
                mutation.balanceAfter.toShort(),
                mutation.occurredAt,
            )
            .execute()
    }
}

data class InitializedEnergy(
    val state: EnergyState,
    val created: Boolean,
)
