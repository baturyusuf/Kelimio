package com.kelimio.api.language

import java.nio.charset.StandardCharsets
import java.text.Normalizer
import java.util.Locale

/**
 * Versioned comparison policy for immutable Type-D display labels.
 *
 * The returned value is server-only uniqueness material. The authored display spelling remains
 * unchanged and callers must not expose the canonical key in public payloads or diagnostics.
 */
object MatchingLabelPolicy {
    const val VERSION = "matching-label-v1"
    const val MAX_CODE_POINTS = 500
    const val MAX_UTF8_BYTES = 2_000
    const val MAX_CANONICAL_CODE_POINTS = 2_000
    const val MAX_CANONICAL_UTF8_BYTES = 4_000

    fun canonicalize(
        value: String,
        languageTag: String,
        policyVersion: String = VERSION,
    ): String {
        if (policyVersion != VERSION || !CANONICAL_LANGUAGE_TAG.matches(languageTag)) {
            throw InvalidMatchingLabelException()
        }
        validateInput(value)
        val normalized = Normalizer.normalize(value, Normalizer.Form.NFC)
        val whitespaceCanonical = canonicalizeWhitespace(normalized)
        if (whitespaceCanonical.isEmpty()) {
            throw InvalidMatchingLabelException()
        }
        val locale = Locale.forLanguageTag(languageTag)
        val caseCanonical = whitespaceCanonical.uppercase(locale).lowercase(locale)
        val canonical = Normalizer.normalize(caseCanonical, Normalizer.Form.NFC)
        if (
            canonical.isEmpty() ||
            canonical.codePointCount(0, canonical.length) > MAX_CANONICAL_CODE_POINTS ||
            canonical.toByteArray(StandardCharsets.UTF_8).size > MAX_CANONICAL_UTF8_BYTES
        ) {
            throw InvalidMatchingLabelException()
        }
        return canonical
    }

    private fun validateInput(value: String) {
        val codePointCount = value.codePointCount(0, value.length)
        if (
            codePointCount !in 1..MAX_CODE_POINTS ||
            value.toByteArray(StandardCharsets.UTF_8).size > MAX_UTF8_BYTES ||
            value.codePoints().anyMatch(::isForbiddenCodePoint)
        ) {
            throw InvalidMatchingLabelException()
        }
    }

    private fun canonicalizeWhitespace(value: String): String {
        val result = StringBuilder(value.length)
        var pendingSpace = false
        value.codePoints().forEach { codePoint ->
            if (codePoint.isUnicodeWhitespace()) {
                if (result.isNotEmpty()) pendingSpace = true
            } else {
                if (pendingSpace) {
                    result.append(' ')
                    pendingSpace = false
                }
                result.appendCodePoint(codePoint)
            }
        }
        return result.toString()
    }

    private fun isForbiddenCodePoint(codePoint: Int): Boolean =
        when (Character.getType(codePoint)) {
            Character.SURROGATE.toInt(),
            Character.PRIVATE_USE.toInt(),
            Character.UNASSIGNED.toInt(),
            Character.CONTROL.toInt(),
            Character.LINE_SEPARATOR.toInt(),
            Character.PARAGRAPH_SEPARATOR.toInt(),
            -> true

            Character.FORMAT.toInt() -> codePoint !in ALLOWED_FORMAT_CODE_POINTS
            else -> false
        }

    private fun Int.isUnicodeWhitespace(): Boolean =
        Character.isWhitespace(this) || Character.isSpaceChar(this)

    private val ALLOWED_FORMAT_CODE_POINTS = setOf(0x200c, 0x200d)
    private val CANONICAL_LANGUAGE_TAG = Regex(LanguageTagNormalizer.CANONICAL_PATTERN)
}

class InvalidMatchingLabelException : IllegalArgumentException("The matching label is invalid.")
