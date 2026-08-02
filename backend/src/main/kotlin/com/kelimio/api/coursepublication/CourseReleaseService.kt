package com.kelimio.api.coursepublication

import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.NotFoundProblem
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Service
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
class CourseReleaseService(
    private val repository: CourseReleaseRepository,
    private val idempotencyService: IdempotencyService,
    private val outbox: TransactionalOutbox,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
) {
    @Transactional(readOnly = true)
    fun impact(user: AppUser, courseId: UUID, releaseId: UUID): CourseReleaseImpactResponse =
        CourseReleaseImpactCalculator.calculate(state(user, courseId, releaseId, lock = false))

    @Transactional
    fun activate(
        user: AppUser,
        courseId: UUID,
        releaseId: UUID,
        idempotencyKey: UUID,
        request: ActivateCourseReleaseRequest,
    ): CourseReleaseActivationResponse {
        val canonicalRequest = buildString {
            append(courseId).append('|')
            append(releaseId).append('|')
            append(request.expectedActiveReleaseId ?: "-").append('|')
            append(request.impactBindingSha256)
        }
        val lookup = idempotencyService.lockAndFind(
            user.id,
            OPERATION,
            idempotencyKey,
            canonicalRequest,
        )
        lookup.resourceId?.let { activationId ->
            val existing = repository.activation(activationId, user.id)
                ?: throw ConflictProblem("The idempotent release activation no longer exists.")
            return existing.toResponse(created = false)
        }

        val lockedState = state(user, courseId, releaseId, lock = true)
        val impact = CourseReleaseImpactCalculator.calculate(lockedState)
        if (request.expectedActiveReleaseId != impact.expectedActiveReleaseId) {
            throw ConflictProblem("The active course release changed after impact review.")
        }
        if (request.impactBindingSha256 != impact.impactBindingSha256) {
            throw ConflictProblem("The release impact changed after review.")
        }

        repository.prepareReleaseTransition(
            previousReleaseId = lockedState.course.activeReleaseId,
            targetReleaseId = releaseId,
        )
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val publicationStatus = repository.switchActiveRelease(
            course = lockedState.course,
            targetReleaseId = releaseId,
            now = now,
        )
        val activationId = UUID.randomUUID()
        val eventId = UUID.randomUUID()
        val correlationId = correlationIdProvider.current()
        val eventType = if (impact.operation == CourseReleaseOperation.ROLLBACK) {
            "content.release-rollback-activated.v1"
        } else {
            "content.release-published.v1"
        }
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "course",
                aggregateId = courseId,
                eventType = eventType,
                schemaVersion = 1,
                payload = mapOf(
                    "eventId" to eventId,
                    "activationId" to activationId,
                    "courseId" to courseId,
                    "releaseId" to releaseId,
                    "previousReleaseId" to impact.expectedActiveReleaseId,
                    "contentChangeSetId" to impact.sourceChangeSetId,
                    "releaseRevision" to impact.releaseRevision,
                    "operation" to impact.operation.name,
                    "questionCount" to impact.targetQuestionCount,
                    "requiredClientCapabilities" to impact.requiredClientCapabilities,
                    "impactBindingSha256" to impact.impactBindingSha256,
                ),
                correlationId = correlationId,
                occurredAt = now,
            ),
        )
        repository.insertActivation(
            activationId = activationId,
            courseId = courseId,
            targetReleaseId = releaseId,
            previousReleaseId = impact.expectedActiveReleaseId,
            sourceChangeSetId = impact.sourceChangeSetId,
            actorUserId = user.id,
            operation = impact.operation,
            impactBindingSha256 = impact.impactBindingSha256,
            releaseRevision = impact.releaseRevision,
            questionCount = impact.targetQuestionCount,
            requiredCapabilities = impact.requiredClientCapabilities,
            outboxEventId = eventId,
            occurredAt = now,
            correlationId = correlationId,
        )
        repository.insertReprojectionJob(
            activationId = activationId,
            courseId = courseId,
            targetReleaseId = releaseId,
            outboxEventId = eventId,
            occurredAt = now,
        )
        idempotencyService.record(
            user.id,
            OPERATION,
            idempotencyKey,
            lookup.fingerprint,
            activationId,
        )
        return CourseReleaseActivationResponse(
            activationId = activationId,
            courseId = courseId,
            releaseId = releaseId,
            previousReleaseId = impact.expectedActiveReleaseId,
            sourceChangeSetId = impact.sourceChangeSetId,
            operation = impact.operation,
            releaseRevision = impact.releaseRevision,
            questionCount = impact.targetQuestionCount,
            requiredClientCapabilities = impact.requiredClientCapabilities,
            coursePublicationStatus = publicationStatus,
            reprojectionStatus = "PENDING",
            activatedAt = now,
            created = true,
        )
    }

    private fun state(
        user: AppUser,
        courseId: UUID,
        releaseId: UUID,
        lock: Boolean,
    ): CourseReleaseImpactState {
        val course = repository.course(courseId, lock)
            ?.takeIf { it.ownerUserId == user.id }
            ?: throw NotFoundProblem("Course was not found.")
        val target = repository.target(courseId, releaseId, lock)
            ?: throw NotFoundProblem("Course release was not found.")
        return CourseReleaseImpactState(
            course = course,
            target = target,
            currentQuestions = course.activeReleaseId?.let(repository::questionManifest).orEmpty(),
            targetQuestions = repository.questionManifest(target.id),
            requiredClientCapabilities = repository.requiredCapabilities(target.id),
            affectedEnrollmentCount = repository.activeEnrollmentCount(course.id),
        )
    }

    private fun CourseReleaseActivationRecord.toResponse(created: Boolean) = CourseReleaseActivationResponse(
        activationId = activationId,
        courseId = courseId,
        releaseId = releaseId,
        previousReleaseId = previousReleaseId,
        sourceChangeSetId = sourceChangeSetId,
        operation = operation,
        releaseRevision = releaseRevision,
        questionCount = questionCount,
        requiredClientCapabilities = requiredClientCapabilities,
        coursePublicationStatus = coursePublicationStatus,
        reprojectionStatus = reprojectionStatus,
        activatedAt = activatedAt,
        created = created,
    )

    private companion object {
        const val OPERATION = "course-release.activate"
    }
}
