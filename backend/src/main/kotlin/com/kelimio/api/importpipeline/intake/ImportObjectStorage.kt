package com.kelimio.api.importpipeline.intake

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component
import software.amazon.awssdk.awscore.AwsRequestOverrideConfiguration
import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.ChecksumAlgorithm
import software.amazon.awssdk.services.s3.model.ChecksumMode
import software.amazon.awssdk.services.s3.model.GetObjectRequest
import software.amazon.awssdk.services.s3.model.HeadObjectRequest
import software.amazon.awssdk.services.s3.model.ListObjectVersionsRequest
import software.amazon.awssdk.services.s3.model.PutObjectRequest
import software.amazon.awssdk.services.s3.model.S3Exception
import java.io.Closeable
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardOpenOption
import java.security.DigestInputStream
import java.security.MessageDigest
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Base64

@Component
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "worker")
class ImportObjectStorage(
    private val s3: S3Client,
    private val settings: ImportRuntimeSettings,
    private val clock: Clock,
) {
    fun downloadQuarantine(claim: ProcessingClaim, deadline: Instant): DownloadedImportObject = downloadAndMeasure(
        bucket = claim.acceptedBucket,
        key = claim.acceptedObjectKey,
        versionId = claim.acceptedVersionId,
        expectedSize = claim.expectedSizeBytes,
        expectedSha256 = claim.assertedSourceSha256,
        stablePrefix = "quarantine",
        deadline = deadline,
    )

    fun archiveSource(
        claim: ProcessingClaim,
        source: DownloadedImportObject,
        now: OffsetDateTime,
        deadline: Instant,
    ): NewImportArtifact {
        val key = "archive/${claim.ownerUserId}/${claim.importId}/source/${source.sha256}.xlsx"
        return putImmutable(
            claim = claim,
            kind = ImportArtifactKind.ARCHIVE_SOURCE,
            key = key,
            mediaType = CourseImportRequestPolicy.XLSX_MEDIA_TYPE,
            sha256 = source.sha256,
            sizeBytes = source.sizeBytes,
            requestBody = RequestBody.fromFile(source.path),
            now = now,
            deadline = deadline,
        )
    }

    fun downloadArchive(
        claim: ProcessingClaim,
        artifact: StoredImportArtifact,
        deadline: Instant,
    ): DownloadedImportObject {
        check(artifact.importId == claim.importId && artifact.artifact.kind == ImportArtifactKind.ARCHIVE_SOURCE)
        return downloadAndMeasure(
            bucket = artifact.artifact.bucket,
            key = artifact.artifact.key,
            versionId = artifact.artifact.versionId,
            expectedSize = artifact.artifact.sizeBytes,
            expectedSha256 = artifact.artifact.sha256,
            stablePrefix = "archive",
            deadline = deadline,
        )
    }

    fun archiveValidationReport(
        claim: ProcessingClaim,
        bytes: ByteArray,
        sha256: String,
        now: OffsetDateTime,
        deadline: Instant,
    ): NewImportArtifact {
        check(hexSha256(bytes) == sha256)
        val key = "archive/${claim.ownerUserId}/${claim.importId}/reports/$sha256.json"
        return putImmutable(
            claim = claim,
            kind = ImportArtifactKind.VALIDATION_REPORT,
            key = key,
            mediaType = "application/json",
            sha256 = sha256,
            sizeBytes = bytes.size.toLong(),
            requestBody = RequestBody.fromBytes(bytes),
            now = now,
            deadline = deadline,
        )
    }

    private fun downloadAndMeasure(
        bucket: String,
        key: String,
        versionId: String,
        expectedSize: Long,
        expectedSha256: String,
        stablePrefix: String,
        deadline: Instant,
    ): DownloadedImportObject {
        val path = Files.createTempFile("kelimio-import-$stablePrefix-", ".bin")
        try {
            val input = s3.getObject(
                GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .versionId(versionId)
                    .checksumMode(ChecksumMode.ENABLED)
                    .overrideConfiguration(deadlineConfiguration(deadline))
                    .build(),
            )
            val measured = input.use { body ->
                val response = body.response()
                if (!response.versionId().isUsableVersionId() || response.versionId() != versionId) {
                    throw ImportStorageException("$stablePrefix-version-mismatch", false)
                }
                if (response.contentLength() != expectedSize) {
                    throw ImportStorageException("$stablePrefix-content-mismatch", false)
                }
                streamBounded(body, path, expectedSize, deadline, stablePrefix)
            }
            if (measured.sizeBytes != expectedSize || measured.sha256 != expectedSha256) {
                throw ImportStorageException("$stablePrefix-content-mismatch", false)
            }
            return DownloadedImportObject(path, measured.sha256, measured.sizeBytes)
        } catch (failure: ImportStorageException) {
            Files.deleteIfExists(path)
            throw failure
        } catch (_: Exception) {
            Files.deleteIfExists(path)
            throw ImportStorageException("$stablePrefix-download-failed", true)
        }
    }

    private fun putImmutable(
        claim: ProcessingClaim,
        kind: ImportArtifactKind,
        key: String,
        mediaType: String,
        sha256: String,
        sizeBytes: Long,
        requestBody: RequestBody,
        now: OffsetDateTime,
        deadline: Instant,
    ): NewImportArtifact {
        val checksum = Base64.getEncoder().encodeToString(hexToBytes(sha256))
        val metadata = mapOf(
            "kelimio-import-id" to claim.importId.toString(),
            "kelimio-owner-id" to claim.ownerUserId.toString(),
            "kelimio-artifact-kind" to kind.name,
            "kelimio-sha256" to sha256,
            "kelimio-size" to sizeBytes.toString(),
        )
        val response = try {
            s3.putObject(
                PutObjectRequest.builder()
                    .bucket(settings.archiveBucket)
                    .key(key)
                    .contentType(mediaType)
                    .contentLength(sizeBytes)
                    .checksumAlgorithm(ChecksumAlgorithm.SHA256)
                    .checksumSHA256(checksum)
                    .metadata(metadata)
                    .ifNoneMatch("*")
                    .overrideConfiguration(deadlineConfiguration(deadline))
                    .build(),
                requestBody,
            )
        } catch (failure: S3Exception) {
            if (failure.statusCode() != 412) throw ImportStorageException("archive-write-failed", true)
            null
        } catch (_: Exception) {
            throw ImportStorageException("archive-write-failed", true)
        }

        val versionId = response?.versionId()?.takeIf { it.isUsableVersionId() }
        val matched = if (versionId == null) {
            recoverImmutableVersion(key, kind, claim, sha256, sizeBytes, mediaType, checksum, deadline)
        } else {
            headMatchingVersion(key, versionId, kind, claim, sha256, sizeBytes, mediaType, checksum, deadline)
                ?: throw ImportStorageException("archive-verification-failed", false)
        }
        return NewImportArtifact(
            kind = kind,
            bucket = settings.archiveBucket,
            key = key,
            versionId = matched.versionId,
            etag = matched.etag,
            sha256 = sha256,
            sizeBytes = sizeBytes,
            mediaType = mediaType,
            createdAt = now.withOffsetSameInstant(ZoneOffset.UTC),
        )
    }

    private fun recoverImmutableVersion(
        key: String,
        kind: ImportArtifactKind,
        claim: ProcessingClaim,
        sha256: String,
        sizeBytes: Long,
        mediaType: String,
        checksum: String,
        deadline: Instant,
    ): MatchedVersion {
        val versions = try {
            s3.listObjectVersionsPaginator(
                ListObjectVersionsRequest.builder().bucket(settings.archiveBucket).prefix(key)
                    .overrideConfiguration(deadlineConfiguration(deadline)).build(),
            ).versions().asSequence()
                .filter { it.key() == key && it.versionId().isUsableVersionId() }
                .take(2)
                .toList()
        } catch (_: Exception) {
            throw ImportStorageException("archive-recovery-failed", true)
        }
        if (versions.size != 1) throw ImportStorageException("archive-version-ambiguous", false)
        return headMatchingVersion(
            key,
            versions.single().versionId(),
            kind,
            claim,
            sha256,
            sizeBytes,
            mediaType,
            checksum,
            deadline,
        ) ?: throw ImportStorageException("archive-version-ambiguous", false)
    }

    private fun headMatchingVersion(
        key: String,
        versionId: String,
        kind: ImportArtifactKind,
        claim: ProcessingClaim,
        sha256: String,
        sizeBytes: Long,
        mediaType: String,
        checksum: String,
        deadline: Instant,
    ): MatchedVersion? {
        val head = try {
            s3.headObject(
            HeadObjectRequest.builder()
                .bucket(settings.archiveBucket)
                .key(key)
                .versionId(versionId)
                .checksumMode(ChecksumMode.ENABLED)
                .overrideConfiguration(deadlineConfiguration(deadline))
                .build(),
            )
        } catch (_: Exception) {
            throw ImportStorageException("archive-verification-unavailable", true)
        }
        val metadata = head.metadata()
        val matches = head.versionId() == versionId && head.contentLength() == sizeBytes &&
            head.contentType() == mediaType && head.checksumSHA256() == checksum &&
            metadata["kelimio-import-id"] == claim.importId.toString() &&
            metadata["kelimio-owner-id"] == claim.ownerUserId.toString() &&
            metadata["kelimio-artifact-kind"] == kind.name &&
            metadata["kelimio-sha256"] == sha256 && metadata["kelimio-size"] == sizeBytes.toString()
        return if (!matches) null else MatchedVersion(
            versionId,
            head.eTag()?.takeIf(String::isNotBlank) ?: return null,
        )
    }

    private fun streamBounded(
        input: java.io.InputStream,
        path: Path,
        expectedSize: Long,
        deadline: Instant,
        stablePrefix: String,
    ): MeasuredObject {
        val digest = MessageDigest.getInstance("SHA-256")
        var size = 0L
        Files.newOutputStream(path, StandardOpenOption.TRUNCATE_EXISTING).use { output ->
            DigestInputStream(input, digest).use { measured ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                if (!clock.instant().isBefore(deadline)) {
                    throw ImportStorageException("$stablePrefix-download-deadline", true)
                }
                val read = measured.read(buffer)
                if (read < 0) break
                size = Math.addExact(size, read.toLong())
                if (size > expectedSize || size > CourseImportRequestPolicy.MAX_FILE_BYTES) {
                    throw ImportStorageException("$stablePrefix-content-mismatch", false)
                }
                output.write(buffer, 0, read)
            }
            }
        }
        return MeasuredObject(size, digest.digest().toHex())
    }

    private fun deadlineConfiguration(deadline: Instant): AwsRequestOverrideConfiguration {
        val remaining = Duration.between(clock.instant(), deadline)
        if (remaining.isZero || remaining.isNegative) throw ImportStorageException("storage-deadline-exceeded", true)
        return AwsRequestOverrideConfiguration.builder()
            .apiCallTimeout(remaining)
            .apiCallAttemptTimeout(remaining)
            .build()
    }

    private fun hexSha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(bytes).toHex()

    private fun hexToBytes(value: String): ByteArray = ByteArray(value.length / 2) { index ->
        value.substring(index * 2, index * 2 + 2).toInt(16).toByte()
    }

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }

    private fun String?.isUsableVersionId(): Boolean = !isNullOrBlank() && !equals("null", ignoreCase = true)

    private data class MeasuredObject(val sizeBytes: Long, val sha256: String)
    private data class MatchedVersion(val versionId: String, val etag: String)
}

class DownloadedImportObject(
    val path: Path,
    val sha256: String,
    val sizeBytes: Long,
) : RedactedImportModel(), Closeable {
    override fun close() {
        Files.deleteIfExists(path)
    }
}

class ImportStorageException(
    val stableCode: String,
    val retryable: Boolean,
) : RuntimeException(stableCode)
