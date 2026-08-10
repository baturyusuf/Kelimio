package com.kelimio.api.teacher

import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.ForbiddenProblem
import com.kelimio.api.web.UnprocessableProblem
import org.springframework.beans.factory.annotation.Value
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Service
internal class TeacherAccessService(
    private val repository: TeacherAccessRepository,
    private val outbox: TransactionalOutbox,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
    @Value("\${KELIMIO_ENVIRONMENT}") environment: String,
    @Value("\${KELIMIO_PRODUCTION_TEACHER_FEATURES_ENABLED:false}")
    private val productionFeaturesEnabled: Boolean,
    @Value("\${KELIMIO_TEACHER_TERMS_VERSION:internal-test-v1}")
    private val requiredTermsVersion: String,
) {
    private val environment = environment.trim().lowercase().also {
        require(it in setOf("local", "test", "production"))
    }

    fun status(jwt: Jwt, user: AppUser): TeacherAccessResponse {
        val eligible = eligible(jwt)
        val termsAccepted = environment != "production" ||
            (eligible && repository.acceptedCurrentTerms(user.id, requiredTermsVersion))
        return TeacherAccessResponse(
            eligible = eligible,
            termsAccepted = termsAccepted,
            productionFeaturesEnabled = environment != "production" || productionFeaturesEnabled,
            requiredTermsVersion = requiredTermsVersion,
        )
    }

    @Transactional
    fun accept(jwt: Jwt, user: AppUser, request: AcceptTeacherTermsRequest): TeacherAccessResponse {
        if (!eligible(jwt)) throw ForbiddenProblem("This account is not eligible for teacher features.")
        if (request.termsVersion != requiredTermsVersion) {
            throw UnprocessableProblem("The current teacher terms version must be accepted.")
        }
        if (environment == "production" && !productionFeaturesEnabled) {
            throw ConflictProblem("Production teacher features are disabled.")
        }
        if (repository.acceptedCurrentTerms(user.id, requiredTermsVersion)) return status(jwt, user)
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val correlationId = correlationIdProvider.current()
        repository.accept(user.id, requiredTermsVersion, now, correlationId)
        val eventId = UUID.randomUUID()
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "teacher-authorization",
                aggregateId = user.id,
                eventType = "teacher.terms-accepted.v1",
                schemaVersion = 1,
                payload = mapOf(
                    "eventId" to eventId,
                    "userId" to user.id,
                    "termsVersion" to requiredTermsVersion,
                ),
                correlationId = correlationId,
                occurredAt = now,
            ),
        )
        return status(jwt, user)
    }

    fun requireAuthorized(jwt: Jwt, user: AppUser) {
        if (environment != "production") return
        if (!productionFeaturesEnabled) throw ForbiddenProblem("Production teacher features are disabled.")
        if (!eligible(jwt)) throw ForbiddenProblem("This account is not eligible for teacher features.")
        if (!repository.acceptedCurrentTerms(user.id, requiredTermsVersion)) {
            throw ConflictProblem("The current teacher terms must be accepted before authoring.")
        }
    }

    private fun eligible(jwt: Jwt): Boolean = when (environment) {
        "local", "test" -> true
        else -> productionFeaturesEnabled && TEACHER_GROUP in jwt.getClaimAsStringList("cognito:groups").orEmpty()
    }

    private companion object {
        const val TEACHER_GROUP = "kelimio-teachers"
    }
}
