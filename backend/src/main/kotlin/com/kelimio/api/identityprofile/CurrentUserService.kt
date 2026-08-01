package com.kelimio.api.identityprofile

import com.kelimio.api.web.ForbiddenProblem
import com.kelimio.api.web.ProfileSetupRequiredProblem
import com.kelimio.api.language.LanguageTagNormalizer
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class CurrentUserService(
    private val repository: IdentityProfileRepository,
    private val languageTagNormalizer: LanguageTagNormalizer,
) {
    @Transactional
    fun resolve(jwt: Jwt): AppUser {
        val subject = jwt.subject?.takeIf { it.isNotBlank() }
            ?: throw ForbiddenProblem("The access token has no usable subject.")
        val rawEmail = jwt.getClaimAsString("email")
        val verifiedEmail = jwt.getClaimAsBoolean("email_verified")
            .takeIf { it == true }
            ?.let { ProfileTextPolicy.safeVerifiedEmail(rawEmail) }
        val rawUsername = jwt.getClaimAsString("preferred_username")
            ?.takeUnless { verifiedEmail == null && it.equals(rawEmail, ignoreCase = true) }
        val username = ProfileTextPolicy.provisionalUsername(rawUsername)
        val displayName = ProfileTextPolicy.provisionalDisplayName(
            sequenceOf(
                jwt.getClaimAsString("name")
                    ?.takeUnless { verifiedEmail == null && it.equals(rawEmail, ignoreCase = true) },
                username,
                verifiedEmail?.substringBefore('@'),
            ),
        )
        val tokenLocale = languageTagNormalizer.normalizeOrNull(jwt.getClaimAsString("locale"))
        val appLocale = tokenLocale?.substringBefore('-')
            ?.takeIf(ProfileSetupService.SUPPORTED_APP_LOCALES::contains)
            ?: "tr"
        val activeTargetLanguage =
            languageTagNormalizer.normalizeOrNull(jwt.getClaimAsString("kelimio_target_language")) ?: "tr"
        return repository.findOrCreate(
            subject,
            verifiedEmail,
            displayName,
            username,
            appLocale,
            activeTargetLanguage,
        )
    }

    @Transactional
    fun requireCompleted(jwt: Jwt): AppUser = resolve(jwt).also {
        if (!it.profileSetupComplete) {
            throw ProfileSetupRequiredProblem()
        }
    }
}
