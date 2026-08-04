package com.kelimio.api.web

import com.fasterxml.jackson.databind.ObjectMapper
import jakarta.servlet.FilterChain
import jakarta.servlet.ServletInputStream
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import java.util.UUID

class AnswerSubmissionBodyLimitFilterTest {
    private val objectMapper = ObjectMapper()
    private val bodyLimitFilter = AnswerSubmissionBodyLimitFilter(objectMapper)
    private val correlationIdFilter = CorrelationIdFilter()

    @Test
    fun `rejects declared oversized answer bodies before reading or invoking downstream code`() {
        val requestId = UUID.randomUUID().toString()
        var inputRead = false
        val request = object : MockHttpServletRequest() {
            override fun getContentLength(): Int = AnswerSubmissionBodyLimitFilter.MAX_BODY_BYTES + 1

            override fun getContentLengthLong(): Long = contentLength.toLong()

            override fun getInputStream(): ServletInputStream {
                inputRead = true
                return super.getInputStream()
            }
        }.answerSubmissionRequest(requestId)
        val response = MockHttpServletResponse()
        var downstreamInvoked = false

        runFilters(request, response) { _, _ -> downstreamInvoked = true }

        assertThat(inputRead).isFalse()
        assertThat(downstreamInvoked).isFalse()
        assertPayloadTooLarge(response, requestId)
    }

    @Test
    fun `bounds chunked answer bodies and never echoes their contents`() {
        val requestId = UUID.randomUUID().toString()
        val sensitiveMarker = "private-chunked-answer"
        val oversizedBody = (sensitiveMarker + "x".repeat(AnswerSubmissionBodyLimitFilter.MAX_BODY_BYTES))
            .toByteArray(Charsets.UTF_8)
        val request = object : MockHttpServletRequest() {
            override fun getContentLength(): Int = -1

            override fun getContentLengthLong(): Long = -1
        }.answerSubmissionRequest(requestId).also { it.setContent(oversizedBody) }
        val response = MockHttpServletResponse()
        var downstreamInvoked = false

        runFilters(request, response) { _, _ -> downstreamInvoked = true }

        assertThat(downstreamInvoked).isFalse()
        assertPayloadTooLarge(response, requestId)
        assertThat(response.contentAsString).doesNotContain(sensitiveMarker)
    }

    @Test
    fun `matrix parameters cannot bypass the answer body cap`() {
        val requestId = UUID.randomUUID().toString()
        val request = object : MockHttpServletRequest() {
            override fun getContentLength(): Int = AnswerSubmissionBodyLimitFilter.MAX_BODY_BYTES + 1

            override fun getContentLengthLong(): Long = contentLength.toLong()
        }.answerSubmissionRequest(requestId).also {
            it.requestURI =
                "/v1/attempts;scope=local/${UUID.randomUUID()};probe=one/answers;probe=two"
        }
        val response = MockHttpServletResponse()
        var downstreamInvoked = false

        runFilters(request, response) { _, _ -> downstreamInvoked = true }

        assertThat(downstreamInvoked).isFalse()
        assertPayloadTooLarge(response, requestId)
    }

    @Test
    fun `percent encoded literal cannot bypass the answer body cap`() {
        val requestId = UUID.randomUUID().toString()
        val request = object : MockHttpServletRequest() {
            override fun getContentLength(): Int = AnswerSubmissionBodyLimitFilter.MAX_BODY_BYTES + 1

            override fun getContentLengthLong(): Long = contentLength.toLong()
        }.answerSubmissionRequest(requestId).also {
            it.requestURI = "/v1/attempts/${UUID.randomUUID()}/%61nswers"
        }
        val response = MockHttpServletResponse()
        var downstreamInvoked = false

        runFilters(request, response) { _, _ -> downstreamInvoked = true }

        assertThat(downstreamInvoked).isFalse()
        assertPayloadTooLarge(response, requestId)
    }

    @Test
    fun `passes an exact limit body through a repeatable bounded request`() {
        val requestId = UUID.randomUUID().toString()
        val body = ByteArray(AnswerSubmissionBodyLimitFilter.MAX_BODY_BYTES) { 'a'.code.toByte() }
        val request = object : MockHttpServletRequest() {
            override fun getContentLength(): Int = -1

            override fun getContentLengthLong(): Long = -1
        }.answerSubmissionRequest(requestId).also { it.setContent(body) }
        val response = MockHttpServletResponse()
        var downstreamBody: ByteArray? = null

        runFilters(request, response) { boundedRequest, _ ->
            downstreamBody = boundedRequest.inputStream.readAllBytes()
        }

        assertThat(downstreamBody).isEqualTo(body)
        assertThat(response.getHeader(HttpHeaders.CACHE_CONTROL)).isEqualTo("no-store")
        assertThat(response.getHeader(CorrelationIdFilter.HEADER_NAME)).isEqualTo(requestId)
    }

    private fun MockHttpServletRequest.answerSubmissionRequest(requestId: String): MockHttpServletRequest =
        apply {
            method = "POST"
            requestURI = "/v1/attempts/${UUID.randomUUID()}/answers"
            contentType = MediaType.APPLICATION_JSON_VALUE
            addHeader(CorrelationIdFilter.HEADER_NAME, requestId)
        }

    private fun runFilters(
        request: MockHttpServletRequest,
        response: MockHttpServletResponse,
        downstream: (jakarta.servlet.ServletRequest, jakarta.servlet.ServletResponse) -> Unit,
    ) {
        correlationIdFilter.doFilter(
            request,
            response,
            FilterChain { correlatedRequest, correlatedResponse ->
                bodyLimitFilter.doFilter(
                    correlatedRequest,
                    correlatedResponse,
                    FilterChain { boundedRequest, boundedResponse ->
                        downstream(boundedRequest, boundedResponse)
                    },
                )
            },
        )
    }

    private fun assertPayloadTooLarge(response: MockHttpServletResponse, requestId: String) {
        assertThat(response.status).isEqualTo(413)
        assertThat(response.contentType).isEqualTo(MediaType.APPLICATION_PROBLEM_JSON_VALUE)
        assertThat(response.getHeader(HttpHeaders.CACHE_CONTROL)).isEqualTo("no-store")
        assertThat(response.getHeader(CorrelationIdFilter.HEADER_NAME)).isEqualTo(requestId)
        val problem = objectMapper.readTree(response.contentAsByteArray)
        assertThat(problem["type"].asText())
            .isEqualTo("https://api.kelimio.invalid/problems/payload-too-large")
        assertThat(problem["title"].asText()).isEqualTo("Payload Too Large")
        assertThat(problem["status"].asInt()).isEqualTo(413)
        assertThat(problem["detail"].asText()).isEqualTo("The request body is too large.")
        assertThat(problem["instance"].asText())
            .matches("/v1/attempts.+/(?:answers|%61nswers)(?:;.*)?")
        assertThat(problem["requestId"].asText()).isEqualTo(requestId)
    }
}
