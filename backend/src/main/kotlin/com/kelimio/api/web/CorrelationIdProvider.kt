package com.kelimio.api.web

import org.slf4j.MDC
import org.springframework.stereotype.Component
import java.util.UUID

@Component
class CorrelationIdProvider {
    fun current(): String = MDC.get(CorrelationIdFilter.MDC_KEY) ?: UUID.randomUUID().toString()
}
