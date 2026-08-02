package com.kelimio.api.courseauthoring

import com.kelimio.api.language.TypedAnswerPolicy
import com.kelimio.api.language.MatchingLabelPolicy
import java.text.Normalizer
import java.util.Locale
import java.util.UUID

internal class ImportedCourseDraftPlanner(
    private val newId: () -> UUID = UUID::randomUUID,
) {
    fun plan(command: InitialCourseDraftCommand): ImportedCourseDraftGraph {
        validateSettings(command.settings)
        val orderedRows = command.rows.sortedBy(InitialCourseDraftRow::ordinal)
        rejectUnless(orderedRows.isNotEmpty())
        rejectUnless(orderedRows.map(InitialCourseDraftRow::ordinal) == (1..orderedRows.size).toList())
        rejectUnless(
            orderedRows.map(InitialCourseDraftRow::questionOrdinal).distinct() ==
                (1..command.expectedQuestionCount).toList(),
        )
        rejectUnless(
            orderedRows.map { it.sourceSheetOrdinal to it.sourceRowNumber }.distinct().size == orderedRows.size,
        )

        val courseId = newId()
        val changeSetId = newId()
        val releaseId = newId()
        val levels = linkedMapOf<String, MutableLevel>()

        orderedRows.forEach { row ->
            validateRow(row, command.settings)
            val level = levels.getOrPut(row.level) {
                MutableLevel(newId(), newId(), row.level)
            }
            val unit = level.units.getOrPut(row.unit) {
                MutableUnit(newId(), newId(), row.unit)
            }
            val topic = unit.topics.getOrPut(row.topic) {
                MutableTopic(newId(), newId(), row.topic)
            }
            val test = topic.tests.getOrPut(row.testNumber) {
                MutableTest(
                    id = newId(),
                    revisionId = newId(),
                    number = row.testNumber,
                    allocationKind = row.allocationKind,
                    resolvedMode = row.resolvedMode,
                )
            }
            rejectUnless(test.allocationKind == row.allocationKind && test.resolvedMode == row.resolvedMode)
            test.rowsByQuestionOrdinal.getOrPut(row.questionOrdinal, ::mutableListOf) += row
        }

        val immutableLevels = levels.values.mapIndexed { levelIndex, level ->
            DraftLevel(
                id = level.id,
                revisionId = level.revisionId,
                title = level.title,
                position = levelIndex + 1,
                units = level.units.values.mapIndexed { unitIndex, unit ->
                    DraftUnit(
                        id = unit.id,
                        revisionId = unit.revisionId,
                        title = unit.title,
                        position = unitIndex + 1,
                        topics = unit.topics.values.mapIndexed { topicIndex, topic ->
                            DraftTopic(
                                id = topic.id,
                                revisionId = topic.revisionId,
                                title = topic.title,
                                position = topicIndex + 1,
                                tests = topic.tests.values.mapIndexed { testIndex, test ->
                                    val questions = test.rowsByQuestionOrdinal.values.map { rows ->
                                        question(rows, command.settings)
                                    }
                                    validateTestComposition(test.resolvedMode, questions)
                                    DraftTest(
                                        id = test.id,
                                        revisionId = test.revisionId,
                                        number = test.number,
                                        allocationKind = test.allocationKind,
                                        resolvedMode = test.resolvedMode,
                                        position = testIndex + 1,
                                        questions = questions,
                                    )
                                },
                            )
                        },
                    )
                },
            )
        }
        val graph = ImportedCourseDraftGraph(courseId, changeSetId, releaseId, immutableLevels)
        rejectUnless(graph.levelCount == command.expectedLevelCount)
        rejectUnless(graph.unitCount == command.expectedUnitCount)
        rejectUnless(graph.topicCount == command.expectedTopicCount)
        rejectUnless(graph.testCount == command.expectedTestCount)
        rejectUnless(graph.sourceRowCount == command.rows.size)
        rejectUnless(graph.questionCount == command.expectedQuestionCount)
        rejectUnless(graph.matchingQuestionCount == command.expectedMatchingQuestionCount)
        rejectUnless(graph.requiredClientCapabilities == command.requiredClientCapabilities)
        return graph
    }

    private fun question(
        rows: List<InitialCourseDraftRow>,
        settings: InitialCourseDraftSettings,
    ): DraftQuestion {
        rejectUnless(rows.isNotEmpty())
        val row = rows.first()
        val matching = row.compositionKind == InitialCompositionKind.MATCHING_GROUP
        if (matching) {
            rejectUnless(rows.size in 2..6)
            rejectUnless(rows.all { it.compositionKind == InitialCompositionKind.MATCHING_GROUP })
            rejectUnless(rows.all { it.projectedQuestionType == InitialProjectedQuestionType.D })
            rejectUnless(rows.mapNotNull(InitialCourseDraftRow::groupPosition) == (1..rows.size).toList())
            rejectUnless(rows.mapNotNull(InitialCourseDraftRow::matchingGroup).map { it.groupCollisionKey() }.distinct().size == 1)
        } else {
            rejectUnless(rows.size == 1 && row.groupPosition == null)
        }
        val prompt = when (row.recordType) {
            InitialRecordType.WORD -> row.targetText
            InitialRecordType.MULTIPLE_CHOICE_CLOZE,
            InitialRecordType.TYPED_CLOZE,
            -> checkNotNull(row.sentence)
        }
        val correctAnswer = when {
            matching -> null
            row.recordType == InitialRecordType.WORD -> checkNotNull(row.translations[settings.defaultSupportLanguageCode])
            else -> checkNotNull(row.correctAnswer)
        }
        val typedCorrectKey = if (row.projectedQuestionType == InitialProjectedQuestionType.C) {
            TypedAnswerPolicy.canonicalize(checkNotNull(correctAnswer), settings.targetLanguageCode)
        } else {
            null
        }
        val typedAlternativeKey = row.alternativeCorrectAnswer?.let {
            TypedAnswerPolicy.canonicalize(it, settings.targetLanguageCode)
        }
        val matchingPairs = if (matching) {
            rows.mapIndexed { index, member ->
                val targetItemId = newId()
                DraftMatchingPair(
                    targetItemId = targetItemId,
                    position = index + 1,
                    targetText = member.targetText,
                    targetLabelKey = MatchingLabelPolicy.canonicalize(
                        member.targetText,
                        settings.targetLanguageCode,
                    ),
                    translations = settings.supportLanguageCodes.map { language ->
                        val text = checkNotNull(member.translations[language])
                        DraftMatchingTranslation(
                            supportItemId = newId(),
                            targetItemId = targetItemId,
                            language = language,
                            text = text,
                            labelKey = MatchingLabelPolicy.canonicalize(text, language),
                        )
                    },
                )
            }
        } else {
            emptyList()
        }
        return DraftQuestion(
            id = newId(),
            revisionId = newId(),
            sourceRows = rows,
            questionType = row.projectedQuestionType.name,
            prompt = prompt.takeUnless { matching },
            correctAnswer = correctAnswer,
            correctAnswerMatchKey = typedCorrectKey,
            alternativeAnswerMatchKey = typedAlternativeKey,
            matchingPairs = matchingPairs,
        )
    }

    private fun validateSettings(settings: InitialCourseDraftSettings) {
        rejectUnless(settings.courseName.length in 1..160)
        rejectUnless(settings.targetLanguageName.length in 1..160)
        rejectUnless(settings.supportLanguageCodes.isNotEmpty())
        rejectUnless(settings.supportLanguageCodes.distinct().size == settings.supportLanguageCodes.size)
        rejectUnless(settings.defaultSupportLanguageCode in settings.supportLanguageCodes)
        rejectUnless(settings.targetLanguageCode !in settings.supportLanguageCodes)
        rejectUnless(settings.targetTestSize > 0)
        rejectUnless(settings.minimumLastAutomaticTestSize in 1..settings.targetTestSize)
        rejectUnless(settings.completionThresholdPercent in 50..100)
        rejectUnless(settings.pricingSource == "APPLICATION")
        rejectUnless(settings.maximumTypedAlternativeAnswers == 1)
        rejectUnless(settings.offlineMode == "SCORELESS_PRACTICE")
    }

    private fun validateTestComposition(mode: InitialTestMode, questions: List<DraftQuestion>) {
        rejectUnless(questions.isNotEmpty())
        when (mode) {
            InitialTestMode.MIXED -> Unit
            InitialTestMode.WORD -> rejectUnless(questions.all { it.questionType == "A" })
            InitialTestMode.MATCHING -> rejectUnless(questions.all { it.questionType == "D" })
            InitialTestMode.MULTIPLE_CHOICE_CLOZE -> rejectUnless(questions.all { it.questionType == "B" })
            InitialTestMode.TYPED_CLOZE -> rejectUnless(questions.all { it.questionType == "C" })
        }
    }

    private fun validateRow(row: InitialCourseDraftRow, settings: InitialCourseDraftSettings) {
        rejectUnless(row.ordinal in 1..10_000)
        rejectUnless(row.questionOrdinal in 1..10_000)
        rejectUnless(row.sourceSheetOrdinal in 0..63)
        rejectUnless(row.sourceSheetName.length in 1..31)
        rejectUnless(row.sourceRowNumber in 1..1_048_576)
        rejectUnless(row.level.length in 1..2_000 && row.unit.length in 1..2_000 && row.topic.length in 1..2_000)
        rejectUnless(row.testNumber > 0)
        rejectUnless(!row.hidden)
        rejectUnless(row.targetText.length in 1..2_000)
        rejectUnless(row.matchingGroup == null || row.matchingGroup.length in 1..2_000)
        rejectUnless(row.note == null || row.note.length in 1..2_000)
        rejectUnless(row.wrongAnswers.size <= 3 && row.wrongAnswers.all { it.length in 1..2_000 })
        when (row.compositionKind) {
            InitialCompositionKind.ROW -> {
                rejectUnless(row.groupPosition == null)
                rejectUnless(row.projectedQuestionType == when (row.recordType) {
                    InitialRecordType.WORD -> InitialProjectedQuestionType.A
                    InitialRecordType.MULTIPLE_CHOICE_CLOZE -> InitialProjectedQuestionType.B
                    InitialRecordType.TYPED_CLOZE -> InitialProjectedQuestionType.C
                })
            }
            InitialCompositionKind.MATCHING_GROUP -> {
                rejectUnless(row.recordType == InitialRecordType.WORD)
                rejectUnless(row.projectedQuestionType == InitialProjectedQuestionType.D)
                rejectUnless(row.groupPosition in 1..6)
                rejectUnless(row.matchingGroup != null)
            }
        }
        when (row.recordType) {
            InitialRecordType.WORD -> {
                rejectUnless(row.targetText.length <= 1_000)
                rejectUnless(row.translations.keys == settings.supportLanguageCodes.toSet())
                rejectUnless(row.translations.values.all { it.length in 1..500 })
                rejectUnless(row.wrongAnswers.all { it.length <= 500 })
                rejectUnless(row.sentence == null && row.correctAnswer == null && row.alternativeCorrectAnswer == null)
            }

            InitialRecordType.MULTIPLE_CHOICE_CLOZE -> {
                rejectUnless(row.translations.isEmpty() && row.matchingGroup == null)
                rejectUnless(row.sentence?.length in 1..1_000)
                rejectUnless(row.correctAnswer?.length in 1..500)
                rejectUnless(row.alternativeCorrectAnswer == null)
                rejectUnless(row.wrongAnswers.size == 3 && row.wrongAnswers.all { it.length <= 500 })
            }

            InitialRecordType.TYPED_CLOZE -> {
                rejectUnless(row.translations.isEmpty() && row.matchingGroup == null)
                rejectUnless(row.sentence?.length in 1..1_000)
                rejectUnless(row.correctAnswer?.length in 1..500)
                rejectUnless(row.alternativeCorrectAnswer == null || row.alternativeCorrectAnswer.length <= 500)
                rejectUnless(row.wrongAnswers.isEmpty())
            }
        }
    }

    private fun rejectUnless(condition: Boolean) {
        if (!condition) throw InitialCourseDraftValidationException()
    }

    private data class MutableLevel(
        val id: UUID,
        val revisionId: UUID,
        val title: String,
        val units: LinkedHashMap<String, MutableUnit> = linkedMapOf(),
    )

    private data class MutableUnit(
        val id: UUID,
        val revisionId: UUID,
        val title: String,
        val topics: LinkedHashMap<String, MutableTopic> = linkedMapOf(),
    )

    private data class MutableTopic(
        val id: UUID,
        val revisionId: UUID,
        val title: String,
        val tests: LinkedHashMap<Int, MutableTest> = linkedMapOf(),
    )

    private data class MutableTest(
        val id: UUID,
        val revisionId: UUID,
        val number: Int,
        val allocationKind: InitialAllocationKind,
        val resolvedMode: InitialTestMode,
        val rowsByQuestionOrdinal: LinkedHashMap<Int, MutableList<InitialCourseDraftRow>> = linkedMapOf(),
    )

    private fun String.groupCollisionKey(): String =
        Normalizer.normalize(uppercase(Locale.ROOT).lowercase(Locale.ROOT), Normalizer.Form.NFC)
}

internal data class ImportedCourseDraftGraph(
    val courseId: UUID,
    val changeSetId: UUID,
    val releaseId: UUID,
    val levels: List<DraftLevel>,
) {
    val units: List<DraftUnit> = levels.flatMap(DraftLevel::units)
    val topics: List<DraftTopic> = units.flatMap(DraftUnit::topics)
    val tests: List<DraftTest> = topics.flatMap(DraftTopic::tests)
    val questions: List<DraftQuestion> = tests.flatMap(DraftTest::questions)
    val levelCount: Int = levels.size
    val unitCount: Int = units.size
    val topicCount: Int = topics.size
    val testCount: Int = tests.size
    val sourceRowCount: Int = questions.sumOf { it.sourceRows.size }
    val rowCount: Int = sourceRowCount
    val questionCount: Int = questions.size
    val matchingQuestionCount: Int = questions.count { it.questionType == "D" }
    val requiredClientCapabilities: List<String> =
        if (matchingQuestionCount == 0) emptyList() else listOf("question.matching.v1")
}

internal data class DraftLevel(
    val id: UUID,
    val revisionId: UUID,
    val title: String,
    val position: Int,
    val units: List<DraftUnit>,
)

internal data class DraftUnit(
    val id: UUID,
    val revisionId: UUID,
    val title: String,
    val position: Int,
    val topics: List<DraftTopic>,
)

internal data class DraftTopic(
    val id: UUID,
    val revisionId: UUID,
    val title: String,
    val position: Int,
    val tests: List<DraftTest>,
)

internal data class DraftTest(
    val id: UUID,
    val revisionId: UUID,
    val number: Int,
    val allocationKind: InitialAllocationKind,
    val resolvedMode: InitialTestMode,
    val position: Int,
    val questions: List<DraftQuestion>,
)

internal data class DraftQuestion(
    val id: UUID,
    val revisionId: UUID,
    val sourceRows: List<InitialCourseDraftRow>,
    val questionType: String,
    val prompt: String?,
    val correctAnswer: String?,
    val correctAnswerMatchKey: String?,
    val alternativeAnswerMatchKey: String?,
    val matchingPairs: List<DraftMatchingPair>,
)

internal data class DraftMatchingPair(
    val targetItemId: UUID,
    val position: Int,
    val targetText: String,
    val targetLabelKey: String,
    val translations: List<DraftMatchingTranslation>,
)

internal data class DraftMatchingTranslation(
    val supportItemId: UUID,
    val targetItemId: UUID,
    val language: String,
    val text: String,
    val labelKey: String,
)
