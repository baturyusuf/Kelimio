package com.kelimio.api.importpipeline.infrastructure.xlsx

import org.apache.poi.openxml4j.opc.OPCPackage
import org.apache.poi.openxml4j.opc.PackageAccess
import org.apache.poi.ss.usermodel.DataFormatter
import org.apache.poi.util.XMLHelper
import org.apache.poi.xssf.eventusermodel.ReadOnlySharedStringsTable
import org.apache.poi.xssf.eventusermodel.XSSFReader
import org.apache.poi.xssf.eventusermodel.XSSFSheetXMLHandler
import org.apache.poi.xssf.usermodel.XSSFComment
import org.xml.sax.InputSource
import java.io.InputStream
import java.nio.file.Files
import java.nio.file.StandardOpenOption
import java.util.Locale

/**
 * Fail-closed XLSX reader for the future isolated import worker.
 *
 * This class deliberately has no Spring annotation and performs no persistence,
 * networking, validation/planning, or success fallback. The caller-provided
 * stream is snapshotted once so preflight and POI parse the exact same bytes.
 */
class SecureXlsxReader(
    private val limits: XlsxImportLimits = XlsxImportLimits.V1,
) {
    init {
        limits.requireNoLooserThan(XlsxImportLimits.baselineFor(limits.rulesVersion))
    }

    fun read(
        originalFileName: String,
        declaredMediaType: String,
        source: InputStream,
    ): RawXlsxWorkbook {
        validateMetadata(originalFileName, declaredMediaType)
        val deadline = XlsxDeadline(limits.maxWallClock)
        val snapshot = Files.createTempFile("kelimio-quarantine-xlsx-", ".xlsx")
        var primaryFailure: Throwable? = null
        try {
            snapshotSource(source, snapshot, deadline)
            verifyZipSignature(snapshot)
            val expectedWorksheetCount = XlsxZipPreflight(limits, deadline).inspect(snapshot)
            return readPreflightedSnapshot(snapshot, deadline, expectedWorksheetCount)
        } catch (failure: Throwable) {
            primaryFailure = failure
            throw failure
        } finally {
            try {
                Files.deleteIfExists(snapshot)
            } catch (_: Exception) {
                runCatching { snapshot.toFile().deleteOnExit() }
                if (primaryFailure == null) {
                    reject(XlsxRejectionCode.TEMPORARY_STORAGE_FAILURE)
                }
            }
        }
    }

    private fun validateMetadata(
        originalFileName: String,
        declaredMediaType: String,
    ) {
        if (
            originalFileName.isBlank() ||
            originalFileName.indexOf('\u0000') >= 0 ||
            '/' in originalFileName ||
            '\\' in originalFileName ||
            !originalFileName.endsWith(XLSX_EXTENSION, ignoreCase = true)
        ) {
            reject(XlsxRejectionCode.INVALID_FILE_NAME)
        }
        if (!declaredMediaType.trim().equals(XLSX_MEDIA_TYPE, ignoreCase = true)) {
            reject(XlsxRejectionCode.INVALID_MEDIA_TYPE)
        }
    }

    private fun snapshotSource(
        source: InputStream,
        snapshot: java.nio.file.Path,
        deadline: XlsxDeadline,
    ) {
        var compressedBytes = 0L
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        Files.newOutputStream(snapshot, StandardOpenOption.TRUNCATE_EXISTING).use { output ->
            while (true) {
                deadline.check()
                val read = source.read(buffer)
                if (read < 0) break
                compressedBytes = Math.addExact(compressedBytes, read.toLong())
                if (compressedBytes > limits.maxCompressedBytes) {
                    reject(XlsxRejectionCode.UPLOAD_TOO_LARGE)
                }
                output.write(buffer, 0, read)
            }
        }
    }

    private fun verifyZipSignature(snapshot: java.nio.file.Path) {
        val signature = ByteArray(ZIP_LOCAL_FILE_HEADER.size)
        Files.newInputStream(snapshot).use { input ->
            var offset = 0
            while (offset < signature.size) {
                val read = input.read(signature, offset, signature.size - offset)
                if (read < 0) reject(XlsxRejectionCode.INVALID_ZIP_SIGNATURE)
                offset += read
            }
        }
        if (!signature.contentEquals(ZIP_LOCAL_FILE_HEADER)) {
            reject(XlsxRejectionCode.INVALID_ZIP_SIGNATURE)
        }
    }

    private fun readPreflightedSnapshot(
        snapshot: java.nio.file.Path,
        deadline: XlsxDeadline,
        expectedWorksheetCount: Int,
    ): RawXlsxWorkbook {
        try {
            OPCPackage.open(snapshot.toFile(), PackageAccess.READ).use { pkg ->
                deadline.check()
                val reader = XSSFReader(pkg)
                deadline.check()
                val styles = reader.stylesTable
                deadline.check()
                val sharedStrings = ReadOnlySharedStringsTable(pkg, false)
                deadline.check()
                val formatter = DataFormatter(Locale.ROOT, false).apply {
                    setUseCachedValuesForFormulaCells(false)
                }
                val budget = WorkbookOutputBudget(limits, deadline)
                val sheets = mutableListOf<RawXlsxSheet>()
                val iterator = reader.sheetIterator

                while (iterator.hasNext()) {
                    deadline.check()
                    if (sheets.size >= limits.maxSheets) reject(XlsxRejectionCode.TOO_MANY_SHEETS)
                    iterator.next().use { input ->
                        val rows = mutableListOf<RawXlsxRow>()
                        val contents = RawSheetContentsHandler(limits, budget, rows)
                        val handler = XSSFSheetXMLHandler(
                            styles,
                            sharedStrings,
                            contents,
                            formatter,
                            false,
                        )
                        XMLHelper.newXMLReader().apply {
                            contentHandler = handler
                            errorHandler = ThrowingSheetErrorHandler
                        }.parse(InputSource(input))
                        sheets += RawXlsxSheet(
                            ordinal = sheets.size,
                            name = iterator.sheetName,
                            rows = rows.toList(),
                        )
                    }
                }

                if (sheets.size != expectedWorksheetCount) {
                    reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                }
                return RawXlsxWorkbook(
                    rulesVersion = limits.rulesVersion,
                    sheets = sheets.toList(),
                )
            }
        } catch (rejected: XlsxRejectedException) {
            throw rejected
        } catch (_: Exception) {
            throw XlsxRejectedException(XlsxRejectionCode.CORRUPT_PACKAGE)
        }
    }

    private class RawSheetContentsHandler(
        private val limits: XlsxImportLimits,
        private val budget: WorkbookOutputBudget,
        private val outputRows: MutableList<RawXlsxRow>,
    ) : XSSFSheetXMLHandler.SheetContentsHandler {
        private var previousRowIndex = -1
        private var activeRowIndex: Int? = null
        private var previousColumnNumber = 0
        private var cells = mutableListOf<RawXlsxCell>()

        override fun startRow(rowNum: Int) {
            budget.checkDeadline()
            if (rowNum < 0 || rowNum <= previousRowIndex || activeRowIndex != null) {
                reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
            }
            previousRowIndex = rowNum
            activeRowIndex = rowNum
            previousColumnNumber = 0
            cells = mutableListOf()
        }

        override fun endRow(rowNum: Int) {
            budget.checkDeadline()
            val expected = activeRowIndex ?: reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
            if (rowNum != expected) reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
            if (cells.isNotEmpty()) {
                budget.addSemanticRow()
                outputRows += RawXlsxRow(
                    rowNumber = Math.addExact(rowNum, 1),
                    cells = cells.toList(),
                )
            }
            activeRowIndex = null
        }

        override fun cell(
            cellReference: String?,
            formattedValue: String?,
            comment: XSSFComment?,
        ) {
            budget.checkDeadline()
            val activeRow = activeRowIndex ?: reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
            val reference = cellReference ?: reject(XlsxRejectionCode.INVALID_CELL_REFERENCE)
            val columnNumber = parseColumnNumber(reference)
            val rowNumber = reference.dropWhile(Char::isLetter).toIntOrNull()
                ?: reject(XlsxRejectionCode.INVALID_CELL_REFERENCE)
            if (rowNumber != activeRow + 1) reject(XlsxRejectionCode.INVALID_CELL_REFERENCE)
            if (columnNumber > limits.maxColumns) reject(XlsxRejectionCode.TOO_MANY_COLUMNS)
            if (columnNumber <= previousColumnNumber) reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
            previousColumnNumber = columnNumber

            val value = formattedValue.orEmpty()
            if (value.isEmpty()) return
            budget.addText(value.length)
            cells += RawXlsxCell(
                rowNumber = rowNumber,
                columnNumber = columnNumber,
                reference = reference,
                value = value,
            )
        }
    }

    private class WorkbookOutputBudget(
        private val limits: XlsxImportLimits,
        private val deadline: XlsxDeadline,
    ) {
        private var semanticRows = 0
        private var textCharacters = 0L

        fun checkDeadline() = deadline.check()

        fun addSemanticRow() {
            semanticRows = Math.addExact(semanticRows, 1)
            if (semanticRows > limits.maxSemanticRows) {
                reject(XlsxRejectionCode.TOO_MANY_SEMANTIC_ROWS)
            }
        }

        fun addText(characters: Int) {
            if (characters > limits.maxCellCharacters) {
                reject(XlsxRejectionCode.CELL_TEXT_TOO_LONG)
            }
            textCharacters = Math.addExact(textCharacters, characters.toLong())
            if (textCharacters > limits.maxTotalTextCharacters) {
                reject(XlsxRejectionCode.TOTAL_TEXT_SIZE_EXCEEDED)
            }
        }
    }

    private object ThrowingSheetErrorHandler : org.xml.sax.ErrorHandler {
        override fun warning(exception: org.xml.sax.SAXParseException) = Unit

        override fun error(exception: org.xml.sax.SAXParseException): Nothing = throw exception

        override fun fatalError(exception: org.xml.sax.SAXParseException): Nothing = throw exception
    }

    companion object {
        const val XLSX_MEDIA_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

        private const val XLSX_EXTENSION = ".xlsx"
        private val ZIP_LOCAL_FILE_HEADER = byteArrayOf(0x50, 0x4B, 0x03, 0x04)
    }
}
