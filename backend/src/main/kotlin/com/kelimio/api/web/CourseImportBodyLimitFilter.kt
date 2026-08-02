package com.kelimio.api.web

import com.fasterxml.jackson.databind.ObjectMapper
import jakarta.servlet.FilterChain
import jakarta.servlet.ReadListener
import jakarta.servlet.ServletInputStream
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletRequestWrapper
import jakarta.servlet.http.HttpServletResponse
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.server.PathContainer
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import org.springframework.web.util.pattern.PathPatternParser
import java.io.BufferedReader
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStreamReader
import java.nio.charset.Charset
import java.nio.charset.StandardCharsets

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
class CourseImportBodyLimitFilter(
    private val objectMapper: ObjectMapper,
) : OncePerRequestFilter() {
    override fun shouldNotFilter(request: HttpServletRequest): Boolean {
        if (request.method != "POST") return true
        val path = PathContainer.parsePath(request.requestURI.removePrefix(request.contextPath.orEmpty()))
        return IMPORT_COMMAND_PATHS.none { it.matches(path) }
    }

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        response.setHeader(HttpHeaders.CACHE_CONTROL, "no-store")
        if (request.contentLengthLong > MAX_BODY_BYTES) return payloadTooLarge(request, response)
        val body = try {
            val output = ByteArrayOutputStream(request.contentLengthLong.coerceIn(0, MAX_BODY_BYTES.toLong()).toInt())
            val buffer = ByteArray(1024)
            var remaining = MAX_BODY_BYTES
            while (true) {
                val read = request.inputStream.read(buffer, 0, minOf(buffer.size, remaining + 1))
                if (read < 0) break
                if (read > remaining) throw BodyTooLargeException()
                output.write(buffer, 0, read)
                remaining -= read
            }
            output.toByteArray()
        } catch (_: BodyTooLargeException) {
            return payloadTooLarge(request, response)
        }
        filterChain.doFilter(CachedRequest(request, body), response)
    }

    private fun payloadTooLarge(request: HttpServletRequest, response: HttpServletResponse) {
        response.status = HttpStatus.PAYLOAD_TOO_LARGE.value()
        response.contentType = MediaType.APPLICATION_PROBLEM_JSON_VALUE
        response.setHeader(HttpHeaders.CACHE_CONTROL, "no-store")
        objectMapper.writeValue(
            response.outputStream,
            mapOf(
                "type" to "https://api.kelimio.invalid/problems/payload-too-large",
                "title" to HttpStatus.PAYLOAD_TOO_LARGE.reasonPhrase,
                "status" to HttpStatus.PAYLOAD_TOO_LARGE.value(),
                "detail" to "The request body is too large.",
                "instance" to request.requestURI,
                "requestId" to request.getAttribute(CorrelationIdFilter.REQUEST_ATTRIBUTE),
            ),
        )
    }

    private class CachedRequest(request: HttpServletRequest, private val bytes: ByteArray) :
        HttpServletRequestWrapper(request) {
        override fun getContentLength(): Int = bytes.size
        override fun getContentLengthLong(): Long = bytes.size.toLong()
        override fun getInputStream(): ServletInputStream = ByteArrayServletInputStream(bytes)
        override fun getReader(): BufferedReader = BufferedReader(
            InputStreamReader(inputStream, Charset.forName(characterEncoding ?: StandardCharsets.UTF_8.name())),
        )
    }

    private class ByteArrayServletInputStream(bytes: ByteArray) : ServletInputStream() {
        private val input = ByteArrayInputStream(bytes)
        override fun read(): Int = input.read()
        override fun read(bytes: ByteArray, offset: Int, length: Int): Int = input.read(bytes, offset, length)
        override fun isFinished(): Boolean = input.available() == 0
        override fun isReady(): Boolean = true
        override fun setReadListener(listener: ReadListener?) {
            if (listener == null) return
            try {
                if (!isFinished) listener.onDataAvailable()
                if (isFinished) listener.onAllDataRead()
            } catch (failure: Exception) {
                listener.onError(failure)
            }
        }
    }

    private class BodyTooLargeException : RuntimeException()

    companion object {
        const val MAX_BODY_BYTES = 8 * 1024
        private val IMPORT_COMMAND_PATHS = listOf(
            PathPatternParser.defaultInstance.parse("/v1/courses/imports"),
            PathPatternParser.defaultInstance.parse("/v1/courses/imports/{importId}/complete"),
            PathPatternParser.defaultInstance.parse("/v1/courses/imports/{importId}/approve"),
        )
    }
}
