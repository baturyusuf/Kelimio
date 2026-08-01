package com.kelimio.api.importpipeline.application

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class ImportLanguageTagNormalizerTest {
    @Test
    fun `normalizes the supported BCP-47 subset without framework state`() {
        val cases = mapOf(
            "EN" to "en",
            "pt-br" to "pt-BR",
            "ZH-hANT" to "zh-Hant",
            "sr-latn-rs" to "sr-Latn-RS",
            "es-419" to "es-419",
            "sl-ROZAJ-BISKE" to "sl-rozaj-biske",
        )

        cases.forEach { (input, expected) ->
            val normalized = ImportLanguageTagNormalizer.normalize(input)
            assertThat(normalized).isEqualTo(expected)
            assertThat(ImportLanguageTagNormalizer.normalize(normalized)).isEqualTo(normalized)
        }
    }

    @Test
    fun `rejects extensions private use whitespace and malformed tags`() {
        listOf(
            "en-US-u-ca-gregory",
            "en-x-private",
            "x-private",
            "en_US",
            "en--US",
            "sl-rozaj-ROZAJ",
            " en",
            "a",
        ).forEach { value ->
            assertThatThrownBy { ImportLanguageTagNormalizer.normalize(value) }
                .isInstanceOf(InvalidImportLanguageTagException::class.java)
        }
    }
}
