package com.kelimio.api.development

import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.util.UUID

@Repository
class LocalStarterCourseRepository(
    private val dsl: DSLContext,
) {
    fun lockOwnerSource(userId: UUID) {
        dsl.fetch(
            "select pg_advisory_xact_lock(hashtextextended(?, 0))",
            "$userId:${LocalStarterCourseDefinition.ORIGIN_TYPE}:${LocalStarterCourseDefinition.ORIGIN_KEY}",
        )
    }

    fun findExistingCourse(userId: UUID): UUID? =
        dsl.fetchOne(
            """
            select course_id
              from course_origin
             where owner_user_id = ?
               and origin_type = ?
               and origin_key = ?
            """.trimIndent(),
            userId,
            LocalStarterCourseDefinition.ORIGIN_TYPE,
            LocalStarterCourseDefinition.ORIGIN_KEY,
        )?.get("course_id", UUID::class.java)

    fun create(userId: UUID, now: OffsetDateTime): UUID {
        val courseId = UUID.randomUUID()
        val releaseId = UUID.randomUUID()
        val testId = UUID.randomUUID()
        val testRevisionId = UUID.randomUUID()

        dsl.execute(
            """
            insert into course(
                id, owner_user_id, name, description, target_language,
                default_support_language, visibility, publication_status,
                access_type, created_at, updated_at, active_release_id
            ) values (
                ?, ?, ?, ?, 'tr', 'en', 'PUBLIC', 'DRAFT', 'FREE',
                cast(? as timestamptz), cast(? as timestamptz), ?
            )
            """.trimIndent(),
            courseId,
            userId,
            LocalStarterCourseDefinition.COURSE_NAME,
            LocalStarterCourseDefinition.COURSE_DESCRIPTION,
            now,
            now,
            releaseId,
        )
        dsl.execute(
            "insert into course_support_language(course_id, language_code) values (?, 'en')",
            courseId,
        )
        dsl.execute(
            """
            insert into course_release(id, course_id, revision_number, status, created_at)
            values (?, ?, 1, 'DRAFT', cast(? as timestamptz))
            """.trimIndent(),
            releaseId,
            courseId,
            now,
        )
        dsl.execute(
            "insert into course_test(id, course_id, created_at) values (?, ?, cast(? as timestamptz))",
            testId,
            courseId,
            now,
        )
        dsl.execute(
            """
            insert into test_revision(
                id, test_id, course_id, revision_number, title, status, pass_threshold, created_at
            ) values (?, ?, ?, 1, ?, 'DRAFT', 0.5000, cast(? as timestamptz))
            """.trimIndent(),
            testRevisionId,
            testId,
            courseId,
            LocalStarterCourseDefinition.TEST_TITLE,
            now,
        )

        LocalStarterCourseDefinition.questions.forEachIndexed { questionIndex, source ->
            val questionId = UUID.randomUUID()
            val questionRevisionId = UUID.randomUUID()
            dsl.execute(
                "insert into question(id, course_id, created_at) values (?, ?, cast(? as timestamptz))",
                questionId,
                courseId,
                now,
            )
            dsl.execute(
                """
                insert into question_revision(
                    id, question_id, course_id, revision_number, question_type,
                    prompt, correct_answer, status, created_at
                ) values (?, ?, ?, 1, ?, ?, ?, 'DRAFT', cast(? as timestamptz))
                """.trimIndent(),
                questionRevisionId,
                questionId,
                courseId,
                source.type.storageCode,
                source.prompt,
                source.correctAnswer,
                now,
            )
            source.options.forEachIndexed { optionIndex, option ->
                dsl.execute(
                    """
                    insert into question_revision_option(
                        id, question_revision_id, option_text, is_correct, position
                    ) values (?, ?, ?, ?, ?)
                    """.trimIndent(),
                    UUID.randomUUID(),
                    questionRevisionId,
                    option,
                    option == source.correctAnswer,
                    optionIndex + 1,
                )
            }
            dsl.execute("update question_revision set status = 'ACTIVE' where id = ?", questionRevisionId)
            dsl.execute(
                """
                insert into test_revision_question(
                    test_revision_id, question_revision_id, question_id, course_id, position
                ) values (?, ?, ?, ?, ?)
                """.trimIndent(),
                testRevisionId,
                questionRevisionId,
                questionId,
                courseId,
                questionIndex + 1,
            )
        }

        dsl.execute("update test_revision set status = 'ACTIVE' where id = ?", testRevisionId)
        dsl.execute(
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
        dsl.execute("update course_release set status = 'ACTIVE' where id = ?", releaseId)
        dsl.execute(
            """
            update course
               set publication_status = 'PUBLISHED', updated_at = cast(? as timestamptz)
             where id = ?
            """.trimIndent(),
            now,
            courseId,
        )
        dsl.execute(
            """
            insert into course_origin(
                course_id, owner_user_id, origin_type, origin_key, source_sha256, created_at
            ) values (?, ?, ?, ?, ?, cast(? as timestamptz))
            """.trimIndent(),
            courseId,
            userId,
            LocalStarterCourseDefinition.ORIGIN_TYPE,
            LocalStarterCourseDefinition.ORIGIN_KEY,
            LocalStarterCourseDefinition.SOURCE_WORKBOOK_SHA256,
            now,
        )
        return courseId
    }
}
