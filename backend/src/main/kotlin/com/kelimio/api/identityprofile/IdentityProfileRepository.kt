package com.kelimio.api.identityprofile

import com.kelimio.api.persistence.Users
import org.jooq.DSLContext
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
        email: String?,
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
                email,
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

        return dsl.select(
            Users.ID,
            Users.SUBJECT,
            Users.EMAIL,
            Users.DISPLAY_NAME,
            Users.USERNAME,
            Users.APP_LOCALE,
            Users.ACTIVE_TARGET_LANGUAGE,
            Users.TIME_ZONE,
        ).from(Users.TABLE)
            .where(Users.SUBJECT.eq(subject))
            .fetchOne {
                AppUser(
                    id = it.get(Users.ID)!!,
                    subject = it.get(Users.SUBJECT)!!,
                    email = it.get(Users.EMAIL),
                    displayName = it.get(Users.DISPLAY_NAME)!!,
                    username = it.get(Users.USERNAME),
                    appLocale = it.get(Users.APP_LOCALE)!!,
                    activeTargetLanguage = it.get(Users.ACTIVE_TARGET_LANGUAGE)!!,
                    timeZone = it.get(Users.TIME_ZONE)!!,
                )
            } ?: error("User insert completed without a readable row")
    }
}
