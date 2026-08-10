package com.kelimio.api.teacher

import jakarta.validation.constraints.Size

internal data class TeacherAccessResponse(
    val eligible: Boolean,
    val termsAccepted: Boolean,
    val productionFeaturesEnabled: Boolean,
    val requiredTermsVersion: String,
)

internal data class AcceptTeacherTermsRequest(
    @field:Size(min = 1, max = 64)
    val termsVersion: String,
)
