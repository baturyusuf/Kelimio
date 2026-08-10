package com.kelimio.api.courseauthoring

import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.math.BigDecimal
import java.sql.PreparedStatement

@Repository
internal class InitialCourseDraftRepository(
    private val dsl: DSLContext,
) {
    fun insert(command: InitialCourseDraftCommand, graph: ImportedCourseDraftGraph) {
        val settings = command.settings
        dsl.execute(
            """
            insert into course(
                id, owner_user_id, name, description, target_language,
                default_support_language, visibility, publication_status,
                access_type, created_at, updated_at, active_release_id
            ) values (?, ?, ?, null, ?, ?, ?, 'DRAFT', 'FREE',
                cast(? as timestamptz), cast(? as timestamptz), null)
            """.trimIndent(),
            graph.courseId,
            command.ownerUserId,
            settings.courseName,
            settings.targetLanguageCode,
            settings.defaultSupportLanguageCode,
            settings.visibility.name,
            command.committedAt,
            command.committedAt,
        )
        batch(
            "insert into course_support_language(course_id, language_code) values (?, ?)",
            settings.supportLanguageCodes,
        ) { statement, language ->
            statement.setObject(1, graph.courseId)
            statement.setString(2, language)
        }
        dsl.execute(
            """
            insert into course_origin(
                course_id, owner_user_id, origin_type, origin_key, source_sha256, created_at
            ) values (?, ?, 'EXCEL_IMPORT', ?, ?, cast(? as timestamptz))
            """.trimIndent(),
            graph.courseId,
            command.ownerUserId,
            command.sourceImportId.toString(),
            command.sourceSha256,
            command.committedAt,
        )
        dsl.execute(
            """
            insert into content_change_set(
                id, course_id, owner_user_id, base_release_id, source_type,
                source_reference_id, status, created_at, committed_at, correlation_id
            ) values (?, ?, ?, null, 'EXCEL_IMPORT', ?, 'COMMITTED',
                cast(? as timestamptz), cast(? as timestamptz), ?)
            """.trimIndent(),
            graph.changeSetId,
            graph.courseId,
            command.ownerUserId,
            command.sourceImportId,
            command.committedAt,
            command.committedAt,
            command.correlationId,
        )
        listOf("CREATED", "COMMITTED").forEach { eventType ->
            dsl.execute(
                """
                insert into content_change_set_event(
                    id, content_change_set_id, event_type, actor_user_id, occurred_at, correlation_id
                ) values (?, ?, ?, ?, cast(? as timestamptz), ?)
                """.trimIndent(),
                java.util.UUID.randomUUID(),
                graph.changeSetId,
                eventType,
                command.ownerUserId,
                command.committedAt,
                command.correlationId,
            )
        }
        dsl.execute(
            """
            insert into course_release(id, course_id, revision_number, status, created_at)
            values (?, ?, 1, 'DRAFT', cast(? as timestamptz))
            """.trimIndent(),
            graph.releaseId,
            graph.courseId,
            command.committedAt,
        )
        dsl.execute(
            """
            insert into course_release_source_change_set(
                course_release_id, course_id, content_change_set_id, created_at
            ) values (?, ?, ?, cast(? as timestamptz))
            """.trimIndent(),
            graph.releaseId,
            graph.courseId,
            graph.changeSetId,
            command.committedAt,
        )
        dsl.execute(
            """
            insert into course_release_metadata(
                course_release_id, course_id, course_name, course_description,
                visibility, created_at
            ) values (?, ?, ?, null, ?, cast(? as timestamptz))
            """.trimIndent(),
            graph.releaseId,
            graph.courseId,
            settings.courseName,
            settings.visibility.name,
            command.committedAt,
        )
        insertSettings(command, graph)
        insertHierarchy(command, graph)
        insertQuestions(command, graph)
    }

    private fun insertSettings(command: InitialCourseDraftCommand, graph: ImportedCourseDraftGraph) {
        val settings = command.settings
        dsl.connection { connection ->
            connection.prepareStatement(
                """
                insert into course_import_draft_settings(
                    course_id, content_change_set_id, course_name, target_language_code,
                    target_language_name, support_language_codes, default_support_language_code,
                    default_test_mode, visibility, target_test_size,
                    minimum_last_automatic_test_size, fill_fixed_tests,
                    completion_threshold_percent, pricing_source,
                    maximum_typed_alternative_answers, offline_mode, created_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """.trimIndent(),
            ).use { statement ->
                statement.setObject(1, graph.courseId)
                statement.setObject(2, graph.changeSetId)
                statement.setString(3, settings.courseName)
                statement.setString(4, settings.targetLanguageCode)
                statement.setString(5, settings.targetLanguageName)
                statement.setArray(
                    6,
                    connection.createArrayOf("varchar", settings.supportLanguageCodes.toTypedArray()),
                )
                statement.setString(7, settings.defaultSupportLanguageCode)
                statement.setString(8, settings.defaultTestMode.name)
                statement.setString(9, settings.visibility.name)
                statement.setInt(10, settings.targetTestSize)
                statement.setInt(11, settings.minimumLastAutomaticTestSize)
                statement.setBoolean(12, settings.fillFixedTests)
                statement.setInt(13, settings.completionThresholdPercent)
                statement.setString(14, settings.pricingSource)
                statement.setInt(15, settings.maximumTypedAlternativeAnswers)
                statement.setString(16, settings.offlineMode)
                statement.setObject(17, command.committedAt)
                check(statement.executeUpdate() == 1)
            }
        }
    }

    private fun insertHierarchy(command: InitialCourseDraftCommand, graph: ImportedCourseDraftGraph) {
        batch(
            "insert into content_level(id, course_id, created_at) values (?, ?, ?)",
            graph.levels,
        ) { statement, level ->
            statement.setObject(1, level.id)
            statement.setObject(2, graph.courseId)
            statement.setObject(3, command.committedAt)
        }
        batch(
            """
            insert into content_level_revision(
                id, level_id, course_id, content_change_set_id, revision_number, title, hidden, created_at
            ) values (?, ?, ?, ?, 1, ?, false, ?)
            """.trimIndent(),
            graph.levels,
        ) { statement, level ->
            statement.setObject(1, level.revisionId)
            statement.setObject(2, level.id)
            statement.setObject(3, graph.courseId)
            statement.setObject(4, graph.changeSetId)
            statement.setString(5, level.title)
            statement.setObject(6, command.committedAt)
        }
        batch(
            """
            insert into course_release_level_revision(
                course_release_id, level_revision_id, level_id, course_id, position
            ) values (?, ?, ?, ?, ?)
            """.trimIndent(),
            graph.levels,
        ) { statement, level ->
            statement.setObject(1, graph.releaseId)
            statement.setObject(2, level.revisionId)
            statement.setObject(3, level.id)
            statement.setObject(4, graph.courseId)
            statement.setInt(5, level.position)
        }

        graph.levels.forEach { level ->
            batch(
                "insert into content_unit(id, course_id, created_at) values (?, ?, ?)",
                level.units,
            ) { statement, unit ->
                statement.setObject(1, unit.id)
                statement.setObject(2, graph.courseId)
                statement.setObject(3, command.committedAt)
            }
            batch(
                """
                insert into content_unit_revision(
                    id, unit_id, course_id, content_change_set_id, revision_number, title, hidden, created_at
                ) values (?, ?, ?, ?, 1, ?, false, ?)
                """.trimIndent(),
                level.units,
            ) { statement, unit ->
                statement.setObject(1, unit.revisionId)
                statement.setObject(2, unit.id)
                statement.setObject(3, graph.courseId)
                statement.setObject(4, graph.changeSetId)
                statement.setString(5, unit.title)
                statement.setObject(6, command.committedAt)
            }
            batch(
                """
                insert into course_release_unit_revision(
                    course_release_id, parent_level_revision_id, unit_revision_id,
                    unit_id, course_id, position
                ) values (?, ?, ?, ?, ?, ?)
                """.trimIndent(),
                level.units,
            ) { statement, unit ->
                statement.setObject(1, graph.releaseId)
                statement.setObject(2, level.revisionId)
                statement.setObject(3, unit.revisionId)
                statement.setObject(4, unit.id)
                statement.setObject(5, graph.courseId)
                statement.setInt(6, unit.position)
            }

            level.units.forEach { unit ->
                batch(
                    "insert into content_topic(id, course_id, created_at) values (?, ?, ?)",
                    unit.topics,
                ) { statement, topic ->
                    statement.setObject(1, topic.id)
                    statement.setObject(2, graph.courseId)
                    statement.setObject(3, command.committedAt)
                }
                batch(
                    """
                    insert into content_topic_revision(
                        id, topic_id, course_id, content_change_set_id, revision_number, title, hidden, created_at
                    ) values (?, ?, ?, ?, 1, ?, false, ?)
                    """.trimIndent(),
                    unit.topics,
                ) { statement, topic ->
                    statement.setObject(1, topic.revisionId)
                    statement.setObject(2, topic.id)
                    statement.setObject(3, graph.courseId)
                    statement.setObject(4, graph.changeSetId)
                    statement.setString(5, topic.title)
                    statement.setObject(6, command.committedAt)
                }
                batch(
                    """
                    insert into course_release_topic_revision(
                        course_release_id, parent_unit_revision_id, topic_revision_id,
                        topic_id, course_id, position
                    ) values (?, ?, ?, ?, ?, ?)
                    """.trimIndent(),
                    unit.topics,
                ) { statement, topic ->
                    statement.setObject(1, graph.releaseId)
                    statement.setObject(2, unit.revisionId)
                    statement.setObject(3, topic.revisionId)
                    statement.setObject(4, topic.id)
                    statement.setObject(5, graph.courseId)
                    statement.setInt(6, topic.position)
                }
            }
        }

        var releaseTestPosition = 0
        graph.levels.forEach { level ->
            level.units.forEach { unit ->
                unit.topics.forEach { topic ->
                    topic.tests.forEach { test ->
                        releaseTestPosition += 1
                        dsl.execute(
                            "insert into course_test(id, course_id, created_at) values (?, ?, cast(? as timestamptz))",
                            test.id,
                            graph.courseId,
                            command.committedAt,
                        )
                        dsl.execute(
                            """
                            insert into test_revision(
                                id, test_id, course_id, revision_number, title, status,
                                pass_threshold, created_at
                            ) values (?, ?, ?, 1, ?, 'DRAFT', ?, cast(? as timestamptz))
                            """.trimIndent(),
                            test.revisionId,
                            test.id,
                            graph.courseId,
                            "Test ${test.number}",
                            BigDecimal.valueOf(command.settings.completionThresholdPercent.toLong(), 2),
                            command.committedAt,
                        )
                        dsl.execute(
                            """
                            insert into test_revision_authoring(
                                test_revision_id, test_id, course_id, content_change_set_id,
                                source_test_number, allocation_kind, resolved_mode, hidden, created_at
                            ) values (?, ?, ?, ?, ?, ?, ?, false, cast(? as timestamptz))
                            """.trimIndent(),
                            test.revisionId,
                            test.id,
                            graph.courseId,
                            graph.changeSetId,
                            test.number,
                            test.allocationKind.name,
                            test.resolvedMode.name,
                            command.committedAt,
                        )
                        dsl.execute(
                            """
                            insert into test_revision_source_change_set(
                                test_revision_id, test_id, course_id,
                                content_change_set_id, created_at
                            ) values (?, ?, ?, ?, cast(? as timestamptz))
                            """.trimIndent(),
                            test.revisionId,
                            test.id,
                            graph.courseId,
                            graph.changeSetId,
                            command.committedAt,
                        )
                        dsl.execute(
                            """
                            insert into course_release_test_revision(
                                course_release_id, test_revision_id, test_id, course_id, position
                            ) values (?, ?, ?, ?, ?)
                            """.trimIndent(),
                            graph.releaseId,
                            test.revisionId,
                            test.id,
                            graph.courseId,
                            releaseTestPosition,
                        )
                        dsl.execute(
                            """
                            insert into course_release_test_hierarchy(
                                course_release_id, parent_topic_revision_id, test_revision_id,
                                test_id, course_id, position
                            ) values (?, ?, ?, ?, ?, ?)
                            """.trimIndent(),
                            graph.releaseId,
                            topic.revisionId,
                            test.revisionId,
                            test.id,
                            graph.courseId,
                            test.position,
                        )
                    }
                }
            }
        }
    }

    private fun insertQuestions(command: InitialCourseDraftCommand, graph: ImportedCourseDraftGraph) {
        graph.tests.forEach { test ->
            test.questions.forEachIndexed { index, question ->
                val representative = question.sourceRows.first()
                val matching = question.questionType == "D"
                dsl.execute(
                    "insert into question(id, course_id, created_at) values (?, ?, cast(? as timestamptz))",
                    question.id,
                    graph.courseId,
                    command.committedAt,
                )
                dsl.execute(
                    """
                    insert into question_revision(
                        id, question_id, course_id, revision_number, question_type,
                        prompt, correct_answer, alternative_correct_answer,
                        answer_match_policy, answer_match_language,
                        correct_answer_match_key, alternative_answer_match_key,
                        matching_policy, matching_label_policy, matching_order_policy,
                        matching_target_language,
                        status, created_at
                    ) values (?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                        'DRAFT', cast(? as timestamptz))
                    """.trimIndent(),
                    question.revisionId,
                    question.id,
                    graph.courseId,
                    question.questionType,
                    question.prompt,
                    question.correctAnswer,
                    if (matching) null else representative.alternativeCorrectAnswer,
                    if (question.questionType == "C") TYPED_ANSWER_POLICY_VERSION else null,
                    if (question.questionType == "C") command.settings.targetLanguageCode else null,
                    question.correctAnswerMatchKey,
                    question.alternativeAnswerMatchKey,
                    if (matching) MATCHING_POLICY_VERSION else null,
                    if (matching) MATCHING_LABEL_POLICY_VERSION else null,
                    if (matching) MATCHING_ORDER_POLICY_VERSION else null,
                    if (matching) command.settings.targetLanguageCode else null,
                    command.committedAt,
                )
                question.options.forEach { option ->
                    dsl.execute(
                        """
                        insert into question_revision_option(
                            id, question_revision_id, option_text, is_correct, position
                        ) values (?, ?, ?, ?, ?)
                        """.trimIndent(),
                        option.id,
                        question.revisionId,
                        option.text,
                        option.correct,
                        option.position,
                    )
                    option.translations.forEach { (language, text) ->
                        dsl.execute(
                            """
                            insert into question_revision_option_translation(
                                option_id, question_revision_id, course_id,
                                support_language, option_text
                            ) values (?, ?, ?, ?, ?)
                            """.trimIndent(),
                            option.id,
                            question.revisionId,
                            graph.courseId,
                            language,
                            text,
                        )
                    }
                }
                dsl.execute(
                    """
                    insert into question_revision_authoring(
                        question_revision_id, question_id, course_id, content_change_set_id,
                        ordinal, source_sheet_ordinal, source_sheet_name, source_row_number,
                        allocation_reason, record_type, target_text, matching_group,
                        hidden, note, created_at
                    ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, cast(? as timestamptz))
                    """.trimIndent(),
                    question.revisionId,
                    question.id,
                    graph.courseId,
                    graph.changeSetId,
                    representative.questionOrdinal,
                    representative.sourceSheetOrdinal,
                    representative.sourceSheetName,
                    representative.sourceRowNumber,
                    representative.allocationReason.name,
                    if (matching) "MATCHING_GROUP" else representative.recordType.name,
                    representative.targetText,
                    representative.matchingGroup,
                    representative.hidden,
                    representative.note,
                    command.committedAt,
                )
                dsl.execute(
                    """
                    insert into question_revision_source_change_set(
                        question_revision_id, question_id, course_id,
                        content_change_set_id, created_at
                    ) values (?, ?, ?, ?, cast(? as timestamptz))
                    """.trimIndent(),
                    question.revisionId,
                    question.id,
                    graph.courseId,
                    graph.changeSetId,
                    command.committedAt,
                )
                if (matching) {
                    question.matchingPairs.forEach { pair ->
                        dsl.execute(
                            """
                            insert into question_revision_matching_pair(
                                target_item_id, question_revision_id, course_id,
                                position, target_text, target_label_key
                            ) values (?, ?, ?, ?, ?, ?)
                            """.trimIndent(),
                            pair.targetItemId,
                            question.revisionId,
                            graph.courseId,
                            pair.position,
                            pair.targetText,
                            pair.targetLabelKey,
                        )
                        pair.translations.forEach { translation ->
                            dsl.execute(
                                """
                                insert into question_revision_matching_translation(
                                    support_item_id, question_revision_id, course_id,
                                    target_item_id, support_language, support_text,
                                    support_label_key
                                ) values (?, ?, ?, ?, ?, ?, ?)
                                """.trimIndent(),
                                translation.supportItemId,
                                question.revisionId,
                                graph.courseId,
                                translation.targetItemId,
                                translation.language,
                                translation.text,
                                translation.labelKey,
                            )
                        }
                    }
                } else {
                    representative.translations.forEach { (language, translation) ->
                        dsl.execute(
                            """
                            insert into question_revision_translation(
                                question_revision_id, course_id, support_language,
                                translation_text, created_at
                            ) values (?, ?, ?, ?, cast(? as timestamptz))
                            """.trimIndent(),
                            question.revisionId,
                            graph.courseId,
                            language,
                            translation,
                            command.committedAt,
                        )
                    }
                    val distractorLanguage = when (representative.recordType) {
                        InitialRecordType.WORD -> command.settings.defaultSupportLanguageCode
                        InitialRecordType.MULTIPLE_CHOICE_CLOZE -> command.settings.targetLanguageCode
                        InitialRecordType.TYPED_CLOZE -> null
                    }
                    representative.wrongAnswers.forEachIndexed { distractorIndex, distractor ->
                        dsl.execute(
                            """
                            insert into question_revision_authored_distractor(
                                question_revision_id, course_id, language_code,
                                position, distractor_text, created_at
                            ) values (?, ?, ?, ?, ?, cast(? as timestamptz))
                            """.trimIndent(),
                            question.revisionId,
                            graph.courseId,
                            checkNotNull(distractorLanguage),
                            distractorIndex + 1,
                            distractor,
                            command.committedAt,
                        )
                    }
                }
                dsl.execute(
                    """
                    insert into question_revision_import_composition(
                        question_revision_id, course_id, content_change_set_id,
                        import_id, composition_kind, source_row_count,
                        first_source_ordinal, created_at
                    ) values (?, ?, ?, ?, ?, ?, ?, cast(? as timestamptz))
                    """.trimIndent(),
                    question.revisionId,
                    graph.courseId,
                    graph.changeSetId,
                    command.sourceImportId,
                    if (matching) "MATCHING_GROUP" else "ROW",
                    question.sourceRows.size,
                    representative.ordinal,
                    command.committedAt,
                )
                question.sourceRows.forEachIndexed { sourceIndex, sourceRow ->
                    dsl.execute(
                        """
                        insert into question_revision_import_source(
                            question_revision_id, course_id, import_id,
                            source_ordinal, position
                        ) values (?, ?, ?, ?, ?)
                        """.trimIndent(),
                        question.revisionId,
                        graph.courseId,
                        command.sourceImportId,
                        sourceRow.ordinal,
                        sourceIndex + 1,
                    )
                }
                dsl.execute(
                    """
                    insert into test_revision_question(
                        test_revision_id, question_revision_id, question_id, course_id, position
                    ) values (?, ?, ?, ?, ?)
                    """.trimIndent(),
                    test.revisionId,
                    question.revisionId,
                    question.id,
                    graph.courseId,
                    index + 1,
                )
            }
        }
    }

    private fun <T> batch(sql: String, rows: List<T>, bind: (PreparedStatement, T) -> Unit) {
        if (rows.isEmpty()) return
        dsl.connection { connection ->
            connection.prepareStatement(sql).use { statement ->
                rows.forEachIndexed { index, row ->
                    bind(statement, row)
                    statement.addBatch()
                    if ((index + 1) % BATCH_SIZE == 0) statement.executeBatch()
                }
                if (rows.size % BATCH_SIZE != 0) statement.executeBatch()
            }
        }
    }

    private companion object {
        const val BATCH_SIZE = 250
        const val TYPED_ANSWER_POLICY_VERSION = "typed-answer-v1"
        const val MATCHING_POLICY_VERSION = "matching-v1"
        const val MATCHING_LABEL_POLICY_VERSION = "matching-label-v1"
        const val MATCHING_ORDER_POLICY_VERSION = "matching-order-v1"
    }
}
