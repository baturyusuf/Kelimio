package com.kelimio.api.operations

import org.slf4j.LoggerFactory
import software.amazon.awssdk.services.ssm.SsmClient
import software.amazon.awssdk.services.ssm.model.GetParameterRequest
import java.time.Clock
import java.time.Duration
import java.time.Instant

class SsmOperatingModeProvider(
    private val ssmClient: SsmClient,
    private val parameterName: String,
    private val clock: Clock = Clock.systemUTC(),
    private val refreshInterval: Duration = Duration.ofSeconds(30),
    private val maximumStaleness: Duration = Duration.ofMinutes(5),
) : OperatingModeProvider {
    private val logger = LoggerFactory.getLogger(SsmOperatingModeProvider::class.java)

    @Volatile
    private var snapshot: Snapshot? = null

    init {
        require(parameterName.startsWith("/kelimio/production/")) {
            "KELIMIO_OPERATING_MODE_PARAMETER must be under /kelimio/production/."
        }
        require(!refreshInterval.isNegative && !refreshInterval.isZero) {
            "Operating-mode refresh interval must be positive."
        }
        require(maximumStaleness >= refreshInterval) {
            "Operating-mode maximum staleness must be at least the refresh interval."
        }
    }

    override fun current(): OperatingMode {
        val now = clock.instant()
        snapshot?.takeIf { Duration.between(it.loadedAt, now) < refreshInterval }?.let { return it.mode }
        return refresh(now)
    }

    @Synchronized
    private fun refresh(now: Instant): OperatingMode {
        snapshot?.takeIf { Duration.between(it.loadedAt, now) < refreshInterval }?.let { return it.mode }
        return try {
            val value = ssmClient.getParameter(
                GetParameterRequest.builder().name(parameterName).withDecryption(false).build(),
            ).parameter()?.value() ?: throw IllegalStateException("Operating-mode parameter has no value.")
            OperatingMode.parse(value).also { snapshot = Snapshot(it, now) }
        } catch (exception: RuntimeException) {
            val retained = snapshot?.takeIf { Duration.between(it.loadedAt, now) <= maximumStaleness }
            if (retained != null) {
                logger.warn(
                    "Operating-mode refresh failed; retaining bounded last-known mode exceptionType={}",
                    exception.javaClass.name,
                )
                retained.mode
            } else {
                logger.error(
                    "Operating-mode refresh failed without a fresh snapshot; failing closed exceptionType={}",
                    exception.javaClass.name,
                )
                OperatingMode.SUSPENDED
            }
        }
    }

    private data class Snapshot(
        val mode: OperatingMode,
        val loadedAt: Instant,
    )
}
