package com.kelimio.api.importpipeline.intake

import com.kelimio.api.courseauthoring.InitialAllocationKind
import com.kelimio.api.courseauthoring.InitialAllocationReason
import com.kelimio.api.courseauthoring.InitialCourseDraftCommand
import com.kelimio.api.courseauthoring.InitialCourseDraftCreator
import com.kelimio.api.courseauthoring.InitialCourseDraftRow
import com.kelimio.api.courseauthoring.InitialCourseDraftSettings
import com.kelimio.api.courseauthoring.InitialCourseDraftValidationException
import com.kelimio.api.courseauthoring.InitialCourseVisibility
import com.kelimio.api.courseauthoring.InitialCompositionKind
import com.kelimio.api.courseauthoring.InitialProjectedQuestionType
import com.kelimio.api.courseauthoring.InitialRecordType
import com.kelimio.api.courseauthoring.InitialTestMode
import com.kelimio.api.idempotency.IdempotencyService
import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.outbox.RecordedOutboxEvent
import com.kelimio.api.outbox.TransactionalOutbox
import com.kelimio.api.web.ConflictProblem
import com.kelimio.api.web.ServiceUnavailableProblem
import com.kelimio.api.web.CorrelationIdProvider
import com.kelimio.api.web.UnprocessableProblem
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.ChecksumAlgorithm
import software.amazon.awssdk.services.s3.model.ChecksumMode
import software.amazon.awssdk.services.s3.model.ChecksumType
import software.amazon.awssdk.services.s3.model.CompleteMultipartUploadRequest
import software.amazon.awssdk.services.s3.model.CompletedMultipartUpload
import software.amazon.awssdk.services.s3.model.CompletedPart
import software.amazon.awssdk.services.s3.model.CreateMultipartUploadRequest
import software.amazon.awssdk.services.s3.model.HeadObjectRequest
import software.amazon.awssdk.services.s3.model.HeadObjectResponse
import software.amazon.awssdk.services.s3.model.ListObjectVersionsRequest
import software.amazon.awssdk.services.s3.model.S3Exception
import software.amazon.awssdk.services.s3.model.UploadPartRequest
import software.amazon.awssdk.services.s3.presigner.S3Presigner
import software.amazon.awssdk.services.s3.presigner.model.UploadPartPresignRequest
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.security.MessageDigest
import java.util.Base64
import java.util.UUID

@Service
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
class CourseImportService(
    private val repository: CourseImportRepository,
    private val idempotencyService: IdempotencyService,
    private val s3: S3Client,
    private val presigner: S3Presigner,
    private val settings: ImportRuntimeSettings,
    private val cursorCodec: CourseImportCursorCodec,
    private val correlationIdProvider: CorrelationIdProvider,
    private val outbox: TransactionalOutbox,
    private val initialCourseDraftCreator: InitialCourseDraftCreator,
    private val clock: Clock,
) {
    @Transactional
    fun create(
        user: AppUser,
        idempotencyKey: UUID,
        request: CreateCourseImportRequest,
    ): CourseImportUploadSessionResponse {
        val normalizedRequest = request.copy(
            originalFileName = CourseImportRequestPolicy.normalizeFileName(request.originalFileName),
        )
        CourseImportRequestPolicy.validateCreate(normalizedRequest)
        val fingerprintInput = canonicalCreateRequest(normalizedRequest)
        val lookup = idempotencyService.lockAndFind(
            user.id,
            CREATE_OPERATION,
            idempotencyKey,
            fingerprintInput,
        )
        lookup.resourceId?.let { existingId ->
            val existing = repository.findOwned(user.id, existingId)
            return uploadResponse(existing, created = false)
        }

        val now = now()
        repository.enforceCreationQuota(user.id, now)
        val importId = UUID.randomUUID()
        val objectKey = "quarantine/${user.id}/$importId/source.xlsx"
        val upload = try {
            s3.createMultipartUpload(
                CreateMultipartUploadRequest.builder()
                    .bucket(settings.quarantineBucket)
                    .key(objectKey)
                    .contentType(normalizedRequest.declaredMediaType)
                    .checksumAlgorithm(ChecksumAlgorithm.SHA256)
                    .checksumType(ChecksumType.COMPOSITE)
                    .metadata(
                        mapOf(
                            "kelimio-import-id" to importId.toString(),
                            "kelimio-owner-id" to user.id.toString(),
                            "kelimio-source-sha256" to normalizedRequest.sourceSha256,
                            "kelimio-source-size" to normalizedRequest.fileSizeBytes.toString(),
                        ),
                    )
                    .build()
            )
        } catch (_: S3Exception) {
            throw ServiceUnavailableProblem("The object store is temporarily unavailable.")
        } catch (_: software.amazon.awssdk.core.exception.SdkClientException) {
            throw ServiceUnavailableProblem("The object store is temporarily unavailable.")
        } catch (_: Exception) {
            throw UnprocessableProblem("The multipart upload could not be created.")
        }
        val uploadId = upload.uploadId()?.takeIf(String::isNotBlank)
            ?: throw IllegalStateException("S3 did not return a multipart upload identifier")
        val expiresAt = now.plus(settings.uploadTtl)
        val parts = normalizedRequest.parts.map { CourseImportPart(it.partNumber, it.sizeBytes, it.sha256) }
        try {
            repository.create(
                NewCourseImport(
                id = importId,
                ownerUserId = user.id,
                rulesVersion = CourseImportRequestPolicy.RULES_VERSION,
                originalFileName = normalizedRequest.originalFileName,
                declaredMediaType = normalizedRequest.declaredMediaType,
                fileSizeBytes = normalizedRequest.fileSizeBytes,
                sourceSha256 = normalizedRequest.sourceSha256,
                quarantineBucket = settings.quarantineBucket,
                quarantineObjectKey = objectKey,
                multipartUploadId = uploadId,
                uploadExpiresAt = expiresAt,
                createdAt = now,
                ),
                parts,
                correlationIdProvider.current(),
            )
            idempotencyService.record(user.id, CREATE_OPERATION, idempotencyKey, lookup.fingerprint, importId)
            return uploadResponse(repository.findOwned(user.id, importId), created = true)
        } catch (failure: Exception) {
            runCatching {
                s3.abortMultipartUpload {
                    it.bucket(settings.quarantineBucket).key(objectKey).uploadId(uploadId)
                }
            }
            throw failure
        }
    }

    @Transactional
    fun complete(
        user: AppUser,
        importId: UUID,
        idempotencyKey: UUID,
        request: CompleteCourseImportUploadRequest,
    ): CourseImportCommandResult<CourseImportStatusResponse> {
        val canonical = canonicalCompletionRequest(importId, request)
        val lookup = idempotencyService.lockAndFind(user.id, COMPLETE_OPERATION, idempotencyKey, canonical)
        lookup.resourceId?.let { resourceId ->
            if (resourceId != importId) throw ConflictProblem("The idempotency record is inconsistent.")
            return CourseImportCommandResult(status(user, importId), created = false)
        }
        val current = repository.lockOwned(user.id, importId)
        val expectedParts = repository.parts(current.id)
        CourseImportRequestPolicy.validateCompletion(request, current.assertedSourceSha256, expectedParts)
        if (current.status != CourseImportStatus.UPLOADING) {
            throw ConflictProblem("The course import upload is no longer open.")
        }
        val uploadExpired = current.uploadExpiresAt <= now()

        val completed = request.parts.map {
            CompletedPart.builder()
                .partNumber(it.partNumber)
                .eTag(it.eTag)
                .checksumSHA256(it.sha256)
                .build()
        }
        val expectedChecksum = expectedCompositeChecksum(expectedParts)
        val completion = if (uploadExpired) {
            recoverCompletedVersion(current, expectedChecksum)
        } else {
            completeOrRecover(current, completed, expectedChecksum)
        }
        val acceptedVersion = completion.versionId
        val head = headAccepted(current, acceptedVersion)
        verifyAcceptedHead(current, acceptedVersion, head, expectedChecksum)
        val now = now()
        val correlationId = correlationIdProvider.current()
        repository.markCompleted(
            current = current,
            completedParts = request.parts,
            versionId = acceptedVersion,
            etag = head.eTag()?.takeIf(String::isNotBlank)
                ?: throw IllegalStateException("S3 accepted object has no ETag"),
            checksumSha256 = head.checksumSHA256(),
            completionEvidence = completion.evidence,
            correlationId = correlationId,
            now = now,
        )
        val eventId = UUID.randomUUID()
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "course-import",
                aggregateId = importId,
                eventType = "import.processing-requested.v1",
                schemaVersion = 1,
                payload = mapOf("eventId" to eventId, "importId" to importId),
                correlationId = correlationId,
                occurredAt = now,
            ),
        )
        idempotencyService.record(user.id, COMPLETE_OPERATION, idempotencyKey, lookup.fingerprint, importId)
        return CourseImportCommandResult(status(user, importId), created = true)
    }

    @Transactional(readOnly = true)
    fun status(user: AppUser, importId: UUID): CourseImportStatusResponse =
        toStatus(repository.findOwned(user.id, importId))

    @Transactional(readOnly = true)
    fun preview(user: AppUser, importId: UUID, cursor: String?, limit: Int): CourseImportPreviewPage {
        val current = repository.findOwned(user.id, importId)
        if (current.status !in setOf(
                CourseImportStatus.PREVIEW_READY,
                CourseImportStatus.APPROVED,
                CourseImportStatus.COMMITTED,
            )
        ) {
            throw ConflictProblem("The course import has no valid preview.")
        }
        val previewIdentity = checkNotNull(repository.preview(importId)).summary.previewSha256!!
        val after = cursorCodec.decode(user.id, importId, previewIdentity, "preview", cursor)
        val rows = repository.previewRows(importId, after, limit + 1)
        val visible = rows.take(limit)
        val next = rows.getOrNull(limit)?.let {
            cursorCodec.encode(user.id, importId, previewIdentity, "preview", visible.last().ordinal)
        }
        return CourseImportPreviewPage(visible, next)
    }

    @Transactional(readOnly = true)
    fun issues(user: AppUser, importId: UUID, cursor: String?, limit: Int): CourseImportIssuePage {
        val current = repository.findOwned(user.id, importId)
        if (current.status !in setOf(
                CourseImportStatus.PREVIEW_READY,
                CourseImportStatus.VALIDATION_FAILED,
                CourseImportStatus.APPROVED,
                CourseImportStatus.COMMITTED,
            )
        ) {
            throw ConflictProblem("The course import has no validation report.")
        }
        val previewIdentity = checkNotNull(repository.preview(importId)).summary.validationReportSha256
        val after = cursorCodec.decode(user.id, importId, previewIdentity, "issues", cursor)
        val issues = repository.previewIssues(importId, after, limit + 1)
        val visible = issues.take(limit)
        val next = issues.getOrNull(limit)?.let {
            cursorCodec.encode(user.id, importId, previewIdentity, "issues", visible.last().ordinal)
        }
        return CourseImportIssuePage(visible, next)
    }

    @Transactional
    fun approve(
        user: AppUser,
        importId: UUID,
        idempotencyKey: UUID,
        request: ApproveCourseImportRequest,
    ): CourseImportApprovalResponse {
        CourseImportRequestPolicy.validateApprovalDigest(request.approvalBindingSha256)
        val canonical = "$importId:${request.approvalBindingSha256}"
        val lookup = idempotencyService.lockAndFind(user.id, APPROVE_OPERATION, idempotencyKey, canonical)
        lookup.resourceId?.let { resourceId ->
            if (resourceId != importId) throw ConflictProblem("The idempotency record is inconsistent.")
            repository.findOwned(user.id, importId)
            val existing = repository.approval(importId)
                ?: throw ConflictProblem("The prior approval result is unavailable.")
            return existing.toResponse(created = false)
        }
        val current = repository.lockOwned(user.id, importId)
        repository.approval(importId)?.let { existing ->
            if (existing.approvalBindingSha256 != request.approvalBindingSha256) {
                throw ConflictProblem("The supplied approval binding is stale.")
            }
            idempotencyService.record(user.id, APPROVE_OPERATION, idempotencyKey, lookup.fingerprint, importId)
            return existing.toResponse(created = false)
        }
        if (current.status != CourseImportStatus.PREVIEW_READY) {
            throw ConflictProblem("The course import is not ready for approval.")
        }
        val preview = repository.preview(importId)
            ?.takeIf { it.summary.isValid }
            ?: throw ConflictProblem("The course import has no valid preview.")
        if (preview.approvalBindingSha256 != request.approvalBindingSha256) {
            throw ConflictProblem("The supplied approval binding is stale.")
        }
        val approval = repository.appendApproval(
            current,
            preview,
            repository.approvalProvenance(importId),
            correlationIdProvider.current(),
            now(),
        )
        idempotencyService.record(user.id, APPROVE_OPERATION, idempotencyKey, lookup.fingerprint, importId)
        return approval.toResponse(created = true)
    }

    @Transactional
    fun commit(
        user: AppUser,
        importId: UUID,
        idempotencyKey: UUID,
        request: CommitCourseImportRequest,
    ): CourseImportCommitResponse {
        CourseImportRequestPolicy.validateApprovalDigest(request.approvalBindingSha256)
        val canonical = "$importId:${request.approvalBindingSha256}"
        val lookup = idempotencyService.lockAndFind(user.id, COMMIT_OPERATION, idempotencyKey, canonical)
        lookup.resourceId?.let { resourceId ->
            if (resourceId != importId) throw ConflictProblem("The idempotency record is inconsistent.")
            repository.findOwned(user.id, importId)
            val existing = repository.commit(importId)
                ?: throw ConflictProblem("The prior commit result is unavailable.")
            return existing.toResponse(created = false)
        }

        val current = repository.lockOwned(user.id, importId)
        repository.commit(importId)?.let { existing ->
            if (existing.approvalBindingSha256 != request.approvalBindingSha256) {
                throw ConflictProblem("The supplied approval binding is stale.")
            }
            idempotencyService.record(user.id, COMMIT_OPERATION, idempotencyKey, lookup.fingerprint, importId)
            return existing.toResponse(created = false)
        }
        if (current.status != CourseImportStatus.APPROVED) {
            throw ConflictProblem("The course import is not approved for commit.")
        }
        val approval = repository.approval(importId)
            ?: throw ConflictProblem("The course import approval is unavailable.")
        if (approval.approvalBindingSha256 != request.approvalBindingSha256) {
            throw ConflictProblem("The supplied approval binding is stale.")
        }
        val preview = repository.preview(importId)
            ?.takeIf {
                it.summary.isValid && it.contentSchemaVersion in IMPORT_CONTENT_SCHEMA_VERSIONS &&
                    it.summary.settings != null && it.approvalBindingSha256 == request.approvalBindingSha256
            }
            ?: throw ConflictProblem("The approved preview is not commit-ready.")
        val rows = repository.previewRows(importId, 0, preview.summary.rowCount + 1)
        if (
            rows.size != preview.summary.rowCount ||
            rows.map(CourseImportPreviewRow::ordinal) != (1..preview.summary.rowCount).toList()
        ) {
            throw ConflictProblem("The approved preview is incomplete.")
        }
        val committedAt = now()
        val correlationId = correlationIdProvider.current()
        val draft = try {
            initialCourseDraftCreator.create(
                preview.toDraftCommand(
                    current = current,
                    approval = approval,
                    rows = rows,
                    correlationId = correlationId,
                    committedAt = committedAt,
                ),
            )
        } catch (_: InitialCourseDraftValidationException) {
            throw ConflictProblem("The approved preview is not commit-ready.")
        }
        val eventId = UUID.randomUUID()
        val contentSchemaVersion = checkNotNull(preview.contentSchemaVersion)
        val matchingContent = contentSchemaVersion == IMPORT_CONTENT_V2
        outbox.appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = "course",
                aggregateId = draft.courseId,
                eventType = if (matchingContent) {
                    "course.draft-created-from-import.v2"
                } else {
                    "course.draft-created-from-import.v1"
                },
                schemaVersion = if (matchingContent) 2 else 1,
                payload = if (matchingContent) {
                    mapOf(
                        "eventId" to eventId,
                        "importId" to importId,
                        "courseId" to draft.courseId,
                        "contentChangeSetId" to draft.contentChangeSetId,
                        "draftReleaseId" to draft.draftReleaseId,
                        "sourceRowCount" to draft.sourceRowCount,
                        "questionCount" to draft.questionCount,
                        "matchingQuestionCount" to draft.matchingQuestionCount,
                        "testCount" to draft.testCount,
                        "requiredClientCapabilities" to draft.requiredClientCapabilities,
                    )
                } else {
                    mapOf(
                        "eventId" to eventId,
                        "importId" to importId,
                        "courseId" to draft.courseId,
                        "contentChangeSetId" to draft.contentChangeSetId,
                        "draftReleaseId" to draft.draftReleaseId,
                        "rowCount" to draft.sourceRowCount,
                        "testCount" to draft.testCount,
                    )
                },
                correlationId = correlationId,
                occurredAt = committedAt,
            ),
        )
        val committed = repository.appendCommit(
            current,
            approval,
            preview,
            draft,
            eventId,
            correlationId,
            committedAt,
        )
        idempotencyService.record(user.id, COMMIT_OPERATION, idempotencyKey, lookup.fingerprint, importId)
        return committed.toResponse(created = true)
    }

    private fun uploadResponse(current: StoredCourseImport, created: Boolean): CourseImportUploadSessionResponse {
        val capturedNow = now()
        val signatureDuration = CourseImportPresignPolicy.signatureDuration(
            Duration.between(capturedNow, current.uploadExpiresAt),
        )
        val upload = if (current.status == CourseImportStatus.UPLOADING && signatureDuration != null) {
            presign(current, repository.parts(current.id), signatureDuration)
        } else {
            null
        }
        return CourseImportUploadSessionResponse(created, toStatus(current), upload)
    }

    private fun presign(
        current: StoredCourseImport,
        parts: List<CourseImportPart>,
        signatureDuration: Duration,
    ): CourseImportUploadInstructions {
        val signedPartsWithExpiry = try {
            parts.map { part ->
                val uploadPart = UploadPartRequest.builder()
                    .bucket(current.quarantineBucket)
                    .key(current.quarantineObjectKey)
                    .uploadId(current.multipartUploadId)
                    .partNumber(part.partNumber)
                    .contentLength(part.sizeBytes)
                    .checksumSHA256(part.sha256Base64)
                    .build()
                val signed = presigner.presignUploadPart(
                    UploadPartPresignRequest.builder()
                        .signatureDuration(signatureDuration)
                        .uploadPartRequest(uploadPart)
                        .build(),
                )
                signed.expiration() to CourseImportPresignedPart(
                    partNumber = part.partNumber,
                    sizeBytes = part.sizeBytes,
                    url = signed.url().toExternalForm(),
                    requiredHeaders = CourseImportPartHeaders(
                        contentLength = part.sizeBytes.toString(),
                        sha256 = part.sha256Base64,
                    ),
                )
            }
        } catch (_: software.amazon.awssdk.core.exception.SdkClientException) {
            throw ServiceUnavailableProblem("The object store is temporarily unavailable.")
        }
        if (!CourseImportPresignPolicy.allExpireWithinSession(
                signedPartsWithExpiry.map { it.first },
                current.uploadExpiresAt.toInstant(),
            )
        ) {
            throw ServiceUnavailableProblem("The object store is temporarily unavailable.")
        }
        val earliestExpiry = signedPartsWithExpiry.minOf { it.first }
        return CourseImportUploadInstructions(
            expiresAt = OffsetDateTime.ofInstant(earliestExpiry, ZoneOffset.UTC),
            parts = signedPartsWithExpiry.map { it.second },
        )
    }

    private fun completeOrRecover(
        current: StoredCourseImport,
        completed: List<CompletedPart>,
        expectedChecksum: String,
    ): CourseImportCompletion {
        try {
            val versionId = s3.completeMultipartUpload(
                CompleteMultipartUploadRequest.builder()
                    .bucket(current.quarantineBucket)
                    .key(current.quarantineObjectKey)
                    .uploadId(current.multipartUploadId)
                    .multipartUpload(CompletedMultipartUpload.builder().parts(completed).build())
                    .checksumType(ChecksumType.COMPOSITE)
                    .mpuObjectSize(current.fileSizeBytes)
                    .ifNoneMatch("*")
                    .build(),
            ).versionId()?.takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }
                ?: throw IllegalStateException("S3 completed an import without a VersionId")
            return CourseImportCompletion(versionId, CourseImportCompletionEvidence.S3_VERIFIED)
        } catch (failure: S3Exception) {
            val errorCode = failure.awsErrorDetails()?.errorCode()
            if (failure.statusCode() !in setOf(404, 412) && errorCode !in setOf("NoSuchUpload", "PreconditionFailed")) {
                if (errorCode in COMPLETE_SEMANTIC_ERROR_CODES) {
                    throw UnprocessableProblem("The multipart upload could not be completed.")
                }
                throw ServiceUnavailableProblem("The object store is temporarily unavailable.")
            }
            return recoverCompletedVersion(current, expectedChecksum)
        } catch (_: software.amazon.awssdk.core.exception.SdkClientException) {
            throw ServiceUnavailableProblem("The object store is temporarily unavailable.")
        }
    }

    private fun recoverCompletedVersion(current: StoredCourseImport, expectedChecksum: String): CourseImportCompletion {
        val versions = try {
            s3.listObjectVersionsPaginator(
                ListObjectVersionsRequest.builder()
                    .bucket(current.quarantineBucket)
                    .prefix(current.quarantineObjectKey)
                    .build(),
            ).versions().asSequence()
                .filter {
                    it.key() == current.quarantineObjectKey && !it.versionId().isNullOrBlank() &&
                        !it.versionId().equals("null", ignoreCase = true)
                }
                .take(2)
                .toList()
        } catch (transient: ServiceUnavailableProblem) {
            throw transient
        } catch (_: S3Exception) {
            throw ServiceUnavailableProblem("The object store is temporarily unavailable.")
        } catch (_: software.amazon.awssdk.core.exception.SdkClientException) {
            throw ServiceUnavailableProblem("The object store is temporarily unavailable.")
        } catch (_: Exception) {
            throw ConflictProblem("The multipart upload is incomplete.")
        }
        if (versions.size != 1) {
            throw ConflictProblem("The completed upload version is ambiguous or unavailable.")
        }
        val versionId = versions.single().versionId()
        if (!acceptedHeadMatches(current, versionId, headAccepted(current, versionId), expectedChecksum)) {
            throw ConflictProblem("The completed upload version is ambiguous or unavailable.")
        }
        return CourseImportCompletion(versionId, CourseImportCompletionEvidence.EXACT_OBJECT_RECOVERY)
    }

    private fun headAccepted(current: StoredCourseImport, versionId: String): HeadObjectResponse = try {
        s3.headObject(
            HeadObjectRequest.builder()
                .bucket(current.quarantineBucket)
                .key(current.quarantineObjectKey)
                .versionId(versionId)
                .checksumMode(ChecksumMode.ENABLED)
                .build(),
        )
    } catch (_: S3Exception) {
        throw ServiceUnavailableProblem("The object store is temporarily unavailable.")
    } catch (_: software.amazon.awssdk.core.exception.SdkClientException) {
        throw ServiceUnavailableProblem("The object store is temporarily unavailable.")
    } catch (_: Exception) {
        throw UnprocessableProblem("The completed upload could not be verified.")
    }

    private fun verifyAcceptedHead(
        current: StoredCourseImport,
        expectedVersionId: String,
        head: HeadObjectResponse,
        expectedChecksum: String,
    ) {
        if (!acceptedHeadMatches(current, expectedVersionId, head, expectedChecksum)) {
            throw UnprocessableProblem("The completed upload does not match its import session.")
        }
    }

    private fun acceptedHeadMatches(
        current: StoredCourseImport,
        expectedVersionId: String,
        head: HeadObjectResponse,
        expectedChecksum: String,
    ): Boolean {
        val metadata = head.metadata()
        return head.versionId() == expectedVersionId &&
                head.contentLength() == current.fileSizeBytes &&
                head.contentType() == current.declaredMediaType &&
                head.checksumSHA256() == expectedChecksum &&
                metadata["kelimio-import-id"] == current.id.toString() &&
                metadata["kelimio-owner-id"] == current.ownerUserId.toString() &&
                metadata["kelimio-source-sha256"] == current.assertedSourceSha256 &&
                metadata["kelimio-source-size"] == current.fileSizeBytes.toString()
    }

    private fun expectedCompositeChecksum(parts: List<CourseImportPart>): String {
        val combined = parts.flatMap { Base64.getDecoder().decode(it.sha256Base64).asIterable() }.toByteArray()
        val checksum = Base64.getEncoder().encodeToString(
            MessageDigest.getInstance("SHA-256").digest(combined),
        )
        return "$checksum-${parts.size}"
    }

    private fun toStatus(current: StoredCourseImport): CourseImportStatusResponse {
        val preview = repository.preview(current.id)
        val approval = repository.approval(current.id)
        val commit = repository.commit(current.id)
        return CourseImportStatusResponse(
            id = current.id,
            status = current.status,
            originalFileName = current.originalFileName,
            declaredMediaType = current.declaredMediaType,
            fileSizeBytes = current.fileSizeBytes,
            rulesVersion = current.rulesVersion,
            processingAttempts = current.processingAttempts,
            createdAt = current.createdAt,
            updatedAt = current.updatedAt,
            uploadExpiresAt = current.uploadExpiresAt,
            preview = preview?.summary,
            approvalBindingSha256 = preview?.approvalBindingSha256,
            approvedAt = approval?.approvedAt,
            commit = commit?.toSummary(),
            failureCode = current.failureCode,
        )
    }

    private fun canonicalCreateRequest(request: CreateCourseImportRequest): String = buildString {
        append(request.originalFileName.length).append(':').append(request.originalFileName)
        append('|').append(request.declaredMediaType)
        append('|').append(request.fileSizeBytes)
        append('|').append(request.sourceSha256)
        request.parts.forEach {
            append('|').append(it.partNumber).append(':').append(it.sizeBytes).append(':').append(it.sha256)
        }
    }

    private fun canonicalCompletionRequest(importId: UUID, request: CompleteCourseImportUploadRequest): String =
        buildString {
            append(importId).append('|').append(request.sourceSha256)
            request.parts.forEach {
                append('|').append(it.partNumber).append(':').append(it.eTag.length).append(':').append(it.eTag)
                    .append(':').append(it.sha256)
            }
        }

    private fun now(): OffsetDateTime = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)

    private companion object {
        const val CREATE_OPERATION = "course-import.create"
        const val COMPLETE_OPERATION = "course-import.complete"
        const val APPROVE_OPERATION = "course-import.approve"
        const val COMMIT_OPERATION = "course-import.commit"
        val IMPORT_CONTENT_SCHEMA_VERSIONS = setOf("import-content-v1", "import-content-v2")
        val COMPLETE_SEMANTIC_ERROR_CODES = setOf(
            "BadDigest",
            "EntityTooSmall",
            "InvalidPart",
            "InvalidPartOrder",
        )
    }
}

internal object CourseImportPresignPolicy {
    private val SAFETY_MARGIN = Duration.ofSeconds(5)
    private val MINIMUM_SIGNATURE_DURATION = Duration.ofSeconds(1)
    private val MAXIMUM_SIGNATURE_DURATION = Duration.ofMinutes(15)

    fun signatureDuration(remaining: Duration): Duration? {
        val bounded = remaining.minus(SAFETY_MARGIN)
        if (bounded < MINIMUM_SIGNATURE_DURATION) return null
        return minOf(bounded, MAXIMUM_SIGNATURE_DURATION)
    }

    fun allExpireWithinSession(expirations: List<Instant>, sessionExpiry: Instant): Boolean =
        expirations.isNotEmpty() && expirations.all { !it.isAfter(sessionExpiry) }
}

data class CourseImportCompletion(
    val versionId: String,
    val evidence: CourseImportCompletionEvidence,
)

enum class CourseImportCompletionEvidence {
    S3_VERIFIED,
    EXACT_OBJECT_RECOVERY,
}

data class CourseImportCommandResult<T>(val value: T, val created: Boolean)

private fun StoredApproval.toResponse(created: Boolean) = CourseImportApprovalResponse(
    importId = importId,
    status = CourseImportStatus.APPROVED,
    approvalBindingSha256 = approvalBindingSha256,
    approvedAt = approvedAt,
    created = created,
)

private fun StoredCourseImportCommit.toSummary() = CourseImportCommitSummary(
    courseId = courseId,
    contentChangeSetId = contentChangeSetId,
    draftReleaseId = draftReleaseId,
    sourceRowCount = sourceRowCount,
    questionCount = questionCount,
    matchingQuestionCount = matchingQuestionCount,
    requiredClientCapabilities = requiredClientCapabilities,
    committedAt = committedAt,
)

private fun StoredCourseImportCommit.toResponse(created: Boolean) = CourseImportCommitResponse(
    importId = importId,
    status = CourseImportStatus.COMMITTED,
    courseId = courseId,
    contentChangeSetId = contentChangeSetId,
    draftReleaseId = draftReleaseId,
    sourceRowCount = sourceRowCount,
    questionCount = questionCount,
    matchingQuestionCount = matchingQuestionCount,
    requiredClientCapabilities = requiredClientCapabilities,
    committedAt = committedAt,
    created = created,
)

private fun StoredPreview.toDraftCommand(
    current: StoredCourseImport,
    approval: StoredApproval,
    rows: List<CourseImportPreviewRow>,
    correlationId: String,
    committedAt: OffsetDateTime,
): InitialCourseDraftCommand {
    val approvedSettings = summary.settings ?: throw InitialCourseDraftValidationException()
    val legacyContent = contentSchemaVersion == IMPORT_CONTENT_V1
    if (!legacyContent && contentSchemaVersion != IMPORT_CONTENT_V2) {
        throw InitialCourseDraftValidationException()
    }
    val expectedQuestionCount = summary.questionCount ?: if (legacyContent) {
        summary.rowCount
    } else {
        throw InitialCourseDraftValidationException()
    }
    val expectedMatchingQuestionCount = summary.matchingQuestionCount ?: if (legacyContent) {
        0
    } else {
        throw InitialCourseDraftValidationException()
    }
    val requiredCapabilities = summary.requiredClientCapabilities ?: if (legacyContent) {
        emptyList()
    } else {
        throw InitialCourseDraftValidationException()
    }
    fun <T : Enum<T>> parse(value: String, enumClass: Class<T>): T = runCatching {
        java.lang.Enum.valueOf(enumClass, value)
    }.getOrElse { throw InitialCourseDraftValidationException() }
    return InitialCourseDraftCommand(
        ownerUserId = current.ownerUserId,
        sourceImportId = current.id,
        sourceSha256 = approval.sourceSha256,
        correlationId = correlationId,
        committedAt = committedAt,
        settings = InitialCourseDraftSettings(
            courseName = approvedSettings.courseName,
            targetLanguageCode = approvedSettings.targetLanguageCode,
            targetLanguageName = approvedSettings.targetLanguageName,
            supportLanguageCodes = approvedSettings.supportLanguageCodes,
            defaultSupportLanguageCode = approvedSettings.defaultSupportLanguageCode,
            defaultTestMode = parse(approvedSettings.defaultTestMode, InitialTestMode::class.java),
            visibility = parse(approvedSettings.visibility, InitialCourseVisibility::class.java),
            targetTestSize = approvedSettings.targetTestSize,
            minimumLastAutomaticTestSize = approvedSettings.minimumLastAutomaticTestSize,
            fillFixedTests = approvedSettings.fillFixedTests,
            completionThresholdPercent = approvedSettings.completionThresholdPercent,
            pricingSource = approvedSettings.pricingSource,
            maximumTypedAlternativeAnswers = approvedSettings.maximumTypedAlternativeAnswers,
            offlineMode = approvedSettings.offlineMode,
        ),
        rows = rows.map { row ->
            val projectedType = row.projectedQuestionType ?: if (legacyContent) {
                when (row.recordType) {
                    "WORD" -> "A"
                    "MULTIPLE_CHOICE_CLOZE" -> "B"
                    "TYPED_CLOZE" -> "C"
                    else -> throw InitialCourseDraftValidationException()
                }
            } else {
                throw InitialCourseDraftValidationException()
            }
            InitialCourseDraftRow(
                ordinal = row.ordinal,
                questionOrdinal = row.questionOrdinal ?: if (legacyContent) {
                    row.ordinal
                } else {
                    throw InitialCourseDraftValidationException()
                },
                projectedQuestionType = parse(projectedType, InitialProjectedQuestionType::class.java),
                compositionKind = parse(
                    row.compositionKind ?: if (legacyContent) "ROW" else throw InitialCourseDraftValidationException(),
                    InitialCompositionKind::class.java,
                ),
                groupPosition = row.groupPosition,
                sourceSheetOrdinal = row.source.sheetOrdinal,
                sourceSheetName = row.source.sheetName,
                sourceRowNumber = row.source.rowNumber,
                level = row.level,
                unit = row.unit,
                topic = row.topic,
                testNumber = row.testNumber,
                allocationKind = parse(row.allocationKind, InitialAllocationKind::class.java),
                allocationReason = parse(row.allocationReason, InitialAllocationReason::class.java),
                resolvedMode = parse(row.resolvedMode, InitialTestMode::class.java),
                recordType = parse(row.recordType, InitialRecordType::class.java),
                targetText = row.targetText,
                translations = row.translations,
                sentence = row.sentence,
                correctAnswer = row.correctAnswer,
                alternativeCorrectAnswer = row.alternativeCorrectAnswer,
                wrongAnswers = row.wrongAnswers,
                matchingGroup = row.matchingGroup,
                hidden = row.hidden,
                note = row.note,
            )
        },
        expectedQuestionCount = expectedQuestionCount,
        expectedMatchingQuestionCount = expectedMatchingQuestionCount,
        requiredClientCapabilities = requiredCapabilities,
        expectedLevelCount = summary.levelCount,
        expectedUnitCount = summary.unitCount,
        expectedTopicCount = summary.topicCount,
        expectedTestCount = summary.testCount,
    )
}

private const val IMPORT_CONTENT_V1 = "import-content-v1"
private const val IMPORT_CONTENT_V2 = "import-content-v2"
