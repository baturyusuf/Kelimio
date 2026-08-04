package com.kelimio.api.config

import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication
import org.springframework.security.config.Customizer.withDefaults
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator
import org.springframework.security.oauth2.core.OAuth2Error
import org.springframework.security.oauth2.core.OAuth2TokenValidator
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.security.oauth2.jwt.JwtDecoder
import org.springframework.security.oauth2.jwt.JwtDecoders
import org.springframework.security.oauth2.jwt.JwtValidators
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder
import org.springframework.security.web.SecurityFilterChain

@Configuration
@EnableMethodSecurity
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
class SecurityConfig {
    @Bean
    fun jwtDecoder(
        @Value("\${KELIMIO_ENVIRONMENT}") environment: String,
        @Value("\${KELIMIO_OIDC_ISSUER}") issuer: String,
        @Value("\${KELIMIO_OIDC_AUDIENCE}") audience: String,
        @Value("\${KELIMIO_OIDC_JWK_SET_URI:}") jwkSetUri: String,
        @Value("\${KELIMIO_OIDC_TOKEN_PROFILE:oidc}") tokenProfile: String,
    ): JwtDecoder {
        OidcEndpointPolicy.validate(environment, issuer, jwkSetUri, audience)
        val decoder = if (jwkSetUri.isBlank()) {
            JwtDecoders.fromIssuerLocation<NimbusJwtDecoder>(issuer)
        } else {
            NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build()
        }
        val audienceValidator = OidcTokenProfile.parse(tokenProfile).validator(audience)
        decoder.setJwtValidator(
            DelegatingOAuth2TokenValidator(
                JwtValidators.createDefaultWithIssuer(issuer),
                audienceValidator,
            ),
        )
        return decoder
    }

    @Bean
    fun securityFilterChain(
        http: HttpSecurity,
        authenticationEntryPoint: ProblemAuthenticationEntryPoint,
        accessDeniedHandler: ProblemAccessDeniedHandler,
    ): SecurityFilterChain =
        http
            .csrf { it.disable() }
            .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
            .authorizeHttpRequests {
                it.requestMatchers("/actuator/health", "/actuator/health/**").permitAll()
                it.requestMatchers("/v1/**").authenticated()
                it.anyRequest().denyAll()
            }
            .exceptionHandling {
                it.authenticationEntryPoint(authenticationEntryPoint)
                it.accessDeniedHandler(accessDeniedHandler)
            }
            .oauth2ResourceServer {
                it.authenticationEntryPoint(authenticationEntryPoint)
                it.jwt(withDefaults())
            }
            .build()
}

enum class OidcTokenProfile {
    OIDC,
    COGNITO_ACCESS,
    ;

    fun validator(expectedAudience: String): OAuth2TokenValidator<Jwt> =
        OAuth2TokenValidator<Jwt> { jwt ->
            val valid = when (this) {
                OIDC -> jwt.audience.contains(expectedAudience)
                COGNITO_ACCESS ->
                    jwt.getClaimAsString("token_use") == "access" &&
                        jwt.getClaimAsString("client_id") == expectedAudience
            }
            if (valid) {
                OAuth2TokenValidatorResult.success()
            } else {
                OAuth2TokenValidatorResult.failure(
                    OAuth2Error("invalid_token", "Token is not valid for this API client.", null),
                )
            }
        }

    companion object {
        fun parse(value: String): OidcTokenProfile = when (value.trim().lowercase()) {
            "oidc" -> OIDC
            "cognito-access" -> COGNITO_ACCESS
            else -> throw IllegalArgumentException(
                "KELIMIO_OIDC_TOKEN_PROFILE must be oidc or cognito-access.",
            )
        }
    }
}
