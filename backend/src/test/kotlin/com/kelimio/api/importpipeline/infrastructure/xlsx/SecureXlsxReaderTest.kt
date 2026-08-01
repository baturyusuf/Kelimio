package com.kelimio.api.importpipeline.infrastructure.xlsx

import org.apache.poi.xssf.usermodel.XSSFWorkbook
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.StandardCharsets
import java.time.Duration
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

class SecureXlsxReaderTest {
    @Test
    fun `accepts the reviewed workbook including its canonical theme styles and shared strings`() {
        val source = requireNotNull(
            javaClass.getResourceAsStream("/import/valid/kurs_excel_plani_v3_test_numarali.xlsx"),
        )

        val result = source.use {
            reader().read("course.xlsx", SecureXlsxReader.XLSX_MEDIA_TYPE, it)
        }

        assertThat(result.sheets.map(RawXlsxSheet::name)).containsExactly(
            "BILGI_AYARLAR",
            "Giriş Seviyesi",
            "A2",
        )
    }

    @Test
    fun `streams visible inert cells with physical coordinates and unchanged Unicode`() {
        val decomposed = "e\u0301"
        val bytes = workbookBytes { workbook ->
            val settings = workbook.createSheet("BILGI_AYARLAR")
            settings.createRow(0).apply {
                createCell(0).setCellValue("Ayar")
                createCell(2).setCellValue("قيمة")
            }
            settings.createRow(499).createCell(0).cellStyle = workbook.createCellStyle()
            workbook.createSheet("Giriş Seviyesi").createRow(4).apply {
                createCell(1).setCellValue(decomposed)
                createCell(3).setCellValue(42.0)
            }
        }

        val result = read(bytes)

        assertThat(result.rulesVersion).isEqualTo("xlsx-v1")
        assertThat(result.sheets.map { it.ordinal to it.name }).containsExactly(
            0 to "BILGI_AYARLAR",
            1 to "Giriş Seviyesi",
        )
        assertThat(result.sheets[0].rows).hasSize(1)
        assertThat(result.sheets[0].rows.single().cells.map { it.reference to it.value })
            .containsExactly("A1" to "Ayar", "C1" to "قيمة")
        assertThat(result.sheets[1].rows.single().rowNumber).isEqualTo(5)
        assertThat(result.sheets[1].rows.single().cells).containsExactly(
            RawXlsxCell(5, 2, "B5", decomposed),
            RawXlsxCell(5, 4, "D5", "42"),
        )
    }

    @Test
    fun `rejects filename media type and signature disagreement`() {
        val valid = workbookBytes { it.createSheet("Sheet1").createRow(0).createCell(0).setCellValue("x") }

        assertRejected(XlsxRejectionCode.INVALID_FILE_NAME) {
            reader().read("../course.xlsx", SecureXlsxReader.XLSX_MEDIA_TYPE, valid.inputStream())
        }
        assertRejected(XlsxRejectionCode.INVALID_FILE_NAME) {
            reader().read("course.xlsm", SecureXlsxReader.XLSX_MEDIA_TYPE, valid.inputStream())
        }
        assertRejected(XlsxRejectionCode.INVALID_MEDIA_TYPE) {
            reader().read("course.xlsx", "application/zip", valid.inputStream())
        }
        assertRejected(XlsxRejectionCode.INVALID_ZIP_SIGNATURE) {
            read("not a zip".toByteArray())
        }
    }

    @Test
    fun `rejects truncated and generic ZIP packages`() {
        val valid = workbookBytes { it.createSheet("Sheet1") }
        assertRejected(XlsxRejectionCode.CORRUPT_PACKAGE) {
            read(valid.copyOf(valid.size - 12))
        }
        assertRejected(XlsxRejectionCode.INVALID_PACKAGE_TYPE) {
            read(rawZip("hello.txt" to "hello".toByteArray()))
        }
    }

    @Test
    fun `checks the ZIP entry count before retaining an unbounded entry list`() {
        val zip = rawZip(
            "a" to byteArrayOf(1),
            "b" to byteArrayOf(2),
            "c" to byteArrayOf(3),
        )
        val limits = XlsxImportLimits.V1.copy(maxZipEntries = 2)

        assertRejected(XlsxRejectionCode.TOO_MANY_ZIP_ENTRIES) {
            read(zip, limits)
        }
    }

    @Test
    fun `rejects unsafe ZIP namespaces and case folding collisions`() {
        assertRejected(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME) {
            read(rawZip("../evil.xml" to "<x/>".toByteArray()))
        }
        assertRejected(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME) {
            read(rawZip("xl\\evil.xml" to "<x/>".toByteArray()))
        }
        assertRejected(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME) {
            read(rawZip("C:/evil.xml" to "<x/>".toByteArray()))
        }
        assertRejected(XlsxRejectionCode.CASE_FOLDING_ZIP_ENTRY_COLLISION) {
            read(rawZip("A.xml" to "<x/>".toByteArray(), "a.xml" to "<x/>".toByteArray()))
        }
        assertRejected(XlsxRejectionCode.CASE_FOLDING_ZIP_ENTRY_COLLISION) {
            read(rawZip("straße.xml" to "<x/>".toByteArray(), "STRASSE.xml" to "<x/>".toByteArray()))
        }
    }

    @Test
    fun `rejects Unicode-path extra swaps before ZIP decoders can disagree`() {
        val valid = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(0).setCellValue("benign")
        }
        val swapped = unicodePathWorksheetSwap(valid)

        assertRejected(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME) {
            read(swapped)
        }
    }

    @Test
    fun `rejects exact duplicate ZIP names`() {
        val original = rawZip(
            "a.xml" to "<x/>".toByteArray(),
            "b.xml" to "<x/>".toByteArray(),
        )
        val duplicate = replaceAscii(original, "b.xml", "a.xml")

        assertRejected(XlsxRejectionCode.DUPLICATE_ZIP_ENTRY) {
            read(duplicate)
        }
    }

    @Test
    fun `rejects macros embeddings and external relationships`() {
        val valid = workbookBytes { it.createSheet("Sheet1") }
        assertRejected(XlsxRejectionCode.ACTIVE_CONTENT) {
            read(addZipEntry(valid, "xl/vbaProject.bin", byteArrayOf(1)))
        }
        assertRejected(XlsxRejectionCode.ACTIVE_CONTENT) {
            read(addZipEntry(valid, "xl/embeddings/object1.xlsx", byteArrayOf(1)))
        }
        val relationship = """
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.invalid" TargetMode="External"/>
            </Relationships>
        """.trimIndent().toByteArray()
        assertRejected(XlsxRejectionCode.EXTERNAL_CONTENT) {
            read(addZipEntry(valid, "xl/worksheets/_rels/sheet1.xml.rels", relationship))
        }
    }

    @Test
    fun `binds every worksheet relationship to a preflight-scanned canonical XML part`() {
        val valid = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(0).setCellValue("cached")
        }
        val disguisedWorksheet = rewriteZip(valid) { name, content ->
            val rewrittenName = name.replace("sheet1.xml", "sheet1.dat")
            val rewrittenContent = if (name.endsWith(".xml") || name.endsWith(".rels")) {
                content.toString(StandardCharsets.UTF_8)
                    .replace("sheet1.xml", "sheet1.dat")
                    .toByteArray(StandardCharsets.UTF_8)
            } else {
                content
            }
            rewrittenName to rewrittenContent
        }

        assertRejected(XlsxRejectionCode.INVALID_PACKAGE_TYPE) {
            read(disguisedWorksheet)
        }
    }

    @Test
    fun `requires exact OOXML relationship type URIs and unique IDs per relationship part`() {
        val valid = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(0).setCellValue("one")
            workbook.createSheet("Sheet2").createRow(0).createCell(0).setCellValue("two")
        }
        val worksheetType =
            "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"
        val fakeWorksheetType = "https://attacker.invalid/relationships/worksheet"
        val mixedRelationshipTypes = rewriteZip(valid) { name, content ->
            if (name != "xl/_rels/workbook.xml.rels") return@rewriteZip name to content
            var seen = 0
            val rewritten = Regex(Regex.escape(worksheetType)).replace(
                content.toString(StandardCharsets.UTF_8),
            ) { match ->
                seen += 1
                if (seen == 2) fakeWorksheetType else match.value
            }
            require(seen == 2)
            name to rewritten.toByteArray(StandardCharsets.UTF_8)
        }
        assertRejected(XlsxRejectionCode.INVALID_PACKAGE_TYPE) {
            read(mixedRelationshipTypes)
        }

        val duplicateRelationshipId = rewriteZip(valid) { name, content ->
            if (name != "xl/_rels/workbook.xml.rels") return@rewriteZip name to content
            val xml = content.toString(StandardCharsets.UTF_8)
            val ids = Regex("""Id="([^"]+)"""").findAll(xml).toList()
            require(ids.size >= 2)
            val duplicate = xml.replaceRange(ids[1].groups[1]!!.range, ids[0].groupValues[1])
            name to duplicate.toByteArray(StandardCharsets.UTF_8)
        }
        assertRejected(XlsxRejectionCode.CORRUPT_PACKAGE) {
            read(duplicateRelationshipId)
        }

        val caseMutatedRelationshipType = rewriteZip(valid) { name, content ->
            if (name != "xl/_rels/workbook.xml.rels") return@rewriteZip name to content
            val xml = content.toString(StandardCharsets.UTF_8)
            val rewritten = xml.replaceFirst("/worksheet\"", "/WORKSHEET\"")
            require(rewritten != xml)
            name to rewritten.toByteArray(StandardCharsets.UTF_8)
        }
        assertRejected(XlsxRejectionCode.INVALID_PACKAGE_TYPE) {
            read(caseMutatedRelationshipType)
        }
    }

    @Test
    fun `requires official core namespaces and unique content-type mappings`() {
        val valid = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(0).setCellValue("value")
        }
        val foreignWorksheetNamespace = rewriteWorksheetXml(valid) { xml ->
            xml.replaceFirst(
                "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
                "urn:attacker:spreadsheet",
            )
        }
        assertRejected(XlsxRejectionCode.INVALID_PACKAGE_TYPE) {
            read(foreignWorksheetNamespace)
        }

        val strictSharedStringsNamespace = rewriteZip(valid) { name, content ->
            if (name != "xl/sharedStrings.xml") return@rewriteZip name to content
            val xml = content.toString(StandardCharsets.UTF_8)
            val rewritten = xml.replace(
                "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
                "http://purl.oclc.org/ooxml/spreadsheetml/main",
            )
            require(rewritten != xml)
            name to rewritten.toByteArray(StandardCharsets.UTF_8)
        }
        assertRejected(XlsxRejectionCode.INVALID_PACKAGE_TYPE) {
            read(strictSharedStringsNamespace)
        }

        listOf("Override", "Default").forEach { elementName ->
            val duplicateMapping = rewriteZip(valid) { name, content ->
                if (name != "[Content_Types].xml") return@rewriteZip name to content
                val xml = content.toString(StandardCharsets.UTF_8)
                val mapping = Regex("<$elementName\\b[^>]*/>").find(xml)?.value
                    ?: error("Missing $elementName mapping")
                val rewritten = xml.replace("</Types>", "$mapping</Types>")
                name to rewritten.toByteArray(StandardCharsets.UTF_8)
            }
            assertRejected(XlsxRejectionCode.INVALID_PACKAGE_TYPE) {
                read(duplicateMapping)
            }
        }
    }

    @Test
    fun `binds POI-loaded shared strings and styles to canonical preflight-scanned XML parts`() {
        val valid = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(0).setCellValue("shared")
        }

        listOf(
            "sharedStrings.xml" to "sharedStrings.dat",
            "styles.xml" to "styles.dat",
        ).forEach { (from, to) ->
            val disguised = rewriteZip(valid) { name, content ->
                val rewrittenName = name.replace(from, to)
                val rewrittenContent = if (name.endsWith(".xml") || name.endsWith(".rels")) {
                    content.toString(StandardCharsets.UTF_8)
                        .replace(from, to)
                        .toByteArray(StandardCharsets.UTF_8)
                } else {
                    content
                }
                rewrittenName to rewrittenContent
            }
            assertRejected(XlsxRejectionCode.INVALID_PACKAGE_TYPE) { read(disguised) }
        }
    }

    @Test
    fun `rejects DTDs and entity declarations without resolving them`() {
        val valid = workbookBytes { it.createSheet("Sheet1") }
        val maliciousXml = """
            <?xml version="1.0"?>
            <!DOCTYPE x [<!ENTITY secret SYSTEM "file:///does-not-exist">]>
            <x>&secret;</x>
        """.trimIndent().toByteArray()

        assertRejected(XlsxRejectionCode.XML_SECURITY_VIOLATION) {
            read(addZipEntry(valid, "docProps/malicious.xml", maliciousXml))
        }
    }

    @Test
    fun `rejects formula cells even when the package contains a cached result`() {
        val bytes = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(0).cellFormula = "1+1"
        }

        assertRejected(XlsxRejectionCode.FORMULA_CELL) { read(bytes) }
    }

    @Test
    fun `preflights POI-buffered worksheet and shared-string text before materialization`() {
        val numeric = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(0).setCellValue(1.0)
        }
        val oversizedValue = rewriteWorksheetXml(numeric) { xml ->
            val rewritten = Regex("<v>[^<]*</v>").replaceFirst(
                xml,
                "<v>${"9".repeat(XlsxImportLimits.V1.maxCellCharacters + 1)}</v>",
            )
            require(rewritten != xml)
            rewritten
        }
        assertRejected(XlsxRejectionCode.CELL_TEXT_TOO_LONG) {
            read(oversizedValue)
        }

        val strings = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(0).setCellValue("private workbook text")
        }
        val nestedSharedString = rewriteZip(strings) { name, content ->
            if (name != "xl/sharedStrings.xml") return@rewriteZip name to content
            val xml = content.toString(StandardCharsets.UTF_8)
            val rewritten = xml
                .replaceFirst("<si>", "<si><si>")
                .replaceFirst("</si>", "</si></si>")
            require(rewritten != xml)
            name to rewritten.toByteArray(StandardCharsets.UTF_8)
        }
        assertRejected(XlsxRejectionCode.CORRUPT_PACKAGE) {
            read(nestedSharedString)
        }

        val wrongSharedStringsRoot = rewriteZip(strings) { name, content ->
            if (name != "xl/sharedStrings.xml") return@rewriteZip name to content
            val xml = content.toString(StandardCharsets.UTF_8)
            val rewritten = xml
                .replaceFirst("<sst", "<notSst")
                .replaceFirst("</sst>", "</notSst>")
            require(rewritten != xml)
            name to rewritten.toByteArray(StandardCharsets.UTF_8)
        }
        assertRejected(XlsxRejectionCode.INVALID_PACKAGE_TYPE) {
            read(wrongSharedStringsRoot)
        }

        val repeatedSharedStringsRoot = rewriteZip(strings) { name, content ->
            if (name != "xl/sharedStrings.xml") return@rewriteZip name to content
            val xml = content.toString(StandardCharsets.UTF_8)
            val rewritten = xml.replaceFirst("</si>", "</si><sst/>")
            require(rewritten != xml)
            name to rewritten.toByteArray(StandardCharsets.UTF_8)
        }
        assertRejected(XlsxRejectionCode.INVALID_PACKAGE_TYPE) {
            read(repeatedSharedStringsRoot)
        }

        val invalidSharedStringIndex = rewriteWorksheetXml(strings) { xml ->
            val rewritten = Regex("<v>[^<]*</v>").replaceFirst(xml, "<v>999999</v>")
            require(rewritten != xml)
            rewritten
        }
        val rejection = runCatching { read(invalidSharedStringIndex) }.exceptionOrNull()
        assertThat(rejection).isInstanceOf(XlsxRejectedException::class.java)
        assertThat((rejection as XlsxRejectedException).code)
            .isEqualTo(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
        assertThat(rejection.cause).isNull()
        assertThat(rejection.message).doesNotContain("private workbook text")
    }

    @Test
    fun `rejects hidden sheets rows columns and default zero-height rows`() {
        val hiddenSheet = workbookBytes { workbook ->
            workbook.createSheet("Visible")
            workbook.createSheet("Hidden")
            workbook.setSheetHidden(1, true)
        }
        assertRejected(XlsxRejectionCode.HIDDEN_SHEET) { read(hiddenSheet) }

        val hiddenRow = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).apply {
                zeroHeight = true
                createCell(0).setCellValue("hidden")
            }
        }
        assertRejected(XlsxRejectionCode.HIDDEN_ROW) { read(hiddenRow) }

        val hiddenColumn = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").apply {
                createRow(0).createCell(0).setCellValue("hidden")
                setColumnHidden(0, true)
            }
        }
        assertRejected(XlsxRejectionCode.HIDDEN_COLUMN) { read(hiddenColumn) }

        val zeroHeight = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").apply {
                ctWorksheet.sheetFormatPr.zeroHeight = true
                createRow(0).createCell(0).setCellValue("hidden by default")
            }
        }
        assertRejected(XlsxRejectionCode.HIDDEN_ROW) { read(zeroHeight) }
    }

    @Test
    fun `rejects whitespace booleans and zero-sized row or column geometry`() {
        val valid = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(0).setCellValue("hidden")
        }

        val whitespaceHidden = rewriteWorksheetXml(valid) { xml ->
            xml.replaceFirst("<row ", "<row hidden=\" true \" ")
        }
        assertRejected(XlsxRejectionCode.HIDDEN_ROW) { read(whitespaceHidden) }

        val zeroHeight = rewriteWorksheetXml(valid) { xml ->
            xml.replaceFirst("<row ", "<row ht=\"0\" ")
        }
        assertRejected(XlsxRejectionCode.HIDDEN_ROW) { read(zeroHeight) }

        val zeroWidth = rewriteWorksheetXml(valid) { xml ->
            xml.replaceFirst(
                "<sheetData>",
                "<cols><col min=\"1\" max=\"1\" width=\"0\"/></cols><sheetData>",
            )
        }
        assertRejected(XlsxRejectionCode.HIDDEN_COLUMN) { read(zeroWidth) }
    }

    @Test
    fun `enforces compressed inflated and ratio budgets`() {
        val bytes = workbookBytes { it.createSheet("Sheet1").createRow(0).createCell(0).setCellValue("x") }

        assertRejected(XlsxRejectionCode.UPLOAD_TOO_LARGE) {
            read(bytes, XlsxImportLimits.V1.copy(maxCompressedBytes = (bytes.size - 1).toLong()))
        }
        assertRejected(XlsxRejectionCode.ZIP_ENTRY_TOO_LARGE) {
            read(
                bytes,
                XlsxImportLimits.V1.copy(
                    maxInflatedEntryBytes = 100,
                    maxTotalInflatedBytes = 1_000_000,
                ),
            )
        }
        assertRejected(XlsxRejectionCode.SUSPICIOUS_COMPRESSION_RATIO) {
            read(
                bytes,
                XlsxImportLimits.V1.copy(
                    maxInflationRatio = 1.0,
                    inflationRatioGraceBytes = 0,
                ),
            )
        }

        val inflatedSizes = inflatedEntrySizes(bytes)
        assertRejected(XlsxRejectionCode.TOTAL_INFLATED_SIZE_EXCEEDED) {
            read(
                bytes,
                XlsxImportLimits.V1.copy(
                    maxInflatedEntryBytes = inflatedSizes.max(),
                    maxTotalInflatedBytes = inflatedSizes.sum() - 1,
                ),
            )
        }
    }

    @Test
    fun `enforces actual sheet row column cell and total text budgets`() {
        val twoSheets = workbookBytes { workbook ->
            workbook.createSheet("One")
            workbook.createSheet("Two")
        }
        assertRejected(XlsxRejectionCode.TOO_MANY_SHEETS) {
            read(twoSheets, XlsxImportLimits.V1.copy(maxSheets = 1))
        }

        val thirdColumn = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(2).setCellValue("x")
        }
        assertRejected(XlsxRejectionCode.TOO_MANY_COLUMNS) {
            read(thirdColumn, XlsxImportLimits.V1.copy(maxColumns = 2))
        }

        val twoRows = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").apply {
                createRow(0).createCell(0).setCellValue("a")
                createRow(1).createCell(0).setCellValue("b")
            }
        }
        assertRejected(XlsxRejectionCode.TOO_MANY_SEMANTIC_ROWS) {
            read(twoRows, XlsxImportLimits.V1.copy(maxSemanticRows = 1))
        }

        val longCell = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).createCell(0).setCellValue("abcd")
        }
        assertRejected(XlsxRejectionCode.CELL_TEXT_TOO_LONG) {
            read(longCell, XlsxImportLimits.V1.copy(maxCellCharacters = 3))
        }

        val totalText = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).apply {
                createCell(0).setCellValue("ab")
                createCell(1).setCellValue("cd")
            }
        }
        assertRejected(XlsxRejectionCode.TOTAL_TEXT_SIZE_EXCEEDED) {
            read(totalText, XlsxImportLimits.V1.copy(maxTotalTextCharacters = 3))
        }


        val twoSharedStrings = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").createRow(0).apply {
                createCell(0).setCellValue("one")
                createCell(1).setCellValue("two")
            }
        }
        assertRejected(XlsxRejectionCode.TOO_MANY_SHARED_STRINGS) {
            read(twoSharedStrings, XlsxImportLimits.V1.copy(maxSharedStringItems = 1))
        }

        assertRejected(XlsxRejectionCode.TOO_MANY_STYLE_RECORDS) {
            read(twoSharedStrings, XlsxImportLimits.V1.copy(maxStyleRecords = 1))
        }

        assertRejected(XlsxRejectionCode.ZIP_ENTRY_TOO_LARGE) {
            read(twoSharedStrings, XlsxImportLimits.V1.copy(maxStylesPartBytes = 1))
        }

        val twoRowsOneColumn = workbookBytes { workbook ->
            workbook.createSheet("Sheet1").apply {
                createRow(0).createCell(0).setCellValue("one")
                createRow(1).createCell(0).setCellValue("two")
            }
        }
        assertRejected(XlsxRejectionCode.TOO_MANY_SHARED_STRINGS) {
            read(
                twoRowsOneColumn,
                XlsxImportLimits.V1.copy(
                    maxSemanticRows = 1,
                    maxColumns = 1,
                ),
            )
        }

        val oversizedRelationship = """
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <!--${"x".repeat(5_000)}-->
            </Relationships>
        """.trimIndent().toByteArray()
        listOf(
            "xl/worksheets/_rels/sheet1.xml.rels",
            "xl/worksheets/_rels/sheet1.xml.RELS",
        ).forEach { relationshipName ->
            assertRejected(XlsxRejectionCode.ZIP_ENTRY_TOO_LARGE) {
                read(
                    addZipEntry(
                        twoSharedStrings,
                        relationshipName,
                        oversizedRelationship,
                    ),
                    XlsxImportLimits.V1.copy(maxWorkbookMetadataPartBytes = 4_096),
                )
            }
        }
    }

    @Test
    fun `deadline fails closed`() {
        var time = 0L
        val deadline = XlsxDeadline(Duration.ofNanos(1)) { time }
        deadline.check()
        time = 2

        assertRejected(XlsxRejectionCode.PARSE_DEADLINE_EXCEEDED) { deadline.check() }
    }

    private fun reader(limits: XlsxImportLimits = XlsxImportLimits.V1) = SecureXlsxReader(limits)

    private fun read(
        bytes: ByteArray,
        limits: XlsxImportLimits = XlsxImportLimits.V1,
    ): RawXlsxWorkbook =
        reader(limits).read(
            originalFileName = "course.xlsx",
            declaredMediaType = SecureXlsxReader.XLSX_MEDIA_TYPE,
            source = ByteArrayInputStream(bytes),
        )

    private fun assertRejected(
        expected: XlsxRejectionCode,
        action: () -> Unit,
    ) {
        assertThatThrownBy(action)
            .isInstanceOf(XlsxRejectedException::class.java)
            .extracting("code")
            .isEqualTo(expected)
    }

    private fun workbookBytes(configure: (XSSFWorkbook) -> Unit): ByteArray {
        val output = ByteArrayOutputStream()
        XSSFWorkbook().use { workbook ->
            configure(workbook)
            workbook.write(output)
        }
        return output.toByteArray()
    }

    private fun rawZip(vararg entries: Pair<String, ByteArray>): ByteArray {
        val output = ByteArrayOutputStream()
        ZipOutputStream(output).use { zip ->
            entries.forEach { (name, content) ->
                zip.putNextEntry(ZipEntry(name))
                zip.write(content)
                zip.closeEntry()
            }
        }
        return output.toByteArray()
    }

    private fun inflatedEntrySizes(zipBytes: ByteArray): List<Long> {
        val sizes = mutableListOf<Long>()
        ZipInputStream(zipBytes.inputStream()).use { zip ->
            while (zip.nextEntry != null) {
                var size = 0L
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val read = zip.read(buffer)
                    if (read < 0) break
                    size += read
                }
                sizes += size
                zip.closeEntry()
            }
        }
        return sizes
    }

    private fun addZipEntry(
        original: ByteArray,
        name: String,
        content: ByteArray,
    ): ByteArray {
        val output = ByteArrayOutputStream()
        ZipOutputStream(output).use { target ->
            ZipInputStream(original.inputStream()).use { source ->
                while (true) {
                    val entry = source.nextEntry ?: break
                    target.putNextEntry(ZipEntry(entry.name))
                    source.copyTo(target)
                    target.closeEntry()
                    source.closeEntry()
                }
            }
            target.putNextEntry(ZipEntry(name))
            target.write(content)
            target.closeEntry()
        }
        return output.toByteArray()
    }

    private fun rewriteZip(
        original: ByteArray,
        transform: (String, ByteArray) -> Pair<String, ByteArray>,
    ): ByteArray {
        val output = ByteArrayOutputStream()
        ZipOutputStream(output).use { target ->
            ZipInputStream(original.inputStream()).use { source ->
                while (true) {
                    val entry = source.nextEntry ?: break
                    val content = source.readAllBytes()
                    val (name, rewritten) = transform(entry.name, content)
                    target.putNextEntry(ZipEntry(name))
                    target.write(rewritten)
                    target.closeEntry()
                    source.closeEntry()
                }
            }
        }
        return output.toByteArray()
    }

    private fun rewriteWorksheetXml(
        original: ByteArray,
        transform: (String) -> String,
    ): ByteArray = rewriteZip(original) { name, content ->
        if (name != "xl/worksheets/sheet1.xml") return@rewriteZip name to content
        val xml = content.toString(StandardCharsets.UTF_8)
        val rewritten = transform(xml)
        require(rewritten != xml)
        name to rewritten.toByteArray(StandardCharsets.UTF_8)
    }

    private fun unicodePathWorksheetSwap(original: ByteArray): ByteArray {
        val output = ByteArrayOutputStream()
        ZipOutputStream(output).use { target ->
            ZipInputStream(original.inputStream()).use { source ->
                while (true) {
                    val entry = source.nextEntry ?: break
                    val content = source.readAllBytes()
                    if (entry.name == "xl/worksheets/sheet1.xml") {
                        writeZipEntry(
                            target,
                            entry.name,
                            content,
                            unicodePathExtra(entry.name, "xl/worksheets/sheet1.dat"),
                        )
                        val malicious = content.toString(StandardCharsets.UTF_8).replace(
                            "<sheetData>",
                            "<sheetData><row r=\"1\"><c r=\"A1\"><f>1+1</f><v>2</v></c></row>",
                        ).toByteArray(StandardCharsets.UTF_8)
                        writeZipEntry(
                            target,
                            "xl/worksheets/sheet1.dat",
                            malicious,
                            unicodePathExtra(
                                "xl/worksheets/sheet1.dat",
                                "xl/worksheets/sheet1.xml",
                            ),
                        )
                    } else {
                        writeZipEntry(target, entry.name, content)
                    }
                    source.closeEntry()
                }
            }
        }
        return output.toByteArray()
    }

    private fun writeZipEntry(
        target: ZipOutputStream,
        name: String,
        content: ByteArray,
        extra: ByteArray? = null,
    ) {
        val entry = ZipEntry(name)
        if (extra != null) entry.extra = extra
        target.putNextEntry(entry)
        target.write(content)
        target.closeEntry()
    }

    private fun unicodePathExtra(
        rawName: String,
        unicodeName: String,
    ): ByteArray {
        val rawNameBytes = rawName.toByteArray(StandardCharsets.UTF_8)
        val unicodeNameBytes = unicodeName.toByteArray(StandardCharsets.UTF_8)
        val crc = CRC32().apply { update(rawNameBytes) }.value
        val dataLength = 1 + Int.SIZE_BYTES + unicodeNameBytes.size
        return ByteBuffer.allocate(Short.SIZE_BYTES * 2 + dataLength)
            .order(ByteOrder.LITTLE_ENDIAN)
            .putShort(0x7075.toShort())
            .putShort(dataLength.toShort())
            .put(1)
            .putInt(crc.toInt())
            .put(unicodeNameBytes)
            .array()
    }

    private fun replaceAscii(
        input: ByteArray,
        from: String,
        to: String,
    ): ByteArray {
        require(from.length == to.length)
        val result = input.copyOf()
        val needle = from.toByteArray(StandardCharsets.US_ASCII)
        val replacement = to.toByteArray(StandardCharsets.US_ASCII)
        for (offset in 0..result.size - needle.size) {
            if (needle.indices.all { result[offset + it] == needle[it] }) {
                replacement.copyInto(result, offset)
            }
        }
        return result
    }
}
