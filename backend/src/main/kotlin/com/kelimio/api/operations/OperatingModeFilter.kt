package com.kelimio.api.operations

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.web.CorrelationIdFilter
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpMethod
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter

@Component
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
class OperatingModeFilter(
    private val provider: OperatingModeProvider,
    private val objectMapper: ObjectMapper,
) : OncePerRequestFilter() {
    override fun shouldNotFilter(request: HttpServletRequest): Boolean =
        !request.requestURI.startsWith("/v1/")

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        val mode = provider.current()
        val problem = blockedProblem(mode, request)
        if (problem == null) {
            filterChain.doFilter(request, response)
            return
        }

        response.status = HttpStatus.SERVICE_UNAVAILABLE.value()
        response.contentType = "application/problem+json"
        response.characterEncoding = Charsets.UTF_8.name()
        response.setHeader(HttpHeaders.CACHE_CONTROL, "no-store")
        response.setHeader(HttpHeaders.RETRY_AFTER, "3600")
        objectMapper.writeValue(
            response.outputStream,
            mapOf(
                "type" to "https://api.kelimio.invalid/problems/${problem.type}",
                "code" to problem.code,
                "title" to HttpStatus.SERVICE_UNAVAILABLE.reasonPhrase,
                "status" to HttpStatus.SERVICE_UNAVAILABLE.value(),
                "detail" to problem.detail,
                "instance" to request.requestURI,
                "requestId" to request.getAttribute(CorrelationIdFilter.REQUEST_ATTRIBUTE),
            ),
        )
    }

    private fun blockedProblem(
        mode: OperatingMode,
        request: HttpServletRequest,
    ): BlockedProblem? = when (mode) {
        OperatingMode.NORMAL -> null
        OperatingMode.CONSERVE -> if (isExpensiveMutation(request)) {
            BlockedProblem(
                "cost-conservation",
                "COST_CONSERVATION",
                "Course authoring and import are temporarily unavailable while the service conserves capacity.",
            )
        } else {
            null
        }
        OperatingMode.READ_ONLY -> if (request.method in SAFE_METHODS) {
            null
        } else {
            BlockedProblem(
                "cost-read-only",
                "COST_READ_ONLY",
                "The service is temporarily read-only. No learning, enrollment, profile, or authoring change was recorded.",
            )
        }
        OperatingMode.SUSPENDED -> BlockedProblem(
            "cost-suspended",
            "COST_SUSPENDED",
            "The service is temporarily suspended. No change was recorded.",
        )
    }

    private fun isExpensiveMutation(request: HttpServletRequest): Boolean =
        request.method !in SAFE_METHODS && (
            EXPENSIVE_PATH_PREFIXES.any(request.requestURI::startsWith) ||
                request.requestURI.matches(RELEASE_MUTATION_PATH)
            )

    private data class BlockedProblem(
        val type: String,
        val code: String,
        val detail: String,
    )

    companion object {
        private val SAFE_METHODS = setOf(
            HttpMethod.GET.name(),
            HttpMethod.HEAD.name(),
            HttpMethod.OPTIONS.name(),
        )
        private val EXPENSIVE_PATH_PREFIXES = setOf(
            "/v1/courses/imports",
            "/v1/development/",
            "/v1/authoring/",
        )
        private val RELEASE_MUTATION_PATH = Regex("^/v1/courses/[^/]+/releases/[^/]+/activate$")
    }
}
