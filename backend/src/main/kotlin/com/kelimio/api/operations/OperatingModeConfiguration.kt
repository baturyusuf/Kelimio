package com.kelimio.api.operations

import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient
import software.amazon.awssdk.services.ssm.SsmClient

@Configuration
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
class OperatingModeConfiguration {
    @Bean
    fun operatingModeProvider(
        @Value("\${KELIMIO_ENVIRONMENT}") environment: String,
        @Value("\${KELIMIO_OPERATING_MODE:NORMAL}") staticMode: String,
        @Value("\${KELIMIO_OPERATING_MODE_PARAMETER:}") parameterName: String,
    ): OperatingModeProvider {
        val normalizedEnvironment = environment.trim().lowercase()
        return if (normalizedEnvironment == "production") {
            require(parameterName.isNotBlank()) {
                "KELIMIO_OPERATING_MODE_PARAMETER is required in production."
            }
            SsmOperatingModeProvider(
                ssmClient = SsmClient.builder()
                    .httpClientBuilder(UrlConnectionHttpClient.builder())
                    .build(),
                parameterName = parameterName.trim(),
            )
        } else {
            require(parameterName.isBlank()) {
                "KELIMIO_OPERATING_MODE_PARAMETER is production-only."
            }
            val mode = OperatingMode.parse(staticMode)
            OperatingModeProvider { mode }
        }
    }
}
