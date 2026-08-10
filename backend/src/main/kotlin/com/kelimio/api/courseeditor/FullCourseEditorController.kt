package com.kelimio.api.courseeditor

import com.kelimio.api.identityprofile.CurrentUserService
import jakarta.validation.Valid
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.http.CacheControl
import org.springframework.http.HttpHeaders
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
@RequestMapping("/v1/teacher/courses/{courseId}/editor")
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
internal class FullCourseEditorController(
    private val currentUserService: CurrentUserService,
    private val service: FullCourseEditorService,
) {
    @GetMapping
    fun document(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
    ): ResponseEntity<FullCourseEditorDocument> {
        val snapshot = service.document(jwt, currentUserService.requireCompleted(jwt), courseId)
        return ResponseEntity.ok()
            .cacheControl(CacheControl.noStore())
            .header(HttpHeaders.ETAG, snapshot.entityTag)
            .body(snapshot.document)
    }

    @PostMapping("/drafts")
    fun createDraft(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
        @RequestHeader(HttpHeaders.IF_MATCH) ifMatch: String,
        @Valid @RequestBody request: SaveFullCourseEditorDraftRequest,
    ): ResponseEntity<FullCourseEditorDraftResponse> {
        val response = service.createDraft(
            jwt = jwt,
            user = currentUserService.requireCompleted(jwt),
            courseId = courseId,
            idempotencyKey = idempotencyKey,
            ifMatch = ifMatch,
            request = request,
        )
        return ResponseEntity.status(if (response.created) HttpStatus.CREATED else HttpStatus.OK)
            .cacheControl(CacheControl.noStore())
            .body(response)
    }
}
