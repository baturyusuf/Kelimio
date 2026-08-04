package com.kelimio.api.importpipeline.intake

import jakarta.annotation.PostConstruct
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.BucketVersioningStatus
import software.amazon.awssdk.services.s3.model.GetBucketVersioningRequest

@Component
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
class ImportBucketVersioningVerifier(
    private val s3: S3Client,
    private val settings: ImportRuntimeSettings,
) {
    @PostConstruct
    fun verifyImmutableVersionPrerequisite() {
        val buckets = if (settings.runtimeRole == ImportRuntimeRole.API) {
            listOf(settings.quarantineBucket)
        } else {
            listOf(settings.quarantineBucket, settings.archiveBucket)
        }
        buckets.forEach { bucket ->
            val status = runCatching {
                s3.getBucketVersioning(GetBucketVersioningRequest.builder().bucket(bucket).build()).status()
            }.getOrElse { throw IllegalStateException("Import object-store prerequisites are unavailable.") }
            check(status == BucketVersioningStatus.ENABLED) {
                "Import object-store versioning must be enabled."
            }
        }
    }
}
