package com.kelimio.api.courseeditor

import com.kelimio.api.web.UnprocessableProblem
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.math.BigDecimal
import java.util.UUID

class FullCourseEditorValidatorTest {
    @Test
    fun `normalizes and accepts a complete four-type course tree`() {
        val current = document()
        val normalized = FullCourseEditorValidator.normalizeAndValidate(
            request = request(current),
            course = course(current),
            current = current,
        )

        assertThat(normalized.name).isEqualTo("Kelimio Test Kursu")
        assertThat(
            normalized.levels.single().units.single().topics.single().tests.single().questions
                .map(CourseEditorQuestion::type),
        ).containsExactly("A", "B", "C", "D")
    }

    @Test
    fun `rejects a stale stable identity`() {
        val current = document()
        val request = request(current).copy(
            levels = request(current).levels.map { it.copy(id = UUID.randomUUID()) },
        )

        assertThatThrownBy {
            FullCourseEditorValidator.normalizeAndValidate(request, course(current), current)
        }.isInstanceOf(UnprocessableProblem::class.java)
            .hasMessageContaining("stale")
    }

    @Test
    fun `rejects a client graded matching question`() {
        val current = document()
        val base = request(current)
        val test = base.levels.single().units.single().topics.single().tests.single()
        val changed = test.questions.map { question ->
            if (question.type == "D") question.copy(correctAnswer = "client-owned") else question
        }
        val request = base.copy(
            levels = base.levels.map { level ->
                level.copy(units = level.units.map { unit ->
                    unit.copy(topics = unit.topics.map { topic ->
                        topic.copy(tests = topic.tests.map { it.copy(questions = changed) })
                    })
                })
            },
        )

        assertThatThrownBy {
            FullCourseEditorValidator.normalizeAndValidate(request, course(current), current)
        }.isInstanceOf(UnprocessableProblem::class.java)
            .hasMessageContaining("Type D stores no prompt")
    }

    @Test
    fun `entity tag changes with release revision`() {
        val courseId = UUID.randomUUID()
        val releaseId = UUID.randomUUID()

        assertThat(FullCourseEditorEntityTag.from(courseId, releaseId, 1))
            .isNotEqualTo(FullCourseEditorEntityTag.from(courseId, releaseId, 2))
    }

    @Test
    fun `editor answer material is redacted from diagnostics`() {
        val question = questions().first()

        assertThat(question.toString())
            .contains("[REDACTED]")
            .doesNotContain("elma", "apple", "تفاحة")
        assertThat(question.options.first().toString())
            .contains("[REDACTED]")
            .doesNotContain("apple")
        assertThat(questions().last().matchingPairs.first().toString())
            .contains("[REDACTED]")
            .doesNotContain("elma", "apple")
    }

    private fun document(): FullCourseEditorDocument {
        val levelId = UUID.randomUUID()
        val unitId = UUID.randomUUID()
        val topicId = UUID.randomUUID()
        val testId = UUID.randomUUID()
        val questions = questions().map { it.copy(id = UUID.randomUUID()) }
        return FullCourseEditorDocument(
            courseId = UUID.randomUUID(),
            activeReleaseId = UUID.randomUUID(),
            releaseRevision = 1,
            name = "Kelimio Test Kursu",
            description = "Dört soru tipi",
            visibility = "PRIVATE",
            targetLanguage = "tr",
            defaultSupportLanguage = "en",
            supportLanguages = listOf("ar", "en"),
            levels = listOf(
                CourseEditorLevel(
                    id = levelId,
                    title = "A1",
                    units = listOf(
                        CourseEditorUnit(
                            id = unitId,
                            title = "Başlangıç",
                            topics = listOf(
                                CourseEditorTopic(
                                    id = topicId,
                                    title = "Günlük Hayat",
                                    tests = listOf(
                                        CourseEditorTest(
                                            id = testId,
                                            title = "Test 1",
                                            passThreshold = BigDecimal("0.50"),
                                            questions = questions,
                                        ),
                                    ),
                                ),
                            ),
                        ),
                    ),
                ),
            ),
        )
    }

    private fun course(document: FullCourseEditorDocument) = FullCourseEditorCourseState(
        courseId = document.courseId,
        ownerUserId = UUID.randomUUID(),
        activeReleaseId = document.activeReleaseId,
        releaseRevision = document.releaseRevision,
        publicationStatus = "PUBLISHED",
        name = document.name,
        description = document.description,
        visibility = document.visibility,
        targetLanguage = document.targetLanguage,
        defaultSupportLanguage = document.defaultSupportLanguage,
        supportLanguages = document.supportLanguages,
    )

    private fun request(document: FullCourseEditorDocument) = SaveFullCourseEditorDraftRequest(
        baseReleaseId = document.activeReleaseId,
        name = "  Kelimio Test Kursu  ",
        description = "Dört soru tipi",
        visibility = "private",
        levels = document.levels,
    )

    private fun questions() = listOf(
        CourseEditorQuestion(
            id = null,
            type = "A",
            prompt = "elma",
            correctAnswer = "apple",
            alternativeCorrectAnswer = null,
            translations = mapOf("ar" to "تفاحة", "en" to "apple"),
            options = listOf(
                option("apple", true, "تفاحة"),
                option("door", false, "باب"),
                option("table", false, "طاولة"),
                option("chair", false, "كرسي"),
            ),
        ),
        CourseEditorQuestion(
            id = null,
            type = "B",
            prompt = "Bugün --- yedim.",
            correctAnswer = "elma",
            alternativeCorrectAnswer = null,
            options = listOf(
                CourseEditorOption("elma", true),
                CourseEditorOption("kapı", false),
                CourseEditorOption("masa", false),
                CourseEditorOption("sandalye", false),
            ),
        ),
        CourseEditorQuestion(
            id = null,
            type = "C",
            prompt = "Bugün --- yedim.",
            correctAnswer = "elma",
            alternativeCorrectAnswer = "bir elma",
        ),
        CourseEditorQuestion(
            id = null,
            type = "D",
            prompt = null,
            correctAnswer = null,
            alternativeCorrectAnswer = null,
            matchingPairs = listOf(
                pair("elma", "تفاحة", "apple"),
                pair("kapı", "باب", "door"),
            ),
        ),
    )

    private fun option(text: String, correct: Boolean, arabic: String) = CourseEditorOption(
        text = text,
        correct = correct,
        translations = mapOf("ar" to arabic, "en" to text),
    )

    private fun pair(target: String, arabic: String, english: String) = CourseEditorMatchingPair(
        targetText = target,
        translations = mapOf("ar" to arabic, "en" to english),
    )
}
