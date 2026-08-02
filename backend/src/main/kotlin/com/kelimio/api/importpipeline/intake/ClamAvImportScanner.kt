package com.kelimio.api.importpipeline.intake

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component
import java.io.BufferedInputStream
import java.io.DataOutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.concurrent.FutureTask
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

@Component
@ConditionalOnProperty(name = ["KELIMIO_IMPORT_ENABLED"], havingValue = "true")
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "worker")
class ClamAvImportScanner(
    private val settings: ImportRuntimeSettings,
    private val clock: Clock,
) {
    fun scan(path: Path, deadline: Instant): ClamAvScanResult {
        val identity = readIdentity(deadline)
        val response = request(deadline) { output ->
            output.write(Z_INSTREAM)
            BufferedInputStream(Files.newInputStream(path)).use { input ->
                val buffer = ByteArray(STREAM_CHUNK_BYTES)
                while (true) {
                    requireBefore(deadline)
                    val read = input.read(buffer)
                    if (read < 0) break
                    output.writeInt(read)
                    output.write(buffer, 0, read)
                }
            }
            output.writeInt(0)
        }
        val identityAfterScan = readIdentity(deadline)
        if (identity != identityAfterScan) {
            throw ClamAvUnavailableException("scanner-identity-changed")
        }
        return when {
            response == "stream: OK" -> ClamAvScanResult.Clean(identity)
            isCanonicalMalwareResponse(response) ->
                ClamAvScanResult.Malware(identity)
            else -> throw ClamAvUnavailableException("scanner-response-invalid")
        }
    }

    private fun readIdentity(deadline: Instant): ClamAvIdentity {
        val response = request(deadline) { it.write(Z_VERSION) }
        val match = VERSION_RESPONSE.matchEntire(response)
            ?: throw ClamAvUnavailableException("scanner-version-invalid")
        val engine = match.groupValues[1]
        val signatureNumber = match.groupValues[2]
        if (!versionAtLeast(engine, settings.minimumClamAvEngineVersion)) {
            throw ClamAvUnavailableException("scanner-engine-unsupported")
        }
        if (signatureNumber.toLongOrNull()?.let { it >= settings.minimumClamAvSignatureNumber } != true) {
            throw ClamAvUnavailableException("scanner-signature-unsupported")
        }
        val normalizedDate = match.groupValues[3].trim().replace(Regex("\\s+"), " ")
        val definitionTime = runCatching {
            LocalDateTime.parse(normalizedDate, DEFINITION_DATE_FORMAT).toInstant(ZoneOffset.UTC)
        }.getOrElse { throw ClamAvUnavailableException("scanner-definition-date-invalid") }
        val now = clock.instant()
        if (
            definitionTime.isBefore(now.minus(settings.maxDefinitionAge)) ||
            definitionTime.isAfter(now.plus(settings.definitionFutureSkew))
        ) {
            throw ClamAvUnavailableException("scanner-definitions-stale")
        }
        return ClamAvIdentity(
            engineVersion = engine.take(128),
            signatureVersion = "$signatureNumber/$normalizedDate".take(128),
        )
    }

    private fun request(deadline: Instant, write: (DataOutputStream) -> Unit): String {
        requireBefore(deadline)
        val socket = Socket()
        val task = FutureTask { requestOnSocket(socket, deadline, write) }
        Thread.ofVirtual().name("kelimio-clamav-request").start(task)
        try {
            return task.get(remainingNanos(deadline), TimeUnit.NANOSECONDS)
        } catch (_: TimeoutException) {
            task.cancel(true)
            throw ClamAvUnavailableException("scanner-deadline-exceeded")
        } catch (failure: ExecutionException) {
            val cause = failure.cause
            if (cause is ClamAvUnavailableException) throw cause
            throw ClamAvUnavailableException("scanner-unavailable")
        } catch (known: ClamAvUnavailableException) {
            throw known
        } catch (interrupted: InterruptedException) {
            Thread.currentThread().interrupt()
            throw ClamAvUnavailableException("scanner-interrupted")
        } catch (_: Exception) {
            throw ClamAvUnavailableException("scanner-unavailable")
        } finally {
            runCatching { socket.close() }
        }
    }

    private fun requestOnSocket(
        socket: Socket,
        deadline: Instant,
        write: (DataOutputStream) -> Unit,
    ): String {
        val timeout = remainingTimeoutMillis(deadline)
        socket.connect(InetSocketAddress(settings.clamAvHost, settings.clamAvPort), timeout)
        socket.soTimeout = timeout
        val output = DataOutputStream(socket.getOutputStream())
        requireBefore(deadline)
        write(output)
        requireBefore(deadline)
        output.flush()
        val response = ByteArray(MAX_RESPONSE_BYTES)
        var count = 0
        val input = socket.getInputStream()
        while (count < response.size) {
            requireBefore(deadline)
            socket.soTimeout = remainingTimeoutMillis(deadline)
            val byte = input.read()
            if (byte < 0 || byte == 0 || byte == '\n'.code) break
            response[count++] = byte.toByte()
        }
        if (count == 0 || count == response.size) {
            throw ClamAvUnavailableException("scanner-response-invalid")
        }
        return String(response, 0, count, StandardCharsets.UTF_8)
    }

    private fun requireBefore(deadline: Instant) {
        if (!clock.instant().isBefore(deadline)) throw ClamAvUnavailableException("scanner-deadline-exceeded")
    }

    private fun remainingNanos(deadline: Instant): Long =
        Duration.between(clock.instant(), deadline).toNanos().coerceAtLeast(1)

    private fun remainingTimeoutMillis(deadline: Instant): Int = minOf(
        Duration.between(clock.instant(), deadline),
        SOCKET_TIMEOUT,
    ).toMillis().coerceAtLeast(1).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()

    private fun versionAtLeast(actual: String, required: String): Boolean {
        val actualParts = parseVersion(actual) ?: return false
        val requiredParts = parseVersion(required) ?: return false
        val width = maxOf(actualParts.size, requiredParts.size)
        return (0 until width).firstNotNullOfOrNull { index ->
            val comparison = (actualParts.getOrElse(index) { 0 }).compareTo(requiredParts.getOrElse(index) { 0 })
            comparison.takeIf { it != 0 }
        }?.let { it > 0 } ?: true
    }

    private fun parseVersion(value: String): List<Int>? {
        if (!ENGINE_VERSION.matches(value)) return null
        return value.split('.').map { it.toIntOrNull() ?: return null }
    }

    private fun isCanonicalMalwareResponse(response: String): Boolean {
        val match = MALWARE_RESPONSE.matchEntire(response) ?: return false
        val signature = match.groupValues[1]
        return signature == signature.trim() && "  " !in signature &&
            signature.any { it in 'A'..'Z' || it in 'a'..'z' || it in '0'..'9' } &&
            signature.all { it in 'A'..'Z' || it in 'a'..'z' || it in '0'..'9' || it in ". _+-" }
    }

    private companion object {
        val Z_VERSION = "zVERSION\u0000".toByteArray(StandardCharsets.US_ASCII)
        val Z_INSTREAM = "zINSTREAM\u0000".toByteArray(StandardCharsets.US_ASCII)
        const val STREAM_CHUNK_BYTES = 8192
        const val MAX_RESPONSE_BYTES = 4096
        val SOCKET_TIMEOUT: Duration = Duration.ofMinutes(2)
        val ENGINE_VERSION = Regex("[0-9]+(?:\\.[0-9]+){1,3}")
        val VERSION_RESPONSE = Regex("^ClamAV ([0-9]+(?:\\.[0-9]+){1,3})/([0-9]+)/(.+)$")
        val MALWARE_RESPONSE = Regex("^stream: (.{1,200}) FOUND$")
        val DEFINITION_DATE_FORMAT: DateTimeFormatter =
            DateTimeFormatter.ofPattern("EEE MMM d HH:mm:ss yyyy", Locale.ENGLISH)
    }
}

sealed interface ClamAvScanResult {
    data class Clean(val identity: ClamAvIdentity) : RedactedImportModel(), ClamAvScanResult
    data class Malware(val identity: ClamAvIdentity) : RedactedImportModel(), ClamAvScanResult
}

data class ClamAvIdentity(
    val engineVersion: String,
    val signatureVersion: String,
) : RedactedImportModel()

class ClamAvUnavailableException(val stableCode: String) : RuntimeException("ClamAV unavailable")
