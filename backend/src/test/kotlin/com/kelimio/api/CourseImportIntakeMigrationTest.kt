package com.kelimio.api

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.flywaydb.core.Flyway
import org.flywaydb.core.api.MigrationVersion
import org.junit.jupiter.api.Test
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.utility.DockerImageName
import java.sql.Connection
import java.sql.DriverManager
import java.sql.SQLException
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@Testcontainers(disabledWithoutDocker = true)
class CourseImportIntakeMigrationTest {
    @Test
    fun `populated V8 upgrades without changing existing facts and enforces V9 lease recovery`() {
        val schema = newSchema(MigrationVersion.fromVersion("8"))
        val userId = UUID.randomUUID()
        val courseId = UUID.randomUUID()
        val releaseId = UUID.randomUUID()
        val testId = UUID.randomUUID()
        val testRevisionId = UUID.randomUUID()
        val questionId = UUID.randomUUID()
        val questionRevisionId = UUID.randomUUID()
        val optionIds = (1..4).map { UUID.randomUUID() }
        val enrollmentId = UUID.randomUUID()
        val attemptId = UUID.randomUUID()
        val submissionId = UUID.randomUUID()
        val scoreEventId = UUID.randomUUID()
        val energyEventId = UUID.randomUUID()
        val outboxEventId = UUID.randomUUID()

        connection(schema).use { connection ->
            connection.autoCommit = false
            insertUser(connection, userId)
            execute(
                connection,
                """
                insert into course(
                    id, owner_user_id, name, target_language, default_support_language,
                    visibility, publication_status, access_type, created_at, updated_at, active_release_id
                ) values (
                    '$courseId', '$userId', 'Retained course', 'tr', 'en',
                    'PRIVATE', 'DRAFT', 'FREE', '$T0'::timestamptz, '$T0'::timestamptz, '$releaseId'
                )
                """,
            )
            execute(connection, "insert into course_support_language(course_id,language_code) values ('$courseId','en')")
            execute(connection, "insert into course_test(id,course_id,created_at) values ('$testId','$courseId','$T0'::timestamptz)")
            execute(
                connection,
                "insert into test_revision(id,test_id,course_id,revision_number,title,status,pass_threshold,created_at) " +
                    "values ('$testRevisionId','$testId','$courseId',1,'Retained test','DRAFT',0.5,'$T0'::timestamptz)",
            )
            execute(connection, "insert into question(id,course_id,created_at) values ('$questionId','$courseId','$T0'::timestamptz)")
            execute(
                connection,
                "insert into question_revision(" +
                    "id,question_id,course_id,revision_number,question_type,prompt,correct_answer,status,created_at" +
                    ") values ('$questionRevisionId','$questionId','$courseId',1,'A','Prompt','Correct','DRAFT','$T0'::timestamptz)",
            )
            (1..4).forEach { position ->
                execute(
                    connection,
                    "insert into question_revision_option(id,question_revision_id,option_text,is_correct,position) " +
                        "values ('${optionIds[position - 1]}','$questionRevisionId','Option $position',${position == 1},$position)",
                )
            }
            execute(connection, "update question_revision set status='ACTIVE' where id='$questionRevisionId'")
            execute(
                connection,
                "insert into test_revision_question(test_revision_id,question_revision_id,question_id,course_id,position) " +
                    "values ('$testRevisionId','$questionRevisionId','$questionId','$courseId',1)",
            )
            execute(connection, "update test_revision set status='ACTIVE' where id='$testRevisionId'")
            execute(
                connection,
                "insert into course_release(id,course_id,revision_number,status,created_at) " +
                    "values ('$releaseId','$courseId',1,'DRAFT','$T0'::timestamptz)",
            )
            execute(
                connection,
                "insert into course_release_test_revision(" +
                    "course_release_id,test_revision_id,test_id,course_id,position" +
                    ") values ('$releaseId','$testRevisionId','$testId','$courseId',1)",
            )
            execute(connection, "update course_release set status='ACTIVE' where id='$releaseId'")
            execute(
                connection,
                "insert into enrollment(id,course_id,user_id,support_language,status,enrolled_at) " +
                    "values ('$enrollmentId','$courseId','$userId','en','ACTIVE','$T0'::timestamptz)",
            )
            execute(
                connection,
                "insert into test_attempt(" +
                    "id,user_id,course_id,course_release_id,course_access_type,test_revision_id,status," +
                    "shuffle_seed,total_questions,answered_count,correct_count,started_at,finished_at,version,support_language" +
                    ") values ('$attemptId','$userId','$courseId','$releaseId','FREE','$testRevisionId'," +
                    "'IN_PROGRESS',42,1,0,0,'$T0'::timestamptz,null,0,'en')",
            )
            execute(
                connection,
                "insert into attempt_question_manifest(" +
                    "attempt_id,test_revision_id,course_id,question_revision_id,position" +
                    ") values ('$attemptId','$testRevisionId','$courseId','$questionRevisionId',1)",
            )
            execute(
                connection,
                "insert into answer_submission(" +
                    "submission_id,attempt_id,user_id,question_revision_id,selected_option_id,is_correct," +
                    "active_score_delta,lifetime_score_delta,active_question_score,lifetime_score," +
                    "energy_balance_after,energy_unlimited,energy_next_regeneration_at,attempt_status_after,submitted_at" +
                    ") values ('$submissionId','$attemptId','$userId','$questionRevisionId','${optionIds.first()}',true," +
                    "60,60,60,60,5,false,null,'IN_PROGRESS','$T1'::timestamptz)",
            )
            execute(
                connection,
                "update test_attempt set answered_count=1,correct_count=1,version=1 where id='$attemptId'",
            )
            execute(
                connection,
                "insert into score_event(" +
                    "id,user_id,attempt_id,submission_id,question_revision_id,active_delta,lifetime_delta,occurred_at" +
                    ") values ('$scoreEventId','$userId','$attemptId','$submissionId','$questionRevisionId',60,60," +
                    "'$T1'::timestamptz)",
            )
            execute(
                connection,
                "insert into attempt_event(id,attempt_id,submission_id,event_type,payload,occurred_at) " +
                    "values ('${UUID.randomUUID()}','$attemptId',null,'STARTED','{}'::jsonb,'$T0'::timestamptz)," +
                    "('${UUID.randomUUID()}','$attemptId','$submissionId','ANSWER_RECORDED','{}'::jsonb,'$T1'::timestamptz)",
            )
            execute(
                connection,
                "update test_attempt set status='COMPLETED_PASS',finished_at='$T1'::timestamptz,version=2 where id='$attemptId'",
            )
            execute(
                connection,
                """
                insert into energy_event(
                    id, user_id, attempt_id, submission_id, event_type, delta,
                    balance_before, balance_after, occurred_at
                ) values (
                    '$energyEventId', '$userId', null, null, 'ACCOUNT_INITIALIZED', 5, 0, 5,
                    '$T0'::timestamptz
                )
                """,
            )
            execute(
                connection,
                """
                insert into outbox_event(
                    id, aggregate_type, aggregate_id, event_type, schema_version,
                    payload, correlation_id, occurred_at
                ) values (
                    '$outboxEventId', 'retained-test', '$courseId', 'retained.v1', 1,
                    '{"retained":true}'::jsonb, 'retained-correlation', '$T0'::timestamptz
                )
                """,
            )
            execute(
                connection,
                "insert into outbox_delivery(event_id, attempt_count, published_at, last_error) " +
                    "values ('$outboxEventId', 2, null, 'retained-error')",
            )
            execute(
                connection,
                "insert into learner_course_progress_projection(" +
                    "user_id,course_id,answered_questions,correct_answers,completed_attempts,passed_attempts," +
                    "active_score,lifetime_score,projection_version,last_event_id,updated_at" +
                    ") values ('$userId','$courseId',1,1,1,1,60,60,1,'$outboxEventId','$T1'::timestamptz)",
            )
            connection.commit()
        }

        val before = connection(schema).use { connection ->
            retainedSnapshot(connection, userId, courseId, energyEventId, outboxEventId, attemptId, scoreEventId)
        }
        migrate(schema)
        val after = connection(schema).use { connection ->
            retainedSnapshot(connection, userId, courseId, energyEventId, outboxEventId, attemptId, scoreEventId)
        }

        assertThat(after).isEqualTo(before)
        connection(schema).use { connection ->
            assertThat(queryString(connection, "select next_attempt_at::text from outbox_delivery where event_id = '$outboxEventId'"))
                .isNull()
            assertThat(
                queryInt(
                    connection,
                    "select count(*) from pg_constraint where connamespace = '$schema'::regnamespace " +
                        "and conname in ('ck_course_import_completed_evidence','ck_course_import_scan_identity')",
                ),
            ).isEqualTo(2)
        }
        assertProcessingLeaseRecoveryRules(schema)
    }

    @Test
    fun `fresh V9 rejects missing audit prerequisites stale provenance and fact mutation`() {
        val schema = newSchema()
        val nullEvidence = createUploading(schema)
        assertSqlFailure {
            transaction(schema) { connection ->
                execute(
                    connection,
                    "insert into course_import_completed_part(" +
                        "import_id,part_number,etag,sha256_base64,evidence_source,completed_at" +
                        ") values ('${nullEvidence.importId}',1,null,'$PART_SHA','S3_VERIFIED','$T1'::timestamptz)",
                )
            }
        }
        val missingOutbox = createUploading(schema)
        assertSqlFailure {
            transaction(schema) { connection -> queue(connection, missingOutbox, includeOutbox = false) }
        }

        transaction(schema) { connection -> queue(connection, missingOutbox, includeOutbox = true) }
        assertSqlFailure {
            transaction(schema) { connection -> claim(connection, missingOutbox, T2.plusMinutes(8)) }
        }
        transaction(schema) { connection -> claim(connection, missingOutbox) }

        assertSqlFailure {
            transaction(schema) { connection -> finishFailed(connection, missingOutbox, attemptOutcome = null) }
        }
        assertSqlFailure {
            transaction(schema) { connection -> finishFailed(connection, missingOutbox, attemptOutcome = "PREVIEW_READY") }
        }

        val quarantineArtifactId = transactionResult(schema) { connection ->
            insertQuarantineArtifact(connection, missingOutbox)
        }
        assertSqlFailure {
            transaction(schema) { connection ->
                insertScan(connection, missingOutbox, quarantineArtifactId, sourceSha256 = OTHER_SHA)
            }
        }
        assertSqlFailure {
            transaction(schema) { connection ->
                execute(
                    connection,
                    scanInsertSql(missingOutbox, quarantineArtifactId, SHA, "CLEAN", "unexpected-code", "1.4.5", "123"),
                )
            }
        }
        assertSqlFailure {
            transaction(schema) { connection ->
                execute(
                    connection,
                    scanInsertSql(missingOutbox, quarantineArtifactId, SHA, "CLEAN", null, null, "123"),
                )
            }
        }

        transaction(schema) { connection -> finishFailed(connection, missingOutbox, attemptOutcome = "EXHAUSTED") }
        assertSqlFailure {
            transaction(schema) { connection ->
                execute(
                    connection,
                    "update course_import_event set correlation_id = 'tampered' where import_id = '${missingOutbox.importId}'",
                )
            }
        }

        assertSqlFailure {
            transaction(schema) { connection ->
                val userId = insertUser(connection)
                execute(
                    connection,
                    initialImportSql(
                        Fixture(UUID.randomUUID(), userId, UUID.randomUUID(), UUID.randomUUID()),
                        status = "QUEUED",
                    ),
                )
            }
        }
    }

    @Test
    fun `preview children are contiguous sealed by terminal transition and approval is provenance bound`() {
        val schema = newSchema()
        val fixture = createUploading(schema)
        transaction(schema) { connection -> queue(connection, fixture, includeOutbox = true) }
        transaction(schema) { connection -> claim(connection, fixture) }
        val facts = transactionResult(schema) { connection -> insertPreviewFacts(connection, fixture) }

        assertSqlFailure {
            transaction(schema) { connection ->
                insertInvalidPreviewParent(connection, fixture, facts)
                execute(
                    connection,
                    "insert into course_import_preview_issue(" +
                        "import_id,ordinal,severity,issue_code,source_sheet_ordinal,source_sheet_name," +
                        "source_row_number,source_column_number,source_reference,message" +
                        ") values ('${fixture.importId}',1,'ERROR','INVALID_SOURCE',1,null,null,null,null,'invalid')",
                )
            }
        }

        assertSqlFailure {
            transaction(schema) { connection -> finishPreview(connection, fixture, facts, rowOrdinal = 2) }
        }

        val firstConnection = connection(schema)
        firstConnection.autoCommit = false
        finishPreview(firstConnection, fixture, facts, rowOrdinal = 1)
        val secondStarted = CountDownLatch(1)
        val executor = Executors.newSingleThreadExecutor()
        val racedInsert = executor.submit<Throwable?> {
            connection(schema).use { second ->
                second.autoCommit = false
                execute(second, "set local lock_timeout = '5s'")
                secondStarted.countDown()
                try {
                    insertPreviewRow(second, fixture.importId, 2)
                    second.commit()
                    null
                } catch (failure: Throwable) {
                    second.rollback()
                    failure
                }
            }
        }
        assertThat(secondStarted.await(5, TimeUnit.SECONDS)).isTrue()
        firstConnection.commit()
        firstConnection.close()
        val raceFailure = racedInsert.get(10, TimeUnit.SECONDS)
        executor.shutdownNow()
        assertThat(raceFailure).isInstanceOf(SQLException::class.java)

        assertSqlFailure {
            transaction(schema) { connection -> insertApproval(connection, fixture, facts, approvalBinding = OTHER_SHA) }
        }
        transaction(schema) { connection ->
            insertApproval(connection, fixture, facts, approvalBinding = BINDING_SHA)
            execute(
                connection,
                "update course_import set status='APPROVED', state_version=4, updated_at='$T4'::timestamptz " +
                    "where id='${fixture.importId}'",
            )
            insertEvent(connection, fixture, 4, "import-approved", "PREVIEW_READY", "APPROVED", fixture.ownerId, null, T4)
        }
        assertThat(
            connection(schema).use { queryString(it, "select status from course_import where id='${fixture.importId}'") },
        ).isEqualTo("APPROVED")
    }

    @Test
    fun `fresh V9 enforces the exact processing lease recovery matrix`() {
        val schema = newSchema()
        assertProcessingLeaseRecoveryRules(schema)
    }

    private fun assertProcessingLeaseRecoveryRules(schema: String) {
        val now = OffsetDateTime.now(ZoneOffset.UTC).withNano(0)

        val active = prepareProcessingAttempt(schema, attemptNumber = 1, base = now.minusMinutes(3))
        assertAttemptTransitionRejected(
            schema,
            active,
            target = "QUEUED",
            outcome = "RETRYABLE_FAILURE",
            finishedAt = active.claimedAt.plusMinutes(1),
        )
        assertAttemptTransitionRejected(
            schema,
            active,
            target = "QUEUED",
            outcome = "RETRYABLE_FAILURE",
            finishedAt = active.claimedAt.plusMinutes(8),
            stableCode = "scanner-unavailable",
        )
        transaction(schema) { connection ->
            finishAttemptTransition(
                connection,
                active.fixture,
                active.processingStateVersion,
                active.attemptNumber,
                active.leaseToken,
                "QUEUED",
                "RETRYABLE_FAILURE",
                active.claimedAt.plusMinutes(1),
                stableCode = "scanner-unavailable",
            )
        }

        val expiredRetry = prepareProcessingAttempt(schema, attemptNumber = 1, base = now.minusHours(2))
        assertAttemptTransitionRejected(
            schema,
            expiredRetry,
            target = "QUEUED",
            outcome = "RETRYABLE_FAILURE",
            finishedAt = expiredRetry.claimedAt.plusMinutes(8),
            stableCode = "scanner-unavailable",
        )
        assertAttemptTransitionRejected(
            schema,
            expiredRetry,
            target = "PROCESSING_FAILED",
            outcome = "EXHAUSTED",
            finishedAt = expiredRetry.claimedAt.plusMinutes(8),
        )
        assertAttemptTransitionRejected(
            schema,
            expiredRetry,
            target = "QUEUED",
            outcome = "EXHAUSTED",
            finishedAt = expiredRetry.claimedAt.plusMinutes(8),
        )
        transaction(schema) { connection ->
            finishAttemptTransition(
                connection,
                expiredRetry.fixture,
                expiredRetry.processingStateVersion,
                expiredRetry.attemptNumber,
                expiredRetry.leaseToken,
                "QUEUED",
                "RETRYABLE_FAILURE",
                expiredRetry.claimedAt.plusMinutes(8),
            )
        }

        val exhausted = prepareProcessingAttempt(schema, attemptNumber = 5, base = now.minusHours(2))
        assertAttemptTransitionRejected(
            schema,
            exhausted,
            target = "QUEUED",
            outcome = "RETRYABLE_FAILURE",
            finishedAt = exhausted.claimedAt.plusMinutes(8),
        )
        assertAttemptTransitionRejected(
            schema,
            exhausted,
            target = "PROCESSING_FAILED",
            outcome = "RETRYABLE_FAILURE",
            finishedAt = exhausted.claimedAt.plusMinutes(8),
        )
        transaction(schema) { connection ->
            finishAttemptTransition(
                connection,
                exhausted.fixture,
                exhausted.processingStateVersion,
                exhausted.attemptNumber,
                exhausted.leaseToken,
                "PROCESSING_FAILED",
                "EXHAUSTED",
                exhausted.claimedAt.plusMinutes(8),
            )
        }

        assertThat(importState(schema, active.fixture)).isEqualTo("QUEUED" to 1)
        assertThat(importState(schema, expiredRetry.fixture)).isEqualTo("QUEUED" to 1)
        assertThat(importState(schema, exhausted.fixture)).isEqualTo("PROCESSING_FAILED" to 5)
    }

    private fun prepareProcessingAttempt(
        schema: String,
        attemptNumber: Int,
        base: OffsetDateTime,
    ): ClaimedAttempt {
        val fixture = createUploading(schema, base)
        transaction(schema) { connection ->
            queue(connection, fixture, includeOutbox = true, queuedAt = base.plusMinutes(1))
        }
        return transactionResult(schema) { connection ->
            var queuedStateVersion = 1
            (1 until attemptNumber).forEach { attempt ->
                val claimedAt = base.plusMinutes(2L + (attempt - 1L) * 9L)
                val leaseToken = UUID.randomUUID()
                claimAttempt(connection, fixture, queuedStateVersion, attempt, leaseToken, claimedAt)
                val processingStateVersion = queuedStateVersion + 1
                finishAttemptTransition(
                    connection,
                    fixture,
                    processingStateVersion,
                    attempt,
                    leaseToken,
                    "QUEUED",
                    "RETRYABLE_FAILURE",
                    claimedAt.plusMinutes(8),
                )
                queuedStateVersion = processingStateVersion + 1
            }
            val claimedAt = base.plusMinutes(2L + (attemptNumber - 1L) * 9L)
            val leaseToken = UUID.randomUUID()
            claimAttempt(connection, fixture, queuedStateVersion, attemptNumber, leaseToken, claimedAt)
            ClaimedAttempt(fixture, queuedStateVersion + 1, attemptNumber, leaseToken, claimedAt)
        }
    }

    private fun assertAttemptTransitionRejected(
        schema: String,
        attempt: ClaimedAttempt,
        target: String,
        outcome: String,
        finishedAt: OffsetDateTime,
        stableCode: String? = "processing-lease-expired",
    ) {
        assertSqlFailure {
            transaction(schema) { connection ->
                finishAttemptTransition(
                    connection,
                    attempt.fixture,
                    attempt.processingStateVersion,
                    attempt.attemptNumber,
                    attempt.leaseToken,
                    target,
                    outcome,
                    finishedAt,
                    stableCode,
                )
            }
        }
    }

    private fun importState(schema: String, fixture: Fixture): Pair<String, Int> =
        connection(schema).use { connection ->
            queryString(connection, "select status from course_import where id='${fixture.importId}'")!! to
                queryInt(connection, "select processing_attempts from course_import where id='${fixture.importId}'")
        }

    private fun createUploading(schema: String, createdAt: OffsetDateTime = T0): Fixture {
        val fixture = Fixture(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID())
        transaction(schema) { connection ->
            insertUser(connection, fixture.ownerId)
            execute(connection, initialImportSql(fixture, createdAt = createdAt))
            execute(
                connection,
                "insert into course_import_part(import_id, part_number, size_bytes, sha256_base64) " +
                    "values ('${fixture.importId}', 1, 1, '$PART_SHA')",
            )
            insertEvent(connection, fixture, 0, "import-created", null, "UPLOADING", fixture.ownerId, null, createdAt)
        }
        return fixture
    }

    private fun queue(
        connection: Connection,
        fixture: Fixture,
        includeOutbox: Boolean,
        queuedAt: OffsetDateTime = T1,
    ) {
        execute(
            connection,
            "insert into course_import_completed_part(" +
                "import_id,part_number,etag,sha256_base64,evidence_source,completed_at" +
                ") values ('${fixture.importId}',1,'part-etag','$PART_SHA','S3_VERIFIED','$queuedAt'::timestamptz)",
        )
        execute(
            connection,
            "update course_import set status='QUEUED',state_version=1,accepted_version_id='${fixture.versionId}'," +
                "accepted_etag='accepted-etag',accepted_size_bytes=1,accepted_checksum_sha256='$COMPOSITE_SHA'," +
                "updated_at='$queuedAt'::timestamptz where id='${fixture.importId}'",
        )
        insertEvent(connection, fixture, 1, "upload-completed", "UPLOADING", "QUEUED", fixture.ownerId, null, queuedAt)
        if (includeOutbox) {
            execute(
                connection,
                "insert into outbox_event(id,aggregate_type,aggregate_id,event_type,schema_version,payload,correlation_id,occurred_at) " +
                    "values ('${fixture.outboxId}','course-import','${fixture.importId}','import.processing-requested.v1',1," +
                    "jsonb_build_object('eventId','${fixture.outboxId}'::uuid,'importId','${fixture.importId}'::uuid)," +
                    "'${fixture.correlation}','$queuedAt'::timestamptz)",
            )
            execute(connection, "insert into outbox_delivery(event_id,attempt_count) values ('${fixture.outboxId}',0)")
        }
    }

    private fun claim(
        connection: Connection,
        fixture: Fixture,
        leaseExpiry: OffsetDateTime = LEASE_EXPIRY,
        claimedAt: OffsetDateTime = T2,
    ) {
        execute(
            connection,
            "update course_import set status='PROCESSING',state_version=2,processing_attempts=1," +
                "processing_lease_token='${fixture.leaseToken}',processing_lease_expires_at='$leaseExpiry'::timestamptz," +
                "updated_at='$claimedAt'::timestamptz where id='${fixture.importId}'",
        )
        insertEvent(connection, fixture, 2, "processing-started", "QUEUED", "PROCESSING", null, null, claimedAt)
    }

    private fun claimAttempt(
        connection: Connection,
        fixture: Fixture,
        queuedStateVersion: Int,
        attemptNumber: Int,
        leaseToken: UUID,
        claimedAt: OffsetDateTime,
    ) {
        val processingStateVersion = queuedStateVersion + 1
        execute(
            connection,
            "update course_import set status='PROCESSING',state_version=$processingStateVersion," +
                "processing_attempts=$attemptNumber,processing_lease_token='$leaseToken'," +
                "processing_lease_expires_at='${claimedAt.plusMinutes(7)}'::timestamptz,failure_code=null," +
                "updated_at='$claimedAt'::timestamptz where id='${fixture.importId}'",
        )
        insertEvent(
            connection,
            fixture,
            processingStateVersion,
            "processing-started",
            "QUEUED",
            "PROCESSING",
            null,
            null,
            claimedAt,
        )
    }

    private fun finishAttemptTransition(
        connection: Connection,
        fixture: Fixture,
        processingStateVersion: Int,
        attemptNumber: Int,
        leaseToken: UUID,
        target: String,
        outcome: String,
        finishedAt: OffsetDateTime,
        stableCode: String? = "processing-lease-expired",
    ) {
        execute(
            connection,
            "insert into course_import_processing_attempt(" +
                "id,import_id,attempt_number,lease_token,outcome,stable_code,started_at,finished_at" +
                ") select '${UUID.randomUUID()}','${fixture.importId}',$attemptNumber,'$leaseToken','$outcome'," +
                "${stableCode.sqlLiteral()},updated_at,'$finishedAt'::timestamptz from course_import " +
                "where id='${fixture.importId}'",
        )
        val targetStateVersion = processingStateVersion + 1
        execute(
            connection,
            "update course_import set status='$target',state_version=$targetStateVersion," +
                "processing_lease_token=null,processing_lease_expires_at=null,failure_code=${stableCode.sqlLiteral()}," +
                "updated_at='$finishedAt'::timestamptz where id='${fixture.importId}'",
        )
        val eventType = when (target) {
            "QUEUED" -> "processing-retry-scheduled"
            "PREVIEW_READY" -> "preview-ready"
            "PROCESSING_FAILED" -> "processing-failed"
            else -> error("Unsupported test transition")
        }
        insertEvent(
            connection,
            fixture,
            targetStateVersion,
            eventType,
            "PROCESSING",
            target,
            null,
            stableCode,
            finishedAt,
        )
    }

    private fun finishFailed(
        connection: Connection,
        fixture: Fixture,
        attemptOutcome: String?,
        stableCode: String = "processing-failed",
        startedAt: OffsetDateTime = T2,
        finishedAt: OffsetDateTime = T3,
    ) {
        if (attemptOutcome != null) {
            execute(
                connection,
                "insert into course_import_processing_attempt(" +
                    "id,import_id,attempt_number,lease_token,outcome,stable_code,started_at,finished_at" +
                    ") values ('${UUID.randomUUID()}','${fixture.importId}',1,'${fixture.leaseToken}'," +
                    "'$attemptOutcome','$stableCode','$startedAt'::timestamptz,'$finishedAt'::timestamptz)",
            )
        }
        execute(
            connection,
            "update course_import set status='PROCESSING_FAILED',state_version=3,processing_lease_token=null," +
                "processing_lease_expires_at=null,failure_code='$stableCode',updated_at='$finishedAt'::timestamptz " +
                "where id='${fixture.importId}'",
        )
        insertEvent(
            connection,
            fixture,
            3,
            stableCode,
            "PROCESSING",
            "PROCESSING_FAILED",
            null,
            "processing-failed",
            finishedAt,
        )
    }

    private fun insertPreviewFacts(connection: Connection, fixture: Fixture): PreviewFacts {
        val quarantineId = insertQuarantineArtifact(connection, fixture)
        val archiveId = UUID.randomUUID()
        val reportId = UUID.randomUUID()
        val scanId = UUID.randomUUID()
        execute(
            connection,
            "insert into course_import_artifact(" +
                "id,import_id,artifact_kind,bucket_name,object_key,object_version_id,etag,sha256,size_bytes,media_type,created_at" +
                ") values ('$archiveId','${fixture.importId}','ARCHIVE_SOURCE','archive'," +
                "'archive/${fixture.ownerId}/${fixture.importId}/source/$SHA.xlsx','archive-version','archive-etag'," +
                "'$SHA',1,'$XLSX_MEDIA_TYPE','$ARTIFACT_TIME'::timestamptz)",
        )
        execute(
            connection,
            "insert into course_import_artifact(" +
                "id,import_id,artifact_kind,bucket_name,object_key,object_version_id,etag,sha256,size_bytes,media_type,created_at" +
                ") values ('$reportId','${fixture.importId}','VALIDATION_REPORT','archive'," +
                "'archive/${fixture.ownerId}/${fixture.importId}/reports/$REPORT_SHA.json','report-version','report-etag'," +
                "'$REPORT_SHA',1,'application/json','$ARTIFACT_TIME'::timestamptz)",
        )
        insertScan(connection, fixture, quarantineId, id = scanId)
        return PreviewFacts(quarantineId, archiveId, reportId, scanId)
    }

    private fun insertQuarantineArtifact(connection: Connection, fixture: Fixture): UUID {
        val id = UUID.randomUUID()
        execute(
            connection,
            "insert into course_import_artifact(" +
                "id,import_id,artifact_kind,bucket_name,object_key,object_version_id,etag,sha256,size_bytes,media_type,created_at" +
                ") values ('$id','${fixture.importId}','QUARANTINE_SOURCE','quarantine','${fixture.objectKey}'," +
                "'${fixture.versionId}','accepted-etag','$SHA',1,'$XLSX_MEDIA_TYPE','$ARTIFACT_TIME'::timestamptz)",
        )
        return id
    }

    private fun insertScan(
        connection: Connection,
        fixture: Fixture,
        artifactId: UUID,
        sourceSha256: String = SHA,
        id: UUID = UUID.randomUUID(),
    ) {
        execute(connection, scanInsertSql(fixture, artifactId, sourceSha256, "CLEAN", null, "1.4.5", "123", id))
    }

    private fun finishPreview(connection: Connection, fixture: Fixture, facts: PreviewFacts, rowOrdinal: Int) {
        execute(
            connection,
            "insert into course_import_preview(" +
                "import_id,quarantine_artifact_id,archive_source_artifact_id,report_artifact_id,clean_scan_id," +
                "rules_version,parser_version,is_valid,row_count,level_count,unit_count,topic_count,test_count," +
                "warning_count,error_count,validation_report_sha256,allocation_sha256,preview_sha256," +
                "approval_binding_sha256,created_at" +
                ") values ('${fixture.importId}','${facts.quarantineId}','${facts.archiveId}','${facts.reportId}'," +
                "'${facts.scanId}','xlsx-v1','test-revision',true,1,1,1,1,1,0,0,'$REPORT_SHA'," +
                "'$ALLOCATION_SHA','$PREVIEW_SHA','$BINDING_SHA','$T3'::timestamptz)",
        )
        insertPreviewRow(connection, fixture.importId, rowOrdinal)
        execute(
            connection,
            "insert into course_import_processing_attempt(" +
                "id,import_id,attempt_number,lease_token,outcome,stable_code,started_at,finished_at" +
                ") values ('${UUID.randomUUID()}','${fixture.importId}',1,'${fixture.leaseToken}'," +
                "'PREVIEW_READY',null,'$T2'::timestamptz,'$T3'::timestamptz)",
        )
        execute(
            connection,
            "update course_import set status='PREVIEW_READY',state_version=3,processing_lease_token=null," +
                "processing_lease_expires_at=null,failure_code=null,updated_at='$T3'::timestamptz " +
                "where id='${fixture.importId}'",
        )
        insertEvent(connection, fixture, 3, "preview-ready", "PROCESSING", "PREVIEW_READY", null, null, T3)
    }

    private fun insertInvalidPreviewParent(connection: Connection, fixture: Fixture, facts: PreviewFacts) {
        execute(
            connection,
            "insert into course_import_preview(" +
                "import_id,quarantine_artifact_id,archive_source_artifact_id,report_artifact_id,clean_scan_id," +
                "rules_version,parser_version,is_valid,row_count,level_count,unit_count,topic_count,test_count," +
                "warning_count,error_count,validation_report_sha256,allocation_sha256,preview_sha256," +
                "approval_binding_sha256,created_at" +
                ") values ('${fixture.importId}','${facts.quarantineId}','${facts.archiveId}','${facts.reportId}'," +
                "'${facts.scanId}','xlsx-v1','test-revision',false,0,0,0,0,0,0,1,'$REPORT_SHA'," +
                "null,null,null,'$T3'::timestamptz)",
        )
    }

    private fun insertPreviewRow(connection: Connection, importId: UUID, ordinal: Int) {
        execute(
            connection,
            "insert into course_import_preview_row(" +
                "import_id,ordinal,source_sheet_ordinal,source_sheet_name,source_row_number,payload" +
                ") values ('$importId',$ordinal,1,'Level',2,'{}'::jsonb)",
        )
    }

    private fun insertApproval(
        connection: Connection,
        fixture: Fixture,
        facts: PreviewFacts,
        approvalBinding: String,
    ) {
        execute(
            connection,
            "insert into course_import_approval(" +
                "id,import_id,owner_user_id,approval_binding_sha256,source_sha256,source_size_bytes," +
                "quarantine_artifact_id,archive_source_artifact_id,report_artifact_id,scan_id," +
                "scanner_engine_version,scanner_signature_version,rules_version,parser_version," +
                "allocation_sha256,preview_sha256,validation_report_sha256,approved_at,correlation_id" +
                ") values ('${UUID.randomUUID()}','${fixture.importId}','${fixture.ownerId}','$approvalBinding'," +
                "'$SHA',1,'${facts.quarantineId}','${facts.archiveId}','${facts.reportId}','${facts.scanId}'," +
                "'1.4.5','123','xlsx-v1','test-revision','$ALLOCATION_SHA','$PREVIEW_SHA','$REPORT_SHA'," +
                "'$T4'::timestamptz,'${fixture.correlation}')",
        )
    }

    private fun insertEvent(
        connection: Connection,
        fixture: Fixture,
        stateVersion: Int,
        eventType: String,
        from: String?,
        to: String,
        actor: UUID?,
        stableCode: String?,
        occurredAt: OffsetDateTime,
    ) {
        execute(
            connection,
            "insert into course_import_event(" +
                "id,import_id,state_version,event_type,from_status,to_status,actor_user_id,stable_code,correlation_id,occurred_at" +
                ") values ('${UUID.randomUUID()}','${fixture.importId}',$stateVersion,'$eventType'," +
                "${from.sqlLiteral()},'$to',${actor.sqlLiteral()},${stableCode.sqlLiteral()}," +
                "'${fixture.correlation}','$occurredAt'::timestamptz)",
        )
    }

    private fun initialImportSql(
        fixture: Fixture,
        status: String = "UPLOADING",
        createdAt: OffsetDateTime = T0,
    ): String =
        "insert into course_import(" +
            "id,owner_user_id,status,state_version,rules_version,original_file_name,declared_media_type," +
            "file_size_bytes,asserted_source_sha256,quarantine_bucket,quarantine_object_key,multipart_upload_id," +
            "upload_expires_at,processing_attempts,created_at,updated_at" +
            ") values ('${fixture.importId}','${fixture.ownerId}','$status',0,'xlsx-v1','course.xlsx'," +
            "'$XLSX_MEDIA_TYPE',1,'$SHA','quarantine','${fixture.objectKey}','multipart-1'," +
            "'${createdAt.plusMinutes(15)}'::timestamptz,0,'$createdAt'::timestamptz,'$createdAt'::timestamptz)"

    private fun scanInsertSql(
        fixture: Fixture,
        artifactId: UUID,
        sourceSha256: String,
        verdict: String,
        stableCode: String?,
        engineVersion: String?,
        signatureVersion: String?,
        id: UUID = UUID.randomUUID(),
    ): String =
        "insert into course_import_scan(" +
            "id,import_id,attempt_number,quarantine_artifact_id,verdict,stable_code,source_sha256," +
            "source_size_bytes,scanner_engine_version,scanner_signature_version,scanned_at" +
            ") values ('$id','${fixture.importId}',1,'$artifactId','$verdict',${stableCode.sqlLiteral()}," +
            "'$sourceSha256',1,${engineVersion.sqlLiteral()},${signatureVersion.sqlLiteral()},'$ARTIFACT_TIME'::timestamptz)"

    private fun retainedSnapshot(
        connection: Connection,
        userId: UUID,
        courseId: UUID,
        energyEventId: UUID,
        outboxEventId: UUID,
        attemptId: UUID,
        scoreEventId: UUID,
    ): List<String?> = listOf(
        queryString(connection, "select row_to_json(t)::text from (select * from app_user where id='$userId') t"),
        queryString(connection, "select row_to_json(t)::text from (select * from course where id='$courseId') t"),
        queryString(connection, "select row_to_json(t)::text from (select * from energy_event where id='$energyEventId') t"),
        queryString(connection, "select row_to_json(t)::text from (select * from test_attempt where id='$attemptId') t"),
        queryString(connection, "select row_to_json(t)::text from (select * from score_event where id='$scoreEventId') t"),
        queryString(
            connection,
            "select row_to_json(t)::text from (select * from learner_course_progress_projection " +
                "where user_id='$userId' and course_id='$courseId') t",
        ),
        queryString(connection, "select row_to_json(t)::text from (select * from outbox_event where id='$outboxEventId') t"),
        queryString(
            connection,
            "select row_to_json(t)::text from (select event_id,attempt_count,published_at,last_error " +
                "from outbox_delivery where event_id='$outboxEventId') t",
        ),
    )

    private fun insertUser(connection: Connection, id: UUID = UUID.randomUUID()): UUID {
        execute(
            connection,
            "insert into app_user(" +
                "id,oidc_subject,email,display_name,username,app_locale,active_target_language,time_zone,created_at,updated_at" +
                ") values ('$id','subject-$id','user-$id@example.invalid','Migration User',null,'en','tr','UTC'," +
                "'$T0'::timestamptz,'$T0'::timestamptz)",
        )
        return id
    }

    private fun newSchema(target: MigrationVersion? = null): String {
        val schema = "import_${UUID.randomUUID().toString().replace("-", "")}"
        migrate(schema, target)
        return schema
    }

    private fun migrate(schema: String, target: MigrationVersion? = null) {
        Flyway.configure()
            .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            .schemas(schema)
            .defaultSchema(schema)
            .createSchemas(true)
            .apply { if (target != null) target(target) }
            .load()
            .migrate()
    }

    private fun connection(schema: String): Connection =
        DriverManager.getConnection(postgres.jdbcUrl, postgres.username, postgres.password).also { connection ->
            connection.createStatement().use { it.execute("set search_path to \"$schema\"") }
        }

    private fun transaction(schema: String, block: (Connection) -> Unit) {
        transactionResult(schema) { connection -> block(connection) }
    }

    private fun <T> transactionResult(schema: String, block: (Connection) -> T): T = connection(schema).use { connection ->
        connection.autoCommit = false
        try {
            val result = block(connection)
            connection.commit()
            result
        } catch (failure: Throwable) {
            connection.rollback()
            throw failure
        }
    }

    private fun assertSqlFailure(block: () -> Unit) {
        assertThatThrownBy(block).isInstanceOf(SQLException::class.java)
    }

    private fun execute(connection: Connection, sql: String) {
        connection.createStatement().use { it.executeUpdate(sql.trimIndent()) }
    }

    private fun queryString(connection: Connection, sql: String): String? =
        connection.createStatement().use { statement ->
            statement.executeQuery(sql).use { result ->
                check(result.next())
                result.getString(1)
            }
        }

    private fun queryInt(connection: Connection, sql: String): Int =
        connection.createStatement().use { statement ->
            statement.executeQuery(sql).use { result ->
                check(result.next())
                result.getInt(1)
            }
        }

    private fun String?.sqlLiteral(): String = this?.let { "'$it'" } ?: "null"
    private fun UUID?.sqlLiteral(): String = this?.let { "'$it'" } ?: "null"

    private data class Fixture(
        val importId: UUID,
        val ownerId: UUID,
        val leaseToken: UUID,
        val outboxId: UUID,
    ) {
        val objectKey = "quarantine/$ownerId/$importId/$SHA.xlsx"
        val versionId = "version-$importId"
        val correlation = "correlation-$importId"
    }

    private data class PreviewFacts(
        val quarantineId: UUID,
        val archiveId: UUID,
        val reportId: UUID,
        val scanId: UUID,
    )

    private data class ClaimedAttempt(
        val fixture: Fixture,
        val processingStateVersion: Int,
        val attemptNumber: Int,
        val leaseToken: UUID,
        val claimedAt: OffsetDateTime,
    )

    private class KPostgreSQLContainer(image: DockerImageName) : PostgreSQLContainer<KPostgreSQLContainer>(image)

    companion object {
        private val T0 = OffsetDateTime.now(ZoneOffset.UTC).withNano(0)
        private val T1 = T0.plusMinutes(1)
        private val T2 = T0.plusMinutes(2)
        private val ARTIFACT_TIME = T0.plusMinutes(3)
        private val T3 = T0.plusMinutes(4)
        private val T4 = T0.plusMinutes(5)
        private val UPLOAD_EXPIRY = T0.plusMinutes(15)
        private val LEASE_EXPIRY = T2.plusMinutes(7)
        private const val XLSX_MEDIA_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        private val SHA = "a".repeat(64)
        private val OTHER_SHA = "f".repeat(64)
        private val REPORT_SHA = "b".repeat(64)
        private val ALLOCATION_SHA = "c".repeat(64)
        private val PREVIEW_SHA = "d".repeat(64)
        private val BINDING_SHA = "e".repeat(64)
        private val PART_SHA = java.util.Base64.getEncoder().encodeToString(ByteArray(32))
        private val COMPOSITE_SHA = "$PART_SHA-1"

        @Container
        @JvmStatic
        private val postgres = KPostgreSQLContainer(
            DockerImageName
                .parse("postgres:17.5-alpine@sha256:6567bca8d7bc8c82c5922425a0baee57be8402df92bae5eacad5f01ae9544daa")
                .asCompatibleSubstituteFor("postgres"),
        )
    }
}
