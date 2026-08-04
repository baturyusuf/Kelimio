package com.kelimio.api.config

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.security.oauth2.jwt.Jwt
import java.time.Instant

class OidcTokenProfileTest {
    @Test
    fun `standard oidc requires the configured audience`() {
        val validator = OidcTokenProfile.OIDC.validator("kelimio-api")

        assertThat(validator.validate(jwt(audience = listOf("kelimio-api"))).hasErrors()).isFalse()
        assertThat(validator.validate(jwt(audience = listOf("another-api"))).hasErrors()).isTrue()
    }

    @Test
    fun `cognito accepts only access token for the configured app client`() {
        val validator = OidcTokenProfile.COGNITO_ACCESS.validator("android-client")

        assertThat(
            validator.validate(
                jwt(tokenUse = "access", clientId = "android-client"),
            ).hasErrors(),
        ).isFalse()
        assertThat(
            validator.validate(
                jwt(tokenUse = "id", clientId = "android-client", audience = listOf("android-client")),
            ).hasErrors(),
        ).isTrue()
        assertThat(
            validator.validate(
                jwt(tokenUse = "access", clientId = "another-client"),
            ).hasErrors(),
        ).isTrue()
    }

    @Test
    fun `unknown token profile fails configuration`() {
        assertThatThrownBy { OidcTokenProfile.parse("permissive") }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("oidc or cognito-access")
    }

    private fun jwt(
        tokenUse: String? = null,
        clientId: String? = null,
        audience: List<String> = emptyList(),
    ): Jwt {
        val now = Instant.parse("2026-08-04T00:00:00Z")
        return Jwt.withTokenValue("token")
            .header("alg", "RS256")
            .subject("subject")
            .issuedAt(now)
            .expiresAt(now.plusSeconds(900))
            .audience(audience)
            .apply {
                tokenUse?.let { claim("token_use", it) }
                clientId?.let { claim("client_id", it) }
            }
            .build()
    }
}
