package com.kelimio.api.outbox

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.persistence.OutboxEvents
import com.kelimio.api.web.CorrelationIdProvider
import org.jooq.DSLContext
import org.jooq.JSONB
import org.springframework.stereotype.Repository
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Repository
class OutboxRepository(
    private val dsl: DSLContext,
    private val objectMapper: ObjectMapper,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
) {
    fun append(
        aggregateType: String,
        aggregateId: UUID,
        eventType: String,
        payload: Map<String, Any?>,
    ): UUID {
        val eventId = UUID.randomUUID()
        dsl.insertInto(OutboxEvents.TABLE)
            .columns(
                OutboxEvents.ID,
                OutboxEvents.AGGREGATE_TYPE,
                OutboxEvents.AGGREGATE_ID,
                OutboxEvents.EVENT_TYPE,
                OutboxEvents.SCHEMA_VERSION,
                OutboxEvents.PAYLOAD,
                OutboxEvents.CORRELATION_ID,
                OutboxEvents.OCCURRED_AT,
            )
            .values(
                eventId,
                aggregateType,
                aggregateId,
                eventType,
                1,
                JSONB.valueOf(objectMapper.writeValueAsString(payload)),
                correlationIdProvider.current(),
                OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC),
            )
            .execute()
        return eventId
    }
}
