package com.kelimio.api.development

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class InternalTesterPolicyTest {
    @Test
    fun `production internal tester group enables the bounded starter course`() {
        assertThat(
            InternalTesterPolicy.canInstallStarterCourse(
                environment = "production",
                groups = listOf(InternalTesterPolicy.GROUP_NAME),
            ),
        ).isTrue()
    }

    @Test
    fun `production users outside the internal tester group remain denied`() {
        assertThat(
            InternalTesterPolicy.canInstallStarterCourse(
                environment = "production",
                groups = emptyList(),
            ),
        ).isFalse()
    }

    @Test
    fun `a copied group claim cannot enable the production path outside production`() {
        assertThat(
            InternalTesterPolicy.canInstallStarterCourse(
                environment = "local",
                groups = listOf(InternalTesterPolicy.GROUP_NAME),
            ),
        ).isFalse()
    }
}
