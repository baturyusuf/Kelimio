package com.kelimio.api.courseauthoring

import org.assertj.core.api.Assertions.assertThatCode
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class SubsequentCourseDraftConfigurationVerifierTest {
    @Test
    fun `local and test environments may enable the proof producer`() {
        assertThatCode { SubsequentCourseDraftConfigurationVerifier("local") }
            .doesNotThrowAnyException()
        assertThatCode { SubsequentCourseDraftConfigurationVerifier(" TEST ") }
            .doesNotThrowAnyException()
    }

    @Test
    fun `staging and production fail closed when the proof producer is enabled`() {
        listOf("staging", "production", "development", "").forEach { environment ->
            assertThatThrownBy { SubsequentCourseDraftConfigurationVerifier(environment) }
                .isInstanceOf(IllegalArgumentException::class.java)
                .hasMessageContaining("cannot be enabled outside local/test")
        }
    }
}
