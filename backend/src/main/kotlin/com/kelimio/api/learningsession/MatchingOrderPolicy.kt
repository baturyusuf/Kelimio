package com.kelimio.api.learningsession

import com.kelimio.api.language.LanguageTagNormalizer
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.UUID

internal enum class MatchingSide(
    val domain: String,
) {
    TARGET("target"),
    SUPPORT("support"),
}

/** Byte-exact deterministic item ordering for one side of a Type-D question. */
internal object MatchingOrderPolicy {
    const val VERSION = "matching-order-v1"
    const val MIN_ITEMS = 2
    const val MAX_ITEMS = 6
    private const val DIGEST_ALGORITHM = "SHA-256"

    fun order(
        itemIds: Collection<UUID>,
        attemptSeed: Long,
        questionRevisionId: UUID,
        side: MatchingSide,
        supportLanguage: String,
        policyVersion: String = VERSION,
    ): List<UUID> {
        val ids = itemIds.toList()
        require(ids.size in MIN_ITEMS..MAX_ITEMS) { "Matching order requires two through six items" }
        require(ids.toSet().size == ids.size) { "Matching order item identifiers must be unique" }
        validatePolicy(policyVersion, supportLanguage)

        return ids
            .map { itemId ->
                RankedItem(
                    itemId = itemId,
                    digest = orderingKey(
                        attemptSeed = attemptSeed,
                        questionRevisionId = questionRevisionId,
                        side = side,
                        supportLanguage = supportLanguage,
                        itemId = itemId,
                        policyVersion = policyVersion,
                    ),
                )
            }
            .sortedWith { left, right ->
                compareUnsigned(left.digest, right.digest).takeIf { it != 0 }
                    ?: compareUnsigned(left.itemId.toRfc4122Bytes(), right.itemId.toRfc4122Bytes())
            }
            .map(RankedItem::itemId)
    }

    internal fun orderingKey(
        attemptSeed: Long,
        questionRevisionId: UUID,
        side: MatchingSide,
        supportLanguage: String,
        itemId: UUID,
        policyVersion: String = VERSION,
    ): ByteArray {
        validatePolicy(policyVersion, supportLanguage)
        return MessageDigest.getInstance(DIGEST_ALGORITHM).apply {
            updateField(policyVersion.toByteArray(StandardCharsets.US_ASCII))
            updateField(ByteBuffer.allocate(Long.SIZE_BYTES).putLong(attemptSeed).array())
            updateField(questionRevisionId.toRfc4122Bytes())
            updateField(side.domain.toByteArray(StandardCharsets.US_ASCII))
            updateField(supportLanguage.toByteArray(StandardCharsets.UTF_8))
            updateField(itemId.toRfc4122Bytes())
        }.digest()
    }

    private fun validatePolicy(policyVersion: String, supportLanguage: String) {
        require(policyVersion == VERSION) { "Unsupported matching order policy" }
        require(CANONICAL_LANGUAGE_TAG.matches(supportLanguage)) {
            "Matching order requires a canonical support language"
        }
    }

    private fun MessageDigest.updateField(value: ByteArray) {
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

    private data class RankedItem(
        val itemId: UUID,
        val digest: ByteArray,
    )

    private val CANONICAL_LANGUAGE_TAG = Regex(LanguageTagNormalizer.CANONICAL_PATTERN)
}
