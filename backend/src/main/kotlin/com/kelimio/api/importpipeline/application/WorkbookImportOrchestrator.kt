package com.kelimio.api.importpipeline.application

import com.kelimio.api.importpipeline.domain.CourseContentPath
import com.kelimio.api.importpipeline.domain.PlannedTest
import com.kelimio.api.importpipeline.domain.ResolvedTestMode
import com.kelimio.api.importpipeline.domain.TestAllocationPlanner
import com.kelimio.api.importpipeline.domain.TestAllocationPolicy
import com.kelimio.api.importpipeline.domain.TestPlanningRow
import com.kelimio.api.importpipeline.domain.WorkbookRecordType
import com.kelimio.api.importpipeline.domain.WorkbookRowSource
import com.kelimio.api.importpipeline.domain.WorkbookTestModeDirective
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxCell
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxRow
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxSheet
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxWorkbook
import com.kelimio.api.language.InvalidTypedAnswerException
import com.kelimio.api.language.TypedAnswerPolicy
import java.text.Normalizer
import java.util.Locale

/**
 * Converts an inert, security-screened workbook into a deterministic preview.
 *
 * This class intentionally has no Spring, persistence, clock, random-ID, or filesystem dependency.
 * Invalid workbooks return issues and never produce a partial test plan.
 */
class WorkbookImportOrchestrator {
    fun preview(
        workbook: RawXlsxWorkbook,
        checkpoint: () -> Unit = {},
    ): WorkbookImportPreview {
        checkpoint()
        val issues = CappedWorkbookIssueList(MAX_COLLECTED_ISSUES, checkpoint)
        if (workbook.rulesVersion !in SUPPORTED_RULES_VERSIONS) {
            issues.error(
                WorkbookImportIssueCode.INVALID_SETTING_VALUE,
                source = null,
                message = "The workbook rules version is not supported",
            )
        }

        val sheets = workbook.sheets.sortedBy(RawXlsxSheet::ordinal)
        checkpoint()
        validateWorkbookSheetIdentity(sheets, issues)

        val settingsSheets = sheets.filter { it.name == SETTINGS_SHEET_NAME }
        if (settingsSheets.size != 1) {
            issues.error(
                WorkbookImportIssueCode.SETTINGS_SHEET_COUNT,
                source = null,
                message = "The workbook must contain exactly one $SETTINGS_SHEET_NAME sheet",
            )
        }
        val settings = settingsSheets.singleOrNull()?.let { parseSettings(workbook.rulesVersion, it, issues) }

        val contentSheets = sheets.filterNot { it.name == SETTINGS_SHEET_NAME }
        if (contentSheets.isEmpty()) {
            issues.error(
                WorkbookImportIssueCode.CONTENT_SHEET_MISSING,
                source = null,
                message = "The workbook must contain at least one level sheet",
            )
        }

        val rows = if (settings == null) {
            emptyList()
        } else {
            contentSheets.flatMap { sheet ->
                checkpoint()
                parseContentSheet(sheet, settings, issues, checkpoint)
            }
        }
        checkpoint()
        if (settings != null && contentSheets.isNotEmpty() && rows.isEmpty()) {
            issues.error(
                WorkbookImportIssueCode.CONTENT_ROW_MISSING,
                source = null,
                message = "The workbook must contain at least one valid content row",
            )
        }

        val plan = if (issues.any { it.severity == WorkbookImportIssueSeverity.ERROR }) {
            null
        } else {
            val validSettings = checkNotNull(settings)
            TestAllocationPlanner.plan(
                rows = rows.map { row ->
                    checkpoint()
                    row.toPlanningRow()
                },
                policy = TestAllocationPolicy(
                    rulesVersion = workbook.rulesVersion,
                    targetTestSize = validSettings.targetTestSize,
                    minimumLastAutomaticTestSize = validSettings.minimumLastAutomaticTestSize,
                    fillFixedTests = validSettings.fillFixedTests,
                    defaultMode = validSettings.defaultTestMode,
                ),
                checkpoint = checkpoint,
            ).also { testPlan ->
                issues += testPlan.issues.map { it.toWorkbookIssue() }
                validatePlannedTestSemantics(workbook.rulesVersion, testPlan.tests, issues, checkpoint)
            }
        }

        val composition = if (
            settings != null && plan?.isValid == true &&
            issues.none { it.severity == WorkbookImportIssueSeverity.ERROR }
        ) {
            WorkbookQuestionComposer.compose(workbook.rulesVersion, settings, rows, plan.tests, checkpoint).also {
                issues += it.issues
            }.composition
        } else {
            null
        }

        return WorkbookImportPreview(
            rulesVersion = workbook.rulesVersion,
            settings = settings,
            rows = rows,
            plan = plan,
            composition = composition,
            issues = issues,
            checkpoint = checkpoint,
        )
    }

    private fun validateWorkbookSheetIdentity(
        sheets: List<RawXlsxSheet>,
        issues: MutableList<WorkbookImportIssue>,
    ) {
        sheets.groupBy(RawXlsxSheet::ordinal)
            .filterValues { it.size > 1 }
            .toSortedMap()
            .forEach { (_, duplicates) ->
                duplicates.drop(1).forEach { duplicate ->
                    issues.error(
                        WorkbookImportIssueCode.DUPLICATE_SHEET_ORDINAL,
                        duplicate.source(rowNumber = 1),
                        "A physical sheet ordinal is repeated",
                    )
                }
            }

        val normalizedNames = mutableMapOf<String, RawXlsxSheet>()
        sheets.forEach { sheet ->
            val normalized = normalizeStructuralText(
                raw = sheet.name,
                source = sheet.source(rowNumber = 1),
                issues = issues,
                missingCode = WorkbookImportIssueCode.INVALID_SHEET_NAME,
            ) ?: return@forEach
            val collisionKey = normalized.collisionKey()
            if (normalizedNames.putIfAbsent(collisionKey, sheet) != null) {
                issues.error(
                    WorkbookImportIssueCode.DUPLICATE_SHEET_NAME,
                    sheet.source(rowNumber = 1),
                    "A normalized sheet name is repeated",
                )
            }
        }
    }

    private fun parseSettings(
        rulesVersion: String,
        sheet: RawXlsxSheet,
        issues: MutableList<WorkbookImportIssue>,
    ): CourseImportSettings? {
        val initialIssueCount = issues.size
        val settingsHeaderRows = sheet.rows.filter { it.rowNumber == SETTINGS_HEADER_ROW }
        if (settingsHeaderRows.size != 1) {
            issues.error(
                WorkbookImportIssueCode.HEADER_ROW_MISSING,
                sheet.source(SETTINGS_HEADER_ROW),
                "The settings sheet must contain exactly one header row",
            )
        } else {
            val headerCells = settingsHeaderRows.single().indexCells(sheet, issues)
            if (headerCells.keys != (1..SETTINGS_HEADER.size).toSet()) {
                issues.error(
                    WorkbookImportIssueCode.HEADER_COLUMN_COUNT,
                    sheet.source(SETTINGS_HEADER_ROW),
                    "The settings header must contain exactly three contiguous columns",
                )
            }
            SETTINGS_HEADER.forEachIndexed { index, expected ->
                requireHeaderLiteral(
                    sheet = sheet,
                    cell = headerCells[index + 1],
                    column = index + 1,
                    expected = expected,
                    issues = issues,
                    rowNumber = SETTINGS_HEADER_ROW,
                )
            }
        }
        val settingRows = sheet.rows
            .filter { it.rowNumber in FIRST_SETTING_ROW..LAST_SETTING_ROW }
            .sortedBy(RawXlsxRow::rowNumber)
        val byName = linkedMapOf<String, SettingValue>()

        val rowsByNumber = settingRows.groupBy(RawXlsxRow::rowNumber)
        (FIRST_SETTING_ROW..LAST_SETTING_ROW).forEach { rowNumber ->
            val rows = rowsByNumber[rowNumber].orEmpty()
            if (rows.isEmpty()) {
                issues.error(
                    WorkbookImportIssueCode.SETTINGS_ROW_MISSING,
                    sheet.source(rowNumber, SETTINGS_NAME_COLUMN),
                    "A required settings row is missing",
                )
            }
            rows.forEach { row ->
                val cells = row.indexCells(sheet, issues)
                cells.keys.filter { it > SETTINGS_DESCRIPTION_COLUMN }.forEach { column ->
                    issues.error(
                        WorkbookImportIssueCode.UNEXPECTED_FIELD_VALUE,
                        sheet.source(row.rowNumber, column, cells[column]),
                        "A settings row has a value outside columns A through C",
                    )
                }
                val nameCell = cells[SETTINGS_NAME_COLUMN]
                val valueCell = cells[SETTINGS_VALUE_COLUMN]
                val name = normalizeStructuralText(
                    raw = nameCell?.value,
                    source = sheet.source(row.rowNumber, SETTINGS_NAME_COLUMN, nameCell),
                    issues = issues,
                    missingCode = WorkbookImportIssueCode.SETTING_NAME_MISSING,
                ) ?: return@forEach
                if (name !in SETTING_NAMES) {
                    issues.error(
                        WorkbookImportIssueCode.UNKNOWN_SETTING,
                        sheet.source(row.rowNumber, SETTINGS_NAME_COLUMN, nameCell),
                        "The settings row name is not part of the xlsx-v1 schema",
                    )
                    return@forEach
                }
                val value = normalizeStructuralText(
                    raw = valueCell?.value,
                    source = sheet.source(row.rowNumber, SETTINGS_VALUE_COLUMN, valueCell),
                    issues = issues,
                    missingCode = WorkbookImportIssueCode.SETTING_VALUE_MISSING,
                ) ?: return@forEach
                val previous = byName.putIfAbsent(
                    name,
                    SettingValue(value, sheet.source(row.rowNumber, SETTINGS_VALUE_COLUMN, valueCell)),
                )
                if (previous != null) {
                    issues.error(
                        WorkbookImportIssueCode.DUPLICATE_SETTING,
                        sheet.source(row.rowNumber, SETTINGS_NAME_COLUMN, nameCell),
                        "A settings row is repeated",
                    )
                }
            }
        }
        SETTING_NAMES.forEach { expected ->
            if (expected !in byName) {
                issues.error(
                    WorkbookImportIssueCode.SETTINGS_ROW_MISSING,
                    sheet.source(rowNumber = FIRST_SETTING_ROW),
                    "A required setting is missing: $expected",
                )
            }
        }
        if (issues.size != initialIssueCount) return null

        val courseName = byName.required(COURSE_NAME)
        val targetLanguage = normalizeLanguage(byName.requiredValue(TARGET_LANGUAGE_CODE), issues)
        val targetLanguageName = byName.required(TARGET_LANGUAGE_NAME)
        val supportLanguages = parseSupportLanguages(byName.requiredValue(SUPPORT_LANGUAGES), issues)
        val defaultSupportLanguage = normalizeLanguage(byName.requiredValue(DEFAULT_SUPPORT_LANGUAGE), issues)
        val defaultMode = parseDefaultMode(byName.requiredValue(DEFAULT_TEST_MODE), issues)
        val visibility = parseVisibility(byName.requiredValue(COURSE_VISIBILITY), issues)
        requireLiteral(byName.requiredValue(PRICE), PRICE_APPLICATION_LITERAL, issues)
        val targetSize = parsePositiveInteger(byName.requiredValue(DEFAULT_TEST_SIZE), issues)
        val minimumLastSize = parsePositiveInteger(byName.requiredValue(MINIMUM_LAST_GROUP), issues)
        val fillFixed = parseFillFixed(byName.requiredValue(FILL_FIXED_TESTS), issues)
        val completionThreshold = parseCompletionThreshold(byName.requiredValue(COMPLETION_THRESHOLD), issues)
        requireLiteral(byName.requiredValue(TYPED_ALTERNATIVE), TYPED_ALTERNATIVE_LITERAL, issues)
        requireLiteral(byName.requiredValue(OFFLINE_MODE), OFFLINE_MODE_LITERAL, issues)

        if (targetLanguage != null && supportLanguages != null && targetLanguage in supportLanguages) {
            issues.invalidSetting(
                byName.requiredValue(SUPPORT_LANGUAGES).source,
                "The target language cannot also be a support language",
            )
        }
        if (
            defaultSupportLanguage != null &&
            supportLanguages != null &&
            defaultSupportLanguage !in supportLanguages
        ) {
            issues.invalidSetting(
                byName.requiredValue(DEFAULT_SUPPORT_LANGUAGE).source,
                "The default support language must be listed among support languages",
            )
        }
        if (targetSize != null && minimumLastSize != null && minimumLastSize > targetSize) {
            issues.invalidSetting(
                byName.requiredValue(MINIMUM_LAST_GROUP).source,
                "The minimum last group size cannot exceed the default test size",
            )
        }
        if (issues.size != initialIssueCount) return null

        return CourseImportSettings(
            rulesVersion = rulesVersion,
            courseName = courseName.value,
            targetLanguageCode = checkNotNull(targetLanguage),
            targetLanguageName = targetLanguageName.value,
            supportLanguageCodes = immutableList(checkNotNull(supportLanguages)),
            defaultSupportLanguageCode = checkNotNull(defaultSupportLanguage),
            defaultTestMode = checkNotNull(defaultMode),
            visibility = checkNotNull(visibility),
            targetTestSize = checkNotNull(targetSize),
            minimumLastAutomaticTestSize = checkNotNull(minimumLastSize),
            fillFixedTests = checkNotNull(fillFixed),
            completionThresholdPercent = checkNotNull(completionThreshold),
        )
    }

    private fun parseContentSheet(
        sheet: RawXlsxSheet,
        settings: CourseImportSettings,
        issues: MutableList<WorkbookImportIssue>,
        checkpoint: () -> Unit,
    ): List<NormalizedWorkbookRow> {
        val level = normalizeStructuralText(
            raw = sheet.name,
            source = sheet.source(rowNumber = 1),
            issues = issues,
            missingCode = WorkbookImportIssueCode.INVALID_SHEET_NAME,
        ) ?: return emptyList()
        val headerRows = sheet.rows.filter { it.rowNumber == HEADER_ROW }
        if (headerRows.size != 1) {
            issues.error(
                WorkbookImportIssueCode.HEADER_ROW_MISSING,
                sheet.source(HEADER_ROW),
                "A level sheet must contain exactly one header row",
            )
            return emptyList()
        }
        val header = parseHeader(sheet, headerRows.single(), settings.supportLanguageCodes, issues) ?: return emptyList()

        val semanticRows = sheet.rows
            .asSequence()
            .filter { it.rowNumber > HEADER_ROW }
            .sortedBy(RawXlsxRow::rowNumber)
            .filter { it.cells.isNotEmpty() }
            .toList()
        if (semanticRows.isEmpty()) {
            issues.error(
                WorkbookImportIssueCode.LEVEL_CONTENT_ROW_MISSING,
                sheet.source(HEADER_ROW),
                "Every level sheet must contain at least one semantic content row",
            )
            return emptyList()
        }
        return semanticRows
            .asSequence()
            .mapNotNull { row ->
                checkpoint()
                parseContentRow(sheet, level, settings.targetLanguageCode, row, header, issues)
            }
            .toList()
    }

    private fun parseHeader(
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        supportLanguages: List<String>,
        issues: MutableList<WorkbookImportIssue>,
    ): ContentHeader? {
        val initialIssueCount = issues.size
        val cells = row.indexCells(sheet, issues)
        val expectedCount = HEADER_PREFIX.size + supportLanguages.size + HEADER_SUFFIX.size
        val actualColumns = cells.keys
        if (actualColumns != (1..expectedCount).toSet()) {
            issues.error(
                WorkbookImportIssueCode.HEADER_COLUMN_COUNT,
                sheet.source(HEADER_ROW),
                "The header columns must be contiguous and match the configured support languages",
            )
        }

        HEADER_PREFIX.forEachIndexed { index, expected ->
            requireHeaderLiteral(sheet, cells[index + 1], index + 1, expected, issues)
        }
        val supportColumns = linkedMapOf<String, Int>()
        supportLanguages.forEachIndexed { index, expectedLanguage ->
            val column = HEADER_PREFIX.size + index + 1
            val cell = cells[column]
            val normalized = cell?.value?.let {
                try {
                    ImportLanguageTagNormalizer.normalize(it)
                } catch (_: InvalidImportLanguageTagException) {
                    null
                }
            }
            if (normalized != expectedLanguage) {
                issues.error(
                    WorkbookImportIssueCode.HEADER_MISMATCH,
                    sheet.source(HEADER_ROW, column, cell),
                    "A support-language header does not match the declared language order",
                )
            } else if (supportColumns.putIfAbsent(normalized, column) != null) {
                issues.error(
                    WorkbookImportIssueCode.HEADER_MISMATCH,
                    sheet.source(HEADER_ROW, column, cell),
                    "A support-language header is repeated",
                )
            }
        }
        HEADER_SUFFIX.forEachIndexed { index, expected ->
            val column = HEADER_PREFIX.size + supportLanguages.size + index + 1
            requireHeaderLiteral(sheet, cells[column], column, expected, issues)
        }
        if (issues.size != initialIssueCount) return null

        return ContentHeader(
            expectedColumnCount = expectedCount,
            supportLanguageColumns = immutableMap(supportColumns),
            sentenceColumn = HEADER_PREFIX.size + supportLanguages.size + 1,
        )
    }

    private fun parseContentRow(
        sheet: RawXlsxSheet,
        level: String,
        targetLanguage: String,
        row: RawXlsxRow,
        header: ContentHeader,
        issues: MutableList<WorkbookImportIssue>,
    ): NormalizedWorkbookRow? {
        val initialIssueCount = issues.size
        val cells = row.indexCells(sheet, issues)
        if (cells.isEmpty()) return null
        cells.keys.filter { it !in 1..header.expectedColumnCount }.forEach { column ->
            issues.error(
                WorkbookImportIssueCode.UNEXPECTED_FIELD_VALUE,
                sheet.source(row.rowNumber, column, cells[column]),
                "A content row has a value outside the declared schema",
            )
        }

        fun structural(column: Int, required: Boolean = false): String? = normalizeStructuralText(
            raw = cells[column]?.value,
            source = sheet.source(row.rowNumber, column, cells[column]),
            issues = issues,
            missingCode = if (required) WorkbookImportIssueCode.REQUIRED_FIELD_MISSING else null,
        )

        fun text(column: Int, required: Boolean = false): String? = normalizeContentText(
            raw = cells[column]?.value,
            source = sheet.source(row.rowNumber, column, cells[column]),
            issues = issues,
            missingCode = if (required) WorkbookImportIssueCode.REQUIRED_FIELD_MISSING else null,
        )

        val unit = structural(UNIT_COLUMN, required = true)
        val topic = structural(TOPIC_COLUMN, required = true)
        val fixedTestNumber = parseTestNumber(structural(TEST_NUMBER_COLUMN), sheet, row, cells, issues)
        val requestedMode = parseRowMode(structural(TEST_MODE_COLUMN), sheet, row, cells, issues)
        val recordType = parseRecordType(structural(RECORD_TYPE_COLUMN, required = true), sheet, row, cells, issues)
        val targetText = text(TARGET_TEXT_COLUMN, required = true)
        val translations = linkedMapOf<String, String>()
        header.supportLanguageColumns.forEach { (language, column) ->
            text(column)?.let { translations[language] = it }
        }
        val sentence = text(header.sentenceColumn)
        val correctAnswer = text(header.sentenceColumn + 1)
        val alternativeCorrectAnswer = text(header.sentenceColumn + 2)
        val wrongAnswersByColumn = (header.sentenceColumn + 3..header.sentenceColumn + 5).map { column ->
            text(column)
        }
        val matchingGroup = structural(header.sentenceColumn + 6)
        val hidden = parseHidden(structural(header.sentenceColumn + 7, required = true), sheet, row, header, cells, issues)
        val note = text(header.sentenceColumn + 8)
        if (hidden == true) {
            issues.error(
                WorkbookImportIssueCode.UNSUPPORTED_HIDDEN_CONTENT,
                sheet.source(row.rowNumber, header.sentenceColumn + 7, cells[header.sentenceColumn + 7]),
                "Hidden-row allocation semantics are not enabled in xlsx-v1",
            )
        }

        if (recordType != null) {
            validateRecordPayload(
                sheet = sheet,
                row = row,
                header = header,
                cells = cells,
                recordType = recordType,
                targetText = targetText,
                translations = translations,
                sentence = sentence,
                correctAnswer = correctAnswer,
                alternativeCorrectAnswer = alternativeCorrectAnswer,
                targetLanguage = targetLanguage,
                wrongAnswersByColumn = wrongAnswersByColumn,
                matchingGroup = matchingGroup,
                issues = issues,
            )
        }
        if (issues.size != initialIssueCount) return null

        val path = CourseContentPath(level = level, unit = checkNotNull(unit), topic = checkNotNull(topic))
        val normalizedWrongAnswers = wrongAnswersByColumn.filterNotNull()
        val contentHash = CanonicalNormalizedRowDigest.sha256(
            path = path,
            recordType = checkNotNull(recordType),
            targetText = checkNotNull(targetText),
            translations = translations,
            sentence = sentence,
            correctAnswer = correctAnswer,
            alternativeCorrectAnswer = alternativeCorrectAnswer,
            wrongAnswers = normalizedWrongAnswers,
            matchingGroup = matchingGroup,
            hidden = checkNotNull(hidden),
            note = note,
        )
        return NormalizedWorkbookRow(
            source = WorkbookRowSource(sheet.ordinal, sheet.name, row.rowNumber),
            path = path,
            fixedTestNumber = fixedTestNumber,
            requestedMode = requestedMode,
            recordType = recordType,
            targetText = targetText,
            translations = immutableMap(translations),
            sentence = sentence,
            correctAnswer = correctAnswer,
            alternativeCorrectAnswer = alternativeCorrectAnswer,
            wrongAnswers = immutableList(normalizedWrongAnswers),
            matchingGroup = matchingGroup,
            hidden = hidden,
            note = note,
            normalizedContentSha256 = contentHash,
        )
    }

    private fun validateRecordPayload(
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        header: ContentHeader,
        cells: Map<Int, RawXlsxCell>,
        recordType: WorkbookRecordType,
        targetText: String?,
        translations: Map<String, String>,
        sentence: String?,
        correctAnswer: String?,
        alternativeCorrectAnswer: String?,
        targetLanguage: String,
        wrongAnswersByColumn: List<String?>,
        matchingGroup: String?,
        issues: MutableList<WorkbookImportIssue>,
    ) {
        val translationColumns = header.supportLanguageColumns
        when (recordType) {
            WorkbookRecordType.WORD -> {
                validateMaximumContentLength(
                    sheet, row, TARGET_TEXT_COLUMN, cells, targetText,
                    MAX_QUESTION_PROMPT_CODE_POINTS, "A word target exceeds the supported prompt length", issues,
                )
                translationColumns.forEach { (language, column) ->
                    if (language !in translations) {
                        issues.error(
                            WorkbookImportIssueCode.MISSING_TRANSLATION,
                            sheet.source(row.rowNumber, column, cells[column]),
                            "A word row requires every declared support-language translation",
                        )
                    }
                    validateMaximumContentLength(
                        sheet, row, column, cells, translations[language],
                        MAX_ANSWER_CODE_POINTS, "A word translation exceeds the supported answer length", issues,
                    )
                }
                wrongAnswersByColumn.forEachIndexed { index, answer ->
                    validateMaximumContentLength(
                        sheet, row, header.sentenceColumn + 3 + index, cells, answer,
                        MAX_ANSWER_CODE_POINTS, "A word distractor exceeds the supported answer length", issues,
                    )
                }
                requireAbsent(
                    sheet,
                    row,
                    cells,
                    listOf(
                        header.sentenceColumn to sentence,
                        header.sentenceColumn + 1 to correctAnswer,
                        header.sentenceColumn + 2 to alternativeCorrectAnswer,
                    ),
                    issues,
                    "Word rows cannot contain cloze fields",
                )
            }

            WorkbookRecordType.MULTIPLE_CHOICE_CLOZE -> {
                requireNoTranslations(sheet, row, cells, translationColumns, translations, issues)
                validateClozeSentence(sheet, row, header.sentenceColumn, cells, sentence, issues)
                validateMaximumContentLength(
                    sheet, row, header.sentenceColumn, cells, sentence,
                    MAX_QUESTION_PROMPT_CODE_POINTS, "A cloze sentence exceeds the supported prompt length", issues,
                )
                validateMaximumContentLength(
                    sheet, row, header.sentenceColumn + 1, cells, correctAnswer,
                    MAX_ANSWER_CODE_POINTS, "A correct answer exceeds the supported answer length", issues,
                )
                wrongAnswersByColumn.forEachIndexed { index, answer ->
                    validateMaximumContentLength(
                        sheet, row, header.sentenceColumn + 3 + index, cells, answer,
                        MAX_ANSWER_CODE_POINTS, "A distractor exceeds the supported answer length", issues,
                    )
                }
                if (correctAnswer == null) {
                    issues.error(
                        WorkbookImportIssueCode.REQUIRED_FIELD_MISSING,
                        sheet.source(row.rowNumber, header.sentenceColumn + 1, cells[header.sentenceColumn + 1]),
                        "A multiple-choice cloze row requires a correct answer",
                    )
                }
                requireAbsent(
                    sheet,
                    row,
                    cells,
                    listOf(
                        header.sentenceColumn + 2 to alternativeCorrectAnswer,
                        header.sentenceColumn + 6 to matchingGroup,
                    ),
                    issues,
                    "A multiple-choice cloze row contains a field reserved for another record type",
                )
                if (wrongAnswersByColumn.count { it != null } != REQUIRED_MULTIPLE_CHOICE_WRONG_ANSWERS) {
                    issues.error(
                        WorkbookImportIssueCode.INVALID_WRONG_ANSWER_COUNT,
                        sheet.source(row.rowNumber, header.sentenceColumn + 3),
                        "A multiple-choice cloze row requires exactly three wrong answers",
                    )
                }
            }

            WorkbookRecordType.TYPED_CLOZE -> {
                requireNoTranslations(sheet, row, cells, translationColumns, translations, issues)
                validateClozeSentence(sheet, row, header.sentenceColumn, cells, sentence, issues)
                validateMaximumContentLength(
                    sheet, row, header.sentenceColumn, cells, sentence,
                    MAX_QUESTION_PROMPT_CODE_POINTS, "A cloze sentence exceeds the supported prompt length", issues,
                )
                if (correctAnswer == null) {
                    issues.error(
                        WorkbookImportIssueCode.REQUIRED_FIELD_MISSING,
                        sheet.source(row.rowNumber, header.sentenceColumn + 1, cells[header.sentenceColumn + 1]),
                        "A typed cloze row requires a correct answer",
                    )
                }
                requireAbsent(
                    sheet,
                    row,
                    cells,
                    wrongAnswersByColumn.mapIndexed { index, value -> header.sentenceColumn + 3 + index to value } +
                        (header.sentenceColumn + 6 to matchingGroup),
                    issues,
                    "A typed cloze row contains a field reserved for another record type",
                )
                validateTypedAnswers(
                    sheet,
                    row,
                    header.sentenceColumn + 1,
                    correctAnswer,
                    alternativeCorrectAnswer,
                    targetLanguage,
                    issues,
                )
            }
        }

        val authoredAnswers = buildList {
            targetText?.let(::add)
            addAll(translations.values)
            correctAnswer?.let(::add)
            alternativeCorrectAnswer?.let(::add)
        }
        validateAnswerUniqueness(
            sheet = sheet,
            row = row,
            firstWrongColumn = header.sentenceColumn + 3,
            authoredAnswers = authoredAnswers,
            alternativeCorrectAnswer = alternativeCorrectAnswer.takeUnless {
                recordType == WorkbookRecordType.TYPED_CLOZE
            },
            correctAnswer = correctAnswer,
            wrongAnswers = wrongAnswersByColumn,
            issues = issues,
        )
    }

    private fun validateMaximumContentLength(
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        column: Int,
        cells: Map<Int, RawXlsxCell>,
        value: String?,
        maximumCodePoints: Int,
        message: String,
        issues: MutableList<WorkbookImportIssue>,
    ) {
        if (value != null && value.codePointCount(0, value.length) > maximumCodePoints) {
            issues.error(
                WorkbookImportIssueCode.INVALID_TEXT,
                sheet.source(row.rowNumber, column, cells[column]),
                message,
            )
        }
    }

    private fun validateAnswerUniqueness(
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        firstWrongColumn: Int,
        authoredAnswers: List<String>,
        alternativeCorrectAnswer: String?,
        correctAnswer: String?,
        wrongAnswers: List<String?>,
        issues: MutableList<WorkbookImportIssue>,
    ) {
        if (
            alternativeCorrectAnswer != null &&
            correctAnswer != null &&
            alternativeCorrectAnswer.answerKey() == correctAnswer.answerKey()
        ) {
            issues.error(
                WorkbookImportIssueCode.DUPLICATE_ANSWER_OPTION,
                sheet.source(row.rowNumber, firstWrongColumn - 1),
                "The alternative answer must differ from the correct answer",
            )
        }
        val answerKeys = authoredAnswers.mapTo(mutableSetOf()) { answer -> answer.answerKey() }
        val seenWrongAnswers = mutableSetOf<String>()
        wrongAnswers.forEachIndexed { index, wrongAnswer ->
            if (wrongAnswer != null) {
                val key = wrongAnswer.answerKey()
                if (key in answerKeys || !seenWrongAnswers.add(key)) {
                    issues.error(
                        WorkbookImportIssueCode.DUPLICATE_ANSWER_OPTION,
                        sheet.source(row.rowNumber, firstWrongColumn + index),
                        "A wrong answer duplicates another authored answer option",
                    )
                }
            }
        }
    }

    private fun validateTypedAnswers(
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        correctAnswerColumn: Int,
        correctAnswer: String?,
        alternativeCorrectAnswer: String?,
        targetLanguage: String,
        issues: MutableList<WorkbookImportIssue>,
    ) {
        fun canonicalize(value: String?, column: Int): String? {
            if (value == null) return null
            return try {
                TypedAnswerPolicy.canonicalize(value, targetLanguage)
            } catch (_: InvalidTypedAnswerException) {
                issues.error(
                    WorkbookImportIssueCode.INVALID_TEXT,
                    sheet.source(row.rowNumber, column),
                    "A typed answer is outside the typed-answer-v1 policy",
                )
                null
            }
        }

        val correctKey = canonicalize(correctAnswer, correctAnswerColumn)
        val alternativeKey = canonicalize(alternativeCorrectAnswer, correctAnswerColumn + 1)
        if (correctKey != null && alternativeKey != null && correctKey == alternativeKey) {
            issues.error(
                WorkbookImportIssueCode.DUPLICATE_ANSWER_OPTION,
                sheet.source(row.rowNumber, correctAnswerColumn + 1),
                "The alternative answer must differ from the correct answer under typed-answer-v1",
            )
        }
    }

    private fun requireNoTranslations(
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        cells: Map<Int, RawXlsxCell>,
        translationColumns: Map<String, Int>,
        translations: Map<String, String>,
        issues: MutableList<WorkbookImportIssue>,
    ) {
        translationColumns.forEach { (language, column) ->
            if (language in translations) {
                issues.error(
                    WorkbookImportIssueCode.UNEXPECTED_FIELD_VALUE,
                    sheet.source(row.rowNumber, column, cells[column]),
                    "Cloze rows cannot contain word-translation fields",
                )
            }
        }
    }

    private fun requireAbsent(
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        cells: Map<Int, RawXlsxCell>,
        fields: List<Pair<Int, String?>>,
        issues: MutableList<WorkbookImportIssue>,
        message: String,
    ) {
        fields.forEach { (column, value) ->
            if (value != null) {
                issues.error(
                    WorkbookImportIssueCode.UNEXPECTED_FIELD_VALUE,
                    sheet.source(row.rowNumber, column, cells[column]),
                    message,
                )
            }
        }
    }

    private fun validateClozeSentence(
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        sentenceColumn: Int,
        cells: Map<Int, RawXlsxCell>,
        sentence: String?,
        issues: MutableList<WorkbookImportIssue>,
    ) {
        if (sentence == null) {
            issues.error(
                WorkbookImportIssueCode.REQUIRED_FIELD_MISSING,
                sheet.source(row.rowNumber, sentenceColumn, cells[sentenceColumn]),
                "A cloze row requires a sentence",
            )
        } else if (sentence.windowed(CLOZE_MARKER.length).count { it == CLOZE_MARKER } != 1) {
            issues.error(
                WorkbookImportIssueCode.INVALID_CLOZE_PLACEHOLDER,
                sheet.source(row.rowNumber, sentenceColumn, cells[sentenceColumn]),
                "A cloze sentence must contain exactly one --- marker",
            )
        }
    }

    private fun parseTestNumber(
        value: String?,
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        cells: Map<Int, RawXlsxCell>,
        issues: MutableList<WorkbookImportIssue>,
    ): Int? {
        if (value == null) return null
        val parsed = value.takeIf(POSITIVE_INTEGER::matches)?.toIntOrNull()
        if (parsed == null || parsed <= 0) {
            issues.error(
                WorkbookImportIssueCode.INVALID_TEST_NUMBER,
                sheet.source(row.rowNumber, TEST_NUMBER_COLUMN, cells[TEST_NUMBER_COLUMN]),
                "Test No must be a positive base-10 integer",
            )
            return null
        }
        return parsed
    }

    private fun parseRowMode(
        value: String?,
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        cells: Map<Int, RawXlsxCell>,
        issues: MutableList<WorkbookImportIssue>,
    ): WorkbookTestModeDirective? {
        if (value == null) return null
        return ROW_MODES[value] ?: run {
            issues.error(
                WorkbookImportIssueCode.INVALID_TEST_MODE,
                sheet.source(row.rowNumber, TEST_MODE_COLUMN, cells[TEST_MODE_COLUMN]),
                "The row test mode is not a supported xlsx-v1 literal",
            )
            null
        }
    }

    private fun parseRecordType(
        value: String?,
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        cells: Map<Int, RawXlsxCell>,
        issues: MutableList<WorkbookImportIssue>,
    ): WorkbookRecordType? {
        if (value == null) return null
        return RECORD_TYPES[value] ?: run {
            issues.error(
                WorkbookImportIssueCode.INVALID_RECORD_TYPE,
                sheet.source(row.rowNumber, RECORD_TYPE_COLUMN, cells[RECORD_TYPE_COLUMN]),
                "The record type is not a supported xlsx-v1 literal",
            )
            null
        }
    }

    private fun parseHidden(
        value: String?,
        sheet: RawXlsxSheet,
        row: RawXlsxRow,
        header: ContentHeader,
        cells: Map<Int, RawXlsxCell>,
        issues: MutableList<WorkbookImportIssue>,
    ): Boolean? {
        if (value == null) return null
        return when (value) {
            HIDDEN_YES -> true
            HIDDEN_NO -> false
            else -> {
                val column = header.sentenceColumn + 7
                issues.error(
                    WorkbookImportIssueCode.INVALID_HIDDEN_VALUE,
                    sheet.source(row.rowNumber, column, cells[column]),
                    "Gizli mi? must be Evet or Hayır",
                )
                null
            }
        }
    }

    private fun requireHeaderLiteral(
        sheet: RawXlsxSheet,
        cell: RawXlsxCell?,
        column: Int,
        expected: String,
        issues: MutableList<WorkbookImportIssue>,
        rowNumber: Int = HEADER_ROW,
    ) {
        val normalized = normalizeStructuralText(
            raw = cell?.value,
            source = sheet.source(rowNumber, column, cell),
            issues = issues,
            missingCode = WorkbookImportIssueCode.HEADER_MISMATCH,
        )
        if (normalized != null && normalized != expected) {
            issues.error(
                WorkbookImportIssueCode.HEADER_MISMATCH,
                sheet.source(rowNumber, column, cell),
                "The header does not match the xlsx-v1 schema at column $column",
            )
        }
    }

    private fun validatePlannedTestSemantics(
        rulesVersion: String,
        tests: List<PlannedTest>,
        issues: MutableList<WorkbookImportIssue>,
        checkpoint: () -> Unit,
    ) {
        tests.forEach { test ->
            checkpoint()
            val mode = test.resolvedMode ?: return@forEach
            if (mode == ResolvedTestMode.MATCHING && rulesVersion == XLSX_V1) {
                val source = test.rows.first().row.source
                issues.error(
                    WorkbookImportIssueCode.UNSUPPORTED_TEST_MODE,
                    source.toCellSource(),
                    "Matching allocation remains disabled until group and scoring semantics are finalized",
                )
                return@forEach
            }
            val requiredRecordType = when (mode) {
                ResolvedTestMode.MIXED -> null
                ResolvedTestMode.WORD -> WorkbookRecordType.WORD
                ResolvedTestMode.MULTIPLE_CHOICE_CLOZE -> WorkbookRecordType.MULTIPLE_CHOICE_CLOZE
                ResolvedTestMode.TYPED_CLOZE -> WorkbookRecordType.TYPED_CLOZE
                ResolvedTestMode.MATCHING -> WorkbookRecordType.WORD
            }
            if (requiredRecordType != null) {
                test.rows.firstOrNull { planned ->
                    checkpoint()
                    planned.row.recordType != requiredRecordType
                }?.let { incompatible ->
                    issues.error(
                        WorkbookImportIssueCode.INCOMPATIBLE_TEST_MODE,
                        incompatible.row.source.toCellSource(),
                        "A non-mixed test contains a record type incompatible with its resolved mode",
                    )
                }
            }
        }
    }

    private fun normalizeLanguage(
        setting: SettingValue,
        issues: MutableList<WorkbookImportIssue>,
    ): String? = try {
        ImportLanguageTagNormalizer.normalize(setting.value)
    } catch (_: InvalidImportLanguageTagException) {
        issues.invalidSetting(setting.source, "A language code is outside the supported BCP-47 subset")
        null
    }

    private fun parseSupportLanguages(
        setting: SettingValue,
        issues: MutableList<WorkbookImportIssue>,
    ): List<String>? {
        val parts = setting.value.split(',').map(String::trim)
        if (parts.isEmpty() || parts.any(String::isEmpty)) {
            issues.invalidSetting(setting.source, "Support languages must be a comma-separated language-code list")
            return null
        }
        val normalized = parts.map { part ->
            try {
                ImportLanguageTagNormalizer.normalize(part)
            } catch (_: InvalidImportLanguageTagException) {
                null
            }
        }
        if (normalized.any { it == null }) {
            issues.invalidSetting(setting.source, "A support language is outside the supported BCP-47 subset")
            return null
        }
        val languages = normalized.filterNotNull()
        if (languages.distinct().size != languages.size) {
            issues.invalidSetting(setting.source, "Support languages must not repeat after normalization")
            return null
        }
        return languages
    }

    private fun parseDefaultMode(
        setting: SettingValue,
        issues: MutableList<WorkbookImportIssue>,
    ): ResolvedTestMode? = DEFAULT_MODES[setting.value] ?: run {
        issues.invalidSetting(setting.source, "The default test mode is not a supported xlsx-v1 literal")
        null
    }

    private fun parseVisibility(
        setting: SettingValue,
        issues: MutableList<WorkbookImportIssue>,
    ): CourseVisibility? = COURSE_VISIBILITIES[setting.value] ?: run {
        issues.invalidSetting(setting.source, "Course visibility must be Public or Private")
        null
    }

    private fun parsePositiveInteger(
        setting: SettingValue,
        issues: MutableList<WorkbookImportIssue>,
    ): Int? {
        val parsed = setting.value.takeIf(POSITIVE_INTEGER::matches)?.toIntOrNull()
        if (parsed == null || parsed !in 1..MAX_TEST_SIZE) {
            issues.invalidSetting(setting.source, "A test-size setting must be between 1 and $MAX_TEST_SIZE")
            return null
        }
        return parsed
    }

    private fun parseFillFixed(
        setting: SettingValue,
        issues: MutableList<WorkbookImportIssue>,
    ): Boolean? = when (setting.value) {
        ENABLED_LITERAL -> true
        DISABLED_LITERAL -> false
        else -> {
            issues.invalidSetting(setting.source, "The fixed-test fill setting must be Açık or Kapalı")
            null
        }
    }

    private fun parseCompletionThreshold(
        setting: SettingValue,
        issues: MutableList<WorkbookImportIssue>,
    ): Int? {
        val match = PERCENTAGE.matchEntire(setting.value)
        val parsed = match?.groupValues?.get(1)?.toIntOrNull()
        if (parsed == null || parsed !in MIN_COMPLETION_PERCENT..MAX_COMPLETION_PERCENT) {
            issues.invalidSetting(
                setting.source,
                "The completion threshold must be a whole percentage from 50% through 100%",
            )
            return null
        }
        return parsed
    }

    private fun requireLiteral(
        setting: SettingValue,
        requiredValue: String,
        issues: MutableList<WorkbookImportIssue>,
    ) {
        if (setting.value != requiredValue) {
            issues.invalidSetting(setting.source, "The setting does not match the required xlsx-v1 policy literal")
        }
    }

    private fun normalizeStructuralText(
        raw: String?,
        source: WorkbookCellSource,
        issues: MutableList<WorkbookImportIssue>,
        missingCode: WorkbookImportIssueCode?,
    ): String? = normalizeText(raw, source, issues, missingCode, structural = true)

    private fun normalizeContentText(
        raw: String?,
        source: WorkbookCellSource,
        issues: MutableList<WorkbookImportIssue>,
        missingCode: WorkbookImportIssueCode?,
    ): String? = normalizeText(raw, source, issues, missingCode, structural = false)

    private fun normalizeText(
        raw: String?,
        source: WorkbookCellSource,
        issues: MutableList<WorkbookImportIssue>,
        missingCode: WorkbookImportIssueCode?,
        structural: Boolean,
    ): String? {
        if (raw == null || raw.isEmpty()) {
            if (missingCode != null) issues.error(missingCode, source, "A required cell is empty")
            return null
        }
        if (raw.isBlank() || raw.hasOuterWhitespace()) {
            issues.error(
                if (structural) WorkbookImportIssueCode.INVALID_STRUCTURAL_TEXT else WorkbookImportIssueCode.INVALID_TEXT,
                source,
                "Cell text cannot be whitespace-only or have leading/trailing whitespace",
            )
            return null
        }
        val normalized = Normalizer.normalize(raw, Normalizer.Form.NFC)
        val maximumCodePoints = if (structural) MAX_STRUCTURAL_TEXT_CODE_POINTS else MAX_CONTENT_TEXT_CODE_POINTS
        if (normalized.codePointCount(0, normalized.length) > maximumCodePoints) {
            issues.error(
                if (structural) WorkbookImportIssueCode.INVALID_STRUCTURAL_TEXT else WorkbookImportIssueCode.INVALID_TEXT,
                source,
                "Cell text exceeds the xlsx-v1 character limit",
            )
            return null
        }
        val forbidden = normalized.codePoints().anyMatch { codePoint ->
            if (structural && codePoint.isXlsxV1DefaultIgnorable()) {
                true
            } else when (Character.getType(codePoint)) {
                Character.SURROGATE.toInt(),
                Character.PRIVATE_USE.toInt(),
                Character.UNASSIGNED.toInt(),
                -> true

                Character.CONTROL.toInt() -> structural || codePoint !in ALLOWED_CONTENT_CONTROL_POINTS
                Character.FORMAT.toInt() -> structural || codePoint !in ALLOWED_CONTENT_FORMAT_POINTS
                Character.LINE_SEPARATOR.toInt(),
                Character.PARAGRAPH_SEPARATOR.toInt(),
                -> true

                else -> false
            }
        }
        if (forbidden) {
            issues.error(
                if (structural) WorkbookImportIssueCode.INVALID_STRUCTURAL_TEXT else WorkbookImportIssueCode.INVALID_TEXT,
                source,
                "Cell text contains a disallowed Unicode control or invisible character",
            )
            return null
        }
        return normalized
    }

    private fun RawXlsxRow.indexCells(
        sheet: RawXlsxSheet,
        issues: MutableList<WorkbookImportIssue>,
    ): Map<Int, RawXlsxCell> {
        val indexed = linkedMapOf<Int, RawXlsxCell>()
        cells.sortedBy(RawXlsxCell::columnNumber).forEach { cell ->
            if (indexed.putIfAbsent(cell.columnNumber, cell) != null) {
                issues.error(
                    WorkbookImportIssueCode.DUPLICATE_CELL,
                    sheet.source(rowNumber, cell.columnNumber, cell),
                    "A physical cell coordinate is repeated",
                )
            }
        }
        return indexed
    }

    private fun NormalizedWorkbookRow.toPlanningRow(): TestPlanningRow = TestPlanningRow(
        source = source,
        path = path,
        fixedTestNumber = fixedTestNumber,
        requestedMode = requestedMode,
        recordType = recordType,
        normalizedContentSha256 = normalizedContentSha256,
    )

    private fun WorkbookRowSource.toCellSource(): WorkbookCellSource = WorkbookCellSource(
        sheetOrdinal = sheetOrdinal,
        sheetName = sheetName,
        rowNumber = rowNumber,
    )

    private fun RawXlsxSheet.source(
        rowNumber: Int,
        columnNumber: Int? = null,
        cell: RawXlsxCell? = null,
    ): WorkbookCellSource = WorkbookCellSource(
        sheetOrdinal = ordinal,
        sheetName = name,
        rowNumber = rowNumber,
        columnNumber = columnNumber,
        reference = cell?.reference,
    )

    private fun String.hasOuterWhitespace(): Boolean =
        codePointAt(0).let { Character.isWhitespace(it) || Character.isSpaceChar(it) } ||
            codePointBefore(length).let { Character.isWhitespace(it) || Character.isSpaceChar(it) }

    private fun String.answerKey(): String = collisionKey()

    private fun String.collisionKey(): String =
        Normalizer.normalize(uppercase(Locale.ROOT).lowercase(Locale.ROOT), Normalizer.Form.NFC)

    private fun MutableList<WorkbookImportIssue>.error(
        code: WorkbookImportIssueCode,
        source: WorkbookCellSource?,
        message: String,
    ) {
        this += WorkbookImportIssue(WorkbookImportIssueSeverity.ERROR, code, source, message)
    }

    private fun MutableList<WorkbookImportIssue>.invalidSetting(
        source: WorkbookCellSource,
        message: String,
    ) {
        error(WorkbookImportIssueCode.INVALID_SETTING_VALUE, source, message)
    }

    private fun Map<String, SettingValue>.required(name: String): SettingValue = checkNotNull(this[name])

    private fun Map<String, SettingValue>.requiredValue(name: String): SettingValue = required(name)

    private data class SettingValue(
        val value: String,
        val source: WorkbookCellSource,
    )

    private data class ContentHeader(
        val expectedColumnCount: Int,
        val supportLanguageColumns: Map<String, Int>,
        val sentenceColumn: Int,
    )

    private companion object {
        const val MAX_COLLECTED_ISSUES = 2_001
        const val MAX_STRUCTURAL_TEXT_CODE_POINTS = 160
        const val MAX_CONTENT_TEXT_CODE_POINTS = 2_000
        const val MAX_QUESTION_PROMPT_CODE_POINTS = 1_000
        const val MAX_ANSWER_CODE_POINTS = 500
        const val XLSX_V1 = "xlsx-v1"
        const val XLSX_V2 = "xlsx-v2"
        val SUPPORTED_RULES_VERSIONS = setOf(XLSX_V1, XLSX_V2)
        const val SETTINGS_SHEET_NAME = "BILGI_AYARLAR"
        const val HEADER_ROW = 1
        const val SETTINGS_HEADER_ROW = 5
        const val FIRST_SETTING_ROW = 6
        const val LAST_SETTING_ROW = 19
        const val SETTINGS_NAME_COLUMN = 1
        const val SETTINGS_VALUE_COLUMN = 2
        const val SETTINGS_DESCRIPTION_COLUMN = 3
        const val UNIT_COLUMN = 1
        const val TOPIC_COLUMN = 2
        const val TEST_NUMBER_COLUMN = 3
        const val TEST_MODE_COLUMN = 4
        const val RECORD_TYPE_COLUMN = 5
        const val TARGET_TEXT_COLUMN = 6
        const val REQUIRED_MULTIPLE_CHOICE_WRONG_ANSWERS = 3
        const val MAX_TEST_SIZE = 10_000
        const val MIN_COMPLETION_PERCENT = 50
        const val MAX_COMPLETION_PERCENT = 100
        const val CLOZE_MARKER = "---"
        const val PRICE_APPLICATION_LITERAL = "Uygulamadan ayarlanır"
        const val TYPED_ALTERNATIVE_LITERAL = "En fazla 1"
        const val OFFLINE_MODE_LITERAL = "Skorsuz pratik"
        const val ENABLED_LITERAL = "Açık"
        const val DISABLED_LITERAL = "Kapalı"
        const val HIDDEN_YES = "Evet"
        const val HIDDEN_NO = "Hayır"

        val POSITIVE_INTEGER = Regex("[1-9][0-9]*")
        val PERCENTAGE = Regex("([0-9]{1,3})%")
        val ALLOWED_CONTENT_CONTROL_POINTS = setOf('\t'.code, '\n'.code, '\r'.code)
        val ALLOWED_CONTENT_FORMAT_POINTS = setOf(0x200c, 0x200d)

        const val COURSE_NAME = "Kurs Adı"
        const val TARGET_LANGUAGE_CODE = "Hedef Dil Kodu"
        const val TARGET_LANGUAGE_NAME = "Hedef Dil Adı"
        const val SUPPORT_LANGUAGES = "Destek Dilleri"
        const val DEFAULT_SUPPORT_LANGUAGE = "Varsayılan Destek Dili"
        const val DEFAULT_TEST_MODE = "Varsayılan Test Modu"
        const val COURSE_VISIBILITY = "Kurs Görünürlüğü"
        const val PRICE = "Fiyat"
        const val DEFAULT_TEST_SIZE = "Varsayılan Test Soru Sayısı"
        const val MINIMUM_LAST_GROUP = "Son Grup Minimum Soru"
        const val FILL_FIXED_TESTS = "Test No Verilen Testleri Varsayılan Soru Sayısına Tamamla"
        const val COMPLETION_THRESHOLD = "Test Tamamlama Eşiği"
        const val TYPED_ALTERNATIVE = "Yazmalı Alternatif Cevap"
        const val OFFLINE_MODE = "Offline Mod"

        val SETTING_NAMES = listOf(
            COURSE_NAME,
            TARGET_LANGUAGE_CODE,
            TARGET_LANGUAGE_NAME,
            SUPPORT_LANGUAGES,
            DEFAULT_SUPPORT_LANGUAGE,
            DEFAULT_TEST_MODE,
            COURSE_VISIBILITY,
            PRICE,
            DEFAULT_TEST_SIZE,
            MINIMUM_LAST_GROUP,
            FILL_FIXED_TESTS,
            COMPLETION_THRESHOLD,
            TYPED_ALTERNATIVE,
            OFFLINE_MODE,
        )
        val SETTINGS_HEADER = listOf("Ayar", "Değer", "Açıklama")

        val HEADER_PREFIX = listOf(
            "Ünite",
            "Konu",
            "Test No",
            "Test Modu (Opsiyonel)",
            "Kayıt Türü",
            "Hedef Kelime/İfade",
        )
        val HEADER_SUFFIX = listOf(
            "Cümle (---)",
            "Doğru Cevap",
            "Alternatif Doğru Cevap",
            "Yanlış 1",
            "Yanlış 2",
            "Yanlış 3",
            "Eşleştirme Grubu",
            "Gizli mi?",
            "Not",
        )

        val DEFAULT_MODES = mapOf(
            "Karışık" to ResolvedTestMode.MIXED,
            "Kelime" to ResolvedTestMode.WORD,
            "Eşleştirme" to ResolvedTestMode.MATCHING,
            "Seçenekli boşluk" to ResolvedTestMode.MULTIPLE_CHOICE_CLOZE,
            "Yazmalı boşluk" to ResolvedTestMode.TYPED_CLOZE,
        )
        val ROW_MODES = mapOf(
            "Varsayılan" to WorkbookTestModeDirective.DEFAULT,
            "Karışık" to WorkbookTestModeDirective.MIXED,
            "Kelime" to WorkbookTestModeDirective.WORD,
            "Eşleştirme" to WorkbookTestModeDirective.MATCHING,
            "Seçenekli boşluk" to WorkbookTestModeDirective.MULTIPLE_CHOICE_CLOZE,
            "Yazmalı boşluk" to WorkbookTestModeDirective.TYPED_CLOZE,
        )
        val RECORD_TYPES = mapOf(
            "Kelime" to WorkbookRecordType.WORD,
            "Cümle Seçenekli" to WorkbookRecordType.MULTIPLE_CHOICE_CLOZE,
            "Cümle Yazmalı" to WorkbookRecordType.TYPED_CLOZE,
        )
        val COURSE_VISIBILITIES = mapOf(
            "Public" to CourseVisibility.PUBLIC,
            "Private" to CourseVisibility.PRIVATE,
        )
    }
}

private class CappedWorkbookIssueList(
    private val maximumSize: Int,
    private val checkpoint: () -> Unit,
) : AbstractMutableList<WorkbookImportIssue>() {
    private val delegate = ArrayList<WorkbookImportIssue>(maximumSize)

    override val size: Int
        get() = delegate.size

    override fun get(index: Int): WorkbookImportIssue = delegate[index]

    override fun add(index: Int, element: WorkbookImportIssue) {
        checkpoint()
        if (delegate.size < maximumSize) delegate.add(index.coerceAtMost(delegate.size), element)
    }

    override fun removeAt(index: Int): WorkbookImportIssue = delegate.removeAt(index)

    override fun set(index: Int, element: WorkbookImportIssue): WorkbookImportIssue = delegate.set(index, element)
}

private fun Int.isXlsxV1DefaultIgnorable(): Boolean =
    this == 0x00ad ||
        this == 0x034f ||
        this == 0x061c ||
        this in 0x115f..0x1160 ||
        this in 0x17b4..0x17b5 ||
        this in 0x180b..0x180f ||
        this in 0x200b..0x200f ||
        this in 0x202a..0x202e ||
        this in 0x2060..0x206f ||
        this == 0x3164 ||
        this in 0xfe00..0xfe0f ||
        this == 0xfeff ||
        this == 0xffa0 ||
        this in 0xfff0..0xfff8 ||
        this in 0x1bca0..0x1bca3 ||
        this in 0x1d173..0x1d17a ||
        this in 0xe0000..0xe0fff
