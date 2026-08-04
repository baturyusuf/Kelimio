package com.kelimio.api.progress

import java.time.OffsetDateTime
import java.util.UUID

data class LearningProgressSnapshot(
    val courseId: UUID,
    val courseReleaseId: UUID,
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

data class LearningProgressProjectionEvent(
    val id: UUID,
    val attemptId: UUID,
)

data class AttemptProjectionContext(
    val userId: UUID,
    val courseId: UUID,
)

data class LearningProgressCounts(
    val answeredQuestions: Int,
    val correctAnswers: Int,
    val completedAttempts: Int,
    val passedAttempts: Int,
    val activeScore: Long,
    val lifetimeScore: Long,
)
