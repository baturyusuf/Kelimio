package com.kelimio.api.account

import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.ServiceUnavailableProblem
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.http.CacheControl
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import software.amazon.awssdk.awscore.exception.AwsServiceException
import software.amazon.awssdk.core.exception.SdkClientException
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.cognitoidentityprovider.CognitoIdentityProviderClient
import software.amazon.awssdk.services.cognitoidentityprovider.model.AdminUserGlobalSignOutRequest
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Configuration
@ConditionalOnProperty(name = ["KELIMIO_COGNITO_SESSION_MANAGEMENT_ENABLED"], havingValue = "true")
internal class CognitoSessionConfiguration {
    @Bean(destroyMethod = "close")
    fun cognitoIdentityProviderClient(
        @Value("\${AWS_REGION}") region: String,
    ): CognitoIdentityProviderClient = CognitoIdentityProviderClient.builder()
        .region(Region.of(region))
        .httpClientBuilder(UrlConnectionHttpClient.builder())
        .build()
}

@RestController
@RequestMapping("/v1/me/session-revocations")
@ConditionalOnProperty(name = ["KELIMIO_COGNITO_SESSION_MANAGEMENT_ENABLED"], havingValue = "true")
internal class CognitoSessionController(
    private val currentUserService: CurrentUserService,
    private val service: CognitoSessionService,
) {
    @PostMapping
    fun revokeAll(
        @AuthenticationPrincipal jwt: Jwt,
    ): ResponseEntity<SessionRevocationResponse> {
        val user = currentUserService.requireCompleted(jwt)
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
            .body(service.revokeAll(user.id, jwt))
    }
}

internal data class SessionRevocationResponse(
    val revokedAt: OffsetDateTime,
)

@Service
@ConditionalOnProperty(name = ["KELIMIO_COGNITO_SESSION_MANAGEMENT_ENABLED"], havingValue = "true")
internal class CognitoSessionService(
    private val cognito: CognitoIdentityProviderClient,
    private val outbox: TransactionalOutbox,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
    @Value("\${KELIMIO_COGNITO_USER_POOL_ID}") private val userPoolId: String,
) {
    @Transactional
    fun revokeAll(userId: UUID, jwt: Jwt): SessionRevocationResponse {
        val username = jwt.getClaimAsString("username")
            ?: jwt.getClaimAsString("cognito:username")
            ?: throw ServiceUnavailableProblem("The identity session cannot be revoked safely.")
        try {
            cognito.adminUserGlobalSignOut(
                AdminUserGlobalSignOutRequest.builder()
                    .userPoolId(userPoolId)
                    .username(username)
                    .build(),
            )
        } catch (_: AwsServiceException) {
            throw ServiceUnavailableProblem("The identity provider is temporarily unavailable.")
        } catch (_: SdkClientException) {
            throw ServiceUnavailableProblem("The identity provider is temporarily unavailable.")
        }
        return record(userId)
    }

    internal fun record(userId: UUID): SessionRevocationResponse {
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val eventId = UUID.randomUUID()
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "account",
                aggregateId = userId,
                eventType = "account.sessions-revoked.v1",
                schemaVersion = 1,
                payload = mapOf("eventId" to eventId, "userId" to userId, "revokedAt" to now),
                correlationId = correlationIdProvider.current(),
                occurredAt = now,
            ),
        )
        return SessionRevocationResponse(revokedAt = now)
    }
}
