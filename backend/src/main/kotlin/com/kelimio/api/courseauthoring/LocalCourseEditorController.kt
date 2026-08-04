package com.kelimio.api.courseauthoring

import com.kelimio.api.identityprofile.CurrentUserService
import jakarta.validation.Valid
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
@RequestMapping("/v1/development/courses/{courseId}/editor")
internal class LocalCourseEditorController(
    private val currentUserService: CurrentUserService,
    private val service: SubsequentCourseDraftService,
) {
    @GetMapping
    fun get(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
    ): ResponseEntity<LocalCourseEditorSnapshot> {
        val document = service.editor(currentUserService.requireCompleted(jwt), courseId)
        return ResponseEntity.ok()
            .cacheControl(CacheControl.noStore())
            .eTag(document.entityTag)
            .body(document.snapshot)
    }

    @PostMapping("/drafts")
    fun createDraft(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
        @RequestHeader("If-Match") ifMatch: String,
        @Valid @RequestBody request: CreateLocalCourseEditorDraftRequest,
    ): ResponseEntity<SubsequentCourseDraftResult> {
        val result = service.createEdited(
            currentUserService.requireCompleted(jwt),
            courseId,
            idempotencyKey,
            ifMatch,
            request,
        )
        return ResponseEntity.status(if (result.created) HttpStatus.CREATED else HttpStatus.OK)
            .cacheControl(CacheControl.noStore())
            .body(result)
    }
}
