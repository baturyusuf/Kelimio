package com.kelimio.api.language

import org.springframework.stereotype.Component
import java.util.Locale

@Component
class LanguageTagNormalizer {
    fun normalize(value: String): String {
        if (value.length !in MIN_LENGTH..MAX_LENGTH || value != value.trim()) {
            throw InvalidLanguageTagException(value)
        }
        val subtags = value.split('-')
        if (subtags.isEmpty() || subtags.any(String::isEmpty)) {
            throw InvalidLanguageTagException(value)
        }

        val normalized = mutableListOf<String>()
        val primary = subtags.first()
        if (!PRIMARY.matches(primary)) {
            throw InvalidLanguageTagException(value)
        }
        normalized += primary.lowercase(Locale.ROOT)

        var index = 1
        subtags.getOrNull(index)?.takeIf(SCRIPT::matches)?.let { script ->
            normalized += script.lowercase(Locale.ROOT).replaceFirstChar { it.titlecase(Locale.ROOT) }
            index += 1
        }
        subtags.getOrNull(index)?.takeIf(REGION::matches)?.let { region ->
            normalized += region.uppercase(Locale.ROOT)
            index += 1
        }
        while (index < subtags.size) {
            val variant = subtags[index]
            if (!VARIANT.matches(variant)) {
                throw InvalidLanguageTagException(value)
            }
            normalized += variant.lowercase(Locale.ROOT)
            index += 1
        }

        return normalized.joinToString("-").also { canonical ->
            if (!CANONICAL.matches(canonical)) {
                throw InvalidLanguageTagException(value)
            }
        }
    }

    fun normalizeOrNull(value: String?): String? =
        value?.let {
            try {
                normalize(it)
            } catch (_: InvalidLanguageTagException) {
                null
            }
        }

    companion object {
        const val CANONICAL_PATTERN =
            "^[a-z]{2,8}(?:-[A-Z][a-z]{3})?(?:-(?:[A-Z]{2}|[0-9]{3}))?(?:-(?:[a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$"

        private const val MIN_LENGTH = 2
        private const val MAX_LENGTH = 35
        private val PRIMARY = Regex("^[A-Za-z]{2,8}$")
        private val SCRIPT = Regex("^[A-Za-z]{4}$")
        private val REGION = Regex("^(?:[A-Za-z]{2}|[0-9]{3})$")
        private val VARIANT = Regex("^(?:[A-Za-z0-9]{5,8}|[0-9][A-Za-z0-9]{3})$")
        private val CANONICAL = Regex(CANONICAL_PATTERN)
    }
}

class InvalidLanguageTagException(
    value: String,
) : IllegalArgumentException("Invalid language tag: $value")
