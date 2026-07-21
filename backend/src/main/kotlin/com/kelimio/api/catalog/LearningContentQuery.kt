package com.kelimio.api.catalog

import org.springframework.stereotype.Service
import java.util.UUID

/** Catalog-owned application boundary used by the learning module. */
interface LearningContentQuery {
    fun findActiveTest(testId: UUID): TestContext?

    fun hasActiveEnrollment(
        courseId: UUID,
        userId: UUID,
    ): Boolean

    fun findAttemptQuestions(testRevisionId: UUID): List<AttemptQuestionSource>
}

@Service
class CatalogLearningContentQuery(
    private val repository: CatalogRepository,
) : LearningContentQuery {
    override fun findActiveTest(testId: UUID): TestContext? = repository.findActiveTest(testId)

    override fun hasActiveEnrollment(
        courseId: UUID,
        userId: UUID,
    ): Boolean = repository.hasActiveEnrollment(courseId, userId)

    override fun findAttemptQuestions(testRevisionId: UUID): List<AttemptQuestionSource> =
        repository.findAttemptQuestions(testRevisionId)
}
