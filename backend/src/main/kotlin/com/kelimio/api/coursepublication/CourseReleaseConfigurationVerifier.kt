package com.kelimio.api.coursepublication

import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component

@Component
@ConditionalOnProperty(name = ["KELIMIO_COURSE_RELEASE_ENABLED"], havingValue = "true")
class CourseReleaseConfigurationVerifier(
    @Value("\${KELIMIO_ENVIRONMENT}") environment: String,
) {
    init {
        require(environment.trim().lowercase() in setOf("local", "test")) {
            "Course release activation requires author eligibility, consent, and staging controls outside local/test."
        }
    }
}
