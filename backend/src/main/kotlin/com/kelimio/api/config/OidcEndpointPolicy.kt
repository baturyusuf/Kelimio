package com.kelimio.api.config

import java.net.URI

object OidcEndpointPolicy {
    private val allowedEnvironments = setOf("local", "test", "development", "staging", "production")

    fun validate(
        environment: String,
        issuer: String,
        jwkSetUri: String,
        audience: String,
    ) {
        val normalizedEnvironment = environment.trim().lowercase()
        require(normalizedEnvironment in allowedEnvironments) {
            "KELIMIO_ENVIRONMENT must be one of ${allowedEnvironments.sorted().joinToString()}."
        }
        require(audience.isNotBlank()) { "KELIMIO_OIDC_AUDIENCE must not be blank." }
        val allowHttp = normalizedEnvironment == "local"
        validateEndpoint("KELIMIO_OIDC_ISSUER", issuer, allowHttp)
        if (jwkSetUri.isNotBlank()) {
            validateEndpoint("KELIMIO_OIDC_JWK_SET_URI", jwkSetUri, allowHttp)
        }
    }

    private fun validateEndpoint(
        label: String,
        value: String,
        allowHttp: Boolean,
    ) {
        val uri = runCatching { URI(value) }.getOrElse {
            throw IllegalArgumentException("$label must be a valid absolute URI.", it)
        }
        require(uri.isAbsolute && !uri.host.isNullOrBlank() && uri.userInfo == null && uri.fragment == null) {
            "$label must be an absolute host URI without user information or a fragment."
        }
        val acceptedScheme = uri.scheme.equals("https", ignoreCase = true) ||
            (allowHttp && uri.scheme.equals("http", ignoreCase = true))
        require(acceptedScheme) {
            "$label must use HTTPS outside the explicit local environment."
        }
    }
}
