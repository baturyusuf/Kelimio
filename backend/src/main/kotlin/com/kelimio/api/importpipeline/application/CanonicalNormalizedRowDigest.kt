package com.kelimio.api.importpipeline.application

import com.kelimio.api.importpipeline.domain.CourseContentPath
import com.kelimio.api.importpipeline.domain.WorkbookRecordType
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

internal object CanonicalNormalizedRowDigest {
    private const val FORMAT_VERSION = "kelimio-normalized-workbook-row-v1"

    fun sha256(
        path: CourseContentPath,
        recordType: WorkbookRecordType,
        targetText: String,
        translations: Map<String, String>,
        sentence: String?,
        correctAnswer: String?,
        alternativeCorrectAnswer: String?,
        wrongAnswers: List<String>,
        matchingGroup: String?,
        hidden: Boolean,
        note: String?,
    ): String {
        val bytes = ByteArrayOutputStream().use { output ->
            DataOutputStream(output).use { data ->
                data.writeText(FORMAT_VERSION)
                data.writeText(path.level)
                data.writeText(path.unit)
                data.writeText(path.topic)
                data.writeText(recordType.name)
                data.writeText(targetText)
                val sortedTranslations = translations.toSortedMap()
                data.writeInt(sortedTranslations.size)
                sortedTranslations.forEach { (language, translation) ->
                    data.writeText(language)
                    data.writeText(translation)
                }
                data.writeNullableText(sentence)
                data.writeNullableText(correctAnswer)
                data.writeNullableText(alternativeCorrectAnswer)
                data.writeInt(wrongAnswers.size)
                wrongAnswers.forEach { wrongAnswer -> data.writeText(wrongAnswer) }
                data.writeNullableText(matchingGroup)
                data.writeBoolean(hidden)
                data.writeNullableText(note)
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

    private fun DataOutputStream.writeNullableText(value: String?) {
        writeBoolean(value != null)
        if (value != null) writeText(value)
    }
}
