package com.kelimio.api

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.scheduling.annotation.EnableScheduling

@SpringBootApplication
@EnableScheduling
class KelimioApiApplication

fun main(args: Array<String>) {
    runApplication<KelimioApiApplication>(*args)
}
