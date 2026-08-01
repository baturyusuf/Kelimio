package com.kelimio.api.importpipeline.infrastructure.xlsx

import java.time.Duration

/**
 * Security limits for one immutable XLSX ruleset.
 *
 * Callers may supply a stricter instance for a constrained worker, but changing
 * [V1] is a rules-version change governed by ADR-006.
 */
data class XlsxImportLimits(
    val rulesVersion: String,
    val maxCompressedBytes: Long,
    val maxZipEntries: Int,
    val maxInflatedEntryBytes: Long,
    val maxTotalInflatedBytes: Long,
    val maxInflationRatio: Double,
    val inflationRatioGraceBytes: Long,
    val maxWorkbookMetadataPartBytes: Long,
    val maxStylesPartBytes: Long,
    val maxThemePartBytes: Long,
    val maxSharedStringsPartBytes: Long,
    val maxSheets: Int,
    val maxColumns: Int,
    val maxSemanticRows: Int,
    val maxCellCharacters: Int,
    val maxTotalTextCharacters: Long,
    val maxSharedStringItems: Int,
    val maxStyleRecords: Int,
    val maxWallClock: Duration,
) {
    init {
        require(rulesVersion.isNotBlank())
        require(maxCompressedBytes > 0)
        require(maxZipEntries > 0)
        require(maxInflatedEntryBytes > 0)
        require(maxTotalInflatedBytes >= maxInflatedEntryBytes)
        require(maxInflationRatio >= 1.0)
        require(inflationRatioGraceBytes >= 0)
        require(maxWorkbookMetadataPartBytes > 0)
        require(maxStylesPartBytes > 0)
        require(maxThemePartBytes > 0)
        require(maxSharedStringsPartBytes > 0)
        require(maxSheets > 0)
        require(maxColumns > 0)
        require(maxSemanticRows > 0)
        require(maxCellCharacters > 0)
        require(maxTotalTextCharacters > 0)
        require(maxSharedStringItems > 0)
        require(maxStyleRecords > 0)
        require(!maxWallClock.isZero && !maxWallClock.isNegative)
    }

    internal fun requireNoLooserThan(baseline: XlsxImportLimits) {
        require(rulesVersion == baseline.rulesVersion) {
            "A different XLSX security policy requires a new reader rules version"
        }
        require(maxCompressedBytes <= baseline.maxCompressedBytes)
        require(maxZipEntries <= baseline.maxZipEntries)
        require(maxInflatedEntryBytes <= baseline.maxInflatedEntryBytes)
        require(maxTotalInflatedBytes <= baseline.maxTotalInflatedBytes)
        require(maxInflationRatio <= baseline.maxInflationRatio)
        require(inflationRatioGraceBytes <= baseline.inflationRatioGraceBytes)
        require(maxWorkbookMetadataPartBytes <= baseline.maxWorkbookMetadataPartBytes)
        require(maxStylesPartBytes <= baseline.maxStylesPartBytes)
        require(maxThemePartBytes <= baseline.maxThemePartBytes)
        require(maxSharedStringsPartBytes <= baseline.maxSharedStringsPartBytes)
        require(maxSheets <= baseline.maxSheets)
        require(maxColumns <= baseline.maxColumns)
        require(maxSemanticRows <= baseline.maxSemanticRows)
        require(maxCellCharacters <= baseline.maxCellCharacters)
        require(maxTotalTextCharacters <= baseline.maxTotalTextCharacters)
        require(maxSharedStringItems <= baseline.maxSharedStringItems)
        require(maxStyleRecords <= baseline.maxStyleRecords)
        require(maxWallClock <= baseline.maxWallClock)
    }

    companion object {
        private const val MEBIBYTE = 1024L * 1024L

        val V1 = XlsxImportLimits(
            rulesVersion = "xlsx-v1",
            maxCompressedBytes = 25L * MEBIBYTE,
            // Do not relax POI's process-global ZipSecureFile file-count guard.
            maxZipEntries = 1_000,
            maxInflatedEntryBytes = 100L * MEBIBYTE,
            maxTotalInflatedBytes = 200L * MEBIBYTE,
            maxInflationRatio = 100.0,
            // Tiny XML parts can legitimately have a high ratio while remaining
            // harmless. Above this absolute size the ratio limit applies.
            // Match POI's effective ZipSecureFile grace so a package cannot
            // pass preflight and then fail later under a stricter hidden limit.
            inflationRatioGraceBytes = 100L * 1024L,
            maxWorkbookMetadataPartBytes = 1L * MEBIBYTE,
            maxStylesPartBytes = 8L * MEBIBYTE,
            maxThemePartBytes = 2L * MEBIBYTE,
            maxSharedStringsPartBytes = 64L * MEBIBYTE,
            maxSheets = 64,
            maxColumns = 64,
            maxSemanticRows = 10_000,
            maxCellCharacters = 2_000,
            maxTotalTextCharacters = 20_000_000,
            maxSharedStringItems = 640_000,
            maxStyleRecords = 10_000,
            maxWallClock = Duration.ofMinutes(6),
        )
    }
}
