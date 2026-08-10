package com.kelimio.api.importpipeline.intake

import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.teacher.TeacherAccessService
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.Size
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.http.CacheControl
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@Validated
@RestController
@RequestMapping("/v1/courses/imports")
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
class CourseImportController(
    private val currentUserService: CurrentUserService,
    private val service: CourseImportService,
    private val teacherAccessService: TeacherAccessService,
) {
    @GetMapping
    fun list(
        @AuthenticationPrincipal jwt: Jwt,
        @RequestParam(required = false) @Size(max = 512) cursor: String?,
        @RequestParam(defaultValue = "20") @Min(1) @Max(50) limit: Int,
    ): ResponseEntity<CourseImportStatusPage> = noStore(
        HttpStatus.OK,
        service.list(teacher(jwt), cursor, limit),
    )

    @PostMapping
    fun create(
        @AuthenticationPrincipal jwt: Jwt,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
        @RequestBody request: CreateCourseImportRequest,
    ): ResponseEntity<CourseImportUploadSessionResponse> {
        val response = service.create(teacher(jwt), idempotencyKey, request)
        return noStore(if (response.created) HttpStatus.CREATED else HttpStatus.OK, response)
    }

    @GetMapping("/{importId}")
    fun status(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable importId: UUID,
    ): ResponseEntity<CourseImportStatusResponse> = noStore(
        HttpStatus.OK,
        service.status(teacher(jwt), importId),
    )

    @PostMapping("/{importId}/complete")
    fun complete(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable importId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
        @RequestBody request: CompleteCourseImportUploadRequest,
    ): ResponseEntity<CourseImportStatusResponse> {
        val result = service.complete(teacher(jwt), importId, idempotencyKey, request)
        return noStore(if (result.created) HttpStatus.ACCEPTED else HttpStatus.OK, result.value)
    }

    @GetMapping("/{importId}/preview")
    fun preview(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable importId: UUID,
        @RequestParam(required = false) @Size(max = 512) cursor: String?,
        @RequestParam(defaultValue = "20") @Min(1) @Max(100) limit: Int,
    ): ResponseEntity<CourseImportPreviewPage> = noStore(
        HttpStatus.OK,
        service.preview(teacher(jwt), importId, cursor, limit),
    )

    @GetMapping("/{importId}/issues")
    fun issues(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable importId: UUID,
        @RequestParam(required = false) @Size(max = 512) cursor: String?,
        @RequestParam(defaultValue = "20") @Min(1) @Max(100) limit: Int,
    ): ResponseEntity<CourseImportIssuePage> = noStore(
        HttpStatus.OK,
        service.issues(teacher(jwt), importId, cursor, limit),
    )

    @PostMapping("/{importId}/approve")
    fun approve(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable importId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
        @RequestBody request: ApproveCourseImportRequest,
    ): ResponseEntity<CourseImportApprovalResponse> {
        val response = service.approve(teacher(jwt), importId, idempotencyKey, request)
        return noStore(if (response.created) HttpStatus.CREATED else HttpStatus.OK, response)
    }

    @PostMapping("/{importId}/commit")
    fun commit(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable importId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
        @RequestBody request: CommitCourseImportRequest,
    ): ResponseEntity<CourseImportCommitResponse> {
        val response = service.commit(teacher(jwt), importId, idempotencyKey, request)
        return noStore(if (response.created) HttpStatus.CREATED else HttpStatus.OK, response)
    }

    private fun teacher(jwt: Jwt): AppUser {
        val user = currentUserService.requireCompleted(jwt)
        teacherAccessService.requireAuthorized(jwt, user)
        return user
    }

    private fun <T> noStore(status: HttpStatus, body: T): ResponseEntity<T> = ResponseEntity.status(status)
        .cacheControl(CacheControl.noStore())
        .body(body)
}
