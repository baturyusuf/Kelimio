package com.kelimio.api.importpipeline.domain

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.ArrayDeque
import java.util.TreeMap

object TestAllocationPlanner {
    fun plan(
        rows: Collection<TestPlanningRow>,
        policy: TestAllocationPolicy,
        checkpoint: () -> Unit = {},
    ): TestPlan {
        checkpoint()
        val orderedRows = rows.sortedBy(TestPlanningRow::source)
        checkpoint()
        val duplicateIssues = duplicateSourceIssues(orderedRows, checkpoint)
        if (duplicateIssues.isNotEmpty()) {
            return TestPlan(policy = policy, tests = emptyList(), issues = duplicateIssues)
        }

        val groupedRows = linkedMapOf<CourseContentPath, MutableList<TestPlanningRow>>()
        orderedRows.forEach { row ->
            checkpoint()
            groupedRows.getOrPut(row.path, ::mutableListOf).add(row)
        }

        val plannedTests = mutableListOf<PlannedTest>()
        val issues = mutableListOf<ImportValidationIssue>()
        groupedRows.forEach { (path, groupRows) ->
            checkpoint()
            val groupPlan = planGroup(path, groupRows, policy, checkpoint)
            plannedTests += groupPlan.first
            issues += groupPlan.second
        }
        return TestPlan(policy = policy, tests = plannedTests, issues = issues)
    }

    private fun planGroup(
        path: CourseContentPath,
        rows: List<TestPlanningRow>,
        policy: TestAllocationPolicy,
        checkpoint: () -> Unit,
    ): Pair<List<PlannedTest>, List<ImportValidationIssue>> {
        val issues = mutableListOf<ImportValidationIssue>()
        val fixed = TreeMap<Int, MutableList<PlannedRow>>()
        val unassigned = ArrayDeque<TestPlanningRow>()

        rows.forEach { row ->
            checkpoint()
            val fixedNumber = row.fixedTestNumber
            if (fixedNumber == null) {
                unassigned.addLast(row)
            } else {
                fixed.getOrPut(fixedNumber, ::mutableListOf)
                    .add(PlannedRow(row, RowAllocationReason.FIXED_DECLARATION))
            }
        }

        fixed.forEach { (testNumber, plannedRows) ->
            checkpoint()
            if (plannedRows.size > policy.targetTestSize) {
                issues += ImportValidationIssue(
                    severity = ImportIssueSeverity.WARNING,
                    code = ImportIssueCode.MANUAL_TEST_EXCEEDS_TARGET,
                    source = plannedRows.first().row.source,
                    path = path,
                    testNumber = testNumber,
                    message =
                        "Fixed test $testNumber contains ${plannedRows.size} rows; " +
                            "target size is ${policy.targetTestSize}",
                )
            }
            if (policy.fillFixedTests) {
                repeat(minOf(policy.targetTestSize - plannedRows.size, unassigned.size).coerceAtLeast(0)) {
                    plannedRows += PlannedRow(unassigned.removeFirst(), RowAllocationReason.FIXED_TEST_FILL)
                }
            }
        }

        val testDrafts = mutableListOf<TestDraft>()
        fixed.forEach { (number, plannedRows) ->
            testDrafts += TestDraft(number, TestAllocationKind.FIXED, plannedRows)
        }

        val automaticChunks = mutableListOf<MutableList<PlannedRow>>()
        while (unassigned.isNotEmpty()) {
            checkpoint()
            val chunk = mutableListOf<PlannedRow>()
            repeat(minOf(policy.targetTestSize, unassigned.size)) {
                chunk += PlannedRow(unassigned.removeFirst(), RowAllocationReason.AUTOMATIC)
            }
            automaticChunks += chunk
        }
        if (
            automaticChunks.size > 1 &&
            automaticChunks.last().size < policy.minimumLastAutomaticTestSize
        ) {
            val smallTail = automaticChunks.removeLast()
            automaticChunks.last() += smallTail
        }

        val maximumFixedNumber = fixed.lastKeyOrNull() ?: 0
        val availableAutomaticNumbers = Int.MAX_VALUE.toLong() - maximumFixedNumber.toLong()
        if (automaticChunks.size.toLong() > availableAutomaticNumbers) {
            issues += ImportValidationIssue(
                severity = ImportIssueSeverity.ERROR,
                code = ImportIssueCode.AUTOMATIC_TEST_NUMBER_OVERFLOW,
                source = automaticChunks.first().first().row.source,
                path = path,
                testNumber = maximumFixedNumber,
                message = "Automatic test numbering would exceed the supported integer range",
            )
            return emptyList<PlannedTest>() to issues
        }

        var nextAutomaticNumber = maximumFixedNumber.toLong() + 1L
        automaticChunks.forEach { chunk ->
            checkpoint()
            testDrafts += TestDraft(nextAutomaticNumber.toInt(), TestAllocationKind.AUTOMATIC, chunk)
            nextAutomaticNumber += 1L
        }

        val tests = testDrafts.map { draft ->
            checkpoint()
            val physicalRows = draft.rows.sortedBy { it.row.source }
            checkpoint()
            val resolution = TestModeResolver.resolve(
                rows = physicalRows.map(PlannedRow::row),
                defaultMode = policy.defaultMode,
                testNumber = draft.number,
            )
            issues += resolution.issues
            PlannedTest(
                path = path,
                number = draft.number,
                allocationKind = draft.kind,
                resolvedMode = resolution.mode,
                rows = physicalRows,
            )
        }
        return tests to issues
    }

    private fun duplicateSourceIssues(
        rows: List<TestPlanningRow>,
        checkpoint: () -> Unit,
    ): List<ImportValidationIssue> {
        val seen = mutableSetOf<Pair<Int, Int>>()
        return rows.mapNotNull { row ->
            checkpoint()
            val position = row.source.sheetOrdinal to row.source.rowNumber
            if (seen.add(position)) {
                null
            } else {
                ImportValidationIssue(
                    severity = ImportIssueSeverity.ERROR,
                    code = ImportIssueCode.DUPLICATE_SOURCE_ROW,
                    source = row.source,
                    path = row.path,
                    testNumber = row.fixedTestNumber,
                    message =
                        "Workbook source row is repeated at sheet ${row.source.sheetOrdinal}, " +
                            "row ${row.source.rowNumber}",
                )
            }
        }
    }

    private data class TestDraft(
        val number: Int,
        val kind: TestAllocationKind,
        val rows: List<PlannedRow>,
    )

    private fun <K, V> TreeMap<K, V>.lastKeyOrNull(): K? = if (isEmpty()) null else lastKey()
}

/**
 * Canonical allocation-only digest. The application layer must bind course
 * settings and this value into a complete preview digest before approval.
 */
object CanonicalTestPlanDigest {
    private const val FORMAT_VERSION = "kelimio-test-allocation-v1"
    private const val HEX_DIGITS = "0123456789abcdef"

    fun sha256(plan: TestPlan, checkpoint: () -> Unit = {}): String {
        require(plan.isValid) { "An invalid test plan cannot produce an allocation digest" }
        val bytes = ByteArrayOutputStream().use { output ->
            DataOutputStream(output).use { data -> writePlan(data, plan, checkpoint) }
            output.toByteArray()
        }
        return MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .fold(StringBuilder(64)) { result, byte ->
                val unsigned = byte.toInt() and 0xff
                result.append(HEX_DIGITS[unsigned ushr 4])
                result.append(HEX_DIGITS[unsigned and 0x0f])
            }
            .toString()
    }

    private fun writePlan(output: DataOutputStream, plan: TestPlan, checkpoint: () -> Unit) {
        checkpoint()
        output.writeString(FORMAT_VERSION)
        output.writeString(plan.policy.rulesVersion)
        output.writeInt(plan.policy.targetTestSize)
        output.writeInt(plan.policy.minimumLastAutomaticTestSize)
        output.writeBoolean(plan.policy.fillFixedTests)
        output.writeString(plan.policy.defaultMode.name)
        output.writeInt(plan.tests.size)
        plan.tests.forEach { test ->
            checkpoint()
            output.writeString(test.path.level)
            output.writeString(test.path.unit)
            output.writeString(test.path.topic)
            output.writeInt(test.number)
            output.writeString(test.allocationKind.name)
            output.writeString(checkNotNull(test.resolvedMode).name)
            output.writeInt(test.rows.size)
            test.rows.forEach { planned ->
                checkpoint()
                val row = planned.row
                output.writeInt(row.source.sheetOrdinal)
                output.writeString(row.source.sheetName)
                output.writeInt(row.source.rowNumber)
                output.writeNullableInt(row.fixedTestNumber)
                output.writeNullableString(row.requestedMode?.name)
                output.writeString(row.recordType.name)
                output.writeString(row.normalizedContentSha256)
                output.writeString(planned.reason.name)
            }
        }
    }

    private fun DataOutputStream.writeString(value: String) {
        val bytes = value.toByteArray(StandardCharsets.UTF_8)
        writeInt(bytes.size)
        write(bytes)
    }

    private fun DataOutputStream.writeNullableString(value: String?) {
        writeBoolean(value != null)
        if (value != null) writeString(value)
    }

    private fun DataOutputStream.writeNullableInt(value: Int?) {
        writeBoolean(value != null)
        if (value != null) writeInt(value)
    }
}
