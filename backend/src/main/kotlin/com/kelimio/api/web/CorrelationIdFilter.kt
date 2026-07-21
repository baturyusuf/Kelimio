package com.kelimio.api.web

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.MDC
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.util.UUID

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
class CorrelationIdFilter : OncePerRequestFilter() {
    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        val incoming = request.getHeader(HEADER_NAME) ?: request.getHeader(LEGACY_HEADER_NAME)
        val correlationId = incoming?.let { runCatching { UUID.fromString(it).toString() }.getOrNull() }
            ?: UUID.randomUUID().toString()
        request.setAttribute(REQUEST_ATTRIBUTE, correlationId)
        response.setHeader(HEADER_NAME, correlationId)
        response.setHeader(LEGACY_HEADER_NAME, correlationId)
        MDC.put(MDC_KEY, correlationId)
        try {
            filterChain.doFilter(request, response)
        } finally {
            MDC.remove(MDC_KEY)
        }
    }

    companion object {
        const val HEADER_NAME = "X-Request-Id"
        const val LEGACY_HEADER_NAME = "X-Correlation-ID"
        const val REQUEST_ATTRIBUTE = "kelimio.correlation-id"
        const val MDC_KEY = "correlationId"
    }
}
