package com.kelimio.api.identityprofile

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.language.InvalidLanguageTagException
import com.kelimio.api.language.LanguageTagNormalizer
import com.kelimio.api.outbox.OutboxRepository
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.UnprocessableProblem
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.text.Normalizer
import java.time.Clock
import java.time.DateTimeException
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.UUID

@Service
class ProfileSetupService(
    private val repository: IdentityProfileRepository,
    private val languageTagNormalizer: LanguageTagNormalizer,
    private val idempotencyService: IdempotencyService,
    private val outboxRepository: OutboxRepository,
    private val objectMapper: ObjectMapper,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
) {
    @Transactional
    fun complete(user: AppUser, idempotencyKey: UUID, command: ProfileSetupCommand): AppUser {
        val canonical = canonicalize(command)
        val lookup = idempotencyService.lockAndFind(
            user.id,
            OPERATION,
            idempotencyKey,
            objectMapper.writeValueAsString(canonical),
        )
        lookup.resourceId?.let { resourceId ->
            check(resourceId == user.id) { "Profile setup idempotency result belongs to another resource" }
            return repository.findById(user.id)
                ?: error("Profile setup idempotency result refers to a missing user")
        }

        val existing = repository.lockById(user.id)
        if (existing.profileSetupComplete) {
            throw ConflictProblem("Profile setup has already been completed.")
        }
        val version = existing.profileVersion + 1
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val completed = repository.completeSetup(
            userId = user.id,
            displayName = canonical.displayName,
            appLocale = canonical.appLocale,
            activeTargetLanguage = canonical.activeTargetLanguage,
            preferredSupportLanguage = canonical.preferredSupportLanguage,
            timeZone = canonical.timeZone,
            profileVersion = version,
            now = now,
        )
        repository.appendSetupEvent(
            userId = user.id,
            profileVersion = version,
            changedFields = SETUP_FIELDS,
            now = now,
            correlationId = correlationIdProvider.current(),
        )
        outboxRepository.append(
            aggregateType = "user-profile",
            aggregateId = user.id,
            eventType = "identity.profile-setup-completed.v1",
            payload = mapOf(
                "userId" to user.id,
                "profileVersion" to version,
                "changedFields" to SETUP_FIELDS,
            ),
        )
        idempotencyService.record(
            user.id,
            OPERATION,
            idempotencyKey,
            lookup.fingerprint,
            user.id,
        )
        return completed
    }

    private fun canonicalize(command: ProfileSetupCommand): CanonicalProfileSetup {
        val displayName = ProfileTextPolicy.canonicalDisplayName(command.displayName)
        val appLocale = normalizeLanguage(command.appLocale, "appLocale")
        if (appLocale !in SUPPORTED_APP_LOCALES) {
            throw UnprocessableProblem("The application locale is not supported by this client release.")
        }
        val targetLanguage = normalizeLanguage(command.activeTargetLanguage, "activeTargetLanguage")
        val supportLanguage = normalizeLanguage(command.preferredSupportLanguage, "preferredSupportLanguage")
        if (targetLanguage == supportLanguage) {
            throw UnprocessableProblem("Target and support languages must be different.")
        }
        return CanonicalProfileSetup(
            displayName = displayName,
            appLocale = appLocale,
            activeTargetLanguage = targetLanguage,
            preferredSupportLanguage = supportLanguage,
            timeZone = normalizeTimeZone(command.timeZone),
        )
    }

    private fun normalizeLanguage(value: String, field: String): String = try {
        languageTagNormalizer.normalize(value)
    } catch (_: InvalidLanguageTagException) {
        throw UnprocessableProblem("$field must be a valid language tag.")
    }

    private fun normalizeTimeZone(value: String): String {
        if (value != value.trim()) {
            throw UnprocessableProblem("timeZone must be a valid IANA time-zone identifier.")
        }
        if (value !in IANA_TIME_ZONE_IDS) {
            throw UnprocessableProblem("timeZone must be a valid IANA time-zone identifier.")
        }
        return try {
            ZoneId.of(value).id
        } catch (_: DateTimeException) {
            throw UnprocessableProblem("timeZone must be a valid IANA time-zone identifier.")
        }
    }

    companion object {
        const val OPERATION = "identity.complete-profile-setup"
        val SUPPORTED_APP_LOCALES = setOf("tr", "en", "ar")
        val SETUP_FIELDS = listOf(
            "displayName",
            "appLocale",
            "activeTargetLanguage",
            "preferredSupportLanguage",
            "timeZone",
            "profileSetupStatus",
        )
        private val IANA_TIME_ZONE_IDS = ZoneId.getAvailableZoneIds() + "UTC"
    }
}

internal object ProfileTextPolicy {
    private const val FALLBACK_DISPLAY_NAME = "Kelimio User"
    private val WHITESPACE = Regex("\\s+")
    private val BIDI_CONTROLS = setOf(
        '\u061C',
        '\u200E',
        '\u200F',
        '\u202A',
        '\u202B',
        '\u202C',
        '\u202D',
        '\u202E',
        '\u2066',
        '\u2067',
        '\u2068',
        '\u2069',
    )

    fun canonicalDisplayName(value: String): String =
        canonicalOrNull(value, 80) ?: throw UnprocessableProblem("The display name is invalid.")

    fun provisionalDisplayName(candidates: Sequence<String?>): String =
        candidates.mapNotNull { canonicalOrNull(it, 80) }.firstOrNull() ?: FALLBACK_DISPLAY_NAME

    fun provisionalUsername(value: String?): String? = canonicalOrNull(value, 40)

    fun safeVerifiedEmail(value: String?): String? {
        val candidate = value?.trim() ?: return null
        val separator = candidate.indexOf('@')
        return candidate.takeIf {
            it.length <= 320 &&
                separator > 0 &&
                separator == it.lastIndexOf('@') &&
                separator < it.lastIndex &&
                it.none { character -> character.isWhitespace() } &&
                it.none(::isUnsafeCharacter)
        }
    }

    private fun canonicalOrNull(value: String?, maxLength: Int): String? {
        val normalized = value?.let { Normalizer.normalize(it, Normalizer.Form.NFKC) }?.trim() ?: return null
        if (normalized.any(::isUnsafeCharacter)) {
            return null
        }
        val collapsed = normalized.replace(WHITESPACE, " ")
        return collapsed.takeIf { it.isNotEmpty() && it.length <= maxLength }
    }

    private fun isUnsafeCharacter(value: Char): Boolean = value.isISOControl() || value in BIDI_CONTROLS
}

data class ProfileSetupCommand(
    val displayName: String,
    val appLocale: String,
    val activeTargetLanguage: String,
    val preferredSupportLanguage: String,
    val timeZone: String,
)

private data class CanonicalProfileSetup(
    val displayName: String,
    val appLocale: String,
    val activeTargetLanguage: String,
    val preferredSupportLanguage: String,
    val timeZone: String,
)
