package com.kelimio.api.learningsession

import com.kelimio.api.language.LanguageTagNormalizer
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.Base64
import java.util.UUID
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

internal data class MatchingAnswerEdge(
    val targetItemId: UUID,
    val supportItemId: UUID,
) {
    override fun toString(): String = "MatchingAnswerEdge([REDACTED])"
}

internal class MatchingReplayConfigurationException :
    IllegalStateException("Matching replay key configuration is unavailable.")

internal class MatchingReplayEvidence(
    val keyVersion: String,
    val digest: ByteArray,
) {
    override fun toString(): String = "MatchingReplayEvidence([REDACTED])"
}

/** Database-confined keyed replay equality token; not anonymity or full-compromise protection. */
class MatchingAnswerReplayDigest private constructor(
    private val keyRing: MatchingReplayKeyRing,
) {
    internal fun computeActive(
        salt: ByteArray,
        userId: UUID,
        attemptId: UUID,
        submissionId: UUID,
        questionRevisionId: UUID,
        supportLanguage: String,
        edges: Collection<MatchingAnswerEdge>,
        policyVersion: String = POLICY_VERSION,
    ): MatchingReplayEvidence {
        val keyVersion = keyRing.activeVersion
        return MatchingReplayEvidence(
            keyVersion = keyVersion,
            digest = compute(
                keyVersion = keyVersion,
                salt = salt,
                userId = userId,
                attemptId = attemptId,
                submissionId = submissionId,
                questionRevisionId = questionRevisionId,
                supportLanguage = supportLanguage,
                edges = edges,
                policyVersion = policyVersion,
            ),
        )
    }

    internal fun compute(
        keyVersion: String,
        salt: ByteArray,
        userId: UUID,
        attemptId: UUID,
        submissionId: UUID,
        questionRevisionId: UUID,
        supportLanguage: String,
        edges: Collection<MatchingAnswerEdge>,
        policyVersion: String = POLICY_VERSION,
    ): ByteArray {
        require(salt.size == SALT_BYTES) { "Matching replay salt must be 16 bytes" }
        require(policyVersion == POLICY_VERSION) { "Unsupported matching replay policy" }
        require(KEY_VERSION_PATTERN.matches(keyVersion)) { "Invalid matching replay key version" }
        require(CANONICAL_LANGUAGE_TAG.matches(supportLanguage)) {
            "Matching replay requires a canonical support language"
        }

        val canonicalEdges = edges.toList().also { submitted ->
            require(submitted.size in MIN_EDGES..MAX_EDGES) {
                "Matching replay requires two through six edges"
            }
            val targetIds = submitted.map(MatchingAnswerEdge::targetItemId).toSet()
            val supportIds = submitted.map(MatchingAnswerEdge::supportItemId).toSet()
            require(targetIds.size == submitted.size) {
                "Matching replay target identifiers must be unique"
            }
            require(supportIds.size == submitted.size) {
                "Matching replay support identifiers must be unique"
            }
            require(targetIds.intersect(supportIds).isEmpty()) {
                "Matching replay target and support identifiers must be disjoint"
            }
        }.sortedWith { left, right ->
            compareUnsigned(
                left.targetItemId.toRfc4122Bytes(),
                right.targetItemId.toRfc4122Bytes(),
            )
        }

        return Mac.getInstance(HMAC_ALGORITHM).apply {
            init(keyRing.verificationKey(keyVersion))
            updateField(HMAC_DOMAIN)
            updateField(salt)
            updateField(policyVersion.toByteArray(StandardCharsets.US_ASCII))
            updateField(keyVersion.toByteArray(StandardCharsets.US_ASCII))
            updateField(userId.toRfc4122Bytes())
            updateField(attemptId.toRfc4122Bytes())
            updateField(submissionId.toRfc4122Bytes())
            updateField(questionRevisionId.toRfc4122Bytes())
            updateField(supportLanguage.toByteArray(StandardCharsets.UTF_8))
            update(ByteBuffer.allocate(Int.SIZE_BYTES).putInt(canonicalEdges.size).array())
            canonicalEdges.forEach { edge ->
                updateField(edge.targetItemId.toRfc4122Bytes())
                updateField(edge.supportItemId.toRfc4122Bytes())
            }
        }.doFinal()
    }

    override fun toString(): String = "MatchingAnswerReplayDigest([REDACTED])"

    companion object {
        const val POLICY_VERSION = "matching-v1"
        const val SALT_BYTES = 16
        const val DIGEST_BYTES = 32
        const val KEY_BYTES = 32
        const val MIN_EDGES = 2
        const val MAX_EDGES = 6
        internal const val MAX_KEYS = 8
        private const val HMAC_ALGORITHM = "HmacSHA256"
        private const val MAX_SERIALIZED_KEY_RING_CHARS = 1024
        private val HMAC_DOMAIN =
            "kelimio.matching-replay.hmac-sha256-v1".toByteArray(StandardCharsets.US_ASCII)
        private val KEY_VERSION_PATTERN = Regex("^[a-z0-9][a-z0-9._-]{0,31}$")
        private val CANONICAL_LANGUAGE_TAG = Regex(LanguageTagNormalizer.CANONICAL_PATTERN)

        fun fromConfiguration(
            activeVersion: String?,
            serializedKeys: String?,
        ): MatchingAnswerReplayDigest =
            MatchingAnswerReplayDigest(
                MatchingReplayKeyRing.parse(activeVersion, serializedKeys),
            )

        fun matches(expected: ByteArray, actual: ByteArray): Boolean =
            MessageDigest.isEqual(expected, actual)

        private fun Mac.updateField(value: ByteArray) {
            update(ByteBuffer.allocate(Int.SIZE_BYTES).putInt(value.size).array())
            update(value)
        }

        private fun compareUnsigned(left: ByteArray, right: ByteArray): Int {
            val length = minOf(left.size, right.size)
            for (index in 0 until length) {
                val comparison = (left[index].toInt() and 0xff).compareTo(right[index].toInt() and 0xff)
                if (comparison != 0) return comparison
            }
            return left.size.compareTo(right.size)
        }

        private fun UUID.toRfc4122Bytes(): ByteArray =
            ByteBuffer.allocate(Long.SIZE_BYTES * 2)
                .putLong(mostSignificantBits)
                .putLong(leastSignificantBits)
                .array()

        private class MatchingReplayKeyRing private constructor(
            val activeVersion: String,
            private val keysByVersion: Map<String, SecretKeySpec>,
        ) {
            fun verificationKey(version: String): SecretKeySpec =
                keysByVersion[version] ?: throw MatchingReplayConfigurationException()

            override fun toString(): String = "MatchingReplayKeyRing([REDACTED])"

            companion object {
                fun parse(
                    activeVersion: String?,
                    serializedKeys: String?,
                ): MatchingReplayKeyRing {
                    if (
                        activeVersion == null ||
                        !KEY_VERSION_PATTERN.matches(activeVersion) ||
                        serializedKeys.isNullOrEmpty() ||
                        serializedKeys.length > MAX_SERIALIZED_KEY_RING_CHARS
                    ) {
                        throw MatchingReplayConfigurationException()
                    }

                    val entries = serializedKeys.split(',')
                    if (entries.size !in 1..MAX_KEYS) {
                        throw MatchingReplayConfigurationException()
                    }
                    val keys = LinkedHashMap<String, SecretKeySpec>(entries.size)
                    entries.forEach { entry ->
                        val separator = entry.indexOf('=')
                        if (separator <= 0) {
                            throw MatchingReplayConfigurationException()
                        }
                        val version = entry.substring(0, separator)
                        val encodedKey = entry.substring(separator + 1)
                        if (!KEY_VERSION_PATTERN.matches(version) || encodedKey.isEmpty() || keys.containsKey(version)) {
                            throw MatchingReplayConfigurationException()
                        }
                        val decoded = try {
                            Base64.getDecoder().decode(encodedKey)
                        } catch (_: IllegalArgumentException) {
                            throw MatchingReplayConfigurationException()
                        }
                        try {
                            if (decoded.size != KEY_BYTES) {
                                throw MatchingReplayConfigurationException()
                            }
                            keys[version] = SecretKeySpec(decoded, HMAC_ALGORITHM)
                        } finally {
                            decoded.fill(0)
                        }
                    }
                    if (!keys.containsKey(activeVersion)) {
                        throw MatchingReplayConfigurationException()
                    }
                    return MatchingReplayKeyRing(activeVersion, keys.toMap())
                }
            }
        }
    }
}
