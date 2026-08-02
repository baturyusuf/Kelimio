package com.kelimio.api.web

import com.fasterxml.jackson.databind.ObjectMapper
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.mock.web.MockFilterChain
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import java.nio.charset.StandardCharsets

class CourseImportBodyLimitFilterTest {
    private val filter = CourseImportBodyLimitFilter(ObjectMapper())

    @Test
    fun `rejects oversized import commands before downstream parsing without reflecting content`() {
        val sentinel = "sensitive-workbook-metadata"
        val request = MockHttpServletRequest("POST", "/v1/courses/imports").apply {
            contentType = "application/json"
            setContent((sentinel + "x".repeat(CourseImportBodyLimitFilter.MAX_BODY_BYTES)).toByteArray())
            setAttribute(CorrelationIdFilter.REQUEST_ATTRIBUTE, "request-1")
        }
        val response = MockHttpServletResponse()
        val chain = MockFilterChain()

        filter.doFilter(request, response, chain)

        assertThat(response.status).isEqualTo(413)
        assertThat(response.getHeader("Cache-Control")).isEqualTo("no-store")
        assertThat(response.contentAsString).doesNotContain(sentinel)
        assertThat(chain.request).isNull()
    }

    @Test
    fun `bounds chunked bodies and covers complete and approve paths`() {
        listOf(
            "/v1/courses/imports/${java.util.UUID.randomUUID()}/complete",
            "/v1/courses/imports/${java.util.UUID.randomUUID()}/approve",
        ).forEach { path ->
            val request = object : MockHttpServletRequest("POST", path) {
                override fun getContentLengthLong(): Long = -1
            }.apply {
                setContent(
                    "x".repeat(CourseImportBodyLimitFilter.MAX_BODY_BYTES + 1)
                        .toByteArray(StandardCharsets.UTF_8),
                )
            }
            val response = MockHttpServletResponse()
            filter.doFilter(request, response, MockFilterChain())
            assertThat(response.status).isEqualTo(413)
            assertThat(response.getHeader("Cache-Control")).isEqualTo("no-store")
        }
    }

    @Test
    fun `accepts an exact-limit body and replays the same bytes downstream`() {
        val body = "x".repeat(CourseImportBodyLimitFilter.MAX_BODY_BYTES).toByteArray(StandardCharsets.UTF_8)
        val request = MockHttpServletRequest("POST", "/v1/courses/imports").apply { setContent(body) }
        val response = MockHttpServletResponse()
        val chain = MockFilterChain()

        filter.doFilter(request, response, chain)

        assertThat(chain.request).isNotNull
        assertThat(chain.request!!.inputStream.readAllBytes()).isEqualTo(body)
        assertThat(response.status).isEqualTo(200)
        assertThat(response.getHeader("Cache-Control")).isEqualTo("no-store")
    }

    @Test
    fun `does not consume or cap unrelated paths and methods`() {
        listOf(
            "GET" to "/v1/courses/imports",
            "POST" to "/v1/courses/imports/not-an-id/preview",
            "POST" to "/v1/catalog",
        ).forEach { (method, path) ->
            val body = "x".repeat(CourseImportBodyLimitFilter.MAX_BODY_BYTES + 1).toByteArray()
            val request = MockHttpServletRequest(method, path).apply { setContent(body) }
            val response = MockHttpServletResponse()
            val chain = MockFilterChain()

            filter.doFilter(request, response, chain)

            assertThat(chain.request).isSameAs(request)
            assertThat(chain.request!!.inputStream.readAllBytes()).isEqualTo(body)
            assertThat(response.status).isEqualTo(200)
        }
    }

    @Test
    fun `caps encoded and matrix variants that Spring routes to import commands`() {
        val importId = java.util.UUID.randomUUID()
        listOf(
            "/v1/courses/imports;foo=bar",
            "/v1/courses/%69mports",
            "/v1/courses/imports/$importId;foo=bar/complete",
            "/v1/courses/imports/$importId/%63omplete",
            "/v1/courses/imports/$importId/approve;foo=bar",
        ).forEach { path ->
            val request = MockHttpServletRequest("POST", path).apply {
                setContent("x".repeat(CourseImportBodyLimitFilter.MAX_BODY_BYTES + 1).toByteArray())
            }
            val response = MockHttpServletResponse()
            filter.doFilter(request, response, MockFilterChain())
            assertThat(response.status).describedAs(path).isEqualTo(413)
        }
    }
}
