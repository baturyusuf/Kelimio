package com.kelimio.api.progress

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

@Component
class LearningProgressProjectionWorker(
    private val repository: LearningProgressProjectionRepository,
    private val processor: LearningProgressProjectionProcessor,
    private val failureRecorder: LearningProgressProjectionFailureRecorder,
    @Value("\${KELIMIO_PROJECTION_ENABLED:true}") private val enabled: Boolean,
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @Scheduled(
        initialDelayString = "\${KELIMIO_PROJECTION_INITIAL_DELAY_MS:1000}",
        fixedDelayString = "\${KELIMIO_PROJECTION_POLL_INTERVAL_MS:1000}",
    )
    fun scheduledRun() {
        if (enabled) {
            processAvailable()
        }
    }

    fun processAvailable(batchSize: Int = 100): Int {
        val events = repository.findCandidates(batchSize)
        events.forEach { event ->
            try {
                processor.process(event)
            } catch (failure: Exception) {
                failureRecorder.record(event, failure)
                logger.warn(
                    "Learning progress projection failed eventId={} exceptionType={}",
                    event.id,
                    failure.javaClass.name,
                )
            }
        }
        return events.size
    }
}
