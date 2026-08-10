package com.kelimio.api.social

import com.kelimio.api.identityprofile.CurrentUserService
import jakarta.validation.Valid
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.Pattern
import org.springframework.http.CacheControl
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@Validated
@RestController
internal class PublicProfileController(
    private val currentUserService: CurrentUserService,
    private val service: PublicProfileService,
) {
    @GetMapping("/v1/me/public-profile")
    fun own(@AuthenticationPrincipal jwt: Jwt): ResponseEntity<OwnPublicProfileResponse> = noStore(
        service.own(currentUserService.requireCompleted(jwt)),
    )

    @PutMapping("/v1/me/public-profile")
    fun update(
        @AuthenticationPrincipal jwt: Jwt,
        @Valid @RequestBody request: UpdatePublicProfileRequest,
    ): ResponseEntity<OwnPublicProfileResponse> = noStore(
        service.update(currentUserService.requireCompleted(jwt), request),
    )

    @GetMapping("/v1/profiles/{username}")
    fun public(
        @PathVariable @Pattern(regexp = "^[a-z][a-z0-9_]{2,23}$") username: String,
    ): ResponseEntity<PublicProfileResponse> = noStore(service.public(username))

    @GetMapping("/v1/leaderboards/global")
    fun leaderboard(
        @RequestParam(defaultValue = "50") @Min(1) @Max(100) limit: Int,
    ): ResponseEntity<LeaderboardResponse> = noStore(service.leaderboard(limit))

    private fun <T> noStore(body: T): ResponseEntity<T> = ResponseEntity.ok()
        .cacheControl(CacheControl.noStore())
        .body(body)
}
