package com.kelimio.api.config

import com.kelimio.api.learningsession.MatchingAnswerReplayDigest
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.core.env.Environment
import java.time.Clock

@Configuration
class ApplicationConfig {
    @Bean
    fun clock(): Clock = Clock.systemUTC()

    @Bean
    @ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "api", matchIfMissing = true)
    fun matchingAnswerReplayDigest(environment: Environment): MatchingAnswerReplayDigest =
        MatchingAnswerReplayDigest.fromConfiguration(
            activeVersion = environment.getProperty("KELIMIO_MATCHING_REPLAY_ACTIVE_KEY_VERSION"),
            serializedKeys = environment.getProperty("KELIMIO_MATCHING_REPLAY_KEYS"),
        )
}
