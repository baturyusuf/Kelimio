package com.kelimio.api.coursepublication

import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.util.UUID

@Repository
class CourseReleaseRepository(
    private val dsl: DSLContext,
) : CourseReleaseActivationLookup {
    fun course(courseId: UUID, lock: Boolean): CourseReleaseCourseState? {
        val lockClause = if (lock) " for update of course_row" else ""
        return dsl.fetchOne(
            """
            select course_row.id, course_row.owner_user_id, course_row.publication_status,
                   course_row.active_release_id, active_release.revision_number as active_release_revision
              from course course_row
              left join course_release active_release on active_release.id = course_row.active_release_id
             where course_row.id = ?$lockClause
            """.trimIndent(),
            courseId,
        )?.let {
            CourseReleaseCourseState(
                id = it.get("id", UUID::class.java)!!,
                ownerUserId = it.get("owner_user_id", UUID::class.java)!!,
                publicationStatus = it.get("publication_status", String::class.java)!!,
                activeReleaseId = it.get("active_release_id", UUID::class.java),
                activeReleaseRevision = it.get("active_release_revision", Int::class.java),
            )
        }
    }

    fun target(courseId: UUID, releaseId: UUID, lock: Boolean): CourseReleaseTargetState? {
        val lockClause = if (lock) " for update of release_row" else ""
        return dsl.fetchOne(
            """
            select release_row.id, release_row.course_id, release_row.revision_number,
                   release_row.status, source.content_change_set_id
              from course_release release_row
              left join course_release_source_change_set source
                on source.course_release_id = release_row.id
             where release_row.id = ? and release_row.course_id = ?$lockClause
            """.trimIndent(),
            releaseId,
            courseId,
        )?.let {
            CourseReleaseTargetState(
                id = it.get("id", UUID::class.java)!!,
                courseId = it.get("course_id", UUID::class.java)!!,
                revision = it.get("revision_number", Int::class.java)!!,
                status = it.get("status", String::class.java)!!,
                sourceChangeSetId = it.get("content_change_set_id", UUID::class.java),
            )
        }
    }

    fun questionManifest(releaseId: UUID): List<CourseReleaseQuestionRef> = dsl.fetch(
        """
        select revision.question_id, revision.id as question_revision_id
          from course_release_test_revision release_test
          join test_revision_question test_question
            on test_question.test_revision_id = release_test.test_revision_id
          join question_revision revision on revision.id = test_question.question_revision_id
         where release_test.course_release_id = ?
         order by revision.question_id, revision.id
        """.trimIndent(),
        releaseId,
    ).map {
        CourseReleaseQuestionRef(
            questionId = it.get("question_id", UUID::class.java)!!,
            questionRevisionId = it.get("question_revision_id", UUID::class.java)!!,
        )
    }

    fun requiredCapabilities(releaseId: UUID): List<String> = dsl.fetch(
        """
        select capability
          from course_release_required_capability
         where course_release_id = ?
         order by capability
        """.trimIndent(),
        releaseId,
    ).map { it.get("capability", String::class.java)!! }

    fun activeEnrollmentCount(courseId: UUID): Int = dsl.fetchOne(
        "select count(*) as count from enrollment where course_id = ? and status = 'ACTIVE'",
        courseId,
    )!!.get("count", Long::class.java)!!.toInt()

    fun prepareReleaseTransition(previousReleaseId: UUID?, targetReleaseId: UUID) {
        previousReleaseId?.let { previous ->
            check(
                dsl.execute(
                    "update course_release set status = 'RETIRED' where id = ? and status = 'ACTIVE'",
                    previous,
                ) == 1,
            ) { "The previous active release changed during activation" }
            dsl.execute(
                """
                update test_revision previous_revision
                   set status = 'RETIRED'
                 where previous_revision.status = 'ACTIVE'
                   and previous_revision.id in (
                        select release_test.test_revision_id
                          from course_release_test_revision release_test
                         where release_test.course_release_id = ?
                   )
                   and not exists (
                        select 1
                          from course_release_test_revision target_test
                         where target_test.course_release_id = ?
                           and target_test.test_revision_id = previous_revision.id
                   )
                """.trimIndent(),
                previous,
                targetReleaseId,
            )
            dsl.execute(
                """
                update question_revision previous_revision
                   set status = 'RETIRED'
                 where previous_revision.status = 'ACTIVE'
                   and previous_revision.id in (
                        select test_question.question_revision_id
                          from course_release_test_revision release_test
                          join test_revision_question test_question
                            on test_question.test_revision_id = release_test.test_revision_id
                         where release_test.course_release_id = ?
                   )
                   and not exists (
                        select 1
                          from course_release_test_revision target_test
                          join test_revision_question target_question
                            on target_question.test_revision_id = target_test.test_revision_id
                         where target_test.course_release_id = ?
                           and target_question.question_revision_id = previous_revision.id
                   )
                """.trimIndent(),
                previous,
                targetReleaseId,
            )
        }
        dsl.execute(
            """
            update question_revision revision
               set status = 'ACTIVE'
             where revision.status in ('DRAFT', 'RETIRED')
               and revision.id in (
                    select test_question.question_revision_id
                      from course_release_test_revision release_test
                      join test_revision_question test_question
                        on test_question.test_revision_id = release_test.test_revision_id
                     where release_test.course_release_id = ?
               )
            """.trimIndent(),
            targetReleaseId,
        )
        dsl.execute(
            """
            update test_revision revision
               set status = 'ACTIVE'
             where revision.status in ('DRAFT', 'RETIRED')
               and revision.id in (
                    select release_test.test_revision_id
                      from course_release_test_revision release_test
                     where release_test.course_release_id = ?
               )
            """.trimIndent(),
            targetReleaseId,
        )
    }

    fun switchActiveRelease(
        course: CourseReleaseCourseState,
        targetReleaseId: UUID,
        now: OffsetDateTime,
    ): String {
        check(
            dsl.execute(
                "update course_release set status = 'ACTIVE' where id = ? and status in ('DRAFT', 'RETIRED')",
                targetReleaseId,
            ) == 1,
        ) { "The target release changed during activation" }
        val publicationStatus = if (course.publicationStatus == "DRAFT") "PUBLISHED" else course.publicationStatus
        check(
            dsl.execute(
                """
                update course
                   set active_release_id = ?, publication_status = ?, updated_at = cast(? as timestamptz)
                 where id = ? and active_release_id is not distinct from ?
                """.trimIndent(),
                targetReleaseId,
                publicationStatus,
                now,
                course.id,
                course.activeReleaseId,
            ) == 1,
        ) { "The course active release changed during activation" }
        return publicationStatus
    }

    fun insertActivation(
        activationId: UUID,
        courseId: UUID,
        targetReleaseId: UUID,
        previousReleaseId: UUID?,
        sourceChangeSetId: UUID,
        actorUserId: UUID,
        operation: CourseReleaseOperation,
        impactBindingSha256: String,
        releaseRevision: Int,
        questionCount: Int,
        requiredCapabilities: List<String>,
        outboxEventId: UUID,
        occurredAt: OffsetDateTime,
        correlationId: String,
    ) {
        check(
            dsl.execute(
                """
                insert into course_release_activation(
                    id, course_id, target_release_id, previous_release_id,
                    source_change_set_id, actor_user_id, operation_kind,
                    expected_active_release_id, impact_binding_sha256,
                    release_revision, question_count, required_client_capabilities,
                    outbox_event_id, occurred_at, correlation_id
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, cast(? as timestamptz), ?)
                """.trimIndent(),
                activationId,
                courseId,
                targetReleaseId,
                previousReleaseId,
                sourceChangeSetId,
                actorUserId,
                operation.name,
                previousReleaseId,
                impactBindingSha256,
                releaseRevision,
                questionCount,
                requiredCapabilities.toTypedArray(),
                outboxEventId,
                occurredAt,
                correlationId,
            ) == 1,
        ) { "Release activation fact was not inserted" }
    }

    fun insertReprojectionJob(
        activationId: UUID,
        courseId: UUID,
        targetReleaseId: UUID,
        outboxEventId: UUID,
        occurredAt: OffsetDateTime,
    ) {
        check(
            dsl.execute(
                """
                insert into course_release_reprojection_job(
                    activation_id, course_id, target_release_id, outbox_event_id,
                    enrollment_cutoff_at, status, cursor_enrolled_at,
                    cursor_enrollment_id, processed_count, attempt_count,
                    last_error_type, created_at, updated_at, completed_at
                ) values (?, ?, ?, ?, cast(? as timestamptz), 'PENDING', null, null, 0, 0,
                          null, cast(? as timestamptz), cast(? as timestamptz), null)
                """.trimIndent(),
                activationId,
                courseId,
                targetReleaseId,
                outboxEventId,
                occurredAt,
                occurredAt,
                occurredAt,
            ) == 1,
        ) { "Release reprojection job was not inserted" }
    }

    fun activation(activationId: UUID, actorUserId: UUID): CourseReleaseActivationRecord? = dsl.fetchOne(
        """
        select activation.id, activation.course_id, activation.target_release_id,
               activation.previous_release_id, activation.source_change_set_id,
               activation.operation_kind, activation.release_revision,
               activation.question_count, activation.required_client_capabilities,
               activation.occurred_at, course.publication_status, job.status as reprojection_status
          from course_release_activation activation
          join course on course.id = activation.course_id
          join course_release_reprojection_job job on job.activation_id = activation.id
         where activation.id = ? and activation.actor_user_id = ?
        """.trimIndent(),
        activationId,
        actorUserId,
    )?.let {
        CourseReleaseActivationRecord(
            activationId = it.get("id", UUID::class.java)!!,
            courseId = it.get("course_id", UUID::class.java)!!,
            releaseId = it.get("target_release_id", UUID::class.java)!!,
            previousReleaseId = it.get("previous_release_id", UUID::class.java),
            sourceChangeSetId = it.get("source_change_set_id", UUID::class.java)!!,
            operation = CourseReleaseOperation.valueOf(it.get("operation_kind", String::class.java)!!),
            releaseRevision = it.get("release_revision", Int::class.java)!!,
            questionCount = it.get("question_count", Int::class.java)!!,
            requiredClientCapabilities = it.get(
                "required_client_capabilities",
                Array<String>::class.java,
            )!!.toList(),
            coursePublicationStatus = it.get("publication_status", String::class.java)!!,
            reprojectionStatus = it.get("reprojection_status", String::class.java)!!,
            activatedAt = it.get("occurred_at", OffsetDateTime::class.java)!!,
        )
    }

    override fun findLatestOwned(
        ownerUserId: UUID,
        courseId: UUID,
        releaseId: UUID,
    ): CourseReleaseActivationSnapshot? = dsl.fetchOne(
        """
        select activation.target_release_id, activation.operation_kind,
               activation.occurred_at, job.status as reprojection_status
          from course_release_activation activation
          join course on course.id = activation.course_id
          join course_release_reprojection_job job on job.activation_id = activation.id
         where activation.course_id = ?
           and activation.target_release_id = ?
           and course.owner_user_id = ?
         order by activation.occurred_at desc, activation.id desc
         limit 1
        """.trimIndent(),
        courseId,
        releaseId,
        ownerUserId,
    )?.let {
        CourseReleaseActivationSnapshot(
            releaseId = it.get("target_release_id", UUID::class.java)!!,
            operation = CourseReleaseOperation.valueOf(it.get("operation_kind", String::class.java)!!),
            activatedAt = it.get("occurred_at", OffsetDateTime::class.java)!!,
            reprojectionStatus = it.get("reprojection_status", String::class.java)!!,
        )
    }
}
