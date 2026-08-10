package com.kelimio.api.importpipeline.intake

import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.S3Configuration
import software.amazon.awssdk.services.s3.presigner.S3Presigner
import software.amazon.awssdk.services.sqs.SqsClient
import java.net.URI
import java.time.Duration
import java.util.Base64

@Configuration
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
class ImportAwsConfiguration {
    @Bean
    @ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
    fun courseImportCursorCodec(settings: ImportRuntimeSettings): CourseImportCursorCodec =
        CourseImportCursorCodec(settings)

    @Bean
    fun importRuntimeSettings(
        @Value("\${KELIMIO_RUNTIME_ROLE:api}") runtimeRole: String,
        @Value("\${AWS_REGION}") awsRegion: String,
        @Value("\${KELIMIO_IMPORT_QUARANTINE_BUCKET}") quarantineBucket: String,
        @Value("\${KELIMIO_IMPORT_ARCHIVE_BUCKET}") archiveBucket: String,
        @Value("\${KELIMIO_IMPORT_QUEUE_NAME}") queueName: String,
        @Value("\${KELIMIO_IMPORT_DLQ_NAME}") dlqName: String,
        @Value("\${KELIMIO_CLAMAV_HOST:clamav}") clamAvHost: String,
        @Value("\${KELIMIO_CLAMAV_PORT:3310}") clamAvPort: Int,
        @Value("\${KELIMIO_ENVIRONMENT}") environment: String,
        @Value("\${KELIMIO_CLAMAV_MIN_ENGINE_VERSION:}") minimumClamAvEngineVersion: String,
        @Value("\${KELIMIO_CLAMAV_MIN_SIGNATURE_NUMBER:}") minimumClamAvSignatureNumber: String,
        @Value("\${KELIMIO_CLAMAV_MAX_DEFINITION_AGE_SECONDS:}") maxDefinitionAgeSeconds: String,
        @Value("\${KELIMIO_CLAMAV_FUTURE_SKEW_SECONDS:}") futureSkewSeconds: String,
        @Value("\${KELIMIO_BUILD_REVISION:}") parserVersion: String,
        @Value("\${KELIMIO_IMPORT_UPLOAD_TTL_SECONDS:900}") uploadTtlSeconds: Long,
        @Value("\${KELIMIO_IMPORT_CURSOR_HMAC_KEY:}") cursorHmacKey: String,
        @Value("\${KELIMIO_PRODUCTION_TEACHER_FEATURES_ENABLED:false}") productionEnabled: Boolean,
    ): ImportRuntimeSettings = ImportRuntimeSettings(
        environment = environment.trim().lowercase().also {
            require(it in setOf("local", "test", "production"))
            require(it != "production" || productionEnabled) {
                "Production course imports require KELIMIO_PRODUCTION_TEACHER_FEATURES_ENABLED=true."
            }
        },
        runtimeRole = ImportRuntimeRole.parse(runtimeRole),
        region = Region.of(awsRegion),
        quarantineBucket = requiredName("KELIMIO_IMPORT_QUARANTINE_BUCKET", quarantineBucket),
        archiveBucket = requiredName("KELIMIO_IMPORT_ARCHIVE_BUCKET", archiveBucket),
        queueName = requiredName("KELIMIO_IMPORT_QUEUE_NAME", queueName),
        dlqName = requiredName("KELIMIO_IMPORT_DLQ_NAME", dlqName),
        clamAvHost = requiredName("KELIMIO_CLAMAV_HOST", clamAvHost),
        clamAvPort = clamAvPort.also { require(it in 1..65535) },
        minimumClamAvEngineVersion = engineVersionPolicy(environment, minimumClamAvEngineVersion),
        minimumClamAvSignatureNumber = policyValue(
            environment,
            "KELIMIO_CLAMAV_MIN_SIGNATURE_NUMBER",
            minimumClamAvSignatureNumber,
            "1",
        ).toLong().also { require(it > 0) },
        maxDefinitionAge = Duration.ofSeconds(
            policyValue(
                environment,
                "KELIMIO_CLAMAV_MAX_DEFINITION_AGE_SECONDS",
                maxDefinitionAgeSeconds,
                "259200",
            ).toLong(),
        ).also { require(it in Duration.ofHours(1)..Duration.ofDays(7)) },
        definitionFutureSkew = Duration.ofSeconds(
            policyValue(
                environment,
                "KELIMIO_CLAMAV_FUTURE_SKEW_SECONDS",
                futureSkewSeconds,
                "86400",
            ).toLong(),
        ).also { require(!it.isNegative && it <= Duration.ofHours(24)) },
        parserVersion = policyValue(
            environment,
            "KELIMIO_BUILD_REVISION",
            parserVersion,
            "local-development",
        ).also { require(it.length <= 160) },
        uploadTtl = Duration.ofSeconds(uploadTtlSeconds).also {
            require(it in Duration.ofMinutes(5)..Duration.ofMinutes(30)) {
                "KELIMIO_IMPORT_UPLOAD_TTL_SECONDS must be between 300 and 1800."
            }
        },
        cursorHmacKey = if (ImportRuntimeRole.parse(runtimeRole) == ImportRuntimeRole.API) {
            decodeKey(cursorHmacKey)
        } else {
            null
        },
    ).also {
        require(it.quarantineBucket != it.archiveBucket) {
            "Import quarantine and archive buckets must be different."
        }
    }

    @Bean(destroyMethod = "close")
    fun importS3Client(
        settings: ImportRuntimeSettings,
        @Value("\${KELIMIO_S3_ENDPOINT:}") endpoint: String,
    ): S3Client = S3Client.builder()
        .region(settings.region)
        .credentialsProvider(DefaultCredentialsProvider.builder().build())
        .httpClientBuilder(UrlConnectionHttpClient.builder())
        .serviceConfiguration(s3Configuration())
        .apply {
            endpoint.takeIf(String::isNotBlank)?.let {
                endpointOverride(validEndpoint("KELIMIO_S3_ENDPOINT", it, publicEndpoint = false))
            }
        }
        .build()

    @Bean(destroyMethod = "close")
    @ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
    fun importS3Presigner(
        settings: ImportRuntimeSettings,
        @Value("\${KELIMIO_S3_PUBLIC_ENDPOINT:}") publicEndpoint: String,
    ): S3Presigner = S3Presigner.builder()
        .region(settings.region)
        .credentialsProvider(DefaultCredentialsProvider.builder().build())
        .serviceConfiguration(s3Configuration())
        .apply {
            publicEndpoint.takeIf(String::isNotBlank)
                ?.let { endpointOverride(validEndpoint("KELIMIO_S3_PUBLIC_ENDPOINT", it, publicEndpoint = true)) }
        }
        .build()

    @Bean(destroyMethod = "close")
    @ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "worker")
    fun importSqsClient(
        settings: ImportRuntimeSettings,
        @Value("\${KELIMIO_SQS_ENDPOINT:}") endpoint: String,
    ): SqsClient = SqsClient.builder()
        .region(settings.region)
        .credentialsProvider(DefaultCredentialsProvider.builder().build())
        .httpClientBuilder(UrlConnectionHttpClient.builder())
        .apply {
            endpoint.takeIf(String::isNotBlank)?.let {
                endpointOverride(validEndpoint("KELIMIO_SQS_ENDPOINT", it, publicEndpoint = false))
            }
        }
        .build()

    private fun s3Configuration(): S3Configuration = S3Configuration.builder()
        .pathStyleAccessEnabled(true)
        .build()

    private fun requiredName(label: String, value: String): String = value.trim().also {
        require(it.isNotEmpty()) { "$label must not be blank." }
    }

    private fun validEndpoint(label: String, value: String, publicEndpoint: Boolean): URI = URI(value).also {
        val allowedHosts = if (publicEndpoint) {
            setOf("localhost", "127.0.0.1", "::1")
        } else {
            setOf("localhost", "127.0.0.1", "::1", "localstack", "host.docker.internal")
        }
        require(
            it.isAbsolute && it.scheme in setOf("http", "https") && it.host?.lowercase() in allowedHosts &&
                it.userInfo == null && it.query == null && it.fragment == null &&
                (it.path.isNullOrEmpty() || it.path == "/"),
        ) {
            "$label must be an approved local/test object-service endpoint."
        }
    }

    private fun decodeKey(value: String): ByteArray = runCatching { Base64.getDecoder().decode(value) }
        .getOrElse { throw IllegalArgumentException("KELIMIO_IMPORT_CURSOR_HMAC_KEY must be valid Base64.") }
        .also { require(it.size == 32) { "KELIMIO_IMPORT_CURSOR_HMAC_KEY must decode to exactly 32 bytes." } }

    private fun policyValue(environment: String, label: String, value: String, localDefault: String): String {
        val normalizedEnvironment = environment.trim().lowercase()
        require(normalizedEnvironment in setOf("local", "test", "staging", "production"))
        if (value.isNotBlank()) return value.trim()
        require(normalizedEnvironment in setOf("local", "test")) {
            "$label must be owner-approved and explicitly configured outside local/test."
        }
        return localDefault
    }

    private fun engineVersionPolicy(environment: String, value: String): String = policyValue(
        environment,
        "KELIMIO_CLAMAV_MIN_ENGINE_VERSION",
        value,
        "1.4.0",
    ).also { version ->
        val components = version.split('.')
        require(components.size in 2..4 && components.all { it.isNotEmpty() && it.all(Char::isDigit) }) {
            "KELIMIO_CLAMAV_MIN_ENGINE_VERSION must be a numeric dotted version."
        }
        require(components.all { it.toIntOrNull() != null }) {
            "KELIMIO_CLAMAV_MIN_ENGINE_VERSION components are too large."
        }
    }
}

class ImportRuntimeSettings(
    val environment: String,
    val runtimeRole: ImportRuntimeRole,
    val region: Region,
    val quarantineBucket: String,
    val archiveBucket: String,
    val queueName: String,
    val dlqName: String,
    val clamAvHost: String,
    val clamAvPort: Int,
    val minimumClamAvEngineVersion: String,
    val minimumClamAvSignatureNumber: Long,
    val maxDefinitionAge: Duration,
    val definitionFutureSkew: Duration,
    val parserVersion: String,
    val uploadTtl: Duration,
    cursorHmacKey: ByteArray?,
) : RedactedImportModel() {
    val cursorHmacKey: ByteArray? = cursorHmacKey?.copyOf()
}

enum class ImportRuntimeRole {
    API,
    WORKER;

    companion object {
        fun parse(value: String): ImportRuntimeRole = when (value.trim().lowercase()) {
            "api" -> API
            "worker" -> WORKER
            else -> throw IllegalArgumentException("KELIMIO_RUNTIME_ROLE must be api or worker.")
        }
    }
}
