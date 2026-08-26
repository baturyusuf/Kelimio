package com.kelimio.api.coursepublication

import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component

@Component
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
class CourseReleaseConfigurationVerifier(
    @Value("\${KELIMIO_ENVIRONMENT}") environment: String,
    @Value("\${KELIMIO_PRODUCTION_TEACHER_FEATURES_ENABLED:false}") productionEnabled: Boolean,
) {
    init {
        val normalizedEnvironment = environment.trim().lowercase()
        require(normalizedEnvironment in setOf("local", "test", "production")) {
            "KELIMIO_ENVIRONMENT must be local, test, or production."
        }
        require(normalizedEnvironment != "production" || productionEnabled) {
            "Production course release activation requires KELIMIO_PRODUCTION_TEACHER_FEATURES_ENABLED=true."
        }
    }
}
