package com.kelimio.api.courseauthoring

import com.kelimio.api.language.TypedAnswerPolicy
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.time.OffsetDateTime
import java.util.UUID

class ImportedCourseDraftPlannerTest {
    @Test
    fun `approved rows become one ordered immutable hierarchy without compiling runtime options`() {
        val planner = ImportedCourseDraftPlanner(newId = sequentialIds())

        val graph = planner.plan(
            command(
                rows = listOf(
                    wordRow(1, level = "A1", unit = "Temel", topic = "Ev", testNumber = 1),
                    typedRow(2, level = "A1", unit = "Temel", topic = "Ev", testNumber = 1),
                    wordRow(3, level = "A1", unit = "Temel", topic = "Günlük", testNumber = 2),
                    wordRow(4, level = "A2", unit = "Seyahat", topic = "Ulaşım", testNumber = 1),
                ),
                expectedLevelCount = 2,
                expectedUnitCount = 2,
                expectedTopicCount = 3,
                expectedTestCount = 3,
            ),
        )

        assertThat(graph.levels.map(DraftLevel::title)).containsExactly("A1", "A2")
        assertThat(graph.levels.map(DraftLevel::position)).containsExactly(1, 2)
        assertThat(graph.levels.first().units.map(DraftUnit::title)).containsExactly("Temel")
        assertThat(graph.levels.first().units.single().topics.map(DraftTopic::title))
            .containsExactly("Ev", "Günlük")
        assertThat(graph.tests.map(DraftTest::number)).containsExactly(1, 2, 1)
        assertThat(graph.tests.map(DraftTest::position)).containsExactly(1, 1, 1)
        assertThat(graph.questions.map { it.sourceRows.single().ordinal }).containsExactly(1, 2, 3, 4)
        assertThat(graph.rowCount).isEqualTo(4)

        val typedQuestion = graph.questions.single { it.questionType == "C" }
        assertThat(typedQuestion.correctAnswerMatchKey)
            .isEqualTo(TypedAnswerPolicy.canonicalize("  İÇERİM  ", "tr"))
        assertThat(typedQuestion.alternativeAnswerMatchKey)
            .isEqualTo(TypedAnswerPolicy.canonicalize("içeri girerim", "tr"))
        assertThat(graph.questions.first { it.questionType == "A" }.correctAnswerMatchKey).isNull()
    }

    @Test
    fun `planner rejects noncontiguous preview ordinals`() {
        val rows = listOf(wordRow(1), wordRow(3, sourceRowNumber = 4))

        assertThatThrownBy {
            ImportedCourseDraftPlanner().plan(command(rows = rows))
        }.isInstanceOf(InitialCourseDraftValidationException::class.java)
    }

    @Test
    fun `planner rejects incomplete word translations and matching runtime mode`() {
        val incomplete = wordRow(1).copy(translations = mapOf("en" to "window"))
        val matching = wordRow(1).copy(resolvedMode = InitialTestMode.MATCHING)

        listOf(incomplete, matching).forEach { row ->
            assertThatThrownBy {
                ImportedCourseDraftPlanner().plan(command(rows = listOf(row)))
            }.isInstanceOf(InitialCourseDraftValidationException::class.java)
        }
    }

    @Test
    fun `planner composes grouped source rows into one complete matching revision`() {
        val rows = listOf(
            wordRow(1).copy(
                resolvedMode = InitialTestMode.MATCHING,
                questionOrdinal = 1,
                projectedQuestionType = InitialProjectedQuestionType.D,
                compositionKind = InitialCompositionKind.MATCHING_GROUP,
                groupPosition = 1,
            ),
            wordRow(2, sourceRowNumber = 3).copy(
                resolvedMode = InitialTestMode.MATCHING,
                questionOrdinal = 1,
                projectedQuestionType = InitialProjectedQuestionType.D,
                compositionKind = InitialCompositionKind.MATCHING_GROUP,
                groupPosition = 2,
            ),
        )

        val graph = ImportedCourseDraftPlanner(newId = sequentialIds()).plan(
            command(rows = rows).copy(
                expectedQuestionCount = 1,
                expectedMatchingQuestionCount = 1,
                requiredClientCapabilities = listOf("question.matching.v1"),
            ),
        )

        assertThat(graph.sourceRowCount).isEqualTo(2)
        assertThat(graph.questionCount).isEqualTo(1)
        assertThat(graph.matchingQuestionCount).isEqualTo(1)
        assertThat(graph.requiredClientCapabilities).containsExactly("question.matching.v1")
        val matching = graph.questions.single()
        assertThat(matching.questionType).isEqualTo("D")
        assertThat(matching.prompt).isNull()
        assertThat(matching.correctAnswer).isNull()
        assertThat(matching.matchingPairs.map(DraftMatchingPair::position)).containsExactly(1, 2)
        assertThat(matching.matchingPairs.map(DraftMatchingPair::targetItemId)).doesNotHaveDuplicates()
        assertThat(matching.matchingPairs.flatMap(DraftMatchingPair::translations).map(DraftMatchingTranslation::supportItemId))
            .doesNotHaveDuplicates()
        assertThat(matching.matchingPairs.flatMap(DraftMatchingPair::translations)).hasSize(6)
    }

    @Test
    fun `planner rejects conflicting metadata inside one authored test`() {
        val rows = listOf(
            wordRow(1),
            wordRow(2, sourceRowNumber = 3).copy(allocationKind = InitialAllocationKind.AUTOMATIC),
        )

        assertThatThrownBy {
            ImportedCourseDraftPlanner().plan(command(rows = rows))
        }.isInstanceOf(InitialCourseDraftValidationException::class.java)
    }

    private fun command(
        rows: List<InitialCourseDraftRow>,
        expectedLevelCount: Int = 1,
        expectedUnitCount: Int = 1,
        expectedTopicCount: Int = 1,
        expectedTestCount: Int = 1,
    ) = InitialCourseDraftCommand(
        ownerUserId = UUID.fromString("00000000-0000-4000-8000-000000000001"),
        sourceImportId = UUID.fromString("00000000-0000-4000-8000-000000000002"),
        sourceSha256 = "a".repeat(64),
        correlationId = "planner-test",
        committedAt = OffsetDateTime.parse("2026-08-02T10:00:00Z"),
        settings = InitialCourseDraftSettings(
            courseName = "Türkçe Temelleri",
            targetLanguageCode = "tr",
            targetLanguageName = "Türkçe",
            supportLanguageCodes = listOf("en", "ar", "fr"),
            defaultSupportLanguageCode = "en",
            defaultTestMode = InitialTestMode.MIXED,
            visibility = InitialCourseVisibility.PUBLIC,
            targetTestSize = 20,
            minimumLastAutomaticTestSize = 10,
            fillFixedTests = true,
            completionThresholdPercent = 50,
            pricingSource = "APPLICATION",
            maximumTypedAlternativeAnswers = 1,
            offlineMode = "SCORELESS_PRACTICE",
        ),
        rows = rows,
        expectedLevelCount = expectedLevelCount,
        expectedUnitCount = expectedUnitCount,
        expectedTopicCount = expectedTopicCount,
        expectedTestCount = expectedTestCount,
    )

    private fun wordRow(
        ordinal: Int,
        level: String = "A1",
        unit: String = "Temel",
        topic: String = "Ev",
        testNumber: Int = 1,
        sourceRowNumber: Int = ordinal + 1,
    ) = InitialCourseDraftRow(
        ordinal = ordinal,
        sourceSheetOrdinal = 1,
        sourceSheetName = "Giriş Seviyesi",
        sourceRowNumber = sourceRowNumber,
        level = level,
        unit = unit,
        topic = topic,
        testNumber = testNumber,
        allocationKind = InitialAllocationKind.FIXED,
        allocationReason = InitialAllocationReason.FIXED_DECLARATION,
        resolvedMode = InitialTestMode.MIXED,
        recordType = InitialRecordType.WORD,
        targetText = "pencere-$ordinal",
        translations = mapOf("en" to "window", "ar" to "نافذة", "fr" to "fenêtre"),
        sentence = null,
        correctAnswer = null,
        alternativeCorrectAnswer = null,
        wrongAnswers = listOf("door", "table", "chair"),
        matchingGroup = "ev",
        hidden = false,
        note = "author note",
    )

    private fun typedRow(
        ordinal: Int,
        level: String,
        unit: String,
        topic: String,
        testNumber: Int,
    ) = InitialCourseDraftRow(
        ordinal = ordinal,
        sourceSheetOrdinal = 1,
        sourceSheetName = "Giriş Seviyesi",
        sourceRowNumber = ordinal + 1,
        level = level,
        unit = unit,
        topic = topic,
        testNumber = testNumber,
        allocationKind = InitialAllocationKind.FIXED,
        allocationReason = InitialAllocationReason.FIXED_DECLARATION,
        resolvedMode = InitialTestMode.MIXED,
        recordType = InitialRecordType.TYPED_CLOZE,
        targetText = "içmek",
        translations = emptyMap(),
        sentence = "Her sabah su ____.",
        correctAnswer = "  İÇERİM  ",
        alternativeCorrectAnswer = "içeri girerim",
        wrongAnswers = emptyList(),
        matchingGroup = null,
        hidden = false,
        note = null,
    )

    private fun sequentialIds(): () -> UUID {
        var value = 10L
        return {
            value += 1
            UUID(0L, value)
        }
    }
}
