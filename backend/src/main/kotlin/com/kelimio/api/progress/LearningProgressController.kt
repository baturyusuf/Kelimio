package com.kelimio.api.progress

import com.kelimio.api.identityprofile.CurrentUserService
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.time.OffsetDateTime
import java.util.UUID

@RestController
@RequestMapping("/v1/courses/{courseId}/progress")
class LearningProgressController(
    private val currentUserService: CurrentUserService,
    private val service: LearningProgressService,
) {
    @GetMapping
    fun get(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
    ): LearningProgressResponse = service.get(currentUserService.requireCompleted(jwt), courseId).toResponse()
}

data class LearningProgressResponse(
    val courseId: UUID,
    val answeredQuestions: Int,
    val correctAnswers: Int,
    val completedAttempts: Int,
    val passedAttempts: Int,
    val activeScore: Long,
    val lifetimeScore: Long,
    val projectionVersion: Long,
    val updating: Boolean,
    val updatedAt: OffsetDateTime?,
)

private fun LearningProgressSnapshot.toResponse() = LearningProgressResponse(
    courseId = courseId,
    answeredQuestions = answeredQuestions,
    correctAnswers = correctAnswers,
    completedAttempts = completedAttempts,
    passedAttempts = passedAttempts,
    activeScore = activeScore,
    lifetimeScore = lifetimeScore,
    projectionVersion = projectionVersion,
    updating = updating,
    updatedAt = updatedAt,
)
