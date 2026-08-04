package com.kelimio.api.coursepublication

import com.kelimio.api.progress.AttemptProjectionContext
import com.kelimio.api.progress.LearningProgressProjectionRepository
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Service
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
class CourseReleaseReprojectionProcessor(
    private val repository: CourseReleaseReprojectionRepository,
    private val progressRepository: LearningProgressProjectionRepository,
    private val clock: Clock,
) {
    @Transactional
    fun process(activationId: UUID, pageSize: Int = 100) {
        require(pageSize in 1..500) { "Release reprojection page size is out of range" }
        val job = repository.lockJob(activationId) ?: return
        if (job.status !in setOf("PENDING", "FAILED")) return
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        if (repository.lockActiveRelease(job.courseId) != job.targetReleaseId) {
            repository.complete(job, now)
            return
        }
        val enrollments = repository.enrollmentPage(job, pageSize)
        if (enrollments.isEmpty()) {
            repository.complete(job, now)
            return
        }
        enrollments.forEach { enrollment ->
            progressRepository.rebuildCourse(
                AttemptProjectionContext(enrollment.userId, job.courseId),
                job.outboxEventId,
                job.targetReleaseId,
                now,
            )
        }
        repository.advance(job, enrollments.last(), enrollments.size, now)
    }
}

@Service
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
class CourseReleaseReprojectionFailureRecorder(
    private val repository: CourseReleaseReprojectionRepository,
    private val clock: Clock,
) {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun record(activationId: UUID, failure: Exception) {
        repository.recordFailure(
            activationId,
            failure.javaClass.name,
            OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC),
        )
    }
}
