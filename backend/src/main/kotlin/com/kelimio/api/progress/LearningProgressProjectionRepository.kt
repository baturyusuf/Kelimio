package com.kelimio.api.progress

import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.util.UUID

@Repository
class LearningProgressProjectionRepository(
    private val dsl: DSLContext,
) {
    fun findCandidates(limit: Int): List<LearningProgressProjectionEvent> =
        dsl.fetch(
            """
            select e.id, e.aggregate_id
              from outbox_event e
              left join outbox_consumer_delivery d
                on d.event_id = e.id and d.consumer_name = ?
             where e.event_type in ('learning.answer-recorded.v1', 'learning.attempt-finished.v1')
               and (
                    d.event_id is null
                    or (d.status = 'FAILED' and d.attempt_count < ?)
               )
             order by e.occurred_at, e.id
             limit ?
            """.trimIndent(),
            CONSUMER_NAME,
            MAX_ATTEMPTS,
            limit,
        ).map {
            LearningProgressProjectionEvent(
                id = it.get("id", UUID::class.java)!!,
                attemptId = it.get("aggregate_id", UUID::class.java)!!,
            )
        }

    fun claim(eventId: UUID): Boolean {
        dsl.execute(
            """
            insert into outbox_consumer_delivery(
                event_id, consumer_name, status, attempt_count
            ) values (?, ?, 'PENDING', 0)
            on conflict (event_id, consumer_name) do nothing
            """.trimIndent(),
            eventId,
            CONSUMER_NAME,
        )
        val status = dsl.fetchOne(
            """
            select status
              from outbox_consumer_delivery
             where event_id = ? and consumer_name = ?
             for update
            """.trimIndent(),
            eventId,
            CONSUMER_NAME,
        )?.get("status", String::class.java) ?: error("Projection delivery row was not readable")
        if (status == "PROCESSED" || status == "DEAD") {
            return false
        }
        dsl.execute(
            """
            update outbox_consumer_delivery
               set status = 'PROCESSING', attempt_count = attempt_count + 1, last_error_type = null
             where event_id = ? and consumer_name = ?
            """.trimIndent(),
            eventId,
            CONSUMER_NAME,
        )
        return true
    }

    fun findAttemptContext(attemptId: UUID): AttemptProjectionContext =
        dsl.fetchOne(
            "select user_id, course_id from test_attempt where id = ?",
            attemptId,
        )?.let {
            AttemptProjectionContext(
                userId = it.get("user_id", UUID::class.java)!!,
                courseId = it.get("course_id", UUID::class.java)!!,
            )
        } ?: error("Projection event refers to an unknown attempt")

    fun rebuild(
        context: AttemptProjectionContext,
        eventId: UUID,
        now: OffsetDateTime,
    ) {
        val courseReleaseId = activeReleaseId(context.courseId, lock = true)
            ?: error("A progress projection requires an active course release")
        rebuildCourse(context, eventId, courseReleaseId, now)
    }

    fun rebuildCourse(
        context: AttemptProjectionContext,
        eventId: UUID,
        courseReleaseId: UUID,
        now: OffsetDateTime,
    ) {
        val counts = readCounts(context, courseReleaseId)
        dsl.execute(
            """
            insert into learner_course_progress_projection(
                user_id, course_id, course_release_id, answered_questions, correct_answers,
                completed_attempts, passed_attempts, active_score, lifetime_score,
                projection_version, last_event_id, updated_at
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, cast(? as timestamptz))
            on conflict (user_id, course_id) do update set
                course_release_id = excluded.course_release_id,
                answered_questions = excluded.answered_questions,
                correct_answers = excluded.correct_answers,
                completed_attempts = excluded.completed_attempts,
                passed_attempts = excluded.passed_attempts,
                active_score = excluded.active_score,
                lifetime_score = excluded.lifetime_score,
                projection_version = learner_course_progress_projection.projection_version + 1,
                last_event_id = excluded.last_event_id,
                updated_at = excluded.updated_at
            """.trimIndent(),
            context.userId,
            context.courseId,
            courseReleaseId,
            counts.answeredQuestions,
            counts.correctAnswers,
            counts.completedAttempts,
            counts.passedAttempts,
            counts.activeScore,
            counts.lifetimeScore,
            eventId,
            now,
        )
    }

    fun markProcessed(eventId: UUID, now: OffsetDateTime) {
        check(
            dsl.execute(
                """
                update outbox_consumer_delivery
                   set status = 'PROCESSED', processed_at = cast(? as timestamptz), last_error_type = null
                 where event_id = ? and consumer_name = ?
                """.trimIndent(),
                now,
                eventId,
                CONSUMER_NAME,
            ) == 1,
        ) { "Projection delivery completion did not update exactly one row" }
    }

    fun recordFailure(eventId: UUID, errorType: String) {
        dsl.execute(
            """
            insert into outbox_consumer_delivery(
                event_id, consumer_name, status, attempt_count, last_error_type
            ) values (?, ?, 'FAILED', 1, ?)
            on conflict (event_id, consumer_name) do update set
                attempt_count = least(outbox_consumer_delivery.attempt_count + 1, ?),
                status = case
                    when outbox_consumer_delivery.attempt_count + 1 >= ? then 'DEAD'
                    else 'FAILED'
                end,
                processed_at = null,
                last_error_type = excluded.last_error_type
            where outbox_consumer_delivery.status <> 'PROCESSED'
            """.trimIndent(),
            eventId,
            CONSUMER_NAME,
            errorType.take(500),
            MAX_ATTEMPTS,
            MAX_ATTEMPTS,
        )
    }

    fun getProgress(userId: UUID, courseId: UUID, activeCourseReleaseId: UUID): LearningProgressSnapshot {
        val row = dsl.fetchOne(
            """
            select answered_questions, correct_answers, completed_attempts, passed_attempts,
                   active_score, lifetime_score, projection_version, course_release_id, updated_at
              from learner_course_progress_projection
             where user_id = ? and course_id = ?
            """.trimIndent(),
            userId,
            courseId,
        )
        val representedReleaseId = row?.get("course_release_id", UUID::class.java)
        return LearningProgressSnapshot(
            courseId = courseId,
            courseReleaseId = representedReleaseId ?: activeCourseReleaseId,
            answeredQuestions = row?.get("answered_questions", Int::class.java) ?: 0,
            correctAnswers = row?.get("correct_answers", Int::class.java) ?: 0,
            completedAttempts = row?.get("completed_attempts", Int::class.java) ?: 0,
            passedAttempts = row?.get("passed_attempts", Int::class.java) ?: 0,
            activeScore = row?.get("active_score", Long::class.java) ?: 0,
            lifetimeScore = row?.get("lifetime_score", Long::class.java) ?: 0,
            projectionVersion = row?.get("projection_version", Long::class.java) ?: 0,
            updating = row != null && representedReleaseId != activeCourseReleaseId ||
                hasPendingEvents(userId, courseId) ||
                hasPendingReleaseReprojection(userId, courseId, activeCourseReleaseId),
            updatedAt = row?.get("updated_at", OffsetDateTime::class.java),
        )
    }

    private fun readCounts(context: AttemptProjectionContext, courseReleaseId: UUID): LearningProgressCounts {
        val row = dsl.fetchOne(
            """
            select
                (select count(*)
                   from answer_submission s
                   join test_attempt a on a.id = s.attempt_id
                  where s.user_id = ? and a.course_id = ?) as answered_questions,
                (select count(*)
                   from answer_submission s
                   join test_attempt a on a.id = s.attempt_id
                  where s.user_id = ? and a.course_id = ? and s.is_correct) as correct_answers,
                (select count(*)
                   from test_attempt a
                  where a.user_id = ? and a.course_id = ?
                    and a.status in ('COMPLETED_PASS', 'COMPLETED_FAIL')) as completed_attempts,
                (select count(*)
                   from test_attempt a
                  where a.user_id = ? and a.course_id = ?
                    and a.status = 'COMPLETED_PASS') as passed_attempts,
                (select coalesce(sum(m.active_score), 0)
                   from question_mastery m
                   join question_revision q on q.id = m.question_revision_id
                  where m.user_id = ? and q.course_id = ?
                    and exists (
                        select 1
                          from course_release_test_revision release_test
                          join test_revision_question test_question
                            on test_question.test_revision_id = release_test.test_revision_id
                         where release_test.course_release_id = ?
                           and test_question.question_revision_id = m.question_revision_id
                    )) as active_score,
                (select coalesce(sum(s.lifetime_delta), 0)
                   from score_event s
                   join test_attempt a on a.id = s.attempt_id
                  where s.user_id = ? and a.course_id = ?) as lifetime_score
            """.trimIndent(),
            context.userId,
            context.courseId,
            context.userId,
            context.courseId,
            context.userId,
            context.courseId,
            context.userId,
            context.courseId,
            context.userId,
            context.courseId,
            courseReleaseId,
            context.userId,
            context.courseId,
        ) ?: error("Unable to rebuild learning progress projection")
        return LearningProgressCounts(
            answeredQuestions = row.get("answered_questions", Long::class.java)!!.toInt(),
            correctAnswers = row.get("correct_answers", Long::class.java)!!.toInt(),
            completedAttempts = row.get("completed_attempts", Long::class.java)!!.toInt(),
            passedAttempts = row.get("passed_attempts", Long::class.java)!!.toInt(),
            activeScore = row.get("active_score", Long::class.java)!!,
            lifetimeScore = row.get("lifetime_score", Long::class.java)!!,
        )
    }

    private fun hasPendingEvents(userId: UUID, courseId: UUID): Boolean =
        dsl.fetchOne(
            """
            select exists (
                select 1
                  from outbox_event e
                  join test_attempt a on a.id = e.aggregate_id
                  left join outbox_consumer_delivery d
                    on d.event_id = e.id and d.consumer_name = ?
                 where a.user_id = ? and a.course_id = ?
                   and e.event_type in ('learning.answer-recorded.v1', 'learning.attempt-finished.v1')
                   and (d.event_id is null or d.status <> 'PROCESSED')
            ) as pending
            """.trimIndent(),
            CONSUMER_NAME,
            userId,
            courseId,
        )?.get("pending", Boolean::class.java) ?: false

    private fun hasPendingReleaseReprojection(
        userId: UUID,
        courseId: UUID,
        activeCourseReleaseId: UUID,
    ): Boolean = dsl.fetchOne(
        """
        select exists (
            select 1
              from course_release_reprojection_job job
              join enrollment enrollment_row
                on enrollment_row.course_id = job.course_id
               and enrollment_row.user_id = ?
               and enrollment_row.status = 'ACTIVE'
               and enrollment_row.enrolled_at <= job.enrollment_cutoff_at
             where job.course_id = ?
               and job.target_release_id = ?
               and job.status in ('PENDING', 'FAILED', 'DEAD')
        ) as pending
        """.trimIndent(),
        userId,
        courseId,
        activeCourseReleaseId,
    )?.get("pending", Boolean::class.java) ?: false

    private fun activeReleaseId(courseId: UUID, lock: Boolean): UUID? {
        val lockClause = if (lock) " for share" else ""
        return dsl.fetchOne(
            "select active_release_id from course where id = ?$lockClause",
            courseId,
        )?.get("active_release_id", UUID::class.java)
    }

    companion object {
        const val CONSUMER_NAME = "learning-progress-projection.v1"
        const val MAX_ATTEMPTS = 5
    }
}
