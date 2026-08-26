package com.kelimio.api.importpipeline.intake

import com.fasterxml.jackson.databind.ObjectMapper
import org.slf4j.LoggerFactory
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import software.amazon.awssdk.services.sqs.SqsClient
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest
import software.amazon.awssdk.services.sqs.model.GetQueueUrlRequest
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest
import software.amazon.awssdk.services.sqs.model.SendMessageRequest
import java.time.Clock
import java.time.Duration
import java.time.OffsetDateTime
import java.time.ZoneOffset

@Component
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
class ImportOutboxPublisher(
    private val repository: CourseImportWorkerRepository,
    private val processor: ImportOutboxPublicationProcessor,
) {
    @Scheduled(fixedDelayString = "\${KELIMIO_IMPORT_OUTBOX_POLL_MS:500}")
    fun publishBatch() {
        repository.unpublishedOutbox(20).forEach { processor.publish(it.eventId) }
    }
}

@Service
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
class ImportOutboxPublicationProcessor(
    private val repository: CourseImportWorkerRepository,
    private val sqs: SqsClient,
    private val settings: ImportRuntimeSettings,
    private val clock: Clock,
) {
    private val queueUrl: String by lazy {
        sqs.getQueueUrl(GetQueueUrlRequest.builder().queueName(settings.queueName).build()).queueUrl()
    }

    @Transactional
    fun publish(eventId: java.util.UUID) {
        val event = repository.lockOutbox(eventId) ?: return
        try {
            val body = "{\"schemaVersion\":1,\"eventId\":\"${event.eventId}\",\"importId\":\"${event.importId}\"}"
            sqs.sendMessage(SendMessageRequest.builder().queueUrl(queueUrl).messageBody(body).build())
            repository.markOutboxPublished(event.eventId, now())
        } catch (_: Exception) {
            repository.recordOutboxFailure(event.eventId, "sqs-publish-failed")
        }
    }

    private fun now(): OffsetDateTime = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
}

@Component
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "worker")
class ImportQueueWorker(
    private val repository: CourseImportWorkerRepository,
    private val coordinator: CourseImportProcessingCoordinator,
    private val sqs: SqsClient,
    private val settings: ImportRuntimeSettings,
    private val objectMapper: ObjectMapper,
    private val clock: Clock,
) {
    private val logger = LoggerFactory.getLogger(ImportQueueWorker::class.java)
    private val queueUrl: String by lazy {
        sqs.getQueueUrl(GetQueueUrlRequest.builder().queueName(settings.queueName).build()).queueUrl()
    }
    private val dlqUrl: String by lazy {
        sqs.getQueueUrl(GetQueueUrlRequest.builder().queueName(settings.dlqName).build()).queueUrl()
    }

    @Scheduled(fixedDelayString = "\${KELIMIO_IMPORT_QUEUE_POLL_MS:500}")
    fun pollOnce() {
        val messages = try {
            sqs.receiveMessage(
                ReceiveMessageRequest.builder()
                    .queueUrl(queueUrl)
                    .maxNumberOfMessages(1)
                    .waitTimeSeconds(1)
                    .visibilityTimeout(IMPORT_VISIBILITY_SECONDS)
                    .build(),
            ).messages()
        } catch (failure: Exception) {
            logger.warn("Course import queue poll failed exceptionType={}", failure.javaClass.name)
            return
        }
        messages.forEach { message ->
            val command = parseCommand(message.body()) ?: return@forEach
            if (!repository.validateCommand(command)) return@forEach
            val result = coordinator.process(command)
            val terminalReady = if (repository.needsDeadLetter(command.importId)) {
                handoffDeadLetter(command)
            } else {
                result == ImportProcessingResult.COMPLETE
            }
            if (terminalReady) {
                runCatching {
                    sqs.deleteMessage(
                        DeleteMessageRequest.builder().queueUrl(queueUrl).receiptHandle(message.receiptHandle()).build(),
                    )
                }.onFailure { failure ->
                    logger.warn("Course import queue delete failed exceptionType={}", failure.javaClass.name)
                }
            }
        }
    }

    private fun handoffDeadLetter(command: ImportQueueCommand): Boolean = runCatching {
        val body = "{\"schemaVersion\":1,\"eventId\":\"${command.eventId}\",\"importId\":\"${command.importId}\"}"
        val sent = sqs.sendMessage(SendMessageRequest.builder().queueUrl(dlqUrl).messageBody(body).build())
        val messageId = sent.messageId()?.takeIf(String::isNotBlank) ?: return false
        repository.recordDeadLetter(
            command,
            messageId,
            OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC),
        )
        true
    }.getOrDefault(false)

    private fun parseCommand(body: String): ImportQueueCommand? = runCatching {
        val tree = objectMapper.readTree(body)
        require(tree.isObject && tree.fieldNames().asSequence().toSet() == COMMAND_FIELDS)
        ImportQueueCommand(
            schemaVersion = tree.required("schemaVersion").intValue(),
            eventId = java.util.UUID.fromString(tree.required("eventId").textValue()),
            importId = java.util.UUID.fromString(tree.required("importId").textValue()),
        )
    }.getOrNull()

    private companion object {
        const val IMPORT_VISIBILITY_SECONDS = 480
        val COMMAND_FIELDS = setOf("schemaVersion", "eventId", "importId")
    }
}

@Service
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "worker")
class CourseImportProcessingCoordinator(
    private val repository: CourseImportWorkerRepository,
    private val storage: ImportObjectStorage,
    private val scanner: ClamAvImportScanner,
    private val materializer: ImportPreviewMaterializer,
    private val settings: ImportRuntimeSettings,
    private val clock: Clock,
) {
    fun process(command: ImportQueueCommand): ImportProcessingResult {
        val started = clock.instant()
        val deadline = started.plus(WORKER_DEADLINE)
        val claim = when (
            val result = repository.claim(
                command.importId,
                now(),
                OffsetDateTime.ofInstant(started.plus(PROCESSING_LEASE), ZoneOffset.UTC),
                "import-worker-${command.eventId}",
            )
        ) {
            is ProcessingClaimResult.Claimed -> result.claim
            ProcessingClaimResult.Complete, ProcessingClaimResult.Missing -> return ImportProcessingResult.COMPLETE
            ProcessingClaimResult.Busy -> return ImportProcessingResult.RETRY
        }
        try {
            storage.downloadQuarantine(claim, deadline).use { quarantine ->
                val quarantineArtifact = repository.recordArtifact(
                    claim,
                    NewImportArtifact(
                        kind = ImportArtifactKind.QUARANTINE_SOURCE,
                        bucket = claim.acceptedBucket,
                        key = claim.acceptedObjectKey,
                        versionId = claim.acceptedVersionId,
                        etag = claim.acceptedEtag,
                        sha256 = quarantine.sha256,
                        sizeBytes = quarantine.sizeBytes,
                        mediaType = claim.declaredMediaType,
                        createdAt = now(),
                    ),
                )
                val cleanScan = cleanScan(claim, quarantineArtifact, quarantine, deadline)
                    ?: return ImportProcessingResult.COMPLETE
                val archiveArtifact = repository.artifact(claim.importId, ImportArtifactKind.ARCHIVE_SOURCE)
                    ?: repository.recordArtifact(
                        claim,
                        storage.archiveSource(claim, quarantine, now(), deadline),
                    )
                storage.downloadArchive(claim, archiveArtifact, deadline).use { verifiedArchive ->
                    val materialized = materializer.materialize(claim, verifiedArchive.path, deadline)
                    val reportSha256 = materialized.summary.validationReportSha256
                    val reportArtifact = repository.artifact(claim.importId, ImportArtifactKind.VALIDATION_REPORT)
                        ?: repository.recordArtifact(
                            claim,
                            storage.archiveValidationReport(
                                claim,
                                materialized.reportBytes,
                                reportSha256,
                                now(),
                                deadline,
                            ),
                        )
                    val binding = if (materialized.summary.isValid) {
                        CanonicalImportApprovalBinding.sha256(
                            ImportApprovalBindingInput(
                                importId = claim.importId,
                                ownerUserId = claim.ownerUserId,
                                quarantine = quarantineArtifact,
                                archiveSource = archiveArtifact,
                                validationReport = reportArtifact,
                                cleanScan = cleanScan,
                                rulesVersion = claim.rulesVersion,
                                parserVersion = settings.parserVersion,
                                allocationSha256 = checkNotNull(materialized.summary.allocationSha256),
                                previewSha256 = checkNotNull(materialized.summary.previewSha256),
                                validationReportSha256 = reportSha256,
                            ),
                        )
                    } else {
                        null
                    }
                    repository.finishPreview(
                        claim,
                        cleanScan,
                        quarantineArtifact,
                        archiveArtifact,
                        reportArtifact,
                        PersistedImportPreview(
                            rulesVersion = claim.rulesVersion,
                            parserVersion = settings.parserVersion,
                            contentSchemaVersion = if (materialized.summary.isValid) {
                                contentSchemaVersion(claim.rulesVersion)
                            } else {
                                null
                            },
                            summary = materialized.summary,
                            approvalBindingSha256 = binding,
                            rows = materialized.rows,
                            issues = materialized.issues,
                        ),
                        now(),
                        OffsetDateTime.ofInstant(deadline, ZoneOffset.UTC),
                    )
                }
            }
            return ImportProcessingResult.COMPLETE
        } catch (_: ImportRetryScheduledException) {
            return ImportProcessingResult.RETRY
        } catch (failure: ImportMaterializationException) {
            return finishFailure(claim, failure.stableCode, failure.retryable)
        } catch (failure: ImportStorageException) {
            return finishFailure(claim, failure.stableCode, failure.retryable)
        } catch (_: Exception) {
            return finishFailure(claim, "worker-unexpected-failure", true)
        }
    }

    private fun cleanScan(
        claim: ProcessingClaim,
        artifact: StoredImportArtifact,
        quarantine: DownloadedImportObject,
        deadline: java.time.Instant,
    ): StoredImportScan? {
        repository.findCleanScan(claim.importId)?.let { return it }
        repository.findMalwareScan(claim.importId)?.let {
            repository.finishMalware(claim, "malware-detected", now())
            return null
        }
        val scannedAt = now()
        return try {
            when (val result = scanner.scan(quarantine.path, deadline)) {
                is ClamAvScanResult.Clean -> repository.recordScan(
                    claim,
                    artifact,
                    NewImportScan(
                        ImportScanVerdict.CLEAN,
                        null,
                        quarantine.sha256,
                        quarantine.sizeBytes,
                        result.identity.engineVersion,
                        result.identity.signatureVersion,
                        scannedAt,
                    ),
                )
                is ClamAvScanResult.Malware -> {
                    repository.recordScan(
                        claim,
                        artifact,
                        NewImportScan(
                            ImportScanVerdict.MALWARE,
                            "malware-detected",
                            quarantine.sha256,
                            quarantine.sizeBytes,
                            result.identity.engineVersion,
                            result.identity.signatureVersion,
                            scannedAt,
                        ),
                    )
                    repository.finishMalware(claim, "malware-detected", now())
                    null
                }
            }
        } catch (failure: ClamAvUnavailableException) {
            repository.recordScan(
                claim,
                artifact,
                NewImportScan(
                    ImportScanVerdict.ERROR,
                    failure.stableCode,
                    quarantine.sha256,
                    quarantine.sizeBytes,
                    null,
                    null,
                    scannedAt,
                ),
            )
            val retry = repository.finishFailure(claim, failure.stableCode, true, now())
            if (retry) throw ImportRetryScheduledException()
            null
        }
    }

    private fun finishFailure(claim: ProcessingClaim, code: String, retryable: Boolean): ImportProcessingResult =
        if (repository.finishFailure(claim, code, retryable, now())) {
            ImportProcessingResult.RETRY
        } else {
            ImportProcessingResult.COMPLETE
        }

    private fun now(): OffsetDateTime = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)

    private fun contentSchemaVersion(rulesVersion: String): String = when (rulesVersion) {
        "xlsx-v1" -> "import-content-v1"
        "xlsx-v2" -> "import-content-v2"
        else -> throw ImportMaterializationException("unsupported-rules-version", retryable = false)
    }

    private companion object {
        val WORKER_DEADLINE: Duration = Duration.ofMinutes(6)
        val PROCESSING_LEASE: Duration = Duration.ofMinutes(7)
    }
}

enum class ImportProcessingResult {
    COMPLETE,
    RETRY,
}

private class ImportRetryScheduledException : RuntimeException()
