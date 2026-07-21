package com.kelimio.api.config

import org.assertj.core.api.Assertions.assertThatIllegalArgumentException
import org.junit.jupiter.api.Test

class OidcEndpointPolicyTest {
    @Test
    fun `production requires https for issuer and jwk endpoints`() {
        assertThatIllegalArgumentException().isThrownBy {
            OidcEndpointPolicy.validate(
                "production",
                "http://identity.example.com/realms/kelimio",
                "https://identity.example.com/jwks",
                "kelimio-api",
            )
        }
        assertThatIllegalArgumentException().isThrownBy {
            OidcEndpointPolicy.validate(
                "production",
                "https://identity.example.com/realms/kelimio",
                "http://identity.example.com/jwks",
                "kelimio-api",
            )
        }
    }

    @Test
    fun `local environment explicitly permits http endpoints`() {
        OidcEndpointPolicy.validate(
            "local",
            "http://localhost:8081/realms/kelimio",
            "http://keycloak:8080/realms/kelimio/protocol/openid-connect/certs",
            "kelimio-api",
        )
    }

    @Test
    fun `unknown environment and endpoint user information fail closed`() {
        assertThatIllegalArgumentException().isThrownBy {
            OidcEndpointPolicy.validate(
                "preview",
                "https://identity.example.com/realms/kelimio",
                "",
                "kelimio-api",
            )
        }
        assertThatIllegalArgumentException().isThrownBy {
            OidcEndpointPolicy.validate(
                "staging",
                "https://user@identity.example.com/realms/kelimio",
                "",
                "kelimio-api",
            )
        }
    }
}
