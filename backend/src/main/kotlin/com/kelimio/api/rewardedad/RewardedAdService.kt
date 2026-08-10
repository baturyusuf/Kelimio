package com.kelimio.api.rewardedad

import com.kelimio.api.energy.EnergyService
import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.NotFoundProblem
import com.kelimio.api.web.TooManyRequestsProblem
import com.kelimio.api.web.UnprocessableProblem
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Clock
import java.time.Duration
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Base64
import java.util.HexFormat
import java.util.UUID

@Service
@ConditionalOnProperty(name = ["KELIMIO_REWARDED_AD_ENABLED"], havingValue = "true")
internal class RewardedAdService(
    private val repository: RewardedAdRepository,
    private val verifier: AdMobSsvVerifier,
    private val settings: RewardedAdSettings,
    private val energyService: EnergyService,
    private val outbox: TransactionalOutbox,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
) {
    private val random = SecureRandom()

    @Transactional
    fun create(user: AppUser, commandId: UUID): RewardedAdSessionResponse {
        repository.findByCommand(user.id, commandId)?.let { return it.toResponse(created = false) }
        val now = now()
        val recentCount = repository.countSince(user.id, now.minus(settings.sessionWindow))
        if (recentCount >= settings.maxSessionsPerWindow) {
            throw TooManyRequestsProblem("Too many rewarded-ad sessions were requested. Try again later.")
        }
        val id = UUID.randomUUID()
        val customData = ByteArray(32).also(random::nextBytes).let {
            Base64.getUrlEncoder().withoutPadding().encodeToString(it)
        }
        repository.insert(
            id = id,
            userId = user.id,
            commandId = commandId,
            customData = customData,
            settings = settings,
            now = now,
            expiresAt = now.plus(settings.sessionTtl),
            correlationId = correlationIdProvider.current(),
        )
        return checkNotNull(repository.findOwned(user.id, id)).toResponse(created = true)
    }

    @Transactional
    fun status(user: AppUser, sessionId: UUID): RewardedAdSessionStatusResponse {
        var session = repository.findOwned(user.id, sessionId, lock = true)
            ?: throw NotFoundProblem("Rewarded-ad session was not found.")
        val now = now()
        if (session.status == RewardedAdStatus.PENDING && session.expiresAt <= now) {
            repository.expire(session, now, correlationIdProvider.current())
            session = checkNotNull(repository.findOwned(user.id, sessionId))
        }
        val energy = if (session.status == RewardedAdStatus.GRANTED) energyService.current(user.id) else null
        return RewardedAdSessionStatusResponse(
            sessionId = session.id,
            status = session.status,
            grantedEnergyDelta = session.grantedEnergyDelta,
            completedAt = session.completedAt,
            energy = energy,
        )
    }

    @Transactional
    fun processCallback(rawQuery: String) {
        val callback = try {
            verifier.verify(rawQuery)
        } catch (_: IllegalArgumentException) {
            throw UnprocessableProblem("The rewarded-ad callback could not be verified.")
        }
        val session = repository.findByCustomData(callback.customData, lock = true) ?: return
        if (session.status == RewardedAdStatus.GRANTED) return
        val now = now()
        val callbackAt = runCatching { java.time.Instant.ofEpochMilli(callback.timestampMillis) }
            .getOrElse {
                repository.reject(session, null, now, correlationIdProvider.current())
                return
            }
        val age = Duration.between(callbackAt, clock.instant())
        val duplicateSession = repository.providerTransactionSession(callback.transactionId)
        if (duplicateSession != null) {
            if (duplicateSession == session.id) return
            repository.reject(session, null, now, correlationIdProvider.current())
            return
        }
        val accepted = session.status == RewardedAdStatus.PENDING &&
            session.expiresAt > now &&
            age >= Duration.ofMinutes(-5) && age <= settings.callbackMaxAge &&
            callback.adUnitId == session.expectedAdUnitId &&
            callback.rewardItem == session.expectedRewardItem &&
            callback.rewardAmount == session.expectedRewardAmount &&
            callback.userId == session.userId.toString()
        if (!accepted) {
            repository.reject(session, callback.transactionId, now, correlationIdProvider.current())
            return
        }
        val credit = energyService.creditRewardedAd(session.userId, callback.rewardAmount)
        val queryHash = HexFormat.of().formatHex(
            MessageDigest.getInstance("SHA-256").digest(rawQuery.toByteArray(Charsets.UTF_8)),
        )
        val correlationId = correlationIdProvider.current()
        repository.grant(session, callback, queryHash, credit.credited, now, correlationId)
        val eventId = UUID.randomUUID()
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "rewarded-ad",
                aggregateId = session.id,
                eventType = "rewarded-ad.energy-granted.v1",
                schemaVersion = 1,
                payload = mapOf(
                    "eventId" to eventId,
                    "sessionId" to session.id,
                    "userId" to session.userId,
                    "transactionId" to callback.transactionId,
                    "energyDelta" to credit.credited,
                ),
                correlationId = correlationId,
                occurredAt = now,
            ),
        )
    }

    private fun RewardedAdSessionRecord.toResponse(created: Boolean) = RewardedAdSessionResponse(
        sessionId = id,
        customData = customData,
        userId = userId.toString(),
        adUnitId = expectedAdUnitId,
        rewardAmount = expectedRewardAmount,
        rewardItem = expectedRewardItem,
        expiresAt = expiresAt,
        status = status,
        created = created,
    )

    private fun now(): OffsetDateTime = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
}
