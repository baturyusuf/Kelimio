package com.kelimio.api.courseauthoring

import org.springframework.stereotype.Service

@Service
internal class InitialCourseDraftService(
    private val repository: InitialCourseDraftRepository,
) : InitialCourseDraftCreator {
    private val planner = ImportedCourseDraftPlanner()

    override fun create(command: InitialCourseDraftCommand): InitialCourseDraftResult {
        val graph = planner.plan(command)
        repository.insert(command, graph)
        return InitialCourseDraftResult(
            courseId = graph.courseId,
            contentChangeSetId = graph.changeSetId,
            draftReleaseId = graph.releaseId,
            rowCount = graph.rowCount,
            levelCount = graph.levelCount,
            unitCount = graph.unitCount,
            topicCount = graph.topicCount,
            testCount = graph.testCount,
        )
    }
}
