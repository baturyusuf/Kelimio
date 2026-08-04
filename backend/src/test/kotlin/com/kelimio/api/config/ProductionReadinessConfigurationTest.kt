package com.kelimio.api.config

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.boot.env.YamlPropertySourceLoader
import org.springframework.core.io.ClassPathResource

class ProductionReadinessConfigurationTest {
    @Test
    fun `readiness fails closed when PostgreSQL is unavailable`() {
        val propertySource = YamlPropertySourceLoader()
            .load("application", ClassPathResource("application.yml"))
            .single()

        assertThat(
            propertySource.getProperty("management.endpoint.health.group.readiness.include"),
        ).isEqualTo("readinessState,db")
    }
}
