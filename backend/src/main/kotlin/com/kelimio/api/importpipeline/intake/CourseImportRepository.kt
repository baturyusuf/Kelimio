package com.kelimio.api.importpipeline.intake

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.courseauthoring.InitialCourseDraftResult
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.NotFoundProblem
import com.kelimio.api.web.TooManyRequestsProblem
import org.jooq.DSLContext
import org.jooq.JSONB
import org.jooq.Record
import org.springframework.stereotype.Repository
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.OffsetDateTime
import java.util.Base64
import java.util.UUID
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

@Repository
class CourseImportRepository(
    private val dsl: DSLContext,
    private val objectMapper: ObjectMapper,
) {
    fun enforceCreationQuota(ownerUserId: UUID, now: OffsetDateTime) {
        dsl.fetch("select pg_advisory_xact_lock(hashtextextended(cast(? as text), 918237))", ownerUserId)
        val active = dsl.fetchOne(
            """
            select count(*) as count from course_import i
             where i.owner_user_id = ? and (
                i.status in ('QUEUED','PROCESSING')
                or (i.status = 'UPLOADING' and not exists (
                    select 1 from course_import_recovery_alert a where a.import_id = i.id
                ))
             )
            """.trimIndent(),
            ownerUserId,
        )?.get("count", Long::class.java) ?: 0
        val recent = dsl.fetchOne(
            "select count(*) as count from course_import where owner_user_id = ? and created_at >= cast(? as timestamptz) - interval '1 hour'",
            ownerUserId,
            now,
        )?.get("count", Long::class.java) ?: 0
        if (active >= 3 || recent >= 20) {
            throw TooManyRequestsProblem("The course import creation quota has been reached.")
        }
    }

    fun create(
        value: NewCourseImport,
        parts: List<CourseImportPart>,
        correlationId: String,
    ) {
        dsl.execute(
            """
            insert into course_import(
                id, owner_user_id, status, state_version, rules_version,
                original_file_name, declared_media_type, file_size_bytes,
                asserted_source_sha256, quarantine_bucket, quarantine_object_key,
                multipart_upload_id, upload_expires_at, processing_attempts,
                created_at, updated_at
            ) values (
                ?, ?, 'UPLOADING', 0, ?, ?, ?, ?, ?, ?, ?, ?,
                cast(? as timestamptz), 0, cast(? as timestamptz), cast(? as timestamptz)
            )
            """.trimIndent(),
            value.id,
            value.ownerUserId,
            value.rulesVersion,
            value.originalFileName,
            value.declaredMediaType,
            value.fileSizeBytes,
            value.sourceSha256,
            value.quarantineBucket,
            value.quarantineObjectKey,
            value.multipartUploadId,
            value.uploadExpiresAt,
            value.createdAt,
            value.createdAt,
        )
        parts.forEach { part ->
            dsl.execute(
                """
                insert into course_import_part(import_id, part_number, size_bytes, sha256_base64)
                values (?, ?, ?, ?)
                """.trimIndent(),
                value.id,
                part.partNumber,
                part.sizeBytes,
                part.sha256Base64,
            )
        }
        appendEvent(
            importId = value.id,
            stateVersion = 0,
            eventType = "import-created",
            fromStatus = null,
            toStatus = CourseImportStatus.UPLOADING,
            actorUserId = value.ownerUserId,
            stableCode = null,
            correlationId = correlationId,
            now = value.createdAt,
        )
    }

    fun findOwned(ownerUserId: UUID, importId: UUID): StoredCourseImport =
        find(ownerUserId, importId, lock = false)

    fun lockOwned(ownerUserId: UUID, importId: UUID): StoredCourseImport =
        find(ownerUserId, importId, lock = true)

    fun expiredUploadingIds(now: OffsetDateTime, limit: Int): List<UUID> = dsl.fetch(
        """
        select i.id from course_import i
         where i.status = 'UPLOADING' and i.upload_expires_at <= cast(? as timestamptz)
           and not exists (select 1 from course_import_recovery_alert a where a.import_id = i.id)
         order by i.upload_expires_at limit ?
        """.trimIndent(),
        now,
        limit,
    ).map { it.get("id", UUID::class.java)!! }

    fun lockExpired(importId: UUID, now: OffsetDateTime): StoredCourseImport? = dsl.fetchOne(
        """
        select id, owner_user_id, status, state_version, rules_version,
               original_file_name, declared_media_type, file_size_bytes,
               asserted_source_sha256, quarantine_bucket, quarantine_object_key,
               multipart_upload_id, upload_expires_at, accepted_version_id,
               accepted_etag, processing_attempts, processing_lease_token,
               processing_lease_expires_at, failure_code, created_at, updated_at
          from course_import
         where id = ? and status = 'UPLOADING' and upload_expires_at <= cast(? as timestamptz)
         for update
        """.trimIndent(),
        importId,
        now,
    )?.let(::toImport)

    fun markExpired(current: StoredCourseImport, correlationId: String, now: OffsetDateTime) {
        val nextVersion = current.stateVersion + 1
        check(
            dsl.execute(
                """
                update course_import set status = 'EXPIRED', state_version = ?, updated_at = cast(? as timestamptz)
                 where id = ? and status = 'UPLOADING' and state_version = ?
                """.trimIndent(),
                nextVersion,
                now,
                current.id,
                current.stateVersion,
            ) == 1,
        )
        appendEvent(
            current.id,
            nextVersion,
            "upload-expired",
            CourseImportStatus.UPLOADING,
            CourseImportStatus.EXPIRED,
            null,
            "upload-expired",
            correlationId,
            now,
        )
    }

    fun recordRecoveryAlert(importId: UUID, disposition: String, now: OffsetDateTime) {
        dsl.execute(
            """
            insert into course_import_recovery_alert(import_id, disposition, created_at)
            values (?, ?, cast(? as timestamptz))
            on conflict (import_id) do nothing
            """.trimIndent(),
            importId,
            disposition,
            now,
        )
    }

    fun parts(importId: UUID): List<CourseImportPart> = dsl.fetch(
        """
        select part_number, size_bytes, sha256_base64
          from course_import_part
         where import_id = ?
         order by part_number
        """.trimIndent(),
        importId,
    ).map {
        CourseImportPart(
            partNumber = it.get("part_number", Int::class.java)!!,
            sizeBytes = it.get("size_bytes", Long::class.java)!!,
            sha256Base64 = it.get("sha256_base64", String::class.java)!!,
        )
    }

    fun markCompleted(
        current: StoredCourseImport,
        completedParts: List<CompletedCourseImportPart>,
        versionId: String,
        etag: String,
        checksumSha256: String?,
        completionEvidence: CourseImportCompletionEvidence,
        correlationId: String,
        now: OffsetDateTime,
    ) {
        completedParts.forEach { part ->
            dsl.execute(
                """
                insert into course_import_completed_part(
                    import_id, part_number, etag, sha256_base64, evidence_source, completed_at
                ) values (?, ?, ?, ?, ?, cast(? as timestamptz))
                on conflict (import_id, part_number) do nothing
                """.trimIndent(),
                current.id,
                part.partNumber,
                part.eTag.takeIf { completionEvidence == CourseImportCompletionEvidence.S3_VERIFIED },
                part.sha256,
                completionEvidence.name,
                now,
            )
        }
        val nextVersion = current.stateVersion + 1
        check(
            dsl.execute(
                """
                update course_import
                   set status = 'QUEUED', state_version = ?, accepted_version_id = ?,
                       accepted_etag = ?, accepted_size_bytes = file_size_bytes,
                       accepted_checksum_sha256 = ?, failure_code = null,
                       updated_at = cast(? as timestamptz)
                 where id = ? and owner_user_id = ? and status = 'UPLOADING' and state_version = ?
                """.trimIndent(),
                nextVersion,
                versionId,
                etag,
                checksumSha256,
                now,
                current.id,
                current.ownerUserId,
                current.stateVersion,
            ) == 1,
        ) { "Course import completion lost its state lock" }
        appendEvent(
            current.id,
            nextVersion,
            "upload-completed",
            CourseImportStatus.UPLOADING,
            CourseImportStatus.QUEUED,
            current.ownerUserId,
            null,
            correlationId,
            now,
        )
    }

    fun preview(importId: UUID): StoredPreview? = dsl.fetchOne(
        """
        select import_id, quarantine_artifact_id, archive_source_artifact_id,
               report_artifact_id, clean_scan_id, rules_version, parser_version,
               content_schema_version, settings_payload,
               is_valid, row_count, question_count, matching_question_count,
               required_client_capabilities, level_count, unit_count, topic_count,
               test_count, warning_count, error_count, validation_report_sha256,
               allocation_sha256, preview_sha256, approval_binding_sha256
          from course_import_preview
         where import_id = ?
        """.trimIndent(),
        importId,
    )?.let(::toPreview)

    fun approval(importId: UUID): StoredApproval? = dsl.fetchOne(
        """
        select id, import_id, source_sha256, approval_binding_sha256, approved_at
          from course_import_approval
         where import_id = ?
        """.trimIndent(),
        importId,
    )?.let {
        StoredApproval(
            id = it.get("id", UUID::class.java)!!,
            importId = it.get("import_id", UUID::class.java)!!,
            sourceSha256 = it.get("source_sha256", String::class.java)!!,
            approvalBindingSha256 = it.get("approval_binding_sha256", String::class.java)!!,
            approvedAt = it.get("approved_at", OffsetDateTime::class.java)!!,
        )
    }

    fun commit(importId: UUID): StoredCourseImportCommit? = dsl.fetchOne(
        """
        select id, import_id, owner_user_id, approval_id, approval_binding_sha256,
               course_id, content_change_set_id, draft_release_id,
               row_count, question_count, matching_question_count,
               required_client_capabilities, committed_at
          from course_import_commit
         where import_id = ?
        """.trimIndent(),
        importId,
    )?.let {
        StoredCourseImportCommit(
            id = it.get("id", UUID::class.java)!!,
            importId = it.get("import_id", UUID::class.java)!!,
            ownerUserId = it.get("owner_user_id", UUID::class.java)!!,
            approvalId = it.get("approval_id", UUID::class.java)!!,
            approvalBindingSha256 = it.get("approval_binding_sha256", String::class.java)!!,
            courseId = it.get("course_id", UUID::class.java)!!,
            contentChangeSetId = it.get("content_change_set_id", UUID::class.java)!!,
            draftReleaseId = it.get("draft_release_id", UUID::class.java)!!,
            sourceRowCount = it.get("row_count", Int::class.java)!!,
            questionCount = it.get("question_count", Int::class.java)!!,
            matchingQuestionCount = it.get("matching_question_count", Int::class.java)!!,
            requiredClientCapabilities = it.get(
                "required_client_capabilities",
                Array<String>::class.java,
            )!!.toList(),
            committedAt = it.get("committed_at", OffsetDateTime::class.java)!!,
        )
    }

    fun previewRows(importId: UUID, afterOrdinal: Int, limit: Int): List<CourseImportPreviewRow> = dsl.fetch(
        """
        select ordinal, payload
          from course_import_preview_row
         where import_id = ? and ordinal > ?
         order by ordinal
         limit ?
        """.trimIndent(),
        importId,
        afterOrdinal,
        limit,
    ).map { row ->
        objectMapper.readValue(row.get("payload", JSONB::class.java)!!.data(), CourseImportPreviewRow::class.java)
    }

    fun previewIssues(importId: UUID, afterOrdinal: Int, limit: Int): List<CourseImportValidationIssue> =
        dsl.fetch(
            """
            select ordinal, severity, issue_code, source_sheet_ordinal, source_sheet_name,
                   source_row_number, source_column_number, source_reference, message
              from course_import_preview_issue
             where import_id = ? and ordinal > ?
             order by ordinal
             limit ?
            """.trimIndent(),
            importId,
            afterOrdinal,
            limit,
        ).map(::toCourseImportValidationIssue)

    fun appendApproval(
        current: StoredCourseImport,
        preview: StoredPreview,
        provenance: ApprovalProvenance,
        correlationId: String,
        now: OffsetDateTime,
    ): StoredApproval {
        val approvalId = UUID.randomUUID()
        dsl.execute(
            """
            insert into course_import_approval(
                id, import_id, owner_user_id, approval_binding_sha256,
                source_sha256, source_size_bytes, quarantine_artifact_id,
                archive_source_artifact_id, report_artifact_id, scan_id,
                scanner_engine_version, scanner_signature_version, rules_version,
                parser_version, allocation_sha256, preview_sha256,
                validation_report_sha256, approved_at, correlation_id
            ) values (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                cast(? as timestamptz), ?
            )
            """.trimIndent(),
            approvalId,
            current.id,
            current.ownerUserId,
            preview.approvalBindingSha256,
            provenance.sourceSha256,
            provenance.sourceSizeBytes,
            preview.quarantineArtifactId,
            preview.archiveSourceArtifactId,
            preview.reportArtifactId,
            preview.cleanScanId,
            provenance.scannerEngineVersion,
            provenance.scannerSignatureVersion,
            preview.rulesVersion,
            preview.parserVersion,
            preview.summary.allocationSha256,
            preview.summary.previewSha256,
            preview.summary.validationReportSha256,
            now,
            correlationId,
        )
        val nextVersion = current.stateVersion + 1
        check(
            dsl.execute(
                """
                update course_import
                   set status = 'APPROVED', state_version = ?, updated_at = cast(? as timestamptz)
                 where id = ? and owner_user_id = ? and status = 'PREVIEW_READY' and state_version = ?
                """.trimIndent(),
                nextVersion,
                now,
                current.id,
                current.ownerUserId,
                current.stateVersion,
            ) == 1,
        ) { "Course import approval lost its state lock" }
        appendEvent(
            current.id,
            nextVersion,
            "import-approved",
            CourseImportStatus.PREVIEW_READY,
            CourseImportStatus.APPROVED,
            current.ownerUserId,
            null,
            correlationId,
            now,
        )
        return StoredApproval(
            id = approvalId,
            importId = current.id,
            sourceSha256 = provenance.sourceSha256,
            approvalBindingSha256 = checkNotNull(preview.approvalBindingSha256),
            approvedAt = now,
        )
    }

    fun appendCommit(
        current: StoredCourseImport,
        approval: StoredApproval,
        preview: StoredPreview,
        draft: InitialCourseDraftResult,
        outboxEventId: UUID,
        correlationId: String,
        now: OffsetDateTime,
    ): StoredCourseImportCommit {
        val commitId = UUID.randomUUID()
        dsl.execute(
            """
            insert into course_import_commit(
                id, import_id, owner_user_id, approval_id, approval_binding_sha256,
                content_schema_version, source_sha256, allocation_sha256, preview_sha256,
                course_id, content_change_set_id, draft_release_id, outbox_event_id,
                row_count, question_count, matching_question_count, required_client_capabilities,
                level_count, unit_count, topic_count, test_count,
                committed_at, correlation_id
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                cast(? as timestamptz), ?)
            """.trimIndent(),
            commitId,
            current.id,
            current.ownerUserId,
            approval.id,
            approval.approvalBindingSha256,
            checkNotNull(preview.contentSchemaVersion),
            approval.sourceSha256,
            checkNotNull(preview.summary.allocationSha256),
            checkNotNull(preview.summary.previewSha256),
            draft.courseId,
            draft.contentChangeSetId,
            draft.draftReleaseId,
            outboxEventId,
            draft.sourceRowCount,
            draft.questionCount,
            draft.matchingQuestionCount,
            draft.requiredClientCapabilities.toTypedArray(),
            draft.levelCount,
            draft.unitCount,
            draft.topicCount,
            draft.testCount,
            now,
            correlationId,
        )
        val nextVersion = current.stateVersion + 1
        check(
            dsl.execute(
                """
                update course_import
                   set status = 'COMMITTED', state_version = ?, updated_at = cast(? as timestamptz)
                 where id = ? and owner_user_id = ? and status = 'APPROVED' and state_version = ?
                """.trimIndent(),
                nextVersion,
                now,
                current.id,
                current.ownerUserId,
                current.stateVersion,
            ) == 1,
        ) { "Course import commit lost its state lock" }
        appendEvent(
            current.id,
            nextVersion,
            "import-committed",
            CourseImportStatus.APPROVED,
            CourseImportStatus.COMMITTED,
            current.ownerUserId,
            null,
            correlationId,
            now,
        )
        return StoredCourseImportCommit(
            id = commitId,
            importId = current.id,
            ownerUserId = current.ownerUserId,
            approvalId = approval.id,
            approvalBindingSha256 = approval.approvalBindingSha256,
            courseId = draft.courseId,
            contentChangeSetId = draft.contentChangeSetId,
            draftReleaseId = draft.draftReleaseId,
            sourceRowCount = draft.sourceRowCount,
            questionCount = draft.questionCount,
            matchingQuestionCount = draft.matchingQuestionCount,
            requiredClientCapabilities = draft.requiredClientCapabilities,
            committedAt = now,
        )
    }

    fun approvalProvenance(importId: UUID): ApprovalProvenance = dsl.fetchOne(
        """
        select s.source_sha256, s.source_size_bytes,
               s.scanner_engine_version, s.scanner_signature_version
          from course_import_preview p
          join course_import_scan s on s.id = p.clean_scan_id
         where p.import_id = ? and p.is_valid and s.verdict = 'CLEAN'
        """.trimIndent(),
        importId,
    )?.let {
        ApprovalProvenance(
            sourceSha256 = it.get("source_sha256", String::class.java)!!,
            sourceSizeBytes = it.get("source_size_bytes", Long::class.java)!!,
            scannerEngineVersion = it.get("scanner_engine_version", String::class.java)!!,
            scannerSignatureVersion = it.get("scanner_signature_version", String::class.java)!!,
        )
    } ?: throw ConflictProblem("The course import has no approvable provenance.")

    private fun find(ownerUserId: UUID, importId: UUID, lock: Boolean): StoredCourseImport {
        val suffix = if (lock) " for update" else ""
        return dsl.fetchOne(
            """
            select id, owner_user_id, status, state_version, rules_version,
                   original_file_name, declared_media_type, file_size_bytes,
                   asserted_source_sha256, quarantine_bucket, quarantine_object_key,
                   multipart_upload_id, upload_expires_at, accepted_version_id,
                   accepted_etag, processing_attempts, processing_lease_token,
                   processing_lease_expires_at, failure_code, created_at, updated_at
              from course_import
             where id = ? and owner_user_id = ?$suffix
            """.trimIndent(),
            importId,
            ownerUserId,
        )?.let(::toImport) ?: throw NotFoundProblem("Course import was not found.")
    }

    internal fun appendEvent(
        importId: UUID,
        stateVersion: Long,
        eventType: String,
        fromStatus: CourseImportStatus?,
        toStatus: CourseImportStatus,
        actorUserId: UUID?,
        stableCode: String?,
        correlationId: String,
        now: OffsetDateTime,
    ) {
        dsl.execute(
            """
            insert into course_import_event(
                id, import_id, state_version, event_type, from_status, to_status,
                actor_user_id, stable_code, correlation_id, occurred_at
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, cast(? as timestamptz))
            """.trimIndent(),
            UUID.randomUUID(),
            importId,
            stateVersion,
            eventType,
            fromStatus?.name,
            toStatus.name,
            actorUserId,
            stableCode,
            correlationId,
            now,
        )
    }

    private fun toImport(row: Record): StoredCourseImport = StoredCourseImport(
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

    private fun toPreview(row: Record): StoredPreview = StoredPreview(
        importId = row.get("import_id", UUID::class.java)!!,
        quarantineArtifactId = row.get("quarantine_artifact_id", UUID::class.java)!!,
        archiveSourceArtifactId = row.get("archive_source_artifact_id", UUID::class.java)!!,
        reportArtifactId = row.get("report_artifact_id", UUID::class.java)!!,
        cleanScanId = row.get("clean_scan_id", UUID::class.java)!!,
        rulesVersion = row.get("rules_version", String::class.java)!!,
        parserVersion = row.get("parser_version", String::class.java)!!,
        contentSchemaVersion = row.get("content_schema_version", String::class.java),
        summary = CourseImportPreviewSummary(
            isValid = row.get("is_valid", Boolean::class.java)!!,
            rowCount = row.get("row_count", Int::class.java)!!,
            questionCount = row.get("question_count", Int::class.java),
            matchingQuestionCount = row.get("matching_question_count", Int::class.java),
            requiredClientCapabilities = row.get(
                "required_client_capabilities",
                Array<String>::class.java,
            )?.toList(),
            levelCount = row.get("level_count", Int::class.java)!!,
            unitCount = row.get("unit_count", Int::class.java)!!,
            topicCount = row.get("topic_count", Int::class.java)!!,
            testCount = row.get("test_count", Int::class.java)!!,
            warningCount = row.get("warning_count", Int::class.java)!!,
            errorCount = row.get("error_count", Int::class.java)!!,
            validationReportSha256 = row.get("validation_report_sha256", String::class.java)!!,
            allocationSha256 = row.get("allocation_sha256", String::class.java),
            previewSha256 = row.get("preview_sha256", String::class.java),
            settings = row.get("settings_payload", JSONB::class.java)?.let {
                objectMapper.readValue(it.data(), CourseImportPreviewSettings::class.java)
            },
        ),
        approvalBindingSha256 = row.get("approval_binding_sha256", String::class.java),
    )
}

internal fun toCourseImportValidationIssue(row: Record): CourseImportValidationIssue {
    val sheetOrdinal = row.get("source_sheet_ordinal", Int::class.javaObjectType)
    return CourseImportValidationIssue(
        ordinal = row.get("ordinal", Int::class.java)!!,
        severity = row.get("severity", String::class.java)!!,
        code = row.get("issue_code", String::class.java)!!,
        source = sheetOrdinal?.let {
            CourseImportSource(
                sheetOrdinal = it,
                sheetName = row.get("source_sheet_name", String::class.java)!!,
                rowNumber = row.get("source_row_number", Int::class.java)!!,
                columnNumber = row.get("source_column_number", Int::class.javaObjectType),
                reference = row.get("source_reference", String::class.java),
            )
        },
        message = row.get("message", String::class.java)!!,
    )
}

data class NewCourseImport(
    val id: UUID,
    val ownerUserId: UUID,
    val rulesVersion: String,
    val originalFileName: String,
    val declaredMediaType: String,
    val fileSizeBytes: Long,
    val sourceSha256: String,
    val quarantineBucket: String,
    val quarantineObjectKey: String,
    val multipartUploadId: String,
    val uploadExpiresAt: OffsetDateTime,
    val createdAt: OffsetDateTime,
) : RedactedImportModel()

data class ApprovalProvenance(
    val sourceSha256: String,
    val sourceSizeBytes: Long,
    val scannerEngineVersion: String,
    val scannerSignatureVersion: String,
) : RedactedImportModel()

class CourseImportCursorCodec(settings: ImportRuntimeSettings) {
    private val key = checkNotNull(settings.cursorHmacKey) { "Cursor HMAC key is required by the API runtime." }.copyOf()

    fun encode(ownerId: UUID, importId: UUID, previewIdentity: String, scope: String, ordinal: Int): String {
        require(ordinal >= 0 && scope in setOf("preview", "issues"))
        val signature = sign(binding(ownerId, importId, previewIdentity, scope, ordinal))
        return "v1.$ordinal.$signature"
    }

    fun decode(ownerId: UUID, importId: UUID, previewIdentity: String, scope: String, cursor: String?): Int {
        if (cursor == null) return 0
        val parts = cursor.split('.')
        val ordinal = parts.getOrNull(1)?.toIntOrNull()?.takeIf { it >= 0 }
        val supplied = parts.getOrNull(2)
        val expected = ordinal?.let { sign(binding(ownerId, importId, previewIdentity, scope, it)) }
        if (parts.size != 3 || parts[0] != "v1" || supplied == null || expected == null ||
            !MessageDigest.isEqual(
                expected.toByteArray(StandardCharsets.US_ASCII),
                supplied.toByteArray(StandardCharsets.US_ASCII),
            )
        ) {
            throw NotFoundProblem("Course import was not found.")
        }
        return ordinal
    }

    private fun binding(
        ownerId: UUID,
        importId: UUID,
        identity: String,
        scope: String,
        ordinal: Int,
    ): String = listOf("course-import-cursor-v1", scope, ownerId.toString(), importId.toString(), identity, ordinal.toString())
        .joinToString(separator = "") { value -> "${value.toByteArray(StandardCharsets.UTF_8).size}:$value" }

    private fun sign(payload: String): String = Base64.getUrlEncoder().withoutPadding().encodeToString(
        Mac.getInstance("HmacSHA256").run {
            init(SecretKeySpec(key, "HmacSHA256"))
            doFinal(payload.toByteArray(StandardCharsets.US_ASCII))
        },
    )
}
