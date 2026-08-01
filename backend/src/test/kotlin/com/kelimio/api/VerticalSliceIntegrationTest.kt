package com.kelimio.api

import com.fasterxml.jackson.databind.ObjectMapper
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.transaction.support.TransactionTemplate
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.utility.DockerImageName
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers(disabledWithoutDocker = true)
class VerticalSliceIntegrationTest {
    @Autowired
    private lateinit var mockMvc: MockMvc

    @Autowired
    private lateinit var objectMapper: ObjectMapper

    @Autowired
    private lateinit var jdbcTemplate: JdbcTemplate

    @Autowired
    private lateinit var transactionTemplate: TransactionTemplate

    @Test
    fun `authenticated learner completes a real server-scored attempt idempotently`() {
        val fixture = createCourseFixture()
        val learnerJwt = jwt().jwt {
            it.subject("integration-learner")
                .claim("email", "learner@integration.invalid")
                .claim("preferred_username", "integration-learner")
                .audience(listOf("kelimio-mobile"))
        }

        mockMvc.get("/v1/me") { with(learnerJwt) }
            .andExpect { status { isOk() } }
            .andExpect { header { exists("X-Request-Id") } }

        mockMvc.get("/v1/catalog/courses")
            .andExpect { status { isUnauthorized() } }

        mockMvc.get("/v1/catalog/courses") { with(learnerJwt) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.items[0].id") { value(fixture.courseId.toString()) } }

        mockMvc.post("/v1/courses/${fixture.courseId}/enrollments") {
            with(learnerJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
            contentType = MediaType.APPLICATION_JSON
            content = """{"supportLanguage":"en"}"""
        }.andExpect { status { isCreated() } }

        val startBody = mockMvc.post("/v1/tests/${fixture.testId}/attempts") {
            with(learnerJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
        }.andExpect {
            status { isCreated() }
            jsonPath("$.questions[0].questionRevisionId") { value(fixture.questionRevisionId.toString()) }
            jsonPath("$.questions[0].options[0].correct") { doesNotExist() }
            jsonPath("$.questions[0].correctOptionId") { doesNotExist() }
        }.andReturn().response.contentAsString
        val startJson = objectMapper.readTree(startBody)
        val attemptId = UUID.fromString(startJson["id"].asText())

        val submissionId = UUID.randomUUID()
        val answerJson = """
            {
              "submissionId":"$submissionId",
              "questionRevisionId":"${fixture.questionRevisionId}",
              "selectedOptionId":"${fixture.correctOptionId}"
            }
        """.trimIndent()
        mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", submissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = answerJson
        }.andExpect {
            status { isOk() }
            jsonPath("$.correct") { value(true) }
            jsonPath("$.activeScoreDelta") { value(60) }
            jsonPath("$.lifetimeScoreDelta") { value(60) }
            jsonPath("$.activeQuestionScore") { value(60) }
            jsonPath("$.lifetimeScore") { value(60) }
            jsonPath("$.energy.balance") { value(5) }
            jsonPath("$.attemptState") { value("IN_PROGRESS") }
        }

        mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", submissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = answerJson
        }.andExpect {
            status { isOk() }
            jsonPath("$.activeScoreDelta") { value(60) }
            jsonPath("$.lifetimeScore") { value(60) }
        }

        mockMvc.post("/v1/attempts/$attemptId/finish") {
            with(learnerJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.state") { value("COMPLETED_PASS") }
                jsonPath("$.correctRatio") { value(1.0) }
            }

        assertThat(count("score_event", "submission_id", submissionId)).isEqualTo(1)
        assertThat(count("answer_submission", "submission_id", submissionId)).isEqualTo(1)
        assertThat(jdbcTemplate.queryForObject("select count(*) from outbox_event", Int::class.java)).isGreaterThanOrEqualTo(3)
    }

    private fun createCourseFixture(): Fixture {
        val fixture = Fixture(
            courseId = UUID.randomUUID(),
            testId = UUID.randomUUID(),
            questionRevisionId = UUID.randomUUID(),
            correctOptionId = UUID.randomUUID(),
        )
        transactionTemplate.executeWithoutResult {
            val now = OffsetDateTime.now(ZoneOffset.UTC)
            val ownerId = UUID.randomUUID()
            val releaseId = UUID.randomUUID()
            val testRevisionId = UUID.randomUUID()
            val questionId = UUID.randomUUID()
            jdbcTemplate.update(
                "insert into app_user(id, oidc_subject, email, display_name, username, app_locale, active_target_language, time_zone, created_at, updated_at) values (?, ?, ?, ?, ?, 'tr', 'tr', 'UTC', ?, ?)",
                ownerId,
                "integration-owner-${fixture.courseId}",
                "owner@integration.invalid",
                "Integration Owner",
                "integration-owner",
                now,
                now,
            )
            jdbcTemplate.update(
                "insert into course(id, owner_user_id, name, description, target_language, default_support_language, visibility, publication_status, access_type, created_at, updated_at, active_release_id) values (?, ?, ?, ?, 'tr', 'en', 'PUBLIC', 'DRAFT', 'FREE', ?, ?, ?)",
                fixture.courseId,
                ownerId,
                "Integration Turkish",
                "A real database-backed test course",
                now,
                now,
                releaseId,
            )
            jdbcTemplate.update(
                "insert into course_support_language(course_id, language_code) values (?, 'en')",
                fixture.courseId,
            )
            jdbcTemplate.update(
                "insert into course_release(id, course_id, revision_number, status, created_at) values (?, ?, 1, 'DRAFT', ?)",
                releaseId,
                fixture.courseId,
                now,
            )
            jdbcTemplate.update(
                "insert into course_test(id, course_id, created_at) values (?, ?, ?)",
                fixture.testId,
                fixture.courseId,
                now,
            )
            jdbcTemplate.update(
                "insert into test_revision(id, test_id, course_id, revision_number, title, status, pass_threshold, created_at) values (?, ?, ?, 1, 'Words', 'DRAFT', 0.5000, ?)",
                testRevisionId,
                fixture.testId,
                fixture.courseId,
                now,
            )
            jdbcTemplate.update(
                "insert into question(id, course_id, created_at) values (?, ?, ?)",
                questionId,
                fixture.courseId,
                now,
            )
            jdbcTemplate.update(
                "insert into question_revision(id, question_id, course_id, revision_number, question_type, prompt, correct_answer, status, created_at) values (?, ?, ?, 1, 'A', 'Pencere', 'Window', 'DRAFT', ?)",
                fixture.questionRevisionId,
                questionId,
                fixture.courseId,
                now,
            )
            val options = listOf(
                fixture.correctOptionId to "Window",
                UUID.randomUUID() to "Door",
                UUID.randomUUID() to "Table",
                UUID.randomUUID() to "Chair",
            )
            options.forEachIndexed { index, (id, text) ->
                jdbcTemplate.update(
                    "insert into question_revision_option(id, question_revision_id, option_text, is_correct, position) values (?, ?, ?, ?, ?)",
                    id,
                    fixture.questionRevisionId,
                    text,
                    id == fixture.correctOptionId,
                    index + 1,
                )
            }
            jdbcTemplate.update(
                "update question_revision set status = 'ACTIVE' where id = ?",
                fixture.questionRevisionId,
            )
            jdbcTemplate.update(
                "insert into test_revision_question(test_revision_id, question_revision_id, question_id, course_id, position) values (?, ?, ?, ?, 1)",
                testRevisionId,
                fixture.questionRevisionId,
                questionId,
                fixture.courseId,
            )
            jdbcTemplate.update(
                "update test_revision set status = 'ACTIVE' where id = ?",
                testRevisionId,
            )
            jdbcTemplate.update(
                "insert into course_release_test_revision(course_release_id, test_revision_id, test_id, course_id, position) values (?, ?, ?, ?, 1)",
                releaseId,
                testRevisionId,
                fixture.testId,
                fixture.courseId,
            )
            jdbcTemplate.update(
                "update course_release set status = 'ACTIVE' where id = ?",
                releaseId,
            )
            jdbcTemplate.update(
                "update course set publication_status = 'PUBLISHED', updated_at = ? where id = ?",
                now,
                fixture.courseId,
            )
        }
        return fixture
    }

    private fun count(
        table: String,
        idColumn: String,
        id: UUID,
    ): Int = jdbcTemplate.queryForObject("select count(*) from $table where $idColumn = ?", Int::class.java, id)!!

    data class Fixture(
        val courseId: UUID,
        val testId: UUID,
        val questionRevisionId: UUID,
        val correctOptionId: UUID,
    )

    private class KPostgreSQLContainer(image: DockerImageName) : PostgreSQLContainer<KPostgreSQLContainer>(image)

    companion object {
        @Container
        @JvmStatic
        private val postgres = KPostgreSQLContainer(
            DockerImageName
                .parse("postgres:17.5-alpine@sha256:6567bca8d7bc8c82c5922425a0baee57be8402df92bae5eacad5f01ae9544daa")
                .asCompatibleSubstituteFor("postgres"),
        )

        @DynamicPropertySource
        @JvmStatic
        fun databaseProperties(registry: DynamicPropertyRegistry) {
            registry.add("KELIMIO_DB_URL", postgres::getJdbcUrl)
            registry.add("KELIMIO_DB_USER", postgres::getUsername)
            registry.add("KELIMIO_DB_PASSWORD", postgres::getPassword)
            registry.add("KELIMIO_ENVIRONMENT") { "test" }
            registry.add("KELIMIO_OIDC_ISSUER") { "https://issuer.integration.invalid" }
            registry.add("KELIMIO_OIDC_AUDIENCE") { "kelimio-mobile" }
            registry.add("KELIMIO_OIDC_JWK_SET_URI") { "https://127.0.0.1:9/jwks" }
        }
    }
}
