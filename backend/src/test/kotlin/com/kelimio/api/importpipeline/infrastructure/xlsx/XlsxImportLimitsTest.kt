package com.kelimio.api.importpipeline.infrastructure.xlsx

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatCode
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.time.Duration

class XlsxImportLimitsTest {
    @Test
    fun `v1 limits remain the accepted ADR boundary`() {
        assertThat(XlsxImportLimits.V1).isEqualTo(
            XlsxImportLimits(
                rulesVersion = "xlsx-v1",
                maxCompressedBytes = 25L * 1024L * 1024L,
                maxZipEntries = 1_000,
                maxInflatedEntryBytes = 100L * 1024L * 1024L,
                maxTotalInflatedBytes = 200L * 1024L * 1024L,
                maxInflationRatio = 100.0,
                inflationRatioGraceBytes = 100L * 1024L,
                maxWorkbookMetadataPartBytes = 1L * 1024L * 1024L,
                maxStylesPartBytes = 8L * 1024L * 1024L,
                maxThemePartBytes = 2L * 1024L * 1024L,
                maxSharedStringsPartBytes = 64L * 1024L * 1024L,
                maxSheets = 64,
                maxColumns = 64,
                maxSemanticRows = 10_000,
                maxCellCharacters = 2_000,
                maxTotalTextCharacters = 20_000_000,
                maxSharedStringItems = 640_000,
                maxStyleRecords = 10_000,
                maxWallClock = Duration.ofMinutes(6),
            ),
        )
    }

    @Test
    fun `reader accepts tighter v1 limits but refuses every silent relaxation`() {
        assertThatCode {
            SecureXlsxReader(
                XlsxImportLimits.V1.copy(
                    maxCompressedBytes = XlsxImportLimits.V1.maxCompressedBytes - 1,
                    maxWallClock = XlsxImportLimits.V1.maxWallClock.minusMillis(1),
                ),
            )
        }.doesNotThrowAnyException()

        val v1 = XlsxImportLimits.V1
        val relaxedPolicies = listOf(
            v1.copy(rulesVersion = "xlsx-v2"),
            v1.copy(maxCompressedBytes = v1.maxCompressedBytes + 1),
            v1.copy(maxZipEntries = v1.maxZipEntries + 1),
            v1.copy(maxInflatedEntryBytes = v1.maxInflatedEntryBytes + 1),
            v1.copy(maxTotalInflatedBytes = v1.maxTotalInflatedBytes + 1),
            v1.copy(maxInflationRatio = v1.maxInflationRatio + 1),
            v1.copy(inflationRatioGraceBytes = v1.inflationRatioGraceBytes + 1),
            v1.copy(maxWorkbookMetadataPartBytes = v1.maxWorkbookMetadataPartBytes + 1),
            v1.copy(maxStylesPartBytes = v1.maxStylesPartBytes + 1),
            v1.copy(maxThemePartBytes = v1.maxThemePartBytes + 1),
            v1.copy(maxSharedStringsPartBytes = v1.maxSharedStringsPartBytes + 1),
            v1.copy(maxSheets = v1.maxSheets + 1),
            v1.copy(maxColumns = v1.maxColumns + 1),
            v1.copy(maxSemanticRows = v1.maxSemanticRows + 1),
            v1.copy(maxCellCharacters = v1.maxCellCharacters + 1),
            v1.copy(maxTotalTextCharacters = v1.maxTotalTextCharacters + 1),
            v1.copy(maxSharedStringItems = v1.maxSharedStringItems + 1),
            v1.copy(maxStyleRecords = v1.maxStyleRecords + 1),
            v1.copy(maxWallClock = v1.maxWallClock.plusMillis(1)),
        )

        relaxedPolicies.forEach { policy ->
            assertThatThrownBy { SecureXlsxReader(policy) }
                .isInstanceOf(IllegalArgumentException::class.java)
        }
    }
}
