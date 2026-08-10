package com.kelimio.api.rewardedad

import com.fasterxml.jackson.databind.ObjectMapper
import com.sun.net.httpserver.HttpServer
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.net.InetSocketAddress
import java.net.URI
import java.net.URLEncoder
import java.net.http.HttpClient
import java.nio.charset.StandardCharsets
import java.security.KeyPairGenerator
import java.security.Signature
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset
import java.util.Base64

class AdMobSsvVerifierTest {
    @Test
    fun `verifies callback against fetched rotating public key`() {
        val keyPair = KeyPairGenerator.getInstance("EC").apply { initialize(256) }.generateKeyPair()
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/keys") { exchange ->
            val body = ObjectMapper().writeValueAsBytes(
                mapOf(
                    "keys" to listOf(
                        mapOf(
                            "keyId" to 42,
                            "base64" to Base64.getEncoder().encodeToString(keyPair.public.encoded),
                        ),
                    ),
                ),
            )
            exchange.sendResponseHeaders(200, body.size.toLong())
            exchange.responseBody.use { it.write(body) }
        }
        server.start()
        try {
            val verifier = AdMobSsvVerifier(
                settings = settings(URI("http://127.0.0.1:${server.address.port}/keys")),
                httpClient = HttpClient.newHttpClient(),
                objectMapper = ObjectMapper(),
                clock = Clock.fixed(Instant.parse("2026-08-10T08:00:00Z"), ZoneOffset.UTC),
            )
            val signed = listOf(
                "ad_unit" to "ca-app-pub-test/reward",
                "custom_data" to "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef1234567890_-",
                "reward_amount" to "1",
                "reward_item" to "energy",
                "timestamp" to "1786348800000",
                "transaction_id" to "transaction-1",
                "user_id" to "11111111-1111-1111-1111-111111111111",
            ).joinToString("&") { (name, value) -> "$name=${encode(value)}" }
            val signer = Signature.getInstance("SHA256withECDSA")
            signer.initSign(keyPair.private)
            signer.update(signed.toByteArray(StandardCharsets.UTF_8))
            val signature = Base64.getUrlEncoder().withoutPadding().encodeToString(signer.sign())

            val result = verifier.verify("$signed&signature=$signature&key_id=42")

            assertThat(result.transactionId).isEqualTo("transaction-1")
            assertThat(result.rewardAmount).isEqualTo(1)
            assertThat(result.keyId).isEqualTo(42)
        } finally {
            server.stop(0)
        }
    }

    @Test
    fun `rejects altered signed content`() {
        val verifier = AdMobSsvVerifier(
            settings = settings(URI("https://example.invalid/keys")),
            httpClient = HttpClient.newHttpClient(),
            objectMapper = ObjectMapper(),
            clock = Clock.systemUTC(),
        )

        assertThatThrownBy {
            verifier.verify("reward_amount=2&key_id=42")
        }.isInstanceOf(IllegalArgumentException::class.java)
    }

    private fun settings(keyUrl: URI) = RewardedAdSettings(
        environment = "test",
        adUnitId = "ca-app-pub-test/reward",
        rewardItem = "energy",
        rewardAmount = 1,
        keyUrl = keyUrl,
        sessionTtl = Duration.ofMinutes(15),
        callbackMaxAge = Duration.ofHours(1),
        maxSessionsPerWindow = 5,
        sessionWindow = Duration.ofMinutes(15),
    )

    private fun encode(value: String): String = URLEncoder.encode(value, StandardCharsets.UTF_8)
}
