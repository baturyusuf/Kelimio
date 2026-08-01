package com.kelimio.api.importpipeline

import com.kelimio.api.importpipeline.application.CoursePricingSource
import com.kelimio.api.importpipeline.application.CourseVisibility
import com.kelimio.api.importpipeline.application.OfflineCourseMode
import com.kelimio.api.importpipeline.application.WorkbookImportOrchestrator
import com.kelimio.api.importpipeline.domain.ResolvedTestMode
import com.kelimio.api.importpipeline.domain.RowAllocationReason
import com.kelimio.api.importpipeline.domain.TestAllocationKind
import com.kelimio.api.importpipeline.domain.WorkbookRecordType
import com.kelimio.api.importpipeline.infrastructure.xlsx.SecureXlsxReader
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.security.MessageDigest

class ReviewedWorkbookGoldenTest {
    @Test
    fun `owner supplied workbook produces the reviewed deterministic preview`() {
        val bytes = checkNotNull(javaClass.getResourceAsStream(FIXTURE_PATH)) {
            "Missing reviewed workbook fixture"
        }.use { it.readAllBytes() }
        assertThat(bytes).hasSize(18_707)
        assertThat(sha256(bytes)).isEqualTo(EXPECTED_SOURCE_SHA_256)

        val rawWorkbook = SecureXlsxReader().read(
            originalFileName = "kurs_excel_plani_v3_test_numarali.xlsx",
            declaredMediaType = SecureXlsxReader.XLSX_MEDIA_TYPE,
            source = bytes.inputStream(),
        )
        assertThat(rawWorkbook.sheets.map { it.name })
            .containsExactly("BILGI_AYARLAR", "Giriş Seviyesi", "A2")

        val preview = WorkbookImportOrchestrator().preview(rawWorkbook)

        assertThat(preview.isValid).isTrue()
        assertThat(preview.issues).isEmpty()
        assertThat(preview.rows).hasSize(23)
        assertThat(preview.levelCount).isEqualTo(2)
        assertThat(preview.unitCount).isEqualTo(4)
        assertThat(preview.topicCount).isEqualTo(5)
        assertThat(preview.testCount).isEqualTo(7)
        assertThat(preview.allocationSha256).isEqualTo(EXPECTED_ALLOCATION_SHA_256)
        assertThat(preview.previewSha256).isEqualTo(EXPECTED_PREVIEW_SHA_256)

        val settings = checkNotNull(preview.settings)
        assertThat(settings.courseName).isEqualTo("Örnek Türkçe Kelime Kursu")
        assertThat(settings.targetLanguageCode).isEqualTo("tr")
        assertThat(settings.targetLanguageName).isEqualTo("Türkçe")
        assertThat(settings.supportLanguageCodes).containsExactly("en", "ar", "fr")
        assertThat(settings.defaultSupportLanguageCode).isEqualTo("en")
        assertThat(settings.defaultTestMode).isEqualTo(ResolvedTestMode.MIXED)
        assertThat(settings.visibility).isEqualTo(CourseVisibility.PUBLIC)
        assertThat(settings.pricingSource).isEqualTo(CoursePricingSource.APPLICATION)
        assertThat(settings.targetTestSize).isEqualTo(20)
        assertThat(settings.minimumLastAutomaticTestSize).isEqualTo(10)
        assertThat(settings.fillFixedTests).isTrue()
        assertThat(settings.completionThresholdPercent).isEqualTo(50)
        assertThat(settings.maximumTypedAlternativeAnswers).isEqualTo(1)
        assertThat(settings.offlineMode).isEqualTo(OfflineCourseMode.SCORELESS_PRACTICE)

        assertThat(preview.rows.groupingBy { it.recordType }.eachCount()).containsExactlyInAnyOrderEntriesOf(
            mapOf(
                WorkbookRecordType.WORD to 18,
                WorkbookRecordType.MULTIPLE_CHOICE_CLOZE to 3,
                WorkbookRecordType.TYPED_CLOZE to 2,
            ),
        )

        val tests = checkNotNull(preview.plan).tests
        assertThat(tests.map { "${it.path.level}/${it.path.unit}/${it.path.topic}/${it.number}" })
            .containsExactly(
                "Giriş Seviyesi/Sosyal Hayat/1/1",
                "Giriş Seviyesi/Sosyal Hayat/1/2",
                "Giriş Seviyesi/Sosyal Hayat/1/3",
                "Giriş Seviyesi/Günlük Hayat/İçecekler/1",
                "Giriş Seviyesi/Ev ve Eşyalar/Mobilyalar/1",
                "A2/Sosyal Yaşam/Market ve Sipariş/1",
                "A2/Sosyal Yaşam/Restoran/1",
            )
        assertThat(tests.map { it.rows.size }).containsExactly(2, 3, 1, 2, 4, 8, 3)
        assertThat(tests.map { it.resolvedMode }).containsExactly(
            ResolvedTestMode.WORD,
            ResolvedTestMode.WORD,
            ResolvedTestMode.WORD,
            ResolvedTestMode.MIXED,
            ResolvedTestMode.MIXED,
            ResolvedTestMode.MIXED,
            ResolvedTestMode.MIXED,
        )
        assertThat(tests.map { it.allocationKind }).containsExactly(
            TestAllocationKind.FIXED,
            TestAllocationKind.FIXED,
            TestAllocationKind.FIXED,
            TestAllocationKind.AUTOMATIC,
            TestAllocationKind.AUTOMATIC,
            TestAllocationKind.FIXED,
            TestAllocationKind.AUTOMATIC,
        )

        val marketTest = tests.single { it.path.topic == "Market ve Sipariş" }
        assertThat(marketTest.rows.map { it.reason }).containsExactly(
            RowAllocationReason.FIXED_DECLARATION,
            RowAllocationReason.FIXED_DECLARATION,
            RowAllocationReason.FIXED_DECLARATION,
            RowAllocationReason.FIXED_TEST_FILL,
            RowAllocationReason.FIXED_TEST_FILL,
            RowAllocationReason.FIXED_TEST_FILL,
            RowAllocationReason.FIXED_TEST_FILL,
            RowAllocationReason.FIXED_TEST_FILL,
        )
    }

    private fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes)
        .joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xff) }

    private companion object {
        const val FIXTURE_PATH = "/import/valid/kurs_excel_plani_v3_test_numarali.xlsx"
        const val EXPECTED_SOURCE_SHA_256 =
            "9fb87f680505e949304257e43e09ab0ce7f71324b4a06bcfae919260ab9f889e"
        const val EXPECTED_ALLOCATION_SHA_256 =
            "53475870de974d7d99b4c7480f5bd8347fbaaef70dc2f412f8592199e6beaebd"
        const val EXPECTED_PREVIEW_SHA_256 =
            "f43424163dbbb9ee78380a93a96a65e682ecc200130e303ea3b9a32a89729d66"
    }
}
