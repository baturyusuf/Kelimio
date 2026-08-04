package com.kelimio.api.language

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class LanguageTagNormalizerTest {
    private val normalizer = LanguageTagNormalizer()

    @Test
    fun `normalizes every supported subtag category to contract casing`() {
        val cases = mapOf(
            "EN" to "en",
            "pt-br" to "pt-BR",
            "ZH-hANT" to "zh-Hant",
            "sr-latn-rs" to "sr-Latn-RS",
            "es-419" to "es-419",
            "de-1996" to "de-1996",
            "sl-ROZAJ-BISKE" to "sl-rozaj-biske",
        )

        cases.forEach { (input, expected) ->
            assertThat(normalizer.normalize(input)).isEqualTo(expected)
        }
    }

    @Test
    fun `normalized values match the OpenAPI pattern and are idempotent`() {
        val inputs = listOf(
            "tr",
            "PT-br",
            "zh-hant-tw",
            "sr-CYRL-rs-1996",
            "sl-rozaj-biske-1994",
        )

        inputs.forEach { input ->
            val normalized = normalizer.normalize(input)
            assertThat(normalized).matches(LanguageTagNormalizer.CANONICAL_PATTERN)
            assertThat(normalizer.normalize(normalized)).isEqualTo(normalized)
        }
    }

    @Test
    fun `enforces the OpenAPI length boundary after structural validation`() {
        assertThat(normalizer.normalize("abcdefgh-ijkl-mn-abcde-1234-abcdefg"))
            .isEqualTo("abcdefgh-Ijkl-MN-abcde-1234-abcdefg")
        assertThatThrownBy { normalizer.normalize("abcdefgh-ijkl-mn-abcde-1234-abcdefgh") }
            .isInstanceOf(InvalidLanguageTagException::class.java)
    }

    @Test
    fun `rejects extensions private use and structures outside the initial contract`() {
        val invalid = listOf(
            "en-US-u-ca-gregory",
            "en-x-private",
            "x-private",
            "en_US",
            "en-abc",
            "en-a",
            "en--US",
            " en",
            "a",
            "en-abcdefghi",
        )

        invalid.forEach { input ->
            assertThatThrownBy { normalizer.normalize(input) }
                .isInstanceOf(InvalidLanguageTagException::class.java)
        }
    }

    @Test
    fun `nullable normalization does not allow invalid claims through`() {
        assertThat(normalizer.normalizeOrNull(null)).isNull()
        assertThat(normalizer.normalizeOrNull("en-u-ca-gregory")).isNull()
        assertThat(normalizer.normalizeOrNull("AR-arab-eg")).isEqualTo("ar-Arab-EG")
    }
}
