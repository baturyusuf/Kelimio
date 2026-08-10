package com.kelimio.api.teacher

import com.kelimio.api.identityprofile.CurrentUserService
import jakarta.validation.Valid
import org.springframework.http.CacheControl
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/v1/teacher/access")
internal class TeacherAccessController(
    private val currentUserService: CurrentUserService,
    private val service: TeacherAccessService,
) {
    @GetMapping
    fun status(@AuthenticationPrincipal jwt: Jwt): ResponseEntity<TeacherAccessResponse> {
        val user = currentUserService.requireCompleted(jwt)
        return noStore(service.status(jwt, user))
    }

    @PostMapping("/terms-acceptance")
    fun accept(
        @AuthenticationPrincipal jwt: Jwt,
        @Valid @RequestBody request: AcceptTeacherTermsRequest,
    ): ResponseEntity<TeacherAccessResponse> {
        val user = currentUserService.requireCompleted(jwt)
        return noStore(service.accept(jwt, user, request))
    }

    private fun <T> noStore(body: T): ResponseEntity<T> = ResponseEntity.ok()
        .cacheControl(CacheControl.noStore())
        .body(body)
}
