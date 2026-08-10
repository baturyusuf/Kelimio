package com.kelimio.api.social

import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size
import java.time.OffsetDateTime
import java.util.UUID

internal data class UpdatePublicProfileRequest(
    @field:Pattern(regexp = "^[a-z][a-z0-9_]{2,23}$")
    val username: String?,
    @field:Size(min = 1, max = 80)
    val displayName: String,
    @field:Size(min = 1, max = 280)
    val bio: String?,
    @field:Pattern(regexp = "^[A-Za-z0-9_-]{8,64}$")
    val avatarSeed: String?,
    val publicProfileEnabled: Boolean,
    val leaderboardOptIn: Boolean,
)

internal data class OwnPublicProfileResponse(
    val username: String?,
    val displayName: String,
    val bio: String?,
    val avatarSeed: String?,
    val targetLanguage: String,
    val publicProfileEnabled: Boolean,
    val leaderboardOptIn: Boolean,
    val lifetimeScore: Long,
    val completedAttempts: Int,
    val updatedAt: OffsetDateTime?,
)

internal data class PublicProfileResponse(
    val username: String,
    val displayName: String,
    val bio: String?,
    val avatarSeed: String?,
    val targetLanguage: String,
    val lifetimeScore: Long,
    val completedAttempts: Int,
    val joinedAt: OffsetDateTime,
)

internal data class LeaderboardEntryResponse(
    val rank: Int,
    val username: String,
    val displayName: String,
    val avatarSeed: String?,
    val targetLanguage: String,
    val lifetimeScore: Long,
    val completedAttempts: Int,
)

internal data class LeaderboardResponse(
    val entries: List<LeaderboardEntryResponse>,
    val generatedAt: OffsetDateTime,
)

internal data class PublicProfileRecord(
    val userId: UUID,
    val username: String?,
    val displayName: String,
    val bio: String?,
    val avatarSeed: String?,
    val targetLanguage: String,
    val publicProfileEnabled: Boolean,
    val leaderboardOptIn: Boolean,
    val lifetimeScore: Long,
    val completedAttempts: Int,
    val profileVersion: Long,
    val createdAt: OffsetDateTime,
    val updatedAt: OffsetDateTime?,
)
