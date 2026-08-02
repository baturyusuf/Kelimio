package com.kelimio.api.language

import java.nio.charset.StandardCharsets
import java.text.Normalizer
import java.util.Locale

/**
 * Versioned, locale-pinned comparison policy for authored and submitted Type-C answers.
 *
 * The returned value is server-only comparison material. Callers must not log, emit, or persist
 * learner canonical values.
 */
object TypedAnswerPolicy {
    const val VERSION = "typed-answer-v1"
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
            throw InvalidTypedAnswerException()
        }
        val whitespaceCanonical = normalizeRawEnvelope(value)
        val locale = Locale.forLanguageTag(languageTag)
        val caseCanonical = whitespaceCanonical.uppercase(locale).lowercase(locale)
        val canonical = Normalizer.normalize(caseCanonical, Normalizer.Form.NFC)
        if (
            canonical.isEmpty() ||
            canonical.codePointCount(0, canonical.length) > MAX_CANONICAL_CODE_POINTS ||
            canonical.toByteArray(StandardCharsets.UTF_8).size > MAX_CANONICAL_UTF8_BYTES
        ) {
            throw InvalidTypedAnswerException()
        }
        return canonical
    }

    /** Locale-independent request-envelope checks safe to run before transactional command handling. */
    fun validateRawEnvelope(value: String) {
        normalizeRawEnvelope(value)
    }

    private fun normalizeRawEnvelope(value: String): String {
        validateInput(value)
        val normalized = Normalizer.normalize(value, Normalizer.Form.NFC)
        val whitespaceCanonical = canonicalizeWhitespace(normalized)
        if (whitespaceCanonical.isEmpty()) {
            throw InvalidTypedAnswerException()
        }
        return whitespaceCanonical
    }

    private fun validateInput(value: String) {
        val codePointCount = value.codePointCount(0, value.length)
        if (
            codePointCount !in 1..MAX_CODE_POINTS ||
            value.toByteArray(StandardCharsets.UTF_8).size > MAX_UTF8_BYTES
        ) {
            throw InvalidTypedAnswerException()
        }
        if (value.codePoints().anyMatch(::isForbiddenCodePoint)) {
            throw InvalidTypedAnswerException()
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

class InvalidTypedAnswerException : IllegalArgumentException("The typed answer is invalid.")
