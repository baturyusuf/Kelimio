package com.kelimio.api.catalog

import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.language.InvalidLanguageTagException
import com.kelimio.api.language.LanguageTagNormalizer
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.ForbiddenProblem
import com.kelimio.api.web.NotFoundProblem
import com.kelimio.api.web.UnprocessableProblem
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class CatalogService(
    private val repository: CatalogRepository,
    private val idempotencyService: IdempotencyService,
    private val languageTagNormalizer: LanguageTagNormalizer,
) {
    @Transactional(readOnly = true)
    fun list(
        user: AppUser,
        cursor: String?,
        targetLanguage: String?,
        supportLanguage: String?,
        limit: Int,
    ): CatalogPage {
        val parsedCursor = cursor?.let {
            runCatching { UUID.fromString(it) }.getOrElse {
                throw UnprocessableProblem("The catalog cursor is invalid.")
            }
        }
        val canonicalTargetLanguage = targetLanguage?.let { normalizeLanguageTag(it, "targetLanguage") }
        val canonicalSupportLanguage = supportLanguage?.let { normalizeLanguageTag(it, "supportLanguage") }
        val rows = repository.listPublicCourses(
            user.id,
            parsedCursor,
            canonicalTargetLanguage,
            canonicalSupportLanguage,
            limit + 1,
        )
        val hasNext = rows.size > limit
        val items = rows.take(limit)
        return CatalogPage(items, items.lastOrNull()?.id?.toString()?.takeIf { hasNext })
    }

    @Transactional(readOnly = true)
    fun details(
        user: AppUser,
        courseId: UUID,
    ): CourseDetails {
        val course = repository.findPublishedCourse(courseId, user.id)
            ?: throw NotFoundProblem("Course was not found.")
        val visibility = repository.findVisibility(courseId)
        if (visibility != "PUBLIC" && !course.enrolled) {
            throw ForbiddenProblem("Private courses require an invitation.")
        }
        return CourseDetails(course, repository.findActiveTests(courseId))
    }

    @Transactional
    fun enroll(
        user: AppUser,
        courseId: UUID,
        supportLanguage: String,
        idempotencyKey: UUID,
    ): EnrollmentResult {
        val canonicalSupportLanguage = normalizeLanguageTag(supportLanguage, "supportLanguage")
        val lookup = idempotencyService.lockAndFind(
            user.id,
            "catalog.enroll",
            idempotencyKey,
            "$courseId|$canonicalSupportLanguage",
        )
        lookup.resourceId?.let { enrollmentId ->
            return repository.findEnrollment(enrollmentId)
                ?: throw ConflictProblem("The idempotent enrollment no longer exists.")
        }
        val course = repository.findPublishedCourse(courseId, user.id)
            ?: throw NotFoundProblem("Course was not found.")
        if (repository.findVisibility(courseId) != "PUBLIC") {
            throw ForbiddenProblem("Private courses require an invitation.")
        }
        if (course.accessType != "FREE") {
            throw ConflictProblem("A verified store entitlement is required for this course.")
        }
        if (!repository.supportsLanguage(courseId, canonicalSupportLanguage)) {
            throw UnprocessableProblem("The course does not support the requested support language.")
        }
        val result = repository.createEnrollment(courseId, user.id, canonicalSupportLanguage)
        if (result.status != "ACTIVE") {
            throw ConflictProblem("The existing enrollment is not active and cannot be reactivated by this endpoint.")
        }
        idempotencyService.record(
            user.id,
            "catalog.enroll",
            idempotencyKey,
            lookup.fingerprint,
            result.id,
        )
        return result
    }

    private fun normalizeLanguageTag(
        value: String,
        field: String,
    ): String =
        try {
            languageTagNormalizer.normalize(value)
        } catch (_: InvalidLanguageTagException) {
            throw UnprocessableProblem("$field is not a supported BCP 47 language tag.")
        }
}

data class CatalogPage(
    val items: List<CourseSummary>,
    val nextCursor: String?,
)
