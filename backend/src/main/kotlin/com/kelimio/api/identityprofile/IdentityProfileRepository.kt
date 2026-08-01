package com.kelimio.api.identityprofile

import com.kelimio.api.persistence.IdentityProfileEvents
import com.kelimio.api.persistence.Users
import org.jooq.DSLContext
import org.jooq.Record
import org.springframework.stereotype.Repository
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Repository
class IdentityProfileRepository(
    private val dsl: DSLContext,
    private val clock: Clock,
) {
    fun findOrCreate(
        subject: String,
        verifiedEmail: String?,
        displayName: String,
        username: String?,
        appLocale: String,
        activeTargetLanguage: String,
    ): AppUser {
        val now = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        dsl.insertInto(Users.TABLE)
            .columns(
                Users.ID,
                Users.SUBJECT,
                Users.EMAIL,
                Users.DISPLAY_NAME,
                Users.USERNAME,
                Users.APP_LOCALE,
                Users.ACTIVE_TARGET_LANGUAGE,
                Users.TIME_ZONE,
                Users.CREATED_AT,
                Users.UPDATED_AT,
            )
            .values(
                UUID.randomUUID(),
                subject,
                verifiedEmail,
                displayName,
                username,
                appLocale,
                activeTargetLanguage,
                "UTC",
                now,
                now,
            )
            .onConflict(Users.SUBJECT)
            .doNothing()
            .execute()

        return findBySubject(subject)
            ?: error("User insert completed without a readable row")
    }

    fun findById(userId: UUID): AppUser? = userSelect()
        .where(Users.ID.eq(userId))
        .fetchOne(::mapUser)

    fun lockById(userId: UUID): AppUser = userSelect()
        .where(Users.ID.eq(userId))
        .forUpdate()
        .fetchOne(::mapUser)
        ?: error("Authenticated user disappeared during profile setup")

    fun completeSetup(
        userId: UUID,
        displayName: String,
        appLocale: String,
        activeTargetLanguage: String,
        preferredSupportLanguage: String,
        timeZone: String,
        profileVersion: Long,
        now: OffsetDateTime,
    ): AppUser {
        check(
            dsl.update(Users.TABLE)
                .set(Users.DISPLAY_NAME, displayName)
                .set(Users.APP_LOCALE, appLocale)
                .set(Users.ACTIVE_TARGET_LANGUAGE, activeTargetLanguage)
                .set(Users.PREFERRED_SUPPORT_LANGUAGE, preferredSupportLanguage)
                .set(Users.TIME_ZONE, timeZone)
                .set(Users.PROFILE_SETUP_COMPLETED_AT, now)
                .set(Users.PROFILE_VERSION, profileVersion)
                .set(Users.UPDATED_AT, now)
                .where(Users.ID.eq(userId))
                .and(Users.PROFILE_SETUP_COMPLETED_AT.isNull)
                .execute() == 1,
        ) { "Profile setup did not update exactly one provisional user" }
        return findById(userId)!!
    }

    fun appendSetupEvent(
        userId: UUID,
        profileVersion: Long,
        changedFields: List<String>,
        now: OffsetDateTime,
        correlationId: String,
    ) {
        dsl.insertInto(IdentityProfileEvents.TABLE)
            .columns(
                IdentityProfileEvents.ID,
                IdentityProfileEvents.USER_ID,
                IdentityProfileEvents.EVENT_TYPE,
                IdentityProfileEvents.PROFILE_VERSION,
                IdentityProfileEvents.CHANGED_FIELDS,
                IdentityProfileEvents.OCCURRED_AT,
                IdentityProfileEvents.CORRELATION_ID,
            )
            .values(
                UUID.randomUUID(),
                userId,
                "PROFILE_SETUP_COMPLETED",
                profileVersion,
                changedFields.toTypedArray(),
                now,
                correlationId,
            )
            .execute()
    }

    private fun findBySubject(subject: String): AppUser? = userSelect()
        .where(Users.SUBJECT.eq(subject))
        .fetchOne(::mapUser)

    private fun userSelect() = dsl.select(
        Users.ID,
        Users.SUBJECT,
        Users.EMAIL,
        Users.DISPLAY_NAME,
        Users.USERNAME,
        Users.APP_LOCALE,
        Users.ACTIVE_TARGET_LANGUAGE,
        Users.PREFERRED_SUPPORT_LANGUAGE,
        Users.TIME_ZONE,
        Users.PROFILE_VERSION,
        Users.PROFILE_SETUP_COMPLETED_AT,
    ).from(Users.TABLE)

    private fun mapUser(record: Record): AppUser = AppUser(
        id = record.get(Users.ID)!!,
        subject = record.get(Users.SUBJECT)!!,
        email = record.get(Users.EMAIL),
        displayName = record.get(Users.DISPLAY_NAME)!!,
        username = record.get(Users.USERNAME),
        appLocale = record.get(Users.APP_LOCALE)!!,
        activeTargetLanguage = record.get(Users.ACTIVE_TARGET_LANGUAGE)!!,
        preferredSupportLanguage = record.get(Users.PREFERRED_SUPPORT_LANGUAGE),
        timeZone = record.get(Users.TIME_ZONE)!!,
        profileVersion = record.get(Users.PROFILE_VERSION)!!,
        profileSetupComplete = record.get(Users.PROFILE_SETUP_COMPLETED_AT) != null,
    )
}
