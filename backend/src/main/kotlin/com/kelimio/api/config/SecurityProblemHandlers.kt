package com.kelimio.api.config

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.web.CorrelationIdFilter
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.security.access.AccessDeniedException
import org.springframework.security.core.AuthenticationException
import org.springframework.security.web.AuthenticationEntryPoint
import org.springframework.security.web.access.AccessDeniedHandler
import org.springframework.stereotype.Component

@Component
class SecurityProblemWriter(
    private val objectMapper: ObjectMapper,
) {
    fun write(
        request: HttpServletRequest,
        response: HttpServletResponse,
        status: HttpStatus,
        type: String,
        detail: String,
    ) {
        response.status = status.value()
        response.contentType = MediaType.APPLICATION_PROBLEM_JSON_VALUE
        objectMapper.writeValue(
            response.outputStream,
            mapOf(
                "type" to "https://api.kelimio.invalid/problems/$type",
                "title" to status.reasonPhrase,
                "status" to status.value(),
                "detail" to detail,
                "instance" to request.requestURI,
                "requestId" to request.getAttribute(CorrelationIdFilter.REQUEST_ATTRIBUTE),
            ),
        )
    }
}

@Component
class ProblemAuthenticationEntryPoint(
    private val writer: SecurityProblemWriter,
) : AuthenticationEntryPoint {
    @Suppress("UNUSED_PARAMETER")
    override fun commence(
        request: HttpServletRequest,
        response: HttpServletResponse,
        authException: AuthenticationException,
    ) {
        writer.write(request, response, HttpStatus.UNAUTHORIZED, "unauthorized", "Authentication is required.")
    }
}

@Component
class ProblemAccessDeniedHandler(
    private val writer: SecurityProblemWriter,
) : AccessDeniedHandler {
    @Suppress("UNUSED_PARAMETER")
    override fun handle(
        request: HttpServletRequest,
        response: HttpServletResponse,
        accessDeniedException: AccessDeniedException,
    ) {
        writer.write(request, response, HttpStatus.FORBIDDEN, "forbidden", "Access is denied.")
    }
}
