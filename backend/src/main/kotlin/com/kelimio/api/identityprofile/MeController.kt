package com.kelimio.api.identityprofile

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/v1/me")
class MeController(
    private val currentUserService: CurrentUserService,
    private val profileSetupService: ProfileSetupService,
) {
    @GetMapping
    fun me(@AuthenticationPrincipal jwt: Jwt): MeResponse =
        currentUserService.resolve(jwt).toResponse()

    @PostMapping("/profile-setup")
    fun completeProfileSetup(
        @AuthenticationPrincipal jwt: Jwt,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
        @Valid @RequestBody request: ProfileSetupRequest,
    ): MeResponse = profileSetupService.complete(
        currentUserService.resolve(jwt),
        idempotencyKey,
        ProfileSetupCommand(
            displayName = request.displayName,
            appLocale = request.appLocale,
            activeTargetLanguage = request.activeTargetLanguage,
            preferredSupportLanguage = request.preferredSupportLanguage,
            timeZone = request.timeZone,
        ),
    ).toResponse()
}

data class ProfileSetupRequest(
    @field:NotBlank
    @field:Size(max = 80)
    val displayName: String,
    @field:NotBlank
    @field:Size(max = 35)
    val appLocale: String,
    @field:NotBlank
    @field:Size(max = 35)
    val activeTargetLanguage: String,
    @field:NotBlank
    @field:Size(max = 35)
    val preferredSupportLanguage: String,
    @field:NotBlank
    @field:Size(max = 64)
    val timeZone: String,
)

data class MeResponse(
    val id: UUID,
    val displayName: String,
    val appLocale: String,
    val activeTargetLanguage: String,
    val preferredSupportLanguage: String?,
    val timeZone: String,
    val profileVersion: Long,
    val profileSetupStatus: ProfileSetupStatus,
)

enum class ProfileSetupStatus { REQUIRED, COMPLETE }

private fun AppUser.toResponse() = MeResponse(
    id = id,
    displayName = displayName,
    appLocale = appLocale,
    activeTargetLanguage = activeTargetLanguage,
    preferredSupportLanguage = preferredSupportLanguage,
    timeZone = timeZone,
    profileVersion = profileVersion,
    profileSetupStatus = if (profileSetupComplete) ProfileSetupStatus.COMPLETE else ProfileSetupStatus.REQUIRED,
)
