package com.kelimio.api.clientcapability

import com.kelimio.api.web.UnprocessableProblem
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class ClientCapabilityPolicyTest {
    @Test
    fun `missing header means no capabilities and valid duplicates are deduplicated`() {
        assertThat(ClientCapabilityPolicy.parse(null)).isEmpty()
        assertThat(
            ClientCapabilityPolicy.parse("question.matching.v1, question.matching.v1"),
        ).containsExactly("question.matching.v1")
    }

    @Test
    fun `malformed or unbounded capability headers fail closed`() {
        listOf(
            "",
            "question.matching.v1,",
            "Question.matching.v1",
            "question_matching_v1",
            (1..17).joinToString(",") { "feature.value$it" },
            "feature.${"a".repeat(64)}",
        ).forEach { raw ->
            assertThatThrownBy { ClientCapabilityPolicy.parse(raw) }
                .isInstanceOf(UnprocessableProblem::class.java)
        }
    }
}
