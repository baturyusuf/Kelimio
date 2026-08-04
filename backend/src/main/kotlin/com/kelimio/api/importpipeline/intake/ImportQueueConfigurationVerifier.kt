package com.kelimio.api.importpipeline.intake

import com.fasterxml.jackson.databind.ObjectMapper
import jakarta.annotation.PostConstruct
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component
import software.amazon.awssdk.services.sqs.SqsClient
import software.amazon.awssdk.services.sqs.model.GetQueueAttributesRequest
import software.amazon.awssdk.services.sqs.model.GetQueueUrlRequest
import software.amazon.awssdk.services.sqs.model.QueueAttributeName

@Component
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "worker")
class ImportQueueConfigurationVerifier(
    private val sqs: SqsClient,
    private val settings: ImportRuntimeSettings,
    private val objectMapper: ObjectMapper,
) {
    @PostConstruct
    fun verifyQueueSafetyPrerequisites() {
        val queueUrl = queueUrl(settings.queueName)
        val dlqUrl = queueUrl(settings.dlqName)
        check(queueUrl != dlqUrl) { "Import queue and dead-letter queue must be different." }
        val queueAttributes = sqs.getQueueAttributes(
            GetQueueAttributesRequest.builder()
                .queueUrl(queueUrl)
                .attributeNames(QueueAttributeName.VISIBILITY_TIMEOUT, QueueAttributeName.REDRIVE_POLICY)
                .build(),
        ).attributes()
        val dlqArn = sqs.getQueueAttributes(
            GetQueueAttributesRequest.builder()
                .queueUrl(dlqUrl)
                .attributeNames(QueueAttributeName.QUEUE_ARN)
                .build(),
        ).attributes()[QueueAttributeName.QUEUE_ARN]
            ?.takeIf(String::isNotBlank)
            ?: error("Import dead-letter queue ARN is unavailable.")
        val visibility = queueAttributes[QueueAttributeName.VISIBILITY_TIMEOUT]?.toIntOrNull()
        check(visibility != null && visibility >= MINIMUM_VISIBILITY_SECONDS) {
            "Import queue visibility timeout must exceed the worker deadline."
        }
        val redrive = queueAttributes[QueueAttributeName.REDRIVE_POLICY]
            ?.let(objectMapper::readTree)
            ?: error("Import queue redrive policy is unavailable.")
        check(redrive.path("deadLetterTargetArn").asText() == dlqArn) {
            "Import queue redrive target must be the configured dead-letter queue."
        }
        check(redrive.path("maxReceiveCount").asText().toIntOrNull() == 5) {
            "Import queue maxReceiveCount must be exactly five."
        }
    }

    private fun queueUrl(name: String): String = sqs.getQueueUrl(
        GetQueueUrlRequest.builder().queueName(name).build(),
    ).queueUrl()?.takeIf(String::isNotBlank) ?: error("Import queue URL is unavailable.")

    private companion object {
        const val MINIMUM_VISIBILITY_SECONDS = 420
    }
}
