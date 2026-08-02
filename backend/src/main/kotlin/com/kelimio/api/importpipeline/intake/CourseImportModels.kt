package com.kelimio.api.importpipeline.intake

import com.fasterxml.jackson.annotation.JsonProperty
import com.fasterxml.jackson.annotation.JsonInclude
import com.kelimio.api.web.UnprocessableProblem
import java.time.OffsetDateTime
import java.text.Normalizer
import java.util.Base64
import java.util.UUID

abstract class RedactedImportModel {
    final override fun toString(): String = "${javaClass.simpleName}(redacted)"
}

data class CreateCourseImportRequest(
    val originalFileName: String,
    val declaredMediaType: String,
    val fileSizeBytes: Long,
    val sourceSha256: String,
    val parts: List<CourseImportPartDeclaration>,
) : RedactedImportModel()

data class CourseImportPartDeclaration(
    val partNumber: Int,
    val sizeBytes: Long,
    val sha256: String,
) : RedactedImportModel()

data class CompleteCourseImportUploadRequest(
    val sourceSha256: String,
    val parts: List<CompletedCourseImportPart>,
) : RedactedImportModel()

data class CompletedCourseImportPart(
    val partNumber: Int,
    val eTag: String,
    val sha256: String,
) : RedactedImportModel()

data class ApproveCourseImportRequest(
    val approvalBindingSha256: String,
) : RedactedImportModel()

data class CourseImportUploadSessionResponse(
    val created: Boolean,
    @get:JsonProperty("import")
    val importStatus: CourseImportStatusResponse,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val upload: CourseImportUploadInstructions?,
) : RedactedImportModel()

data class CourseImportUploadInstructions(
    val expiresAt: OffsetDateTime,
    val parts: List<CourseImportPresignedPart>,
) : RedactedImportModel()

data class CourseImportPresignedPart(
    val partNumber: Int,
    val sizeBytes: Long,
    val url: String,
    val requiredHeaders: CourseImportPartHeaders,
) : RedactedImportModel()

data class CourseImportPartHeaders(
    val contentLength: String,
    val sha256: String,
) : RedactedImportModel()

data class CourseImportStatusResponse(
    val id: UUID,
    val status: CourseImportStatus,
    val originalFileName: String,
    val declaredMediaType: String,
    val fileSizeBytes: Long,
    val rulesVersion: String,
    val processingAttempts: Int,
    val createdAt: OffsetDateTime,
    val updatedAt: OffsetDateTime,
    val uploadExpiresAt: OffsetDateTime,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val preview: CourseImportPreviewSummary?,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val approvalBindingSha256: String?,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val approvedAt: OffsetDateTime?,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val failureCode: String?,
) : RedactedImportModel()

enum class CourseImportStatus {
    UPLOADING,
    QUEUED,
    PROCESSING,
    PREVIEW_READY,
    VALIDATION_FAILED,
    MALWARE_REJECTED,
    PROCESSING_FAILED,
    EXPIRED,
    APPROVED,
}

data class CourseImportPreviewSummary(
    @get:JsonProperty("isValid") val isValid: Boolean,
    val rowCount: Int,
    val levelCount: Int,
    val unitCount: Int,
    val topicCount: Int,
    val testCount: Int,
    val warningCount: Int,
    val errorCount: Int,
    val validationReportSha256: String,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val allocationSha256: String?,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val previewSha256: String?,
) : RedactedImportModel()

data class CourseImportPreviewPage(
    val items: List<CourseImportPreviewRow>,
    val nextCursor: String?,
) : RedactedImportModel()

data class CourseImportPreviewRow(
    val ordinal: Int,
    val source: CourseImportSource,
    val level: String,
    val unit: String,
    val topic: String,
    val testNumber: Int,
    val allocationKind: String,
    val allocationReason: String,
    val resolvedMode: String,
    val recordType: String,
    val targetText: String,
    val translations: Map<String, String>,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val sentence: String?,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val correctAnswer: String?,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val alternativeCorrectAnswer: String?,
    val wrongAnswers: List<String>,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val matchingGroup: String?,
    val hidden: Boolean,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val note: String?,
) : RedactedImportModel()

data class CourseImportSource(
    val sheetOrdinal: Int,
    val sheetName: String,
    val rowNumber: Int,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val columnNumber: Int?,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val reference: String?,
) : RedactedImportModel()

data class CourseImportIssuePage(
    val items: List<CourseImportValidationIssue>,
    val nextCursor: String?,
) : RedactedImportModel()

data class CourseImportValidationIssue(
    val ordinal: Int,
    val severity: String,
    val code: String,
    @get:JsonInclude(JsonInclude.Include.ALWAYS) val source: CourseImportSource?,
    val message: String,
) : RedactedImportModel()

data class CourseImportApprovalResponse(
    val importId: UUID,
    val status: CourseImportStatus,
    val approvalBindingSha256: String,
    val approvedAt: OffsetDateTime,
    val created: Boolean,
) : RedactedImportModel()

object CourseImportRequestPolicy {
    const val XLSX_MEDIA_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    const val RULES_VERSION = "xlsx-v1"
    const val MAX_FILE_BYTES = 25L * 1024L * 1024L
    const val PART_BYTES = 5L * 1024L * 1024L
    const val MAX_PARTS = 5

    private val fileNamePattern = Regex("^[^/:\\\\\\u0000-\\u001f\\u007f-\\u009f]{1,250}\\.[xX][lL][sS][xX]$")
    private val sha256Hex = Regex("[0-9a-f]{64}")
    private val sha256Base64 = Regex("[A-Za-z0-9+/]{43}=")
    private val opaqueEtag = Regex("[\\x21-\\x7e]{1,256}")

    fun validateCreate(request: CreateCourseImportRequest) {
        rejectUnless(fileNamePattern.matches(request.originalFileName))
        rejectUnless(request.originalFileName == request.originalFileName.trim())
        rejectUnless(request.originalFileName.codePoints().noneMatch(::isDefaultIgnorable))
        rejectUnless(request.declaredMediaType == XLSX_MEDIA_TYPE)
        rejectUnless(request.fileSizeBytes in 1..MAX_FILE_BYTES)
        rejectUnless(sha256Hex.matches(request.sourceSha256))
        rejectUnless(request.parts.size in 1..MAX_PARTS)
        rejectUnless(request.parts.map { it.partNumber } == (1..request.parts.size).toList())
        rejectUnless(request.parts.sumOf { it.sizeBytes } == request.fileSizeBytes)
        request.parts.forEachIndexed { index, part ->
            val finalPart = index == request.parts.lastIndex
            rejectUnless(part.sizeBytes in 1..PART_BYTES)
            rejectUnless(finalPart || part.sizeBytes == PART_BYTES)
            rejectUnless(sha256Base64.matches(part.sha256) && decodesToSha256(part.sha256))
        }
    }

    fun normalizeFileName(value: String): String = Normalizer.normalize(value, Normalizer.Form.NFC)

    fun validateCompletion(
        request: CompleteCourseImportUploadRequest,
        expectedSourceSha256: String,
        expectedParts: List<CourseImportPart>,
    ) {
        rejectUnless(request.sourceSha256 == expectedSourceSha256)
        rejectUnless(request.parts.size == expectedParts.size)
        request.parts.zip(expectedParts).forEach { (actual, expected) ->
            rejectUnless(actual.partNumber == expected.partNumber)
            rejectUnless(actual.sha256 == expected.sha256Base64)
            rejectUnless(opaqueEtag.matches(actual.eTag))
        }
    }

    fun validateApprovalDigest(value: String) {
        rejectUnless(sha256Hex.matches(value))
    }

    private fun decodesToSha256(value: String): Boolean =
        runCatching { Base64.getDecoder().decode(value).size == 32 }.getOrDefault(false)

    private fun isDefaultIgnorable(codePoint: Int): Boolean =
        Character.getType(codePoint) == Character.FORMAT.toInt() ||
            codePoint == 0x00ad || codePoint == 0x034f || codePoint == 0x061c ||
            codePoint in 0x115f..0x1160 || codePoint in 0x17b4..0x17b5 ||
            codePoint in 0x180b..0x180f || codePoint in 0x200b..0x200f ||
            codePoint in 0x202a..0x202e || codePoint in 0x2060..0x206f ||
            codePoint == 0x3164 || codePoint in 0xfe00..0xfe0f || codePoint == 0xfeff ||
            codePoint == 0xffa0 || codePoint in 0xfff0..0xfff8 ||
            codePoint in 0x1bca0..0x1bca3 || codePoint in 0x1d173..0x1d17a ||
            codePoint in 0xe0000..0xe0fff

    private fun rejectUnless(value: Boolean) {
        if (!value) throw UnprocessableProblem("The course import request is invalid.")
    }
}

data class CourseImportPart(
    val partNumber: Int,
    val sizeBytes: Long,
    val sha256Base64: String,
) : RedactedImportModel()

data class StoredCourseImport(
    val id: UUID,
    val ownerUserId: UUID,
    val status: CourseImportStatus,
    val stateVersion: Long,
    val rulesVersion: String,
    val originalFileName: String,
    val declaredMediaType: String,
    val fileSizeBytes: Long,
    val assertedSourceSha256: String,
    val quarantineBucket: String,
    val quarantineObjectKey: String,
    val multipartUploadId: String,
    val uploadExpiresAt: OffsetDateTime,
    val acceptedVersionId: String?,
    val acceptedEtag: String?,
    val processingAttempts: Int,
    val leaseToken: UUID?,
    val leaseExpiresAt: OffsetDateTime?,
    val failureCode: String?,
    val createdAt: OffsetDateTime,
    val updatedAt: OffsetDateTime,
) : RedactedImportModel()

data class StoredPreview(
    val importId: UUID,
    val quarantineArtifactId: UUID,
    val archiveSourceArtifactId: UUID,
    val reportArtifactId: UUID,
    val cleanScanId: UUID,
    val rulesVersion: String,
    val parserVersion: String,
    val summary: CourseImportPreviewSummary,
    val approvalBindingSha256: String?,
) : RedactedImportModel()

data class StoredApproval(
    val importId: UUID,
    val approvalBindingSha256: String,
    val approvedAt: OffsetDateTime,
) : RedactedImportModel()

internal fun truncateImportText(value: String, maximumCodePoints: Int): String {
    require(maximumCodePoints >= 0)
    if (value.codePointCount(0, value.length) <= maximumCodePoints) return value
    return value.substring(0, value.offsetByCodePoints(0, maximumCodePoints))
}
