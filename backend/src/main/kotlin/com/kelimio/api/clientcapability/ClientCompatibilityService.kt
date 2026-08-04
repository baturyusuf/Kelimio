package com.kelimio.api.clientcapability

import com.kelimio.api.persistence.Attempts
import com.kelimio.api.persistence.CourseReleases
import com.kelimio.api.persistence.CourseReleaseTestRevisions
import com.kelimio.api.persistence.Courses
import com.kelimio.api.persistence.Enrollments
import com.kelimio.api.web.ClientUpgradeRequiredProblem
import org.jooq.DSLContext
import org.jooq.impl.DSL.field
import org.jooq.impl.DSL.name
import org.jooq.impl.DSL.table
import org.springframework.stereotype.Repository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class ClientCompatibilityService(
    private val repository: ClientCompatibilityRepository,
) {
    @Transactional(readOnly = true)
    fun requireRelease(releaseId: UUID, advertised: Set<String>) {
        if (!advertised.containsAll(repository.requiredCapabilities(releaseId))) {
            throw ClientUpgradeRequiredProblem()
        }
    }

    @Transactional(readOnly = true)
    fun requirePublishedTest(testId: UUID, userId: UUID, advertised: Set<String>) {
        repository.publishedReleaseForEnrolledTest(testId, userId)?.let { requireRelease(it, advertised) }
    }

    @Transactional(readOnly = true)
    fun requireOwnedAttempt(attemptId: UUID, userId: UUID, advertised: Set<String>) {
        repository.releaseForOwnedAttempt(attemptId, userId)?.let { requireRelease(it, advertised) }
    }
}

@Repository
class ClientCompatibilityRepository(
    private val dsl: DSLContext,
) {
    fun requiredCapabilities(releaseId: UUID): Set<String> =
        dsl.select(CAPABILITY)
            .from(RELEASE_CAPABILITIES)
            .where(RELEASE_ID.eq(releaseId))
            .orderBy(CAPABILITY.asc())
            .fetchSet(CAPABILITY)

    fun publishedReleaseForEnrolledTest(testId: UUID, userId: UUID): UUID? =
        dsl.select(CourseReleaseTestRevisions.COURSE_RELEASE_ID)
            .from(CourseReleaseTestRevisions.TABLE)
            .join(CourseReleases.TABLE)
            .on(CourseReleases.ID.eq(CourseReleaseTestRevisions.COURSE_RELEASE_ID))
            .join(Courses.TABLE)
            .on(Courses.ID.eq(CourseReleases.COURSE_ID))
            .and(Courses.ACTIVE_RELEASE_ID.eq(CourseReleases.ID))
            .join(Enrollments.TABLE)
            .on(Enrollments.COURSE_ID.eq(Courses.ID))
            .where(CourseReleaseTestRevisions.TEST_ID.eq(testId))
            .and(CourseReleases.STATUS.eq("ACTIVE"))
            .and(Courses.STATUS.eq("PUBLISHED"))
            .and(Enrollments.USER_ID.eq(userId))
            .and(Enrollments.STATUS.eq("ACTIVE"))
            .fetchOne(CourseReleaseTestRevisions.COURSE_RELEASE_ID)

    fun releaseForOwnedAttempt(attemptId: UUID, userId: UUID): UUID? =
        dsl.select(Attempts.COURSE_RELEASE_ID)
            .from(Attempts.TABLE)
            .where(Attempts.ID.eq(attemptId))
            .and(Attempts.USER_ID.eq(userId))
            .fetchOne(Attempts.COURSE_RELEASE_ID)

    private companion object {
        val RELEASE_CAPABILITIES = table(name("course_release_required_capability"))
        val RELEASE_ID = field(name("course_release_required_capability", "course_release_id"), UUID::class.java)
        val CAPABILITY = field(name("course_release_required_capability", "capability"), String::class.java)
    }
}
