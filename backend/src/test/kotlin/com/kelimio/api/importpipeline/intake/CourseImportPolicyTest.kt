package com.kelimio.api.importpipeline.intake

import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.databind.json.JsonMapper
import com.fasterxml.jackson.module.kotlin.KotlinModule
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxCell
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxRow
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxSheet
import com.kelimio.api.importpipeline.infrastructure.xlsx.RawXlsxWorkbook
import com.kelimio.api.web.NotFoundProblem
import com.kelimio.api.web.UnprocessableProblem
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import software.amazon.awssdk.regions.Region
import java.time.Duration
import java.time.Instant
import java.time.OffsetDateTime
import java.util.Base64
import java.util.UUID

class CourseImportPolicyTest {
    @Test
    fun `presigned uploads expire before the authoritative session boundary`() {
        assertThat(CourseImportPresignPolicy.signatureDuration(Duration.ofSeconds(5))).isNull()
        assertThat(CourseImportPresignPolicy.signatureDuration(Duration.ofMillis(5_999))).isNull()
        assertThat(CourseImportPresignPolicy.signatureDuration(Duration.ofSeconds(6)))
            .isEqualTo(Duration.ofSeconds(1))
        assertThat(CourseImportPresignPolicy.signatureDuration(Duration.ofMinutes(20)))
            .isEqualTo(Duration.ofMinutes(15))

        val sessionExpiry = Instant.parse("2026-08-02T09:15:00Z")
        assertThat(
            CourseImportPresignPolicy.allExpireWithinSession(
                listOf(sessionExpiry.minusMillis(1), sessionExpiry),
                sessionExpiry,
            ),
        ).isTrue()
        assertThat(
            CourseImportPresignPolicy.allExpireWithinSession(
                listOf(sessionExpiry.plusNanos(1)),
                sessionExpiry,
            ),
        ).isFalse()
        assertThat(CourseImportPresignPolicy.allExpireWithinSession(emptyList(), sessionExpiry)).isFalse()
    }

    @Test
    fun `accepts exact sequential multipart declarations`() {
        CourseImportRequestPolicy.validateCreate(validCreate())
    }

    @Test
    fun `rejects gaps changed hashes wrong sizes and disguised file names`() {
        val request = validCreate()
        val invalid = listOf(
            request.copy(parts = request.parts.mapIndexed { index, part -> part.copy(partNumber = index + 2) }),
            request.copy(fileSizeBytes = request.fileSizeBytes + 1),
            request.copy(parts = listOf(request.parts.first().copy(sizeBytes = 123), request.parts.last())),
            request.copy(originalFileName = "course:copy.xlsx"),
            request.copy(originalFileName = "course\u0085copy.xlsx"),
            request.copy(originalFileName = "course\u200bcopy.xlsx"),
            request.copy(originalFileName = "course\uFFF9copy.xlsx"),
            request.copy(originalFileName = "course\uD804\uDCBDcopy.xlsx"),
            request.copy(originalFileName = "course\uDB40\uDC00copy.xlsx"),
        )
        invalid.forEach { value ->
            assertThatThrownBy { CourseImportRequestPolicy.validateCreate(value) }
                .isInstanceOf(UnprocessableProblem::class.java)
        }
    }

    @Test
    fun `completion is bound to the original whole and part digests`() {
        val expected = validCreate().parts.map { CourseImportPart(it.partNumber, it.sizeBytes, it.sha256) }
        val valid = CompleteCourseImportUploadRequest(
            sourceSha256 = "a".repeat(64),
            parts = expected.map { CompletedCourseImportPart(it.partNumber, "etag-${it.partNumber}", it.sha256Base64) },
        )
        CourseImportRequestPolicy.validateCompletion(valid, "a".repeat(64), expected)
        assertThatThrownBy {
            CourseImportRequestPolicy.validateCompletion(
                valid.copy(parts = valid.parts.mapIndexed { index, part ->
                    if (index == 0) part.copy(sha256 = digestBase64(9)) else part
                }),
                "a".repeat(64),
                expected,
            )
        }.isInstanceOf(UnprocessableProblem::class.java)
    }

    @Test
    fun `cursor is opaque and bound to owner import identity and page kind`() {
        val codec = CourseImportCursorCodec(settings())
        val owner = UUID.randomUUID()
        val importId = UUID.randomUUID()
        val identity = "d".repeat(64)
        val cursor = codec.encode(owner, importId, identity, "preview", 27)

        assertThat(cursor).doesNotContain(owner.toString(), importId.toString(), identity)
        assertThat(codec.decode(owner, importId, identity, "preview", cursor)).isEqualTo(27)
        val tamperedCursor = cursor.dropLast(1) + if (cursor.last() == 'A') "B" else "A"
        val invalidOperations: List<() -> Unit> = listOf(
            { check(codec.decode(UUID.randomUUID(), importId, identity, "preview", cursor) >= 0) },
            { check(codec.decode(owner, UUID.randomUUID(), identity, "preview", cursor) >= 0) },
            { check(codec.decode(owner, importId, "e".repeat(64), "preview", cursor) >= 0) },
            { check(codec.decode(owner, importId, identity, "issues", cursor) >= 0) },
            { check(codec.decode(owner, importId, identity, "preview", tamperedCursor) >= 0) },
        )
        invalidOperations.forEach { operation ->
            assertThatThrownBy(operation).isInstanceOf(NotFoundProblem::class.java)
        }
    }

    @Test
    fun `required nullable response members remain present and models redact content`() {
        val mapper = JsonMapper.builder()
            .addModule(KotlinModule.Builder().build())
            .addModule(JavaTimeModule())
            .defaultPropertyInclusion(
                JsonInclude.Value.construct(JsonInclude.Include.NON_NULL, JsonInclude.Include.NON_NULL),
            )
            .build()
        val summary = CourseImportPreviewSummary(false, 0, 0, 0, 0, 0, 0, 1, "a".repeat(64), null, null)
        val status = CourseImportStatusResponse(
            UUID.randomUUID(),
            CourseImportStatus.VALIDATION_FAILED,
            "secret.xlsx",
            CourseImportRequestPolicy.XLSX_MEDIA_TYPE,
            1,
            "xlsx-v1",
            1,
            OffsetDateTime.parse("2026-01-01T00:00:00Z"),
            OffsetDateTime.parse("2026-01-01T00:01:00Z"),
            OffsetDateTime.parse("2026-01-01T00:15:00Z"),
            summary,
            null,
            null,
            null,
        )
        val json = mapper.readTree(mapper.writeValueAsBytes(status))
        assertThat(json.has("approvalBindingSha256")).isTrue()
        assertThat(json.has("approvedAt")).isTrue()
        assertThat(json.has("failureCode")).isTrue()
        assertThat(json["preview"].has("allocationSha256")).isTrue()
        assertThat(json["preview"].has("previewSha256")).isTrue()
        assertThat(json["preview"].has("isValid")).isTrue()
        assertThat(json["preview"].has("valid")).isFalse()
        val sessionJson = mapper.readTree(mapper.writeValueAsBytes(CourseImportUploadSessionResponse(false, status, null)))
        assertThat(sessionJson.has("upload")).isTrue()
        assertThat(sessionJson["upload"].isNull).isTrue()

        val source = CourseImportSource(0, "Sheet", 1, null, null)
        val rowJson = mapper.readTree(
            mapper.writeValueAsBytes(
                CourseImportPreviewRow(
                    1,
                    source,
                    "A1",
                    "U1",
                    "T1",
                    1,
                    "AUTOMATIC",
                    "AUTOMATIC",
                    "WORD",
                    "WORD",
                    "word",
                    mapOf("tr" to "kelime"),
                    null,
                    null,
                    null,
                    emptyList(),
                    null,
                    false,
                    null,
                ),
            ),
        )
        listOf("sentence", "correctAnswer", "alternativeCorrectAnswer", "matchingGroup", "note").forEach {
            assertThat(rowJson.has(it)).isTrue()
        }
        assertThat(rowJson["source"].has("columnNumber")).isTrue()
        assertThat(rowJson["source"].has("reference")).isTrue()
        val issueJson = mapper.readTree(
            mapper.writeValueAsBytes(CourseImportValidationIssue(1, "ERROR", "INVALID", null, "Invalid")),
        )
        assertThat(issueJson.has("source")).isTrue()

        val sentinel = "do-not-log-this-cell"
        val raw = RawXlsxWorkbook("xlsx-v1", listOf(RawXlsxSheet(0, sentinel, listOf(RawXlsxRow(1, listOf(
            RawXlsxCell(1, 1, "A1", sentinel),
        ))))))
        assertThat(raw.toString()).doesNotContain(sentinel).contains("redacted")
        assertThat(validCreate().copy(originalFileName = sentinel).toString()).doesNotContain(sentinel)
        assertThat(truncateImportText("a".repeat(499) + "\uD83D\uDE00tail", 500)).endsWith("\uD83D\uDE00")
    }

    @Test
    fun `approval binding changes with every provenance identity`() {
        val now = OffsetDateTime.parse("2026-01-01T00:00:00Z")
        val importId = UUID.randomUUID()
        val ownerId = UUID.randomUUID()
        fun artifact(kind: ImportArtifactKind, suffix: String) = StoredImportArtifact(
            UUID.nameUUIDFromBytes("$kind-$suffix".toByteArray()),
            importId,
            NewImportArtifact(
                kind,
                "$kind-bucket",
                "$ownerId/$importId/$suffix",
                "version-$suffix",
                "etag-$suffix",
                if (kind == ImportArtifactKind.VALIDATION_REPORT) "b".repeat(64) else "a".repeat(64),
                if (kind == ImportArtifactKind.VALIDATION_REPORT) 7 else 42,
                if (kind == ImportArtifactKind.VALIDATION_REPORT) "application/json" else CourseImportRequestPolicy.XLSX_MEDIA_TYPE,
                now,
            ),
        )
        val quarantine = artifact(ImportArtifactKind.QUARANTINE_SOURCE, "q")
        val archive = artifact(ImportArtifactKind.ARCHIVE_SOURCE, "a").copy(
            artifact = artifact(ImportArtifactKind.ARCHIVE_SOURCE, "a").artifact.copy(sha256 = "a".repeat(64)),
        )
        val report = artifact(ImportArtifactKind.VALIDATION_REPORT, "r")
        val scan = StoredImportScan(
            UUID.randomUUID(),
            importId,
            1,
            quarantine.id,
            NewImportScan(ImportScanVerdict.CLEAN, null, "a".repeat(64), 42, "1.4.5", "123/date", now),
        )
        val input = ImportApprovalBindingInput(
            importId,
            ownerId,
            quarantine,
            archive,
            report,
            scan,
            "xlsx-v1",
            "build-1",
            "c".repeat(64),
            "d".repeat(64),
            "b".repeat(64),
        )
        val original = CanonicalImportApprovalBinding.sha256(input)
        assertThat(original).matches("[0-9a-f]{64}")
        assertThat(
            CanonicalImportApprovalBinding.sha256(input.copy(parserVersion = "build-2")),
        ).isNotEqualTo(original)
        assertThat(
            CanonicalImportApprovalBinding.sha256(
                input.copy(archiveSource = archive.copy(artifact = archive.artifact.copy(versionId = "version-other"))),
            ),
        ).isNotEqualTo(original)
    }

    private fun validCreate(): CreateCourseImportRequest = CreateCourseImportRequest(
        originalFileName = "course.xlsx",
        declaredMediaType = CourseImportRequestPolicy.XLSX_MEDIA_TYPE,
        fileSizeBytes = CourseImportRequestPolicy.PART_BYTES + 7,
        sourceSha256 = "a".repeat(64),
        parts = listOf(
            CourseImportPartDeclaration(1, CourseImportRequestPolicy.PART_BYTES, digestBase64(1)),
            CourseImportPartDeclaration(2, 7, digestBase64(2)),
        ),
    )

    private fun digestBase64(value: Int): String = Base64.getEncoder().encodeToString(ByteArray(32) { value.toByte() })

    private fun settings(): ImportRuntimeSettings = ImportRuntimeSettings(
        environment = "test",
        runtimeRole = ImportRuntimeRole.API,
        region = Region.EU_CENTRAL_1,
        quarantineBucket = "quarantine",
        archiveBucket = "archive",
        queueName = "queue",
        dlqName = "dlq",
        clamAvHost = "localhost",
        clamAvPort = 3310,
        minimumClamAvEngineVersion = "1.4.0",
        minimumClamAvSignatureNumber = 1,
        maxDefinitionAge = Duration.ofHours(72),
        definitionFutureSkew = Duration.ofHours(24),
        parserVersion = "test-revision",
        uploadTtl = Duration.ofMinutes(15),
        cursorHmacKey = ByteArray(32) { 7 },
    )
}
