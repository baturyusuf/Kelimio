package com.kelimio.api.importpipeline.intake

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import software.amazon.awssdk.regions.Region
import java.io.DataInputStream
import java.net.ServerSocket
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset

class ClamAvImportScannerTest {
    private val now = Instant.parse("2026-08-02T12:00:00Z")
    private val version = "ClamAV 1.4.5/123/Sun Aug 2 00:00:00 2026"

    @Test
    fun `clean verdict is accepted only with the same supported fresh identity before and after`() {
        FakeClamServer(listOf(version, "stream: OK", version)).use { server ->
            val source = Files.createTempFile("clam-test-", ".xlsx")
            try {
                Files.write(source, byteArrayOf(1, 2, 3, 4))
                val result = scanner(server.port).scan(source, now.plusSeconds(10))
                assertThat(result).isInstanceOf(ClamAvScanResult.Clean::class.java)
                assertThat((result as ClamAvScanResult.Clean).identity.engineVersion).isEqualTo("1.4.5")
            } finally {
                Files.deleteIfExists(source)
            }
        }
    }

    @Test
    fun `unsupported engine and changed scan identity fail closed`() {
        FakeClamServer(listOf("ClamAV 0.0/123/Sun Aug 2 00:00:00 2026")).use { server ->
            val source = Files.createTempFile("clam-test-", ".xlsx")
            try {
                assertThatThrownBy { scanner(server.port).scan(source, now.plusSeconds(10)) }
                    .isInstanceOfSatisfying(ClamAvUnavailableException::class.java) {
                        assertThat(it.stableCode).isEqualTo("scanner-engine-unsupported")
                    }
            } finally {
                Files.deleteIfExists(source)
            }
        }

        FakeClamServer(
            listOf(version, "stream: OK", "ClamAV 1.4.5/124/Sun Aug 2 00:00:00 2026"),
        ).use { server ->
            val source = Files.createTempFile("clam-test-", ".xlsx")
            try {
                assertThatThrownBy { scanner(server.port).scan(source, now.plusSeconds(10)) }
                    .isInstanceOfSatisfying(ClamAvUnavailableException::class.java) {
                        assertThat(it.stableCode).isEqualTo("scanner-identity-changed")
                    }
            } finally {
                Files.deleteIfExists(source)
            }
        }
    }

    @Test
    fun `malware signature must be canonical and nonempty`() {
        listOf(
            "stream:   FOUND",
            "stream:  Bad FOUND",
            "stream: Bad  Name FOUND",
            "stream: Bäd FOUND",
            "stream: Bad\tName FOUND",
        ).forEach { response ->
            FakeClamServer(listOf(version, response, version)).use { server ->
                val source = Files.createTempFile("clam-test-", ".xlsx")
                try {
                    assertThatThrownBy { scanner(server.port).scan(source, now.plusSeconds(10)) }
                        .isInstanceOfSatisfying(ClamAvUnavailableException::class.java) {
                            assertThat(it.stableCode).isEqualTo("scanner-response-invalid")
                        }
                } finally {
                    Files.deleteIfExists(source)
                }
            }
        }
    }

    private fun scanner(port: Int): ClamAvImportScanner = ClamAvImportScanner(
        settings = ImportRuntimeSettings(
            environment = "test",
            runtimeRole = ImportRuntimeRole.WORKER,
            region = Region.EU_CENTRAL_1,
            quarantineBucket = "quarantine",
            archiveBucket = "archive",
            queueName = "queue",
            dlqName = "dlq",
            clamAvHost = "127.0.0.1",
            clamAvPort = port,
            minimumClamAvEngineVersion = "1.4.0",
            minimumClamAvSignatureNumber = 100,
            maxDefinitionAge = Duration.ofHours(72),
            definitionFutureSkew = Duration.ofHours(1),
            parserVersion = "test-revision",
            uploadTtl = Duration.ofMinutes(15),
            cursorHmacKey = null,
        ),
        clock = Clock.fixed(now, ZoneOffset.UTC),
    )

    private class FakeClamServer(private val responses: List<String>) : AutoCloseable {
        private val server = ServerSocket(0)
        val port: Int = server.localPort
        private val thread = Thread.ofVirtual().name("fake-clamav").start {
            responses.forEach { response ->
                server.accept().use { socket ->
                    val input = DataInputStream(socket.getInputStream())
                    val command = readNullTerminated(input)
                    if (command == "zINSTREAM") {
                        while (true) {
                            val size = input.readInt()
                            if (size == 0) break
                            input.readNBytes(size)
                        }
                    }
                    socket.getOutputStream().apply {
                        write(response.toByteArray(StandardCharsets.UTF_8))
                        write(0)
                        flush()
                    }
                }
            }
        }

        override fun close() {
            runCatching { server.close() }
            thread.join(Duration.ofSeconds(2))
        }

        private fun readNullTerminated(input: DataInputStream): String {
            val bytes = ArrayList<Byte>()
            while (true) {
                val value = input.read()
                if (value < 0 || value == 0) break
                bytes += value.toByte()
            }
            return String(bytes.toByteArray(), StandardCharsets.US_ASCII)
        }
    }
}
