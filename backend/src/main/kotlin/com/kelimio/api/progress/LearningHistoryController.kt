package com.kelimio.api.progress

import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.identityprofile.CurrentUserService
import org.jooq.DSLContext
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.stereotype.Repository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.time.Clock
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.util.UUID

@RestController
@RequestMapping("/v1/me/learning-summary")
internal class LearningHistoryController(
    private val currentUserService: CurrentUserService,
    private val service: LearningHistoryService,
) {
    @GetMapping
    fun get(@AuthenticationPrincipal jwt: Jwt): LearningSummaryResponse =
        service.get(currentUserService.requireCompleted(jwt))
}

internal data class LearningSummaryResponse(
    val activeScore: Long,
    val lifetimeScore: Long,
    val answeredQuestions: Int,
    val correctAnswers: Int,
    val completedAttempts: Int,
    val passedAttempts: Int,
    val enrolledCourses: Int,
    val completedCourses: Int,
    val currentStreakDays: Int,
    val history: List<LearningHistoryItemResponse>,
)

internal data class LearningHistoryItemResponse(
    val attemptId: UUID,
    val courseId: UUID,
    val courseName: String,
    val testTitle: String,
    val status: String,
    val answeredCount: Int,
    val correctCount: Int,
    val totalQuestions: Int,
    val finishedAt: OffsetDateTime,
)

@Service
internal class LearningHistoryService(
    private val repository: LearningHistoryRepository,
    private val clock: Clock,
) {
    @Transactional(readOnly = true)
    fun get(user: AppUser): LearningSummaryResponse {
        val totals = repository.totals(user.id)
        val today = LocalDate.now(clock.withZone(ZoneId.of(user.timeZone)))
        val streak = currentStreak(repository.streakDays(user.id), today)
        return LearningSummaryResponse(
            activeScore = totals.activeScore,
            lifetimeScore = totals.lifetimeScore,
            answeredQuestions = totals.answeredQuestions,
            correctAnswers = totals.correctAnswers,
            completedAttempts = totals.completedAttempts,
            passedAttempts = totals.passedAttempts,
            enrolledCourses = totals.enrolledCourses,
            completedCourses = totals.completedCourses,
            currentStreakDays = streak,
            history = repository.history(user.id),
        )
    }

    private fun currentStreak(days: List<LocalDate>, today: LocalDate): Int {
        if (days.isEmpty() || days.first() !in setOf(today, today.minusDays(1))) return 0
        var expected = days.first()
        var count = 0
        for (day in days) {
            if (day != expected) break
            count++
            expected = expected.minusDays(1)
        }
        return count
    }
}

internal data class LearningTotals(
    val activeScore: Long,
    val lifetimeScore: Long,
    val answeredQuestions: Int,
    val correctAnswers: Int,
    val completedAttempts: Int,
    val passedAttempts: Int,
    val enrolledCourses: Int,
    val completedCourses: Int,
)

@Repository
internal class LearningHistoryRepository(private val dsl: DSLContext) {
    fun totals(userId: UUID): LearningTotals = checkNotNull(
        dsl.fetchOne(
            """
            select coalesce(sum(active_score), 0)::bigint active_score,
                   coalesce(sum(lifetime_score), 0)::bigint lifetime_score,
                   coalesce(sum(answered_questions), 0)::int answered_questions,
                   coalesce(sum(correct_answers), 0)::int correct_answers,
                   coalesce(sum(completed_attempts), 0)::int completed_attempts,
                   coalesce(sum(passed_attempts), 0)::int passed_attempts,
                   (select count(*)::int from enrollment where user_id = ? and status = 'ACTIVE') enrolled_courses,
                   count(*) filter (where completed_attempts > 0)::int completed_courses
              from learner_course_progress_projection
             where user_id = ?
            """.trimIndent(),
            userId,
            userId,
        ),
    ).let {
        LearningTotals(
            activeScore = it.get("active_score", Long::class.java)!!,
            lifetimeScore = it.get("lifetime_score", Long::class.java)!!,
            answeredQuestions = it.get("answered_questions", Int::class.java)!!,
            correctAnswers = it.get("correct_answers", Int::class.java)!!,
            completedAttempts = it.get("completed_attempts", Int::class.java)!!,
            passedAttempts = it.get("passed_attempts", Int::class.java)!!,
            enrolledCourses = it.get("enrolled_courses", Int::class.java)!!,
            completedCourses = it.get("completed_courses", Int::class.java)!!,
        )
    }

    fun streakDays(userId: UUID): List<LocalDate> = dsl.fetch(
        "select local_date from streak_day where user_id = ? order by local_date desc limit 366",
        userId,
    ).map { it.get("local_date", LocalDate::class.java)!! }

    fun history(userId: UUID): List<LearningHistoryItemResponse> = dsl.fetch(
        """
        select attempt.id, attempt.course_id, course.name, revision.title, attempt.status,
               attempt.answered_count, attempt.correct_count, attempt.total_questions, attempt.finished_at
          from test_attempt attempt
          join course on course.id = attempt.course_id
          join test_revision revision on revision.id = attempt.test_revision_id
         where attempt.user_id = ?
           and attempt.status in ('COMPLETED_PASS', 'COMPLETED_FAIL')
         order by attempt.finished_at desc, attempt.id desc
         limit 50
        """.trimIndent(),
        userId,
    ).map {
        LearningHistoryItemResponse(
            attemptId = it.get("id", UUID::class.java)!!,
            courseId = it.get("course_id", UUID::class.java)!!,
            courseName = it.get("name", String::class.java)!!,
            testTitle = it.get("title", String::class.java)!!,
            status = it.get("status", String::class.java)!!,
            answeredCount = it.get("answered_count", Int::class.java)!!,
            correctCount = it.get("correct_count", Int::class.java)!!,
            totalQuestions = it.get("total_questions", Int::class.java)!!,
            finishedAt = it.get("finished_at", OffsetDateTime::class.java)!!,
        )
    }
}
