package com.kelimio.api.rewardedad

import com.fasterxml.jackson.databind.ObjectMapper
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component
import java.net.URLDecoder
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.security.KeyFactory
import java.security.PublicKey
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.Base64

@Component
@ConditionalOnProperty(name = ["KELIMIO_REWARDED_AD_ENABLED"], havingValue = "true")
internal class AdMobSsvVerifier(
    private val settings: RewardedAdSettings,
    private val httpClient: HttpClient,
    private val objectMapper: ObjectMapper,
    private val clock: Clock,
) {
    @Volatile
    private var keys: CachedKeys? = null

    fun verify(rawQuery: String): VerifiedAdMobCallback {
        require(rawQuery.length in 1..8192) { "Invalid SSV query length." }
        val signatureMarker = "&signature="
        val signatureIndex = rawQuery.indexOf(signatureMarker)
        require(signatureIndex > 0) { "SSV signature parameter is missing." }
        val keyMarker = "&key_id="
        val keyIndex = rawQuery.indexOf(keyMarker, signatureIndex + signatureMarker.length)
        require(keyIndex > signatureIndex && rawQuery.indexOf('&', keyIndex + 1) == -1) {
            "SSV signature and key_id must be the final parameters."
        }
        val encodedSignature = rawQuery.substring(signatureIndex + signatureMarker.length, keyIndex)
        val keyId = rawQuery.substring(keyIndex + keyMarker.length).toLongOrNull()
            ?: throw IllegalArgumentException("Invalid SSV key_id.")
        val signedContent = rawQuery.substring(0, signatureIndex).toByteArray(StandardCharsets.UTF_8)
        val publicKey = currentKeys()[keyId] ?: refreshKeys(force = true)[keyId]
            ?: throw IllegalArgumentException("Unknown SSV key_id.")
        val verifier = Signature.getInstance("SHA256withECDSA")
        verifier.initVerify(publicKey)
        verifier.update(signedContent)
        require(verifier.verify(decodeUrlBase64(encodedSignature))) { "Invalid SSV signature." }

        val pairs = rawQuery.substring(0, signatureIndex).split('&').map { part ->
            val separator = part.indexOf('=')
            require(separator > 0) { "Invalid SSV parameter." }
            decode(part.substring(0, separator)) to decode(part.substring(separator + 1))
        }
        require(pairs.map(Pair<String, String>::first).distinct().size == pairs.size) {
            "Duplicate SSV parameters are not accepted."
        }
        val parameters = pairs.toMap()
        val required = setOf(
            "ad_unit", "custom_data", "reward_amount", "reward_item",
            "timestamp", "transaction_id", "user_id",
        )
        require(parameters.keys.containsAll(required)) { "Required SSV parameters are missing." }
        return VerifiedAdMobCallback(
            keyId = keyId,
            adUnitId = parameters.getValue("ad_unit"),
            rewardAmount = parameters.getValue("reward_amount").toIntOrNull()
                ?: throw IllegalArgumentException("Invalid reward amount."),
            rewardItem = parameters.getValue("reward_item"),
            timestampMillis = parameters.getValue("timestamp").toLongOrNull()
                ?: throw IllegalArgumentException("Invalid callback timestamp."),
            transactionId = parameters.getValue("transaction_id").also {
                require(it.length in 1..128) { "Invalid transaction ID." }
            },
            userId = parameters.getValue("user_id").also {
                require(it.length in 1..128) { "Invalid user ID." }
            },
            customData = parameters.getValue("custom_data").also {
                require(it.matches(Regex("^[A-Za-z0-9_-]{32,128}$"))) { "Invalid custom data." }
            },
        )
    }

    private fun currentKeys(): Map<Long, PublicKey> {
        val now = clock.instant()
        return keys?.takeIf { Duration.between(it.loadedAt, now) < CACHE_DURATION }?.values
            ?: refreshKeys(force = false)
    }

    @Synchronized
    private fun refreshKeys(force: Boolean): Map<Long, PublicKey> {
        val now = clock.instant()
        if (!force) {
            keys?.takeIf { Duration.between(it.loadedAt, now) < CACHE_DURATION }?.let { return it.values }
        }
        val request = HttpRequest.newBuilder(settings.keyUrl)
            .timeout(Duration.ofSeconds(10))
            .header("Accept", "application/json")
            .GET()
            .build()
        val response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8))
        require(response.statusCode() == 200) { "AdMob key server was unavailable." }
        val keyNodes = objectMapper.readTree(response.body()).path("keys")
        require(keyNodes.isArray) { "AdMob key response is invalid." }
        val values = linkedMapOf<Long, PublicKey>()
        keyNodes.forEach { node ->
            val keyIdNode = node.path("keyId")
            val base64Node = node.path("base64")
            require(keyIdNode.isIntegralNumber && keyIdNode.longValue() > 0) {
                "AdMob key response contains an invalid key ID."
            }
            require(base64Node.isTextual && base64Node.textValue().isNotBlank()) {
                "AdMob key response contains invalid key material."
            }
            val keyId = keyIdNode.longValue()
            val encoded = Base64.getDecoder().decode(base64Node.textValue())
            val key = KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(encoded))
            require(values.put(keyId, key) == null) { "AdMob key response contains duplicate key IDs." }
        }
        require(values.isNotEmpty()) { "AdMob key server returned no keys." }
        keys = CachedKeys(values, now)
        return values
    }

    private fun decode(value: String): String = URLDecoder.decode(value, StandardCharsets.UTF_8)

    private fun decodeUrlBase64(value: String): ByteArray {
        val padding = "=".repeat((4 - value.length % 4) % 4)
        return Base64.getUrlDecoder().decode(value + padding)
    }

    private data class CachedKeys(val values: Map<Long, PublicKey>, val loadedAt: Instant)

    private companion object {
        val CACHE_DURATION: Duration = Duration.ofHours(12)
    }
}
