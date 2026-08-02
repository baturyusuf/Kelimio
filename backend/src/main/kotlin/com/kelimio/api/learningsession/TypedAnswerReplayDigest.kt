package com.kelimio.api.learningsession

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.UUID

internal object TypedAnswerReplayDigest {
    const val SALT_BYTES = 16
    const val DIGEST_BYTES = 32
    private const val FORMAT_VERSION = "kelimio-typed-answer-replay-v1"

    fun compute(
        salt: ByteArray,
        attemptId: UUID,
        submissionId: UUID,
        questionRevisionId: UUID,
        policyVersion: String,
        canonicalAnswer: String,
    ): ByteArray {
        require(salt.size == SALT_BYTES) { "Typed-answer replay salt must be 16 bytes" }
        val payload = ByteArrayOutputStream().use { bytes ->
            DataOutputStream(bytes).use { output ->
                output.writeLengthPrefixed(FORMAT_VERSION)
                output.writeLengthPrefixed(salt)
                output.writeLengthPrefixed(attemptId.toBytes())
                output.writeLengthPrefixed(submissionId.toBytes())
                output.writeLengthPrefixed(questionRevisionId.toBytes())
                output.writeLengthPrefixed(policyVersion)
                output.writeLengthPrefixed(canonicalAnswer)
            }
            bytes.toByteArray()
        }
        return MessageDigest.getInstance("SHA-256").digest(payload)
    }

    fun matches(expected: ByteArray, actual: ByteArray): Boolean = MessageDigest.isEqual(expected, actual)

    private fun DataOutputStream.writeLengthPrefixed(value: String) {
        writeLengthPrefixed(value.toByteArray(StandardCharsets.UTF_8))
    }

    private fun DataOutputStream.writeLengthPrefixed(value: ByteArray) {
        writeInt(value.size)
        write(value)
    }

    private fun UUID.toBytes(): ByteArray =
        ByteBuffer.allocate(Long.SIZE_BYTES * 2)
            .putLong(mostSignificantBits)
            .putLong(leastSignificantBits)
            .array()
}
