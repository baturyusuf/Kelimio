package com.kelimio.api.identityprofile

import java.util.UUID

data class AppUser(
    val id: UUID,
    val subject: String,
    val email: String?,
    val displayName: String,
    val username: String?,
    val appLocale: String,
    val activeTargetLanguage: String,
    val timeZone: String,
)
