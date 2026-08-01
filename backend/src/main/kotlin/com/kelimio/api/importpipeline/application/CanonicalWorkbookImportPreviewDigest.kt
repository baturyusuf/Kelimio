package com.kelimio.api.importpipeline.application

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

/** Canonical digest for approving the complete, valid workbook preview. */
internal object CanonicalWorkbookImportPreviewDigest {
    private const val FORMAT_VERSION = "kelimio-workbook-import-preview-v1"

    fun sha256(
        settings: CourseImportSettings,
        allocationSha256: String,
    ): String {
        require(SHA_256.matches(allocationSha256)) { "Allocation digest must be a lowercase SHA-256 value" }
        val bytes = ByteArrayOutputStream().use { output ->
            DataOutputStream(output).use { data ->
                data.writeText(FORMAT_VERSION)
                data.writeText(settings.rulesVersion)
                data.writeText(settings.courseName)
                data.writeText(settings.targetLanguageCode)
                data.writeText(settings.targetLanguageName)
                data.writeInt(settings.supportLanguageCodes.size)
                settings.supportLanguageCodes.forEach { language -> data.writeText(language) }
                data.writeText(settings.defaultSupportLanguageCode)
                data.writeText(settings.defaultTestMode.name)
                data.writeText(settings.visibility.name)
                data.writeInt(settings.targetTestSize)
                data.writeInt(settings.minimumLastAutomaticTestSize)
                data.writeBoolean(settings.fillFixedTests)
                data.writeInt(settings.completionThresholdPercent)
                data.writeText(settings.pricingSource.name)
                data.writeInt(settings.maximumTypedAlternativeAnswers)
                data.writeText(settings.offlineMode.name)
                data.writeText(allocationSha256)
            }
            output.toByteArray()
        }
        return MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xff) }
    }

    private fun DataOutputStream.writeText(value: String) {
        val bytes = value.toByteArray(StandardCharsets.UTF_8)
        writeInt(bytes.size)
        write(bytes)
    }

    private val SHA_256 = Regex("[0-9a-f]{64}")
}
