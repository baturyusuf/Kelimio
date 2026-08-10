package com.kelimio.api.rewardedad

import org.jooq.DSLContext
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.util.UUID

@Repository
@ConditionalOnProperty(name = ["KELIMIO_REWARDED_AD_ENABLED"], havingValue = "true")
internal class RewardedAdRepository(
    private val dsl: DSLContext,
) {
    fun findByCommand(userId: UUID, commandId: UUID): RewardedAdSessionRecord? = dsl.fetchOne(
        "select * from rewarded_ad_session where user_id = ? and idempotency_key = ?",
        userId,
        commandId,
    )?.toRecord()

    fun countSince(userId: UUID, since: OffsetDateTime): Int = checkNotNull(
        dsl.fetchOne(
            "select count(*)::integer as count from rewarded_ad_session where user_id = ? and created_at >= ?",
            userId,
            since,
        ),
    ).get("count", Int::class.java)!!

    fun insert(
        id: UUID,
        userId: UUID,
        commandId: UUID,
        customData: String,
        settings: RewardedAdSettings,
        now: OffsetDateTime,
        expiresAt: OffsetDateTime,
        correlationId: String,
    ) {
        check(
            dsl.execute(
                """
                insert into rewarded_ad_session(
                    id, user_id, idempotency_key, custom_data, expected_ad_unit_id,
                    expected_reward_item, expected_reward_amount, status,
                    created_at, expires_at, correlation_id
                ) values (?, ?, ?, ?, ?, ?, ?, 'PENDING',
                          cast(? as timestamptz), cast(? as timestamptz), ?)
                """.trimIndent(),
                id,
                userId,
                commandId,
                customData,
                settings.adUnitId,
                settings.rewardItem,
                settings.rewardAmount,
                now,
                expiresAt,
                correlationId,
            ) == 1,
        )
        appendEvent(id, userId, "SESSION_CREATED", null, null, now, correlationId)
    }

    fun findOwned(userId: UUID, sessionId: UUID, lock: Boolean = false): RewardedAdSessionRecord? {
        val suffix = if (lock) " for update" else ""
        return dsl.fetchOne(
            "select * from rewarded_ad_session where id = ? and user_id = ?$suffix",
            sessionId,
            userId,
        )?.toRecord()
    }

    fun findByCustomData(customData: String, lock: Boolean = false): RewardedAdSessionRecord? {
        val suffix = if (lock) " for update" else ""
        return dsl.fetchOne(
            "select * from rewarded_ad_session where custom_data = ?$suffix",
            customData,
        )?.toRecord()
    }

    fun providerTransactionSession(transactionId: String): UUID? = dsl.fetchOne(
        "select id from rewarded_ad_session where provider_transaction_id = ?",
        transactionId,
    )?.get("id", UUID::class.java)

    fun grant(
        session: RewardedAdSessionRecord,
        callback: VerifiedAdMobCallback,
        querySha256: String,
        energyDelta: Int,
        now: OffsetDateTime,
        correlationId: String,
    ) {
        check(
            dsl.execute(
                """
                update rewarded_ad_session
                   set status = 'GRANTED', provider_transaction_id = ?, provider_key_id = ?,
                       callback_query_sha256 = ?, granted_energy_delta = ?,
                       completed_at = cast(? as timestamptz)
                 where id = ? and status = 'PENDING'
                """.trimIndent(),
                callback.transactionId,
                callback.keyId,
                querySha256,
                energyDelta,
                now,
                session.id,
            ) == 1,
        ) { "Rewarded-ad session changed before grant" }
        appendEvent(
            session.id,
            session.userId,
            "REWARD_GRANTED",
            callback.transactionId,
            energyDelta,
            now,
            correlationId,
        )
    }

    fun reject(
        session: RewardedAdSessionRecord,
        transactionId: String?,
        now: OffsetDateTime,
        correlationId: String,
    ) {
        if (session.status != RewardedAdStatus.PENDING) return
        check(
            dsl.execute(
                """
                update rewarded_ad_session
                   set status = 'REJECTED', provider_transaction_id = ?,
                       completed_at = cast(? as timestamptz)
                 where id = ? and status = 'PENDING'
                """.trimIndent(),
                transactionId,
                now,
                session.id,
            ) == 1,
        )
        appendEvent(session.id, session.userId, "REWARD_REJECTED", transactionId, null, now, correlationId)
    }

    fun expire(session: RewardedAdSessionRecord, now: OffsetDateTime, correlationId: String) {
        if (session.status != RewardedAdStatus.PENDING) return
        check(
            dsl.execute(
                """
                update rewarded_ad_session
                   set status = 'EXPIRED', completed_at = cast(? as timestamptz)
                 where id = ? and status = 'PENDING'
                """.trimIndent(),
                now,
                session.id,
            ) == 1,
        )
        appendEvent(session.id, session.userId, "SESSION_EXPIRED", null, null, now, correlationId)
    }

    private fun appendEvent(
        sessionId: UUID,
        userId: UUID,
        type: String,
        transactionId: String?,
        energyDelta: Int?,
        now: OffsetDateTime,
        correlationId: String,
    ) {
        val inserted = dsl.execute(
            """
            insert into rewarded_ad_event(
                id, session_id, user_id, event_type, provider_transaction_id,
                energy_delta, occurred_at, correlation_id
            ) values (?, ?, ?, ?, ?, ?, cast(? as timestamptz), ?)
            on conflict (session_id, event_type) do nothing
            """.trimIndent(),
            UUID.randomUUID(),
            sessionId,
            userId,
            type,
            transactionId,
            energyDelta,
            now,
            correlationId,
        )
        check(inserted in 0..1)
    }

    private fun org.jooq.Record.toRecord() = RewardedAdSessionRecord(
        id = get("id", UUID::class.java)!!,
        userId = get("user_id", UUID::class.java)!!,
        customData = get("custom_data", String::class.java)!!,
        expectedAdUnitId = get("expected_ad_unit_id", String::class.java)!!,
        expectedRewardItem = get("expected_reward_item", String::class.java)!!,
        expectedRewardAmount = get("expected_reward_amount", Int::class.java)!!,
        status = RewardedAdStatus.valueOf(get("status", String::class.java)!!),
        providerTransactionId = get("provider_transaction_id", String::class.java),
        grantedEnergyDelta = get("granted_energy_delta", Short::class.java)?.toInt(),
        createdAt = get("created_at", OffsetDateTime::class.java)!!,
        expiresAt = get("expires_at", OffsetDateTime::class.java)!!,
        completedAt = get("completed_at", OffsetDateTime::class.java),
    )
}
