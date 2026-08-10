package com.kelimio.api.rewardedad

import com.kelimio.api.energy.EnergySnapshot
import java.time.OffsetDateTime
import java.util.UUID

internal data class RewardedAdSessionResponse(
    val sessionId: UUID,
    val customData: String,
    val userId: String,
    val adUnitId: String,
    val rewardAmount: Int,
    val rewardItem: String,
    val expiresAt: OffsetDateTime,
    val status: RewardedAdStatus,
    val created: Boolean,
)

internal data class RewardedAdSessionStatusResponse(
    val sessionId: UUID,
    val status: RewardedAdStatus,
    val grantedEnergyDelta: Int?,
    val completedAt: OffsetDateTime?,
    val energy: EnergySnapshot?,
)

internal enum class RewardedAdStatus {
    PENDING,
    GRANTED,
    REJECTED,
    EXPIRED,
}

internal data class RewardedAdSessionRecord(
    val id: UUID,
    val userId: UUID,
    val customData: String,
    val expectedAdUnitId: String,
    val expectedRewardItem: String,
    val expectedRewardAmount: Int,
    val status: RewardedAdStatus,
    val providerTransactionId: String?,
    val grantedEnergyDelta: Int?,
    val createdAt: OffsetDateTime,
    val expiresAt: OffsetDateTime,
    val completedAt: OffsetDateTime?,
)

internal data class VerifiedAdMobCallback(
    val keyId: Long,
    val adUnitId: String,
    val rewardAmount: Int,
    val rewardItem: String,
    val timestampMillis: Long,
    val transactionId: String,
    val userId: String,
    val customData: String,
)
