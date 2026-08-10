package com.kelimio.api.rewardedad

import com.kelimio.api.identityprofile.CurrentUserService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.http.CacheControl
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/v1/rewards/ads")
@ConditionalOnProperty(name = ["KELIMIO_REWARDED_AD_ENABLED"], havingValue = "true")
internal class RewardedAdController(
    private val currentUserService: CurrentUserService,
    private val service: RewardedAdService,
) {
    @PostMapping("/sessions")
    fun create(
        @AuthenticationPrincipal jwt: Jwt,
        @RequestHeader("Idempotency-Key") commandId: UUID,
    ): ResponseEntity<RewardedAdSessionResponse> {
        val response = service.create(currentUserService.requireCompleted(jwt), commandId)
        return ResponseEntity.status(if (response.created) HttpStatus.CREATED else HttpStatus.OK)
            .cacheControl(CacheControl.noStore())
            .body(response)
    }

    @GetMapping("/sessions/{sessionId}")
    fun status(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable sessionId: UUID,
    ): ResponseEntity<RewardedAdSessionStatusResponse> = ResponseEntity.ok()
        .cacheControl(CacheControl.noStore())
        .body(service.status(currentUserService.requireCompleted(jwt), sessionId))

    @GetMapping("/ssv", produces = [MediaType.TEXT_PLAIN_VALUE])
    fun callback(request: HttpServletRequest): ResponseEntity<String> {
        service.processCallback(request.queryString ?: "")
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body("ok")
    }
}
