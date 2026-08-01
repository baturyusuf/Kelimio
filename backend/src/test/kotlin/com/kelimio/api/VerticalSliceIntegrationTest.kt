package com.kelimio.api

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.progress.LearningProgressProjectionWorker
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
import org.springframework.test.web.servlet.request.RequestPostProcessor
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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

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

    @Autowired
    private lateinit var projectionWorker: LearningProgressProjectionWorker

    @Test
    fun `authenticated user completes first login profile setup idempotently`() {
        val subject = "profile-setup-${UUID.randomUUID()}"
        val profileJwt = jwt().jwt {
            it.subject(subject)
                .claim("email", "profile@integration.invalid")
                .claim("email_verified", true)
                .claim("preferred_username", "profile-user")
                .audience(listOf("kelimio-mobile"))
        }

        mockMvc.get("/v1/me") { with(profileJwt) }
            .andExpect {
                status { isOk() }
                jsonPath("$.profileSetupStatus") { value("REQUIRED") }
                jsonPath("$.profileVersion") { value(0) }
                jsonPath("$.preferredSupportLanguage") { doesNotExist() }
                jsonPath("$.timeZone") { value("UTC") }
                jsonPath("$.subject") { doesNotExist() }
                jsonPath("$.email") { doesNotExist() }
                jsonPath("$.username") { doesNotExist() }
            }

        mockMvc.get("/v1/catalog/courses") { with(profileJwt) }
            .andExpect {
                status { isConflict() }
                jsonPath("$.type") { value("https://api.kelimio.invalid/problems/profile-setup-required") }
            }

        mockMvc.post("/v1/development/starter-course") {
            with(profileJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
        }.andExpect {
            status { isConflict() }
            jsonPath("$.type") { value("https://api.kelimio.invalid/problems/profile-setup-required") }
        }

        mockMvc.post("/v1/me/profile-setup") {
            with(profileJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
            contentType = MediaType.APPLICATION_JSON
            content = profileSetupRequest().dropLast(1) + ",\"userId\":\"${UUID.randomUUID()}\"}"
        }.andExpect { status { isBadRequest() } }

        mockMvc.post("/v1/me/profile-setup") {
            with(profileJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
            contentType = MediaType.APPLICATION_JSON
            content = profileSetupRequest(displayName = "Unsafe\u202EName")
        }.andExpect { status { isUnprocessableEntity() } }

        mockMvc.post("/v1/me/profile-setup") {
            with(profileJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
            contentType = MediaType.APPLICATION_JSON
            content = profileSetupRequest(targetLanguage = "tr", supportLanguage = "tr")
        }.andExpect { status { isUnprocessableEntity() } }

        mockMvc.post("/v1/me/profile-setup") {
            with(profileJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
            contentType = MediaType.APPLICATION_JSON
            content = profileSetupRequest(timeZone = "+03:00")
        }.andExpect { status { isUnprocessableEntity() } }

        val firstKey = UUID.randomUUID()
        val request = profileSetupRequest(displayName = "  Ｐrofile   User  ")
        repeat(2) {
            mockMvc.post("/v1/me/profile-setup") {
                with(profileJwt)
                header("Idempotency-Key", firstKey.toString())
                contentType = MediaType.APPLICATION_JSON
                content = request
            }.andExpect {
                status { isOk() }
                jsonPath("$.displayName") { value("Profile User") }
                jsonPath("$.appLocale") { value("ar") }
                jsonPath("$.activeTargetLanguage") { value("tr") }
                jsonPath("$.preferredSupportLanguage") { value("en") }
                jsonPath("$.timeZone") { value("Europe/Istanbul") }
                jsonPath("$.profileVersion") { value(1) }
                jsonPath("$.profileSetupStatus") { value("COMPLETE") }
            }
        }

        mockMvc.post("/v1/me/profile-setup") {
            with(profileJwt)
            header("Idempotency-Key", firstKey.toString())
            contentType = MediaType.APPLICATION_JSON
            content = profileSetupRequest(displayName = "Changed Name")
        }.andExpect { status { isConflict() } }

        mockMvc.post("/v1/me/profile-setup") {
            with(profileJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
            contentType = MediaType.APPLICATION_JSON
            content = request
        }.andExpect { status { isConflict() } }

        val userId = jdbcTemplate.queryForObject(
            "select id from app_user where oidc_subject = ?",
            UUID::class.java,
            subject,
        )!!
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from outbox_event where aggregate_id = ? and event_type = 'identity.profile-setup-completed.v1'",
                Int::class.java,
                userId,
            ),
        ).isEqualTo(1)
        assertThat(count("identity_profile_event", "user_id", userId)).isEqualTo(1)
        assertThat(count("course", "owner_user_id", userId)).isZero()
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from command_idempotency where user_id = ? and operation = 'identity.complete-profile-setup'",
                Int::class.java,
                userId,
            ),
        ).isEqualTo(1)
    }

    @Test
    fun `matching verified emails never link distinct oidc subjects`() {
        val sharedEmail = "shared-${UUID.randomUUID()}@integration.invalid"
        listOf("first", "second").forEach { suffix ->
            val subjectJwt = jwt().jwt {
                it.subject("$suffix-${UUID.randomUUID()}")
                    .claim("email", sharedEmail)
                    .claim("email_verified", true)
                    .audience(listOf("kelimio-mobile"))
            }
            mockMvc.get("/v1/me") { with(subjectJwt) }
                .andExpect { status { isOk() } }
        }
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from app_user where email = ?",
                Int::class.java,
                sharedEmail,
            ),
        ).isEqualTo(2)

        val unverifiedSubject = "unverified-${UUID.randomUUID()}"
        mockMvc.get("/v1/me") {
            with(
                jwt().jwt {
                    it.subject(unverifiedSubject)
                        .claim("email", sharedEmail)
                        .claim("email_verified", false)
                        .claim("name", "Unsafe\u202EName")
                        .claim("preferred_username", sharedEmail)
                        .audience(listOf("kelimio-mobile"))
                },
            )
        }.andExpect {
            status { isOk() }
            jsonPath("$.displayName") { value("Kelimio User") }
        }
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from app_user where oidc_subject = ? and email is null and username is null and display_name = 'Kelimio User'",
                Int::class.java,
                unverifiedSubject,
            ),
        ).isEqualTo(1)
    }

    @Test
    fun `concurrent profile setup commands commit exactly one profile fact`() {
        val subject = "concurrent-profile-${UUID.randomUUID()}"
        fun subjectJwt() = jwt().jwt {
            it.subject(subject)
                .claim("email", "concurrent-${UUID.randomUUID()}@integration.invalid")
                .claim("email_verified", true)
                .audience(listOf("kelimio-mobile"))
        }

        mockMvc.get("/v1/me") { with(subjectJwt()) }
            .andExpect { status { isOk() } }

        val ready = CountDownLatch(2)
        val start = CountDownLatch(1)
        val executor = Executors.newFixedThreadPool(2)
        try {
            val responses = List(2) {
                executor.submit<Int> {
                    ready.countDown()
                    check(start.await(10, TimeUnit.SECONDS))
                    mockMvc.post("/v1/me/profile-setup") {
                        with(subjectJwt())
                        header("Idempotency-Key", UUID.randomUUID().toString())
                        contentType = MediaType.APPLICATION_JSON
                        content = profileSetupRequest(displayName = "Concurrent User")
                    }.andReturn().response.status
                }
            }
            check(ready.await(10, TimeUnit.SECONDS))
            start.countDown()
            assertThat(responses.map { it.get(30, TimeUnit.SECONDS) })
                .containsExactlyInAnyOrder(200, 409)
        } finally {
            start.countDown()
            executor.shutdownNow()
        }

        val userId = jdbcTemplate.queryForObject(
            "select id from app_user where oidc_subject = ?",
            UUID::class.java,
            subject,
        )!!
        assertThat(count("identity_profile_event", "user_id", userId)).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from command_idempotency where user_id = ? and operation = 'identity.complete-profile-setup'",
                Int::class.java,
                userId,
            ),
        ).isEqualTo(1)
    }

    @Test
    fun `local starter course installs one immutable release idempotently`() {
        val ownerJwt = jwt().jwt {
            it.subject("local-starter-owner")
                .claim("email", "starter-owner@integration.invalid")
                .claim("preferred_username", "starter-owner")
                .audience(listOf("kelimio-mobile"))
        }
        completeProfileSetup(ownerJwt, displayName = "Starter Owner")
        val firstKey = UUID.randomUUID()
        val firstBody = mockMvc.post("/v1/development/starter-course") {
            with(ownerJwt)
            header("Idempotency-Key", firstKey.toString())
        }.andExpect {
            status { isCreated() }
            jsonPath("$.created") { value(true) }
            jsonPath("$.sourceWorkbookSha256") {
                value("9fb87f680505e949304257e43e09ab0ce7f71324b4a06bcfae919260ab9f889e")
            }
        }.andReturn().response.contentAsString
        val courseId = UUID.fromString(objectMapper.readTree(firstBody)["courseId"].asText())

        mockMvc.post("/v1/development/starter-course") {
            with(ownerJwt)
            header("Idempotency-Key", firstKey.toString())
        }.andExpect {
            status { isOk() }
            jsonPath("$.courseId") { value(courseId.toString()) }
            jsonPath("$.created") { value(false) }
        }

        mockMvc.post("/v1/development/starter-course") {
            with(ownerJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
        }.andExpect {
            status { isOk() }
            jsonPath("$.courseId") { value(courseId.toString()) }
            jsonPath("$.created") { value(false) }
        }

        mockMvc.get("/v1/courses/$courseId") { with(ownerJwt) }
            .andExpect {
                status { isOk() }
                jsonPath("$.name") { value("Örnek Türkçe Kelime Kursu") }
                jsonPath("$.supportLanguages[0]") { value("en") }
                jsonPath("$.tests[0].questionCount") { value(6) }
            }

        assertThat(count("course_origin", "course_id", courseId)).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from outbox_event where aggregate_id = ? and event_type = 'content.release-published.v1'",
                Int::class.java,
                courseId,
            ),
        ).isEqualTo(1)
    }

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
        completeProfileSetup(learnerJwt, displayName = "Integration Learner")

        mockMvc.get("/v1/catalog/courses")
            .andExpect { status { isUnauthorized() } }

        val catalogBody = mockMvc.get("/v1/catalog/courses") { with(learnerJwt) }
            .andExpect { status { isOk() } }
            .andReturn().response.contentAsString
        assertThat(
            objectMapper.readTree(catalogBody)["items"].map { it["id"].asText() },
        ).contains(fixture.courseId.toString())

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

        while (projectionWorker.processAvailable() > 0) {
            // Drain every currently available projection event deterministically.
        }
        mockMvc.get("/v1/courses/${fixture.courseId}/progress") { with(learnerJwt) }
            .andExpect {
                status { isOk() }
                jsonPath("$.answeredQuestions") { value(1) }
                jsonPath("$.correctAnswers") { value(1) }
                jsonPath("$.completedAttempts") { value(1) }
                jsonPath("$.passedAttempts") { value(1) }
                jsonPath("$.activeScore") { value(60) }
                jsonPath("$.lifetimeScore") { value(60) }
                jsonPath("$.updating") { value(false) }
            }

        assertThat(count("score_event", "submission_id", submissionId)).isEqualTo(1)
        assertThat(count("answer_submission", "submission_id", submissionId)).isEqualTo(1)
        assertThat(jdbcTemplate.queryForObject("select count(*) from outbox_event", Int::class.java)).isGreaterThanOrEqualTo(3)
        assertThat(
            jdbcTemplate.queryForObject("select count(*) from outbox_delivery", Int::class.java),
        ).isEqualTo(jdbcTemplate.queryForObject("select count(*) from outbox_event", Int::class.java))
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

    private fun completeProfileSetup(
        authentication: RequestPostProcessor,
        displayName: String,
    ) {
        mockMvc.post("/v1/me/profile-setup") {
            with(authentication)
            header("Idempotency-Key", UUID.randomUUID().toString())
            contentType = MediaType.APPLICATION_JSON
            content = profileSetupRequest(displayName = displayName)
        }.andExpect {
            status { isOk() }
            jsonPath("$.profileSetupStatus") { value("COMPLETE") }
        }
    }

    private fun profileSetupRequest(
        displayName: String = "  Profile   User  ",
        targetLanguage: String = "tr",
        supportLanguage: String = "en",
        timeZone: String = "Europe/Istanbul",
    ): String = """
        {
          "displayName":"$displayName",
          "appLocale":"ar",
          "activeTargetLanguage":"$targetLanguage",
          "preferredSupportLanguage":"$supportLanguage",
          "timeZone":"$timeZone"
        }
    """.trimIndent()

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
            registry.add("KELIMIO_ENVIRONMENT") { "local" }
            registry.add("KELIMIO_LOCAL_STARTER_COURSE_ENABLED") { "true" }
            registry.add("KELIMIO_PROJECTION_ENABLED") { "false" }
            registry.add("KELIMIO_OIDC_ISSUER") { "https://issuer.integration.invalid" }
            registry.add("KELIMIO_OIDC_AUDIENCE") { "kelimio-mobile" }
            registry.add("KELIMIO_OIDC_JWK_SET_URI") { "https://127.0.0.1:9/jwks" }
        }
    }
}
