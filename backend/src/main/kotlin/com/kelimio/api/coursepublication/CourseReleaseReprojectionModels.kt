package com.kelimio.api.coursepublication

import java.time.OffsetDateTime
import java.util.UUID

data class CourseReleaseReprojectionCandidate(
    val activationId: UUID,
)

data class CourseReleaseReprojectionJob(
    val activationId: UUID,
    val courseId: UUID,
    val targetReleaseId: UUID,
    val outboxEventId: UUID,
    val enrollmentCutoffAt: OffsetDateTime,
    val status: String,
    val cursorEnrolledAt: OffsetDateTime?,
    val cursorEnrollmentId: UUID?,
)

data class CourseReleaseReprojectionEnrollment(
    val enrollmentId: UUID,
    val userId: UUID,
    val enrolledAt: OffsetDateTime,
)
