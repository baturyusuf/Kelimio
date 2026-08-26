package com.kelimio.api.coursepublication

import org.assertj.core.api.Assertions.assertThatCode
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class CourseReleaseConfigurationVerifierTest {
    @Test
    fun `local and test release activation remain available without production flag`() {
        assertThatCode { CourseReleaseConfigurationVerifier("local", false) }.doesNotThrowAnyException()
        assertThatCode { CourseReleaseConfigurationVerifier("test", false) }.doesNotThrowAnyException()
    }

    @Test
    fun `production release activation requires the teacher feature gate`() {
        assertThatThrownBy { CourseReleaseConfigurationVerifier("production", false) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("KELIMIO_PRODUCTION_TEACHER_FEATURES_ENABLED=true")

        assertThatCode { CourseReleaseConfigurationVerifier("production", true) }.doesNotThrowAnyException()
    }

    @Test
    fun `unknown environments fail closed`() {
        assertThatThrownBy { CourseReleaseConfigurationVerifier("staging", true) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("KELIMIO_ENVIRONMENT")
    }
}
