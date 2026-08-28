package com.kelimio.api.coursepublication

import com.kelimio.api.web.ConflictProblem
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.util.UUID

class CourseReleaseImpactCalculatorTest {
    @Test
    fun `initial publication binds the exact manifest but not the advisory enrollment count`() {
        val state = state(
            publicationStatus = "DRAFT",
            activeReleaseId = null,
            activeReleaseRevision = null,
            targetStatus = "DRAFT",
            targetRevision = 1,
            currentQuestions = emptyList(),
            targetQuestions = listOf(ref(1, 101), ref(2, 102)),
            capabilities = listOf("question.matching.v1", "question.matching.v1"),
            enrollmentCount = 3,
        )

        val impact = CourseReleaseImpactCalculator.calculate(state)
        val withDifferentAdvisoryCount = CourseReleaseImpactCalculator.calculate(
            state.copy(affectedEnrollmentCount = 19),
        )

        assertThat(impact.operation).isEqualTo(CourseReleaseOperation.INITIAL_PUBLICATION)
        assertThat(impact.expectedActiveReleaseId).isNull()
        assertThat(impact.targetQuestionCount).isEqualTo(2)
        assertThat(impact.addedQuestionCount).isEqualTo(2)
        assertThat(impact.changedQuestionCount).isZero()
        assertThat(impact.requiredClientCapabilities).containsExactly("question.matching.v1")
        assertThat(impact.impactBindingSha256).matches("^[0-9a-f]{64}$")
        assertThat(withDifferentAdvisoryCount.impactBindingSha256).isEqualTo(impact.impactBindingSha256)
    }

    @Test
    fun `publication reports stable question revision changes additions and removals`() {
        val impact = CourseReleaseImpactCalculator.calculate(
            state(
                publicationStatus = "PUBLISHED",
                activeReleaseId = id(900),
                activeReleaseRevision = 1,
                targetStatus = "DRAFT",
                targetRevision = 2,
                currentQuestions = listOf(ref(1, 101), ref(2, 102), ref(3, 103)),
                targetQuestions = listOf(ref(1, 101), ref(2, 202), ref(4, 204)),
            ),
        )

        assertThat(impact.operation).isEqualTo(CourseReleaseOperation.PUBLICATION)
        assertThat(impact.unchangedQuestionCount).isEqualTo(1)
        assertThat(impact.changedQuestionCount).isEqualTo(1)
        assertThat(impact.addedQuestionCount).isEqualTo(1)
        assertThat(impact.removedQuestionCount).isEqualTo(1)
    }

    @Test
    fun `an already active target fails closed before activation`() {
        val activeReleaseId = id(900)
        val state = state(
            publicationStatus = "PUBLISHED",
            activeReleaseId = activeReleaseId,
            activeReleaseRevision = 1,
            targetReleaseId = activeReleaseId,
            targetStatus = "ACTIVE",
            targetRevision = 1,
            currentQuestions = listOf(ref(1, 101)),
            targetQuestions = listOf(ref(1, 101)),
        )

        assertThatThrownBy { CourseReleaseImpactCalculator.calculate(state) }
            .isInstanceOf(ConflictProblem::class.java)
    }

    @Test
    fun `an abandoned target fails closed before impact calculation`() {
        val state = state(
            publicationStatus = "DRAFT",
            activeReleaseId = null,
            activeReleaseRevision = null,
            targetStatus = "ABANDONED",
            targetRevision = 1,
            currentQuestions = emptyList(),
            targetQuestions = listOf(ref(1, 101)),
        )

        assertThatThrownBy { CourseReleaseImpactCalculator.calculate(state) }
            .isInstanceOf(ConflictProblem::class.java)
    }

    private fun state(
        publicationStatus: String,
        activeReleaseId: UUID?,
        activeReleaseRevision: Int?,
        targetStatus: String,
        targetRevision: Int,
        currentQuestions: List<CourseReleaseQuestionRef>,
        targetQuestions: List<CourseReleaseQuestionRef>,
        targetReleaseId: UUID = id(901),
        capabilities: List<String> = emptyList(),
        enrollmentCount: Int = 0,
    ) = CourseReleaseImpactState(
        course = CourseReleaseCourseState(
            id = id(800),
            ownerUserId = id(700),
            publicationStatus = publicationStatus,
            activeReleaseId = activeReleaseId,
            activeReleaseRevision = activeReleaseRevision,
        ),
        target = CourseReleaseTargetState(
            id = targetReleaseId,
            courseId = id(800),
            revision = targetRevision,
            status = targetStatus,
            sourceChangeSetId = id(600),
        ),
        currentQuestions = currentQuestions,
        targetQuestions = targetQuestions,
        requiredClientCapabilities = capabilities,
        affectedEnrollmentCount = enrollmentCount,
    )

    private fun ref(question: Int, revision: Int) = CourseReleaseQuestionRef(id(question), id(revision))

    private fun id(value: Int): UUID = UUID(0, value.toLong())
}
