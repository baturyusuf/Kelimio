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
class MultipleChoiceClozeMigrationTest {
    @Test
    fun `V5 preserves active Type A content and admits only well formed Type B prompts`() {
        Flyway.configure()
            .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            .target(MigrationVersion.fromVersion("4"))
            .load()
            .migrate()

        val courseId = UUID.randomUUID()
        val typeARevisionId = UUID.randomUUID()
        DriverManager.getConnection(postgres.jdbcUrl, postgres.username, postgres.password).use { connection ->
            createPublishedTypeAContent(connection, courseId, typeARevisionId)
        }

        Flyway.configure()
            .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            .load()
            .migrate()

        DriverManager.getConnection(postgres.jdbcUrl, postgres.username, postgres.password).use { connection ->
            connection.prepareStatement(
                "select question_type from question_revision where id = ?",
            ).use { statement ->
                statement.setObject(1, typeARevisionId)
                statement.executeQuery().use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("question_type")).isEqualTo("A")
                }
            }

            val typeBRevisionId = insertActiveQuestion(
                connection = connection,
                courseId = courseId,
                type = "B",
                prompt = "Ben her sabah çay ---.",
                correctAnswer = "içerim",
                wrongAnswers = listOf("yerim", "koşarım", "yazarım"),
            )
            assertThat(
                connection.prepareStatement(
                    "select prompt from question_revision where id = ? and question_type = 'B'",
                ).use { statement ->
                    statement.setObject(1, typeBRevisionId)
                    statement.executeQuery().use { result ->
                        check(result.next())
                        result.getString("prompt")
                    }
                },
            ).isEqualTo("Ben her sabah çay ---.")

            assertThatThrownBy {
                insertDraftQuestion(
                    connection,
                    courseId,
                    type = "B",
                    prompt = "Ben her sabah çay içerim.",
                    correctAnswer = "içerim",
                )
            }.isInstanceOf(SQLException::class.java)

            assertThatThrownBy {
                insertDraftQuestion(
                    connection,
                    courseId,
                    type = "B",
                    prompt = "Ben her sabah çay ----.",
                    correctAnswer = "içerim",
                )
            }.isInstanceOf(SQLException::class.java)

            assertThatThrownBy {
                insertDraftQuestion(
                    connection,
                    courseId,
                    type = "B",
                    prompt = "Ben --- çay ---.",
                    correctAnswer = "içerim",
                )
            }.isInstanceOf(SQLException::class.java)

            assertThatThrownBy {
                insertDraftQuestion(
                    connection,
                    courseId,
                    type = "C",
                    prompt = "Sabah kahvaltıda çay ---.",
                    correctAnswer = "içerim",
                )
            }.isInstanceOf(SQLException::class.java)
        }
    }

    private fun createPublishedTypeAContent(
        connection: Connection,
        courseId: UUID,
        questionRevisionId: UUID,
    ) {
        val now = OffsetDateTime.now(ZoneOffset.UTC)
        val ownerId = UUID.randomUUID()
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
                ) values (?, ?, ?, ?, ?, 'tr', 'tr', 'UTC', ?, ?)
                """.trimIndent(),
                ownerId,
                "migration-owner-$ownerId",
                "migration-owner@integration.invalid",
                "Migration Owner",
                "migration-owner",
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
                ) values (?, ?, 'Migration Course', 'V5 rehearsal', 'tr', 'en',
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
            execute(
                connection,
                "insert into question(id, course_id, created_at) values (?, ?, ?)",
                questionId,
                courseId,
                now,
            )
            execute(
                connection,
                """
                insert into question_revision(
                    id, question_id, course_id, revision_number, question_type,
                    prompt, correct_answer, status, created_at
                ) values (?, ?, ?, 1, 'A', 'Pencere', 'Window', 'DRAFT', ?)
                """.trimIndent(),
                questionRevisionId,
                questionId,
                courseId,
                now,
            )
            listOf("Window", "Door", "Table", "Chair").forEachIndexed { index, answer ->
                execute(
                    connection,
                    """
                    insert into question_revision_option(
                        id, question_revision_id, option_text, is_correct, position
                    ) values (?, ?, ?, ?, ?)
                    """.trimIndent(),
                    UUID.randomUUID(),
                    questionRevisionId,
                    answer,
                    answer == "Window",
                    index + 1,
                )
            }
            execute(connection, "update question_revision set status = 'ACTIVE' where id = ?", questionRevisionId)
            execute(
                connection,
                """
                insert into test_revision_question(
                    test_revision_id, question_revision_id, question_id, course_id, position
                ) values (?, ?, ?, ?, 1)
                """.trimIndent(),
                testRevisionId,
                questionRevisionId,
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

    private fun insertActiveQuestion(
        connection: Connection,
        courseId: UUID,
        type: String,
        prompt: String,
        correctAnswer: String,
        wrongAnswers: List<String>,
    ): UUID {
        val questionRevisionId = insertDraftQuestion(connection, courseId, type, prompt, correctAnswer)
        (listOf(correctAnswer) + wrongAnswers).forEachIndexed { index, answer ->
            execute(
                connection,
                """
                insert into question_revision_option(
                    id, question_revision_id, option_text, is_correct, position
                ) values (?, ?, ?, ?, ?)
                """.trimIndent(),
                UUID.randomUUID(),
                questionRevisionId,
                answer,
                index == 0,
                index + 1,
            )
        }
        execute(connection, "update question_revision set status = 'ACTIVE' where id = ?", questionRevisionId)
        return questionRevisionId
    }

    private fun insertDraftQuestion(
        connection: Connection,
        courseId: UUID,
        type: String,
        prompt: String,
        correctAnswer: String,
    ): UUID {
        val now = OffsetDateTime.now(ZoneOffset.UTC)
        val questionId = UUID.randomUUID()
        val questionRevisionId = UUID.randomUUID()
        execute(
            connection,
            "insert into question(id, course_id, created_at) values (?, ?, ?)",
            questionId,
            courseId,
            now,
        )
        execute(
            connection,
            """
            insert into question_revision(
                id, question_id, course_id, revision_number, question_type,
                prompt, correct_answer, status, created_at
            ) values (?, ?, ?, 1, ?, ?, ?, 'DRAFT', ?)
            """.trimIndent(),
            questionRevisionId,
            questionId,
            courseId,
            type,
            prompt,
            correctAnswer,
            now,
        )
        return questionRevisionId
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
