package com.kelimio.api

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class KelimioApiApplication

fun main(args: Array<String>) {
    runApplication<KelimioApiApplication>(*args)
}
