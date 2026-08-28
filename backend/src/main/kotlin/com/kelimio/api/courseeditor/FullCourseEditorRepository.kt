package com.kelimio.api.courseeditor

import com.kelimio.api.language.MatchingLabelPolicy
import com.kelimio.api.language.TypedAnswerPolicy
import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.math.BigDecimal
import java.time.OffsetDateTime
import java.util.UUID

@Repository
internal class FullCourseEditorRepository(
    private val dsl: DSLContext,
) {
    fun lockCourse(courseId: UUID, ownerUserId: UUID): Boolean = dsl.fetchOne(
        "select id from course where id = ? and owner_user_id = ? for update",
        courseId,
        ownerUserId,
    ) != null

    fun courseState(courseId: UUID, ownerUserId: UUID): FullCourseEditorCourseState? = dsl.fetchOne(
            """
            select course.id, course.owner_user_id, course.active_release_id,
                   release_row.revision_number, course.publication_status,
                   course.name, course.description, course.visibility,
                   course.target_language, course.default_support_language,
                   array_agg(language.language_code order by language.language_code) as support_languages
              from course
              join course_release release_row on release_row.id = course.active_release_id
              join course_support_language language on language.course_id = course.id
             where course.id = ? and course.owner_user_id = ?
             group by course.id, release_row.id
            """.trimIndent(),
            courseId,
            ownerUserId,
        )?.let {
            FullCourseEditorCourseState(
                courseId = it.get("id", UUID::class.java)!!,
                ownerUserId = it.get("owner_user_id", UUID::class.java)!!,
                activeReleaseId = it.get("active_release_id", UUID::class.java)!!,
                releaseRevision = it.get("revision_number", Int::class.java)!!,
                publicationStatus = it.get("publication_status", String::class.java)!!,
                name = it.get("name", String::class.java)!!,
                description = it.get("description", String::class.java),
                visibility = it.get("visibility", String::class.java)!!,
                targetLanguage = it.get("target_language", String::class.java)!!,
                defaultSupportLanguage = it.get("default_support_language", String::class.java)!!,
                supportLanguages = it.get("support_languages", Array<String>::class.java)!!.toList(),
            )
        }

    fun publishedCourseState(courseId: UUID): FullCourseEditorCourseState? = dsl.fetchOne(
        """
        select course.id, course.owner_user_id, course.active_release_id,
               release_row.revision_number, course.publication_status,
               course.name, course.description, course.visibility,
               course.target_language, course.default_support_language,
               array_agg(language.language_code order by language.language_code) as support_languages
          from course
          join course_release release_row on release_row.id = course.active_release_id
          join course_support_language language on language.course_id = course.id
         where course.id = ? and course.publication_status = 'PUBLISHED'
         group by course.id, release_row.id
        """.trimIndent(),
        courseId,
    )?.let {
        FullCourseEditorCourseState(
            courseId = it.get("id", UUID::class.java)!!,
            ownerUserId = it.get("owner_user_id", UUID::class.java)!!,
            activeReleaseId = it.get("active_release_id", UUID::class.java)!!,
            releaseRevision = it.get("revision_number", Int::class.java)!!,
            publicationStatus = it.get("publication_status", String::class.java)!!,
            name = it.get("name", String::class.java)!!,
            description = it.get("description", String::class.java),
            visibility = it.get("visibility", String::class.java)!!,
            targetLanguage = it.get("target_language", String::class.java)!!,
            defaultSupportLanguage = it.get("default_support_language", String::class.java)!!,
            supportLanguages = it.get("support_languages", Array<String>::class.java)!!.toList(),
        )
    }

    fun document(course: FullCourseEditorCourseState): FullCourseEditorDocument {
        val releaseId = course.activeReleaseId
        val levels = linkedMapOf<UUID, MutableLevel>()
        val units = linkedMapOf<UUID, MutableUnit>()
        val topics = linkedMapOf<UUID, MutableTopic>()
        val tests = linkedMapOf<UUID, MutableTest>()
        val questions = linkedMapOf<UUID, MutableQuestion>()

        dsl.fetch(
            """
            select link.level_id, revision.title, link.position
              from course_release_level_revision link
              join content_level_revision revision on revision.id = link.level_revision_id
             where link.course_release_id = ?
             order by link.position
            """.trimIndent(),
            releaseId,
        ).forEach {
            val id = it.get("level_id", UUID::class.java)!!
            levels[id] = MutableLevel(id, it.get("title", String::class.java)!!, it.get("position", Int::class.java)!!)
        }
        dsl.fetch(
            """
            select parent.level_id, link.unit_id, revision.title, link.position
              from course_release_unit_revision link
              join course_release_level_revision parent
                on parent.course_release_id = link.course_release_id
               and parent.level_revision_id = link.parent_level_revision_id
              join content_unit_revision revision on revision.id = link.unit_revision_id
             where link.course_release_id = ?
             order by parent.position, link.position
            """.trimIndent(),
            releaseId,
        ).forEach {
            val id = it.get("unit_id", UUID::class.java)!!
            val unit = MutableUnit(id, it.get("title", String::class.java)!!, it.get("position", Int::class.java)!!)
            units[id] = unit
            levels.getValue(it.get("level_id", UUID::class.java)!!).units += unit
        }
        dsl.fetch(
            """
            select parent.unit_id, link.topic_id, revision.title, link.position
              from course_release_topic_revision link
              join course_release_unit_revision parent
                on parent.course_release_id = link.course_release_id
               and parent.unit_revision_id = link.parent_unit_revision_id
              join content_topic_revision revision on revision.id = link.topic_revision_id
             where link.course_release_id = ?
             order by parent.unit_id, link.position
            """.trimIndent(),
            releaseId,
        ).forEach {
            val id = it.get("topic_id", UUID::class.java)!!
            val topic = MutableTopic(id, it.get("title", String::class.java)!!, it.get("position", Int::class.java)!!)
            topics[id] = topic
            units.getValue(it.get("unit_id", UUID::class.java)!!).topics += topic
        }
        dsl.fetch(
            """
            select parent.topic_id, hierarchy.test_id, revision.title,
                   revision.pass_threshold, hierarchy.position
              from course_release_test_hierarchy hierarchy
              join course_release_topic_revision parent
                on parent.course_release_id = hierarchy.course_release_id
               and parent.topic_revision_id = hierarchy.parent_topic_revision_id
              join test_revision revision on revision.id = hierarchy.test_revision_id
             where hierarchy.course_release_id = ?
             order by parent.topic_id, hierarchy.position
            """.trimIndent(),
            releaseId,
        ).forEach {
            val id = it.get("test_id", UUID::class.java)!!
            val test = MutableTest(
                id,
                it.get("title", String::class.java)!!,
                it.get("pass_threshold", BigDecimal::class.java)!!,
                it.get("position", Int::class.java)!!,
            )
            tests[id] = test
            topics.getValue(it.get("topic_id", UUID::class.java)!!).tests += test
        }
        dsl.fetch(
            """
            select test_revision.test_id, question.question_id, question.question_type,
                   question.prompt, question.correct_answer, question.alternative_correct_answer,
                   test_question.position
              from course_release_test_revision release_test
              join test_revision on test_revision.id = release_test.test_revision_id
              join test_revision_question test_question on test_question.test_revision_id = test_revision.id
              join question_revision question on question.id = test_question.question_revision_id
             where release_test.course_release_id = ?
             order by release_test.position, test_question.position
            """.trimIndent(),
            releaseId,
        ).forEach {
            val id = it.get("question_id", UUID::class.java)!!
            val question = MutableQuestion(
                id = id,
                type = it.get("question_type", String::class.java)!!,
                prompt = it.get("prompt", String::class.java),
                correctAnswer = it.get("correct_answer", String::class.java),
                alternativeCorrectAnswer = it.get("alternative_correct_answer", String::class.java),
                position = it.get("position", Int::class.java)!!,
            )
            questions[id] = question
            tests.getValue(it.get("test_id", UUID::class.java)!!).questions += question
        }
        dsl.fetch(
            """
            select question.question_id, translation.support_language, translation.translation_text
              from course_release_test_revision release_test
              join test_revision_question test_question on test_question.test_revision_id = release_test.test_revision_id
              join question_revision question on question.id = test_question.question_revision_id
              join question_revision_translation translation
                on translation.question_revision_id = question.id
             where release_test.course_release_id = ?
             order by question.question_id, translation.support_language
            """.trimIndent(),
            releaseId,
        ).forEach {
            questions.getValue(it.get("question_id", UUID::class.java)!!).translations[
                it.get("support_language", String::class.java)!!
            ] = it.get("translation_text", String::class.java)!!
        }
        dsl.fetch(
            """
            select question.question_id, question.id as question_revision_id,
                   option.id, option.option_text, option.is_correct, option.position
              from course_release_test_revision release_test
              join test_revision_question test_question on test_question.test_revision_id = release_test.test_revision_id
              join question_revision question on question.id = test_question.question_revision_id
              join question_revision_option option on option.question_revision_id = question.id
             where release_test.course_release_id = ?
             order by question.question_id, option.position
            """.trimIndent(),
            releaseId,
        ).forEach {
            val option = MutableOption(
                id = it.get("id", UUID::class.java)!!,
                text = it.get("option_text", String::class.java)!!,
                correct = it.get("is_correct", Boolean::class.java)!!,
                position = it.get("position", Int::class.java)!!,
            )
            questions.getValue(it.get("question_id", UUID::class.java)!!).options += option
        }
        dsl.fetch(
            """
            select question.question_id, option_translation.option_id,
                   option_translation.support_language, option_translation.option_text
              from course_release_test_revision release_test
              join test_revision_question test_question on test_question.test_revision_id = release_test.test_revision_id
              join question_revision question on question.id = test_question.question_revision_id
              join question_revision_option_translation option_translation
                on option_translation.question_revision_id = question.id
             where release_test.course_release_id = ?
             order by question.question_id, option_translation.option_id,
                      option_translation.support_language
            """.trimIndent(),
            releaseId,
        ).forEach {
            val optionId = it.get("option_id", UUID::class.java)!!
            val option = questions.getValue(it.get("question_id", UUID::class.java)!!).options
                .first { candidate -> candidate.id == optionId }
            option.translations[it.get("support_language", String::class.java)!!] =
                it.get("option_text", String::class.java)!!
        }
        val pairsByTarget = linkedMapOf<UUID, MutableMatchingPair>()
        dsl.fetch(
            """
            select question.question_id, pair.target_item_id, pair.target_text, pair.position
              from course_release_test_revision release_test
              join test_revision_question test_question on test_question.test_revision_id = release_test.test_revision_id
              join question_revision question on question.id = test_question.question_revision_id
              join question_revision_matching_pair pair on pair.question_revision_id = question.id
             where release_test.course_release_id = ?
             order by question.question_id, pair.position
            """.trimIndent(),
            releaseId,
        ).forEach {
            val targetId = it.get("target_item_id", UUID::class.java)!!
            val pair = MutableMatchingPair(
                it.get("target_text", String::class.java)!!,
                it.get("position", Short::class.java)!!.toInt(),
            )
            pairsByTarget[targetId] = pair
            questions.getValue(it.get("question_id", UUID::class.java)!!).matchingPairs += pair
        }
        dsl.fetch(
            """
            select translation.target_item_id, translation.support_language, translation.support_text
              from course_release_test_revision release_test
              join test_revision_question test_question on test_question.test_revision_id = release_test.test_revision_id
              join question_revision question on question.id = test_question.question_revision_id
              join question_revision_matching_translation translation
                on translation.question_revision_id = question.id
             where release_test.course_release_id = ?
             order by translation.target_item_id, translation.support_language
            """.trimIndent(),
            releaseId,
        ).forEach {
            pairsByTarget.getValue(it.get("target_item_id", UUID::class.java)!!).translations[
                it.get("support_language", String::class.java)!!
            ] = it.get("support_text", String::class.java)!!
        }

        return FullCourseEditorDocument(
            courseId = course.courseId,
            activeReleaseId = course.activeReleaseId,
            releaseRevision = course.releaseRevision,
            name = course.name,
            description = course.description,
            visibility = course.visibility,
            targetLanguage = course.targetLanguage,
            defaultSupportLanguage = course.defaultSupportLanguage,
            supportLanguages = course.supportLanguages,
            levels = levels.values.sortedBy(MutableLevel::position).map(MutableLevel::toDto),
        )
    }

    fun hasOpenDraft(courseId: UUID): Boolean = checkNotNull(
        dsl.fetchOne(
            "select exists(select 1 from course_release where course_id = ? and status = 'DRAFT') as found",
            courseId,
        ),
    ).get("found", Boolean::class.java)!!

    fun createDraft(command: FullCourseEditorCommitCommand): FullCourseEditorDraftResponse {
        val course = command.course
        val request = command.request
        val nextReleaseRevision = checkNotNull(
            dsl.fetchOne(
                "select coalesce(max(revision_number), 0) + 1 as revision from course_release where course_id = ?",
                course.courseId,
            ),
        ).get("revision", Int::class.java)!!
        insertChangeSet(command)
        check(
            dsl.execute(
                """
                insert into course_release(id, course_id, revision_number, status, created_at)
                values (?, ?, ?, 'DRAFT', cast(? as timestamptz))
                """.trimIndent(),
                command.draftReleaseId,
                course.courseId,
                nextReleaseRevision,
                command.createdAt,
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
                course.courseId,
                command.contentChangeSetId,
                command.createdAt,
            ) == 1,
        )
        check(
            dsl.execute(
                """
                insert into course_release_metadata(
                    course_release_id, course_id, course_name, course_description,
                    visibility, created_at
                ) values (?, ?, ?, ?, ?, cast(? as timestamptz))
                """.trimIndent(),
                command.draftReleaseId,
                course.courseId,
                request.name,
                request.description,
                request.visibility,
                command.createdAt,
            ) == 1,
        )

        var globalTestPosition = 0
        var globalQuestionOrdinal = 0
        var unitCount = 0
        var topicCount = 0
        var testCount = 0
        var matchingPresent = false
        request.levels.forEachIndexed { levelIndex, level ->
            val levelId = stableId("content_level", level.id, course.courseId, command.createdAt)
            val levelRevisionId = UUID.randomUUID()
            insertLevelRevision(command, levelId, levelRevisionId, level.title, levelIndex + 1)
            level.units.forEachIndexed { unitIndex, unit ->
                unitCount += 1
                val unitId = stableId("content_unit", unit.id, course.courseId, command.createdAt)
                val unitRevisionId = UUID.randomUUID()
                insertUnitRevision(command, unitId, unitRevisionId, unit.title, levelRevisionId, unitIndex + 1)
                unit.topics.forEachIndexed { topicIndex, topic ->
                    topicCount += 1
                    val topicId = stableId("content_topic", topic.id, course.courseId, command.createdAt)
                    val topicRevisionId = UUID.randomUUID()
                    insertTopicRevision(command, topicId, topicRevisionId, topic.title, unitRevisionId, topicIndex + 1)
                    topic.tests.forEachIndexed { testIndex, test ->
                        testCount += 1
                        globalTestPosition += 1
                        val testId = stableId("course_test", test.id, course.courseId, command.createdAt)
                        val testRevisionId = UUID.randomUUID()
                        insertTestRevision(
                            command,
                            testId,
                            testRevisionId,
                            test,
                            topicRevisionId,
                            testIndex + 1,
                            globalTestPosition,
                        )
                        test.questions.forEachIndexed { questionIndex, question ->
                            globalQuestionOrdinal += 1
                            matchingPresent = matchingPresent || question.type == "D"
                            val questionId = stableId("question", question.id, course.courseId, command.createdAt)
                            val questionRevisionId = UUID.randomUUID()
                            insertQuestionRevision(
                                command = command,
                                questionId = questionId,
                                questionRevisionId = questionRevisionId,
                                question = question,
                                testRevisionId = testRevisionId,
                                position = questionIndex + 1,
                                ordinal = globalQuestionOrdinal,
                            )
                        }
                    }
                }
            }
        }
        if (matchingPresent) {
            check(
                dsl.execute(
                    """
                    insert into course_release_required_capability(
                        course_release_id, course_id, capability, created_at
                    ) values (?, ?, 'question.matching.v1', cast(? as timestamptz))
                    on conflict do nothing
                    """.trimIndent(),
                    command.draftReleaseId,
                    course.courseId,
                    command.createdAt,
                ) in 0..1,
            )
        }
        check(
            dsl.execute(
                """
                insert into full_course_authoring_commit(
                    id, command_id, course_id, owner_user_id, base_release_id,
                    content_change_set_id, draft_release_id, outbox_event_id, document_sha256,
                    level_count, unit_count, topic_count, test_count, question_count,
                    created_at, correlation_id
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, cast(? as timestamptz), ?)
                """.trimIndent(),
                UUID.randomUUID(),
                command.commandId,
                course.courseId,
                command.ownerUserId,
                course.activeReleaseId,
                command.contentChangeSetId,
                command.draftReleaseId,
                command.outboxEventId,
                command.documentSha256,
                request.levels.size,
                unitCount,
                topicCount,
                testCount,
                globalQuestionOrdinal,
                command.createdAt,
                command.correlationId,
            ) == 1,
        )
        return FullCourseEditorDraftResponse(
            courseId = course.courseId,
            baseReleaseId = course.activeReleaseId,
            contentChangeSetId = command.contentChangeSetId,
            draftReleaseId = command.draftReleaseId,
            releaseRevision = nextReleaseRevision,
            questionCount = globalQuestionOrdinal,
            requiredClientCapabilities = if (matchingPresent) listOf("question.matching.v1") else emptyList(),
            createdAt = command.createdAt,
            created = true,
        )
    }

    fun result(draftReleaseId: UUID, ownerUserId: UUID, created: Boolean): FullCourseEditorDraftResponse? = dsl.fetchOne(
        """
        select commit.course_id, commit.base_release_id, commit.content_change_set_id,
               commit.draft_release_id, release_row.revision_number,
               commit.question_count, commit.created_at,
               coalesce(array_agg(capability.capability order by capability.capability)
                   filter (where capability.capability is not null), '{}'::varchar[]) as capabilities
          from full_course_authoring_commit commit
          join course_release release_row on release_row.id = commit.draft_release_id
          left join course_release_required_capability capability
            on capability.course_release_id = commit.draft_release_id
         where commit.draft_release_id = ? and commit.owner_user_id = ?
         group by commit.id, release_row.id
        """.trimIndent(),
        draftReleaseId,
        ownerUserId,
    )?.let {
        FullCourseEditorDraftResponse(
            courseId = it.get("course_id", UUID::class.java)!!,
            baseReleaseId = it.get("base_release_id", UUID::class.java)!!,
            contentChangeSetId = it.get("content_change_set_id", UUID::class.java)!!,
            draftReleaseId = it.get("draft_release_id", UUID::class.java)!!,
            releaseRevision = it.get("revision_number", Int::class.java)!!,
            questionCount = it.get("question_count", Int::class.java)!!,
            requiredClientCapabilities = it.get("capabilities", Array<String>::class.java)!!.toList(),
            createdAt = it.get("created_at", OffsetDateTime::class.java)!!,
            created = created,
        )
    }

    private fun insertChangeSet(command: FullCourseEditorCommitCommand) {
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
                command.course.courseId,
                command.ownerUserId,
                command.course.activeReleaseId,
                command.commandId,
                command.createdAt,
                command.createdAt,
                command.correlationId,
            ) == 1,
        )
        listOf("CREATED", "COMMITTED").forEach { type ->
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
                    type,
                    command.ownerUserId,
                    command.createdAt,
                    command.correlationId,
                ) == 1,
            )
        }
    }

    private fun insertLevelRevision(
        command: FullCourseEditorCommitCommand,
        levelId: UUID,
        revisionId: UUID,
        title: String,
        position: Int,
    ) {
        val revision = nextRevision("content_level_revision", "level_id", levelId)
        check(dsl.execute(
            """
            insert into content_level_revision(
                id, level_id, course_id, content_change_set_id,
                revision_number, title, hidden, created_at
            ) values (?, ?, ?, ?, ?, ?, false, cast(? as timestamptz))
            """.trimIndent(),
            revisionId, levelId, command.course.courseId, command.contentChangeSetId,
            revision, title, command.createdAt,
        ) == 1)
        check(dsl.execute(
            """
            insert into course_release_level_revision(
                course_release_id, level_revision_id, level_id, course_id, position
            ) values (?, ?, ?, ?, ?)
            """.trimIndent(),
            command.draftReleaseId, revisionId, levelId, command.course.courseId, position,
        ) == 1)
    }

    private fun insertUnitRevision(
        command: FullCourseEditorCommitCommand,
        unitId: UUID,
        revisionId: UUID,
        title: String,
        parentRevisionId: UUID,
        position: Int,
    ) {
        val revision = nextRevision("content_unit_revision", "unit_id", unitId)
        check(dsl.execute(
            """
            insert into content_unit_revision(
                id, unit_id, course_id, content_change_set_id,
                revision_number, title, hidden, created_at
            ) values (?, ?, ?, ?, ?, ?, false, cast(? as timestamptz))
            """.trimIndent(),
            revisionId, unitId, command.course.courseId, command.contentChangeSetId,
            revision, title, command.createdAt,
        ) == 1)
        check(dsl.execute(
            """
            insert into course_release_unit_revision(
                course_release_id, parent_level_revision_id, unit_revision_id,
                unit_id, course_id, position
            ) values (?, ?, ?, ?, ?, ?)
            """.trimIndent(),
            command.draftReleaseId, parentRevisionId, revisionId, unitId,
            command.course.courseId, position,
        ) == 1)
    }

    private fun insertTopicRevision(
        command: FullCourseEditorCommitCommand,
        topicId: UUID,
        revisionId: UUID,
        title: String,
        parentRevisionId: UUID,
        position: Int,
    ) {
        val revision = nextRevision("content_topic_revision", "topic_id", topicId)
        check(dsl.execute(
            """
            insert into content_topic_revision(
                id, topic_id, course_id, content_change_set_id,
                revision_number, title, hidden, created_at
            ) values (?, ?, ?, ?, ?, ?, false, cast(? as timestamptz))
            """.trimIndent(),
            revisionId, topicId, command.course.courseId, command.contentChangeSetId,
            revision, title, command.createdAt,
        ) == 1)
        check(dsl.execute(
            """
            insert into course_release_topic_revision(
                course_release_id, parent_unit_revision_id, topic_revision_id,
                topic_id, course_id, position
            ) values (?, ?, ?, ?, ?, ?)
            """.trimIndent(),
            command.draftReleaseId, parentRevisionId, revisionId, topicId,
            command.course.courseId, position,
        ) == 1)
    }

    private fun insertTestRevision(
        command: FullCourseEditorCommitCommand,
        testId: UUID,
        revisionId: UUID,
        test: CourseEditorTest,
        parentTopicRevisionId: UUID,
        hierarchyPosition: Int,
        globalPosition: Int,
    ) {
        val revision = nextRevision("test_revision", "test_id", testId)
        check(dsl.execute(
            """
            insert into test_revision(
                id, test_id, course_id, revision_number, title,
                status, pass_threshold, created_at
            ) values (?, ?, ?, ?, ?, 'DRAFT', ?, cast(? as timestamptz))
            """.trimIndent(),
            revisionId, testId, command.course.courseId, revision,
            test.title, test.passThreshold, command.createdAt,
        ) == 1)
        check(dsl.execute(
            """
            insert into test_revision_source_change_set(
                test_revision_id, test_id, course_id, content_change_set_id, created_at
            ) values (?, ?, ?, ?, cast(? as timestamptz))
            """.trimIndent(),
            revisionId, testId, command.course.courseId,
            command.contentChangeSetId, command.createdAt,
        ) == 1)
        val mode = resolvedMode(test.questions)
        check(dsl.execute(
            """
            insert into test_revision_authoring(
                test_revision_id, test_id, course_id, content_change_set_id,
                source_test_number, allocation_kind, resolved_mode, hidden, created_at
            ) values (?, ?, ?, ?, ?, 'FIXED', ?, false, cast(? as timestamptz))
            """.trimIndent(),
            revisionId, testId, command.course.courseId, command.contentChangeSetId,
            globalPosition, mode, command.createdAt,
        ) == 1)
        check(dsl.execute(
            """
            insert into course_release_test_revision(
                course_release_id, test_revision_id, test_id, course_id, position
            ) values (?, ?, ?, ?, ?)
            """.trimIndent(),
            command.draftReleaseId, revisionId, testId, command.course.courseId, globalPosition,
        ) == 1)
        check(dsl.execute(
            """
            insert into course_release_test_hierarchy(
                course_release_id, parent_topic_revision_id, test_revision_id,
                test_id, course_id, position
            ) values (?, ?, ?, ?, ?, ?)
            """.trimIndent(),
            command.draftReleaseId, parentTopicRevisionId, revisionId,
            testId, command.course.courseId, hierarchyPosition,
        ) == 1)
    }

    private fun insertQuestionRevision(
        command: FullCourseEditorCommitCommand,
        questionId: UUID,
        questionRevisionId: UUID,
        question: CourseEditorQuestion,
        testRevisionId: UUID,
        position: Int,
        ordinal: Int,
    ) {
        val revision = nextRevision("question_revision", "question_id", questionId)
        val correctOption = question.options.singleOrNull(CourseEditorOption::correct)
        val correctAnswer = when (question.type) {
            "A", "B" -> checkNotNull(correctOption).text
            "C" -> question.correctAnswer
            "D" -> null
            else -> error("Unsupported question type")
        }
        val typedCorrectKey = if (question.type == "C") {
            TypedAnswerPolicy.canonicalize(checkNotNull(question.correctAnswer), command.course.targetLanguage)
        } else {
            null
        }
        val typedAlternativeKey = if (question.type == "C") {
            question.alternativeCorrectAnswer?.let {
                TypedAnswerPolicy.canonicalize(it, command.course.targetLanguage)
            }
        } else {
            null
        }
        check(dsl.execute(
            """
            insert into question_revision(
                id, question_id, course_id, revision_number, question_type,
                prompt, correct_answer, alternative_correct_answer,
                answer_match_policy, answer_match_language,
                correct_answer_match_key, alternative_answer_match_key,
                matching_policy, matching_label_policy, matching_order_policy,
                matching_target_language, status, created_at
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                      'DRAFT', cast(? as timestamptz))
            """.trimIndent(),
            questionRevisionId, questionId, command.course.courseId, revision, question.type,
            question.prompt, correctAnswer, question.alternativeCorrectAnswer,
            if (question.type == "C") TypedAnswerPolicy.VERSION else null,
            if (question.type == "C") command.course.targetLanguage else null,
            typedCorrectKey, typedAlternativeKey,
            if (question.type == "D") "matching-v1" else null,
            if (question.type == "D") MatchingLabelPolicy.VERSION else null,
            if (question.type == "D") "matching-order-v1" else null,
            if (question.type == "D") command.course.targetLanguage else null,
            command.createdAt,
        ) == 1)
        check(dsl.execute(
            """
            insert into question_revision_source_change_set(
                question_revision_id, question_id, course_id,
                content_change_set_id, created_at
            ) values (?, ?, ?, ?, cast(? as timestamptz))
            """.trimIndent(),
            questionRevisionId, questionId, command.course.courseId,
            command.contentChangeSetId, command.createdAt,
        ) == 1)

        if (question.type == "A") {
            question.translations.toSortedMap().forEach { (language, text) ->
                insertQuestionTranslation(command, questionRevisionId, language, text)
            }
        }
        question.options.forEachIndexed { optionIndex, option ->
            val optionId = UUID.randomUUID()
            check(dsl.execute(
                """
                insert into question_revision_option(
                    id, question_revision_id, option_text, is_correct, position
                ) values (?, ?, ?, ?, ?)
                """.trimIndent(),
                optionId, questionRevisionId, option.text, option.correct, optionIndex + 1,
            ) == 1)
            option.translations.toSortedMap().forEach { (language, text) ->
                check(dsl.execute(
                    """
                    insert into question_revision_option_translation(
                        option_id, question_revision_id, course_id,
                        support_language, option_text
                    ) values (?, ?, ?, ?, ?)
                    """.trimIndent(),
                    optionId, questionRevisionId, command.course.courseId, language, text,
                ) == 1)
            }
        }
        if (question.type in setOf("A", "B")) {
            val distractorLanguage = if (question.type == "A") {
                command.course.defaultSupportLanguage
            } else {
                command.course.targetLanguage
            }
            question.options.filterNot(CourseEditorOption::correct).forEachIndexed { index, option ->
                check(dsl.execute(
                    """
                    insert into question_revision_authored_distractor(
                        question_revision_id, course_id, language_code,
                        position, distractor_text, created_at
                    ) values (?, ?, ?, ?, ?, cast(? as timestamptz))
                    """.trimIndent(),
                    questionRevisionId, command.course.courseId, distractorLanguage,
                    index + 1, option.text, command.createdAt,
                ) == 1)
            }
        }
        if (question.type == "D") {
            question.matchingPairs.forEachIndexed { pairIndex, pair ->
                val targetItemId = UUID.randomUUID()
                check(dsl.execute(
                    """
                    insert into question_revision_matching_pair(
                        target_item_id, question_revision_id, course_id,
                        position, target_text, target_label_key
                    ) values (?, ?, ?, ?, ?, ?)
                    """.trimIndent(),
                    targetItemId, questionRevisionId, command.course.courseId,
                    pairIndex + 1, pair.targetText,
                    MatchingLabelPolicy.canonicalize(pair.targetText, command.course.targetLanguage),
                ) == 1)
                pair.translations.toSortedMap().forEach { (language, text) ->
                    check(dsl.execute(
                        """
                        insert into question_revision_matching_translation(
                            support_item_id, question_revision_id, course_id,
                            target_item_id, support_language, support_text,
                            support_label_key
                        ) values (?, ?, ?, ?, ?, ?, ?)
                        """.trimIndent(),
                        UUID.randomUUID(), questionRevisionId, command.course.courseId,
                        targetItemId, language, text,
                        MatchingLabelPolicy.canonicalize(text, language),
                    ) == 1)
                }
            }
        }
        val recordType = when (question.type) {
            "A" -> "WORD"
            "B" -> "MULTIPLE_CHOICE_CLOZE"
            "C" -> "TYPED_CLOZE"
            "D" -> "MATCHING_GROUP"
            else -> error("Unsupported question type")
        }
        val targetText = when (question.type) {
            "A" -> checkNotNull(question.prompt)
            "B", "C" -> checkNotNull(question.correctAnswer)
            "D" -> question.matchingPairs.first().targetText
            else -> error("Unsupported question type")
        }
        check(dsl.execute(
            """
            insert into question_revision_authoring(
                question_revision_id, question_id, course_id, content_change_set_id,
                ordinal, source_sheet_ordinal, source_sheet_name, source_row_number,
                allocation_reason, record_type, target_text, matching_group,
                hidden, note, created_at
            ) values (?, ?, ?, ?, ?, 0, 'Mobile Editor', ?,
                      'FIXED_DECLARATION', ?, ?, ?, false,
                      'full-course-editor-v1', cast(? as timestamptz))
            """.trimIndent(),
            questionRevisionId, questionId, command.course.courseId, command.contentChangeSetId,
            ordinal, ordinal, recordType, targetText,
            if (question.type == "D") "mobile-$questionId" else null,
            command.createdAt,
        ) == 1)
        check(dsl.execute(
            """
            insert into test_revision_question(
                test_revision_id, question_revision_id, question_id, course_id, position
            ) values (?, ?, ?, ?, ?)
            """.trimIndent(),
            testRevisionId, questionRevisionId, questionId, command.course.courseId, position,
        ) == 1)
    }

    private fun insertQuestionTranslation(
        command: FullCourseEditorCommitCommand,
        questionRevisionId: UUID,
        language: String,
        text: String,
    ) {
        check(dsl.execute(
            """
            insert into question_revision_translation(
                question_revision_id, course_id, support_language,
                translation_text, created_at
            ) values (?, ?, ?, ?, cast(? as timestamptz))
            """.trimIndent(),
            questionRevisionId, command.course.courseId, language, text, command.createdAt,
        ) == 1)
    }

    private fun stableId(table: String, requested: UUID?, courseId: UUID, now: OffsetDateTime): UUID {
        if (requested != null) {
            val foundCourse = dsl.fetchOne("select course_id from $table where id = ?", requested)
                ?.get("course_id", UUID::class.java)
            check(foundCourse == courseId) { "Stable content identity does not belong to the course" }
            return requested
        }
        val id = UUID.randomUUID()
        check(
            dsl.execute(
                "insert into $table(id, course_id, created_at) values (?, ?, cast(? as timestamptz))",
                id,
                courseId,
                now,
            ) == 1,
        )
        return id
    }

    private fun nextRevision(table: String, idColumn: String, id: UUID): Int = checkNotNull(
        dsl.fetchOne(
            "select coalesce(max(revision_number), 0) + 1 as revision from $table where $idColumn = ?",
            id,
        ),
    ).get("revision", Int::class.java)!!

    private fun resolvedMode(questions: List<CourseEditorQuestion>): String {
        val types = questions.map(CourseEditorQuestion::type).toSet()
        return if (types.size != 1) {
            "MIXED"
        } else {
            when (types.single()) {
                "A" -> "WORD"
                "B" -> "MULTIPLE_CHOICE_CLOZE"
                "C" -> "TYPED_CLOZE"
                "D" -> "MATCHING"
                else -> "MIXED"
            }
        }
    }

    private data class MutableLevel(
        val id: UUID,
        val title: String,
        val position: Int,
        val units: MutableList<MutableUnit> = mutableListOf(),
    ) {
        fun toDto() = CourseEditorLevel(
            id = id,
            title = title,
            units = units.sortedBy(MutableUnit::position).map(MutableUnit::toDto),
        )
    }

    private data class MutableUnit(
        val id: UUID,
        val title: String,
        val position: Int,
        val topics: MutableList<MutableTopic> = mutableListOf(),
    ) {
        fun toDto() = CourseEditorUnit(
            id = id,
            title = title,
            topics = topics.sortedBy(MutableTopic::position).map(MutableTopic::toDto),
        )
    }

    private data class MutableTopic(
        val id: UUID,
        val title: String,
        val position: Int,
        val tests: MutableList<MutableTest> = mutableListOf(),
    ) {
        fun toDto() = CourseEditorTopic(
            id = id,
            title = title,
            tests = tests.sortedBy(MutableTest::position).map(MutableTest::toDto),
        )
    }

    private data class MutableTest(
        val id: UUID,
        val title: String,
        val passThreshold: BigDecimal,
        val position: Int,
        val questions: MutableList<MutableQuestion> = mutableListOf(),
    ) {
        fun toDto() = CourseEditorTest(
            id = id,
            title = title,
            passThreshold = passThreshold,
            questions = questions.sortedBy(MutableQuestion::position).map(MutableQuestion::toDto),
        )
    }

    private data class MutableQuestion(
        val id: UUID,
        val type: String,
        val prompt: String?,
        val correctAnswer: String?,
        val alternativeCorrectAnswer: String?,
        val position: Int,
        val translations: MutableMap<String, String> = linkedMapOf(),
        val options: MutableList<MutableOption> = mutableListOf(),
        val matchingPairs: MutableList<MutableMatchingPair> = mutableListOf(),
    ) {
        fun toDto() = CourseEditorQuestion(
            id = id,
            type = type,
            prompt = prompt,
            correctAnswer = correctAnswer,
            alternativeCorrectAnswer = alternativeCorrectAnswer,
            translations = translations.toMap(),
            options = options.sortedBy(MutableOption::position).map(MutableOption::toDto),
            matchingPairs = matchingPairs.sortedBy(MutableMatchingPair::position).map(MutableMatchingPair::toDto),
        )
    }

    private data class MutableOption(
        val id: UUID,
        val text: String,
        val correct: Boolean,
        val position: Int,
        val translations: MutableMap<String, String> = linkedMapOf(),
    ) {
        fun toDto() = CourseEditorOption(text = text, correct = correct, translations = translations.toMap())
    }

    private data class MutableMatchingPair(
        val targetText: String,
        val position: Int,
        val translations: MutableMap<String, String> = linkedMapOf(),
    ) {
        fun toDto() = CourseEditorMatchingPair(targetText = targetText, translations = translations.toMap())
    }
}
