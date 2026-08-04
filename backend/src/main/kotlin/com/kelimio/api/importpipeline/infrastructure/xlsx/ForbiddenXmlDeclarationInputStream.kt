package com.kelimio.api.importpipeline.infrastructure.xlsx

import java.io.FilterInputStream
import java.io.InputStream
import java.nio.charset.StandardCharsets

/** Rejects DTD/entity declarations before an XML parser can act on them. */
internal class ForbiddenXmlDeclarationInputStream(
    delegate: InputStream,
) : FilterInputStream(delegate) {
    private val matchers = FORBIDDEN_PATTERNS.map(::BytePatternMatcher)

    override fun read(): Int {
        val value = super.read()
        if (value >= 0) inspect(value.toByte())
        return value
    }

    override fun read(
        target: ByteArray,
        offset: Int,
        length: Int,
    ): Int {
        val read = `in`.read(target, offset, length)
        if (read > 0) {
            for (index in offset until offset + read) inspect(target[index])
        }
        return read
    }

    private fun inspect(value: Byte) {
        if (matchers.any { it.accept(value) }) {
            reject(XlsxRejectionCode.XML_SECURITY_VIOLATION)
        }
    }

    private class BytePatternMatcher(
        private val pattern: ByteArray,
    ) {
        private var matched = 0

        fun accept(value: Byte): Boolean {
            matched = when {
                value == pattern[matched] -> matched + 1
                value == pattern[0] -> 1
                else -> 0
            }
            if (matched != pattern.size) return false
            matched = 0
            return true
        }
    }

    companion object {
        private val ASCII_DECLARATIONS = listOf("<!DOCTYPE", "<!ENTITY")
            .map { it.toByteArray(StandardCharsets.US_ASCII) }
        private val FORBIDDEN_PATTERNS = ASCII_DECLARATIONS.flatMap { ascii ->
            listOf(
                ascii,
                ByteArray(ascii.size * 2) { index -> if (index % 2 == 0) ascii[index / 2] else 0 },
                ByteArray(ascii.size * 2) { index -> if (index % 2 == 0) 0 else ascii[index / 2] },
            )
        }
    }
}
