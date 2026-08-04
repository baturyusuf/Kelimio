package com.kelimio.api.learningsession

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.util.UUID

class MatchingOrderPolicyTest {
    @Test
    fun `matching-order-v1 has fixed byte-exact keys and unsigned ordering`() {
        val ids = listOf(
            uuid("00000000-0000-4000-8000-000000000001"),
            uuid("7fffffff-ffff-4fff-bfff-fffffffffff2"),
            uuid("80000000-0000-4000-8000-000000000003"),
            uuid("ffffffff-ffff-4fff-bfff-fffffffffff4"),
        )
        val questionRevisionId = uuid("12345678-1234-4abc-8def-1234567890ab")
        val attemptSeed = -81_985_529_216_486_896L

        assertThat(
            MatchingOrderPolicy.order(
                ids,
                attemptSeed,
                questionRevisionId,
                MatchingSide.TARGET,
                "en",
            ),
        ).containsExactly(
            uuid("7fffffff-ffff-4fff-bfff-fffffffffff2"),
            uuid("ffffffff-ffff-4fff-bfff-fffffffffff4"),
            uuid("00000000-0000-4000-8000-000000000001"),
            uuid("80000000-0000-4000-8000-000000000003"),
        )
        assertThat(
            MatchingOrderPolicy.order(
                ids.reversed(),
                attemptSeed,
                questionRevisionId,
                MatchingSide.SUPPORT,
                "en",
            ),
        ).containsExactly(
            uuid("80000000-0000-4000-8000-000000000003"),
            uuid("00000000-0000-4000-8000-000000000001"),
            uuid("7fffffff-ffff-4fff-bfff-fffffffffff2"),
            uuid("ffffffff-ffff-4fff-bfff-fffffffffff4"),
        )
        assertThat(
            MatchingOrderPolicy.order(
                ids.reversed(),
                attemptSeed,
                questionRevisionId,
                MatchingSide.TARGET,
                "en",
            ),
        ).containsExactlyElementsOf(
            MatchingOrderPolicy.order(
                ids,
                attemptSeed,
                questionRevisionId,
                MatchingSide.TARGET,
                "en",
            ),
        )

        assertThat(
            MatchingOrderPolicy.orderingKey(
                attemptSeed,
                questionRevisionId,
                MatchingSide.TARGET,
                "en",
                ids.first(),
            ).hex(),
        ).isEqualTo("8d4db0f9a039906eeab49b01c410033b6c4934b67aeca829b2fbd1b2de460db0")
        assertThat(
            MatchingOrderPolicy.orderingKey(
                attemptSeed,
                questionRevisionId,
                MatchingSide.SUPPORT,
                "en",
                ids.first(),
            ).hex(),
        ).isEqualTo("b9613d32fe252c7d5f0c952efa33fa936be2ae0249ea1b619395fbfa9dd5b23e")
    }

    @Test
    fun `independent side domains allow coincidental alignment without derangement`() {
        val targets = (1..4).map { uuid("10000000-0000-4000-8000-${it.toString().padStart(12, '0')}") }
        val supports = (1..4).map { uuid("20000000-0000-4000-8000-${it.toString().padStart(12, '0')}") }
        val questionRevisionId = uuid("12345678-1234-4abc-8def-1234567890ab")

        val targetOrder = MatchingOrderPolicy.order(
            targets,
            -98L,
            questionRevisionId,
            MatchingSide.TARGET,
            "en",
        )
        val supportOrder = MatchingOrderPolicy.order(
            supports,
            -98L,
            questionRevisionId,
            MatchingSide.SUPPORT,
            "en",
        )
        val alignedPositions = targetOrder.indices.filter { position ->
            targets.indexOf(targetOrder[position]) == supports.indexOf(supportOrder[position])
        }

        assertThat(targetOrder).containsExactly(
            targets[3],
            targets[1],
            targets[2],
            targets[0],
        )
        assertThat(supportOrder).containsExactly(
            supports[2],
            supports[1],
            supports[3],
            supports[0],
        )
        assertThat(alignedPositions).containsExactly(1, 3)
    }

    @Test
    fun `ordering binds seed question side and pinned support language`() {
        val itemId = uuid("00000000-0000-4000-8000-000000000001")
        val questionRevisionId = uuid("12345678-1234-4abc-8def-1234567890ab")
        val base = MatchingOrderPolicy.orderingKey(
            42L,
            questionRevisionId,
            MatchingSide.TARGET,
            "en",
            itemId,
        )

        assertThat(
            MatchingOrderPolicy.orderingKey(43L, questionRevisionId, MatchingSide.TARGET, "en", itemId),
        ).isNotEqualTo(base)
        assertThat(
            MatchingOrderPolicy.orderingKey(
                42L,
                uuid("12345678-1234-4abc-8def-1234567890ac"),
                MatchingSide.TARGET,
                "en",
                itemId,
            ),
        ).isNotEqualTo(base)
        assertThat(
            MatchingOrderPolicy.orderingKey(42L, questionRevisionId, MatchingSide.SUPPORT, "en", itemId),
        ).isNotEqualTo(base)
        assertThat(
            MatchingOrderPolicy.orderingKey(42L, questionRevisionId, MatchingSide.TARGET, "tr", itemId),
        ).isNotEqualTo(base)
    }

    @Test
    fun `ordering rejects invalid bounds duplicates language and policy`() {
        val questionRevisionId = uuid("12345678-1234-4abc-8def-1234567890ab")
        val first = uuid("00000000-0000-4000-8000-000000000001")
        val second = uuid("00000000-0000-4000-8000-000000000002")

        assertThatThrownBy {
            MatchingOrderPolicy.order(listOf(first), 1L, questionRevisionId, MatchingSide.TARGET, "en")
        }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy {
            MatchingOrderPolicy.order(
                (1..7).map { uuid("00000000-0000-4000-8000-${it.toString().padStart(12, '0')}") },
                1L,
                questionRevisionId,
                MatchingSide.TARGET,
                "en",
            )
        }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy {
            MatchingOrderPolicy.order(listOf(first, first), 1L, questionRevisionId, MatchingSide.TARGET, "en")
        }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy {
            MatchingOrderPolicy.order(listOf(first, second), 1L, questionRevisionId, MatchingSide.TARGET, "EN")
        }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy {
            MatchingOrderPolicy.order(
                listOf(first, second),
                1L,
                questionRevisionId,
                MatchingSide.TARGET,
                "en",
                "matching-order-v2",
            )
        }.isInstanceOf(IllegalArgumentException::class.java)
    }

    private fun uuid(value: String): UUID = UUID.fromString(value)

    private fun ByteArray.hex(): String = joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
}
