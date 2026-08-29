package com.kelimio.api.progress

import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import org.springframework.stereotype.Service
import java.time.OffsetDateTime
import java.util.UUID

interface TeacherCourseAnalyticsQuery {
    fun get(courseId: UUID, activeCourseReleaseId: UUID): TeacherCourseAnalyticsSnapshot
}

data class TeacherCourseAnalyticsSnapshot(
    val courseId: UUID,
    val courseReleaseId: UUID,
    val updating: Boolean,
    val metrics: TeacherCourseAnalyticsMetrics?,
    val updatedAt: OffsetDateTime?,
)

data class TeacherCourseAnalyticsMetrics(
    val learnersWithRecordedActivity: Int,
    val performance: TeacherCoursePerformance?,
)

data class TeacherCoursePerformance(
    val answeredQuestions: Long,
    val correctAnswers: Long,
    val completedAttempts: Long,
    val passedAttempts: Long,
)

@Service
internal class ProjectedTeacherCourseAnalyticsQuery(
    private val repository: TeacherCourseAnalyticsProjectionRepository,
) : TeacherCourseAnalyticsQuery {
    override fun get(courseId: UUID, activeCourseReleaseId: UUID): TeacherCourseAnalyticsSnapshot {
        if (repository.hasUnresolvedWork(courseId, activeCourseReleaseId)) {
            return TeacherCourseAnalyticsSnapshot(
                courseId = courseId,
                courseReleaseId = activeCourseReleaseId,
                updating = true,
                metrics = null,
                updatedAt = null,
            )
        }
        val aggregate = repository.aggregate(courseId, activeCourseReleaseId)
        return TeacherCourseAnalyticsSnapshot(
            courseId = courseId,
            courseReleaseId = activeCourseReleaseId,
            updating = false,
            metrics = TeacherCourseAnalyticsMetrics(
                learnersWithRecordedActivity = aggregate.learnersWithRecordedActivity,
                performance = aggregate.takeIf {
                    it.learnersWithRecordedActivity >= MINIMUM_PERFORMANCE_COHORT
                }?.let {
                    TeacherCoursePerformance(
                        answeredQuestions = it.answeredQuestions,
                        correctAnswers = it.correctAnswers,
                        completedAttempts = it.completedAttempts,
                        passedAttempts = it.passedAttempts,
                    )
                },
            ),
            updatedAt = aggregate.updatedAt,
        )
    }

    private companion object {
        const val MINIMUM_PERFORMANCE_COHORT = 3
    }
}

internal data class TeacherCourseAnalyticsAggregate(
    val learnersWithRecordedActivity: Int,
    val answeredQuestions: Long,
    val correctAnswers: Long,
    val completedAttempts: Long,
    val passedAttempts: Long,
    val updatedAt: OffsetDateTime?,
)

@Repository
internal class TeacherCourseAnalyticsProjectionRepository(
    private val dsl: DSLContext,
) {
    fun hasUnresolvedWork(courseId: UUID, activeCourseReleaseId: UUID): Boolean = dsl.fetchOne(
        """
        select
            exists (
                select 1
                  from outbox_event event
                  join test_attempt attempt on attempt.id = event.aggregate_id
                  left join outbox_consumer_delivery delivery
                    on delivery.event_id = event.id and delivery.consumer_name = ?
                 where attempt.course_id = ?
                   and event.event_type in ('learning.answer-recorded.v1', 'learning.attempt-finished.v1')
                   and (delivery.event_id is null or delivery.status <> 'PROCESSED')
            )
            or coalesce((
                select job.status <> 'COMPLETED'
                  from course_release_reprojection_job job
                 where job.course_id = ? and job.target_release_id = ?
                 order by job.created_at desc, job.activation_id desc
                 limit 1
            ), false) as unresolved
        """.trimIndent(),
        LearningProgressProjectionRepository.CONSUMER_NAME,
        courseId,
        courseId,
        activeCourseReleaseId,
    )?.get("unresolved", Boolean::class.java) ?: true

    fun aggregate(courseId: UUID, activeCourseReleaseId: UUID): TeacherCourseAnalyticsAggregate {
        val row = checkNotNull(
            dsl.fetchOne(
                """
                select count(*) as learners_with_recorded_activity,
                       coalesce(sum(answered_questions), 0) as answered_questions,
                       coalesce(sum(correct_answers), 0) as correct_answers,
                       coalesce(sum(completed_attempts), 0) as completed_attempts,
                       coalesce(sum(passed_attempts), 0) as passed_attempts,
                       max(updated_at) as updated_at
                  from learner_course_progress_projection
                 where course_id = ? and course_release_id = ?
                """.trimIndent(),
                courseId,
                activeCourseReleaseId,
            ),
        )
        return TeacherCourseAnalyticsAggregate(
            learnersWithRecordedActivity = row.get("learners_with_recorded_activity", Long::class.java)!!.toInt(),
            answeredQuestions = row.get("answered_questions", Long::class.java)!!,
            correctAnswers = row.get("correct_answers", Long::class.java)!!,
            completedAttempts = row.get("completed_attempts", Long::class.java)!!,
            passedAttempts = row.get("passed_attempts", Long::class.java)!!,
            updatedAt = row.get("updated_at", OffsetDateTime::class.java),
        )
    }
}
