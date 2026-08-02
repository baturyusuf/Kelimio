package com.kelimio.api.importpipeline.intake

import com.fasterxml.jackson.databind.ObjectMapper
import org.jooq.DSLContext
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.time.Clock
import java.time.ZoneOffset
import java.time.Duration
import java.util.UUID

@Repository
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "worker")
class CourseImportWorkerRepository(
    private val dsl: DSLContext,
    private val imports: CourseImportRepository,
    private val objectMapper: ObjectMapper,
    private val clock: Clock,
) {
    fun unpublishedOutbox(limit: Int): List<ImportOutboxEvent> = dsl.fetch(
        """
        select e.id, e.aggregate_id, e.correlation_id
          from outbox_event e
          join outbox_delivery d on d.event_id = e.id
         where e.event_type = 'import.processing-requested.v1'
           and d.published_at is null
           and (d.next_attempt_at is null or d.next_attempt_at <= current_timestamp)
         order by e.occurred_at, e.id
         limit ?
        """.trimIndent(),
        limit,
    ).map {
        ImportOutboxEvent(
            eventId = it.get("id", UUID::class.java)!!,
            importId = it.get("aggregate_id", UUID::class.java)!!,
            correlationId = it.get("correlation_id", String::class.java)!!,
        )
    }

    @Transactional
    fun lockOutbox(eventId: UUID): ImportOutboxEvent? = dsl.fetchOne(
        """
        select e.id, e.aggregate_id, e.correlation_id
          from outbox_event e
          join outbox_delivery d on d.event_id = e.id
         where e.id = ?
           and e.event_type = 'import.processing-requested.v1'
           and d.published_at is null
           and (d.next_attempt_at is null or d.next_attempt_at <= current_timestamp)
         for update of d skip locked
        """.trimIndent(),
        eventId,
    )?.let {
        ImportOutboxEvent(
            eventId = it.get("id", UUID::class.java)!!,
            importId = it.get("aggregate_id", UUID::class.java)!!,
            correlationId = it.get("correlation_id", String::class.java)!!,
        )
    }

    fun markOutboxPublished(eventId: UUID, now: OffsetDateTime) {
        check(
            dsl.execute(
                """
                update outbox_delivery
                   set published_at = cast(? as timestamptz), attempt_count = attempt_count + 1,
                       last_error = null, next_attempt_at = null
                 where event_id = ? and published_at is null
                """.trimIndent(),
                now,
                eventId,
            ) == 1,
        ) { "Import outbox publication lost its delivery lock" }
    }

    @Transactional
    fun recordOutboxFailure(eventId: UUID, failureCode: String) {
        val result = dsl.fetchOne(
            """
            update outbox_delivery
               set attempt_count = attempt_count + 1, last_error = ?,
                   next_attempt_at = current_timestamp +
                       make_interval(secs => least(300, power(2, least(attempt_count + 1, 8))::integer))
             where event_id = ? and published_at is null
             returning attempt_count
            """.trimIndent(),
            failureCode.take(2000),
            eventId,
        ) ?: return
        val attempts = result.get("attempt_count", Int::class.java)!!
        if (attempts >= 5) {
            dsl.execute(
                """
                insert into course_import_dispatch_alert(event_id, import_id, attempt_count, stable_code, created_at)
                select e.id, e.aggregate_id, ?, 'sqs-publish-failed', current_timestamp
                  from outbox_event e where e.id = ?
                on conflict (event_id) do nothing
                """.trimIndent(),
                attempts,
                eventId,
            )
        }
    }

    fun validateCommand(command: ImportQueueCommand): Boolean {
        if (command.schemaVersion != IMPORT_QUEUE_SCHEMA_VERSION) return false
        return dsl.fetchOne(
        """
        select exists (
            select 1
              from outbox_event e
              join outbox_delivery d on d.event_id = e.id
             where e.id = ? and e.aggregate_id = ?
               and e.aggregate_type = 'course-import'
               and e.event_type = 'import.processing-requested.v1'
               and e.schema_version = 1
               and e.payload = jsonb_build_object('eventId', e.id, 'importId', e.aggregate_id)
        ) as valid
        """.trimIndent(),
        command.eventId,
        command.importId,
        )?.get("valid", Boolean::class.java) == true
    }

    fun needsDeadLetter(importId: UUID): Boolean = dsl.fetchOne(
        """
        select exists (
            select 1 from course_import i
             where i.id = ? and i.status = 'PROCESSING_FAILED'
               and not exists (select 1 from course_import_dead_letter d where d.import_id = i.id)
        ) as needed
        """.trimIndent(),
        importId,
    )?.get("needed", Boolean::class.java) == true

    @Transactional
    fun recordDeadLetter(command: ImportQueueCommand, providerMessageId: String, now: OffsetDateTime) {
        dsl.execute(
            """
            insert into course_import_dead_letter(import_id, event_id, reason_code, provider_message_id, created_at)
            values (?, ?, 'processing-failed', ?, cast(? as timestamptz))
            on conflict (import_id) do nothing
            """.trimIndent(),
            command.importId,
            command.eventId,
            providerMessageId.take(256),
            now,
        )
    }

    @Transactional
    fun claim(
        importId: UUID,
        now: OffsetDateTime,
        leaseExpiresAt: OffsetDateTime,
        correlationId: String,
    ): ProcessingClaimResult {
        var current = lock(importId) ?: return ProcessingClaimResult.Missing
        if (current.status in TERMINAL_STATES) return ProcessingClaimResult.Complete
        if (
            current.status == CourseImportStatus.PROCESSING &&
            current.leaseExpiresAt?.isAfter(now) == true
        ) {
            return ProcessingClaimResult.Busy
        }
        if (current.status == CourseImportStatus.PROCESSING) {
            dsl.execute(
                """
                insert into course_import_processing_attempt(
                    id, import_id, attempt_number, lease_token, outcome, stable_code, started_at, finished_at
                ) values (?, ?, ?, ?, ?, 'processing-lease-expired', cast(? as timestamptz), cast(? as timestamptz))
                on conflict (import_id, attempt_number) do nothing
                """.trimIndent(),
                UUID.randomUUID(),
                current.id,
                current.processingAttempts,
                checkNotNull(current.leaseToken),
                if (current.processingAttempts >= MAX_ATTEMPTS) "EXHAUSTED" else "RETRYABLE_FAILURE",
                current.updatedAt,
                now,
            )
            if (current.processingAttempts >= MAX_ATTEMPTS) {
                transitionFromProcessing(
                    current,
                    CourseImportStatus.PROCESSING_FAILED,
                    "processing-lease-expired",
                    correlationId,
                    now,
                )
                return ProcessingClaimResult.Complete
            }
            current = transitionFromProcessing(
                current,
                CourseImportStatus.QUEUED,
                "processing-lease-expired",
                correlationId,
                now,
            )
        }
        if (current.status != CourseImportStatus.QUEUED || current.processingAttempts >= MAX_ATTEMPTS) {
            return ProcessingClaimResult.Complete
        }
        val token = UUID.randomUUID()
        val nextVersion = current.stateVersion + 1
        val nextAttempt = current.processingAttempts + 1
        check(
            dsl.execute(
                """
                update course_import
                   set status = 'PROCESSING', state_version = ?, processing_attempts = ?,
                       processing_lease_token = ?, processing_lease_expires_at = cast(? as timestamptz),
                       failure_code = null, updated_at = cast(? as timestamptz)
                 where id = ? and status = 'QUEUED' and state_version = ?
                """.trimIndent(),
                nextVersion,
                nextAttempt,
                token,
                leaseExpiresAt,
                now,
                current.id,
                current.stateVersion,
            ) == 1,
        ) { "Course import processing claim lost its state lock" }
        imports.appendEvent(
            current.id,
            nextVersion,
            "processing-started",
            CourseImportStatus.QUEUED,
            CourseImportStatus.PROCESSING,
            null,
            null,
            correlationId,
            now,
        )
        return ProcessingClaimResult.Claimed(
            ProcessingClaim(
                importId = current.id,
                ownerUserId = current.ownerUserId,
                attemptNumber = nextAttempt,
                leaseToken = token,
                acceptedBucket = current.quarantineBucket,
                acceptedObjectKey = current.quarantineObjectKey,
                acceptedVersionId = checkNotNull(current.acceptedVersionId),
                acceptedEtag = checkNotNull(current.acceptedEtag),
                originalFileName = current.originalFileName,
                declaredMediaType = current.declaredMediaType,
                expectedSizeBytes = current.fileSizeBytes,
                assertedSourceSha256 = current.assertedSourceSha256,
                rulesVersion = current.rulesVersion,
                startedAt = now,
                correlationId = correlationId,
            ),
        )
    }

    @Transactional
    fun recordArtifact(claim: ProcessingClaim, artifact: NewImportArtifact): StoredImportArtifact {
        requireActiveLease(claim)
        val existing = findArtifact(claim.importId, artifact.kind)
        if (existing != null) {
            check(existing.matches(artifact)) { "Existing import artifact conflicts with deterministic retry" }
            return existing
        }
        val id = UUID.randomUUID()
        dsl.execute(
            """
            insert into course_import_artifact(
                id, import_id, artifact_kind, bucket_name, object_key,
                object_version_id, etag, sha256, size_bytes, media_type, created_at
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, cast(? as timestamptz))
            """.trimIndent(),
            id,
            claim.importId,
            artifact.kind.name,
            artifact.bucket,
            artifact.key,
            artifact.versionId,
            artifact.etag,
            artifact.sha256,
            artifact.sizeBytes,
            artifact.mediaType,
            artifact.createdAt,
        )
        return StoredImportArtifact(id, claim.importId, artifact)
    }

    @Transactional
    fun recordScan(
        claim: ProcessingClaim,
        quarantineArtifact: StoredImportArtifact,
        scan: NewImportScan,
    ): StoredImportScan {
        requireActiveLease(claim)
        findScan(claim.importId, claim.attemptNumber)?.let { existing ->
            check(existing.matches(scan, quarantineArtifact.id)) { "Existing import scan conflicts with retry" }
            return existing
        }
        val id = UUID.randomUUID()
        dsl.execute(
            """
            insert into course_import_scan(
                id, import_id, attempt_number, quarantine_artifact_id, verdict,
                stable_code, source_sha256, source_size_bytes, scanner_engine_version,
                scanner_signature_version, scanned_at
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, cast(? as timestamptz))
            """.trimIndent(),
            id,
            claim.importId,
            claim.attemptNumber,
            quarantineArtifact.id,
            scan.verdict.name,
            scan.stableCode,
            scan.sourceSha256,
            scan.sourceSizeBytes,
            scan.engineVersion,
            scan.signatureVersion,
            scan.scannedAt,
        )
        return StoredImportScan(id, claim.importId, claim.attemptNumber, quarantineArtifact.id, scan)
    }

    fun findCleanScan(importId: UUID): StoredImportScan? = dsl.fetchOne(
        """
        select id, import_id, attempt_number, quarantine_artifact_id, verdict,
               stable_code, source_sha256, source_size_bytes,
               scanner_engine_version, scanner_signature_version, scanned_at
          from course_import_scan
         where import_id = ? and verdict = 'CLEAN'
        """.trimIndent(),
        importId,
    )?.let(::toScan)

    fun findMalwareScan(importId: UUID): StoredImportScan? = dsl.fetchOne(
        """
        select id, import_id, attempt_number, quarantine_artifact_id, verdict,
               stable_code, source_sha256, source_size_bytes,
               scanner_engine_version, scanner_signature_version, scanned_at
          from course_import_scan
         where import_id = ? and verdict = 'MALWARE'
        """.trimIndent(),
        importId,
    )?.let(::toScan)

    @Transactional
    fun finishMalware(claim: ProcessingClaim, stableCode: String, now: OffsetDateTime) {
        finishWithoutPreview(claim, CourseImportStatus.MALWARE_REJECTED, stableCode, "MALWARE_REJECTED", now)
    }

    @Transactional
    fun finishFailure(claim: ProcessingClaim, stableCode: String, retryable: Boolean, now: OffsetDateTime): Boolean {
        val current = requireActiveLease(claim)
        val willRetry = retryable && claim.attemptNumber < MAX_ATTEMPTS
        val target = if (willRetry) CourseImportStatus.QUEUED else CourseImportStatus.PROCESSING_FAILED
        dsl.execute(
            """
            insert into course_import_processing_attempt(
                id, import_id, attempt_number, lease_token, outcome, stable_code,
                started_at, finished_at
            ) values (?, ?, ?, ?, ?, ?, cast(? as timestamptz), cast(? as timestamptz))
            """.trimIndent(),
            UUID.randomUUID(),
            claim.importId,
            claim.attemptNumber,
            claim.leaseToken,
            if (willRetry) "RETRYABLE_FAILURE" else "EXHAUSTED",
            stableCode,
            claim.startedAt,
            now,
        )
        transitionFromProcessing(current, target, stableCode, claim.correlationId, now)
        return willRetry
    }

    @Transactional
    fun finishPreview(
        claim: ProcessingClaim,
        cleanScan: StoredImportScan,
        quarantineArtifact: StoredImportArtifact,
        archiveArtifact: StoredImportArtifact,
        reportArtifact: StoredImportArtifact,
        persisted: PersistedImportPreview,
        now: OffsetDateTime,
        deadline: OffsetDateTime,
    ) {
        val remaining = Duration.between(OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC), deadline)
        check(!remaining.isZero && !remaining.isNegative) { "Course import persistence deadline expired" }
        val timeoutMillis = remaining.toMillis().coerceAtLeast(1).toString()
        dsl.fetchValue("select set_config('statement_timeout', ?, true)", "$timeoutMillis ms")
        dsl.fetchValue("select set_config('transaction_timeout', ?, true)", "$timeoutMillis ms")
        val current = requireActiveLease(claim)
        dsl.execute(
            """
            insert into course_import_preview(
                import_id, quarantine_artifact_id, archive_source_artifact_id,
                report_artifact_id, clean_scan_id, rules_version, parser_version,
                is_valid, row_count, level_count, unit_count, topic_count, test_count,
                warning_count, error_count, validation_report_sha256,
                allocation_sha256, preview_sha256, approval_binding_sha256, created_at
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, cast(? as timestamptz))
            """.trimIndent(),
            claim.importId,
            quarantineArtifact.id,
            archiveArtifact.id,
            reportArtifact.id,
            cleanScan.id,
            persisted.rulesVersion,
            persisted.parserVersion,
            persisted.summary.isValid,
            persisted.summary.rowCount,
            persisted.summary.levelCount,
            persisted.summary.unitCount,
            persisted.summary.topicCount,
            persisted.summary.testCount,
            persisted.summary.warningCount,
            persisted.summary.errorCount,
            persisted.summary.validationReportSha256,
            persisted.summary.allocationSha256,
            persisted.summary.previewSha256,
            persisted.approvalBindingSha256,
            now,
        )
        dsl.connection { connection ->
            connection.prepareStatement(
                """
                insert into course_import_preview_row(
                    import_id, ordinal, source_sheet_ordinal, source_sheet_name, source_row_number, payload
                ) values (?, ?, ?, ?, ?, cast(? as jsonb))
                """.trimIndent(),
            ).use { statement ->
                persisted.rows.forEachIndexed { index, row ->
                    statement.setObject(1, claim.importId)
                    statement.setInt(2, row.ordinal)
                    statement.setInt(3, row.source.sheetOrdinal)
                    statement.setString(4, row.source.sheetName)
                    statement.setInt(5, row.source.rowNumber)
                    statement.setString(6, objectMapper.writeValueAsString(row))
                    statement.addBatch()
                    if ((index + 1) % PERSISTENCE_BATCH_SIZE == 0) statement.executeBatch()
                }
                if (persisted.rows.size % PERSISTENCE_BATCH_SIZE != 0) statement.executeBatch()
            }
            connection.prepareStatement(
                """
                insert into course_import_preview_issue(
                    import_id, ordinal, severity, issue_code, source_sheet_ordinal,
                    source_sheet_name, source_row_number, source_column_number, source_reference, message
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """.trimIndent(),
            ).use { statement ->
                persisted.issues.forEachIndexed { index, issue ->
                    statement.setObject(1, claim.importId)
                    statement.setInt(2, issue.ordinal)
                    statement.setString(3, issue.severity)
                    statement.setString(4, issue.code)
                    statement.setObject(5, issue.source?.sheetOrdinal)
                    statement.setString(6, issue.source?.sheetName)
                    statement.setObject(7, issue.source?.rowNumber)
                    statement.setObject(8, issue.source?.columnNumber)
                    statement.setString(9, issue.source?.reference)
                    statement.setString(10, issue.message)
                    statement.addBatch()
                    if ((index + 1) % PERSISTENCE_BATCH_SIZE == 0) statement.executeBatch()
                }
                if (persisted.issues.size % PERSISTENCE_BATCH_SIZE != 0) statement.executeBatch()
            }
        }
        val status = if (persisted.summary.isValid) {
            CourseImportStatus.PREVIEW_READY
        } else {
            CourseImportStatus.VALIDATION_FAILED
        }
        dsl.execute(
            """
            insert into course_import_processing_attempt(
                id, import_id, attempt_number, lease_token, outcome, stable_code,
                started_at, finished_at
            ) values (?, ?, ?, ?, ?, null, cast(? as timestamptz), cast(? as timestamptz))
            """.trimIndent(),
            UUID.randomUUID(),
            claim.importId,
            claim.attemptNumber,
            claim.leaseToken,
            status.name,
            claim.startedAt,
            now,
        )
        transitionFromProcessing(current, status, null, claim.correlationId, now)
    }

    fun artifact(importId: UUID, kind: ImportArtifactKind): StoredImportArtifact? = findArtifact(importId, kind)

    private fun finishWithoutPreview(
        claim: ProcessingClaim,
        status: CourseImportStatus,
        stableCode: String,
        outcome: String,
        now: OffsetDateTime,
    ) {
        val current = requireActiveLease(claim)
        dsl.execute(
            """
            insert into course_import_processing_attempt(
                id, import_id, attempt_number, lease_token, outcome, stable_code,
                started_at, finished_at
            ) values (?, ?, ?, ?, ?, ?, cast(? as timestamptz), cast(? as timestamptz))
            """.trimIndent(),
            UUID.randomUUID(),
            claim.importId,
            claim.attemptNumber,
            claim.leaseToken,
            outcome,
            stableCode,
            claim.startedAt,
            now,
        )
        transitionFromProcessing(current, status, stableCode, claim.correlationId, now)
    }

    private fun transitionFromProcessing(
        current: StoredCourseImport,
        target: CourseImportStatus,
        stableCode: String?,
        correlationId: String,
        now: OffsetDateTime,
    ): StoredCourseImport {
        val nextVersion = current.stateVersion + 1
        check(
            dsl.execute(
                """
                update course_import
                   set status = ?, state_version = ?, processing_lease_token = null,
                       processing_lease_expires_at = null, failure_code = ?,
                       updated_at = cast(? as timestamptz)
                 where id = ? and status = 'PROCESSING' and state_version = ?
                """.trimIndent(),
                target.name,
                nextVersion,
                stableCode,
                now,
                current.id,
                current.stateVersion,
            ) == 1,
        ) { "Course import worker lost its processing lease" }
        imports.appendEvent(
            current.id,
            nextVersion,
            when (target) {
                CourseImportStatus.QUEUED -> "processing-retry-scheduled"
                CourseImportStatus.PREVIEW_READY -> "preview-ready"
                CourseImportStatus.VALIDATION_FAILED -> "validation-failed"
                CourseImportStatus.MALWARE_REJECTED -> "malware-rejected"
                CourseImportStatus.PROCESSING_FAILED -> "processing-failed"
                else -> error("Unsupported worker transition")
            },
            CourseImportStatus.PROCESSING,
            target,
            null,
            stableCode,
            correlationId,
            now,
        )
        return lock(current.id)!!
    }

    private fun requireActiveLease(claim: ProcessingClaim): StoredCourseImport {
        val current = lock(claim.importId) ?: error("Course import disappeared")
        check(
            current.status == CourseImportStatus.PROCESSING &&
                current.leaseToken == claim.leaseToken &&
                current.processingAttempts == claim.attemptNumber &&
                current.leaseExpiresAt?.isAfter(OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)) == true
        ) { "Course import worker lease is stale" }
        return current
    }

    private fun lock(importId: UUID): StoredCourseImport? = dsl.fetchOne(
        """
        select id, owner_user_id, status, state_version, rules_version,
               original_file_name, declared_media_type, file_size_bytes,
               asserted_source_sha256, quarantine_bucket, quarantine_object_key,
               multipart_upload_id, upload_expires_at, accepted_version_id,
               accepted_etag, processing_attempts, processing_lease_token,
               processing_lease_expires_at, failure_code, created_at, updated_at
          from course_import
         where id = ?
         for update
        """.trimIndent(),
        importId,
    )?.let { row ->
        StoredCourseImport(
            id = row.get("id", UUID::class.java)!!,
            ownerUserId = row.get("owner_user_id", UUID::class.java)!!,
            status = CourseImportStatus.valueOf(row.get("status", String::class.java)!!),
            stateVersion = row.get("state_version", Long::class.java)!!,
            rulesVersion = row.get("rules_version", String::class.java)!!,
            originalFileName = row.get("original_file_name", String::class.java)!!,
            declaredMediaType = row.get("declared_media_type", String::class.java)!!,
            fileSizeBytes = row.get("file_size_bytes", Long::class.java)!!,
            assertedSourceSha256 = row.get("asserted_source_sha256", String::class.java)!!,
            quarantineBucket = row.get("quarantine_bucket", String::class.java)!!,
            quarantineObjectKey = row.get("quarantine_object_key", String::class.java)!!,
            multipartUploadId = row.get("multipart_upload_id", String::class.java)!!,
            uploadExpiresAt = row.get("upload_expires_at", OffsetDateTime::class.java)!!,
            acceptedVersionId = row.get("accepted_version_id", String::class.java),
            acceptedEtag = row.get("accepted_etag", String::class.java),
            processingAttempts = row.get("processing_attempts", Int::class.java)!!,
            leaseToken = row.get("processing_lease_token", UUID::class.java),
            leaseExpiresAt = row.get("processing_lease_expires_at", OffsetDateTime::class.java),
            failureCode = row.get("failure_code", String::class.java),
            createdAt = row.get("created_at", OffsetDateTime::class.java)!!,
            updatedAt = row.get("updated_at", OffsetDateTime::class.java)!!,
        )
    }

    private fun findArtifact(importId: UUID, kind: ImportArtifactKind): StoredImportArtifact? = dsl.fetchOne(
        """
        select id, import_id, artifact_kind, bucket_name, object_key, object_version_id,
               etag, sha256, size_bytes, media_type, created_at
          from course_import_artifact
         where import_id = ? and artifact_kind = ?
        """.trimIndent(),
        importId,
        kind.name,
    )?.let {
        StoredImportArtifact(
            id = it.get("id", UUID::class.java)!!,
            importId = it.get("import_id", UUID::class.java)!!,
            artifact = NewImportArtifact(
                kind = ImportArtifactKind.valueOf(it.get("artifact_kind", String::class.java)!!),
                bucket = it.get("bucket_name", String::class.java)!!,
                key = it.get("object_key", String::class.java)!!,
                versionId = it.get("object_version_id", String::class.java)!!,
                etag = it.get("etag", String::class.java)!!,
                sha256 = it.get("sha256", String::class.java)!!,
                sizeBytes = it.get("size_bytes", Long::class.java)!!,
                mediaType = it.get("media_type", String::class.java)!!,
                createdAt = it.get("created_at", OffsetDateTime::class.java)!!,
            ),
        )
    }

    private fun findScan(importId: UUID, attemptNumber: Int): StoredImportScan? = dsl.fetchOne(
        """
        select id, import_id, attempt_number, quarantine_artifact_id, verdict,
               stable_code, source_sha256, source_size_bytes,
               scanner_engine_version, scanner_signature_version, scanned_at
          from course_import_scan
         where import_id = ? and attempt_number = ?
        """.trimIndent(),
        importId,
        attemptNumber,
    )?.let(::toScan)

    private fun toScan(row: org.jooq.Record): StoredImportScan = StoredImportScan(
        id = row.get("id", UUID::class.java)!!,
        importId = row.get("import_id", UUID::class.java)!!,
        attemptNumber = row.get("attempt_number", Int::class.java)!!,
        quarantineArtifactId = row.get("quarantine_artifact_id", UUID::class.java)!!,
        scan = NewImportScan(
            verdict = ImportScanVerdict.valueOf(row.get("verdict", String::class.java)!!),
            stableCode = row.get("stable_code", String::class.java),
            sourceSha256 = row.get("source_sha256", String::class.java)!!,
            sourceSizeBytes = row.get("source_size_bytes", Long::class.java)!!,
            engineVersion = row.get("scanner_engine_version", String::class.java),
            signatureVersion = row.get("scanner_signature_version", String::class.java),
            scannedAt = row.get("scanned_at", OffsetDateTime::class.java)!!,
        ),
    )

    private companion object {
        const val MAX_ATTEMPTS = 5
        const val IMPORT_QUEUE_SCHEMA_VERSION = 1
        const val PERSISTENCE_BATCH_SIZE = 500
        val TERMINAL_STATES = setOf(
            CourseImportStatus.PREVIEW_READY,
            CourseImportStatus.VALIDATION_FAILED,
            CourseImportStatus.MALWARE_REJECTED,
            CourseImportStatus.PROCESSING_FAILED,
            CourseImportStatus.EXPIRED,
            CourseImportStatus.APPROVED,
        )
    }
}

data class ImportOutboxEvent(
    val eventId: UUID,
    val importId: UUID,
    val correlationId: String,
) : RedactedImportModel()

data class ImportQueueCommand(
    val schemaVersion: Int,
    val eventId: UUID,
    val importId: UUID,
) : RedactedImportModel()

sealed interface ProcessingClaimResult {
    data class Claimed(val claim: ProcessingClaim) : ProcessingClaimResult
    data object Busy : ProcessingClaimResult
    data object Complete : ProcessingClaimResult
    data object Missing : ProcessingClaimResult
}

data class ProcessingClaim(
    val importId: UUID,
    val ownerUserId: UUID,
    val attemptNumber: Int,
    val leaseToken: UUID,
    val acceptedBucket: String,
    val acceptedObjectKey: String,
    val acceptedVersionId: String,
    val acceptedEtag: String,
    val originalFileName: String,
    val declaredMediaType: String,
    val expectedSizeBytes: Long,
    val assertedSourceSha256: String,
    val rulesVersion: String,
    val startedAt: OffsetDateTime,
    val correlationId: String,
) : RedactedImportModel()

enum class ImportArtifactKind {
    QUARANTINE_SOURCE,
    ARCHIVE_SOURCE,
    VALIDATION_REPORT,
}

data class NewImportArtifact(
    val kind: ImportArtifactKind,
    val bucket: String,
    val key: String,
    val versionId: String,
    val etag: String,
    val sha256: String,
    val sizeBytes: Long,
    val mediaType: String,
    val createdAt: OffsetDateTime,
) : RedactedImportModel()

data class StoredImportArtifact(
    val id: UUID,
    val importId: UUID,
    val artifact: NewImportArtifact,
) : RedactedImportModel() {
    fun matches(other: NewImportArtifact): Boolean =
        artifact.kind == other.kind && artifact.bucket == other.bucket && artifact.key == other.key &&
            artifact.versionId == other.versionId && artifact.etag == other.etag &&
            artifact.sha256 == other.sha256 && artifact.sizeBytes == other.sizeBytes &&
            artifact.mediaType == other.mediaType
}

enum class ImportScanVerdict {
    CLEAN,
    MALWARE,
    ERROR,
}

data class NewImportScan(
    val verdict: ImportScanVerdict,
    val stableCode: String?,
    val sourceSha256: String,
    val sourceSizeBytes: Long,
    val engineVersion: String?,
    val signatureVersion: String?,
    val scannedAt: OffsetDateTime,
) : RedactedImportModel()

data class StoredImportScan(
    val id: UUID,
    val importId: UUID,
    val attemptNumber: Int,
    val quarantineArtifactId: UUID,
    val scan: NewImportScan,
) : RedactedImportModel() {
    fun matches(other: NewImportScan, artifactId: UUID): Boolean =
        quarantineArtifactId == artifactId && scan.verdict == other.verdict &&
            scan.stableCode == other.stableCode && scan.sourceSha256 == other.sourceSha256 &&
            scan.sourceSizeBytes == other.sourceSizeBytes && scan.engineVersion == other.engineVersion &&
            scan.signatureVersion == other.signatureVersion
}

data class PersistedImportPreview(
    val rulesVersion: String,
    val parserVersion: String,
    val summary: CourseImportPreviewSummary,
    val approvalBindingSha256: String?,
    val rows: List<CourseImportPreviewRow>,
    val issues: List<CourseImportValidationIssue>,
) : RedactedImportModel()
