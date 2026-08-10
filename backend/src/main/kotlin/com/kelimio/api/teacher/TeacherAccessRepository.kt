package com.kelimio.api.teacher

import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime
import java.util.UUID

@Repository
internal class TeacherAccessRepository(
    private val dsl: DSLContext,
) {
    fun acceptedCurrentTerms(userId: UUID, termsVersion: String): Boolean = checkNotNull(
        dsl.fetchOne(
            """
            select exists(
                select 1 from teacher_authorization
                 where user_id = ? and status = 'ACTIVE'
                   and accepted_terms_version = ?
            ) as accepted
            """.trimIndent(),
            userId,
            termsVersion,
        ),
    ).get("accepted", Boolean::class.java)!!

    fun accept(
        userId: UUID,
        termsVersion: String,
        occurredAt: OffsetDateTime,
        correlationId: String,
    ) {
        check(
            dsl.execute(
                """
                insert into teacher_authorization(
                    user_id, status, accepted_terms_version, accepted_at,
                    revoked_at, updated_at
                ) values (?, 'ACTIVE', ?, cast(? as timestamptz), null, cast(? as timestamptz))
                on conflict (user_id) do update
                   set status = 'ACTIVE', accepted_terms_version = excluded.accepted_terms_version,
                       accepted_at = excluded.accepted_at, revoked_at = null,
                       updated_at = excluded.updated_at
                """.trimIndent(),
                userId,
                termsVersion,
                occurredAt,
                occurredAt,
            ) == 1,
        )
        check(
            dsl.execute(
                """
                insert into teacher_authorization_event(
                    id, user_id, event_type, terms_version, occurred_at, correlation_id
                ) values (?, ?, 'TERMS_ACCEPTED', ?, cast(? as timestamptz), ?)
                """.trimIndent(),
                UUID.randomUUID(),
                userId,
                termsVersion,
                occurredAt,
                correlationId,
            ) == 1,
        )
    }
}
