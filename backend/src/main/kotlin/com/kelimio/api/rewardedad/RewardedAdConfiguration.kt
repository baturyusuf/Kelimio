package com.kelimio.api.rewardedad

import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import java.net.URI
import java.net.http.HttpClient
import java.time.Duration

@Configuration
@ConditionalOnProperty(name = ["KELIMIO_REWARDED_AD_ENABLED"], havingValue = "true")
internal class RewardedAdConfiguration {
    @Bean
    fun rewardedAdSettings(
        @Value("\${KELIMIO_ENVIRONMENT}") environment: String,
        @Value("\${KELIMIO_ADMOB_REWARDED_AD_UNIT_ID}") adUnitId: String,
        @Value("\${KELIMIO_ADMOB_REWARD_ITEM:energy}") rewardItem: String,
        @Value("\${KELIMIO_ADMOB_REWARD_AMOUNT:1}") rewardAmount: Int,
        @Value("\${KELIMIO_ADMOB_SSV_KEY_URL:https://www.gstatic.com/admob/reward/verifier-keys.json}") keyUrl: String,
        @Value("\${KELIMIO_ADMOB_REWARD_SESSION_TTL_SECONDS:900}") sessionTtlSeconds: Long,
        @Value("\${KELIMIO_ADMOB_CALLBACK_MAX_AGE_SECONDS:3600}") callbackMaxAgeSeconds: Long,
        @Value("\${KELIMIO_ADMOB_MAX_SESSIONS_PER_WINDOW:5}") maxSessionsPerWindow: Int,
        @Value("\${KELIMIO_ADMOB_SESSION_WINDOW_SECONDS:900}") sessionWindowSeconds: Long,
    ): RewardedAdSettings {
        val normalizedEnvironment = environment.trim().lowercase()
        require(normalizedEnvironment in setOf("local", "test", "production"))
        val keyUri = URI(keyUrl)
        require(
            keyUri.scheme == "https" && keyUri.host == "www.gstatic.com" &&
                keyUri.path == "/admob/reward/verifier-keys.json" &&
                keyUri.userInfo == null && keyUri.query == null && keyUri.fragment == null,
        ) { "KELIMIO_ADMOB_SSV_KEY_URL must be the official AdMob verifier-key endpoint." }
        return RewardedAdSettings(
            environment = normalizedEnvironment,
            adUnitId = adUnitId.trim().also { require(it.length in 5..128) },
            rewardItem = rewardItem.trim().also { require(it.length in 1..64) },
            rewardAmount = rewardAmount.also { require(it in 1..20) },
            keyUrl = keyUri,
            sessionTtl = Duration.ofSeconds(sessionTtlSeconds).also {
                require(it in Duration.ofMinutes(5)..Duration.ofHours(1))
            },
            callbackMaxAge = Duration.ofSeconds(callbackMaxAgeSeconds).also {
                require(it in Duration.ofMinutes(5)..Duration.ofHours(24))
            },
            maxSessionsPerWindow = maxSessionsPerWindow.also { require(it in 1..20) },
            sessionWindow = Duration.ofSeconds(sessionWindowSeconds).also {
                require(it in Duration.ofMinutes(5)..Duration.ofHours(24))
            },
        )
    }

    @Bean
    fun rewardedAdHttpClient(): HttpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(5))
        .followRedirects(HttpClient.Redirect.NEVER)
        .build()
}

internal data class RewardedAdSettings(
    val environment: String,
    val adUnitId: String,
    val rewardItem: String,
    val rewardAmount: Int,
    val keyUrl: URI,
    val sessionTtl: Duration,
    val callbackMaxAge: Duration,
    val maxSessionsPerWindow: Int,
    val sessionWindow: Duration,
)
