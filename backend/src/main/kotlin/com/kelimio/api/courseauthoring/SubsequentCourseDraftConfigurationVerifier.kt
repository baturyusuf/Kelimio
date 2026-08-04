package com.kelimio.api.courseauthoring

import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component

@Component
@ConditionalOnProperty(name = ["KELIMIO_LOCAL_COURSE_AUTHORING_ENABLED"], havingValue = "true")
internal class SubsequentCourseDraftConfigurationVerifier(
    @Value("\${KELIMIO_ENVIRONMENT}") environment: String,
) {
    init {
        require(environment.trim().lowercase() in setOf("local", "test")) {
            "Local course authoring cannot be enabled outside local/test environments."
        }
    }
}
