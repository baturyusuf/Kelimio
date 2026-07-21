package com.kelimio.api.identityprofile

import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/v1/me")
class MeController(
    private val currentUserService: CurrentUserService,
) {
    @GetMapping
    fun me(@AuthenticationPrincipal jwt: Jwt): MeResponse =
        currentUserService.resolve(jwt).let {
            MeResponse(
                id = it.id,
                subject = it.subject,
                displayName = it.displayName,
                username = it.username,
                appLocale = it.appLocale,
                activeTargetLanguage = it.activeTargetLanguage,
            )
        }
}

data class MeResponse(
    val id: UUID,
    val subject: String,
    val displayName: String,
    val username: String?,
    val appLocale: String,
    val activeTargetLanguage: String,
)
