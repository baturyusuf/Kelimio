package com.kelimio.api.catalog

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class LearningQuestionTypeTest {
    @Test
    fun `maps the supported storage codes exhaustively`() {
        assertThat(LearningQuestionType.fromStorageCode("A"))
            .isEqualTo(LearningQuestionType.WORD_MULTIPLE_CHOICE)
        assertThat(LearningQuestionType.fromStorageCode("B"))
            .isEqualTo(LearningQuestionType.MULTIPLE_CHOICE_CLOZE)
        assertThat(LearningQuestionType.WORD_MULTIPLE_CHOICE.apiValue)
            .isEqualTo("WORD_MULTIPLE_CHOICE")
        assertThat(LearningQuestionType.MULTIPLE_CHOICE_CLOZE.apiValue)
            .isEqualTo("MULTIPLE_CHOICE_CLOZE")
    }

    @Test
    fun `fails closed for an unsupported storage code`() {
        assertThatThrownBy { LearningQuestionType.fromStorageCode("C") }
            .isInstanceOf(IllegalStateException::class.java)
            .hasMessage("Unsupported stored learning question type")
    }
}
