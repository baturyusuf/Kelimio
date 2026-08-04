package com.kelimio.api.importpipeline.intake

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.AbortMultipartUploadRequest
import software.amazon.awssdk.services.s3.model.ChecksumMode
import software.amazon.awssdk.services.s3.model.HeadObjectRequest
import software.amazon.awssdk.services.s3.model.ListObjectVersionsRequest
import software.amazon.awssdk.services.s3.model.S3Exception
import java.security.MessageDigest
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID
import java.util.Base64

@Component
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
class CourseImportExpiryWorker(
    private val repository: CourseImportRepository,
    private val processor: CourseImportExpiryProcessor,
    private val clock: Clock,
) {
    @Scheduled(fixedDelayString = "\${KELIMIO_IMPORT_EXPIRY_POLL_MS:30000}")
    fun expireBatch() {
        repository.expiredUploadingIds(now(), 20).forEach(processor::expire)
    }

    private fun now(): OffsetDateTime = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
}

@Service
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
class CourseImportExpiryProcessor(
    private val repository: CourseImportRepository,
    private val s3: S3Client,
    private val clock: Clock,
) {
    @Transactional
    fun expire(importId: UUID) {
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val current = repository.lockExpired(importId, now) ?: return
        val abortFailure = runCatching {
            s3.abortMultipartUpload(
                AbortMultipartUploadRequest.builder()
                    .bucket(current.quarantineBucket)
                    .key(current.quarantineObjectKey)
                    .uploadId(current.multipartUploadId)
                    .build(),
            )
        }.exceptionOrNull()
        // A missing/uncertain upload can be a completed object whose DB commit was lost.
        // It remains UPLOADING so a client completion retry can perform exact-version reconciliation.
        if (abortFailure != null) {
            val missingUpload = abortFailure is S3Exception &&
                (abortFailure.statusCode() == 404 || abortFailure.awsErrorDetails()?.errorCode() == "NoSuchUpload")
            if (!missingUpload) return
            when (completedObjectDisposition(current)) {
                CompletedObjectDisposition.NONE -> Unit
                CompletedObjectDisposition.MATCHING -> {
                    repository.recordRecoveryAlert(current.id, "MATCHING_COMPLETED_OBJECT", now)
                    return
                }
                CompletedObjectDisposition.AMBIGUOUS -> {
                    repository.recordRecoveryAlert(current.id, "AMBIGUOUS_OBJECT_VERSIONS", now)
                    return
                }
                CompletedObjectDisposition.TRANSIENT -> return
            }
        }
        repository.markExpired(current, "import-expiry-worker", now)
    }

    private fun completedObjectDisposition(current: StoredCourseImport): CompletedObjectDisposition {
        return try {
            val versions = s3.listObjectVersionsPaginator(
            ListObjectVersionsRequest.builder()
                .bucket(current.quarantineBucket)
                .prefix(current.quarantineObjectKey)
                .build(),
        ).versions().asSequence()
            .filter {
                it.key() == current.quarantineObjectKey && !it.versionId().isNullOrBlank() &&
                    !it.versionId().equals("null", ignoreCase = true)
            }
            .take(2)
            .toList()
            if (versions.isEmpty()) {
                CompletedObjectDisposition.NONE
            } else if (versions.size != 1) {
                CompletedObjectDisposition.AMBIGUOUS
            } else {
                val head = s3.headObject(
            HeadObjectRequest.builder()
                .bucket(current.quarantineBucket)
                .key(current.quarantineObjectKey)
                .versionId(versions.single().versionId())
                .checksumMode(ChecksumMode.ENABLED)
                .build(),
        )
                val metadata = head.metadata()
                val expectedChecksum = expectedCompositeChecksum(repository.parts(current.id))
                val matches = head.versionId() == versions.single().versionId() &&
                    head.contentLength() == current.fileSizeBytes && head.contentType() == current.declaredMediaType &&
                    head.checksumSHA256() == expectedChecksum &&
                    metadata["kelimio-import-id"] == current.id.toString() &&
                    metadata["kelimio-owner-id"] == current.ownerUserId.toString() &&
                    metadata["kelimio-source-sha256"] == current.assertedSourceSha256 &&
                    metadata["kelimio-source-size"] == current.fileSizeBytes.toString()
                if (matches) CompletedObjectDisposition.MATCHING else CompletedObjectDisposition.AMBIGUOUS
            }
        } catch (_: Exception) {
            CompletedObjectDisposition.TRANSIENT
        }
    }

    private fun expectedCompositeChecksum(parts: List<CourseImportPart>): String {
        val combined = parts.flatMap { Base64.getDecoder().decode(it.sha256Base64).asIterable() }.toByteArray()
        val digest = MessageDigest.getInstance("SHA-256").digest(combined)
        return "${Base64.getEncoder().encodeToString(digest)}-${parts.size}"
    }

    private enum class CompletedObjectDisposition {
        NONE,
        MATCHING,
        AMBIGUOUS,
        TRANSIENT,
    }
}
