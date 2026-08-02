package com.kelimio.api.importpipeline.application

import com.kelimio.api.importpipeline.domain.ResolvedTestMode
import com.kelimio.api.importpipeline.domain.RowAllocationReason
import com.kelimio.api.importpipeline.domain.WorkbookRecordType
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxCell
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxRow
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxSheet
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxWorkbook
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class WorkbookImportOrchestratorTest {
    private val orchestrator = WorkbookImportOrchestrator()

    @Test
    fun `produces a normalized deterministic preview and invokes the planner`() {
        val workbook = workbook(
            contentRows = listOf(
                typedRow(5),
                multipleChoiceRow(4),
                RawXlsxRow(500, emptyList()),
                wordRow(2, testNumber = "1", mode = "Kelime", target = "Merhaba"),
                wordRow(3, testNumber = "1", target = "Güle güle"),
            ),
            settingsOverrides = mapOf(
                "Varsayılan Test Soru Sayısı" to "2",
                "Son Grup Minimum Soru" to "1",
            ),
        )

        val first = orchestrator.preview(workbook.copy(sheets = workbook.sheets.reversed()))
        val second = orchestrator.preview(workbook)

        assertThat(first.isValid).isTrue()
        assertThat(first.issues).isEmpty()
        assertThat(first.rows).hasSize(4)
        assertThat(first.rows.map { it.source.rowNumber }).containsExactly(2, 3, 4, 5)
        assertThat(first.levelCount).isEqualTo(1)
        assertThat(first.unitCount).isEqualTo(1)
        assertThat(first.topicCount).isEqualTo(1)
        assertThat(first.testCount).isEqualTo(2)
        assertThat(first.settings?.targetLanguageCode).isEqualTo("tr")
        assertThat(first.settings?.supportLanguageCodes).containsExactly("en", "ar", "fr")
        assertThat(first.settings?.defaultSupportLanguageCode).isEqualTo("en")
        assertThat(first.rows.first().translations.keys).containsExactly("en", "ar", "fr")
        assertThat(first.rows.first().translations["ar"]).isEqualTo("مرحبا 2")
        assertThat(first.rows.first().normalizedContentSha256).matches("[0-9a-f]{64}")

        val tests = checkNotNull(first.plan).tests
        assertThat(tests.map { it.number to it.rows.size }).containsExactly(1 to 2, 2 to 2)
        assertThat(tests.first().resolvedMode).isEqualTo(ResolvedTestMode.WORD)
        assertThat(tests.last().resolvedMode).isEqualTo(ResolvedTestMode.MIXED)
        assertThat(tests.last().rows.map { it.reason }).containsOnly(RowAllocationReason.AUTOMATIC)
        assertThat(first.allocationSha256).matches("[0-9a-f]{64}")
        assertThat(first.previewSha256).matches("[0-9a-f]{64}")
        assertThat(second.allocationSha256).isEqualTo(first.allocationSha256)
        assertThat(second.previewSha256).isEqualTo(first.previewSha256)
        assertThat(second.rows.map { it.normalizedContentSha256 })
            .containsExactlyElementsOf(first.rows.map { it.normalizedContentSha256 })
    }

    @Test
    fun `returns duplicate unknown and missing setting issues without a partial plan`() {
        val baseSettings = settingValues().toMutableList()
        baseSettings[13] = "Kurs Adı" to "Başka kurs"
        val duplicate = orchestrator.preview(
            workbook(settingsRows = settingsSheetRows(baseSettings)),
        )
        assertThat(duplicate.issueCodes())
            .contains(
                WorkbookImportIssueCode.DUPLICATE_SETTING,
                WorkbookImportIssueCode.SETTINGS_ROW_MISSING,
            )
        assertThat(duplicate.settings).isNull()
        assertThat(duplicate.plan).isNull()

        val unknownSettings = settingValues().toMutableList()
        unknownSettings[0] = "Bilinmeyen Ayar" to "değer"
        val unknown = orchestrator.preview(
            workbook(settingsRows = settingsSheetRows(unknownSettings)),
        )
        assertThat(unknown.issueCodes())
            .contains(
                WorkbookImportIssueCode.UNKNOWN_SETTING,
                WorkbookImportIssueCode.SETTINGS_ROW_MISSING,
            )

        val missing = orchestrator.preview(
            workbook(settingsRows = settingsSheetRows(settingValues()).filterNot { it.rowNumber == 11 }),
        )
        assertThat(missing.issueCodes()).contains(WorkbookImportIssueCode.SETTINGS_ROW_MISSING)
        assertThat(missing.plan).isNull()
    }

    @Test
    fun `requires the exact settings header and rejects values beyond column C`() {
        val badHeader = settingsSheetRows(settingValues()).map { row ->
            if (row.rowNumber == 5) rowOf(5, 1 to "Ayar", 2 to "Yanlış", 3 to "Açıklama") else row
        }
        val headerPreview = orchestrator.preview(workbook(settingsRows = badHeader))
        assertThat(headerPreview.issueCodes()).contains(WorkbookImportIssueCode.HEADER_MISMATCH)

        val extraCell = settingsSheetRows(settingValues()).map { row ->
            if (row.rowNumber == 6) row.copy(cells = row.cells + cell(6, 4, "beklenmeyen")) else row
        }
        val extraPreview = orchestrator.preview(workbook(settingsRows = extraCell))
        assertThat(extraPreview.issueCodes()).contains(WorkbookImportIssueCode.UNEXPECTED_FIELD_VALUE)
    }

    @Test
    fun `enforces language membership policy and numeric setting ranges`() {
        val invalidOverrides = listOf(
            mapOf("Destek Dilleri" to "EN, en, FR"),
            mapOf("Destek Dilleri" to "TR, AR, FR", "Varsayılan Destek Dili" to "AR"),
            mapOf("Varsayılan Destek Dili" to "DE"),
            mapOf("Varsayılan Test Soru Sayısı" to "0"),
            mapOf("Varsayılan Test Soru Sayısı" to "5", "Son Grup Minimum Soru" to "6"),
            mapOf("Test Tamamlama Eşiği" to "49%"),
            mapOf("Varsayılan Test Modu" to "Varsayılan"),
            mapOf("Fiyat" to "Ücretsiz"),
            mapOf("Offline Mod" to "Skorlu"),
        )

        invalidOverrides.forEach { overrides ->
            val preview = orchestrator.preview(workbook(settingsOverrides = overrides))
            assertThat(preview.issueCodes())
                .describedAs("settings overrides: $overrides")
                .contains(WorkbookImportIssueCode.INVALID_SETTING_VALUE)
            assertThat(preview.settings).isNull()
            assertThat(preview.plan).isNull()
        }
    }

    @Test
    fun `full preview digest binds settings that do not affect allocation`() {
        val base = orchestrator.preview(workbook())
        val renamed = orchestrator.preview(
            workbook(settingsOverrides = mapOf("Kurs Adı" to "Başka Kurs")),
        )
        val thresholdChanged = orchestrator.preview(
            workbook(settingsOverrides = mapOf("Test Tamamlama Eşiği" to "75%")),
        )
        val visibilityChanged = orchestrator.preview(
            workbook(settingsOverrides = mapOf("Kurs Görünürlüğü" to "Private")),
        )

        val previews = listOf(base, renamed, thresholdChanged, visibilityChanged)
        assertThat(previews).allMatch { preview -> preview.isValid }
        assertThat(previews.map { it.allocationSha256 }).containsOnly(base.allocationSha256)
        assertThat(previews.map { it.previewSha256 })
            .doesNotContainNull()
            .doesNotHaveDuplicates()
            .allMatch { digest -> checkNotNull(digest).matches(Regex("[0-9a-f]{64}")) }
    }

    @Test
    fun `requires exactly one settings sheet and at least one level sheet`() {
        val noSettings = RawXlsxWorkbook(
            rulesVersion = "xlsx-v1",
            sheets = listOf(levelSheet()),
        )
        assertThat(orchestrator.preview(noSettings).issueCodes())
            .contains(WorkbookImportIssueCode.SETTINGS_SHEET_COUNT)

        val settingsOnly = RawXlsxWorkbook(
            rulesVersion = "xlsx-v1",
            sheets = listOf(settingsSheet()),
        )
        assertThat(orchestrator.preview(settingsOnly).issueCodes())
            .contains(WorkbookImportIssueCode.CONTENT_SHEET_MISSING)

        val duplicateSettings = RawXlsxWorkbook(
            rulesVersion = "xlsx-v1",
            sheets = listOf(settingsSheet(), settingsSheet(ordinal = 2)),
        )
        assertThat(orchestrator.preview(duplicateSettings).issueCodes())
            .contains(WorkbookImportIssueCode.SETTINGS_SHEET_COUNT)

        val headerOnly = orchestrator.preview(workbook(contentRows = emptyList()))
        assertThat(headerOnly.issueCodes()).contains(
            WorkbookImportIssueCode.CONTENT_ROW_MISSING,
            WorkbookImportIssueCode.LEVEL_CONTENT_ROW_MISSING,
        )
        assertThat(headerOnly.plan).isNull()

        val emptySecondLevel = orchestrator.preview(
            RawXlsxWorkbook(
                rulesVersion = "xlsx-v1",
                sheets = listOf(settingsSheet(), levelSheet(), levelSheet(ordinal = 2, name = "A2", rows = emptyList())),
            ),
        )
        assertThat(emptySecondLevel.issueCodes()).contains(WorkbookImportIssueCode.LEVEL_CONTENT_ROW_MISSING)
    }

    @Test
    fun `requires exact dynamic headers in declared language order and rejects Soru No`() {
        val wrongLanguageHeader = contentHeader().toMutableList().also { it[7] = "DE" }
        val languagePreview = orchestrator.preview(
            workbook(level = levelSheet(header = wrongLanguageHeader)),
        )
        assertThat(languagePreview.issueCodes()).contains(WorkbookImportIssueCode.HEADER_MISMATCH)

        val withQuestionNumber = contentHeader().toMutableList().also { it.add(3, "Soru No") }
        val questionNumberPreview = orchestrator.preview(
            workbook(level = levelSheet(header = withQuestionNumber)),
        )
        assertThat(questionNumberPreview.issueCodes())
            .contains(WorkbookImportIssueCode.HEADER_COLUMN_COUNT, WorkbookImportIssueCode.HEADER_MISMATCH)
        assertThat(questionNumberPreview.plan).isNull()

        val decomposedHeader = contentHeader().toMutableList().also { it[0] = "U\u0308nite" }
        val normalizedPreview = orchestrator.preview(workbook(level = levelSheet(header = decomposedHeader)))
        assertThat(normalizedPreview.isValid).isTrue()
    }

    @Test
    fun `requires complete word translations and forbids cloze payload on word rows`() {
        val incomplete = wordRow(2).withoutColumn(9).copy(
            cells = wordRow(2).withoutColumn(9).cells + cell(2, 10, "Bu alan olmamalı ---"),
        )
        val preview = orchestrator.preview(workbook(contentRows = listOf(incomplete)))

        assertThat(preview.issueCodes())
            .contains(
                WorkbookImportIssueCode.MISSING_TRANSLATION,
                WorkbookImportIssueCode.UNEXPECTED_FIELD_VALUE,
            )
        assertThat(preview.rows).isEmpty()
        assertThat(preview.plan).isNull()
    }

    @Test
    fun `validates multiple choice cloze marker options and reserved fields`() {
        val invalid = multipleChoiceRow(2).copy(
            cells = multipleChoiceRow(2).cells
                .filterNot { it.columnNumber == 15 }
                .map { cell ->
                    when (cell.columnNumber) {
                        10 -> cell.copy(value = "--- ve ---")
                        else -> cell
                    }
                } + listOf(cell(2, 12, "alternatif"), cell(2, 16, "GRUP")),
        )
        val preview = orchestrator.preview(workbook(contentRows = listOf(invalid)))

        assertThat(preview.issueCodes())
            .contains(
                WorkbookImportIssueCode.INVALID_CLOZE_PLACEHOLDER,
                WorkbookImportIssueCode.INVALID_WRONG_ANSWER_COUNT,
                WorkbookImportIssueCode.UNEXPECTED_FIELD_VALUE,
            )
    }

    @Test
    fun `fails closed when authored multiple choice distractors are absent`() {
        val withoutDistractors = multipleChoiceRow(2).copy(
            cells = multipleChoiceRow(2).cells.filterNot { it.columnNumber in 13..15 },
        )
        val preview = orchestrator.preview(workbook(contentRows = listOf(withoutDistractors)))

        assertThat(preview.issueCodes()).contains(WorkbookImportIssueCode.INVALID_WRONG_ANSWER_COUNT)
        assertThat(preview.plan).isNull()
    }

    @Test
    fun `validates typed cloze payload and answer uniqueness`() {
        val invalid = typedRow(2).copy(
            cells = typedRow(2).cells + listOf(
                cell(2, 7, "Drink"),
                cell(2, 13, "içerim"),
                cell(2, 16, "GRUP"),
            ),
        )
        val preview = orchestrator.preview(workbook(contentRows = listOf(invalid)))

        assertThat(preview.issueCodes())
            .contains(
                WorkbookImportIssueCode.UNEXPECTED_FIELD_VALUE,
                WorkbookImportIssueCode.DUPLICATE_ANSWER_OPTION,
            )
    }

    @Test
    fun `uses the target language typed policy for authored answer collisions`() {
        val collision = typedRow(2).copy(
            cells = typedRow(2).cells.map { cell ->
                when (cell.columnNumber) {
                    11 -> cell.copy(value = "İÇERİM")
                    12 -> cell.copy(value = "içerim")
                    else -> cell
                }
            },
        )
        val preview = orchestrator.preview(workbook(contentRows = listOf(collision)))

        assertThat(preview.issueCodes()).contains(WorkbookImportIssueCode.DUPLICATE_ANSWER_OPTION)
        assertThat(preview.plan).isNull()
    }

    @Test
    fun `uses deterministic Unicode case folding for answer collisions`() {
        val word = wordRow(2, target = "Straße").copy(
            cells = wordRow(2, target = "Straße").cells + cell(2, 13, "STRASSE"),
        )
        val preview = orchestrator.preview(workbook(contentRows = listOf(word)))

        assertThat(preview.issueCodes()).contains(WorkbookImportIssueCode.DUPLICATE_ANSWER_OPTION)
    }

    @Test
    fun `rejects invalid row enums positive integers and structural whitespace`() {
        val invalid = rowOf(
            2,
            1 to " Ünite",
            2 to "Konu",
            3 to "0",
            4 to "Rastgele",
            5 to "Bilinmeyen",
            6 to "hedef",
            17 to "Belki",
        )
        val preview = orchestrator.preview(workbook(contentRows = listOf(invalid)))

        assertThat(preview.issueCodes())
            .contains(
                WorkbookImportIssueCode.INVALID_STRUCTURAL_TEXT,
                WorkbookImportIssueCode.INVALID_TEST_NUMBER,
                WorkbookImportIssueCode.INVALID_TEST_MODE,
                WorkbookImportIssueCode.INVALID_RECORD_TYPE,
                WorkbookImportIssueCode.INVALID_HIDDEN_VALUE,
            )
    }

    @Test
    fun `normalizes NFC content and rejects invisible structural controls`() {
        val decomposed = wordRow(2, target = "Cafe\u0301")
        val valid = orchestrator.preview(workbook(contentRows = listOf(decomposed)))
        assertThat(valid.isValid).isTrue()
        assertThat(valid.rows.single().targetText).isEqualTo("Café")

        val unsafeSheet = levelSheet(name = "A\u202E1")
        val unsafe = orchestrator.preview(workbook(level = unsafeSheet))
        assertThat(unsafe.issueCodes()).contains(WorkbookImportIssueCode.INVALID_STRUCTURAL_TEXT)
        assertThat(unsafe.plan).isNull()

        val joiners = wordRow(2, target = "می\u200Dروم").copy(
            cells = wordRow(2, target = "می\u200Dروم").cells.map { cell ->
                if (cell.columnNumber == 8) cell.copy(value = "می\u200Cروم") else cell
            },
        )
        val joinerContent = orchestrator.preview(workbook(contentRows = listOf(joiners)))
        assertThat(joinerContent.isValid).isTrue()
        assertThat(joinerContent.rows.single().targetText).isEqualTo("می\u200Dروم")
        assertThat(joinerContent.rows.single().translations["ar"]).isEqualTo("می\u200Cروم")

        val joinerStructure = orchestrator.preview(workbook(level = levelSheet(name = "A\u200C2")))
        assertThat(joinerStructure.issueCodes()).contains(WorkbookImportIssueCode.INVALID_STRUCTURAL_TEXT)

        listOf("\u034F", "\uFE0F").forEach { invisibleName ->
            val invisibleStructure = orchestrator.preview(workbook(level = levelSheet(name = invisibleName)))
            assertThat(invisibleStructure.issueCodes())
                .contains(WorkbookImportIssueCode.INVALID_STRUCTURAL_TEXT)
        }
    }

    @Test
    fun `surfaces a domain mode conflict and never exposes a digest for invalid plans`() {
        val rows = listOf(
            wordRow(2, testNumber = "1", mode = "Kelime", target = "Bir"),
            wordRow(3, testNumber = "1", mode = "Karışık", target = "İki"),
        )
        val preview = orchestrator.preview(workbook(contentRows = rows))

        assertThat(preview.issueCodes()).contains(WorkbookImportIssueCode.PLANNING_TEST_MODE_CONFLICT)
        assertThat(preview.plan).isNotNull()
        assertThat(preview.isValid).isFalse()
        assertThat(preview.allocationSha256).isNull()
        assertThat(preview.previewSha256).isNull()
    }

    @Test
    fun `fails closed for unresolved matching hidden and incompatible mode semantics`() {
        val matching = orchestrator.preview(
            workbook(contentRows = listOf(wordRow(2, mode = "Eşleştirme"))),
        )
        assertThat(matching.issueCodes()).contains(WorkbookImportIssueCode.UNSUPPORTED_TEST_MODE)
        assertThat(matching.allocationSha256).isNull()
        assertThat(matching.previewSha256).isNull()

        val incompatible = multipleChoiceRow(2).copy(
            cells = multipleChoiceRow(2).cells + cell(2, 4, "Kelime"),
        )
        val incompatiblePreview = orchestrator.preview(workbook(contentRows = listOf(incompatible)))
        assertThat(incompatiblePreview.issueCodes()).contains(WorkbookImportIssueCode.INCOMPATIBLE_TEST_MODE)

        val hidden = wordRow(2).copy(
            cells = wordRow(2).cells.map { cell ->
                if (cell.columnNumber == 17) cell.copy(value = "Evet") else cell
            },
        )
        val hiddenPreview = orchestrator.preview(workbook(contentRows = listOf(hidden)))
        assertThat(hiddenPreview.issueCodes()).contains(WorkbookImportIssueCode.UNSUPPORTED_HIDDEN_CONTENT)
        assertThat(hiddenPreview.plan).isNull()
    }

    @Test
    fun `returns immutable settings and row snapshots`() {
        val preview = orchestrator.preview(workbook())
        val settingsLanguages = checkNotNull(preview.settings).supportLanguageCodes
        val translations = preview.rows.single().translations
        val wrongAnswers = preview.rows.single().wrongAnswers

        assertThatThrownBy { (settingsLanguages as MutableList<String>).add("de") }
            .isInstanceOf(UnsupportedOperationException::class.java)
        assertThatThrownBy { (translations as MutableMap<String, String>)["de"] = "Wort" }
            .isInstanceOf(UnsupportedOperationException::class.java)
        assertThatThrownBy { (wrongAnswers as MutableList<String>).add("other") }
            .isInstanceOf(UnsupportedOperationException::class.java)
    }

    private fun WorkbookImportPreview.issueCodes(): List<WorkbookImportIssueCode> = issues.map { it.code }

    private fun workbook(
        contentRows: List<RawXlsxRow> = listOf(wordRow(2)),
        settingsOverrides: Map<String, String> = emptyMap(),
        settingsRows: List<RawXlsxRow>? = null,
        level: RawXlsxSheet? = null,
    ): RawXlsxWorkbook {
        val values = settingValues().map { (name, value) -> name to (settingsOverrides[name] ?: value) }
        return RawXlsxWorkbook(
            rulesVersion = "xlsx-v1",
            sheets = listOf(
                settingsSheet(rows = settingsRows ?: settingsSheetRows(values)),
                level ?: levelSheet(rows = contentRows),
            ),
        )
    }

    private fun settingsSheet(
        ordinal: Int = 0,
        rows: List<RawXlsxRow> = settingsSheetRows(settingValues()),
    ): RawXlsxSheet = RawXlsxSheet(
        ordinal = ordinal,
        name = "BILGI_AYARLAR",
        rows = rows,
    )

    private fun settingsSheetRows(values: List<Pair<String, String>>): List<RawXlsxRow> =
        listOf(rowOf(5, 1 to "Ayar", 2 to "Değer", 3 to "Açıklama")) +
            values.mapIndexed { index, (name, value) -> rowOf(index + 6, 1 to name, 2 to value) }

    private fun settingValues(): List<Pair<String, String>> = listOf(
        "Kurs Adı" to "Örnek Türkçe Kelime Kursu",
        "Hedef Dil Kodu" to "TR",
        "Hedef Dil Adı" to "Türkçe",
        "Destek Dilleri" to "EN, AR, FR",
        "Varsayılan Destek Dili" to "EN",
        "Varsayılan Test Modu" to "Karışık",
        "Kurs Görünürlüğü" to "Public",
        "Fiyat" to "Uygulamadan ayarlanır",
        "Varsayılan Test Soru Sayısı" to "20",
        "Son Grup Minimum Soru" to "10",
        "Test No Verilen Testleri Varsayılan Soru Sayısına Tamamla" to "Açık",
        "Test Tamamlama Eşiği" to "50%",
        "Yazmalı Alternatif Cevap" to "En fazla 1",
        "Offline Mod" to "Skorsuz pratik",
    )

    private fun levelSheet(
        ordinal: Int = 1,
        name: String = "Giriş Seviyesi",
        header: List<String> = contentHeader(),
        rows: List<RawXlsxRow> = listOf(wordRow(2)),
    ): RawXlsxSheet = RawXlsxSheet(
        ordinal = ordinal,
        name = name,
        rows = listOf(rowOf(1, *header.mapIndexed { index, value -> index + 1 to value }.toTypedArray())) + rows,
    )

    private fun contentHeader(): List<String> = listOf(
        "Ünite",
        "Konu",
        "Test No",
        "Test Modu (Opsiyonel)",
        "Kayıt Türü",
        "Hedef Kelime/İfade",
        "EN",
        "AR",
        "FR",
        "Cümle (---)",
        "Doğru Cevap",
        "Alternatif Doğru Cevap",
        "Yanlış 1",
        "Yanlış 2",
        "Yanlış 3",
        "Eşleştirme Grubu",
        "Gizli mi?",
        "Not",
    )

    private fun wordRow(
        rowNumber: Int,
        testNumber: String? = null,
        mode: String? = null,
        target: String = "Merhaba",
    ): RawXlsxRow = rowOf(
        rowNumber,
        1 to "Sosyal Hayat",
        2 to "Selamlaşma",
        3 to testNumber,
        4 to mode,
        5 to "Kelime",
        6 to target,
        7 to "Hello $rowNumber",
        8 to "مرحبا $rowNumber",
        9 to "Bonjour $rowNumber",
        17 to "Hayır",
    )

    private fun multipleChoiceRow(rowNumber: Int): RawXlsxRow = rowOf(
        rowNumber,
        1 to "Sosyal Hayat",
        2 to "Selamlaşma",
        5 to "Cümle Seçenekli",
        6 to "içmek",
        10 to "Ben çay ---.",
        11 to "içerim",
        13 to "yerim",
        14 to "koşarım",
        15 to "yazarım",
        17 to "Hayır",
    )

    private fun typedRow(rowNumber: Int): RawXlsxRow = rowOf(
        rowNumber,
        1 to "Sosyal Hayat",
        2 to "Selamlaşma",
        5 to "Cümle Yazmalı",
        6 to "içmek",
        10 to "Ben çay ---.",
        11 to "içerim",
        12 to "içiyorum",
        17 to "Hayır",
    )

    private fun RawXlsxRow.withoutColumn(column: Int): RawXlsxRow =
        copy(cells = cells.filterNot { it.columnNumber == column })

    private fun rowOf(rowNumber: Int, vararg values: Pair<Int, String?>): RawXlsxRow = RawXlsxRow(
        rowNumber = rowNumber,
        cells = values.mapNotNull { (column, value) -> value?.let { cell(rowNumber, column, it) } },
    )

    private fun cell(rowNumber: Int, column: Int, value: String): RawXlsxCell = RawXlsxCell(
        rowNumber = rowNumber,
        columnNumber = column,
        reference = "${('A'.code + column - 1).toChar()}$rowNumber",
        value = value,
    )
}
