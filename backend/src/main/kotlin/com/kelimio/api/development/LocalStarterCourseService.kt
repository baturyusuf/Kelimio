package com.kelimio.api.development

import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.outbox.OutboxRepository
import com.kelimio.api.web.NotFoundProblem
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Service
class LocalStarterCourseService(
    private val repository: LocalStarterCourseRepository,
    private val idempotencyService: IdempotencyService,
    private val outboxRepository: OutboxRepository,
    private val clock: Clock,
    @Value("\${KELIMIO_ENVIRONMENT}") private val environment: String,
    @Value("\${KELIMIO_LOCAL_STARTER_COURSE_ENABLED:false}") private val enabled: Boolean,
) {
    @Transactional
    fun install(
        user: AppUser,
        idempotencyKey: UUID,
        productionInternalTesterAuthorized: Boolean = false,
    ): LocalStarterCourseResult {
        val localAllowed = environment == "local" && enabled
        val productionAllowed =
            environment == "production" && productionInternalTesterAuthorized
        if (!localAllowed && !productionAllowed) {
            throw NotFoundProblem("Starter-course installation is not enabled.")
        }
        val lookup = idempotencyService.lockAndFind(
            user.id,
            "development.install-starter-course",
            idempotencyKey,
            LocalStarterCourseDefinition.ORIGIN_KEY,
        )
        lookup.resourceId?.let { return result(it, false) }

        repository.lockOwnerSource(user.id)
        repository.findExistingCourse(user.id)?.let { existing ->
            idempotencyService.record(
                user.id,
                "development.install-starter-course",
                idempotencyKey,
                lookup.fingerprint,
                existing,
            )
            return result(existing, false)
        }

        val courseId = repository.create(
            user.id,
            OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC),
        )
        outboxRepository.append(
            aggregateType = "course",
            aggregateId = courseId,
            eventType = "content.release-published.v1",
            payload = mapOf(
                "courseId" to courseId,
                "originType" to LocalStarterCourseDefinition.ORIGIN_TYPE,
                "sourceSha256" to LocalStarterCourseDefinition.SOURCE_WORKBOOK_SHA256,
            ),
        )
        idempotencyService.record(
            user.id,
            "development.install-starter-course",
            idempotencyKey,
            lookup.fingerprint,
            courseId,
        )
        return result(courseId, true)
    }

    private fun result(courseId: UUID, created: Boolean) = LocalStarterCourseResult(
        courseId = courseId,
        created = created,
        sourceWorkbookSha256 = LocalStarterCourseDefinition.SOURCE_WORKBOOK_SHA256,
    )
}
