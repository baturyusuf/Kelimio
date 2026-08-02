package com.kelimio.api.config

import com.kelimio.api.learningsession.MatchingAnswerReplayDigest
import com.kelimio.api.learningsession.MatchingReplayConfigurationException
import com.kelimio.api.learningsession.LearningSessionController
import com.kelimio.api.learningsession.LearningSessionService
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.boot.test.context.runner.ApplicationContextRunner
import java.util.Base64

class MatchingReplayConfigurationTest {
    private val key = ByteArray(MatchingAnswerReplayDigest.KEY_BYTES) { (it + 1).toByte() }
    private val encodedKey = Base64.getEncoder().encodeToString(key)

    @Test
    fun `worker application slice boots without API replay secrets or learning API beans`() {
        ApplicationContextRunner()
            .withUserConfiguration(
                ApplicationConfig::class.java,
                LearningSessionService::class.java,
                LearningSessionController::class.java,
            )
            .withPropertyValues("KELIMIO_RUNTIME_ROLE=worker")
            .run { context ->
                assertThat(context).hasNotFailed()
                assertThat(context).doesNotHaveBean(MatchingAnswerReplayDigest::class.java)
                assertThat(context).doesNotHaveBean(LearningSessionService::class.java)
                assertThat(context).doesNotHaveBean(LearningSessionController::class.java)
            }
    }

    @Test
    fun `application startup requires valid matching replay configuration`() {
        ApplicationContextRunner()
            .withUserConfiguration(ApplicationConfig::class.java)
            .run { context ->
                assertThat(context).hasFailed()
                assertThat(context.startupFailure)
                    .hasRootCauseInstanceOf(MatchingReplayConfigurationException::class.java)
            }

        ApplicationContextRunner()
            .withUserConfiguration(ApplicationConfig::class.java)
            .withPropertyValues(
                "KELIMIO_MATCHING_REPLAY_ACTIVE_KEY_VERSION=local-v1",
                "KELIMIO_MATCHING_REPLAY_KEYS=local-v1=not-base64!",
            ).run { context ->
                assertThat(context).hasFailed()
                assertThat(context.startupFailure)
                    .hasRootCauseInstanceOf(MatchingReplayConfigurationException::class.java)
                assertThat(context.startupFailure!!.stackTraceToString())
                    .doesNotContain(encodedKey)
                    .doesNotContain("not-base64!")
                    .doesNotContain("local-v1")
            }

        ApplicationContextRunner()
            .withUserConfiguration(ApplicationConfig::class.java)
            .withPropertyValues(
                "KELIMIO_MATCHING_REPLAY_ACTIVE_KEY_VERSION=local-v1",
                "KELIMIO_MATCHING_REPLAY_KEYS=local-v1=$encodedKey",
            ).run { context ->
                assertThat(context).hasNotFailed()
                assertThat(context).hasSingleBean(MatchingAnswerReplayDigest::class.java)
            }
    }

    @Test
    fun `key ring parser rejects noncanonical duplicate missing oversized and malformed entries without disclosure`() {
        val invalidConfigurations = listOf(
            null to "local-v1=$encodedKey",
            "" to "local-v1=$encodedKey",
            "Local-v1" to "Local-v1=$encodedKey",
            "local-v1" to null,
            "local-v1" to "",
            "local-v1" to "broken-entry",
            "local-v1" to "local-v1=",
            "local-v1" to "local-v1=not-base64!",
            "local-v1" to "local-v1=${Base64.getEncoder().encodeToString(ByteArray(31))}",
            "local-v1" to "local-v1=${Base64.getEncoder().encodeToString(ByteArray(33))}",
            "local-v1" to "local-v1=$encodedKey,local-v1=$encodedKey",
            "local-v2" to "local-v1=$encodedKey",
            "local-v1" to (1..(MatchingAnswerReplayDigest.MAX_KEYS + 1)).joinToString(",") {
                "key-v$it=$encodedKey"
            },
            "local-v1" to "local-v1=${"A".repeat(1025)}",
        )

        invalidConfigurations.forEach { (activeVersion, serializedKeys) ->
            assertThatThrownBy {
                MatchingAnswerReplayDigest.fromConfiguration(activeVersion, serializedKeys)
            }.isInstanceOf(MatchingReplayConfigurationException::class.java)
                .hasMessage("Matching replay key configuration is unavailable.")
                .hasMessageNotContaining(encodedKey)
                .hasMessageNotContaining("local-v1")
        }
    }
}
