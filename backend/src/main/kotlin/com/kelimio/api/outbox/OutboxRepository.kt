package com.kelimio.api.outbox

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.persistence.OutboxEvents
import com.kelimio.api.persistence.OutboxDeliveries
import com.kelimio.api.web.CorrelationIdProvider
import org.jooq.DSLContext
import org.jooq.JSONB
import org.springframework.stereotype.Repository
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

interface TransactionalOutbox {
    fun appendRecorded(event: RecordedOutboxEvent)
}

data class RecordedOutboxEvent(
    val id: UUID,
    val aggregateType: String,
    val aggregateId: UUID,
    val eventType: String,
    val schemaVersion: Int,
    val payload: Map<String, Any?>,
    val correlationId: String,
    val occurredAt: OffsetDateTime,
)

@Repository
class OutboxRepository(
    private val dsl: DSLContext,
    private val objectMapper: ObjectMapper,
    private val correlationIdProvider: CorrelationIdProvider,
    private val clock: Clock,
) : TransactionalOutbox {
    fun append(
        aggregateType: String,
        aggregateId: UUID,
        eventType: String,
        payload: Map<String, Any?>,
    ): UUID {
        val eventId = UUID.randomUUID()
        appendRecorded(
            RecordedOutboxEvent(
                id = eventId,
                aggregateType = aggregateType,
                aggregateId = aggregateId,
                eventType = eventType,
                schemaVersion = 1,
                payload = payload,
                correlationId = correlationIdProvider.current(),
                occurredAt = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC),
            ),
        )
        return eventId
    }

    override fun appendRecorded(event: RecordedOutboxEvent) {
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
                event.id,
                event.aggregateType,
                event.aggregateId,
                event.eventType,
                event.schemaVersion,
                JSONB.valueOf(objectMapper.writeValueAsString(event.payload)),
                event.correlationId,
                event.occurredAt,
            )
            .execute()
        dsl.insertInto(OutboxDeliveries.TABLE)
            .columns(
                OutboxDeliveries.EVENT_ID,
                OutboxDeliveries.ATTEMPT_COUNT,
            )
            .values(event.id, 0)
            .execute()
    }
}
