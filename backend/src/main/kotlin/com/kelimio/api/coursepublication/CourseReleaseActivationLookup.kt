package com.kelimio.api.coursepublication

import java.time.OffsetDateTime
import java.util.UUID

/**
 * The course-publication-owned application boundary for querying whether a
 * release was already activated. Consumers must not query publication tables.
 */
interface CourseReleaseActivationLookup {
    fun findLatestOwned(
        ownerUserId: UUID,
        courseId: UUID,
        releaseId: UUID,
    ): CourseReleaseActivationSnapshot?
}

data class CourseReleaseActivationSnapshot(
    val releaseId: UUID,
    val operation: CourseReleaseOperation,
    val activatedAt: OffsetDateTime,
    val reprojectionStatus: String,
)
