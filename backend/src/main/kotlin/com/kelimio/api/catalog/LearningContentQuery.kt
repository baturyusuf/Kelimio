package com.kelimio.api.catalog

import org.springframework.stereotype.Service
import java.util.UUID

/** Catalog-owned application boundary used by the learning module. */
interface LearningContentQuery {
    fun findActiveTest(testId: UUID): TestContext?

    fun lockActiveEnrollmentSupportLanguage(
        courseId: UUID,
        userId: UUID,
    ): String?

    fun findAttemptQuestions(
        testRevisionId: UUID,
        supportLanguage: String,
    ): List<AttemptQuestionSource>
}

@Service
class CatalogLearningContentQuery(
    private val repository: CatalogRepository,
) : LearningContentQuery {
    override fun findActiveTest(testId: UUID): TestContext? = repository.findActiveTest(testId)

    override fun lockActiveEnrollmentSupportLanguage(
        courseId: UUID,
        userId: UUID,
    ): String? = repository.lockActiveEnrollmentSupportLanguage(courseId, userId)

    override fun findAttemptQuestions(
        testRevisionId: UUID,
        supportLanguage: String,
    ): List<AttemptQuestionSource> = repository.findAttemptQuestions(testRevisionId, supportLanguage)
}
