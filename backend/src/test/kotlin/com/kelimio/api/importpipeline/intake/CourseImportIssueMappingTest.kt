package com.kelimio.api.importpipeline.intake

import org.assertj.core.api.Assertions.assertThat
import org.jooq.Record
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

class CourseImportIssueMappingTest {
    @Test
    fun `maps workbook-wide issues without manufacturing a primitive source coordinate`() {
        val row = issueRecord()
        `when`(row.get("source_sheet_ordinal", Int::class.javaObjectType)).thenReturn(null)

        val issue = toCourseImportValidationIssue(row)

        assertThat(issue.source).isNull()
    }

    @Test
    fun `maps nullable cell coordinates for sheet-scoped issues`() {
        val row = issueRecord()
        `when`(row.get("source_sheet_ordinal", Int::class.javaObjectType)).thenReturn(2)
        `when`(row.get("source_sheet_name", String::class.java)).thenReturn("Words")
        `when`(row.get("source_row_number", Int::class.java)).thenReturn(7)
        `when`(row.get("source_column_number", Int::class.javaObjectType)).thenReturn(null)
        `when`(row.get("source_reference", String::class.java)).thenReturn(null)

        val issue = toCourseImportValidationIssue(row)

        assertThat(issue.source).isEqualTo(CourseImportSource(2, "Words", 7, null, null))
    }

    private fun issueRecord(): Record = mock(Record::class.java).also { row ->
        `when`(row.get("ordinal", Int::class.java)).thenReturn(1)
        `when`(row.get("severity", String::class.java)).thenReturn("ERROR")
        `when`(row.get("issue_code", String::class.java)).thenReturn("XLSX_INVALID_PACKAGE")
        `when`(row.get("message", String::class.java)).thenReturn("The workbook failed secure XLSX validation.")
    }
}
