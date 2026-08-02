package com.kelimio.api.coursepublication

import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.util.UUID

@Repository
class CourseReleaseReprojectionRepository(
    private val dsl: DSLContext,
) {
    fun findCandidates(limit: Int): List<CourseReleaseReprojectionCandidate> = dsl.fetch(
        """
        select activation_id
          from course_release_reprojection_job
         where status in ('PENDING', 'FAILED') and attempt_count < ?
         order by created_at, activation_id
         limit ?
        """.trimIndent(),
        MAX_ATTEMPTS,
        limit,
    ).map { CourseReleaseReprojectionCandidate(it.get("activation_id", UUID::class.java)!!) }

    fun lockJob(activationId: UUID): CourseReleaseReprojectionJob? = dsl.fetchOne(
        """
        select activation_id, course_id, target_release_id, outbox_event_id,
               enrollment_cutoff_at, status, cursor_enrolled_at, cursor_enrollment_id
          from course_release_reprojection_job
         where activation_id = ?
         for update
        """.trimIndent(),
        activationId,
    )?.let {
        CourseReleaseReprojectionJob(
            activationId = it.get("activation_id", UUID::class.java)!!,
            courseId = it.get("course_id", UUID::class.java)!!,
            targetReleaseId = it.get("target_release_id", UUID::class.java)!!,
            outboxEventId = it.get("outbox_event_id", UUID::class.java)!!,
            enrollmentCutoffAt = it.get("enrollment_cutoff_at", OffsetDateTime::class.java)!!,
            status = it.get("status", String::class.java)!!,
            cursorEnrolledAt = it.get("cursor_enrolled_at", OffsetDateTime::class.java),
            cursorEnrollmentId = it.get("cursor_enrollment_id", UUID::class.java),
        )
    }

    fun lockActiveRelease(courseId: UUID): UUID? = dsl.fetchOne(
        "select active_release_id from course where id = ? for share",
        courseId,
    )?.get("active_release_id", UUID::class.java)

    fun enrollmentPage(job: CourseReleaseReprojectionJob, limit: Int): List<CourseReleaseReprojectionEnrollment> {
        val baseSql = """
            select id, user_id, enrolled_at
              from enrollment
             where course_id = ?
               and status = 'ACTIVE'
               and enrolled_at <= cast(? as timestamptz)
        """.trimIndent()
        val result = if (job.cursorEnrolledAt == null) {
            dsl.fetch(
                "$baseSql order by enrolled_at, id limit ?",
                job.courseId,
                job.enrollmentCutoffAt,
                limit,
            )
        } else {
            dsl.fetch(
                """
                $baseSql
                   and (enrolled_at, id) > (cast(? as timestamptz), ?)
                 order by enrolled_at, id
                 limit ?
                """.trimIndent(),
                job.courseId,
                job.enrollmentCutoffAt,
                job.cursorEnrolledAt,
                checkNotNull(job.cursorEnrollmentId),
                limit,
            )
        }
        return result.map {
            CourseReleaseReprojectionEnrollment(
                enrollmentId = it.get("id", UUID::class.java)!!,
                userId = it.get("user_id", UUID::class.java)!!,
                enrolledAt = it.get("enrolled_at", OffsetDateTime::class.java)!!,
            )
        }
    }

    fun advance(
        job: CourseReleaseReprojectionJob,
        cursor: CourseReleaseReprojectionEnrollment,
        processedCount: Int,
        now: OffsetDateTime,
    ) {
        check(
            dsl.execute(
                """
                update course_release_reprojection_job
                   set status = 'PENDING', cursor_enrolled_at = cast(? as timestamptz),
                       cursor_enrollment_id = ?, processed_count = processed_count + ?,
                       last_error_type = null, updated_at = cast(? as timestamptz)
                 where activation_id = ? and status in ('PENDING', 'FAILED')
                """.trimIndent(),
                cursor.enrolledAt,
                cursor.enrollmentId,
                processedCount,
                now,
                job.activationId,
            ) == 1,
        ) { "Release reprojection cursor did not advance exactly once" }
    }

    fun complete(job: CourseReleaseReprojectionJob, now: OffsetDateTime) {
        check(
            dsl.execute(
                """
                update course_release_reprojection_job
                   set status = 'COMPLETED', completed_at = cast(? as timestamptz),
                       last_error_type = null, updated_at = cast(? as timestamptz)
                 where activation_id = ? and status in ('PENDING', 'FAILED')
                """.trimIndent(),
                now,
                now,
                job.activationId,
            ) == 1,
        ) { "Release reprojection job did not complete exactly once" }
    }

    fun recordFailure(activationId: UUID, errorType: String, now: OffsetDateTime) {
        dsl.execute(
            """
            update course_release_reprojection_job
               set attempt_count = least(attempt_count + 1, ?),
                   status = case when attempt_count + 1 >= ? then 'DEAD' else 'FAILED' end,
                   last_error_type = ?, completed_at = null, updated_at = cast(? as timestamptz)
             where activation_id = ? and status in ('PENDING', 'FAILED')
            """.trimIndent(),
            MAX_ATTEMPTS,
            MAX_ATTEMPTS,
            errorType.take(500),
            now,
            activationId,
        )
    }

    companion object {
        const val MAX_ATTEMPTS = 5
    }
}
