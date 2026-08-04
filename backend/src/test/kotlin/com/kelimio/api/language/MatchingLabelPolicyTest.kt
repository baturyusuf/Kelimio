package com.kelimio.api.language

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class MatchingLabelPolicyTest {
    @Test
    fun `matching label v1 mirrors safe locale pinned typed-answer semantics`() {
        val examples = listOf(
            Triple("  İÇERİM\u00a0  şimdi  ", "tr", "içerim şimdi"),
            Triple("I", "tr", "ı"),
            Triple("Cafe\u0301", "fr", "café"),
            Triple("ΟΣ", "el", TypedAnswerPolicy.canonicalize("ος", "el")),
            Triple("می\u200cروم", "fa", "می\u200cروم"),
            Triple("می\u200dروم", "fa", "می\u200dروم"),
        )

        examples.forEach { (value, language, expected) ->
            assertThat(MatchingLabelPolicy.canonicalize(value, language)).isEqualTo(expected)
            assertThat(MatchingLabelPolicy.canonicalize(value, language))
                .isEqualTo(TypedAnswerPolicy.canonicalize(value, language))
        }
        assertThat(MatchingLabelPolicy.canonicalize("Straße", "de"))
            .isEqualTo(MatchingLabelPolicy.canonicalize("STRASSE", "de"))
        assertThat(MatchingLabelPolicy.canonicalize("ß".repeat(500), "de"))
            .isEqualTo("ss".repeat(500))
    }

    @Test
    fun `matching labels preserve meaningful accents and punctuation`() {
        assertThat(MatchingLabelPolicy.canonicalize("cafe", "fr"))
            .isNotEqualTo(MatchingLabelPolicy.canonicalize("café", "fr"))
        assertThat(MatchingLabelPolicy.canonicalize("dont", "en"))
            .isNotEqualTo(MatchingLabelPolicy.canonicalize("don't", "en"))
        assertThat(MatchingLabelPolicy.canonicalize("I", "en"))
            .isNotEqualTo(MatchingLabelPolicy.canonicalize("I", "tr"))
    }

    @Test
    fun `matching label validation fails closed without echoing content`() {
        val sensitiveSpoof = "private-matching-label\u202e"
        val invalid = listOf(
            "   ",
            "line\nbreak",
            "tab\tlabel",
            "line\u2028separator",
            "paragraph\u2029separator",
            sensitiveSpoof,
            "unsafe\u2066label",
            "private\ue000label",
            "unassigned\u0378label",
            "a".repeat(MatchingLabelPolicy.MAX_CODE_POINTS + 1),
            "\ud800",
        )

        invalid.forEach { value ->
            assertThatThrownBy { MatchingLabelPolicy.canonicalize(value, "tr") }
                .isInstanceOf(InvalidMatchingLabelException::class.java)
                .hasMessage("The matching label is invalid.")
                .hasMessageNotContaining(value)
        }
        assertThatThrownBy { MatchingLabelPolicy.canonicalize("Window", "EN") }
            .isInstanceOf(InvalidMatchingLabelException::class.java)
        assertThatThrownBy {
            MatchingLabelPolicy.canonicalize("Window", "en", "matching-label-v2")
        }.isInstanceOf(InvalidMatchingLabelException::class.java)
    }

    @Test
    fun `matching label canonicalization is idempotent`() {
        val canonical = MatchingLabelPolicy.canonicalize("  Sabah\u2003KAHVALTIDA ", "tr")
        assertThat(MatchingLabelPolicy.canonicalize(canonical, "tr")).isEqualTo(canonical)
    }
}
