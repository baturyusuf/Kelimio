package com.kelimio.api.importpipeline.domain

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.security.MessageDigest
import kotlin.random.Random

class TestAllocationPlannerTest {
    @Test
    fun `fill enabled grows fixed tests first and creates target-sized automatic tests`() {
        val rows = (1..100).map { number -> row(number, fixedTestNumber = if (number <= 3) 1 else null) }

        val plan = TestAllocationPlanner.plan(rows, policy(fillFixed = true))

        assertThat(plan.isValid).isTrue()
        assertThat(plan.tests.map { it.number }).containsExactly(1, 2, 3, 4, 5)
        assertThat(plan.tests.map { it.rows.size }).containsExactly(20, 20, 20, 20, 20)
        assertThat(plan.tests.first().rows.map { it.reason }.count { it == RowAllocationReason.FIXED_TEST_FILL })
            .isEqualTo(17)
    }

    @Test
    fun `fill disabled leaves fixed tests unchanged and allocates the complete pool`() {
        val rows = (1..100).map { number -> row(number, fixedTestNumber = if (number <= 3) 1 else null) }

        val plan = TestAllocationPlanner.plan(rows, policy(fillFixed = false))

        assertThat(plan.tests.map { it.number }).containsExactly(1, 2, 3, 4, 5, 6)
        assertThat(plan.tests.map { it.rows.size }).containsExactly(3, 20, 20, 20, 20, 17)
    }

    @Test
    fun `fixed test gaps are retained and automatic numbers start after the maximum fixed number`() {
        val plan = TestAllocationPlanner.plan(
            rows = listOf(
                row(2, fixedTestNumber = 3),
                row(3),
                row(4, fixedTestNumber = 1),
                row(5),
            ),
            policy = policy(fillFixed = false),
        )

        assertThat(plan.tests.map { it.number }).containsExactly(1, 3, 4)
        assertThat(plan.tests.map { it.allocationKind }).containsExactly(
            TestAllocationKind.FIXED,
            TestAllocationKind.FIXED,
            TestAllocationKind.AUTOMATIC,
        )
    }

    @Test
    fun `small automatic tail merges only into a preceding automatic test`() {
        val expected = mapOf(
            7 to listOf(7),
            27 to listOf(27),
            30 to listOf(20, 10),
            41 to listOf(20, 21),
        )

        expected.forEach { (poolSize, expectedSizes) ->
            val plan = TestAllocationPlanner.plan((1..poolSize).map(::row), policy(fillFixed = false))
            assertThat(plan.tests.map { it.rows.size })
                .describedAs("automatic chunk sizes for pool %s", poolSize)
                .containsExactlyElementsOf(expectedSizes)
        }

        val fixedAndSmallPool = listOf(row(1, fixedTestNumber = 1)) +
            (2..20).map { row(it, fixedTestNumber = 1) } +
            (21..27).map(::row)
        val plan = TestAllocationPlanner.plan(fixedAndSmallPool, policy(fillFixed = false))

        assertThat(plan.tests.map { it.rows.size }).containsExactly(20, 7)
        assertThat(plan.tests.last().allocationKind).isEqualTo(TestAllocationKind.AUTOMATIC)
    }

    @Test
    fun `oversized fixed tests remain intact and produce an explanatory warning`() {
        val plan = TestAllocationPlanner.plan(
            rows = (1..21).map { row(it, fixedTestNumber = 1) },
            policy = policy(fillFixed = true),
        )

        assertThat(plan.isValid).isTrue()
        assertThat(plan.tests).hasSize(1)
        assertThat(plan.tests.single().rows).hasSize(21)
        assertThat(plan.issues).hasSize(1)
        assertThat(plan.issues.single().code).isEqualTo(ImportIssueCode.MANUAL_TEST_EXCEEDS_TARGET)
        assertThat(plan.issues.single().severity).isEqualTo(ImportIssueSeverity.WARNING)
    }

    @Test
    fun `fixed tests are filled in ascending test order`() {
        val plan = TestAllocationPlanner.plan(
            rows = listOf(
                row(2, fixedTestNumber = 2),
                row(3, fixedTestNumber = 1),
                row(4),
                row(5),
                row(6),
            ),
            policy = TestAllocationPolicy("xlsx-v1", 3, 2, true, ResolvedTestMode.MIXED),
        )

        assertThat(plan.tests.map { it.number }).containsExactly(1, 2)
        assertThat(plan.tests[0].rows.map { it.row.source.rowNumber }).containsExactly(3, 4, 5)
        assertThat(plan.tests[1].rows.map { it.row.source.rowNumber }).containsExactly(2, 6)
    }

    @Test
    fun `mode is resolved after automatic rows have been assigned to a fixed test`() {
        val plan = TestAllocationPlanner.plan(
            rows = listOf(
                row(2, fixedTestNumber = 1, mode = WorkbookTestModeDirective.WORD),
                row(3, mode = WorkbookTestModeDirective.MIXED),
            ),
            policy = TestAllocationPolicy("xlsx-v1", 2, 1, true, ResolvedTestMode.MIXED),
        )

        assertThat(plan.isValid).isFalse()
        assertThat(plan.tests.single().resolvedMode).isNull()
        assertThat(plan.issues.map { it.code })
            .containsExactly(ImportIssueCode.TEST_MODE_CONFLICT)
    }

    @Test
    fun `physical workbook order is stable regardless of caller iteration order`() {
        val input = listOf(row(9), row(2), row(7), row(4))

        val plan = TestAllocationPlanner.plan(
            input,
            TestAllocationPolicy("xlsx-v1", 10, 5, false, ResolvedTestMode.MIXED),
        )

        assertThat(plan.tests.single().rows.map { it.row.source.rowNumber }).containsExactly(2, 4, 7, 9)
    }

    @Test
    fun `duplicate physical row coordinates fail before any allocation`() {
        val first = row(2)
        val duplicate = first.copy(normalizedContentSha256 = sha256("different-content"))

        val plan = TestAllocationPlanner.plan(listOf(first, duplicate), policy(fillFixed = false))

        assertThat(plan.isValid).isFalse()
        assertThat(plan.tests).isEmpty()
        assertThat(plan.issues.map { it.code })
            .containsExactly(ImportIssueCode.DUPLICATE_SOURCE_ROW)
    }

    @Test
    fun `automatic numbering beyond the integer range fails closed instead of wrapping`() {
        val plan = TestAllocationPlanner.plan(
            rows = listOf(
                row(2, fixedTestNumber = Int.MAX_VALUE),
                row(3),
            ),
            policy = policy(fillFixed = false),
        )

        assertThat(plan.isValid).isFalse()
        assertThat(plan.tests).isEmpty()
        assertThat(plan.issues.map { it.code })
            .containsExactly(ImportIssueCode.AUTOMATIC_TEST_NUMBER_OVERFLOW)
    }

    @Test
    fun `maximum fixed number remains valid when no automatic test is needed`() {
        val plan = TestAllocationPlanner.plan(
            rows = listOf(row(2, fixedTestNumber = Int.MAX_VALUE)),
            policy = policy(fillFixed = false),
        )

        assertThat(plan.isValid).isTrue()
        assertThat(plan.tests.map { it.number }).containsExactly(Int.MAX_VALUE)
    }

    @Test
    fun `random valid allocations never lose or duplicate a row and remain group isolated`() {
        repeat(500) { seed ->
            val random = Random(seed)
            val count = random.nextInt(1, 151)
            val target = random.nextInt(1, 21)
            val minimum = random.nextInt(1, target + 1)
            val input = (1..count).map { index ->
                val groupNumber = random.nextInt(0, 4)
                row(
                    rowNumber = index + 1,
                    fixedTestNumber = when (random.nextInt(0, 6)) {
                        0 -> 1
                        1 -> 3
                        else -> null
                    },
                    path = CourseContentPath("A1", "Unit $groupNumber", "Topic $groupNumber"),
                )
            }.shuffled(random)

            val plan = TestAllocationPlanner.plan(
                rows = input,
                policy = TestAllocationPolicy("xlsx-v1", target, minimum, random.nextBoolean(), ResolvedTestMode.MIXED),
            )

            assertThat(plan.isValid).isTrue()
            val plannedRows = plan.tests.flatMap { it.rows }.map { it.row }
            assertThat(plannedRows).hasSize(input.size)
            assertThat(plannedRows.map { it.source }.distinct()).hasSize(input.size)
            assertThat(plannedRows.map { it.source }.toSet()).isEqualTo(input.map { it.source }.toSet())
            plan.tests.forEach { test ->
                assertThat(test.rows.map { it.row.source }).isSorted()
                assertThat(test.rows.map { it.row.path }.distinct()).containsExactly(test.path)
            }
        }
    }

    private fun policy(fillFixed: Boolean) =
        TestAllocationPolicy("xlsx-v1", 20, 10, fillFixed, ResolvedTestMode.MIXED)

    private fun row(
        rowNumber: Int,
        fixedTestNumber: Int? = null,
        mode: WorkbookTestModeDirective? = null,
        path: CourseContentPath = CourseContentPath("A1", "Unit", "Topic"),
    ) = TestPlanningRow(
        source = WorkbookRowSource(0, "A1", rowNumber),
        path = path,
        fixedTestNumber = fixedTestNumber,
        requestedMode = mode,
        recordType = WorkbookRecordType.WORD,
        normalizedContentSha256 = sha256("$rowNumber-${path.unit}-${path.topic}"),
    )

    private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray())
        .joinToString("") { byte -> "%02x".format(byte) }
}
