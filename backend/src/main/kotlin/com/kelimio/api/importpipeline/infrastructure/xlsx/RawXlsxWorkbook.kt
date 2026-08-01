package com.kelimio.api.importpipeline.infrastructure.xlsx

/**
 * Inert worksheet values emitted by the secure reader.
 *
 * Ordinals are zero-based because they represent physical workbook order. Row
 * and column coordinates are one-based to match the coordinates an author sees
 * in Excel. Only semantic (non-empty) rows and cells are retained; no text is
 * trimmed, case-folded, or Unicode-normalized here.
 */
data class RawXlsxWorkbook(
    val rulesVersion: String,
    val sheets: List<RawXlsxSheet>,
)

data class RawXlsxSheet(
    val ordinal: Int,
    val name: String,
    val rows: List<RawXlsxRow>,
)

data class RawXlsxRow(
    val rowNumber: Int,
    val cells: List<RawXlsxCell>,
)

data class RawXlsxCell(
    val rowNumber: Int,
    val columnNumber: Int,
    val reference: String,
    val value: String,
)
