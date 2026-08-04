package com.kelimio.api.operations

import com.fasterxml.jackson.databind.ObjectMapper
import jakarta.servlet.FilterChain
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import software.amazon.awssdk.services.ssm.SsmClient
import software.amazon.awssdk.services.ssm.model.GetParameterRequest
import software.amazon.awssdk.services.ssm.model.GetParameterResponse
import software.amazon.awssdk.services.ssm.model.Parameter
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset

class OperatingModeTest {
    @Test
    fun `normal mode permits mutations`() {
        val chain = RecordingFilterChain()
        val response = runFilter(OperatingMode.NORMAL, "POST", "/v1/attempts/one/answers", chain)

        assertThat(response.status).isEqualTo(200)
        assertThat(chain.called).isTrue()
    }

    @Test
    fun `conserve mode blocks authoring but permits learning`() {
        val authoringChain = RecordingFilterChain()
        val authoring = runFilter(OperatingMode.CONSERVE, "POST", "/v1/courses/imports", authoringChain)
        val learningChain = RecordingFilterChain()
        val learning = runFilter(OperatingMode.CONSERVE, "POST", "/v1/attempts/one/answers", learningChain)

        assertThat(authoring.status).isEqualTo(503)
        assertThat(authoring.contentAsString)
            .contains("cost-conservation")
            .contains("COST_CONSERVATION")
        assertThat(authoringChain.called).isFalse()
        assertThat(learning.status).isEqualTo(200)
        assertThat(learningChain.called).isTrue()
    }

    @Test
    fun `read only mode permits reads and rejects mutations without forwarding`() {
        val readChain = RecordingFilterChain()
        val read = runFilter(OperatingMode.READ_ONLY, "GET", "/v1/courses", readChain)
        val writeChain = RecordingFilterChain()
        val write = runFilter(OperatingMode.READ_ONLY, "POST", "/v1/enrollments", writeChain)

        assertThat(read.status).isEqualTo(200)
        assertThat(readChain.called).isTrue()
        assertThat(write.status).isEqualTo(503)
        assertThat(write.getHeader("Cache-Control")).isEqualTo("no-store")
        assertThat(write.getHeader("Retry-After")).isEqualTo("3600")
        assertThat(write.contentAsString).contains("cost-read-only")
        assertThat(writeChain.called).isFalse()
    }

    @Test
    fun `suspended mode rejects every api request but not health`() {
        val apiChain = RecordingFilterChain()
        val api = runFilter(OperatingMode.SUSPENDED, "GET", "/v1/courses", apiChain)
        val healthChain = RecordingFilterChain()
        val health = runFilter(OperatingMode.SUSPENDED, "GET", "/actuator/health", healthChain)

        assertThat(api.status).isEqualTo(503)
        assertThat(api.contentAsString).contains("cost-suspended")
        assertThat(apiChain.called).isFalse()
        assertThat(health.status).isEqualTo(200)
        assertThat(healthChain.called).isTrue()
    }

    @Test
    fun `ssm provider fails closed without a snapshot`() {
        val ssm = mock(SsmClient::class.java)
        org.mockito.Mockito.`when`(ssm.getParameter(org.mockito.ArgumentMatchers.any(GetParameterRequest::class.java)))
            .thenThrow(IllegalStateException("unavailable"))
        val provider = provider(ssm)

        assertThat(provider.current()).isEqualTo(OperatingMode.SUSPENDED)
    }

    @Test
    fun `ssm provider parses a valid server mode`() {
        val ssm = mock(SsmClient::class.java)
        org.mockito.Mockito.`when`(ssm.getParameter(org.mockito.ArgumentMatchers.any(GetParameterRequest::class.java)))
            .thenReturn(
                GetParameterResponse.builder()
                    .parameter(Parameter.builder().value("READ_ONLY").build())
                    .build(),
            )

        assertThat(provider(ssm).current()).isEqualTo(OperatingMode.READ_ONLY)
    }

    @Test
    fun `ssm provider retains only a bounded last known mode before failing closed`() {
        val ssm = mock(SsmClient::class.java)
        org.mockito.Mockito.`when`(ssm.getParameter(org.mockito.ArgumentMatchers.any(GetParameterRequest::class.java)))
            .thenReturn(
                GetParameterResponse.builder()
                    .parameter(Parameter.builder().value("CONSERVE").build())
                    .build(),
            )
            .thenThrow(IllegalStateException("unavailable"))
        val clock = MutableClock(Instant.parse("2026-08-04T00:00:00Z"))
        val provider = provider(ssm, clock)

        assertThat(provider.current()).isEqualTo(OperatingMode.CONSERVE)
        clock.advance(Duration.ofMinutes(1))
        assertThat(provider.current()).isEqualTo(OperatingMode.CONSERVE)
        clock.advance(Duration.ofMinutes(5))
        assertThat(provider.current()).isEqualTo(OperatingMode.SUSPENDED)
    }

    @Test
    fun `production configuration requires the server operating mode parameter`() {
        assertThatThrownBy {
            OperatingModeConfiguration().operatingModeProvider("production", "NORMAL", "")
        }.isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("required in production")
    }

    @Test
    fun `local configuration rejects a production parameter`() {
        assertThatThrownBy {
            OperatingModeConfiguration().operatingModeProvider(
                "local",
                "NORMAL",
                "/kelimio/production/operating-mode",
            )
        }.isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("production-only")
    }

    private fun provider(
        ssm: SsmClient,
        clock: Clock = Clock.fixed(Instant.parse("2026-08-04T00:00:00Z"), ZoneOffset.UTC),
    ): SsmOperatingModeProvider =
        SsmOperatingModeProvider(
            ssmClient = ssm,
            parameterName = "/kelimio/production/operating-mode",
            clock = clock,
            refreshInterval = Duration.ofSeconds(30),
            maximumStaleness = Duration.ofMinutes(5),
        )

    private fun runFilter(
        mode: OperatingMode,
        method: String,
        path: String,
        chain: RecordingFilterChain,
    ): MockHttpServletResponse {
        val request = MockHttpServletRequest(method, path)
        val response = MockHttpServletResponse()
        OperatingModeFilter(OperatingModeProvider { mode }, ObjectMapper()).doFilter(request, response, chain)
        return response
    }

    private class RecordingFilterChain : FilterChain {
        var called = false

        override fun doFilter(
            request: jakarta.servlet.ServletRequest,
            response: jakarta.servlet.ServletResponse,
        ) {
            called = true
        }
    }

    private class MutableClock(
        private var current: Instant,
    ) : Clock() {
        override fun getZone() = ZoneOffset.UTC

        override fun withZone(zone: java.time.ZoneId): Clock = this

        override fun instant(): Instant = current

        fun advance(duration: Duration) {
            current = current.plus(duration)
        }
    }
}
