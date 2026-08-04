package com.kelimio.api

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.SpringApplication
import org.springframework.boot.runApplication
import org.springframework.scheduling.annotation.EnableScheduling
import kotlin.system.exitProcess

@SpringBootApplication
@EnableScheduling
class KelimioApiApplication

fun main(args: Array<String>) {
    val context = runApplication<KelimioApiApplication>(*args)
    if (context.environment.getProperty("KELIMIO_RUNTIME_ROLE") == "migration") {
        exitProcess(SpringApplication.exit(context))
    }
}
