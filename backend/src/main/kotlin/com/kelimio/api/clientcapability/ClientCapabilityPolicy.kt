package com.kelimio.api.clientcapability

import com.kelimio.api.web.UnprocessableProblem

object ClientCapabilityPolicy {
    const val HEADER_NAME = "X-Kelimio-Client-Capabilities"
    const val MATCHING_V1 = "question.matching.v1"

    private const val MAX_CAPABILITIES = 16
    private const val MAX_TOKEN_LENGTH = 64
    private const val MAX_HEADER_LENGTH = MAX_CAPABILITIES * (MAX_TOKEN_LENGTH + 1)
    private val tokenPattern = Regex("^[a-z][a-z0-9]*(?:\\.[a-z][a-z0-9]*)+$")

    fun parse(raw: String?): Set<String> {
        if (raw == null) return emptySet()
        if (raw.isEmpty() || raw.length > MAX_HEADER_LENGTH) reject()
        val tokens = raw.split(',').map(String::trim)
        if (tokens.size !in 1..MAX_CAPABILITIES || tokens.any { token ->
                token.isEmpty() || token.length > MAX_TOKEN_LENGTH || !tokenPattern.matches(token)
            }
        ) {
            reject()
        }
        return tokens.toSet()
    }

    private fun reject(): Nothing =
        throw UnprocessableProblem("The client capability header is invalid.")
}
