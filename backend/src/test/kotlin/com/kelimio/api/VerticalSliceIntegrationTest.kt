package com.kelimio.api

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.language.TypedAnswerPolicy
import com.kelimio.api.progress.LearningProgressProjectionWorker
import com.kelimio.api.web.AnswerSubmissionBodyLimitFilter
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
                jsonPath("$.tests[0].questionCount") { value(7) }
            }

        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from question_revision where course_id = ? and question_type = 'A'",
                Int::class.java,
                courseId,
            ),
        ).isEqualTo(5)
        assertThat(
            jdbcTemplate.queryForObject(
                "select prompt from question_revision where course_id = ? and question_type = 'B'",
                String::class.java,
                courseId,
            ),
        ).isEqualTo("Ben her sabah çay ---.")
        assertThat(
            jdbcTemplate.queryForObject(
                "select origin_key from course_origin where course_id = ?",
                String::class.java,
                courseId,
            ),
        ).isEqualTo("kurs-excel-plani-v3-type-a-b-c-en-v3")
        val typedQuestion = jdbcTemplate.queryForMap(
            """
            select prompt, correct_answer, alternative_correct_answer,
                   answer_match_policy, answer_match_language,
                   correct_answer_match_key, alternative_answer_match_key
              from question_revision
             where course_id = ? and question_type = 'C'
            """.trimIndent(),
            courseId,
        )
        assertThat(typedQuestion["prompt"]).isEqualTo("Sabah kahvaltıda çay ---.")
        assertThat(typedQuestion["correct_answer"]).isEqualTo("içerim")
        assertThat(typedQuestion["alternative_correct_answer"]).isEqualTo("içiyorum")
        assertThat(typedQuestion["answer_match_policy"]).isEqualTo(TypedAnswerPolicy.VERSION)
        assertThat(typedQuestion["answer_match_language"]).isEqualTo("tr")
        assertThat(typedQuestion["correct_answer_match_key"]).isEqualTo("içerim")
        assertThat(typedQuestion["alternative_answer_match_key"]).isEqualTo("içiyorum")
        assertThat(
            jdbcTemplate.queryForObject(
                """
                select count(*)
                  from question_revision_option qro
                  join question_revision qr on qr.id = qro.question_revision_id
                 where qr.course_id = ? and qr.question_type = 'C'
                """.trimIndent(),
                Int::class.java,
                courseId,
            ),
        ).isZero()

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
            jsonPath("$.questions[0].type") { value("WORD_MULTIPLE_CHOICE") }
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

        mockMvc.get("/v1/attempts/$attemptId/answers/$submissionId") {
            with(learnerJwt)
        }.andExpect {
            status { isOk() }
            header { string("Cache-Control", "no-store") }
            jsonPath("$.correct") { value(true) }
            jsonPath("$.correctOptionId") { value(fixture.correctOptionId.toString()) }
            jsonPath("$.correctAnswerText") { doesNotExist() }
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

    @Test
    fun `multiple choice cloze remains answer key free and records a server authoritative wrong answer once`() {
        val fixture = createCourseFixture(
            questionType = "B",
            prompt = "Ben her sabah çay ---.",
            correctAnswer = "içerim",
            wrongAnswers = listOf("yerim", "koşarım", "yazarım"),
        )
        val learnerJwt = jwt().jwt {
            it.subject("cloze-learner-${fixture.courseId}")
                .claim("email", "cloze-learner@integration.invalid")
                .claim("preferred_username", "cloze-learner")
                .audience(listOf("kelimio-mobile"))
        }
        mockMvc.get("/v1/me") { with(learnerJwt) }
            .andExpect { status { isOk() } }
        completeProfileSetup(learnerJwt, displayName = "Cloze Learner")
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
            jsonPath("$.questions[0].type") { value("MULTIPLE_CHOICE_CLOZE") }
            jsonPath("$.questions[0].prompt") { value("Ben her sabah çay ---.") }
            jsonPath("$.questions[0].options.length()") { value(4) }
            jsonPath("$.questions[0].options[*].correct") { doesNotExist() }
            jsonPath("$.questions[0].correctOptionId") { doesNotExist() }
            jsonPath("$.questions[0].correctAnswer") { doesNotExist() }
        }.andReturn().response.contentAsString
        val attemptId = UUID.fromString(objectMapper.readTree(startBody)["id"].asText())

        val forgedSubmissionId = UUID.randomUUID()
        mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", forgedSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content =
                """
                {
                  "submissionId":"$forgedSubmissionId",
                  "questionRevisionId":"${fixture.questionRevisionId}",
                  "selectedOptionId":"${fixture.wrongOptionId}",
                  "correct":true
                }
                """.trimIndent()
        }.andExpect { status { isBadRequest() } }
        assertThat(count("answer_submission", "submission_id", forgedSubmissionId)).isZero()

        val submissionId = UUID.randomUUID()
        val answerJson =
            """
            {
              "submissionId":"$submissionId",
              "questionRevisionId":"${fixture.questionRevisionId}",
              "selectedOptionId":"${fixture.wrongOptionId}"
            }
            """.trimIndent()
        repeat(2) {
            mockMvc.post("/v1/attempts/$attemptId/answers") {
                with(learnerJwt)
                header("Idempotency-Key", submissionId.toString())
                contentType = MediaType.APPLICATION_JSON
                content = answerJson
            }.andExpect {
                status { isOk() }
                jsonPath("$.correct") { value(false) }
                jsonPath("$.correctOptionId") { value(fixture.correctOptionId.toString()) }
                jsonPath("$.activeScoreDelta") { value(0) }
                jsonPath("$.lifetimeScoreDelta") { value(0) }
                jsonPath("$.activeQuestionScore") { value(0) }
                jsonPath("$.lifetimeScore") { value(0) }
                jsonPath("$.energy.balance") { value(4) }
                jsonPath("$.attemptState") { value("IN_PROGRESS") }
            }
        }

        mockMvc.post("/v1/attempts/$attemptId/finish") {
            with(learnerJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
        }.andExpect {
            status { isOk() }
            jsonPath("$.state") { value("COMPLETED_FAIL") }
            jsonPath("$.correctCount") { value(0) }
            jsonPath("$.questionCount") { value(1) }
            jsonPath("$.correctRatio") { value(0.0) }
        }

        assertThat(count("answer_submission", "submission_id", submissionId)).isEqualTo(1)
        assertThat(count("score_event", "submission_id", submissionId)).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from energy_event where submission_id = ? and event_type = 'WRONG_ANSWER_DEBIT'",
                Int::class.java,
                submissionId,
            ),
        ).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from attempt_event where submission_id = ? and event_type = 'ANSWER_RECORDED'",
                Int::class.java,
                submissionId,
            ),
        ).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from outbox_event where aggregate_id = ? and event_type = 'learning.answer-recorded.v1'",
                Int::class.java,
                attemptId,
            ),
        ).isEqualTo(1)
    }

    @Test
    fun `typed cloze remains answer key free and reconciles private server authoritative evidence`() {
        val fixture = createCourseFixture(
            questionType = "C",
            prompt = "Sabah kahvaltıda çay ---. ",
            correctAnswer = "içerim",
            alternativeCorrectAnswer = "içiyorum",
        )
        val learnerJwt = jwt().jwt {
            it.subject("typed-cloze-learner-${fixture.courseId}")
                .claim("email", "typed-cloze-learner@integration.invalid")
                .claim("preferred_username", "typed-cloze-learner")
                .audience(listOf("kelimio-mobile"))
        }
        mockMvc.get("/v1/me") { with(learnerJwt) }
            .andExpect { status { isOk() } }
        completeProfileSetup(learnerJwt, displayName = "Typed Cloze Learner")
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
            jsonPath("$.questions[0].type") { value("TYPED_CLOZE") }
            jsonPath("$.questions[0].prompt") { value("Sabah kahvaltıda çay ---. ") }
            jsonPath("$.questions[0].options.length()") { value(0) }
            jsonPath("$.questions[0].correctOptionId") { doesNotExist() }
            jsonPath("$.questions[0].correctAnswer") { doesNotExist() }
            jsonPath("$.questions[0].correctAnswerText") { doesNotExist() }
            jsonPath("$.questions[0].answerMatchPolicy") { doesNotExist() }
            jsonPath("$.questions[0].answerMatchLanguage") { doesNotExist() }
        }.andReturn().response.contentAsString
        val attemptId = UUID.fromString(objectMapper.readTree(startBody)["id"].asText())

        val oversizedSubmissionId = UUID.randomUUID()
        val oversizedRequestId = UUID.randomUUID()
        val oversizedSensitivePrefix = "private-oversized-${UUID.randomUUID()}"
        val oversizedBody = objectMapper.writeValueAsString(
            mapOf(
                "submissionId" to oversizedSubmissionId,
                "questionRevisionId" to fixture.questionRevisionId,
                "typedAnswer" to oversizedSensitivePrefix +
                    "x".repeat(AnswerSubmissionBodyLimitFilter.MAX_BODY_BYTES),
            ),
        )
        val oversizedResponse = mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("X-Request-Id", oversizedRequestId.toString())
            header("Idempotency-Key", oversizedSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = oversizedBody
        }.andExpect {
            status { isPayloadTooLarge() }
            header { string("Cache-Control", "no-store") }
            header { string("X-Request-Id", oversizedRequestId.toString()) }
            jsonPath("$.type") { value("https://api.kelimio.invalid/problems/payload-too-large") }
            jsonPath("$.detail") { value("The request body is too large.") }
            jsonPath("$.requestId") { value(oversizedRequestId.toString()) }
        }.andReturn().response.contentAsString
        assertThat(oversizedResponse).doesNotContain(oversizedSensitivePrefix)
        assertThat(count("answer_submission", "submission_id", oversizedSubmissionId)).isZero()
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from command_idempotency where idempotency_key = ?",
                Int::class.java,
                oversizedSubmissionId,
            ),
        ).isZero()

        val matrixSubmissionId = UUID.randomUUID()
        val matrixRequestId = UUID.randomUUID()
        val matrixSensitivePrefix = "private-matrix-${UUID.randomUUID()}"
        val matrixBody = objectMapper.writeValueAsString(
            mapOf(
                "submissionId" to matrixSubmissionId,
                "questionRevisionId" to fixture.questionRevisionId,
                "typedAnswer" to matrixSensitivePrefix +
                    "x".repeat(AnswerSubmissionBodyLimitFilter.MAX_BODY_BYTES),
            ),
        )
        val matrixResponse = mockMvc.post(
            "/v1/attempts;scope=local/$attemptId;probe=one/answers;probe=two",
        ) {
            with(learnerJwt)
            header("X-Request-Id", matrixRequestId.toString())
            header("Idempotency-Key", matrixSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = matrixBody
        }.andExpect {
            status { isPayloadTooLarge() }
            header { string("Cache-Control", "no-store") }
            header { string("X-Request-Id", matrixRequestId.toString()) }
            jsonPath("$.type") { value("https://api.kelimio.invalid/problems/payload-too-large") }
            jsonPath("$.detail") { value("The request body is too large.") }
            jsonPath("$.requestId") { value(matrixRequestId.toString()) }
        }.andReturn().response.contentAsString
        assertThat(matrixResponse).doesNotContain(matrixSensitivePrefix)
        assertThat(count("answer_submission", "submission_id", matrixSubmissionId)).isZero()
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from command_idempotency where idempotency_key = ?",
                Int::class.java,
                matrixSubmissionId,
            ),
        ).isZero()

        val rejectedSubmissionId = UUID.randomUUID()
        mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", rejectedSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content =
                """
                {
                  "submissionId":"$rejectedSubmissionId",
                  "questionRevisionId":"${fixture.questionRevisionId}",
                  "selectedOptionId":"${fixture.correctOptionId}",
                  "typedAnswer":"içerim"
                }
                """.trimIndent()
        }.andExpect { status { isBadRequest() } }
        assertThat(count("answer_submission", "submission_id", rejectedSubmissionId)).isZero()

        mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", rejectedSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content =
                """
                {
                  "submissionId":"$rejectedSubmissionId",
                  "questionRevisionId":"${fixture.questionRevisionId}",
                  "selectedOptionId":"${fixture.correctOptionId}"
                }
                """.trimIndent()
        }.andExpect { status { isUnprocessableEntity() } }
        assertThat(count("answer_submission", "submission_id", rejectedSubmissionId)).isZero()

        val sensitiveInvalidAnswer = "private-${UUID.randomUUID()}\u202E"
        val invalidBody = mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", rejectedSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content =
                objectMapper.writeValueAsString(
                    mapOf(
                        "submissionId" to rejectedSubmissionId,
                        "questionRevisionId" to fixture.questionRevisionId,
                        "typedAnswer" to sensitiveInvalidAnswer,
                    ),
                )
        }.andExpect {
            status { isUnprocessableEntity() }
            jsonPath("$.detail") { value("The typed answer is invalid.") }
        }.andReturn().response.contentAsString
        assertThat(invalidBody).doesNotContain(sensitiveInvalidAnswer)
        assertThat(count("answer_submission", "submission_id", rejectedSubmissionId)).isZero()

        val submissionId = UUID.randomUUID()
        val sensitiveRawAnswer = "  İÇİYORUM\u00A0 "
        val answerJson = objectMapper.writeValueAsString(
            mapOf(
                "submissionId" to submissionId,
                "questionRevisionId" to fixture.questionRevisionId,
                "typedAnswer" to sensitiveRawAnswer,
            ),
        )
        repeat(2) {
            mockMvc.post("/v1/attempts/$attemptId/answers") {
                with(learnerJwt)
                header("Idempotency-Key", submissionId.toString())
                contentType = MediaType.APPLICATION_JSON
                content = answerJson
            }.andExpect {
                status { isOk() }
                header { string("Cache-Control", "no-store") }
                jsonPath("$.correct") { value(true) }
                jsonPath("$.correctOptionId") { doesNotExist() }
                jsonPath("$.correctAnswerText") { value("içerim") }
                jsonPath("$.activeScoreDelta") { value(60) }
                jsonPath("$.lifetimeScoreDelta") { value(60) }
                jsonPath("$.energy.balance") { value(5) }
            }
        }

        val differentAnswerBody = objectMapper.writeValueAsString(
            mapOf(
                "submissionId" to submissionId,
                "questionRevisionId" to fixture.questionRevisionId,
                "typedAnswer" to "başka",
            ),
        )
        mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", submissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = differentAnswerBody
        }.andExpect { status { isConflict() } }

        mockMvc.get("/v1/attempts/$attemptId/answers/$submissionId") {
            with(learnerJwt)
        }.andExpect {
            status { isOk() }
            header { string("Cache-Control", "no-store") }
            jsonPath("$.submissionId") { value(submissionId.toString()) }
            jsonPath("$.correct") { value(true) }
            jsonPath("$.correctOptionId") { doesNotExist() }
            jsonPath("$.correctAnswerText") { value("içerim") }
        }

        val otherJwt = jwt().jwt {
            it.subject("typed-cloze-other-${fixture.courseId}")
                .claim("email", "typed-cloze-other@integration.invalid")
                .audience(listOf("kelimio-mobile"))
        }
        mockMvc.get("/v1/me") { with(otherJwt) }.andExpect { status { isOk() } }
        completeProfileSetup(otherJwt, displayName = "Other Learner")
        mockMvc.get("/v1/attempts/$attemptId/answers/$submissionId") {
            with(otherJwt)
        }.andExpect { status { isNotFound() } }
        mockMvc.get("/v1/attempts/$attemptId/answers/${UUID.randomUUID()}") {
            with(learnerJwt)
        }.andExpect { status { isNotFound() } }

        val evidence = jdbcTemplate.queryForMap(
            """
            select answer_kind, selected_option_id, typed_answer_salt,
                   typed_answer_digest, typed_match_ordinal
              from answer_submission
             where submission_id = ?
            """.trimIndent(),
            submissionId,
        )
        assertThat(evidence["answer_kind"]).isEqualTo("TYPED_TEXT")
        assertThat(evidence["selected_option_id"]).isNull()
        assertThat(evidence["typed_answer_salt"] as ByteArray).hasSize(16)
        assertThat(evidence["typed_answer_digest"] as ByteArray).hasSize(32)
        assertThat((evidence["typed_match_ordinal"] as Number).toInt()).isEqualTo(2)
        assertThat(count("answer_submission", "submission_id", submissionId)).isEqualTo(1)
        assertThat(count("score_event", "submission_id", submissionId)).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from energy_event where submission_id = ?",
                Int::class.java,
                submissionId,
            ),
        ).isZero()

        val storedEventText = jdbcTemplate.queryForObject(
            """
            select coalesce(string_agg(payload::text, ' '), '')
              from (
                    select payload from attempt_event where submission_id = ?
                    union all
                    select payload from outbox_event where aggregate_id = ?
              ) private_payloads
            """.trimIndent(),
            String::class.java,
            submissionId,
            attemptId,
        )!!
        assertThat(storedEventText)
            .doesNotContain(sensitiveRawAnswer)
            .doesNotContain("içiyorum")
            .doesNotContain("içerim")
        assertThat(
            jdbcTemplate.queryForObject(
                """
                select count(*)
                  from command_idempotency
                 where operation = 'learning.submit-answer'
                   and resource_id = ?
                   and request_fingerprint ~ '^[0-9a-f]{64}$'
                """.trimIndent(),
                Int::class.java,
                submissionId,
            ),
        ).isEqualTo(1)
    }

    private fun createCourseFixture(
        questionType: String = "A",
        prompt: String = "Pencere",
        correctAnswer: String = "Window",
        wrongAnswers: List<String> = listOf("Door", "Table", "Chair"),
        alternativeCorrectAnswer: String? = null,
    ): Fixture {
        require(questionType == "C" || wrongAnswers.size == 3)
        val fixture = Fixture(
            courseId = UUID.randomUUID(),
            testId = UUID.randomUUID(),
            questionRevisionId = UUID.randomUUID(),
            correctOptionId = UUID.randomUUID(),
            wrongOptionId = UUID.randomUUID(),
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
            val answerPolicy = questionType.takeIf { it == "C" }?.let { TypedAnswerPolicy.VERSION }
            val answerLanguage = questionType.takeIf { it == "C" }?.let { "tr" }
            val primaryMatchKey = answerLanguage?.let {
                TypedAnswerPolicy.canonicalize(correctAnswer, it, checkNotNull(answerPolicy))
            }
            val alternativeMatchKey = answerLanguage?.let { language ->
                alternativeCorrectAnswer?.let {
                    TypedAnswerPolicy.canonicalize(it, language, checkNotNull(answerPolicy))
                }
            }
            jdbcTemplate.update(
                """
                insert into question_revision(
                    id, question_id, course_id, revision_number, question_type,
                    prompt, correct_answer, alternative_correct_answer,
                    answer_match_policy, answer_match_language,
                    correct_answer_match_key, alternative_answer_match_key,
                    status, created_at
                ) values (?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, 'DRAFT', ?)
                """.trimIndent(),
                fixture.questionRevisionId,
                questionId,
                fixture.courseId,
                questionType,
                prompt,
                correctAnswer,
                alternativeCorrectAnswer,
                answerPolicy,
                answerLanguage,
                primaryMatchKey,
                alternativeMatchKey,
                now,
            )
            val options = if (questionType == "C") {
                emptyList()
            } else {
                listOf(
                    fixture.correctOptionId to correctAnswer,
                    fixture.wrongOptionId to wrongAnswers[0],
                    UUID.randomUUID() to wrongAnswers[1],
                    UUID.randomUUID() to wrongAnswers[2],
                )
            }
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
        val wrongOptionId: UUID,
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
