package com.kelimio.api.importpipeline.infrastructure.xlsx

import java.time.Duration

internal class XlsxDeadline(
    duration: Duration,
    private val nanoTime: () -> Long = System::nanoTime,
) {
    private val startedAt = nanoTime()
    private val allowedNanos = duration.toNanos()

    fun check() {
        val elapsed = nanoTime() - startedAt
        if (elapsed < 0 || elapsed > allowedNanos) {
            reject(XlsxRejectionCode.PARSE_DEADLINE_EXCEEDED)
        }
    }
}
