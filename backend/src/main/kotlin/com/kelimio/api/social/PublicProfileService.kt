package com.kelimio.api.social

import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.NotFoundProblem
import com.kelimio.api.web.UnprocessableProblem
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Service
internal class PublicProfileService(
    private val repository: PublicProfileRepository,
    private val outbox: TransactionalOutbox,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
) {
    @Transactional(readOnly = true)
    fun own(user: AppUser): OwnPublicProfileResponse = repository.findOwn(user.id)?.toOwn()
        ?: throw NotFoundProblem("Profile was not found.")

    @Transactional
    fun update(user: AppUser, request: UpdatePublicProfileRequest): OwnPublicProfileResponse {
        val normalized = request.copy(
            username = request.username?.trim()?.lowercase()?.takeIf(String::isNotEmpty),
            displayName = request.displayName.trim(),
            bio = request.bio?.trim()?.takeIf(String::isNotEmpty),
            avatarSeed = request.avatarSeed?.trim()?.takeIf(String::isNotEmpty),
        )
        validate(normalized)
        if (!repository.lockUser(user.id)) throw NotFoundProblem("Profile was not found.")
        val previous = repository.findOwn(user.id) ?: throw NotFoundProblem("Profile was not found.")
        val changedFields = changedFields(previous, normalized)
        if (changedFields.isEmpty()) return previous.toOwn()
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val version = try {
            repository.update(user.id, normalized, now)
        } catch (_: PublicUsernameConflictException) {
            throw ConflictProblem("This username is already in use.")
        }
        val correlationId = correlationIdProvider.current()
        repository.appendEvent(user.id, version, changedFields, now, correlationId)
        val eventId = UUID.randomUUID()
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "public-profile",
                aggregateId = user.id,
                eventType = "public-profile.updated.v1",
                schemaVersion = 1,
                payload = mapOf(
                    "eventId" to eventId,
                    "userId" to user.id,
                    "profileVersion" to version,
                    "changedFields" to changedFields,
                    "publicProfileEnabled" to normalized.publicProfileEnabled,
                    "leaderboardOptIn" to normalized.leaderboardOptIn,
                ),
                correlationId = correlationId,
                occurredAt = now,
            ),
        )
        return checkNotNull(repository.findOwn(user.id)).toOwn()
    }

    @Transactional(readOnly = true)
    fun public(username: String): PublicProfileResponse = repository.findPublic(username)
        ?.toPublic()
        ?: throw NotFoundProblem("Public profile was not found.")

    @Transactional(readOnly = true)
    fun leaderboard(limit: Int): LeaderboardResponse = LeaderboardResponse(
        entries = repository.leaderboard(limit),
        generatedAt = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC),
    )

    private fun validate(request: UpdatePublicProfileRequest) {
        if ((request.publicProfileEnabled || request.leaderboardOptIn) && request.username == null) {
            throw UnprocessableProblem("A username is required before enabling a public profile.")
        }
        if (request.leaderboardOptIn && !request.publicProfileEnabled) {
            throw UnprocessableProblem("Leaderboard participation requires an enabled public profile.")
        }
        if (request.username in RESERVED_USERNAMES) {
            throw UnprocessableProblem("This username is reserved.")
        }
        if (request.displayName.isBlank()) {
            throw UnprocessableProblem("Display name must not be blank.")
        }
    }

    private fun changedFields(previous: PublicProfileRecord, request: UpdatePublicProfileRequest): List<String> = buildList {
        if (previous.username != request.username) add("username")
        if (previous.displayName != request.displayName) add("displayName")
        if (previous.bio != request.bio) add("bio")
        if (previous.avatarSeed != request.avatarSeed) add("avatarSeed")
        if (previous.publicProfileEnabled != request.publicProfileEnabled) add("publicProfileEnabled")
        if (previous.leaderboardOptIn != request.leaderboardOptIn) add("leaderboardOptIn")
    }

    private fun PublicProfileRecord.toOwn() = OwnPublicProfileResponse(
        username = username,
        displayName = displayName,
        bio = bio,
        avatarSeed = avatarSeed,
        targetLanguage = targetLanguage,
        publicProfileEnabled = publicProfileEnabled,
        leaderboardOptIn = leaderboardOptIn,
        lifetimeScore = lifetimeScore,
        completedAttempts = completedAttempts,
        updatedAt = updatedAt,
    )

    private fun PublicProfileRecord.toPublic() = PublicProfileResponse(
        username = checkNotNull(username),
        displayName = displayName,
        bio = bio,
        avatarSeed = avatarSeed,
        targetLanguage = targetLanguage,
        lifetimeScore = lifetimeScore,
        completedAttempts = completedAttempts,
        joinedAt = createdAt,
    )

    private companion object {
        val RESERVED_USERNAMES = setOf(
            "admin", "administrator", "support", "kelimio", "moderator", "root", "system", "teacher",
        )
    }
}
