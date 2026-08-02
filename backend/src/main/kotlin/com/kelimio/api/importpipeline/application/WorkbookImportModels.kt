package com.kelimio.api.importpipeline.application

import com.kelimio.api.importpipeline.domain.CourseContentPath
import com.kelimio.api.importpipeline.domain.ImportIssueCode
import com.kelimio.api.importpipeline.domain.ImportIssueSeverity
import com.kelimio.api.importpipeline.domain.ImportValidationIssue
import com.kelimio.api.importpipeline.domain.ResolvedTestMode
import com.kelimio.api.importpipeline.domain.TestPlan
import com.kelimio.api.importpipeline.domain.WorkbookRecordType
import com.kelimio.api.importpipeline.domain.WorkbookRowSource
import com.kelimio.api.importpipeline.domain.WorkbookTestModeDirective
import java.util.Collections

class CourseImportSettings(
    val rulesVersion: String,
    val courseName: String,
    val targetLanguageCode: String,
    val targetLanguageName: String,
    supportLanguageCodes: Collection<String>,
    val defaultSupportLanguageCode: String,
    val defaultTestMode: ResolvedTestMode,
    val visibility: CourseVisibility,
    val targetTestSize: Int,
    val minimumLastAutomaticTestSize: Int,
    val fillFixedTests: Boolean,
    val completionThresholdPercent: Int,
) {
    val supportLanguageCodes: List<String> = immutableList(supportLanguageCodes)
    val pricingSource: CoursePricingSource = CoursePricingSource.APPLICATION
    val maximumTypedAlternativeAnswers: Int = 1
    val offlineMode: OfflineCourseMode = OfflineCourseMode.SCORELESS_PRACTICE

    init {
        require(rulesVersion.isNotBlank())
        require(courseName.isNotBlank())
        require(targetLanguageCode.isNotBlank())
        require(targetLanguageName.isNotBlank())
        require(supportLanguageCodes.isNotEmpty())
        require(supportLanguageCodes.distinct().size == supportLanguageCodes.size)
        require(defaultSupportLanguageCode in supportLanguageCodes)
        require(targetLanguageCode !in supportLanguageCodes)
        require(targetTestSize > 0)
        require(minimumLastAutomaticTestSize in 1..targetTestSize)
        require(completionThresholdPercent in 50..100)
    }
}

enum class CourseVisibility {
    PUBLIC,
    PRIVATE,
}

enum class CoursePricingSource {
    APPLICATION,
}

enum class OfflineCourseMode {
    SCORELESS_PRACTICE,
}

class NormalizedWorkbookRow(
    val source: WorkbookRowSource,
    val path: CourseContentPath,
    val fixedTestNumber: Int?,
    val requestedMode: WorkbookTestModeDirective?,
    val recordType: WorkbookRecordType,
    val targetText: String,
    translations: Map<String, String>,
    val sentence: String?,
    val correctAnswer: String?,
    val alternativeCorrectAnswer: String?,
    wrongAnswers: Collection<String>,
    val matchingGroup: String?,
    val hidden: Boolean,
    val note: String?,
    val normalizedContentSha256: String,
) {
    val translations: Map<String, String> = immutableMap(translations)
    val wrongAnswers: List<String> = immutableList(wrongAnswers)
}

data class WorkbookCellSource(
    val sheetOrdinal: Int,
    val sheetName: String,
    val rowNumber: Int,
    val columnNumber: Int? = null,
    val reference: String? = null,
) { override fun toString(): String = "WorkbookCellSource(redacted)" }

enum class WorkbookImportIssueSeverity {
    WARNING,
    ERROR,
}

enum class WorkbookImportIssueCode {
    SETTINGS_SHEET_COUNT,
    SETTINGS_ROW_MISSING,
    SETTING_NAME_MISSING,
    SETTING_VALUE_MISSING,
    UNKNOWN_SETTING,
    DUPLICATE_SETTING,
    INVALID_SETTING_VALUE,
    CONTENT_SHEET_MISSING,
    CONTENT_ROW_MISSING,
    LEVEL_CONTENT_ROW_MISSING,
    INVALID_SHEET_NAME,
    DUPLICATE_SHEET_NAME,
    DUPLICATE_SHEET_ORDINAL,
    DUPLICATE_CELL,
    HEADER_ROW_MISSING,
    HEADER_COLUMN_COUNT,
    HEADER_MISMATCH,
    INVALID_STRUCTURAL_TEXT,
    INVALID_TEXT,
    REQUIRED_FIELD_MISSING,
    UNEXPECTED_FIELD_VALUE,
    INVALID_TEST_NUMBER,
    INVALID_TEST_MODE,
    INVALID_RECORD_TYPE,
    INVALID_HIDDEN_VALUE,
    MISSING_TRANSLATION,
    INVALID_CLOZE_PLACEHOLDER,
    INVALID_WRONG_ANSWER_COUNT,
    DUPLICATE_ANSWER_OPTION,
    INCOMPATIBLE_TEST_MODE,
    UNSUPPORTED_TEST_MODE,
    MATCHING_GROUP_REQUIRED,
    MATCHING_GROUP_CROSSES_TEST,
    INVALID_MATCHING_GROUP_SIZE,
    INVALID_MATCHING_LABEL,
    DUPLICATE_MATCHING_LABEL,
    UNSUPPORTED_HIDDEN_CONTENT,
    PLANNING_DUPLICATE_SOURCE_ROW,
    PLANNING_MANUAL_TEST_EXCEEDS_TARGET,
    PLANNING_TEST_MODE_CONFLICT,
    PLANNING_AUTOMATIC_TEST_NUMBER_OVERFLOW,
}

data class WorkbookImportIssue(
    val severity: WorkbookImportIssueSeverity,
    val code: WorkbookImportIssueCode,
    val source: WorkbookCellSource?,
    val message: String,
) { override fun toString(): String = "WorkbookImportIssue(redacted)" }

class WorkbookImportPreview internal constructor(
    val rulesVersion: String,
    val settings: CourseImportSettings?,
    rows: Collection<NormalizedWorkbookRow>,
    val plan: TestPlan?,
    val composition: WorkbookQuestionComposition?,
    issues: Collection<WorkbookImportIssue>,
    checkpoint: () -> Unit = {},
) {
    val rows: List<NormalizedWorkbookRow> = immutableList(rows)
    val issues: List<WorkbookImportIssue> = immutableList(issues)
    val isValid: Boolean =
        settings != null &&
            plan?.isValid == true &&
            composition != null &&
            this.issues.none { it.severity == WorkbookImportIssueSeverity.ERROR }

    val allocationSha256: String? = if (isValid) checkNotNull(plan).allocationSha256(checkpoint) else null
    val previewSha256: String? = if (isValid) {
        CanonicalWorkbookImportPreviewDigest.sha256(
            settings = checkNotNull(settings),
            allocationSha256 = checkNotNull(allocationSha256),
        )
    } else {
        null
    }
    val levelCount: Int
    val unitCount: Int
    val topicCount: Int
    val testCount: Int = plan?.tests?.size ?: 0

    init {
        val levels = mutableSetOf<String>()
        val units = mutableSetOf<Pair<String, String>>()
        val topics = mutableSetOf<Triple<String, String, String>>()
        this.rows.forEach { row ->
            checkpoint()
            levels += row.path.level
            units += row.path.level to row.path.unit
            topics += Triple(row.path.level, row.path.unit, row.path.topic)
        }
        levelCount = levels.size
        unitCount = units.size
        topicCount = topics.size
    }
}

internal fun ImportValidationIssue.toWorkbookIssue(): WorkbookImportIssue = WorkbookImportIssue(
    severity = when (severity) {
        ImportIssueSeverity.WARNING -> WorkbookImportIssueSeverity.WARNING
        ImportIssueSeverity.ERROR -> WorkbookImportIssueSeverity.ERROR
    },
    code = when (code) {
        ImportIssueCode.DUPLICATE_SOURCE_ROW -> WorkbookImportIssueCode.PLANNING_DUPLICATE_SOURCE_ROW
        ImportIssueCode.MANUAL_TEST_EXCEEDS_TARGET -> WorkbookImportIssueCode.PLANNING_MANUAL_TEST_EXCEEDS_TARGET
        ImportIssueCode.TEST_MODE_CONFLICT -> WorkbookImportIssueCode.PLANNING_TEST_MODE_CONFLICT
        ImportIssueCode.AUTOMATIC_TEST_NUMBER_OVERFLOW ->
            WorkbookImportIssueCode.PLANNING_AUTOMATIC_TEST_NUMBER_OVERFLOW
    },
    source = source?.let {
        WorkbookCellSource(
            sheetOrdinal = it.sheetOrdinal,
            sheetName = it.sheetName,
            rowNumber = it.rowNumber,
        )
    },
    message = message,
)

internal fun <T> immutableList(values: Collection<T>): List<T> =
    Collections.unmodifiableList(ArrayList(values))

internal fun <K, V> immutableMap(values: Map<K, V>): Map<K, V> =
    Collections.unmodifiableMap(LinkedHashMap(values))
