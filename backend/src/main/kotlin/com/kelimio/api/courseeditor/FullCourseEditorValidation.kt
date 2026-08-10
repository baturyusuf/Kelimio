package com.kelimio.api.courseeditor

import com.kelimio.api.language.MatchingLabelPolicy
import com.kelimio.api.language.TypedAnswerPolicy
import com.kelimio.api.web.UnprocessableProblem
import java.text.Normalizer
import java.util.Locale
import java.util.UUID

internal object FullCourseEditorValidator {
    fun normalizeAndValidate(
        request: SaveFullCourseEditorDraftRequest,
        course: FullCourseEditorCourseState,
        current: FullCourseEditorDocument,
    ): SaveFullCourseEditorDraftRequest {
        val normalized = request.copy(
            name = text(request.name, 160, "Course name"),
            description = optionalText(request.description, 2_000, "Course description"),
            visibility = request.visibility.trim().uppercase(Locale.ROOT),
            levels = request.levels.map(::normalizeLevel),
        )
        reject(normalized.baseReleaseId != course.activeReleaseId, "The active release changed before editing.")
        reject(normalized.visibility !in setOf("PUBLIC", "PRIVATE"), "Visibility must be PUBLIC or PRIVATE.")
        validateStableIds(normalized, current)
        validateTree(normalized, course)
        return normalized
    }

    private fun normalizeLevel(value: CourseEditorLevel) = value.copy(
        title = text(value.title, 2_000, "Level title"),
        units = value.units.map(::normalizeUnit),
    )

    private fun normalizeUnit(value: CourseEditorUnit) = value.copy(
        title = text(value.title, 2_000, "Unit title"),
        topics = value.topics.map(::normalizeTopic),
    )

    private fun normalizeTopic(value: CourseEditorTopic) = value.copy(
        title = text(value.title, 2_000, "Topic title"),
        tests = value.tests.map(::normalizeTest),
    )

    private fun normalizeTest(value: CourseEditorTest) = value.copy(
        title = text(value.title, 160, "Test title"),
        questions = value.questions.map(::normalizeQuestion),
    )

    private fun normalizeQuestion(value: CourseEditorQuestion) = value.copy(
        type = value.type.trim().uppercase(Locale.ROOT),
        prompt = optionalText(value.prompt, 1_000, "Question prompt"),
        correctAnswer = optionalText(value.correctAnswer, 500, "Correct answer"),
        alternativeCorrectAnswer = optionalText(
            value.alternativeCorrectAnswer,
            500,
            "Alternative correct answer",
        ),
        translations = normalizeMap(value.translations, 500, "Question translation"),
        options = value.options.map { option ->
            option.copy(
                text = text(option.text, 500, "Option text"),
                translations = normalizeMap(option.translations, 500, "Option translation"),
            )
        },
        matchingPairs = value.matchingPairs.map { pair ->
            pair.copy(
                targetText = text(pair.targetText, 500, "Matching target"),
                translations = normalizeMap(pair.translations, 500, "Matching translation"),
            )
        },
    )

    private fun validateStableIds(
        request: SaveFullCourseEditorDraftRequest,
        current: FullCourseEditorDocument,
    ) {
        val currentLevels = current.levels.mapNotNull(CourseEditorLevel::id).toSet()
        val currentUnits = current.levels.flatMap(CourseEditorLevel::units)
            .mapNotNull(CourseEditorUnit::id).toSet()
        val currentTopics = current.levels.flatMap(CourseEditorLevel::units)
            .flatMap(CourseEditorUnit::topics).mapNotNull(CourseEditorTopic::id).toSet()
        val currentTests = current.levels.flatMap(CourseEditorLevel::units)
            .flatMap(CourseEditorUnit::topics).flatMap(CourseEditorTopic::tests)
            .mapNotNull(CourseEditorTest::id).toSet()
        val currentQuestions = current.levels.flatMap(CourseEditorLevel::units)
            .flatMap(CourseEditorUnit::topics).flatMap(CourseEditorTopic::tests)
            .flatMap(CourseEditorTest::questions).mapNotNull(CourseEditorQuestion::id).toSet()

        checkIds("level", request.levels.mapNotNull(CourseEditorLevel::id), currentLevels)
        val units = request.levels.flatMap(CourseEditorLevel::units)
        checkIds("unit", units.mapNotNull(CourseEditorUnit::id), currentUnits)
        val topics = units.flatMap(CourseEditorUnit::topics)
        checkIds("topic", topics.mapNotNull(CourseEditorTopic::id), currentTopics)
        val tests = topics.flatMap(CourseEditorTopic::tests)
        checkIds("test", tests.mapNotNull(CourseEditorTest::id), currentTests)
        checkIds(
            "question",
            tests.flatMap(CourseEditorTest::questions).mapNotNull(CourseEditorQuestion::id),
            currentQuestions,
        )
    }

    private fun checkIds(label: String, ids: List<UUID>, currentIds: Set<UUID>) {
        reject(ids.distinct().size != ids.size, "A $label identifier is used more than once.")
        reject(ids.any { it !in currentIds }, "A stale or unrelated $label identifier was supplied.")
    }

    private fun validateTree(request: SaveFullCourseEditorDraftRequest, course: FullCourseEditorCourseState) {
        reject(request.levels.isEmpty() || request.levels.size > 100, "A course requires 1 to 100 levels.")
        uniqueTitles(request.levels.map(CourseEditorLevel::title), "level")
        var unitCount = 0
        var topicCount = 0
        var testCount = 0
        var questionCount = 0
        request.levels.forEach { level ->
            reject(level.units.isEmpty() || level.units.size > 100, "Each level requires 1 to 100 units.")
            uniqueTitles(level.units.map(CourseEditorUnit::title), "unit")
            level.units.forEach { unit ->
                unitCount += 1
                reject(unit.topics.isEmpty() || unit.topics.size > 100, "Each unit requires 1 to 100 topics.")
                uniqueTitles(unit.topics.map(CourseEditorTopic::title), "topic")
                unit.topics.forEach { topic ->
                    topicCount += 1
                    reject(topic.tests.isEmpty() || topic.tests.size > 100, "Each topic requires 1 to 100 tests.")
                    uniqueTitles(topic.tests.map(CourseEditorTest::title), "test")
                    topic.tests.forEach { test ->
                        testCount += 1
                        reject(test.passThreshold < MIN_PASS_THRESHOLD || test.passThreshold > MAX_PASS_THRESHOLD) {
                            "Test pass threshold must be between 0.50 and 1.00."
                        }
                        reject(test.questions.isEmpty() || test.questions.size > 500) {
                            "Each test requires 1 to 500 questions."
                        }
                        test.questions.forEach { question ->
                            questionCount += 1
                            validateQuestion(question, course)
                        }
                    }
                }
            }
        }
        reject(unitCount > 500, "A course may contain at most 500 units.")
        reject(topicCount > 2_000, "A course may contain at most 2,000 topics.")
        reject(testCount > 5_000, "A course may contain at most 5,000 tests.")
        reject(questionCount > 10_000, "A course may contain at most 10,000 questions.")
    }

    private fun validateQuestion(question: CourseEditorQuestion, course: FullCourseEditorCourseState) {
        val supportLanguages = course.supportLanguages.toSet()
        when (question.type) {
            "A" -> {
                reject(question.prompt == null, "Type A requires a target-language word.")
                reject(question.correctAnswer == null, "Type A requires a correct support-language answer.")
                reject(question.alternativeCorrectAnswer != null, "Type A cannot have an alternative typed answer.")
                reject(question.matchingPairs.isNotEmpty(), "Type A cannot contain matching pairs.")
                requireExactLanguages(question.translations, supportLanguages, "Type A question translations")
                validateOptions(question, course, requireTranslations = true)
                val correct = question.options.single(CourseEditorOption::correct)
                reject(correct.text != question.correctAnswer) {
                    "Type A correctAnswer must equal the correct option in the default support language."
                }
                reject(correct.translations != question.translations) {
                    "Type A question translations must equal the correct option translations."
                }
            }

            "B" -> {
                requireCloze(question.prompt, "Type B")
                reject(question.correctAnswer == null, "Type B requires a correct answer.")
                reject(question.alternativeCorrectAnswer != null, "Type B cannot have an alternative typed answer.")
                reject(question.translations.isNotEmpty(), "Type B cannot contain question translations.")
                reject(question.matchingPairs.isNotEmpty(), "Type B cannot contain matching pairs.")
                validateOptions(question, course, requireTranslations = false)
                reject(question.options.single(CourseEditorOption::correct).text != question.correctAnswer) {
                    "Type B correctAnswer must equal the correct option."
                }
            }

            "C" -> {
                requireCloze(question.prompt, "Type C")
                val correct = question.correctAnswer
                    ?: throw UnprocessableProblem("Type C requires a correct answer.")
                reject(question.translations.isNotEmpty(), "Type C cannot contain question translations.")
                reject(question.options.isNotEmpty(), "Type C cannot contain options.")
                reject(question.matchingPairs.isNotEmpty(), "Type C cannot contain matching pairs.")
                val correctKey = typedKey(correct, course.targetLanguage)
                question.alternativeCorrectAnswer?.let { alternative ->
                    reject(typedKey(alternative, course.targetLanguage) == correctKey) {
                        "Type C alternative answer must differ from the primary answer."
                    }
                }
            }

            "D" -> {
                reject(question.prompt != null || question.correctAnswer != null ||
                    question.alternativeCorrectAnswer != null) {
                    "Type D stores no prompt or typed correct answer."
                }
                reject(question.translations.isNotEmpty(), "Type D cannot contain question translations.")
                reject(question.options.isNotEmpty(), "Type D cannot contain options.")
                reject(question.matchingPairs.size !in 2..6, "Type D requires 2 to 6 complete pairs.")
                val targetKeys = mutableSetOf<String>()
                val supportKeys = course.supportLanguages.associateWith { mutableSetOf<String>() }
                question.matchingPairs.forEach { pair ->
                    requireExactLanguages(pair.translations, supportLanguages, "Type D pair translations")
                    reject(!targetKeys.add(matchingKey(pair.targetText, course.targetLanguage))) {
                        "Type D target labels must be unique."
                    }
                    pair.translations.forEach { (language, value) ->
                        reject(!supportKeys.getValue(language).add(matchingKey(value, language))) {
                            "Type D support labels must be unique within each language."
                        }
                    }
                }
            }

            else -> throw UnprocessableProblem("Question type must be A, B, C or D.")
        }
    }

    private fun validateOptions(
        question: CourseEditorQuestion,
        course: FullCourseEditorCourseState,
        requireTranslations: Boolean,
    ) {
        reject(question.options.size != 4, "Type A and B questions require exactly four options.")
        reject(question.options.count(CourseEditorOption::correct) != 1, "Exactly one option must be correct.")
        val defaultKeys = mutableSetOf<String>()
        val supportLanguages = course.supportLanguages.toSet()
        val translatedKeys = course.supportLanguages.associateWith { mutableSetOf<String>() }
        question.options.forEach { option ->
            reject(!defaultKeys.add(matchingKey(option.text, course.defaultSupportLanguage))) {
                "Option labels must be unique."
            }
            if (requireTranslations) {
                requireExactLanguages(option.translations, supportLanguages, "Type A option translations")
                reject(option.translations.getValue(course.defaultSupportLanguage) != option.text) {
                    "Type A option text must equal its default support-language translation."
                }
                option.translations.forEach { (language, value) ->
                    reject(!translatedKeys.getValue(language).add(matchingKey(value, language))) {
                        "Type A options must be unique within each support language."
                    }
                }
            } else {
                reject(option.translations.isNotEmpty(), "Type B options cannot contain translations.")
            }
        }
    }

    private fun requireCloze(prompt: String?, type: String) {
        reject(prompt == null || prompt.windowed(CLOZE_MARKER.length).count { it == CLOZE_MARKER } != 1) {
            "$type prompt must contain exactly one --- marker."
        }
    }

    private fun requireExactLanguages(values: Map<String, String>, expected: Set<String>, label: String) {
        reject(values.keys != expected, "$label must contain exactly the course support languages.")
    }

    private fun uniqueTitles(values: List<String>, label: String) {
        val normalized = values.map { it.lowercase(Locale.ROOT) }
        reject(normalized.distinct().size != normalized.size, "Sibling $label titles must be unique.")
    }

    private fun normalizeMap(values: Map<String, String>, max: Int, label: String): Map<String, String> =
        values.entries.associate { (language, value) ->
            language.trim() to text(value, max, label)
        }.toSortedMap()

    private fun text(value: String, max: Int, label: String): String {
        val normalized = Normalizer.normalize(value.trim(), Normalizer.Form.NFC)
        reject(normalized.isEmpty() || normalized.length > max, "$label must contain 1 to $max characters.")
        return normalized
    }

    private fun optionalText(value: String?, max: Int, label: String): String? = value?.let {
        val normalized = Normalizer.normalize(it.trim(), Normalizer.Form.NFC)
        if (normalized.isEmpty()) null else text(normalized, max, label)
    }

    private fun typedKey(value: String, language: String): String = runCatching {
        TypedAnswerPolicy.canonicalize(value, language)
    }.getOrElse { throw UnprocessableProblem("Typed answers contain unsupported characters or length.") }

    private fun matchingKey(value: String, language: String): String = runCatching {
        MatchingLabelPolicy.canonicalize(value, language)
    }.getOrElse { throw UnprocessableProblem("A label contains unsupported characters or length.") }

    private inline fun reject(condition: Boolean, message: () -> String) {
        if (condition) throw UnprocessableProblem(message())
    }

    private fun reject(condition: Boolean, message: String) = reject(condition) { message }

    private const val CLOZE_MARKER = "---"
    private val MIN_PASS_THRESHOLD = java.math.BigDecimal("0.50")
    private val MAX_PASS_THRESHOLD = java.math.BigDecimal.ONE
}
