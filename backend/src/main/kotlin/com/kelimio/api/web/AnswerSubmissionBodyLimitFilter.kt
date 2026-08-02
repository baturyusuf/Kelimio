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

/**
 * Bounds answer JSON before Jackson allocation, authentication, or transactional command handling.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
class AnswerSubmissionBodyLimitFilter(
    private val objectMapper: ObjectMapper,
) : OncePerRequestFilter() {
    override fun shouldNotFilter(request: HttpServletRequest): Boolean =
        request.method != "POST" ||
            !ANSWER_SUBMISSION_PATH.matches(
                PathContainer.parsePath(request.requestURI.removeContextPath(request)),
            )

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        response.setHeader(HttpHeaders.CACHE_CONTROL, "no-store")
        if (request.contentLengthLong > MAX_BODY_BYTES) {
            writePayloadTooLarge(request, response)
            return
        }
        val body = try {
            readBoundedBody(request)
        } catch (_: AnswerSubmissionBodyTooLargeException) {
            writePayloadTooLarge(request, response)
            return
        }
        filterChain.doFilter(CachedBodyRequest(request, body), response)
    }

    private fun readBoundedBody(request: HttpServletRequest): ByteArray {
        val initialCapacity = request.contentLengthLong
            .coerceIn(0, MAX_BODY_BYTES.toLong())
            .toInt()
        val output = ByteArrayOutputStream(initialCapacity)
        val buffer = ByteArray(READ_BUFFER_BYTES)
        var remaining = MAX_BODY_BYTES
        while (true) {
            val read = request.inputStream.read(buffer, 0, minOf(buffer.size, remaining + 1))
            if (read < 0) break
            if (read > remaining) throw AnswerSubmissionBodyTooLargeException()
            output.write(buffer, 0, read)
            remaining -= read
        }
        return output.toByteArray()
    }

    private fun writePayloadTooLarge(
        request: HttpServletRequest,
        response: HttpServletResponse,
    ) {
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

    private fun String.removeContextPath(request: HttpServletRequest): String =
        removePrefix(request.contextPath.orEmpty())

    private class CachedBodyRequest(
        request: HttpServletRequest,
        private val body: ByteArray,
    ) : HttpServletRequestWrapper(request) {
        override fun getContentLength(): Int = body.size

        override fun getContentLengthLong(): Long = body.size.toLong()

        override fun getInputStream(): ServletInputStream = ByteArrayServletInputStream(body)

        override fun getReader(): BufferedReader =
            BufferedReader(
                InputStreamReader(
                    inputStream,
                    Charset.forName(characterEncoding ?: StandardCharsets.UTF_8.name()),
                ),
            )
    }

    private class ByteArrayServletInputStream(body: ByteArray) : ServletInputStream() {
        private val input = ByteArrayInputStream(body)

        override fun read(): Int = input.read()

        override fun read(bytes: ByteArray, offset: Int, length: Int): Int = input.read(bytes, offset, length)

        override fun isFinished(): Boolean = input.available() == 0

        override fun isReady(): Boolean = true

        override fun setReadListener(listener: ReadListener?) {
            if (listener == null) return
            try {
                if (!isFinished) listener.onDataAvailable()
                if (isFinished) listener.onAllDataRead()
            } catch (exception: Exception) {
                listener.onError(exception)
            }
        }
    }

    private class AnswerSubmissionBodyTooLargeException : RuntimeException()

    companion object {
        const val MAX_BODY_BYTES = 8 * 1024
        private const val READ_BUFFER_BYTES = 1024
        // Use the same path semantics as Spring MVC so matrix parameters cannot bypass the pre-Jackson cap.
        private val ANSWER_SUBMISSION_PATH =
            PathPatternParser.defaultInstance.parse("/v1/attempts/{attemptId}/answers")
    }
}
