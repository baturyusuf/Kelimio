package com.kelimio.api.operations

enum class OperatingMode {
    NORMAL,
    CONSERVE,
    READ_ONLY,
    SUSPENDED,
    ;

    companion object {
        fun parse(value: String): OperatingMode =
            entries.firstOrNull { it.name == value.trim().uppercase() }
                ?: throw IllegalArgumentException(
                    "KELIMIO_OPERATING_MODE must be one of ${entries.joinToString { it.name }}.",
                )
    }
}

fun interface OperatingModeProvider {
    fun current(): OperatingMode
}
