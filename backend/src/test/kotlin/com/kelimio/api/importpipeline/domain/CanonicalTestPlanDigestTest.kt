package com.kelimio.api.importpipeline.domain

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.security.MessageDigest

class CanonicalTestPlanDigestTest {
    private val policy = TestAllocationPolicy("xlsx-v1", 20, 10, false, ResolvedTestMode.MIXED)

    @Test
    fun `digest is deterministic across input collection order`() {
        val rows = listOf(row(2), row(3), row(4, fixed = 1), row(5))

        val forward = TestAllocationPlanner.plan(rows, policy).allocationSha256()
        val reverse = TestAllocationPlanner.plan(rows.reversed(), policy).allocationSha256()

        assertThat(forward).isEqualTo(reverse).matches("[0-9a-f]{64}")
    }

    @Test
    fun `digest changes when normalized row content changes`() {
        val original = listOf(row(2), row(3))
        val changed = original.toMutableList().also {
            it[1] = it[1].copy(normalizedContentSha256 = sha256("changed"))
        }

        val originalDigest = TestAllocationPlanner.plan(original, policy).allocationSha256()
        val changedDigest = TestAllocationPlanner.plan(changed, policy).allocationSha256()

        assertThat(changedDigest).isNotEqualTo(originalDigest)
    }

    @Test
    fun `digest changes with allocation policy`() {
        val rows = (1..25).map(::row)
        val first = TestAllocationPlanner.plan(rows, policy).allocationSha256()
        val second = TestAllocationPlanner.plan(
            rows,
            policy.copy(targetTestSize = 15, minimumLastAutomaticTestSize = 8),
        ).allocationSha256()

        assertThat(second).isNotEqualTo(first)
    }

    @Test
    fun `invalid plans cannot produce an allocation digest`() {
        val rows = listOf(
            row(2, mode = WorkbookTestModeDirective.WORD),
            row(3, mode = WorkbookTestModeDirective.MATCHING),
        )
        val plan = TestAllocationPlanner.plan(rows, policy)

        assertThatThrownBy(plan::allocationSha256)
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("invalid test plan")
    }

    private fun row(
        rowNumber: Int,
        fixed: Int? = null,
        mode: WorkbookTestModeDirective? = null,
    ) = TestPlanningRow(
        source = WorkbookRowSource(0, "A1", rowNumber),
        path = CourseContentPath("A1", "Unit", "Topic"),
        fixedTestNumber = fixed,
        requestedMode = mode,
        recordType = WorkbookRecordType.WORD,
        normalizedContentSha256 = sha256("row-$rowNumber"),
    )

    private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray())
        .joinToString("") { byte -> "%02x".format(byte) }
}
