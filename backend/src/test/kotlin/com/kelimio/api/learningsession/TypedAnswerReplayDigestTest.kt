package com.kelimio.api.learningsession

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.util.UUID

class TypedAnswerReplayDigestTest {
    @Test
    fun `digest binds salt identities policy and canonical answer`() {
        val salt = ByteArray(TypedAnswerReplayDigest.SALT_BYTES) { it.toByte() }
        val attemptId = UUID.randomUUID()
        val submissionId = UUID.randomUUID()
        val questionRevisionId = UUID.randomUUID()
        val digest = TypedAnswerReplayDigest.compute(
            salt,
            attemptId,
            submissionId,
            questionRevisionId,
            "typed-answer-v1",
            "içerim",
        )

        assertThat(digest).hasSize(TypedAnswerReplayDigest.DIGEST_BYTES)
        assertThat(
            TypedAnswerReplayDigest.compute(
                salt,
                attemptId,
                submissionId,
                questionRevisionId,
                "typed-answer-v1",
                "içerim",
            ),
        ).isEqualTo(digest)
        assertThat(
            TypedAnswerReplayDigest.compute(
                salt,
                attemptId,
                submissionId,
                questionRevisionId,
                "typed-answer-v1",
                "içiyorum",
            ),
        ).isNotEqualTo(digest)
        assertThat(
            TypedAnswerReplayDigest.compute(
                salt,
                attemptId,
                UUID.randomUUID(),
                questionRevisionId,
                "typed-answer-v1",
                "içerim",
            ),
        ).isNotEqualTo(digest)
        assertThat(
            TypedAnswerReplayDigest.compute(
                salt,
                UUID.randomUUID(),
                submissionId,
                questionRevisionId,
                "typed-answer-v1",
                "içerim",
            ),
        ).isNotEqualTo(digest)
        assertThat(
            TypedAnswerReplayDigest.compute(
                salt,
                attemptId,
                submissionId,
                UUID.randomUUID(),
                "typed-answer-v1",
                "içerim",
            ),
        ).isNotEqualTo(digest)
        assertThat(
            TypedAnswerReplayDigest.compute(
                salt,
                attemptId,
                submissionId,
                questionRevisionId,
                "typed-answer-v2",
                "içerim",
            ),
        ).isNotEqualTo(digest)
        assertThat(
            TypedAnswerReplayDigest.compute(
                salt.copyOf().also { it[0] = (it[0] + 1).toByte() },
                attemptId,
                submissionId,
                questionRevisionId,
                "typed-answer-v1",
                "içerim",
            ),
        ).isNotEqualTo(digest)
        assertThat(TypedAnswerReplayDigest.matches(digest, digest.copyOf())).isTrue()
    }
}
