package com.kelimio.api.progress

import com.kelimio.api.catalog.CatalogRepository
import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.web.ForbiddenProblem
import com.kelimio.api.web.NotFoundProblem
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class LearningProgressService(
    private val catalogRepository: CatalogRepository,
    private val projectionRepository: LearningProgressProjectionRepository,
) {
    @Transactional(readOnly = true)
    fun get(user: AppUser, courseId: UUID): LearningProgressSnapshot {
        val course = catalogRepository.findPublishedCourse(courseId, user.id)
            ?: throw NotFoundProblem("Course was not found.")
        if (course.visibility != "PUBLIC" && !course.enrolled) {
            throw ForbiddenProblem("Course progress is not accessible.")
        }
        return projectionRepository.getProgress(user.id, courseId)
    }
}
