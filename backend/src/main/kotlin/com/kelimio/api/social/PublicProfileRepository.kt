package com.kelimio.api.social

import org.jooq.DSLContext
import org.jooq.exception.DataAccessException
import org.springframework.stereotype.Repository
import java.sql.SQLException
import java.time.OffsetDateTime
import java.util.UUID

@Repository
internal class PublicProfileRepository(
    private val dsl: DSLContext,
) {
    fun lockUser(userId: UUID): Boolean = dsl.fetchOne(
        "select id from app_user where id = ? for update",
        userId,
    ) != null

    fun findOwn(userId: UUID): PublicProfileRecord? = dsl.fetchOne(
        PROFILE_SELECT + " where user_row.id = ? group by user_row.id",
        userId,
    )?.toProfileRecord()

    fun findPublic(username: String): PublicProfileRecord? = dsl.fetchOne(
        PROFILE_SELECT +
            """
             where lower(user_row.username) = lower(?)
               and user_row.public_profile_enabled
             group by user_row.id
            """.trimIndent(),
        username,
    )?.toProfileRecord()

    fun update(
        userId: UUID,
        request: UpdatePublicProfileRequest,
        now: OffsetDateTime,
    ): Long {
        val nextVersion = checkNotNull(
            dsl.fetchOne("select profile_version + 1 as version from app_user where id = ?", userId),
        ).get("version", Long::class.java)!!
        try {
            check(
                dsl.execute(
                    """
                    update app_user
                       set username = ?, display_name = ?, public_bio = ?, avatar_seed = ?,
                           public_profile_enabled = ?, leaderboard_opt_in = ?,
                           public_profile_updated_at = cast(? as timestamptz),
                           profile_version = ?, updated_at = cast(? as timestamptz)
                     where id = ?
                    """.trimIndent(),
                    request.username,
                    request.displayName.trim(),
                    request.bio?.trim(),
                    request.avatarSeed,
                    request.publicProfileEnabled,
                    request.leaderboardOptIn,
                    now,
                    nextVersion,
                    now,
                    userId,
                ) == 1,
            ) { "Public profile update did not affect exactly one user" }
        } catch (failure: DataAccessException) {
            if (failure.findSqlState() == "23505") throw PublicUsernameConflictException()
            throw failure
        }
        return nextVersion
    }

    fun appendEvent(
        userId: UUID,
        profileVersion: Long,
        changedFields: List<String>,
        occurredAt: OffsetDateTime,
        correlationId: String,
    ) {
        check(
            dsl.execute(
                """
                insert into public_profile_event(
                    id, user_id, event_type, profile_version, changed_fields,
                    occurred_at, correlation_id
                ) values (?, ?, 'PUBLIC_PROFILE_UPDATED', ?, ?, cast(? as timestamptz), ?)
                """.trimIndent(),
                UUID.randomUUID(),
                userId,
                profileVersion,
                changedFields.toTypedArray(),
                occurredAt,
                correlationId,
            ) == 1,
        ) { "Public profile event was not inserted" }
    }

    fun leaderboard(limit: Int): List<LeaderboardEntryResponse> = dsl.fetch(
        """
        with totals as (
            select user_row.id, user_row.username, user_row.display_name,
                   user_row.avatar_seed, user_row.active_target_language,
                   coalesce(sum(progress.lifetime_score), 0)::bigint as lifetime_score,
                   coalesce(sum(progress.completed_attempts), 0)::integer as completed_attempts
              from app_user user_row
              left join learner_course_progress_projection progress
                on progress.user_id = user_row.id
             where user_row.public_profile_enabled
               and user_row.leaderboard_opt_in
               and user_row.username is not null
             group by user_row.id
        )
        select (row_number() over (
                   order by lifetime_score desc, completed_attempts desc, lower(username), id
               ))::integer as rank,
               username, display_name, avatar_seed, active_target_language,
               lifetime_score, completed_attempts
          from totals
         order by rank
         limit ?
        """.trimIndent(),
        limit,
    ).map {
        LeaderboardEntryResponse(
            rank = it.get("rank", Int::class.java)!!,
            username = it.get("username", String::class.java)!!,
            displayName = it.get("display_name", String::class.java)!!,
            avatarSeed = it.get("avatar_seed", String::class.java),
            targetLanguage = it.get("active_target_language", String::class.java)!!,
            lifetimeScore = it.get("lifetime_score", Long::class.java)!!,
            completedAttempts = it.get("completed_attempts", Int::class.java)!!,
        )
    }

    private fun org.jooq.Record.toProfileRecord(): PublicProfileRecord = PublicProfileRecord(
        userId = get("id", UUID::class.java)!!,
        username = get("username", String::class.java),
        displayName = get("display_name", String::class.java)!!,
        bio = get("public_bio", String::class.java),
        avatarSeed = get("avatar_seed", String::class.java),
        targetLanguage = get("active_target_language", String::class.java)!!,
        publicProfileEnabled = get("public_profile_enabled", Boolean::class.java)!!,
        leaderboardOptIn = get("leaderboard_opt_in", Boolean::class.java)!!,
        lifetimeScore = get("lifetime_score", Long::class.java)!!,
        completedAttempts = get("completed_attempts", Int::class.java)!!,
        profileVersion = get("profile_version", Long::class.java)!!,
        createdAt = get("created_at", OffsetDateTime::class.java)!!,
        updatedAt = get("public_profile_updated_at", OffsetDateTime::class.java),
    )

    private fun Throwable.findSqlState(): String? {
        var current: Throwable? = this
        repeat(16) {
            if (current is SQLException) return current.sqlState
            current = current?.cause
        }
        return null
    }

    private companion object {
        val PROFILE_SELECT =
            """
            select user_row.id, user_row.username, user_row.display_name,
                   user_row.public_bio, user_row.avatar_seed,
                   user_row.active_target_language,
                   user_row.public_profile_enabled, user_row.leaderboard_opt_in,
                   user_row.profile_version, user_row.created_at,
                   user_row.public_profile_updated_at,
                   coalesce(sum(progress.lifetime_score), 0)::bigint as lifetime_score,
                   coalesce(sum(progress.completed_attempts), 0)::integer as completed_attempts
              from app_user user_row
              left join learner_course_progress_projection progress
                on progress.user_id = user_row.id
            """.trimIndent()
    }
}

internal class PublicUsernameConflictException : RuntimeException()
