package com.kelimio.api.development

import com.kelimio.api.identityprofile.CurrentUserService
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/v1/development/starter-course")
class LocalStarterCourseController(
    private val currentUserService: CurrentUserService,
    private val service: LocalStarterCourseService,
    @Value("\${KELIMIO_ENVIRONMENT}") private val environment: String,
) {
    @PostMapping
    fun install(
        @AuthenticationPrincipal jwt: Jwt,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
    ): ResponseEntity<LocalStarterCourseResponse> {
        val productionInternalTesterAuthorized = InternalTesterPolicy.canInstallStarterCourse(
            environment = environment,
            groups = jwt.getClaimAsStringList("cognito:groups").orEmpty(),
        )
        val result = service.install(
            user = currentUserService.requireCompleted(jwt),
            idempotencyKey = idempotencyKey,
            productionInternalTesterAuthorized = productionInternalTesterAuthorized,
        )
        val status = if (result.created) HttpStatus.CREATED else HttpStatus.OK
        return ResponseEntity.status(status).body(
            LocalStarterCourseResponse(
                courseId = result.courseId,
                created = result.created,
                sourceWorkbookSha256 = result.sourceWorkbookSha256,
            ),
        )
    }
}

data class LocalStarterCourseResponse(
    val courseId: UUID,
    val created: Boolean,
    val sourceWorkbookSha256: String,
)
