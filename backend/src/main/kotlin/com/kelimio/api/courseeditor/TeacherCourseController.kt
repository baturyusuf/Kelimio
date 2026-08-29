package com.kelimio.api.courseeditor

import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.persistence.CourseReleases
import com.kelimio.api.persistence.Courses
import com.kelimio.api.progress.TeacherCourseAnalyticsMetrics
import com.kelimio.api.progress.TeacherCourseAnalyticsQuery
import com.kelimio.api.progress.TeacherCourseAnalyticsSnapshot
import com.kelimio.api.progress.TeacherCoursePerformance
import com.kelimio.api.teacher.TeacherAccessService
import com.kelimio.api.web.NotFoundProblem
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import org.jooq.DSLContext
import org.jooq.impl.DSL.noCondition
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.http.CacheControl
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.stereotype.Repository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.OffsetDateTime
import java.util.UUID

@Validated
@RestController
@RequestMapping("/v1/teacher/courses")
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
internal class TeacherCourseController(
    private val currentUserService: CurrentUserService,
    private val service: TeacherCourseService,
) {
    @GetMapping
    fun list(
        @AuthenticationPrincipal jwt: Jwt,
        @RequestParam(required = false) cursor: UUID?,
        @RequestParam(defaultValue = "20") @Min(1) @Max(100) limit: Int,
    ): TeacherCoursePageResponse = service.list(jwt, currentUserService.requireCompleted(jwt), cursor, limit)

    @GetMapping("/{courseId}/analytics")
    fun analytics(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
    ): ResponseEntity<TeacherCourseAnalyticsResponse> = ResponseEntity.ok()
        .cacheControl(CacheControl.noStore())
        .body(service.analytics(jwt, currentUserService.requireCompleted(jwt), courseId))
}

internal data class TeacherCoursePageResponse(
    val items: List<TeacherCourseSummaryResponse>,
    val nextCursor: UUID?,
)

internal data class TeacherCourseSummaryResponse(
    val id: UUID,
    val name: String,
    val description: String?,
    val targetLanguage: String,
    val defaultSupportLanguage: String,
    val visibility: String,
    val publicationStatus: String,
    val activeReleaseId: UUID,
    val activeReleaseRevision: Int,
    val hasOpenDraft: Boolean,
    val openDraftReleaseId: UUID?,
    val createdAt: OffsetDateTime,
)

internal data class TeacherCourseAnalyticsResponse(
    val courseId: UUID,
    val courseReleaseId: UUID,
    val updating: Boolean,
    val metrics: TeacherCourseAnalyticsMetricsResponse?,
    val updatedAt: OffsetDateTime?,
)

internal data class TeacherCourseAnalyticsMetricsResponse(
    val learnersWithRecordedActivity: Int,
    val performance: TeacherCoursePerformanceResponse?,
)

internal data class TeacherCoursePerformanceResponse(
    val answeredQuestions: Long,
    val correctAnswers: Long,
    val completedAttempts: Long,
    val passedAttempts: Long,
)

@Service
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
internal class TeacherCourseService(
    private val repository: TeacherCourseRepository,
    private val teacherAccessService: TeacherAccessService,
    private val analyticsQuery: TeacherCourseAnalyticsQuery,
) {
    @Transactional(readOnly = true)
    fun list(jwt: Jwt, user: AppUser, cursor: UUID?, limit: Int): TeacherCoursePageResponse {
        teacherAccessService.requireAuthorized(jwt, user)
        val rows = repository.list(user.id, cursor, limit + 1)
        val items = rows.take(limit)
        return TeacherCoursePageResponse(
            items = items,
            nextCursor = items.lastOrNull()?.id?.takeIf { rows.size > limit },
        )
    }

    @Transactional(readOnly = true)
    fun analytics(jwt: Jwt, user: AppUser, courseId: UUID): TeacherCourseAnalyticsResponse {
        teacherAccessService.requireAuthorized(jwt, user)
        val activeReleaseId = repository.findOwnedActiveRelease(user.id, courseId)
            ?: throw NotFoundProblem("Course was not found.")
        return analyticsQuery.get(courseId, activeReleaseId).toResponse()
    }
}

@Repository
internal class TeacherCourseRepository(private val dsl: DSLContext) {
    fun findOwnedActiveRelease(ownerUserId: UUID, courseId: UUID): UUID? = dsl.fetchOne(
        "select active_release_id from course where id = ? and owner_user_id = ?",
        courseId,
        ownerUserId,
    )?.get("active_release_id", UUID::class.java)

    fun list(ownerUserId: UUID, cursor: UUID?, limit: Int): List<TeacherCourseSummaryResponse> {
        val cursorCondition = cursor?.let { Courses.ID.gt(it) } ?: noCondition()
        val openDraftReleaseId = org.jooq.impl.DSL.field(
            "(select draft.id from course_release draft where draft.course_id = {0} and draft.status = 'DRAFT' limit 1)",
            UUID::class.java,
            Courses.ID,
        )
        return dsl.select(
            Courses.ID,
            Courses.NAME,
            Courses.DESCRIPTION,
            Courses.TARGET_LANGUAGE,
            Courses.DEFAULT_SUPPORT_LANGUAGE,
            Courses.VISIBILITY,
            Courses.STATUS,
            Courses.ACTIVE_RELEASE_ID,
            CourseReleases.REVISION_NUMBER,
            openDraftReleaseId,
            Courses.CREATED_AT,
        ).from(Courses.TABLE)
            .join(CourseReleases.TABLE)
            .on(CourseReleases.ID.eq(Courses.ACTIVE_RELEASE_ID))
            .and(CourseReleases.COURSE_ID.eq(Courses.ID))
            .where(Courses.OWNER_ID.eq(ownerUserId))
            .and(cursorCondition)
            .orderBy(Courses.ID.asc())
            .limit(limit)
            .fetch {
                TeacherCourseSummaryResponse(
                    id = it.get(Courses.ID)!!,
                    name = it.get(Courses.NAME)!!,
                    description = it.get(Courses.DESCRIPTION),
                    targetLanguage = it.get(Courses.TARGET_LANGUAGE)!!,
                    defaultSupportLanguage = it.get(Courses.DEFAULT_SUPPORT_LANGUAGE)!!,
                    visibility = it.get(Courses.VISIBILITY)!!,
                    publicationStatus = it.get(Courses.STATUS)!!,
                    activeReleaseId = it.get(Courses.ACTIVE_RELEASE_ID)!!,
                    activeReleaseRevision = it.get(CourseReleases.REVISION_NUMBER)!!,
                    hasOpenDraft = it.get(openDraftReleaseId) != null,
                    openDraftReleaseId = it.get(openDraftReleaseId),
                    createdAt = it.get(Courses.CREATED_AT)!!,
                )
            }
    }
}

private fun TeacherCourseAnalyticsSnapshot.toResponse() = TeacherCourseAnalyticsResponse(
    courseId = courseId,
    courseReleaseId = courseReleaseId,
    updating = updating,
    metrics = metrics?.toResponse(),
    updatedAt = updatedAt,
)

private fun TeacherCourseAnalyticsMetrics.toResponse() = TeacherCourseAnalyticsMetricsResponse(
    learnersWithRecordedActivity = learnersWithRecordedActivity,
    performance = performance?.toResponse(),
)

private fun TeacherCoursePerformance.toResponse() = TeacherCoursePerformanceResponse(
    answeredQuestions = answeredQuestions,
    correctAnswers = correctAnswers,
    completedAttempts = completedAttempts,
    passedAttempts = passedAttempts,
)
