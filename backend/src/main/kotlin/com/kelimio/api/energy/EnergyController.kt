package com.kelimio.api.energy

import com.kelimio.api.identityprofile.CurrentUserService
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/v1/energy")
class EnergyController(
    private val currentUserService: CurrentUserService,
    private val energyService: EnergyService,
) {
    @GetMapping
    fun energy(@AuthenticationPrincipal jwt: Jwt): EnergySnapshot =
        energyService.current(currentUserService.resolve(jwt).id)
}
