package com.kelimio.api.development

import com.kelimio.api.catalog.LearningQuestionType
import java.util.UUID

data class LocalStarterCourseResult(
    val courseId: UUID,
    val created: Boolean,
    val sourceWorkbookSha256: String,
)

internal data class StarterQuestion(
    val type: LearningQuestionType,
    val prompt: String,
    val correctAnswer: String,
    val options: List<String>,
    val alternativeCorrectAnswer: String? = null,
)

internal object LocalStarterCourseDefinition {
    const val ORIGIN_TYPE = "LOCAL_STARTER"
    const val ORIGIN_KEY = "kurs-excel-plani-v3-type-a-b-c-en-v3"
    const val SOURCE_WORKBOOK_SHA256 = "9fb87f680505e949304257e43e09ab0ce7f71324b4a06bcfae919260ab9f889e"
    const val COURSE_NAME = "Örnek Türkçe Kelime Kursu"
    const val COURSE_DESCRIPTION =
        "Yerel geliştirme için kaynak çalışma kitabındaki Type-A, Type-B ve Type-C satırlarından oluşturulan başlangıç kursu."
    const val TEST_TITLE = "Giriş Seviyesi · Başlangıç Kelimeleri"

    private val words = listOf(
        "Merhaba" to "Hello",
        "Hoşça kal" to "Goodbye",
        "Teşekkür ederim" to "Thank you",
        "Lütfen" to "Please",
        "Evet" to "Yes",
        "Hayır" to "No",
    )

    val questions: List<StarterQuestion> =
        words.take(5).mapIndexed { index, (prompt, answer) ->
            StarterQuestion(
                type = LearningQuestionType.WORD_MULTIPLE_CHOICE,
                prompt = prompt,
                correctAnswer = answer,
                options = List(4) { offset -> words[(index + offset) % words.size].second },
            )
        } +
            StarterQuestion(
                type = LearningQuestionType.MULTIPLE_CHOICE_CLOZE,
                prompt = "Ben her sabah çay ---.",
                correctAnswer = "içerim",
                options = listOf("içerim", "yerim", "koşarım", "yazarım"),
            ) +
            StarterQuestion(
                type = LearningQuestionType.TYPED_CLOZE,
                prompt = "Sabah kahvaltıda çay ---.",
                correctAnswer = "içerim",
                alternativeCorrectAnswer = "içiyorum",
                options = emptyList(),
            )
}
