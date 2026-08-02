package com.kelimio.api

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.flywaydb.core.Flyway
import org.flywaydb.core.api.MigrationVersion
import org.junit.jupiter.api.Test
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.utility.DockerImageName
import java.sql.Connection
import java.sql.DriverManager
import java.sql.SQLException
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Testcontainers(disabledWithoutDocker = true)
class TypedClozeMigrationTest {
    @Test
    fun `V6 preserves multiple choice revisions and enforces immutable typed cloze content`() {
        Flyway.configure()
            .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            .target(MigrationVersion.fromVersion("5"))
            .load()
            .migrate()

        val courseId = UUID.randomUUID()
        val typeARevisionId = UUID.randomUUID()
        val typeACorrectOptionId = UUID.randomUUID()
        val typeBRevisionId = UUID.randomUUID()
        val existingAttemptId = UUID.randomUUID()
        val existingSubmissionId = UUID.randomUUID()
        DriverManager.getConnection(postgres.jdbcUrl, postgres.username, postgres.password).use { connection ->
            createPublishedTypeAContent(
                connection,
                courseId,
                typeARevisionId,
                typeACorrectOptionId,
            )
            insertActiveMultipleChoiceQuestion(
                connection,
                courseId,
                typeBRevisionId,
                type = "B",
                prompt = "Ben her sabah çay ---.",
                correctAnswer = "içerim",
                wrongAnswers = listOf("yerim", "koşarım", "yazarım"),
            )
            insertExistingOptionAnswerFact(
                connection,
                courseId,
                typeARevisionId,
                typeACorrectOptionId,
                existingAttemptId,
                existingSubmissionId,
            )
        }

        Flyway.configure()
            .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            .load()
            .migrate()

        DriverManager.getConnection(postgres.jdbcUrl, postgres.username, postgres.password).use { connection ->
            assertMultipleChoiceRevisionPreserved(connection, typeARevisionId, "A")
            assertMultipleChoiceRevisionPreserved(connection, typeBRevisionId, "B")
            connection.prepareStatement(
                """
                select answer_kind, selected_option_id, typed_answer_salt,
                       typed_answer_digest, typed_match_ordinal, is_correct,
                       active_score_delta, lifetime_score_delta
                  from answer_submission
                 where submission_id = ? and attempt_id = ?
                """.trimIndent(),
            ).use { statement ->
                statement.setObject(1, existingSubmissionId)
                statement.setObject(2, existingAttemptId)
                statement.executeQuery().use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("answer_kind")).isEqualTo("OPTION")
                    assertThat(result.getObject("selected_option_id", UUID::class.java))
                        .isEqualTo(typeACorrectOptionId)
                    assertThat(result.getBytes("typed_answer_salt")).isNull()
                    assertThat(result.getBytes("typed_answer_digest")).isNull()
                    assertThat(result.getObject("typed_match_ordinal")).isNull()
                    assertThat(result.getBoolean("is_correct")).isTrue()
                    assertThat(result.getInt("active_score_delta")).isEqualTo(60)
                    assertThat(result.getInt("lifetime_score_delta")).isEqualTo(60)
                }
            }

            assertThatThrownBy {
                insertTypedDraftQuestion(
                    connection,
                    courseId,
                    prompt = "Eksik işaret",
                    language = "tr",
                )
            }.isInstanceOf(SQLException::class.java)
            assertThatThrownBy {
                insertTypedDraftQuestion(
                    connection,
                    courseId,
                    prompt = "Sabah kahvaltıda çay ----.",
                    language = "tr",
                )
            }.isInstanceOf(SQLException::class.java)

            val languageMismatchRevisionId = insertTypedDraftQuestion(
                connection,
                courseId,
                prompt = "Sabah kahvaltıda çay ---. ",
                language = "en",
            )
            assertThatThrownBy {
                execute(
                    connection,
                    "update question_revision set status = 'ACTIVE' where id = ?",
                    languageMismatchRevisionId,
                )
            }.isInstanceOf(SQLException::class.java)

            val typedRevisionId = insertTypedDraftQuestion(
                connection,
                courseId,
                prompt = "Sabah kahvaltıda çay ---. ",
                language = "tr",
            )
            assertThatThrownBy {
                insertOption(connection, typedRevisionId, "içerim", true, 1)
            }.isInstanceOf(SQLException::class.java)

            execute(connection, "update question_revision set status = 'ACTIVE' where id = ?", typedRevisionId)
            assertThat(
                connection.prepareStatement(
                    "select count(*) from question_revision_option where question_revision_id = ?",
                ).use { statement ->
                    statement.setObject(1, typedRevisionId)
                    statement.executeQuery().use { result ->
                        check(result.next())
                        result.getInt(1)
                    }
                },
            ).isZero()
            assertThatThrownBy {
                execute(
                    connection,
                    "update question_revision set correct_answer = 'değiştirildi' where id = ?",
                    typedRevisionId,
                )
            }.isInstanceOf(SQLException::class.java)
            assertThatThrownBy {
                execute(
                    connection,
                    "update question_revision set correct_answer_match_key = 'değiştirildi' where id = ?",
                    typedRevisionId,
                )
            }.isInstanceOf(SQLException::class.java)
        }
    }

    private fun createPublishedTypeAContent(
        connection: Connection,
        courseId: UUID,
        typeARevisionId: UUID,
        typeACorrectOptionId: UUID,
    ) {
        val now = OffsetDateTime.now(ZoneOffset.UTC)
        val ownerId = UUID.randomUUID()
        val ownerSuffix = ownerId.toString().take(12)
        val releaseId = UUID.randomUUID()
        val testId = UUID.randomUUID()
        val testRevisionId = UUID.randomUUID()
        val questionId = UUID.randomUUID()
        connection.autoCommit = false
        try {
            execute(
                connection,
                """
                insert into app_user(
                    id, oidc_subject, email, display_name, username, app_locale,
                    active_target_language, time_zone, created_at, updated_at
                ) values (?, ?, ?, 'Migration Owner', ?, 'tr', 'tr', 'UTC', ?, ?)
                """.trimIndent(),
                ownerId,
                "typed-migration-owner-$ownerId",
                "typed-migration-$ownerSuffix@integration.invalid",
                "typed-migration-$ownerSuffix",
                now,
                now,
            )
            execute(
                connection,
                """
                insert into course(
                    id, owner_user_id, name, description, target_language,
                    default_support_language, visibility, publication_status,
                    access_type, created_at, updated_at, active_release_id
                ) values (?, ?, 'Typed Migration Course', 'V6 rehearsal', 'tr', 'en',
                    'PUBLIC', 'DRAFT', 'FREE', ?, ?, ?)
                """.trimIndent(),
                courseId,
                ownerId,
                now,
                now,
                releaseId,
            )
            execute(
                connection,
                "insert into course_support_language(course_id, language_code) values (?, 'en')",
                courseId,
            )
            execute(
                connection,
                "insert into course_release(id, course_id, revision_number, status, created_at) values (?, ?, 1, 'DRAFT', ?)",
                releaseId,
                courseId,
                now,
            )
            execute(
                connection,
                "insert into course_test(id, course_id, created_at) values (?, ?, ?)",
                testId,
                courseId,
                now,
            )
            execute(
                connection,
                """
                insert into test_revision(
                    id, test_id, course_id, revision_number, title, status, pass_threshold, created_at
                ) values (?, ?, ?, 1, 'Migration Test', 'DRAFT', 0.5000, ?)
                """.trimIndent(),
                testRevisionId,
                testId,
                courseId,
                now,
            )
            execute(connection, "insert into question(id, course_id, created_at) values (?, ?, ?)", questionId, courseId, now)
            execute(
                connection,
                """
                insert into question_revision(
                    id, question_id, course_id, revision_number, question_type,
                    prompt, correct_answer, status, created_at
                ) values (?, ?, ?, 1, 'A', 'Pencere', 'Window', 'DRAFT', ?)
                """.trimIndent(),
                typeARevisionId,
                questionId,
                courseId,
                now,
            )
            listOf("Window", "Door", "Table", "Chair").forEachIndexed { index, answer ->
                insertOption(
                    connection,
                    typeARevisionId,
                    answer,
                    index == 0,
                    index + 1,
                    optionId = if (index == 0) typeACorrectOptionId else UUID.randomUUID(),
                )
            }
            execute(connection, "update question_revision set status = 'ACTIVE' where id = ?", typeARevisionId)
            execute(
                connection,
                """
                insert into test_revision_question(
                    test_revision_id, question_revision_id, question_id, course_id, position
                ) values (?, ?, ?, ?, 1)
                """.trimIndent(),
                testRevisionId,
                typeARevisionId,
                questionId,
                courseId,
            )
            execute(connection, "update test_revision set status = 'ACTIVE' where id = ?", testRevisionId)
            execute(
                connection,
                """
                insert into course_release_test_revision(
                    course_release_id, test_revision_id, test_id, course_id, position
                ) values (?, ?, ?, ?, 1)
                """.trimIndent(),
                releaseId,
                testRevisionId,
                testId,
                courseId,
            )
            execute(connection, "update course_release set status = 'ACTIVE' where id = ?", releaseId)
            execute(
                connection,
                "update course set publication_status = 'PUBLISHED', updated_at = ? where id = ?",
                now,
                courseId,
            )
            connection.commit()
        } catch (exception: Throwable) {
            connection.rollback()
            throw exception
        } finally {
            connection.autoCommit = true
        }
    }

    private fun insertExistingOptionAnswerFact(
        connection: Connection,
        courseId: UUID,
        questionRevisionId: UUID,
        selectedOptionId: UUID,
        attemptId: UUID,
        submissionId: UUID,
    ) {
        val now = OffsetDateTime.now(ZoneOffset.UTC)
        val userId = UUID.randomUUID()
        val userSuffix = userId.toString().take(12)
        val releaseAndTestRevision = connection.prepareStatement(
            """
            select crtr.course_release_id, trq.test_revision_id
              from test_revision_question trq
              join course_release_test_revision crtr
                on crtr.test_revision_id = trq.test_revision_id
             where trq.question_revision_id = ?
            """.trimIndent(),
        ).use { statement ->
            statement.setObject(1, questionRevisionId)
            statement.executeQuery().use { result ->
                check(result.next())
                result.getObject("course_release_id", UUID::class.java) to
                    result.getObject("test_revision_id", UUID::class.java)
            }
        }
        connection.autoCommit = false
        try {
            execute(
                connection,
                """
                insert into app_user(
                    id, oidc_subject, email, display_name, username, app_locale,
                    active_target_language, time_zone, created_at, updated_at
                ) values (?, ?, ?, 'Legacy Learner', ?, 'tr', 'tr', 'UTC', ?, ?)
                """.trimIndent(),
                userId,
                "typed-migration-learner-$userId",
                "typed-learner-$userSuffix@integration.invalid",
                "typed-learner-$userSuffix",
                now,
                now,
            )
            execute(
                connection,
                """
                insert into test_attempt(
                    id, user_id, course_id, course_release_id, course_access_type,
                    test_revision_id, status, shuffle_seed, total_questions,
                    answered_count, correct_count, started_at
                ) values (?, ?, ?, ?, 'FREE', ?, 'IN_PROGRESS', 42, 1, 1, 1, ?)
                """.trimIndent(),
                attemptId,
                userId,
                courseId,
                releaseAndTestRevision.first,
                releaseAndTestRevision.second,
                now,
            )
            execute(
                connection,
                """
                insert into attempt_question_manifest(
                    attempt_id, test_revision_id, course_id, question_revision_id, position
                ) values (?, ?, ?, ?, 1)
                """.trimIndent(),
                attemptId,
                releaseAndTestRevision.second,
                courseId,
                questionRevisionId,
            )
            execute(
                connection,
                """
                insert into answer_submission(
                    submission_id, attempt_id, user_id, question_revision_id,
                    selected_option_id, is_correct, active_score_delta,
                    lifetime_score_delta, active_question_score, lifetime_score,
                    energy_balance_after, energy_unlimited,
                    energy_next_regeneration_at, attempt_status_after, submitted_at
                ) values (?, ?, ?, ?, ?, true, 60, 60, 60, 60, 5, false,
                    null, 'IN_PROGRESS', ?)
                """.trimIndent(),
                submissionId,
                attemptId,
                userId,
                questionRevisionId,
                selectedOptionId,
                now,
            )
            connection.commit()
        } catch (exception: Throwable) {
            connection.rollback()
            throw exception
        } finally {
            connection.autoCommit = true
        }
    }

    private fun insertTypedDraftQuestion(
        connection: Connection,
        courseId: UUID,
        prompt: String,
        language: String,
    ): UUID {
        val now = OffsetDateTime.now(ZoneOffset.UTC)
        val questionId = UUID.randomUUID()
        val revisionId = UUID.randomUUID()
        execute(connection, "insert into question(id, course_id, created_at) values (?, ?, ?)", questionId, courseId, now)
        execute(
            connection,
            """
            insert into question_revision(
                id, question_id, course_id, revision_number, question_type,
                prompt, correct_answer, alternative_correct_answer,
                answer_match_policy, answer_match_language,
                correct_answer_match_key, alternative_answer_match_key,
                status, created_at
            ) values (?, ?, ?, 1, 'C', ?, 'içerim', 'içiyorum',
                'typed-answer-v1', ?, 'içerim', 'içiyorum', 'DRAFT', ?)
            """.trimIndent(),
            revisionId,
            questionId,
            courseId,
            prompt,
            language,
            now,
        )
        return revisionId
    }

    private fun insertActiveMultipleChoiceQuestion(
        connection: Connection,
        courseId: UUID,
        revisionId: UUID,
        type: String,
        prompt: String,
        correctAnswer: String,
        wrongAnswers: List<String>,
    ) {
        val now = OffsetDateTime.now(ZoneOffset.UTC)
        val questionId = UUID.randomUUID()
        execute(connection, "insert into question(id, course_id, created_at) values (?, ?, ?)", questionId, courseId, now)
        execute(
            connection,
            """
            insert into question_revision(
                id, question_id, course_id, revision_number, question_type,
                prompt, correct_answer, status, created_at
            ) values (?, ?, ?, 1, ?, ?, ?, 'DRAFT', ?)
            """.trimIndent(),
            revisionId,
            questionId,
            courseId,
            type,
            prompt,
            correctAnswer,
            now,
        )
        (listOf(correctAnswer) + wrongAnswers).forEachIndexed { index, answer ->
            insertOption(connection, revisionId, answer, index == 0, index + 1)
        }
        execute(connection, "update question_revision set status = 'ACTIVE' where id = ?", revisionId)
    }

    private fun assertMultipleChoiceRevisionPreserved(
        connection: Connection,
        revisionId: UUID,
        expectedType: String,
    ) {
        connection.prepareStatement(
            """
            select question_type, alternative_correct_answer, answer_match_policy,
                   answer_match_language, correct_answer_match_key,
                   alternative_answer_match_key
              from question_revision
             where id = ?
            """.trimIndent(),
        ).use { statement ->
            statement.setObject(1, revisionId)
            statement.executeQuery().use { result ->
                assertThat(result.next()).isTrue()
                assertThat(result.getString("question_type")).isEqualTo(expectedType)
                assertThat(result.getString("alternative_correct_answer")).isNull()
                assertThat(result.getString("answer_match_policy")).isNull()
                assertThat(result.getString("answer_match_language")).isNull()
                assertThat(result.getString("correct_answer_match_key")).isNull()
                assertThat(result.getString("alternative_answer_match_key")).isNull()
            }
        }
    }

    private fun insertOption(
        connection: Connection,
        questionRevisionId: UUID,
        answer: String,
        correct: Boolean,
        position: Int,
        optionId: UUID = UUID.randomUUID(),
    ) {
        execute(
            connection,
            """
            insert into question_revision_option(
                id, question_revision_id, option_text, is_correct, position
            ) values (?, ?, ?, ?, ?)
            """.trimIndent(),
            optionId,
            questionRevisionId,
            answer,
            correct,
            position,
        )
    }

    private fun execute(
        connection: Connection,
        sql: String,
        vararg values: Any,
    ): Int = connection.prepareStatement(sql).use { statement ->
        values.forEachIndexed { index, value -> statement.setObject(index + 1, value) }
        statement.executeUpdate()
    }

    private class KPostgreSQLContainer(image: DockerImageName) : PostgreSQLContainer<KPostgreSQLContainer>(image)

    companion object {
        @Container
        @JvmStatic
        private val postgres = KPostgreSQLContainer(
            DockerImageName
                .parse("postgres:17.5-alpine@sha256:6567bca8d7bc8c82c5922425a0baee57be8402df92bae5eacad5f01ae9544daa")
                .asCompatibleSubstituteFor("postgres"),
        )
    }
}
