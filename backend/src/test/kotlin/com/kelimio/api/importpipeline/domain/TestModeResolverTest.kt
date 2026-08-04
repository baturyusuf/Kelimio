package com.kelimio.api.importpipeline.domain

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.security.MessageDigest

class TestModeResolverTest {
    @Test
    fun `all blank mode cells inherit the course default after allocation`() {
        val result = TestModeResolver.resolve(
            rows = listOf(row(2), row(3)),
            defaultMode = ResolvedTestMode.MIXED,
            testNumber = 1,
        )

        assertThat(result.isValid).isTrue()
        assertThat(result.mode).isEqualTo(ResolvedTestMode.MIXED)
        assertThat(result.issues).isEmpty()
    }

    @Test
    fun `one explicit mode controls all blank rows in the allocated test`() {
        val result = TestModeResolver.resolve(
            rows = listOf(row(2), row(3, WorkbookTestModeDirective.WORD), row(4)),
            defaultMode = ResolvedTestMode.MIXED,
            testNumber = 7,
        )

        assertThat(result.mode).isEqualTo(ResolvedTestMode.WORD)
        assertThat(result.isValid).isTrue()
    }

    @Test
    fun `default directive and the same effective explicit mode are compatible`() {
        val result = TestModeResolver.resolve(
            rows = listOf(
                row(2, WorkbookTestModeDirective.DEFAULT),
                row(3, WorkbookTestModeDirective.MIXED),
            ),
            defaultMode = ResolvedTestMode.MIXED,
            testNumber = 1,
        )

        assertThat(result.mode).isEqualTo(ResolvedTestMode.MIXED)
        assertThat(result.isValid).isTrue()
    }

    @Test
    fun `default directive conflicts with an explicit non-default mode`() {
        val result = TestModeResolver.resolve(
            rows = listOf(
                row(2, WorkbookTestModeDirective.DEFAULT),
                row(3, WorkbookTestModeDirective.WORD),
            ),
            defaultMode = ResolvedTestMode.MIXED,
            testNumber = 4,
        )

        assertThat(result.isValid).isFalse()
        assertThat(result.mode).isNull()
        assertThat(result.issues).hasSize(1)
        val issue = result.issues.single()
        assertThat(issue.code).isEqualTo(ImportIssueCode.TEST_MODE_CONFLICT)
        assertThat(issue.severity).isEqualTo(ImportIssueSeverity.ERROR)
        assertThat(issue.source?.rowNumber).isEqualTo(3)
        assertThat(issue.testNumber).isEqualTo(4)
    }

    @Test
    fun `two distinct explicit modes fail closed`() {
        val result = TestModeResolver.resolve(
            rows = listOf(
                row(8, WorkbookTestModeDirective.TYPED_CLOZE),
                row(9),
                row(10, WorkbookTestModeDirective.MULTIPLE_CHOICE_CLOZE),
            ),
            defaultMode = ResolvedTestMode.MIXED,
            testNumber = 2,
        )

        assertThat(result.isValid).isFalse()
        assertThat(result.issues.map { it.code })
            .containsExactly(ImportIssueCode.TEST_MODE_CONFLICT)
    }

    private fun row(rowNumber: Int, mode: WorkbookTestModeDirective? = null) = TestPlanningRow(
        source = WorkbookRowSource(0, "A1", rowNumber),
        path = CourseContentPath("A1", "Unit", "Topic"),
        fixedTestNumber = null,
        requestedMode = mode,
        recordType = WorkbookRecordType.WORD,
        normalizedContentSha256 = sha256("row-$rowNumber"),
    )

    private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray())
        .joinToString("") { byte -> "%02x".format(byte) }
}
