package com.kelimio.api.progress

import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset

@Service
class LearningProgressProjectionProcessor(
    private val repository: LearningProgressProjectionRepository,
    private val clock: Clock,
) {
    @Transactional
    fun process(event: LearningProgressProjectionEvent) {
        if (!repository.claim(event.id)) {
            return
        }
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        repository.rebuild(repository.findAttemptContext(event.attemptId), event.id, now)
        repository.markProcessed(event.id, now)
    }
}

@Service
class LearningProgressProjectionFailureRecorder(
    private val repository: LearningProgressProjectionRepository,
) {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun record(event: LearningProgressProjectionEvent, failure: Exception) {
        repository.recordFailure(event.id, failure.javaClass.name)
    }
}
