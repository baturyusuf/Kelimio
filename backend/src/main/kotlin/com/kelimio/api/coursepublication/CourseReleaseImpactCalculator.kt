package com.kelimio.api.coursepublication

import com.kelimio.api.web.ConflictProblem
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.HexFormat
import java.util.UUID

internal object CourseReleaseImpactCalculator {
    fun calculate(state: CourseReleaseImpactState): CourseReleaseImpactResponse {
        val sourceChangeSetId = state.target.sourceChangeSetId
            ?: throw ConflictProblem("The target release has no committed source change set.")
        val operation = operation(state)
        val current = uniqueManifest(state.currentQuestions, "current")
        val target = uniqueManifest(state.targetQuestions, "target")
        if (target.isEmpty()) {
            throw ConflictProblem("The target release contains no questions.")
        }
        val unchanged = target.count { (questionId, revisionId) -> current[questionId] == revisionId }
        val changed = target.count { (questionId, revisionId) ->
            current.containsKey(questionId) && current[questionId] != revisionId
        }
        val added = target.keys.count { it !in current }
        val removed = current.keys.count { it !in target }
        val capabilities = state.requiredClientCapabilities.distinct().sorted()
        val binding = binding(
            state = state,
            operation = operation,
            sourceChangeSetId = sourceChangeSetId,
            current = current,
            target = target,
            capabilities = capabilities,
        )
        return CourseReleaseImpactResponse(
            courseId = state.course.id,
            targetReleaseId = state.target.id,
            expectedActiveReleaseId = state.course.activeReleaseId,
            sourceChangeSetId = sourceChangeSetId,
            operation = operation,
            releaseRevision = state.target.revision,
            targetQuestionCount = target.size,
            unchangedQuestionCount = unchanged,
            changedQuestionCount = changed,
            addedQuestionCount = added,
            removedQuestionCount = removed,
            affectedEnrollmentCount = state.affectedEnrollmentCount,
            requiredClientCapabilities = capabilities,
            impactBindingSha256 = binding,
        )
    }

    private fun operation(state: CourseReleaseImpactState): CourseReleaseOperation {
        val course = state.course
        val target = state.target
        if (course.publicationStatus == "REMOVED") {
            throw ConflictProblem("A removed course cannot activate a release.")
        }
        if (course.activeReleaseId == null) {
            if (course.publicationStatus != "DRAFT" || target.status != "DRAFT" || target.revision != 1) {
                throw ConflictProblem("The initial publication target is invalid.")
            }
            return CourseReleaseOperation.INITIAL_PUBLICATION
        }
        if (target.id == course.activeReleaseId || target.status == "ACTIVE") {
            throw ConflictProblem("The target release is already active.")
        }
        if (course.publicationStatus !in setOf("PUBLISHED", "HIDDEN")) {
            throw ConflictProblem("The course cannot activate another release in its current state.")
        }
        return when (target.status) {
            "DRAFT" -> {
                if (target.revision <= checkNotNull(course.activeReleaseRevision)) {
                    throw ConflictProblem("A new publication must advance the release revision.")
                }
                CourseReleaseOperation.PUBLICATION
            }
            "RETIRED" -> CourseReleaseOperation.ROLLBACK
            else -> throw ConflictProblem("The target release cannot be activated.")
        }
    }

    private fun uniqueManifest(
        questions: List<CourseReleaseQuestionRef>,
        label: String,
    ): Map<UUID, UUID> {
        val manifest = linkedMapOf<UUID, UUID>()
        questions.sortedWith(compareBy({ it.questionId.toString() }, { it.questionRevisionId.toString() }))
            .forEach { question ->
                val previous = manifest.putIfAbsent(question.questionId, question.questionRevisionId)
                if (previous != null && previous != question.questionRevisionId) {
                    throw ConflictProblem("The $label release maps one question to conflicting revisions.")
                }
            }
        return manifest
    }

    private fun binding(
        state: CourseReleaseImpactState,
        operation: CourseReleaseOperation,
        sourceChangeSetId: UUID,
        current: Map<UUID, UUID>,
        target: Map<UUID, UUID>,
        capabilities: List<String>,
    ): String {
        val canonical = buildString {
            append("course-release-impact-v1\n")
            append("course=").append(state.course.id).append('\n')
            append("current=").append(state.course.activeReleaseId ?: "-").append('\n')
            append("target=").append(state.target.id).append('\n')
            append("targetRevision=").append(state.target.revision).append('\n')
            append("operation=").append(operation.name).append('\n')
            append("sourceChangeSet=").append(sourceChangeSetId).append('\n')
            current.toSortedMap(compareBy<UUID> { it.toString() }).forEach { (questionId, revisionId) ->
                append("currentQuestion=").append(questionId).append(':').append(revisionId).append('\n')
            }
            target.toSortedMap(compareBy<UUID> { it.toString() }).forEach { (questionId, revisionId) ->
                append("targetQuestion=").append(questionId).append(':').append(revisionId).append('\n')
            }
            capabilities.forEach { append("capability=").append(it).append('\n') }
        }
        return HexFormat.of().formatHex(
            MessageDigest.getInstance("SHA-256").digest(canonical.toByteArray(StandardCharsets.UTF_8)),
        )
    }
}
