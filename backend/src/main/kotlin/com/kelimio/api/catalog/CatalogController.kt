package com.kelimio.api.catalog

import com.kelimio.api.identityprofile.CurrentUserService
import jakarta.validation.Valid
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.Pattern
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
import java.time.OffsetDateTime
import java.util.UUID

@Validated
@RestController
@RequestMapping("/v1")
class CatalogController(
    private val catalogService: CatalogService,
    private val currentUserService: CurrentUserService,
) {
    @GetMapping("/catalog/courses")
    fun listCourses(
        @AuthenticationPrincipal jwt: Jwt,
        @RequestParam(required = false) cursor: String?,
        @RequestParam(defaultValue = "20") @Min(1) @Max(100) limit: Int,
        @RequestParam(required = false) @Pattern(regexp = CANONICAL_LANGUAGE_TAG_PATTERN)
        targetLanguage: String?,
        @RequestParam(required = false) @Pattern(regexp = CANONICAL_LANGUAGE_TAG_PATTERN)
        supportLanguage: String?,
    ): CoursePageResponse = catalogService.list(
        currentUserService.resolve(jwt),
        cursor,
        targetLanguage,
        supportLanguage,
        limit,
    ).toResponse()

    @GetMapping("/courses/{courseId}")
    fun courseDetails(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
    ): CourseDetailResponse = catalogService.details(currentUserService.resolve(jwt), courseId).toResponse()

    @PostMapping("/courses/{courseId}/enrollments")
    fun enroll(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
        @RequestHeader("Idempotency-Key") idempotencyKey: UUID,
        @Valid @RequestBody request: EnrollmentRequest,
    ): ResponseEntity<EnrollmentResponse> {
        val result = catalogService.enroll(
            user = currentUserService.resolve(jwt),
            courseId = courseId,
            supportLanguage = request.supportLanguage,
            idempotencyKey = idempotencyKey,
        )
        val status = if (result.created) HttpStatus.CREATED else HttpStatus.OK
        return ResponseEntity.status(status).body(
            EnrollmentResponse(
                id = result.id,
                courseId = result.courseId,
                supportLanguage = result.supportLanguage,
                status = result.status,
                enrolledAt = result.enrolledAt,
            ),
        )
    }
}

data class EnrollmentRequest(
    @field:Pattern(regexp = CANONICAL_LANGUAGE_TAG_PATTERN)
    val supportLanguage: String,
)

private const val CANONICAL_LANGUAGE_TAG_PATTERN =
    "^[a-z]{2,8}(?:-[A-Z][a-z]{3})?(?:-(?:[A-Z]{2}|[0-9]{3}))?(?:-(?:[a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$"

data class EnrollmentResponse(
    val id: UUID,
    val courseId: UUID,
    val supportLanguage: String,
    val status: String,
    val enrolledAt: OffsetDateTime,
)

data class CoursePageResponse(
    val items: List<CourseSummaryResponse>,
    val nextCursor: String?,
)

data class CourseSummaryResponse(
    val id: UUID,
    val name: String,
    val description: String?,
    val targetLanguage: String,
    val supportLanguages: List<String>,
    val accessType: String,
    val visibility: String,
    val enrolled: Boolean,
)

data class CourseDetailResponse(
    val id: UUID,
    val name: String,
    val description: String?,
    val targetLanguage: String,
    val supportLanguages: List<String>,
    val accessType: String,
    val visibility: String,
    val enrolled: Boolean,
    val ownerDisplayName: String,
    val releaseId: UUID,
    val tests: List<TestSummaryResponse>,
)

data class TestSummaryResponse(
    val id: UUID,
    val revisionId: UUID,
    val name: String,
    val position: Int,
    val questionCount: Int,
)

private fun CatalogPage.toResponse() = CoursePageResponse(items.map { it.toResponse() }, nextCursor)

private fun CourseSummary.toResponse() = CourseSummaryResponse(
    id,
    name,
    description,
    targetLanguage,
    supportLanguages,
    accessType,
    visibility,
    enrolled,
)

private fun CourseDetails.toResponse() = CourseDetailResponse(
    id = course.id,
    name = course.name,
    description = course.description,
    targetLanguage = course.targetLanguage,
    supportLanguages = course.supportLanguages,
    accessType = course.accessType,
    visibility = course.visibility,
    enrolled = course.enrolled,
    ownerDisplayName = course.ownerDisplayName,
    releaseId = course.releaseId,
    tests = tests.map {
        TestSummaryResponse(it.id, it.revisionId, it.title, it.position, it.questionCount)
    },
)
