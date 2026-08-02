package com.kelimio.api.development

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class LocalStarterCoursePrivacyTest {
    @Test
    fun `starter diagnostics redact authored answer material`() {
        val matching = LocalStarterCourseDefinition.questions.last()

        assertThat(matching.toString())
            .contains("matchingPairs=[REDACTED]")
            .doesNotContain("Pencere")
            .doesNotContain("Window")
        assertThat(matching.matchingPairs.first().toString())
            .contains("[REDACTED]")
            .doesNotContain("Pencere")
            .doesNotContain("Window")
    }
}
