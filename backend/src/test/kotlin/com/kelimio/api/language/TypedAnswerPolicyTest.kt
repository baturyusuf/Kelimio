package com.kelimio.api.language

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class TypedAnswerPolicyTest {
    @Test
    fun `canonicalizes NFC locale case and Unicode whitespace deterministically`() {
        assertThat(TypedAnswerPolicy.canonicalize("  İÇERİM\u00a0  şimdi  ", "tr"))
            .isEqualTo("içerim şimdi")
        assertThat(TypedAnswerPolicy.canonicalize("I", "tr")).isEqualTo("ı")
        assertThat(TypedAnswerPolicy.canonicalize("Straße", "de"))
            .isEqualTo(TypedAnswerPolicy.canonicalize("STRASSE", "de"))
        assertThat(TypedAnswerPolicy.canonicalize("ß".repeat(500), "de"))
            .isEqualTo("ss".repeat(500))
        assertThat(TypedAnswerPolicy.canonicalize("Cafe\u0301", "fr")).isEqualTo("café")
        assertThat(TypedAnswerPolicy.canonicalize("ΟΣ", "el"))
            .isEqualTo(TypedAnswerPolicy.canonicalize("ος", "el"))
        assertThat(TypedAnswerPolicy.canonicalize("می\u200cروم", "fa"))
            .isEqualTo("می\u200cروم")
        assertThat(TypedAnswerPolicy.canonicalize("می\u200dروم", "fa"))
            .isEqualTo("می\u200dروم")
        assertThat(TypedAnswerPolicy.canonicalize("😀".repeat(500), "en"))
            .isEqualTo("😀".repeat(500))
    }

    @Test
    fun `preserves accents punctuation and target locale distinctions`() {
        assertThat(TypedAnswerPolicy.canonicalize("cafe", "fr"))
            .isNotEqualTo(TypedAnswerPolicy.canonicalize("café", "fr"))
        assertThat(TypedAnswerPolicy.canonicalize("dont", "en"))
            .isNotEqualTo(TypedAnswerPolicy.canonicalize("don't", "en"))
        assertThat(TypedAnswerPolicy.canonicalize("I", "en"))
            .isNotEqualTo(TypedAnswerPolicy.canonicalize("I", "tr"))
    }

    @Test
    fun `rejects empty oversized malformed and spoofing input without echoing it`() {
        val invalid = listOf(
            "   ",
            "line\nbreak",
            "tab\tanswer",
            "line\u2028separator",
            "paragraph\u2029separator",
            "unsafe\u202eanswer",
            "unsafe\u2066answer",
            "private\ue000answer",
            "unassigned\u0378answer",
            "a".repeat(TypedAnswerPolicy.MAX_CODE_POINTS + 1),
            "\ud800",
        )
        invalid.forEach { value ->
            assertThatThrownBy { TypedAnswerPolicy.canonicalize(value, "tr") }
                .isInstanceOf(InvalidTypedAnswerException::class.java)
                .hasMessage("The typed answer is invalid.")
        }
        assertThatThrownBy { TypedAnswerPolicy.canonicalize("answer", "EN") }
            .isInstanceOf(InvalidTypedAnswerException::class.java)
        assertThatThrownBy { TypedAnswerPolicy.canonicalize("answer", "en", "typed-answer-v2") }
            .isInstanceOf(InvalidTypedAnswerException::class.java)
    }

    @Test
    fun `canonicalization is idempotent`() {
        val canonical = TypedAnswerPolicy.canonicalize("  Sabah\u2003KAHVALTIDA ", "tr")
        assertThat(TypedAnswerPolicy.canonicalize(canonical, "tr")).isEqualTo(canonical)
    }
}
