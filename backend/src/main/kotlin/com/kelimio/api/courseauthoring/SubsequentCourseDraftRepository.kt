package com.kelimio.api.courseauthoring

import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.util.UUID

@Repository
internal class SubsequentCourseDraftRepository(
    private val dsl: DSLContext,
) {
    fun course(courseId: UUID): CourseAuthoringCourseState? = dsl.fetchOne(
        """
        select id, owner_user_id, publication_status, active_release_id
          from course
         where id = ?
        """.trimIndent(),
        courseId,
    )?.toCourseState()

    fun lockCourse(courseId: UUID): CourseAuthoringCourseState? = dsl.fetchOne(
        """
        select id, owner_user_id, publication_status, active_release_id
          from course
         where id = ?
         for update
        """.trimIndent(),
        courseId,
    )?.toCourseState()

    private fun org.jooq.Record.toCourseState() =
        CourseAuthoringCourseState(
            courseId = get("id", UUID::class.java)!!,
            ownerUserId = get("owner_user_id", UUID::class.java)!!,
            publicationStatus = get("publication_status", String::class.java)!!,
            activeReleaseId = get("active_release_id", UUID::class.java),
        )

    fun editorSnapshot(courseId: UUID): LocalCourseEditorSnapshot? = dsl.fetchOne(
        """
        select course.id as course_id, course.name as course_name,
               release_row.id as active_release_id,
               release_row.revision_number as release_revision,
               level_revision.title as level_title,
               unit_revision.title as unit_title,
               topic_revision.title as topic_title,
               test_revision.test_id, test_revision.title as test_title,
               question_revision.question_id, question_revision.id as question_revision_id,
               question_revision.revision_number as question_revision,
               question_revision.prompt
          from course
          join course_release release_row on release_row.id = course.active_release_id
          join course_release_test_hierarchy test_hierarchy
            on test_hierarchy.course_release_id = release_row.id
          join test_revision on test_revision.id = test_hierarchy.test_revision_id
          join test_revision_question test_question
            on test_question.test_revision_id = test_revision.id
          join question_revision on question_revision.id = test_question.question_revision_id
          join content_topic_revision topic_revision
            on topic_revision.id = test_hierarchy.parent_topic_revision_id
          join course_release_topic_revision release_topic
            on release_topic.course_release_id = release_row.id
           and release_topic.topic_revision_id = topic_revision.id
          join course_release_unit_revision release_unit
            on release_unit.course_release_id = release_row.id
           and release_unit.unit_revision_id = release_topic.parent_unit_revision_id
          join content_unit_revision unit_revision
            on unit_revision.id = release_unit.unit_revision_id
          join course_release_level_revision release_level
            on release_level.course_release_id = release_row.id
           and release_level.level_revision_id = release_unit.parent_level_revision_id
          join content_level_revision level_revision
            on level_revision.id = release_level.level_revision_id
         where course.id = ?
           and course.publication_status in ('PUBLISHED', 'HIDDEN')
           and release_row.status = 'ACTIVE'
           and test_revision.status = 'ACTIVE'
           and question_revision.status = 'ACTIVE'
           and question_revision.question_type = 'C'
         order by release_level.position, release_unit.position, release_topic.position,
                  test_hierarchy.position, test_question.position,
                  question_revision.question_id, question_revision.id
         limit 1
        """.trimIndent(),
        courseId,
    )?.let {
        LocalCourseEditorSnapshot(
            courseId = it.get("course_id", UUID::class.java)!!,
            courseName = it.get("course_name", String::class.java)!!,
            activeReleaseId = it.get("active_release_id", UUID::class.java)!!,
            releaseRevision = it.get("release_revision", Int::class.java)!!,
            levelTitle = it.get("level_title", String::class.java)!!,
            unitTitle = it.get("unit_title", String::class.java)!!,
            topicTitle = it.get("topic_title", String::class.java)!!,
            testId = it.get("test_id", UUID::class.java)!!,
            testTitle = it.get("test_title", String::class.java)!!,
            questionId = it.get("question_id", UUID::class.java)!!,
            questionRevisionId = it.get("question_revision_id", UUID::class.java)!!,
            questionRevision = it.get("question_revision", Int::class.java)!!,
            prompt = it.get("prompt", String::class.java)!!,
        )
    }

    fun hasUnpublishedDraft(courseId: UUID, baseReleaseId: UUID): Boolean = dsl.fetchOne(
            """
            select exists(
                select 1
              from course_authoring_commit authoring
              join course_release release_row on release_row.id = authoring.draft_release_id
             where authoring.course_id = ?
               and authoring.base_release_id = ?
               and release_row.status = 'DRAFT'
            ) as found
            """.trimIndent(),
            courseId,
            baseReleaseId,
    )!!.get("found", Boolean::class.java)!!

    fun source(
        courseId: UUID,
        baseReleaseId: UUID,
        expectedQuestionRevisionId: UUID? = null,
    ): CourseAuthoringSource? = dsl.fetchOne(
        """
        select release_row.course_id, release_row.id as base_release_id,
               (select max(candidate.revision_number) + 1
                  from course_release candidate
                 where candidate.course_id = release_row.course_id) as next_release_revision,
               question_revision.question_id as changed_question_id,
               question_revision.id as previous_question_revision_id,
               question_revision.revision_number as previous_question_revision,
               (select max(candidate.revision_number) + 1
                  from question_revision candidate
                 where candidate.question_id = question_revision.question_id) as next_question_revision,
               question_revision.prompt as previous_prompt,
               test_revision.test_id as changed_test_id,
               test_revision.id as previous_test_revision_id,
               test_revision.revision_number as previous_test_revision,
               (select max(candidate.revision_number) + 1
                  from test_revision candidate
                 where candidate.test_id = test_revision.test_id) as next_test_revision
          from course_release release_row
          join course_release_test_revision release_test
            on release_test.course_release_id = release_row.id
          join test_revision on test_revision.id = release_test.test_revision_id
          join test_revision_question test_question
            on test_question.test_revision_id = test_revision.id
          join question_revision on question_revision.id = test_question.question_revision_id
         where release_row.id = ?
           and release_row.course_id = ?
           and release_row.status = 'ACTIVE'
           and question_revision.question_type = 'C'
           and (cast(? as uuid) is null or question_revision.id = cast(? as uuid))
         order by release_test.position, test_question.position,
                  question_revision.question_id, question_revision.id
         limit 1
        """.trimIndent(),
        baseReleaseId,
        courseId,
        expectedQuestionRevisionId,
        expectedQuestionRevisionId,
    )?.let {
        CourseAuthoringSource(
            courseId = it.get("course_id", UUID::class.java)!!,
            baseReleaseId = it.get("base_release_id", UUID::class.java)!!,
            nextReleaseRevision = it.get("next_release_revision", Int::class.java)!!,
            changedQuestionId = it.get("changed_question_id", UUID::class.java)!!,
            previousQuestionRevisionId = it.get("previous_question_revision_id", UUID::class.java)!!,
            previousQuestionRevision = it.get("previous_question_revision", Int::class.java)!!,
            nextQuestionRevision = it.get("next_question_revision", Int::class.java)!!,
            previousPrompt = it.get("previous_prompt", String::class.java)!!,
            changedTestId = it.get("changed_test_id", UUID::class.java)!!,
            previousTestRevisionId = it.get("previous_test_revision_id", UUID::class.java)!!,
            previousTestRevision = it.get("previous_test_revision", Int::class.java)!!,
            nextTestRevision = it.get("next_test_revision", Int::class.java)!!,
        )
    }

    fun createDraft(command: CreateSubsequentCourseDraftCommand) {
        val source = command.source
        check(
            dsl.execute(
                """
                insert into content_change_set(
                    id, course_id, owner_user_id, base_release_id, source_type,
                    source_reference_id, status, created_at, committed_at, correlation_id
                ) values (?, ?, ?, ?, 'MOBILE_AUTHORING', ?, 'COMMITTED',
                          cast(? as timestamptz), cast(? as timestamptz), ?)
                """.trimIndent(),
                command.contentChangeSetId,
                source.courseId,
                command.ownerUserId,
                source.baseReleaseId,
                command.commandId,
                command.occurredAt,
                command.occurredAt,
                command.correlationId,
            ) == 1,
        )
        listOf("CREATED", "COMMITTED").forEach { eventType ->
            check(
                dsl.execute(
                    """
                    insert into content_change_set_event(
                        id, content_change_set_id, event_type, actor_user_id,
                        occurred_at, correlation_id
                    ) values (?, ?, ?, ?, cast(? as timestamptz), ?)
                    """.trimIndent(),
                    UUID.randomUUID(),
                    command.contentChangeSetId,
                    eventType,
                    command.ownerUserId,
                    command.occurredAt,
                    command.correlationId,
                ) == 1,
            )
        }
        check(
            dsl.execute(
                """
                insert into course_release(id, course_id, revision_number, status, created_at)
                values (?, ?, ?, 'DRAFT', cast(? as timestamptz))
                """.trimIndent(),
                command.draftReleaseId,
                source.courseId,
                command.releaseRevision,
                command.occurredAt,
            ) == 1,
        )
        check(
            dsl.execute(
                """
                insert into course_release_source_change_set(
                    course_release_id, course_id, content_change_set_id, created_at
                ) values (?, ?, ?, cast(? as timestamptz))
                """.trimIndent(),
                command.draftReleaseId,
                source.courseId,
                command.contentChangeSetId,
                command.occurredAt,
            ) == 1,
        )
        check(
            dsl.execute(
                """
                insert into course_release_metadata(
                    course_release_id, course_id, course_name, course_description,
                    visibility, created_at
                )
                select ?, course_id, course_name, course_description,
                       visibility, cast(? as timestamptz)
                  from course_release_metadata
                 where course_release_id = ? and course_id = ?
                """.trimIndent(),
                command.draftReleaseId,
                command.occurredAt,
                source.baseReleaseId,
                source.courseId,
            ) == 1,
        )

        check(
            dsl.execute(
                """
                insert into question_revision(
                    id, question_id, course_id, revision_number, question_type,
                    prompt, correct_answer, alternative_correct_answer,
                    answer_match_policy, answer_match_language,
                    correct_answer_match_key, alternative_answer_match_key,
                    matching_policy, matching_label_policy, matching_order_policy,
                    matching_target_language, status, created_at
                )
                select ?, question_id, course_id, ?, question_type,
                       ?, correct_answer,
                       alternative_correct_answer, answer_match_policy,
                       answer_match_language, correct_answer_match_key,
                       alternative_answer_match_key, matching_policy,
                       matching_label_policy, matching_order_policy,
                       matching_target_language, 'DRAFT', cast(? as timestamptz)
                  from question_revision
                 where id = ? and question_id = ? and course_id = ?
                   and revision_number = ? and question_type = 'C'
                   and status = 'ACTIVE' and length(prompt) <= 960
                """.trimIndent(),
                command.questionRevisionId,
                source.nextQuestionRevision,
                command.editedPrompt,
                command.occurredAt,
                source.previousQuestionRevisionId,
                source.changedQuestionId,
                source.courseId,
                source.previousQuestionRevision,
            ) == 1,
        )
        dsl.execute(
            """
            insert into question_revision_translation(
                question_revision_id, course_id, support_language,
                translation_text, created_at
            )
            select ?, course_id, support_language, translation_text, cast(? as timestamptz)
              from question_revision_translation
             where question_revision_id = ?
             order by support_language
            """.trimIndent(),
            command.questionRevisionId,
            command.occurredAt,
            source.previousQuestionRevisionId,
        )
        check(
            dsl.execute(
                """
                insert into question_revision_source_change_set(
                    question_revision_id, question_id, course_id,
                    content_change_set_id, created_at
                ) values (?, ?, ?, ?, cast(? as timestamptz))
                """.trimIndent(),
                command.questionRevisionId,
                source.changedQuestionId,
                source.courseId,
                command.contentChangeSetId,
                command.occurredAt,
            ) == 1,
        )

        check(
            dsl.execute(
                """
                insert into test_revision(
                    id, test_id, course_id, revision_number, title,
                    status, pass_threshold, created_at
                )
                select ?, test_id, course_id, ?, title,
                       'DRAFT', pass_threshold, cast(? as timestamptz)
                  from test_revision
                 where id = ? and test_id = ? and course_id = ?
                   and revision_number = ? and status = 'ACTIVE'
                """.trimIndent(),
                command.testRevisionId,
                source.nextTestRevision,
                command.occurredAt,
                source.previousTestRevisionId,
                source.changedTestId,
                source.courseId,
                source.previousTestRevision,
            ) == 1,
        )
        check(
            dsl.execute(
                """
                insert into test_revision_source_change_set(
                    test_revision_id, test_id, course_id,
                    content_change_set_id, created_at
                ) values (?, ?, ?, ?, cast(? as timestamptz))
                """.trimIndent(),
                command.testRevisionId,
                source.changedTestId,
                source.courseId,
                command.contentChangeSetId,
                command.occurredAt,
            ) == 1,
        )
        dsl.execute(
            """
            insert into test_revision_question(
                test_revision_id, question_revision_id, question_id, course_id, position
            )
            select ?,
                   case when question_id = ? then ? else question_revision_id end,
                   question_id, course_id, position
              from test_revision_question
             where test_revision_id = ?
             order by position
            """.trimIndent(),
            command.testRevisionId,
            source.changedQuestionId,
            command.questionRevisionId,
            source.previousTestRevisionId,
        )

        copyHierarchy(command)
    }

    private fun copyHierarchy(command: CreateSubsequentCourseDraftCommand) {
        val source = command.source
        dsl.execute(
            """
            insert into course_release_level_revision(
                course_release_id, level_revision_id, level_id, course_id, position
            )
            select ?, level_revision_id, level_id, course_id, position
              from course_release_level_revision
             where course_release_id = ?
             order by position
            """.trimIndent(),
            command.draftReleaseId,
            source.baseReleaseId,
        )
        dsl.execute(
            """
            insert into course_release_unit_revision(
                course_release_id, parent_level_revision_id, unit_revision_id,
                unit_id, course_id, position
            )
            select ?, parent_level_revision_id, unit_revision_id,
                   unit_id, course_id, position
              from course_release_unit_revision
             where course_release_id = ?
             order by parent_level_revision_id, position
            """.trimIndent(),
            command.draftReleaseId,
            source.baseReleaseId,
        )
        dsl.execute(
            """
            insert into course_release_topic_revision(
                course_release_id, parent_unit_revision_id, topic_revision_id,
                topic_id, course_id, position
            )
            select ?, parent_unit_revision_id, topic_revision_id,
                   topic_id, course_id, position
              from course_release_topic_revision
             where course_release_id = ?
             order by parent_unit_revision_id, position
            """.trimIndent(),
            command.draftReleaseId,
            source.baseReleaseId,
        )
        dsl.execute(
            """
            insert into course_release_test_revision(
                course_release_id, test_revision_id, test_id, course_id, position
            )
            select ?,
                   case when test_id = ? then ? else test_revision_id end,
                   test_id, course_id, position
              from course_release_test_revision
             where course_release_id = ?
             order by position
            """.trimIndent(),
            command.draftReleaseId,
            source.changedTestId,
            command.testRevisionId,
            source.baseReleaseId,
        )
        dsl.execute(
            """
            insert into course_release_test_hierarchy(
                course_release_id, parent_topic_revision_id, test_revision_id,
                test_id, course_id, position
            )
            select ?, parent_topic_revision_id,
                   case when test_id = ? then ? else test_revision_id end,
                   test_id, course_id, position
              from course_release_test_hierarchy
             where course_release_id = ?
             order by parent_topic_revision_id, position
            """.trimIndent(),
            command.draftReleaseId,
            source.changedTestId,
            command.testRevisionId,
            source.baseReleaseId,
        )
    }

    fun insertCommit(command: CreateSubsequentCourseDraftCommand) {
        val source = command.source
        check(
            dsl.execute(
                """
                insert into course_authoring_commit(
                    id, course_id, owner_user_id, base_release_id,
                    content_change_set_id, draft_release_id,
                    changed_question_id, previous_question_revision_id,
                    question_revision_id, changed_test_id,
                    previous_test_revision_id, test_revision_id,
                    outbox_event_id, occurred_at, correlation_id
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, cast(? as timestamptz), ?)
                """.trimIndent(),
                command.commandId,
                source.courseId,
                command.ownerUserId,
                source.baseReleaseId,
                command.contentChangeSetId,
                command.draftReleaseId,
                source.changedQuestionId,
                source.previousQuestionRevisionId,
                command.questionRevisionId,
                source.changedTestId,
                source.previousTestRevisionId,
                command.testRevisionId,
                command.outboxEventId,
                command.occurredAt,
                command.correlationId,
            ) == 1,
        )
    }

    fun result(draftReleaseId: UUID, ownerUserId: UUID, created: Boolean): SubsequentCourseDraftResult? = dsl.fetchOne(
        """
        select authoring.course_id, authoring.base_release_id,
               authoring.content_change_set_id, authoring.draft_release_id,
               release_row.revision_number, authoring.changed_question_id,
               authoring.previous_question_revision_id, authoring.question_revision_id,
               authoring.changed_test_id, authoring.previous_test_revision_id,
               authoring.test_revision_id, authoring.occurred_at
          from course_authoring_commit authoring
          join course_release release_row on release_row.id = authoring.draft_release_id
         where authoring.draft_release_id = ? and authoring.owner_user_id = ?
        """.trimIndent(),
        draftReleaseId,
        ownerUserId,
    )?.let {
        SubsequentCourseDraftResult(
            courseId = it.get("course_id", UUID::class.java)!!,
            baseReleaseId = it.get("base_release_id", UUID::class.java)!!,
            contentChangeSetId = it.get("content_change_set_id", UUID::class.java)!!,
            draftReleaseId = it.get("draft_release_id", UUID::class.java)!!,
            releaseRevision = it.get("revision_number", Int::class.java)!!,
            changedQuestionId = it.get("changed_question_id", UUID::class.java)!!,
            previousQuestionRevisionId = it.get("previous_question_revision_id", UUID::class.java)!!,
            questionRevisionId = it.get("question_revision_id", UUID::class.java)!!,
            changedTestId = it.get("changed_test_id", UUID::class.java)!!,
            previousTestRevisionId = it.get("previous_test_revision_id", UUID::class.java)!!,
            testRevisionId = it.get("test_revision_id", UUID::class.java)!!,
            createdAt = it.get("occurred_at", java.time.OffsetDateTime::class.java)!!,
            created = created,
        )
    }
}
