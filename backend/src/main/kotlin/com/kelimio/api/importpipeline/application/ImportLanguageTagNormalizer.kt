package com.kelimio.api.importpipeline.application

import java.util.Locale

/** Pure import-boundary BCP-47 subset; deliberately independent of Spring-managed runtime code. */
object ImportLanguageTagNormalizer {
    fun normalize(value: String): String {
        if (value.length !in MIN_LENGTH..MAX_LENGTH || value != value.trim()) {
            throw InvalidImportLanguageTagException(value)
        }
        val subtags = value.split('-')
        if (subtags.isEmpty() || subtags.any(String::isEmpty)) {
            throw InvalidImportLanguageTagException(value)
        }

        val normalized = mutableListOf<String>()
        val primary = subtags.first()
        if (!PRIMARY.matches(primary)) {
            throw InvalidImportLanguageTagException(value)
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
        val variants = mutableSetOf<String>()
        while (index < subtags.size) {
            val variant = subtags[index]
            if (!VARIANT.matches(variant)) {
                throw InvalidImportLanguageTagException(value)
            }
            val normalizedVariant = variant.lowercase(Locale.ROOT)
            if (!variants.add(normalizedVariant)) {
                throw InvalidImportLanguageTagException(value)
            }
            normalized += normalizedVariant
            index += 1
        }

        return normalized.joinToString("-").also { canonical ->
            if (!CANONICAL.matches(canonical)) throw InvalidImportLanguageTagException(value)
        }
    }

    private const val MIN_LENGTH = 2
    private const val MAX_LENGTH = 35
    private val PRIMARY = Regex("^[A-Za-z]{2,8}$")
    private val SCRIPT = Regex("^[A-Za-z]{4}$")
    private val REGION = Regex("^(?:[A-Za-z]{2}|[0-9]{3})$")
    private val VARIANT = Regex("^(?:[A-Za-z0-9]{5,8}|[0-9][A-Za-z0-9]{3})$")
    private val CANONICAL =
        Regex("^[a-z]{2,8}(?:-[A-Z][a-z]{3})?(?:-(?:[A-Z]{2}|[0-9]{3}))?(?:-(?:[a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$")
}

class InvalidImportLanguageTagException(
    value: String,
) : IllegalArgumentException("Invalid import language tag: $value")
