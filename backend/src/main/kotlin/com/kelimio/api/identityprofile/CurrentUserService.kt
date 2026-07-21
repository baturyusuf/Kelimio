package com.kelimio.api.identityprofile

import com.kelimio.api.web.ForbiddenProblem
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
        val username = jwt.getClaimAsString("preferred_username")
            ?.takeIf { it.isNotBlank() }
            ?.take(40)
        val displayName = sequenceOf(
            jwt.getClaimAsString("preferred_username"),
            jwt.getClaimAsString("name"),
            jwt.getClaimAsString("email")?.substringBefore('@'),
            subject,
        ).first { !it.isNullOrBlank() }!!.take(80)
        val appLocale = languageTagNormalizer.normalizeOrNull(jwt.getClaimAsString("locale")) ?: "tr"
        val activeTargetLanguage =
            languageTagNormalizer.normalizeOrNull(jwt.getClaimAsString("kelimio_target_language")) ?: "tr"
        return repository.findOrCreate(
            subject,
            jwt.getClaimAsString("email"),
            displayName,
            username,
            appLocale,
            activeTargetLanguage,
        )
    }

}
