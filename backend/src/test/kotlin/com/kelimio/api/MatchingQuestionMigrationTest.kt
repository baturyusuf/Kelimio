package com.kelimio.api

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.flywaydb.core.Flyway
import org.flywaydb.core.api.FlywayException
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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

@Testcontainers(disabledWithoutDocker = true)
class MatchingQuestionMigrationTest {
    @Test
    fun `V7 backfills the exact enrollment language without a default fallback`() {
        val database = isolatedDatabase("matching_backfill")
        migrate(database, "6")
        val legacy = connection(database).use { createLegacyAttempt(it, createEnrollment = true) }

        migrate(database)

        connection(database).use { connection ->
            assertThat(queryString(connection, "select support_language from test_attempt where id = ?", legacy.attemptId))
                .isEqualTo("ar")
            assertThat(
                queryString(
                    connection,
                    """
                    select column_default
                      from information_schema.columns
                     where table_schema = current_schema()
                       and table_name = 'test_attempt'
                       and column_name = 'support_language'
                    """.trimIndent(),
                ),
            ).isNull()

            assertThatThrownBy {
                insertAttempt(
                    connection,
                    legacy.userId,
                    legacy.courseId,
                    legacy.releaseId,
                    legacy.testRevisionId,
                    legacy.questionRevisionId,
                    supportLanguage = "en",
                )
            }.isInstanceOf(SQLException::class.java)
            execute(
                connection,
                "update enrollment set support_language = 'en' where course_id = ? and user_id = ?",
                legacy.courseId,
                legacy.userId,
            )
            assertThat(queryString(connection, "select support_language from test_attempt where id = ?", legacy.attemptId))
                .isEqualTo("ar")
            assertThatThrownBy {
                execute(
                    connection,
                    "update test_attempt set support_language = 'en' where id = ?",
                    legacy.attemptId,
                )
            }.isInstanceOf(SQLException::class.java)
        }
    }

    @Test
    fun `V7 fails closed when a legacy attempt has no owning enrollment`() {
        val database = isolatedDatabase("matching_backfill_reject")
        migrate(database, "6")
        connection(database).use { createLegacyAttempt(it, createEnrollment = false) }

        assertThatThrownBy { migrate(database) }
            .isInstanceOf(FlywayException::class.java)
            .hasMessageContaining("V7")
            .rootCause()
            .hasMessageContaining(
                "V7 cannot pin support language: every existing attempt requires exactly one owning enrollment",
            )

        connection(database).use { connection ->
            assertThat(
                queryInt(
                    connection,
                    """
                    select count(*)
                      from information_schema.columns
                     where table_schema = current_schema()
                       and table_name = 'test_attempt'
                       and column_name = 'support_language'
                    """.trimIndent(),
                ),
            ).isZero()
        }
    }

    @Test
    fun `V7 enforces complete immutable matching content and disjoint random identities`() {
        val database = isolatedDatabase("matching_content")
        migrate(database)
        connection(database).use { connection ->
            val base = createBaseCourse(connection, listOf("en", "ar"))
            val matching = insertMatchingDraft(connection, base.courseId, listOf("en", "ar"), pairCount = 2)
            execute(connection, "update question_revision set status = 'ACTIVE' where id = ?", matching.revisionId)

            connection.prepareStatement(
                """
                select prompt, correct_answer, matching_policy, matching_label_policy,
                       matching_order_policy, matching_target_language
                  from question_revision
                 where id = ?
                """.trimIndent(),
            ).use { statement ->
                statement.setObject(1, matching.revisionId)
                statement.executeQuery().use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("prompt")).isNull()
                    assertThat(result.getString("correct_answer")).isNull()
                    assertThat(result.getString("matching_policy")).isEqualTo("matching-v1")
                    assertThat(result.getString("matching_label_policy")).isEqualTo("matching-label-v1")
                    assertThat(result.getString("matching_order_policy")).isEqualTo("matching-order-v1")
                    assertThat(result.getString("matching_target_language")).isEqualTo("tr")
                }
            }

            assertThatThrownBy {
                execute(
                    connection,
                    "insert into course_support_language(course_id, language_code) values (?, 'fr')",
                    base.courseId,
                )
            }.isInstanceOf(SQLException::class.java)
            assertThatThrownBy {
                execute(
                    connection,
                    "update question_revision_matching_pair set target_text = 'changed' where target_item_id = ?",
                    matching.targetIds.first(),
                )
            }.isInstanceOf(SQLException::class.java)
            assertThatThrownBy {
                execute(
                    connection,
                    "delete from question_revision_matching_translation where support_item_id = ?",
                    matching.supportIds.first(),
                )
            }.isInstanceOf(SQLException::class.java)

            val optionForbidden = insertMatchingDraft(
                connection,
                base.courseId,
                listOf("en", "ar"),
                pairCount = 2,
                insertTranslations = false,
            )
            assertThatThrownBy {
                execute(
                    connection,
                    """
                    insert into question_revision_option(
                        id, question_revision_id, option_text, is_correct, position
                    ) values (?, ?, 'forbidden', false, 1)
                    """.trimIndent(),
                    UUID.randomUUID(),
                    optionForbidden.revisionId,
                )
            }.isInstanceOf(SQLException::class.java)

            val incomplete = insertMatchingDraft(
                connection,
                base.courseId,
                listOf("en"),
                pairCount = 2,
            )
            assertThatThrownBy {
                execute(connection, "update question_revision set status = 'ACTIVE' where id = ?", incomplete.revisionId)
            }.isInstanceOf(SQLException::class.java)

            val tooSmall = insertMatchingDraft(connection, base.courseId, listOf("en", "ar"), pairCount = 1)
            assertThatThrownBy {
                execute(connection, "update question_revision set status = 'ACTIVE' where id = ?", tooSmall.revisionId)
            }.isInstanceOf(SQLException::class.java)

            val identityRevision = insertMatchingDraft(
                connection,
                base.courseId,
                emptyList(),
                pairCount = 0,
            )
            assertThatThrownBy {
                insertPair(
                    connection,
                    identityRevision.revisionId,
                    base.courseId,
                    UUID.fromString("10000000-0000-1000-8000-000000000001"),
                    1,
                    "invalid-version",
                )
            }.isInstanceOf(SQLException::class.java)
            assertThatThrownBy {
                insertPair(
                    connection,
                    identityRevision.revisionId,
                    base.courseId,
                    matching.supportIds.first(),
                    1,
                    "reused-support-id",
                )
            }.isInstanceOf(SQLException::class.java)

            val disjointPairId = UUID.randomUUID()
            insertPair(connection, identityRevision.revisionId, base.courseId, disjointPairId, 1, "fresh-target")
            assertThatThrownBy {
                insertTranslation(
                    connection,
                    identityRevision.revisionId,
                    base.courseId,
                    disjointPairId,
                    "en",
                    matching.targetIds.first(),
                    "reused-target-id",
                )
            }.isInstanceOf(SQLException::class.java)

            val duplicateLabelId = UUID.randomUUID()
            assertThatThrownBy {
                insertPair(
                    connection,
                    identityRevision.revisionId,
                    base.courseId,
                    duplicateLabelId,
                    2,
                    "fresh-target",
                )
            }.isInstanceOf(SQLException::class.java)

            val source = createBaseCourse(connection, listOf("en", "fr"))
            assertThatThrownBy {
                execute(
                    connection,
                    """
                    update course_support_language
                       set course_id = ?
                     where course_id = ? and language_code = 'fr'
                    """.trimIndent(),
                    base.courseId,
                    source.courseId,
                )
            }.isInstanceOf(SQLException::class.java)
        }
    }

    @Test
    fun `V7 serializes language insertion against matching activation and leaves no incomplete active revision`() {
        val database = isolatedDatabase("matching_concurrency")
        migrate(database, "7")
        val fixture = connection(database).use { connection ->
            val base = createBaseCourse(connection, listOf("en"), publish = false)
            base to insertMatchingDraft(connection, base.courseId, listOf("en"), pairCount = 2)
        }

        connection(database).use { activationConnection ->
            activationConnection.autoCommit = false
            execute(
                activationConnection,
                "update question_revision set status = 'ACTIVE' where id = ?",
                fixture.second.revisionId,
            )

            val executor = Executors.newSingleThreadExecutor()
            try {
                val started = CountDownLatch(1)
                val languageInsert = executor.submit<Throwable?> {
                    connection(database).use { languageConnection ->
                        started.countDown()
                        try {
                            execute(
                                languageConnection,
                                "insert into course_support_language(course_id, language_code) values (?, 'ar')",
                                fixture.first.courseId,
                            )
                            null
                        } catch (exception: Throwable) {
                            exception
                        }
                    }
                }
                assertThat(started.await(5, TimeUnit.SECONDS)).isTrue()
                assertThatThrownBy { languageInsert.get(250, TimeUnit.MILLISECONDS) }
                    .isInstanceOf(TimeoutException::class.java)

                activationConnection.commit()
                assertThat(languageInsert.get(5, TimeUnit.SECONDS)).isInstanceOf(SQLException::class.java)
            } finally {
                if (!activationConnection.autoCommit) {
                    activationConnection.rollback()
                    activationConnection.autoCommit = true
                }
                executor.shutdownNow()
            }
        }

        connection(database).use { connection ->
            assertThat(queryString(connection, "select status from question_revision where id = ?", fixture.second.revisionId))
                .isEqualTo("ACTIVE")
            assertThat(
                queryInt(
                    connection,
                    "select count(*) from course_support_language where course_id = ?",
                    fixture.first.courseId,
                ),
            ).isEqualTo(1)
            assertMatchingCompleteness(connection, fixture.second.revisionId, fixture.first.courseId)
        }

        val reverseFixture = connection(database).use { connection ->
            val base = createBaseCourse(connection, listOf("en"), publish = false)
            base to insertMatchingDraft(connection, base.courseId, listOf("en"), pairCount = 2)
        }
        connection(database).use { languageConnection ->
            languageConnection.autoCommit = false
            execute(
                languageConnection,
                "insert into course_support_language(course_id, language_code) values (?, 'ar')",
                reverseFixture.first.courseId,
            )

            val executor = Executors.newSingleThreadExecutor()
            try {
                val started = CountDownLatch(1)
                val activation = executor.submit<Throwable?> {
                    connection(database).use { activationConnection ->
                        started.countDown()
                        try {
                            execute(
                                activationConnection,
                                "update question_revision set status = 'ACTIVE' where id = ?",
                                reverseFixture.second.revisionId,
                            )
                            null
                        } catch (exception: Throwable) {
                            exception
                        }
                    }
                }
                assertThat(started.await(5, TimeUnit.SECONDS)).isTrue()
                assertThatThrownBy { activation.get(250, TimeUnit.MILLISECONDS) }
                    .isInstanceOf(TimeoutException::class.java)

                languageConnection.commit()
                assertThat(activation.get(5, TimeUnit.SECONDS)).isInstanceOf(SQLException::class.java)
            } finally {
                if (!languageConnection.autoCommit) {
                    languageConnection.rollback()
                    languageConnection.autoCommit = true
                }
                executor.shutdownNow()
            }
        }
        connection(database).use { connection ->
            assertThat(
                queryString(
                    connection,
                    "select status from question_revision where id = ?",
                    reverseFixture.second.revisionId,
                ),
            ).isEqualTo("DRAFT")
            assertThat(
                queryInt(
                    connection,
                    "select count(*) from course_support_language where course_id = ?",
                    reverseFixture.first.courseId,
                ),
            ).isEqualTo(2)
        }
    }

    @Test
    fun `V8 fails closed instead of converting unkeyed matching facts`() {
        val database = isolatedDatabase("matching_v8_reject")
        migrate(database, "7")
        connection(database).use { connection ->
            val base = createBaseCourse(connection, listOf("en"))
            val matching = insertMatchingDraft(connection, base.courseId, listOf("en"), pairCount = 2)
            execute(connection, "update question_revision set status = 'ACTIVE' where id = ?", matching.revisionId)
            val release = publishMatchingRevision(connection, base, matching.revisionId)
            val learnerId = createLearner(connection, base.courseId, "en")
            val attemptId = insertAttempt(
                connection,
                learnerId,
                base.courseId,
                release.releaseId,
                release.testRevisionId,
                matching.revisionId,
                "en",
            )

            connection.autoCommit = false
            try {
                insertV7MatchingAnswer(
                    connection,
                    UUID.randomUUID(),
                    attemptId,
                    learnerId,
                    matching.revisionId,
                    correctPairCount = 2,
                    isCorrect = true,
                )
                execute(
                    connection,
                    """
                    update test_attempt
                       set answered_count = 1, correct_count = 1, version = 1
                     where id = ?
                    """.trimIndent(),
                    attemptId,
                )
                connection.commit()
            } catch (exception: Throwable) {
                connection.rollback()
                throw exception
            } finally {
                connection.autoCommit = true
            }
        }

        assertThatThrownBy { migrate(database) }
            .isInstanceOf(FlywayException::class.java)
            .hasMessageContaining("V8")
            .rootCause()
            .hasMessageContaining("V8 cannot convert existing matching answer facts to keyed replay evidence")

        connection(database).use { connection ->
            assertThat(
                queryInt(
                    connection,
                    """
                    select count(*)
                      from information_schema.columns
                     where table_schema = current_schema()
                       and table_name = 'answer_submission'
                       and column_name = 'matching_correct_pair_count'
                    """.trimIndent(),
                ),
            ).isEqualTo(1)
            assertThat(
                queryInt(
                    connection,
                    """
                    select count(*)
                      from information_schema.columns
                     where table_schema = current_schema()
                       and table_name = 'answer_submission'
                       and column_name = 'matching_replay_key_version'
                    """.trimIndent(),
                ),
            ).isZero()
        }
    }

    @Test
    fun `V8 stores versioned matching replay evidence without a revealing pair count`() {
        val database = isolatedDatabase("matching_facts")
        migrate(database)
        connection(database).use { connection ->
            val base = createBaseCourse(connection, listOf("en"))
            val matching = insertMatchingDraft(connection, base.courseId, listOf("en"), pairCount = 2)
            execute(connection, "update question_revision set status = 'ACTIVE' where id = ?", matching.revisionId)
            val release = publishMatchingRevision(connection, base, matching.revisionId)
            val learnerId = createLearner(connection, base.courseId, "en")

            val validAttempt = insertAttempt(
                connection,
                learnerId,
                base.courseId,
                release.releaseId,
                release.testRevisionId,
                matching.revisionId,
                "en",
            )
            val submissionId = UUID.randomUUID()
            connection.autoCommit = false
            try {
                insertMatchingAnswer(
                    connection,
                    submissionId,
                    validAttempt,
                    learnerId,
                    matching.revisionId,
                    keyVersion = "test-v1",
                    isCorrect = true,
                )
                execute(
                    connection,
                    """
                    update test_attempt
                       set answered_count = 1, correct_count = 1, version = 1
                     where id = ?
                    """.trimIndent(),
                    validAttempt,
                )
                connection.commit()
            } catch (exception: Throwable) {
                connection.rollback()
                throw exception
            } finally {
                connection.autoCommit = true
            }

            connection.prepareStatement(
                """
                select answer_kind, selected_option_id, typed_answer_digest,
                       octet_length(matching_answer_salt) as salt_length,
                       octet_length(matching_answer_digest) as digest_length,
                       matching_replay_key_version, is_correct
                  from answer_submission
                 where submission_id = ?
                """.trimIndent(),
            ).use { statement ->
                statement.setObject(1, submissionId)
                statement.executeQuery().use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("answer_kind")).isEqualTo("MATCHING")
                    assertThat(result.getObject("selected_option_id")).isNull()
                    assertThat(result.getBytes("typed_answer_digest")).isNull()
                    assertThat(result.getInt("salt_length")).isEqualTo(16)
                    assertThat(result.getInt("digest_length")).isEqualTo(32)
                    assertThat(result.getString("matching_replay_key_version")).isEqualTo("test-v1")
                    assertThat(result.getBoolean("is_correct")).isTrue()
                }
            }
            assertThat(
                queryInt(
                    connection,
                    """
                    select count(*)
                      from information_schema.columns
                     where table_schema = current_schema()
                       and table_name = 'answer_submission'
                       and column_name = 'matching_correct_pair_count'
                    """.trimIndent(),
                ),
            ).isZero()
            assertThatThrownBy {
                execute(
                    connection,
                    "update answer_submission set matching_replay_key_version = 'test-v2' where submission_id = ?",
                    submissionId,
                )
            }.isInstanceOf(SQLException::class.java)

            val missingVersionAttempt = insertAttempt(
                connection,
                learnerId,
                base.courseId,
                release.releaseId,
                release.testRevisionId,
                matching.revisionId,
                "en",
            )
            assertThatThrownBy {
                insertMatchingAnswer(
                    connection,
                    UUID.randomUUID(),
                    missingVersionAttempt,
                    learnerId,
                    matching.revisionId,
                    keyVersion = null,
                    isCorrect = true,
                )
            }.isInstanceOf(SQLException::class.java)

            val noncanonicalVersionAttempt = insertAttempt(
                connection,
                learnerId,
                base.courseId,
                release.releaseId,
                release.testRevisionId,
                matching.revisionId,
                "en",
            )
            assertThatThrownBy {
                insertMatchingAnswer(
                    connection,
                    UUID.randomUUID(),
                    noncanonicalVersionAttempt,
                    learnerId,
                    matching.revisionId,
                    keyVersion = "TEST-V1",
                    isCorrect = false,
                )
            }.isInstanceOf(SQLException::class.java)
        }
    }

    private fun createLegacyAttempt(connection: Connection, createEnrollment: Boolean): LegacyAttempt {
        val base = createBaseCourse(connection, listOf("en", "ar"))
        val userId = createUser(connection, "legacy-learner")
        if (createEnrollment) {
            execute(
                connection,
                """
                insert into enrollment(id, course_id, user_id, support_language, status, enrolled_at)
                values (?, ?, ?, 'ar', 'ACTIVE', ?)
                """.trimIndent(),
                UUID.randomUUID(),
                base.courseId,
                userId,
                now(),
            )
        }
        val attemptId = insertLegacyAttempt(
            connection,
            userId,
            base.courseId,
            base.releaseId,
            base.testRevisionId,
            base.questionRevisionId,
        )
        return LegacyAttempt(
            userId,
            base.courseId,
            base.releaseId,
            base.testRevisionId,
            base.questionRevisionId,
            attemptId,
        )
    }

    private fun createBaseCourse(
        connection: Connection,
        supportLanguages: List<String>,
        publish: Boolean = true,
    ): BaseCourse {
        val ownerId = createUser(connection, "course-owner")
        val courseId = UUID.randomUUID()
        val releaseId = UUID.randomUUID()
        val testId = UUID.randomUUID()
        val testRevisionId = UUID.randomUUID()
        val questionId = UUID.randomUUID()
        val questionRevisionId = UUID.randomUUID()
        val createdAt = now()
        connection.autoCommit = false
        try {
            execute(
                connection,
                """
                insert into course(
                    id, owner_user_id, name, description, target_language,
                    default_support_language, visibility, publication_status,
                    access_type, created_at, updated_at, active_release_id
                ) values (?, ?, 'Matching migration course', null, 'tr', ?,
                    'PRIVATE', 'DRAFT', 'FREE', ?, ?, ?)
                """.trimIndent(),
                courseId,
                ownerId,
                supportLanguages.first(),
                createdAt,
                createdAt,
                releaseId,
            )
            supportLanguages.forEach { language ->
                execute(
                    connection,
                    "insert into course_support_language(course_id, language_code) values (?, ?)",
                    courseId,
                    language,
                )
            }
            execute(
                connection,
                "insert into course_release(id, course_id, revision_number, status, created_at) values (?, ?, 1, 'DRAFT', ?)",
                releaseId,
                courseId,
                createdAt,
            )
            execute(connection, "insert into course_test(id, course_id, created_at) values (?, ?, ?)", testId, courseId, createdAt)
            execute(
                connection,
                """
                insert into test_revision(
                    id, test_id, course_id, revision_number, title, status, pass_threshold, created_at
                ) values (?, ?, ?, 1, 'Bootstrap test', 'DRAFT', 0.5000, ?)
                """.trimIndent(),
                testRevisionId,
                testId,
                courseId,
                createdAt,
            )
            execute(connection, "insert into question(id, course_id, created_at) values (?, ?, ?)", questionId, courseId, createdAt)
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
                createdAt,
            )
            listOf("Window", "Door", "Table", "Chair").forEachIndexed { index, text ->
                execute(
                    connection,
                    """
                    insert into question_revision_option(
                        id, question_revision_id, option_text, is_correct, position
                    ) values (?, ?, ?, ?, ?)
                    """.trimIndent(),
                    UUID.randomUUID(),
                    questionRevisionId,
                    text,
                    index == 0,
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
            if (publish) {
                execute(connection, "update course set publication_status = 'PUBLISHED' where id = ?", courseId)
            }
            connection.commit()
        } catch (exception: Throwable) {
            connection.rollback()
            throw exception
        } finally {
            connection.autoCommit = true
        }
        return BaseCourse(courseId, releaseId, testRevisionId, questionRevisionId)
    }

    private fun insertMatchingDraft(
        connection: Connection,
        courseId: UUID,
        translationLanguages: List<String>,
        pairCount: Int,
        insertTranslations: Boolean = true,
    ): MatchingQuestion {
        val questionId = UUID.randomUUID()
        val revisionId = UUID.randomUUID()
        execute(connection, "insert into question(id, course_id, created_at) values (?, ?, ?)", questionId, courseId, now())
        execute(
            connection,
            """
            insert into question_revision(
                id, question_id, course_id, revision_number, question_type,
                prompt, correct_answer, matching_policy, matching_label_policy,
                matching_order_policy, matching_target_language, status, created_at
            ) values (?, ?, ?, 1, 'D', null, null, 'matching-v1', 'matching-label-v1',
                'matching-order-v1', 'tr', 'DRAFT', ?)
            """.trimIndent(),
            revisionId,
            questionId,
            courseId,
            now(),
        )
        val targetIds = mutableListOf<UUID>()
        val supportIds = mutableListOf<UUID>()
        repeat(pairCount) { index ->
            val targetId = UUID.randomUUID()
            targetIds += targetId
            insertPair(connection, revisionId, courseId, targetId, index + 1, "target-${index + 1}")
            if (insertTranslations) {
                translationLanguages.forEach { language ->
                    val supportId = UUID.randomUUID()
                    supportIds += supportId
                    insertTranslation(
                        connection,
                        revisionId,
                        courseId,
                        targetId,
                        language,
                        supportId,
                        "$language-support-${index + 1}",
                    )
                }
            }
        }
        return MatchingQuestion(questionId, revisionId, targetIds, supportIds)
    }

    private fun publishMatchingRevision(
        connection: Connection,
        base: BaseCourse,
        matchingRevisionId: UUID,
    ): PublishedMatching {
        val testId = UUID.randomUUID()
        val testRevisionId = UUID.randomUUID()
        val releaseId = UUID.randomUUID()
        val questionId = queryUuid(
            connection,
            "select question_id from question_revision where id = ?",
            matchingRevisionId,
        )
        connection.autoCommit = false
        try {
            execute(connection, "insert into course_test(id, course_id, created_at) values (?, ?, ?)", testId, base.courseId, now())
            execute(
                connection,
                """
                insert into test_revision(
                    id, test_id, course_id, revision_number, title, status, pass_threshold, created_at
                ) values (?, ?, ?, 1, 'Matching test', 'DRAFT', 0.5000, ?)
                """.trimIndent(),
                testRevisionId,
                testId,
                base.courseId,
                now(),
            )
            execute(
                connection,
                """
                insert into test_revision_question(
                    test_revision_id, question_revision_id, question_id, course_id, position
                ) values (?, ?, ?, ?, 1)
                """.trimIndent(),
                testRevisionId,
                matchingRevisionId,
                questionId,
                base.courseId,
            )
            execute(connection, "update test_revision set status = 'ACTIVE' where id = ?", testRevisionId)
            execute(
                connection,
                "insert into course_release(id, course_id, revision_number, status, created_at) values (?, ?, 2, 'DRAFT', ?)",
                releaseId,
                base.courseId,
                now(),
            )
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
                base.courseId,
            )
            execute(connection, "update course_release set status = 'RETIRED' where id = ?", base.releaseId)
            execute(connection, "update course_release set status = 'ACTIVE' where id = ?", releaseId)
            execute(
                connection,
                "update course set active_release_id = ?, updated_at = ? where id = ?",
                releaseId,
                now(),
                base.courseId,
            )
            connection.commit()
        } catch (exception: Throwable) {
            connection.rollback()
            throw exception
        } finally {
            connection.autoCommit = true
        }
        return PublishedMatching(releaseId, testRevisionId)
    }

    private fun createLearner(connection: Connection, courseId: UUID, supportLanguage: String): UUID {
        val learnerId = createUser(connection, "matching-learner")
        execute(
            connection,
            """
            insert into enrollment(id, course_id, user_id, support_language, status, enrolled_at)
            values (?, ?, ?, ?, 'ACTIVE', ?)
            """.trimIndent(),
            UUID.randomUUID(),
            courseId,
            learnerId,
            supportLanguage,
            now(),
        )
        return learnerId
    }

    private fun createUser(connection: Connection, prefix: String): UUID {
        val id = UUID.randomUUID()
        val suffix = id.toString().take(12)
        execute(
            connection,
            """
            insert into app_user(
                id, oidc_subject, email, display_name, username, app_locale,
                active_target_language, time_zone, created_at, updated_at
            ) values (?, ?, ?, 'Migration User', ?, 'tr', 'tr', 'UTC', ?, ?)
            """.trimIndent(),
            id,
            "$prefix-$id",
            "$prefix-$suffix@integration.invalid",
            "$prefix-$suffix",
            now(),
            now(),
        )
        return id
    }

    private fun insertLegacyAttempt(
        connection: Connection,
        userId: UUID,
        courseId: UUID,
        releaseId: UUID,
        testRevisionId: UUID,
        questionRevisionId: UUID,
    ): UUID {
        val attemptId = UUID.randomUUID()
        connection.autoCommit = false
        try {
            execute(
                connection,
                """
                insert into test_attempt(
                    id, user_id, course_id, course_release_id, course_access_type,
                    test_revision_id, status, shuffle_seed, total_questions,
                    answered_count, correct_count, started_at
                ) values (?, ?, ?, ?, 'FREE', ?, 'IN_PROGRESS', 7, 1, 0, 0, ?)
                """.trimIndent(),
                attemptId,
                userId,
                courseId,
                releaseId,
                testRevisionId,
                now(),
            )
            execute(
                connection,
                """
                insert into attempt_question_manifest(
                    attempt_id, test_revision_id, course_id, question_revision_id, position
                ) values (?, ?, ?, ?, 1)
                """.trimIndent(),
                attemptId,
                testRevisionId,
                courseId,
                questionRevisionId,
            )
            connection.commit()
        } catch (exception: Throwable) {
            connection.rollback()
            throw exception
        } finally {
            connection.autoCommit = true
        }
        return attemptId
    }

    private fun insertAttempt(
        connection: Connection,
        userId: UUID,
        courseId: UUID,
        releaseId: UUID,
        testRevisionId: UUID,
        questionRevisionId: UUID,
        supportLanguage: String,
    ): UUID {
        val attemptId = UUID.randomUUID()
        connection.autoCommit = false
        try {
            execute(
                connection,
                """
                insert into test_attempt(
                    id, user_id, course_id, course_release_id, course_access_type,
                    test_revision_id, support_language, status, shuffle_seed,
                    total_questions, answered_count, correct_count, started_at
                ) values (?, ?, ?, ?, 'FREE', ?, ?, 'IN_PROGRESS', 11, 1, 0, 0, ?)
                """.trimIndent(),
                attemptId,
                userId,
                courseId,
                releaseId,
                testRevisionId,
                supportLanguage,
                now(),
            )
            execute(
                connection,
                """
                insert into attempt_question_manifest(
                    attempt_id, test_revision_id, course_id, question_revision_id, position
                ) values (?, ?, ?, ?, 1)
                """.trimIndent(),
                attemptId,
                testRevisionId,
                courseId,
                questionRevisionId,
            )
            connection.commit()
        } catch (exception: Throwable) {
            connection.rollback()
            throw exception
        } finally {
            connection.autoCommit = true
        }
        return attemptId
    }

    private fun insertPair(
        connection: Connection,
        revisionId: UUID,
        courseId: UUID,
        targetId: UUID,
        position: Int,
        text: String,
    ) {
        execute(
            connection,
            """
            insert into question_revision_matching_pair(
                target_item_id, question_revision_id, course_id, position,
                target_text, target_label_key
            ) values (?, ?, ?, ?, ?, ?)
            """.trimIndent(),
            targetId,
            revisionId,
            courseId,
            position,
            text,
            text,
        )
    }

    private fun insertTranslation(
        connection: Connection,
        revisionId: UUID,
        courseId: UUID,
        targetId: UUID,
        language: String,
        supportId: UUID,
        text: String,
    ) {
        execute(
            connection,
            """
            insert into question_revision_matching_translation(
                support_item_id, question_revision_id, course_id, target_item_id,
                support_language, support_text, support_label_key
            ) values (?, ?, ?, ?, ?, ?, ?)
            """.trimIndent(),
            supportId,
            revisionId,
            courseId,
            targetId,
            language,
            text,
            text,
        )
    }

    private fun insertMatchingAnswer(
        connection: Connection,
        submissionId: UUID,
        attemptId: UUID,
        userId: UUID,
        revisionId: UUID,
        keyVersion: String?,
        isCorrect: Boolean,
    ) {
        execute(
            connection,
            """
            insert into answer_submission(
                submission_id, attempt_id, user_id, question_revision_id,
                selected_option_id, answer_kind, typed_answer_salt,
                typed_answer_digest, typed_match_ordinal, matching_answer_salt,
                matching_answer_digest, matching_replay_key_version, is_correct,
                active_score_delta, lifetime_score_delta, active_question_score,
                lifetime_score, energy_balance_after, energy_unlimited,
                energy_next_regeneration_at, attempt_status_after, submitted_at
            ) values (?, ?, ?, ?, null, 'MATCHING', null, null, null,
                decode(repeat('11', 16), 'hex'), decode(repeat('22', 32), 'hex'), ?, ?,
                ?, ?, ?, ?, 5, false, null, 'IN_PROGRESS', ?)
            """.trimIndent(),
            submissionId,
            attemptId,
            userId,
            revisionId,
            keyVersion,
            isCorrect,
            if (isCorrect) 60 else 0,
            if (isCorrect) 60 else 0,
            if (isCorrect) 60 else 0,
            if (isCorrect) 60 else 0,
            now(),
        )
    }

    private fun insertV7MatchingAnswer(
        connection: Connection,
        submissionId: UUID,
        attemptId: UUID,
        userId: UUID,
        revisionId: UUID,
        correctPairCount: Int,
        isCorrect: Boolean,
    ) {
        execute(
            connection,
            """
            insert into answer_submission(
                submission_id, attempt_id, user_id, question_revision_id,
                selected_option_id, answer_kind, typed_answer_salt,
                typed_answer_digest, typed_match_ordinal, matching_answer_salt,
                matching_answer_digest, matching_correct_pair_count, is_correct,
                active_score_delta, lifetime_score_delta, active_question_score,
                lifetime_score, energy_balance_after, energy_unlimited,
                energy_next_regeneration_at, attempt_status_after, submitted_at
            ) values (?, ?, ?, ?, null, 'MATCHING', null, null, null,
                decode(repeat('11', 16), 'hex'), decode(repeat('22', 32), 'hex'), ?, ?,
                ?, ?, ?, ?, 5, false, null, 'IN_PROGRESS', ?)
            """.trimIndent(),
            submissionId,
            attemptId,
            userId,
            revisionId,
            correctPairCount,
            isCorrect,
            if (isCorrect) 60 else 0,
            if (isCorrect) 60 else 0,
            if (isCorrect) 60 else 0,
            if (isCorrect) 60 else 0,
            now(),
        )
    }

    private fun assertMatchingCompleteness(connection: Connection, revisionId: UUID, courseId: UUID) {
        val pairCount = queryInt(
            connection,
            "select count(*) from question_revision_matching_pair where question_revision_id = ?",
            revisionId,
        )
        val languageCount = queryInt(
            connection,
            "select count(*) from course_support_language where course_id = ?",
            courseId,
        )
        val translationCount = queryInt(
            connection,
            "select count(*) from question_revision_matching_translation where question_revision_id = ?",
            revisionId,
        )
        assertThat(pairCount).isBetween(2, 6)
        assertThat(translationCount).isEqualTo(pairCount * languageCount)
    }

    private fun isolatedDatabase(prefix: String): TestDatabase {
        val schema = "${prefix}_${UUID.randomUUID().toString().replace("-", "")}"
        DriverManager.getConnection(postgres.jdbcUrl, postgres.username, postgres.password).use { connection ->
            connection.createStatement().use { statement -> statement.execute("create schema $schema") }
        }
        val separator = if (postgres.jdbcUrl.contains('?')) '&' else '?'
        return TestDatabase(schema, "${postgres.jdbcUrl}${separator}currentSchema=$schema")
    }

    private fun migrate(database: TestDatabase, target: String? = null) {
        val configuration = Flyway.configure()
            .dataSource(database.jdbcUrl, postgres.username, postgres.password)
            .schemas(database.schema)
            .defaultSchema(database.schema)
        if (target != null) {
            configuration.target(MigrationVersion.fromVersion(target))
        }
        configuration.load().migrate()
    }

    private fun connection(database: TestDatabase): Connection =
        DriverManager.getConnection(database.jdbcUrl, postgres.username, postgres.password)

    private fun queryString(connection: Connection, sql: String, vararg values: Any): String? =
        connection.prepareStatement(sql).use { statement ->
            values.forEachIndexed { index, value -> statement.setObject(index + 1, value) }
            statement.executeQuery().use { result ->
                check(result.next())
                result.getString(1)
            }
        }

    private fun queryUuid(connection: Connection, sql: String, vararg values: Any): UUID =
        connection.prepareStatement(sql).use { statement ->
            values.forEachIndexed { index, value -> statement.setObject(index + 1, value) }
            statement.executeQuery().use { result ->
                check(result.next())
                result.getObject(1, UUID::class.java)
            }
        }

    private fun queryInt(connection: Connection, sql: String, vararg values: Any): Int =
        connection.prepareStatement(sql).use { statement ->
            values.forEachIndexed { index, value -> statement.setObject(index + 1, value) }
            statement.executeQuery().use { result ->
                check(result.next())
                result.getInt(1)
            }
        }

    private fun execute(connection: Connection, sql: String, vararg values: Any?): Int =
        connection.prepareStatement(sql).use { statement ->
            values.forEachIndexed { index, value -> statement.setObject(index + 1, value) }
            statement.executeUpdate()
        }

    private fun now(): OffsetDateTime = OffsetDateTime.now(ZoneOffset.UTC)

    private data class TestDatabase(val schema: String, val jdbcUrl: String)

    private data class BaseCourse(
        val courseId: UUID,
        val releaseId: UUID,
        val testRevisionId: UUID,
        val questionRevisionId: UUID,
    )

    private data class LegacyAttempt(
        val userId: UUID,
        val courseId: UUID,
        val releaseId: UUID,
        val testRevisionId: UUID,
        val questionRevisionId: UUID,
        val attemptId: UUID,
    )

    private data class MatchingQuestion(
        val questionId: UUID,
        val revisionId: UUID,
        val targetIds: List<UUID>,
        val supportIds: List<UUID>,
    )

    private data class PublishedMatching(val releaseId: UUID, val testRevisionId: UUID)

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
