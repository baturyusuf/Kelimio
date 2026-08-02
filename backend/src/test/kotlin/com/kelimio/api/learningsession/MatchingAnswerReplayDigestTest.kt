package com.kelimio.api.learningsession

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.util.Base64
import java.util.UUID

class MatchingAnswerReplayDigestTest {
    private val salt = ByteArray(MatchingAnswerReplayDigest.SALT_BYTES) { it.toByte() }
    private val primaryKey = ByteArray(MatchingAnswerReplayDigest.KEY_BYTES) { (it + 1).toByte() }
    private val secondaryKey = ByteArray(MatchingAnswerReplayDigest.KEY_BYTES) { (it + 33).toByte() }
    private val digest = configuredDigest("test-v1", mapOf("test-v1" to primaryKey))
    private val userId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val attemptId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val submissionId = uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc")
    private val questionRevisionId = uuid("dddddddd-dddd-4ddd-8ddd-dddddddddddd")
    private val edges = listOf(
        edge(
            "00000000-0000-4000-8000-000000000001",
            "11111111-1111-4111-8111-111111111111",
        ),
        edge(
            "7fffffff-ffff-4fff-bfff-fffffffffff2",
            "22222222-2222-4222-8222-222222222222",
        ),
        edge(
            "80000000-0000-4000-8000-000000000003",
            "33333333-3333-4333-8333-333333333333",
        ),
        edge(
            "ffffffff-ffff-4fff-bfff-fffffffffff4",
            "44444444-4444-4444-8444-444444444444",
        ),
    )

    @Test
    fun `matching-v1 HMAC matches the fixed framed unsigned UUID vector`() {
        val actual = compute(edges.reversed())

        assertThat(actual).hasSize(MatchingAnswerReplayDigest.DIGEST_BYTES)
        assertThat(actual.hex())
            .isEqualTo("732335f1b9957a8b8a7a7abd354b60861831a7dcb9d4cea8378f834fc1967bac")
        assertThat(compute(listOf(edges[2], edges[0], edges[3], edges[1])))
            .isEqualTo(actual)
    }

    @Test
    fun `HMAC binds external key key version salt command identities language and every edge`() {
        val base = compute(edges)
        val differentKey = configuredDigest("test-v1", mapOf("test-v1" to secondaryKey))
        val differentVersion = configuredDigest("test-v2", mapOf("test-v2" to primaryKey))

        assertThat(compute(edges, digest = differentKey)).isNotEqualTo(base)
        assertThat(compute(edges, digest = differentVersion, keyVersion = "test-v2")).isNotEqualTo(base)
        assertThat(compute(edges, salt = salt.copyOf().also { it[0] = 1 })).isNotEqualTo(base)
        assertThat(compute(edges, userId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaab")))
            .isNotEqualTo(base)
        assertThat(compute(edges, attemptId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbc")))
            .isNotEqualTo(base)
        assertThat(compute(edges, submissionId = uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccd")))
            .isNotEqualTo(base)
        assertThat(
            compute(
                edges,
                questionRevisionId = uuid("dddddddd-dddd-4ddd-8ddd-ddddddddddde"),
            ),
        ).isNotEqualTo(base)
        assertThat(compute(edges, supportLanguage = "tr")).isNotEqualTo(base)
        assertThat(
            compute(
                edges.toMutableList().also {
                    it[2] = MatchingAnswerEdge(
                        it[2].targetItemId,
                        uuid("55555555-5555-4555-8555-555555555555"),
                    )
                },
            ),
        ).isNotEqualTo(base)

        assertThatThrownBy {
            compute(edges, policyVersion = "matching-v2")
        }.isInstanceOf(IllegalArgumentException::class.java)
    }

    @Test
    fun `rotation verifies retained historical keys and missing keys fail as configuration errors`() {
        val rotating = configuredDigest(
            "test-v2",
            mapOf("test-v1" to primaryKey, "test-v2" to secondaryKey),
        )
        val historical = compute(edges)

        assertThat(compute(edges, digest = rotating, keyVersion = "test-v1"))
            .isEqualTo(historical)
        assertThat(
            rotating.computeActive(
                salt,
                userId,
                attemptId,
                submissionId,
                questionRevisionId,
                "en",
                edges,
            ).keyVersion,
        ).isEqualTo("test-v2")
        assertThatThrownBy {
            compute(
                edges,
                digest = configuredDigest("test-v2", mapOf("test-v2" to secondaryKey)),
                keyVersion = "test-v1",
            )
        }.isInstanceOf(MatchingReplayConfigurationException::class.java)
            .hasMessage("Matching replay key configuration is unavailable.")
    }

    @Test
    fun `constant-time equality primitive accepts equal digests and rejects differences`() {
        val expected = compute(edges)
        val changed = expected.copyOf().also { it[it.lastIndex] = (it.last() + 1).toByte() }

        assertThat(MatchingAnswerReplayDigest.matches(expected, expected.copyOf())).isTrue()
        assertThat(MatchingAnswerReplayDigest.matches(expected, changed)).isFalse()
        assertThat(MatchingAnswerReplayDigest.matches(expected, expected.copyOf(expected.size - 1))).isFalse()
    }

    @Test
    fun `HMAC rejects non-bijections overlapping sides invalid bounds and invalid framing inputs`() {
        assertThatThrownBy { compute(edges.take(1)) }
            .isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy {
            compute(
                (1..7).map { index ->
                    edge(
                        "10000000-0000-4000-8000-${index.toString().padStart(12, '0')}",
                        "20000000-0000-4000-8000-${index.toString().padStart(12, '0')}",
                    )
                },
            )
        }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy { compute(edges + edges.first()) }
            .isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy {
            compute(edges.toMutableList().also { it[1] = MatchingAnswerEdge(it[1].targetItemId, it[0].supportItemId) })
        }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy {
            compute(
                edges.toMutableList().also {
                    it[1] = MatchingAnswerEdge(it[1].targetItemId, edges[0].targetItemId)
                },
            )
        }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy { compute(edges, salt = ByteArray(15)) }
            .isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy { compute(edges, supportLanguage = "EN") }
            .isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy { compute(edges, keyVersion = "TEST-V1") }
            .isInstanceOf(IllegalArgumentException::class.java)
    }

    @Test
    fun `matching replay diagnostics redact keys versions digests and item identifiers`() {
        val edge = edges.first()
        val evidence = digest.computeActive(
            salt,
            userId,
            attemptId,
            submissionId,
            questionRevisionId,
            "en",
            edges,
        )
        val encodedKey = Base64.getEncoder().encodeToString(primaryKey)

        assertThat(edge.toString())
            .doesNotContain(edge.targetItemId.toString())
            .doesNotContain(edge.supportItemId.toString())
            .contains("[REDACTED]")
        assertThat(evidence.toString())
            .doesNotContain(evidence.keyVersion)
            .doesNotContain(evidence.digest.hex())
            .contains("[REDACTED]")
        assertThat(digest.toString())
            .doesNotContain("test-v1")
            .doesNotContain(encodedKey)
            .contains("[REDACTED]")
    }

    private fun compute(
        submitted: Collection<MatchingAnswerEdge>,
        digest: MatchingAnswerReplayDigest = this.digest,
        keyVersion: String = "test-v1",
        salt: ByteArray = this.salt,
        userId: UUID = this.userId,
        attemptId: UUID = this.attemptId,
        submissionId: UUID = this.submissionId,
        questionRevisionId: UUID = this.questionRevisionId,
        supportLanguage: String = "en",
        policyVersion: String = MatchingAnswerReplayDigest.POLICY_VERSION,
    ): ByteArray = digest.compute(
        keyVersion = keyVersion,
        salt = salt,
        userId = userId,
        attemptId = attemptId,
        submissionId = submissionId,
        questionRevisionId = questionRevisionId,
        supportLanguage = supportLanguage,
        edges = submitted,
        policyVersion = policyVersion,
    )

    private fun configuredDigest(
        activeVersion: String,
        keys: Map<String, ByteArray>,
    ): MatchingAnswerReplayDigest =
        MatchingAnswerReplayDigest.fromConfiguration(
            activeVersion,
            keys.entries.joinToString(",") { (version, key) ->
                "$version=${Base64.getEncoder().encodeToString(key)}"
            },
        )

    private fun edge(target: String, support: String): MatchingAnswerEdge =
        MatchingAnswerEdge(uuid(target), uuid(support))

    private fun uuid(value: String): UUID = UUID.fromString(value)

    private fun ByteArray.hex(): String = joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
}
