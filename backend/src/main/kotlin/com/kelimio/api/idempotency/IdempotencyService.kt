package com.kelimio.api.idempotency

import com.kelimio.api.persistence.CommandIdempotency
import com.kelimio.api.web.ConflictProblem
import org.jooq.DSLContext
import org.springframework.stereotype.Service
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.HexFormat
import java.util.UUID

@Service
class IdempotencyService(
    private val dsl: DSLContext,
    private val clock: Clock,
) {
    fun lockAndFind(
        userId: UUID,
        operation: String,
        key: UUID,
        canonicalRequest: String,
    ): IdempotencyLookup {
        val fingerprint = fingerprint(canonicalRequest)
        dsl.fetch(
            "select pg_advisory_xact_lock(hashtextextended(?, 0))",
            "$userId:$operation:$key",
        )
        val existing = dsl.select(CommandIdempotency.FINGERPRINT, CommandIdempotency.RESOURCE_ID)
            .from(CommandIdempotency.TABLE)
            .where(CommandIdempotency.USER_ID.eq(userId))
            .and(CommandIdempotency.OPERATION.eq(operation))
            .and(CommandIdempotency.KEY.eq(key))
            .fetchOne()
            ?: return IdempotencyLookup(fingerprint, null)
        if (existing.get(CommandIdempotency.FINGERPRINT) != fingerprint) {
            throw ConflictProblem("Idempotency-Key was already used with a different request.")
        }
        return IdempotencyLookup(fingerprint, existing.get(CommandIdempotency.RESOURCE_ID))
    }

    fun record(
        userId: UUID,
        operation: String,
        key: UUID,
        fingerprint: String,
        resourceId: UUID,
    ) {
        dsl.insertInto(CommandIdempotency.TABLE)
            .columns(
                CommandIdempotency.USER_ID,
                CommandIdempotency.OPERATION,
                CommandIdempotency.KEY,
                CommandIdempotency.FINGERPRINT,
                CommandIdempotency.RESOURCE_ID,
                CommandIdempotency.CREATED_AT,
            )
            .values(
                userId,
                operation,
                key,
                fingerprint,
                resourceId,
                OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC),
            )
            .execute()
    }

    private fun fingerprint(value: String): String =
        HexFormat.of().formatHex(
            MessageDigest.getInstance("SHA-256").digest(value.toByteArray(StandardCharsets.UTF_8)),
        )
}

data class IdempotencyLookup(
    val fingerprint: String,
    val resourceId: UUID?,
)
