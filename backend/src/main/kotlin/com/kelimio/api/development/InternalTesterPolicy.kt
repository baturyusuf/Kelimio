package com.kelimio.api.development

internal object InternalTesterPolicy {
    const val GROUP_NAME = "kelimio-internal-testers"

    fun canInstallStarterCourse(
        environment: String,
        groups: Collection<String>,
    ): Boolean = environment == "production" && GROUP_NAME in groups
}
