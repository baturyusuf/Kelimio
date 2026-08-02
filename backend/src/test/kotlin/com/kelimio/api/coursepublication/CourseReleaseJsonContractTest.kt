package com.kelimio.api.coursepublication

import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.databind.json.JsonMapper
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import com.fasterxml.jackson.module.kotlin.KotlinModule
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.OffsetDateTime
import java.util.UUID

class CourseReleaseJsonContractTest {
    private val mapper = JsonMapper.builder()
        .addModule(KotlinModule.Builder().build())
        .addModule(JavaTimeModule())
        .defaultPropertyInclusion(
            JsonInclude.Value.construct(JsonInclude.Include.NON_NULL, JsonInclude.Include.NON_NULL),
        )
        .build()

    @Test
    fun `initial release responses retain required nullable identifiers`() {
        val courseId = UUID.randomUUID()
        val releaseId = UUID.randomUUID()
        val changeSetId = UUID.randomUUID()
        val impact = CourseReleaseImpactResponse(
            courseId = courseId,
            targetReleaseId = releaseId,
            expectedActiveReleaseId = null,
            sourceChangeSetId = changeSetId,
            operation = CourseReleaseOperation.INITIAL_PUBLICATION,
            releaseRevision = 1,
            targetQuestionCount = 1,
            unchangedQuestionCount = 0,
            changedQuestionCount = 0,
            addedQuestionCount = 1,
            removedQuestionCount = 0,
            affectedEnrollmentCount = 0,
            requiredClientCapabilities = emptyList(),
            impactBindingSha256 = "a".repeat(64),
        )
        val activation = CourseReleaseActivationResponse(
            activationId = UUID.randomUUID(),
            courseId = courseId,
            releaseId = releaseId,
            previousReleaseId = null,
            sourceChangeSetId = changeSetId,
            operation = CourseReleaseOperation.INITIAL_PUBLICATION,
            releaseRevision = 1,
            questionCount = 1,
            requiredClientCapabilities = emptyList(),
            coursePublicationStatus = "PUBLISHED",
            reprojectionStatus = "COMPLETED",
            activatedAt = OffsetDateTime.parse("2026-08-02T00:00:00Z"),
            created = true,
        )

        val impactJson = mapper.readTree(mapper.writeValueAsBytes(impact))
        val activationJson = mapper.readTree(mapper.writeValueAsBytes(activation))

        assertThat(impactJson.has("expectedActiveReleaseId")).isTrue()
        assertThat(impactJson["expectedActiveReleaseId"].isNull).isTrue()
        assertThat(activationJson.has("previousReleaseId")).isTrue()
        assertThat(activationJson["previousReleaseId"].isNull).isTrue()
    }
}
