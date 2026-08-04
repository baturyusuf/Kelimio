package com.kelimio.api.importpipeline.intake

import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.UUID

object CanonicalImportApprovalBinding {
    fun sha256(input: ImportApprovalBindingInput): String {
        val digest = MessageDigest.getInstance("SHA-256")
        input.fields().forEach { value ->
            val bytes = value.toByteArray(StandardCharsets.UTF_8)
            digest.update(ByteBuffer.allocate(Int.SIZE_BYTES).putInt(bytes.size).array())
            digest.update(bytes)
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}

data class ImportApprovalBindingInput(
    val importId: UUID,
    val ownerUserId: UUID,
    val quarantine: StoredImportArtifact,
    val archiveSource: StoredImportArtifact,
    val validationReport: StoredImportArtifact,
    val cleanScan: StoredImportScan,
    val rulesVersion: String,
    val parserVersion: String,
    val allocationSha256: String,
    val previewSha256: String,
    val validationReportSha256: String,
) : RedactedImportModel() {
    internal fun fields(): List<String> = buildList {
        add("kelimio-course-import-approval-v1")
        add(importId.toString())
        add(ownerUserId.toString())
        addArtifact(quarantine)
        addArtifact(archiveSource)
        addArtifact(validationReport)
        add(cleanScan.id.toString())
        add(cleanScan.scan.sourceSha256)
        add(cleanScan.scan.sourceSizeBytes.toString())
        add(checkNotNull(cleanScan.scan.engineVersion))
        add(checkNotNull(cleanScan.scan.signatureVersion))
        add(rulesVersion)
        add(parserVersion)
        add(allocationSha256)
        add(previewSha256)
        add(validationReportSha256)
    }

    private fun MutableList<String>.addArtifact(value: StoredImportArtifact) {
        add(value.id.toString())
        add(value.artifact.kind.name)
        add(value.artifact.bucket)
        add(value.artifact.key)
        add(value.artifact.versionId)
        add(value.artifact.etag)
        add(value.artifact.sha256)
        add(value.artifact.sizeBytes.toString())
        add(value.artifact.mediaType)
    }
}
