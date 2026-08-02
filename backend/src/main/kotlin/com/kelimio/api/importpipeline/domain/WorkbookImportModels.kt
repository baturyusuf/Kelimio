package com.kelimio.api.importpipeline.domain

import java.util.Collections

/**
 * Stable, physical source coordinate. Sheet ordinals are zero-based and row numbers are one-based.
 */
data class WorkbookRowSource(
    val sheetOrdinal: Int,
    val sheetName: String,
    val rowNumber: Int,
) : Comparable<WorkbookRowSource> {
    init {
        require(sheetOrdinal >= 0) { "Sheet ordinal must not be negative" }
        require(sheetName.isNotBlank()) { "Sheet name must not be blank" }
        require(rowNumber > 0) { "Workbook row number must be positive" }
    }

    override fun compareTo(other: WorkbookRowSource): Int =
        compareValuesBy(
            this,
            other,
            WorkbookRowSource::sheetOrdinal,
            WorkbookRowSource::rowNumber,
            WorkbookRowSource::sheetName,
        )

    override fun toString(): String = "WorkbookRowSource(redacted)"
}

data class CourseContentPath(
    val level: String,
    val unit: String,
    val topic: String,
) {
    init {
        require(level.isNotBlank()) { "Level must not be blank" }
        require(unit.isNotBlank()) { "Unit must not be blank" }
        require(topic.isNotBlank()) { "Topic must not be blank" }
    }

    override fun toString(): String = "CourseContentPath(redacted)"
}

/** A workbook directive. DEFAULT is resolved to the course default after allocation. */
enum class WorkbookTestModeDirective {
    DEFAULT,
    MIXED,
    WORD,
    MATCHING,
    MULTIPLE_CHOICE_CLOZE,
    TYPED_CLOZE,
}

enum class ResolvedTestMode {
    MIXED,
    WORD,
    MATCHING,
    MULTIPLE_CHOICE_CLOZE,
    TYPED_CLOZE,
}

enum class WorkbookRecordType {
    WORD,
    MULTIPLE_CHOICE_CLOZE,
    TYPED_CLOZE,
}

/**
 * The planner deliberately carries only normalized, schema-independent row identity. The caller
 * computes [normalizedContentSha256] from every normalized content field so the allocation digest
 * can bind the plan to content without coupling this package to a persistence schema.
 */
data class TestPlanningRow(
    val source: WorkbookRowSource,
    val path: CourseContentPath,
    val fixedTestNumber: Int?,
    val requestedMode: WorkbookTestModeDirective?,
    val recordType: WorkbookRecordType,
    val normalizedContentSha256: String,
) {
    init {
        require(fixedTestNumber == null || fixedTestNumber > 0) { "Fixed test number must be positive" }
        require(SHA_256_PATTERN.matches(normalizedContentSha256)) {
            "Normalized content fingerprint must be a lowercase SHA-256 value"
        }
    }

    private companion object {
        val SHA_256_PATTERN = Regex("[0-9a-f]{64}")
    }

    override fun toString(): String = "TestPlanningRow(redacted)"
}

data class TestAllocationPolicy(
    val rulesVersion: String,
    val targetTestSize: Int,
    val minimumLastAutomaticTestSize: Int,
    val fillFixedTests: Boolean,
    val defaultMode: ResolvedTestMode,
) {
    init {
        require(rulesVersion.isNotBlank()) { "Rules version must not be blank" }
        require(targetTestSize > 0) { "Target test size must be positive" }
        require(minimumLastAutomaticTestSize in 1..targetTestSize) {
            "Minimum last automatic test size must be between one and the target test size"
        }
    }
}

enum class TestAllocationKind {
    FIXED,
    AUTOMATIC,
}

enum class RowAllocationReason {
    FIXED_DECLARATION,
    FIXED_TEST_FILL,
    AUTOMATIC,
}

data class PlannedRow(
    val row: TestPlanningRow,
    val reason: RowAllocationReason,
) { override fun toString(): String = "PlannedRow(redacted)" }

class PlannedTest internal constructor(
    val path: CourseContentPath,
    val number: Int,
    val allocationKind: TestAllocationKind,
    val resolvedMode: ResolvedTestMode?,
    rows: Collection<PlannedRow>,
) {
    val rows: List<PlannedRow> = immutableList(rows)

    init {
        require(number > 0) { "Planned test number must be positive" }
        require(rows.isNotEmpty()) { "A planned test cannot be empty" }
    }
}

enum class ImportIssueSeverity {
    WARNING,
    ERROR,
}

enum class ImportIssueCode {
    DUPLICATE_SOURCE_ROW,
    MANUAL_TEST_EXCEEDS_TARGET,
    AUTOMATIC_TEST_NUMBER_OVERFLOW,
    TEST_MODE_CONFLICT,
}

data class ImportValidationIssue(
    val severity: ImportIssueSeverity,
    val code: ImportIssueCode,
    val source: WorkbookRowSource?,
    val path: CourseContentPath?,
    val testNumber: Int?,
    val message: String,
) { override fun toString(): String = "ImportValidationIssue(redacted)" }

class TestPlan internal constructor(
    val policy: TestAllocationPolicy,
    tests: Collection<PlannedTest>,
    issues: Collection<ImportValidationIssue>,
) {
    val tests: List<PlannedTest> = immutableList(tests)
    val issues: List<ImportValidationIssue> = immutableList(issues)
    val isValid: Boolean = this.issues.none { it.severity == ImportIssueSeverity.ERROR }

    fun allocationSha256(checkpoint: () -> Unit = {}): String = CanonicalTestPlanDigest.sha256(this, checkpoint)
}

class ModeResolution internal constructor(
    val mode: ResolvedTestMode?,
    issues: Collection<ImportValidationIssue>,
) {
    val issues: List<ImportValidationIssue> = immutableList(issues)
    val isValid: Boolean = mode != null && this.issues.none { it.severity == ImportIssueSeverity.ERROR }
}

internal fun <T> immutableList(values: Collection<T>): List<T> =
    Collections.unmodifiableList(ArrayList(values))
