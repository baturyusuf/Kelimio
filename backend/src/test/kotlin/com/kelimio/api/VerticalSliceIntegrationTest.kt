package com.kelimio.api

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.language.TypedAnswerPolicy
import com.kelimio.api.language.MatchingLabelPolicy
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
import java.util.Base64
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
                jsonPath("$.tests[0].questionCount") { value(8) }
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
        ).isEqualTo("kurs-excel-plani-v3-type-a-b-c-d-en-v4")
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

        val matchingQuestion = jdbcTemplate.queryForMap(
            """
            select prompt, correct_answer, matching_policy, matching_label_policy,
                   matching_order_policy, matching_target_language
              from question_revision
             where course_id = ? and question_type = 'D'
            """.trimIndent(),
            courseId,
        )
        assertThat(matchingQuestion["prompt"]).isNull()
        assertThat(matchingQuestion["correct_answer"]).isNull()
        assertThat(matchingQuestion["matching_policy"]).isEqualTo("matching-v1")
        assertThat(matchingQuestion["matching_label_policy"]).isEqualTo("matching-label-v1")
        assertThat(matchingQuestion["matching_order_policy"]).isEqualTo("matching-order-v1")
        assertThat(matchingQuestion["matching_target_language"]).isEqualTo("tr")
        val starterPairs = jdbcTemplate.queryForList(
            """
            select pair.target_item_id, pair.target_text,
                   translation.support_item_id, translation.support_text
              from question_revision_matching_pair pair
              join question_revision_matching_translation translation
                on translation.question_revision_id = pair.question_revision_id
               and translation.target_item_id = pair.target_item_id
               and translation.course_id = pair.course_id
             where pair.course_id = ? and translation.support_language = 'en'
             order by pair.position
            """.trimIndent(),
            courseId,
        )
        assertThat(starterPairs.map { it["target_text"] to it["support_text"] }).containsExactly(
            "Pencere" to "Window",
            "Kapı" to "Door",
            "Masa" to "Table",
            "Sandalye" to "Chair",
        )
        val targetItemIds = starterPairs.map { it["target_item_id"] as UUID }
        val supportItemIds = starterPairs.map { it["support_item_id"] as UUID }
        assertThat(targetItemIds + supportItemIds).allSatisfy { assertThat(it.version()).isEqualTo(4) }
        assertThat(targetItemIds.toSet().intersect(supportItemIds.toSet())).isEmpty()

        val secondOwnerJwt = jwt().jwt {
            it.subject("local-starter-second-owner")
                .claim("email", "starter-second-owner@integration.invalid")
                .claim("preferred_username", "starter-second-owner")
                .audience(listOf("kelimio-mobile"))
        }
        completeProfileSetup(secondOwnerJwt, displayName = "Second Starter Owner")
        val secondBody = mockMvc.post("/v1/development/starter-course") {
            with(secondOwnerJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
        }.andExpect {
            status { isCreated() }
            jsonPath("$.created") { value(true) }
        }.andReturn().response.contentAsString
        val secondCourseId = UUID.fromString(objectMapper.readTree(secondBody)["courseId"].asText())
        assertThat(secondCourseId).isNotEqualTo(courseId)
        assertThat(
            jdbcTemplate.queryForObject(
                """
                select count(*)
                  from question_revision_matching_pair first_pair
                  join question_revision_matching_pair second_pair
                    on second_pair.target_item_id = first_pair.target_item_id
                 where first_pair.course_id = ? and second_pair.course_id = ?
                """.trimIndent(),
                Int::class.java,
                courseId,
                secondCourseId,
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

    @Test
    fun `matching is answer key free complete server authoritative and replay safe`() {
        val fixture = createCourseFixture(
            questionType = "D",
            prompt = null,
            correctAnswer = null,
        )
        val learnerJwt = jwt().jwt {
            it.subject("matching-learner-${fixture.courseId}")
                .claim("email", "matching-learner@integration.invalid")
                .claim("preferred_username", "matching-learner")
                .audience(listOf("kelimio-mobile"))
        }
        mockMvc.get("/v1/me") { with(learnerJwt) }.andExpect { status { isOk() } }
        completeProfileSetup(learnerJwt, displayName = "Matching Learner")
        mockMvc.post("/v1/courses/${fixture.courseId}/enrollments") {
            with(learnerJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
            contentType = MediaType.APPLICATION_JSON
            content = """{"supportLanguage":"en"}"""
        }.andExpect { status { isCreated() } }

        val startKey = UUID.randomUUID()
        fun startAttempt(): String = mockMvc.post("/v1/tests/${fixture.testId}/attempts") {
            with(learnerJwt)
            header("Idempotency-Key", startKey.toString())
        }.andExpect {
            status { isCreated() }
            jsonPath("$.supportLanguage") { value("en") }
            jsonPath("$.questions[0].type") { value("MATCHING") }
            jsonPath("$.questions[0].options.length()") { value(0) }
            jsonPath("$.questions[0].targetItems.length()") { value(4) }
            jsonPath("$.questions[0].supportItems.length()") { value(4) }
            jsonPath("$.questions[0].matchingPolicy") { doesNotExist() }
            jsonPath("$.questions[0].correctMatches") { doesNotExist() }
        }.andReturn().response.contentAsString

        val firstStartBody = startAttempt()
        val replayedStartBody = startAttempt()
        val firstStart = objectMapper.readTree(firstStartBody)
        val replayedStart = objectMapper.readTree(replayedStartBody)
        val attemptId = UUID.fromString(firstStart["id"].asText())
        val question = firstStart["questions"].single()
        assertThat(question.has("prompt")).isTrue()
        assertThat(question["prompt"].isNull).isTrue()
        assertThat(question["targetItems"]).isEqualTo(replayedStart["questions"].single()["targetItems"])
        assertThat(question["supportItems"]).isEqualTo(replayedStart["questions"].single()["supportItems"])
        assertThat(replayedStart["id"].asText()).isEqualTo(attemptId.toString())
        assertThat(question["targetItems"].map { it["text"].asText() }).containsExactlyInAnyOrder(
            "Pencere",
            "Kapı",
            "Masa",
            "Sandalye",
        )
        assertThat(question["supportItems"].map { it["text"].asText() }).containsExactlyInAnyOrder(
            "Window",
            "Door",
            "Table",
            "Chair",
        )
        val issuedTargetIds = question["targetItems"].map { UUID.fromString(it["id"].asText()) }.toSet()
        val issuedSupportIds = question["supportItems"].map { UUID.fromString(it["id"].asText()) }.toSet()
        assertThat(issuedTargetIds.intersect(issuedSupportIds)).isEmpty()
        assertThat(
            jdbcTemplate.queryForObject(
                "select support_language from test_attempt where id = ?",
                String::class.java,
                attemptId,
            ),
        ).isEqualTo("en")
        assertThat(
            jdbcTemplate.update(
                "update enrollment set support_language = 'de' where course_id = ? and status = 'ACTIVE'",
                fixture.courseId,
            ),
        ).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select support_language from test_attempt where id = ?",
                String::class.java,
                attemptId,
            ),
        ).isEqualTo("en")
        val replayAfterEnrollmentChange = objectMapper.readTree(startAttempt())
        assertThat(replayAfterEnrollmentChange["supportLanguage"].asText()).isEqualTo("en")
        assertThat(replayAfterEnrollmentChange["questions"].single()["targetItems"])
            .isEqualTo(question["targetItems"])
        assertThat(replayAfterEnrollmentChange["questions"].single()["supportItems"])
            .isEqualTo(question["supportItems"])

        val nullElementSubmissionId = UUID.randomUUID()
        val nullElementSensitiveId = UUID.randomUUID()
        val nullElementResponse = mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", nullElementSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content =
                """
                {
                  "submissionId":"$nullElementSubmissionId",
                  "questionRevisionId":"${fixture.questionRevisionId}",
                  "matches":[null,{"targetItemId":"$nullElementSensitiveId","supportItemId":"${UUID.randomUUID()}"}]
                }
                """.trimIndent()
        }.andExpect {
            status { isUnprocessableEntity() }
            header { string("Cache-Control", "no-store") }
            jsonPath("$.detail") { value("The matching answer must be a complete bijection.") }
        }.andReturn().response.contentAsString
        assertThat(nullElementResponse).doesNotContain(nullElementSensitiveId.toString())

        val missingFieldSubmissionId = UUID.randomUUID()
        val missingFieldSensitiveId = UUID.randomUUID()
        val missingFieldResponse = mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", missingFieldSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content =
                """
                {
                  "submissionId":"$missingFieldSubmissionId",
                  "questionRevisionId":"${fixture.questionRevisionId}",
                  "matches":[
                    {"targetItemId":"$missingFieldSensitiveId"},
                    {"targetItemId":"${UUID.randomUUID()}","supportItemId":"${UUID.randomUUID()}"}
                  ]
                }
                """.trimIndent()
        }.andExpect { status { isBadRequest() } }
            .andReturn().response.contentAsString
        assertThat(missingFieldResponse).doesNotContain(missingFieldSensitiveId.toString())

        val duplicateSubmissionId = UUID.randomUUID()
        val duplicateTargetId = issuedTargetIds.first()
        val issuedSupports = issuedSupportIds.toList()
        mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", duplicateSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = objectMapper.writeValueAsString(
                mapOf(
                    "submissionId" to duplicateSubmissionId,
                    "questionRevisionId" to fixture.questionRevisionId,
                    "matches" to listOf(
                        mapOf("targetItemId" to duplicateTargetId, "supportItemId" to issuedSupports[0]),
                        mapOf("targetItemId" to duplicateTargetId, "supportItemId" to issuedSupports[1]),
                    ),
                ),
            )
        }.andExpect { status { isUnprocessableEntity() } }

        val foreignSubmissionId = UUID.randomUUID()
        val issuedTargets = issuedTargetIds.toList()
        mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", foreignSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = objectMapper.writeValueAsString(
                mapOf(
                    "submissionId" to foreignSubmissionId,
                    "questionRevisionId" to fixture.questionRevisionId,
                    "matches" to issuedTargets.mapIndexed { index, targetId ->
                        mapOf(
                            "targetItemId" to targetId,
                            "supportItemId" to if (index == 0) UUID.randomUUID() else issuedSupports[index],
                        )
                    },
                ),
            )
        }.andExpect { status { isUnprocessableEntity() } }
        assertThat(count("answer_submission", "attempt_id", attemptId)).isZero()
        assertThat(count("energy_event", "attempt_id", attemptId)).isZero()

        val targetIdByText = question["targetItems"].associate { it["text"].asText() to it["id"].asText() }
        val supportIdByText = question["supportItems"].associate { it["text"].asText() to it["id"].asText() }
        val correctMatches = fixture.matchingPairs.map { pair ->
            mapOf(
                "targetItemId" to targetIdByText.getValue(pair.targetText),
                "supportItemId" to supportIdByText.getValue(pair.supportText),
            )
        }
        val submissionId = UUID.randomUUID()
        fun matchingBody(matches: List<Map<String, String>>) = objectMapper.writeValueAsString(
            mapOf(
                "submissionId" to submissionId,
                "questionRevisionId" to fixture.questionRevisionId,
                "matches" to matches,
            ),
        )
        val firstAnswerBody = mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", submissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = matchingBody(correctMatches.reversed())
        }.andExpect {
            status { isOk() }
            header { string("Cache-Control", "no-store") }
            jsonPath("$.correct") { value(true) }
            jsonPath("$.correctOptionId") { doesNotExist() }
            jsonPath("$.correctAnswerText") { doesNotExist() }
            jsonPath("$.correctMatches.length()") { value(4) }
            jsonPath("$.activeScoreDelta") { value(60) }
            jsonPath("$.lifetimeScoreDelta") { value(60) }
            jsonPath("$.energy.balance") { value(5) }
        }.andReturn().response.contentAsString
        val authoritativeMatches = objectMapper.readTree(firstAnswerBody)["correctMatches"].map {
            it["targetItemId"].asText() to it["supportItemId"].asText()
        }.toSet()
        assertThat(authoritativeMatches).isEqualTo(
            correctMatches.map { it.getValue("targetItemId") to it.getValue("supportItemId") }.toSet(),
        )

        mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", submissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = matchingBody(correctMatches)
        }.andExpect {
            status { isOk() }
            jsonPath("$.correct") { value(true) }
        }

        val changedMatches = correctMatches.toMutableList().also { matches ->
            val firstSupport = matches[0].getValue("supportItemId")
            val secondSupport = matches[1].getValue("supportItemId")
            matches[0] = matches[0] + ("supportItemId" to secondSupport)
            matches[1] = matches[1] + ("supportItemId" to firstSupport)
        }
        mockMvc.post("/v1/attempts/$attemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", submissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = matchingBody(changedMatches)
        }.andExpect { status { isConflict() } }

        mockMvc.get("/v1/attempts/$attemptId/answers/$submissionId") {
            with(learnerJwt)
        }.andExpect {
            status { isOk() }
            header { string("Cache-Control", "no-store") }
            jsonPath("$.correct") { value(true) }
            jsonPath("$.correctMatches.length()") { value(4) }
        }

        val evidence = jdbcTemplate.queryForMap(
            """
            select answer_kind, selected_option_id,
                   typed_answer_salt, typed_answer_digest, typed_match_ordinal,
                   matching_answer_salt, matching_answer_digest, matching_replay_key_version
              from answer_submission
             where submission_id = ?
            """.trimIndent(),
            submissionId,
        )
        assertThat(evidence["answer_kind"]).isEqualTo("MATCHING")
        assertThat(evidence["selected_option_id"]).isNull()
        assertThat(evidence["typed_answer_salt"]).isNull()
        assertThat(evidence["typed_answer_digest"]).isNull()
        assertThat(evidence["typed_match_ordinal"]).isNull()
        val matchingSalt = evidence["matching_answer_salt"] as ByteArray
        val matchingDigest = evidence["matching_answer_digest"] as ByteArray
        assertThat(matchingSalt).hasSize(16)
        assertThat(matchingDigest).hasSize(32)
        assertThat(evidence["matching_replay_key_version"]).isEqualTo("integration-v1")
        assertThat(
            jdbcTemplate.queryForObject(
                """
                select count(*)
                  from information_schema.columns
                 where table_schema = current_schema()
                   and table_name = 'answer_submission'
                   and column_name = 'matching_correct_pair_count'
                """.trimIndent(),
                Int::class.java,
            ),
        ).isZero()
        assertThat(count("answer_submission", "submission_id", submissionId)).isEqualTo(1)
        assertThat(count("score_event", "submission_id", submissionId)).isEqualTo(1)
        assertThat(count("energy_event", "submission_id", submissionId)).isZero()
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from outbox_event where aggregate_id = ? and event_type = 'learning.answer-recorded.v1'",
                Int::class.java,
                attemptId,
            ),
        ).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select answered_count from test_attempt where id = ?",
                Int::class.java,
                attemptId,
            ),
        ).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from attempt_event where submission_id = ? and event_type = 'ANSWER_RECORDED'",
                Int::class.java,
                submissionId,
            ),
        ).isEqualTo(1)
        val eventText = jdbcTemplate.queryForObject(
            """
            select coalesce(string_agg(payload::text, ' '), '')
              from (
                    select payload from attempt_event where submission_id = ?
                    union all
                    select payload from outbox_event where aggregate_id = ?
              ) answer_events
            """.trimIndent(),
            String::class.java,
            submissionId,
            attemptId,
        )!!
        fixture.matchingPairs.forEach { pair ->
            assertThat(eventText)
                .doesNotContain(pair.targetItemId.toString())
                .doesNotContain(pair.supportItemId.toString())
                .doesNotContain(pair.targetText)
                .doesNotContain(pair.supportText)
        }
        assertThat(eventText)
            .doesNotContain("integration-v1")
            .doesNotContain(Base64.getEncoder().encodeToString(matchingSalt))
            .doesNotContain(Base64.getEncoder().encodeToString(matchingDigest))

        assertThat(
            jdbcTemplate.update(
                "update enrollment set support_language = 'en' where course_id = ? and status = 'ACTIVE'",
                fixture.courseId,
            ),
        ).isEqualTo(1)

        val wrongStartBody = mockMvc.post("/v1/tests/${fixture.testId}/attempts") {
            with(learnerJwt)
            header("Idempotency-Key", UUID.randomUUID().toString())
        }.andExpect { status { isCreated() } }
            .andReturn().response.contentAsString
        val wrongStart = objectMapper.readTree(wrongStartBody)
        val wrongAttemptId = UUID.fromString(wrongStart["id"].asText())
        val wrongQuestion = wrongStart["questions"].single()
        val wrongTargetIdByText = wrongQuestion["targetItems"].associate {
            it["text"].asText() to it["id"].asText()
        }
        val wrongSupportIdByText = wrongQuestion["supportItems"].associate {
            it["text"].asText() to it["id"].asText()
        }
        val wrongMatches = fixture.matchingPairs.mapIndexed { index, pair ->
            val rotatedSupport = fixture.matchingPairs[(index + 1) % fixture.matchingPairs.size]
            mapOf(
                "targetItemId" to wrongTargetIdByText.getValue(pair.targetText),
                "supportItemId" to wrongSupportIdByText.getValue(rotatedSupport.supportText),
            )
        }
        val wrongSubmissionId = UUID.randomUUID()
        mockMvc.post("/v1/attempts/$wrongAttemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", wrongSubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = objectMapper.writeValueAsString(
                mapOf(
                    "submissionId" to wrongSubmissionId,
                    "questionRevisionId" to fixture.questionRevisionId,
                    "matches" to wrongMatches,
                ),
            )
        }.andExpect {
            status { isOk() }
            header { string("Cache-Control", "no-store") }
            jsonPath("$.correct") { value(false) }
            jsonPath("$.correctMatches.length()") { value(4) }
            jsonPath("$.activeScoreDelta") { value(0) }
            jsonPath("$.lifetimeScoreDelta") { value(0) }
            jsonPath("$.energy.balance") { value(4) }
        }
        val wrongEvidence = jdbcTemplate.queryForMap(
            """
            select is_correct, matching_replay_key_version,
                   octet_length(matching_answer_salt) as salt_length,
                   octet_length(matching_answer_digest) as digest_length
              from answer_submission
             where submission_id = ?
            """.trimIndent(),
            wrongSubmissionId,
        )
        assertThat(wrongEvidence["is_correct"]).isEqualTo(false)
        assertThat(wrongEvidence["matching_replay_key_version"]).isEqualTo("integration-v1")
        assertThat((wrongEvidence["salt_length"] as Number).toInt()).isEqualTo(16)
        assertThat((wrongEvidence["digest_length"] as Number).toInt()).isEqualTo(32)
        assertThat(count("answer_submission", "submission_id", wrongSubmissionId)).isEqualTo(1)
        assertThat(count("score_event", "submission_id", wrongSubmissionId)).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from energy_event where submission_id = ? and event_type = 'WRONG_ANSWER_DEBIT'",
                Int::class.java,
                wrongSubmissionId,
            ),
        ).isEqualTo(1)
        assertThat(
            jdbcTemplate.queryForObject(
                "select count(*) from outbox_event where aggregate_id = ? and event_type = 'learning.answer-recorded.v1'",
                Int::class.java,
                wrongAttemptId,
            ),
        ).isEqualTo(1)

        val missingKeyStart = objectMapper.readTree(
            mockMvc.post("/v1/tests/${fixture.testId}/attempts") {
                with(learnerJwt)
                header("Idempotency-Key", UUID.randomUUID().toString())
            }.andExpect { status { isCreated() } }
                .andReturn().response.contentAsString,
        )
        val missingKeyAttemptId = UUID.fromString(missingKeyStart["id"].asText())
        val missingKeyQuestion = missingKeyStart["questions"].single()
        val missingKeyTargets = missingKeyQuestion["targetItems"].associate {
            it["text"].asText() to it["id"].asText()
        }
        val missingKeySupports = missingKeyQuestion["supportItems"].associate {
            it["text"].asText() to it["id"].asText()
        }
        val missingKeyMatches = fixture.matchingPairs.map { pair ->
            mapOf(
                "targetItemId" to missingKeyTargets.getValue(pair.targetText),
                "supportItemId" to missingKeySupports.getValue(pair.supportText),
            )
        }
        val missingKeySubmissionId = UUID.randomUUID()
        transactionTemplate.executeWithoutResult {
            jdbcTemplate.update(
                """
                insert into answer_submission(
                    submission_id, attempt_id, user_id, question_revision_id,
                    selected_option_id, answer_kind, typed_answer_salt,
                    typed_answer_digest, typed_match_ordinal, matching_answer_salt,
                    matching_answer_digest, matching_replay_key_version, is_correct,
                    active_score_delta, lifetime_score_delta, active_question_score,
                    lifetime_score, energy_balance_after, energy_unlimited,
                    energy_next_regeneration_at, attempt_status_after, submitted_at
                ) values (?, ?, (select user_id from test_attempt where id = ?), ?,
                    null, 'MATCHING', null, null, null, decode(repeat('11', 16), 'hex'),
                    decode(repeat('22', 32), 'hex'), 'retired-v1', true,
                    0, 0, 60, 60, 4, false, null, 'IN_PROGRESS', now())
                """.trimIndent(),
                missingKeySubmissionId,
                missingKeyAttemptId,
                missingKeyAttemptId,
                fixture.questionRevisionId,
            )
            jdbcTemplate.update(
                """
                update test_attempt
                   set answered_count = 1, correct_count = 1, version = 1
                 where id = ?
                """.trimIndent(),
                missingKeyAttemptId,
            )
        }
        val missingKeyResponse = mockMvc.post("/v1/attempts/$missingKeyAttemptId/answers") {
            with(learnerJwt)
            header("Idempotency-Key", missingKeySubmissionId.toString())
            contentType = MediaType.APPLICATION_JSON
            content = objectMapper.writeValueAsString(
                mapOf(
                    "submissionId" to missingKeySubmissionId,
                    "questionRevisionId" to fixture.questionRevisionId,
                    "matches" to missingKeyMatches,
                ),
            )
        }.andExpect {
            status { isInternalServerError() }
            header { string("Cache-Control", "no-store") }
            jsonPath("$.type") { value("https://api.kelimio.invalid/problems/internal-error") }
            jsonPath("$.detail") { value("An unexpected error occurred.") }
        }.andReturn().response.contentAsString
        assertThat(missingKeyResponse)
            .doesNotContain("retired-v1")
            .doesNotContain("matching_replay_key_version")
            .doesNotContain("11111111111111111111111111111111")
            .doesNotContain("2222222222222222222222222222222222222222222222222222222222222222")
        assertThat(count("answer_submission", "submission_id", missingKeySubmissionId)).isEqualTo(1)
    }

    private fun createCourseFixture(
        questionType: String = "A",
        prompt: String? = "Pencere",
        correctAnswer: String? = "Window",
        wrongAnswers: List<String> = listOf("Door", "Table", "Chair"),
        alternativeCorrectAnswer: String? = null,
        matchingLabels: List<Pair<String, String>> = listOf(
            "Pencere" to "Window",
            "Kapı" to "Door",
            "Masa" to "Table",
            "Sandalye" to "Chair",
        ),
    ): Fixture {
        require(questionType in setOf("A", "B", "C", "D"))
        require(questionType in setOf("C", "D") || wrongAnswers.size == 3)
        require(questionType != "D" || matchingLabels.size in 2..6)
        val matchingPairs = if (questionType == "D") {
            matchingLabels.map { (targetText, supportText) ->
                MatchingFixturePair(
                    targetItemId = UUID.randomUUID(),
                    targetText = targetText,
                    supportItemId = UUID.randomUUID(),
                    supportText = supportText,
                    alternateSupportItemId = UUID.randomUUID(),
                    alternateSupportText = "de-$supportText",
                )
            }
        } else {
            emptyList()
        }
        val fixture = Fixture(
            courseId = UUID.randomUUID(),
            testId = UUID.randomUUID(),
            questionRevisionId = UUID.randomUUID(),
            correctOptionId = UUID.randomUUID(),
            wrongOptionId = UUID.randomUUID(),
            matchingPairs = matchingPairs,
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
            if (questionType == "D") {
                jdbcTemplate.update(
                    "insert into course_support_language(course_id, language_code) values (?, 'de')",
                    fixture.courseId,
                )
            }
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
                TypedAnswerPolicy.canonicalize(checkNotNull(correctAnswer), it, checkNotNull(answerPolicy))
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
                    matching_policy, matching_label_policy, matching_order_policy,
                    matching_target_language,
                    status, created_at
                ) values (?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'DRAFT', ?)
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
                questionType.takeIf { it == "D" }?.let { "matching-v1" },
                questionType.takeIf { it == "D" }?.let { MatchingLabelPolicy.VERSION },
                questionType.takeIf { it == "D" }?.let { "matching-order-v1" },
                questionType.takeIf { it == "D" }?.let { "tr" },
                now,
            )
            val options = if (questionType == "C" || questionType == "D") {
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
            fixture.matchingPairs.forEachIndexed { index, pair ->
                jdbcTemplate.update(
                    """
                    insert into question_revision_matching_pair(
                        target_item_id, question_revision_id, course_id, position,
                        target_text, target_label_key
                    ) values (?, ?, ?, ?, ?, ?)
                    """.trimIndent(),
                    pair.targetItemId,
                    fixture.questionRevisionId,
                    fixture.courseId,
                    index + 1,
                    pair.targetText,
                    MatchingLabelPolicy.canonicalize(pair.targetText, "tr"),
                )
                jdbcTemplate.update(
                    """
                    insert into question_revision_matching_translation(
                        support_item_id, question_revision_id, course_id, target_item_id,
                        support_language, support_text, support_label_key
                    ) values (?, ?, ?, ?, 'en', ?, ?)
                    """.trimIndent(),
                    pair.supportItemId,
                    fixture.questionRevisionId,
                    fixture.courseId,
                    pair.targetItemId,
                    pair.supportText,
                    MatchingLabelPolicy.canonicalize(pair.supportText, "en"),
                )
                jdbcTemplate.update(
                    """
                    insert into question_revision_matching_translation(
                        support_item_id, question_revision_id, course_id, target_item_id,
                        support_language, support_text, support_label_key
                    ) values (?, ?, ?, ?, 'de', ?, ?)
                    """.trimIndent(),
                    pair.alternateSupportItemId,
                    fixture.questionRevisionId,
                    fixture.courseId,
                    pair.targetItemId,
                    pair.alternateSupportText,
                    MatchingLabelPolicy.canonicalize(pair.alternateSupportText, "de"),
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
        val matchingPairs: List<MatchingFixturePair>,
    )

    data class MatchingFixturePair(
        val targetItemId: UUID,
        val targetText: String,
        val supportItemId: UUID,
        val supportText: String,
        val alternateSupportItemId: UUID,
        val alternateSupportText: String,
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
            registry.add("KELIMIO_MATCHING_REPLAY_ACTIVE_KEY_VERSION") { "integration-v1" }
            registry.add("KELIMIO_MATCHING_REPLAY_KEYS") {
                "integration-v1=AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8="
            }
        }
    }
}
