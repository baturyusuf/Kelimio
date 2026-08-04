package com.kelimio.api.importpipeline.intake

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.SerializationFeature
import com.kelimio.api.importpipeline.application.WorkbookImportIssue
import com.kelimio.api.importpipeline.application.WorkbookImportOrchestrator
import com.kelimio.api.importpipeline.application.WorkbookImportPreview
import com.kelimio.api.importpipeline.infrastructure.xlsx.SecureXlsxReader
import com.kelimio.api.importpipeline.infrastructure.xlsx.XlsxImportLimits
import com.kelimio.api.importpipeline.infrastructure.xlsx.XlsxRejectedException
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component
import java.nio.file.Files
import java.nio.file.Path
import java.security.MessageDigest
import java.time.Clock
import java.time.Duration
import java.time.Instant

@Component
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "worker")
class ImportPreviewMaterializer(
    objectMapper: ObjectMapper,
    private val settings: ImportRuntimeSettings,
    private val clock: Clock,
) {
    private val reportWriter = objectMapper.writer()
        .with(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS)
    private val orchestrator = WorkbookImportOrchestrator()

    fun materialize(
        claim: ProcessingClaim,
        verifiedArchive: Path,
        deadline: Instant,
    ): MaterializedImportPreview {
        val remaining = Duration.between(clock.instant(), deadline)
        if (remaining.isZero || remaining.isNegative) {
            throw ImportMaterializationException("parser-deadline-exceeded", retryable = true)
        }
        val baseline = when (claim.rulesVersion) {
            XlsxImportLimits.V1.rulesVersion -> XlsxImportLimits.V1
            XlsxImportLimits.V2.rulesVersion -> XlsxImportLimits.V2
            else -> throw ImportMaterializationException("unsupported-rules-version", retryable = false)
        }
        val reader = SecureXlsxReader(
            baseline.copy(maxWallClock = minOf(remaining, baseline.maxWallClock)),
        )
        val preview = try {
            Files.newInputStream(verifiedArchive).use { input ->
                orchestrator.preview(
                    reader.read(claim.originalFileName, claim.declaredMediaType, input),
                    checkpoint = { requireBefore(deadline) },
                )
            }
        } catch (rejected: XlsxRejectedException) {
            if (rejected.code.name in SYSTEM_XLSX_REJECTIONS) {
                throw ImportMaterializationException(
                    stableCode = when (rejected.code.name) {
                        "PARSE_DEADLINE_EXCEEDED" -> "parser-deadline-exceeded"
                        else -> "parser-temporary-storage-failure"
                    },
                    retryable = true,
                )
            }
            return rejectedPreview(claim, rejected)
        }
        if (!clock.instant().isBefore(deadline)) {
            throw ImportMaterializationException("parser-deadline-exceeded", retryable = true)
        }
        val truncated = preview.issues.size > MAX_PERSISTED_ISSUES
        val rawIssues = preview.issues.take(
            if (truncated) MAX_PERSISTED_ISSUES - 1 else MAX_PERSISTED_ISSUES,
        ).mapIndexed { index, issue -> issue.toPublic(index + 1) }
        val issues = if (truncated) {
            rawIssues.take(MAX_PERSISTED_ISSUES - 1) + CourseImportValidationIssue(
                ordinal = MAX_PERSISTED_ISSUES,
                severity = "ERROR",
                code = "ISSUE_LIMIT_EXCEEDED",
                source = null,
                message = "The workbook produced too many validation issues.",
            )
        } else {
            rawIssues
        }
        val effectiveValid = preview.isValid && !truncated
        val rows = if (effectiveValid) publicRows(preview) { requireBefore(deadline) } else emptyList()
        requireBefore(deadline)
        val counts = PreviewCounts(
            isValid = effectiveValid,
            rowCount = rows.size,
            questionCount = preview.composition?.questionCount?.takeIf { effectiveValid },
            matchingQuestionCount = preview.composition?.matchingQuestionCount?.takeIf { effectiveValid },
            requiredClientCapabilities = preview.composition?.requiredClientCapabilities?.takeIf { effectiveValid },
            levelCount = if (effectiveValid) preview.levelCount else 0,
            unitCount = if (effectiveValid) preview.unitCount else 0,
            topicCount = if (effectiveValid) preview.topicCount else 0,
            testCount = if (effectiveValid) preview.testCount else 0,
            warningCount = issues.count { it.severity == "WARNING" },
            errorCount = issues.count { it.severity == "ERROR" },
            allocationSha256 = preview.allocationSha256.takeIf { effectiveValid },
            previewSha256 = preview.previewSha256.takeIf { effectiveValid },
        )
        check(!counts.isValid || counts.errorCount == 0)
        val publicSettings = preview.settings?.takeIf { effectiveValid }?.let {
            CourseImportPreviewSettings(
                courseName = it.courseName,
                targetLanguageCode = it.targetLanguageCode,
                targetLanguageName = it.targetLanguageName,
                supportLanguageCodes = it.supportLanguageCodes,
                defaultSupportLanguageCode = it.defaultSupportLanguageCode,
                defaultTestMode = it.defaultTestMode.name,
                visibility = it.visibility.name,
                targetTestSize = it.targetTestSize,
                minimumLastAutomaticTestSize = it.minimumLastAutomaticTestSize,
                fillFixedTests = it.fillFixedTests,
                completionThresholdPercent = it.completionThresholdPercent,
                pricingSource = it.pricingSource.name,
                maximumTypedAlternativeAnswers = it.maximumTypedAlternativeAnswers,
                offlineMode = it.offlineMode.name,
            )
        }
        val report = validationReport(claim, counts, issues)
        requireBefore(deadline)
        return MaterializedImportPreview(
            summary = counts.toSummary(report.sha256, publicSettings),
            rows = rows,
            issues = issues,
            reportBytes = report.bytes,
        )
    }

    private fun publicRows(preview: WorkbookImportPreview, checkpoint: () -> Unit): List<CourseImportPreviewRow> {
        val normalized = preview.rows.associateBy {
            checkpoint()
            it.source
        }
        return checkNotNull(preview.plan).tests.flatMap { test ->
            checkpoint()
            test.rows.map { planned ->
                checkpoint()
                test to planned
            }
        }.mapIndexed { index, (test, planned) ->
            checkpoint()
            val row = checkNotNull(normalized[planned.row.source])
            CourseImportPreviewRow(
                ordinal = index + 1,
                questionOrdinal = checkNotNull(preview.composition).row(row.source).questionOrdinal,
                projectedQuestionType = preview.composition.row(row.source).questionType.name,
                compositionKind = preview.composition.row(row.source).compositionKind.name,
                groupPosition = preview.composition.row(row.source).groupPosition,
                source = CourseImportSource(
                    sheetOrdinal = row.source.sheetOrdinal,
                    sheetName = row.source.sheetName,
                    rowNumber = row.source.rowNumber,
                    columnNumber = null,
                    reference = null,
                ),
                level = row.path.level,
                unit = row.path.unit,
                topic = row.path.topic,
                testNumber = test.number,
                allocationKind = test.allocationKind.name,
                allocationReason = planned.reason.name,
                resolvedMode = checkNotNull(test.resolvedMode).name,
                recordType = row.recordType.name,
                targetText = row.targetText,
                translations = row.translations.toSortedMap(),
                sentence = row.sentence,
                correctAnswer = row.correctAnswer,
                alternativeCorrectAnswer = row.alternativeCorrectAnswer,
                wrongAnswers = row.wrongAnswers,
                matchingGroup = row.matchingGroup,
                hidden = row.hidden,
                note = row.note,
            )
        }
    }

    private fun rejectedPreview(
        claim: ProcessingClaim,
        rejected: XlsxRejectedException,
    ): MaterializedImportPreview {
        val issue = CourseImportValidationIssue(
            ordinal = 1,
            severity = "ERROR",
            code = "XLSX_${rejected.code.name}",
            source = null,
            message = "The workbook failed secure XLSX validation.",
        )
        val counts = PreviewCounts(false, 0, null, null, null, 0, 0, 0, 0, 0, 1, null, null)
        val report = validationReport(claim, counts, listOf(issue))
        return MaterializedImportPreview(counts.toSummary(report.sha256, null), emptyList(), listOf(issue), report.bytes)
    }

    private fun validationReport(
        claim: ProcessingClaim,
        counts: PreviewCounts,
        issues: List<CourseImportValidationIssue>,
    ): DeterministicReport {
        val report = mapOf(
            "schemaVersion" to 2,
            "importId" to claim.importId.toString(),
            "sourceSha256" to claim.assertedSourceSha256,
            "sourceSizeBytes" to claim.expectedSizeBytes,
            "rulesVersion" to claim.rulesVersion,
            "parserVersion" to settings.parserVersion,
            "valid" to counts.isValid,
            "rowCount" to counts.rowCount,
            "questionCount" to counts.questionCount,
            "matchingQuestionCount" to counts.matchingQuestionCount,
            "requiredClientCapabilities" to counts.requiredClientCapabilities,
            "levelCount" to counts.levelCount,
            "unitCount" to counts.unitCount,
            "topicCount" to counts.topicCount,
            "testCount" to counts.testCount,
            "warningCount" to counts.warningCount,
            "errorCount" to counts.errorCount,
            "allocationSha256" to counts.allocationSha256,
            "previewSha256" to counts.previewSha256,
            "issues" to issues,
        )
        val bytes = reportWriter.writeValueAsBytes(report)
        if (bytes.size > MAX_REPORT_BYTES) {
            throw ImportMaterializationException("validation-report-too-large", retryable = false)
        }
        return DeterministicReport(bytes, sha256(bytes))
    }

    private fun WorkbookImportIssue.toPublic(ordinal: Int): CourseImportValidationIssue =
        CourseImportValidationIssue(
            ordinal = ordinal,
            severity = severity.name,
            code = code.name,
            source = source?.let {
                CourseImportSource(it.sheetOrdinal, it.sheetName, it.rowNumber, it.columnNumber, it.reference)
            },
            message = truncateImportText(message, 500),
        )

    private fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes).joinToString("") { "%02x".format(it) }

    private fun requireBefore(deadline: Instant) {
        if (!clock.instant().isBefore(deadline)) {
            throw ImportMaterializationException("parser-deadline-exceeded", retryable = true)
        }
    }

    private data class PreviewCounts(
        val isValid: Boolean,
        val rowCount: Int,
        val questionCount: Int?,
        val matchingQuestionCount: Int?,
        val requiredClientCapabilities: List<String>?,
        val levelCount: Int,
        val unitCount: Int,
        val topicCount: Int,
        val testCount: Int,
        val warningCount: Int,
        val errorCount: Int,
        val allocationSha256: String?,
        val previewSha256: String?,
    ) {
        fun toSummary(reportSha256: String, settings: CourseImportPreviewSettings?) = CourseImportPreviewSummary(
            isValid = isValid,
            rowCount = rowCount,
            questionCount = questionCount,
            matchingQuestionCount = matchingQuestionCount,
            requiredClientCapabilities = requiredClientCapabilities,
            levelCount = levelCount,
            unitCount = unitCount,
            topicCount = topicCount,
            testCount = testCount,
            warningCount = warningCount,
            errorCount = errorCount,
            validationReportSha256 = reportSha256,
            allocationSha256 = allocationSha256,
            previewSha256 = previewSha256,
            settings = settings,
        )
    }

    private data class DeterministicReport(val bytes: ByteArray, val sha256: String)

    private companion object {
        const val MAX_PERSISTED_ISSUES = 2_000
        const val MAX_REPORT_BYTES = 4 * 1024 * 1024
        val SYSTEM_XLSX_REJECTIONS = setOf("PARSE_DEADLINE_EXCEEDED", "TEMPORARY_STORAGE_FAILURE")
    }
}

data class MaterializedImportPreview(
    val summary: CourseImportPreviewSummary,
    val rows: List<CourseImportPreviewRow>,
    val issues: List<CourseImportValidationIssue>,
    val reportBytes: ByteArray,
) : RedactedImportModel()

class ImportMaterializationException(
    val stableCode: String,
    val retryable: Boolean,
) : RuntimeException(stableCode)
