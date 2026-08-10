package com.kelimio.api.coursepublication

import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.teacher.TeacherAccessService
import jakarta.validation.Valid
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.http.CacheControl
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/v1/courses/{courseId}/releases")
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
internal class CourseReleaseController(
    private val currentUserService: CurrentUserService,
    private val teacherAccessService: TeacherAccessService,
    private val service: CourseReleaseService,
) {
    @GetMapping("/{releaseId}/impact")
    fun impact(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
        @PathVariable releaseId: UUID,
    ): ResponseEntity<CourseReleaseImpactResponse> {
        val user = currentUserService.requireCompleted(jwt)
        teacherAccessService.requireAuthorized(jwt, user)
        return noStore(HttpStatus.OK, service.impact(user, courseId, releaseId))
    }

    @PostMapping("/{releaseId}/activate")
    fun activate(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
        @PathVariable releaseId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
        @Valid @RequestBody request: ActivateCourseReleaseRequest,
    ): ResponseEntity<CourseReleaseActivationResponse> {
        val user = currentUserService.requireCompleted(jwt)
        teacherAccessService.requireAuthorized(jwt, user)
        val response = service.activate(
            user,
            courseId,
            releaseId,
            idempotencyKey,
            request,
        )
        return noStore(if (response.created) HttpStatus.CREATED else HttpStatus.OK, response)
    }

    private fun <T> noStore(status: HttpStatus, body: T): ResponseEntity<T> = ResponseEntity.status(status)
        .cacheControl(CacheControl.noStore())
        .body(body)
}
