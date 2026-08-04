package com.kelimio.api.coursepublication

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

@Component
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
class CourseReleaseReprojectionWorker(
    private val repository: CourseReleaseReprojectionRepository,
    private val processor: CourseReleaseReprojectionProcessor,
    private val failureRecorder: CourseReleaseReprojectionFailureRecorder,
    @Value("\${KELIMIO_PROJECTION_ENABLED:true}") private val enabled: Boolean,
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @Scheduled(
        initialDelayString = "\${KELIMIO_RELEASE_REPROJECTION_INITIAL_DELAY_MS:1000}",
        fixedDelayString = "\${KELIMIO_RELEASE_REPROJECTION_POLL_INTERVAL_MS:1000}",
    )
    fun scheduledRun() {
        if (enabled) processAvailable()
    }

    fun processAvailable(batchSize: Int = 10): Int {
        val jobs = repository.findCandidates(batchSize)
        jobs.forEach { job ->
            try {
                processor.process(job.activationId)
            } catch (failure: Exception) {
                failureRecorder.record(job.activationId, failure)
                logger.warn(
                    "Course release reprojection failed activationId={} exceptionType={}",
                    job.activationId,
                    failure.javaClass.name,
                )
            }
        }
        return jobs.size
    }
}
