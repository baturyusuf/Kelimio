package com.kelimio.api.importpipeline.infrastructure.xlsx

import org.apache.commons.compress.archivers.zip.ZipArchiveEntry
import org.apache.commons.compress.archivers.zip.ZipFile
import org.xml.sax.Attributes
import org.xml.sax.InputSource
import org.xml.sax.SAXException
import org.xml.sax.SAXParseException
import org.xml.sax.helpers.DefaultHandler
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.nio.charset.CodingErrorAction
import java.nio.file.Path
import java.text.Normalizer
import java.util.Locale
import java.util.zip.CRC32
import java.util.zip.ZipException
import javax.xml.XMLConstants
import javax.xml.parsers.ParserConfigurationException
import javax.xml.parsers.SAXParserFactory

internal class XlsxZipPreflight(
    private val limits: XlsxImportLimits,
    private val deadline: XlsxDeadline,
) {
    fun inspect(path: Path): Int {
        try {
            return ZipFile.builder()
                .setPath(path)
                .setUseUnicodeExtraFields(false)
                .get()
                .use { zip ->
                val entries = ArrayList<ZipArchiveEntry>(minOf(limits.maxZipEntries, 256))
                val enumeration = zip.entries
                while (enumeration.hasMoreElements()) {
                    deadline.check()
                    if (entries.size == limits.maxZipEntries) {
                        reject(XlsxRejectionCode.TOO_MANY_ZIP_ENTRIES)
                    }
                    entries += enumeration.nextElement()
                }

                val exactNames = mutableSetOf<String>()
                val caseFoldedNames = mutableSetOf<String>()
                val packageFacts = PackageFacts()
                var totalInflatedBytes = 0L
                var observedTotalInflatedBytes = 0L

                entries.forEach { entry ->
                    deadline.check()
                    validateEntryIdentity(entry)
                    val normalizedName = validateEntryName(entry.name)
                    if (!exactNames.add(normalizedName)) {
                        reject(XlsxRejectionCode.DUPLICATE_ZIP_ENTRY)
                    }
                    val caseFoldedName = unicodeCaseFold(normalizedName)
                    if (!caseFoldedNames.add(caseFoldedName)) {
                        reject(XlsxRejectionCode.CASE_FOLDING_ZIP_ENTRY_COLLISION)
                    }
                    rejectKnownUnsafePart(caseFoldedName)
                    validateDeclaredSizes(entry, normalizedName)

                    totalInflatedBytes = addWithoutOverflow(totalInflatedBytes, entry.size)
                    if (totalInflatedBytes > limits.maxTotalInflatedBytes) {
                        reject(XlsxRejectionCode.TOTAL_INFLATED_SIZE_EXCEEDED)
                    }

                    observedTotalInflatedBytes = addWithoutOverflow(
                        observedTotalInflatedBytes,
                        validateInflatedContent(zip, entry),
                    )
                    if (observedTotalInflatedBytes > limits.maxTotalInflatedBytes) {
                        reject(XlsxRejectionCode.TOTAL_INFLATED_SIZE_EXCEEDED)
                    }
                }

                requireCoreParts(exactNames)
                entries
                    .asSequence()
                    .filterNot(ZipArchiveEntry::isDirectory)
                    .filter { isXmlPart(it.name) }
                    .forEach { entry ->
                        deadline.check()
                        zip.getInputStream(entry).use { input ->
                            inspectXml(entry.name, input, packageFacts)
                        }
                    }
                packageFacts.validate(exactNames)
                packageFacts.sheetCount
            }
        } catch (rejected: XlsxRejectedException) {
            throw rejected
        } catch (_: ZipException) {
            throw XlsxRejectedException(XlsxRejectionCode.CORRUPT_PACKAGE)
        } catch (_: SAXParseException) {
            throw XlsxRejectedException(XlsxRejectionCode.CORRUPT_PACKAGE)
        } catch (_: SAXException) {
            throw XlsxRejectedException(XlsxRejectionCode.XML_SECURITY_VIOLATION)
        } catch (_: ParserConfigurationException) {
            throw XlsxRejectedException(XlsxRejectionCode.XML_SECURITY_VIOLATION)
        } catch (_: Exception) {
            throw XlsxRejectedException(XlsxRejectionCode.CORRUPT_PACKAGE)
        }
    }

    private fun validateEntryIdentity(entry: ZipArchiveEntry) {
        if (
            entry.localFileDataExtra.isNotEmpty() ||
            entry.centralDirectoryExtra.isNotEmpty() ||
            !entry.comment.isNullOrEmpty()
        ) {
            reject(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME)
        }
        val rawName = entry.rawName ?: reject(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME)
        val decodedRawName = try {
            StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(rawName))
                .toString()
        } catch (_: java.nio.charset.CharacterCodingException) {
            reject(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME)
        }
        if (decodedRawName != entry.name) {
            reject(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME)
        }
    }

    private fun validateEntryName(rawName: String): String {
        if (
            rawName.isEmpty() ||
            rawName.indexOf('\u0000') >= 0 ||
            '\\' in rawName ||
            rawName.startsWith('/') ||
            rawName.startsWith("//") ||
            DRIVE_PREFIX.containsMatchIn(rawName)
        ) {
            reject(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME)
        }

        val normalized = Normalizer.normalize(rawName, Normalizer.Form.NFC)
        val isDirectory = normalized.endsWith('/')
        val segments = normalized.split('/').let { parts ->
            if (isDirectory) parts.dropLast(1) else parts
        }
        if (
            segments.isEmpty() ||
            segments.any { it.isEmpty() || it == "." || it == ".." }
        ) {
            reject(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME)
        }
        return normalized
    }

    private fun validateDeclaredSizes(
        entry: ZipArchiveEntry,
        normalizedName: String,
    ) {
        if (entry.size < 0 || entry.compressedSize < 0) {
            reject(XlsxRejectionCode.CORRUPT_PACKAGE)
        }
        if (entry.size > limits.maxInflatedEntryBytes) {
            reject(XlsxRejectionCode.ZIP_ENTRY_TOO_LARGE)
        }
        val partSpecificLimit = when {
            normalizedName.endsWith(".rels", ignoreCase = true) ||
                WORKBOOK_METADATA_PARTS.contains(normalizedName) -> {
                limits.maxWorkbookMetadataPartBytes
            }
            normalizedName == "xl/styles.xml" -> limits.maxStylesPartBytes
            CANONICAL_THEME_PART.matches(normalizedName) -> limits.maxThemePartBytes
            normalizedName == "xl/sharedStrings.xml" -> limits.maxSharedStringsPartBytes
            else -> limits.maxInflatedEntryBytes
        }
        if (entry.size > partSpecificLimit) {
            reject(XlsxRejectionCode.ZIP_ENTRY_TOO_LARGE)
        }
        if (entry.size > limits.inflationRatioGraceBytes) {
            if (entry.compressedSize == 0L) {
                reject(XlsxRejectionCode.SUSPICIOUS_COMPRESSION_RATIO)
            }
            val ratio = entry.size.toDouble() / entry.compressedSize.toDouble()
            if (ratio > limits.maxInflationRatio) {
                reject(XlsxRejectionCode.SUSPICIOUS_COMPRESSION_RATIO)
            }
        }
    }

    private fun validateInflatedContent(
        zip: ZipFile,
        entry: ZipArchiveEntry,
    ): Long {
        val crc = CRC32()
        var observed = 0L
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        zip.getInputStream(entry).use { input ->
            while (true) {
                deadline.check()
                val read = input.read(buffer)
                if (read < 0) break
                observed = addWithoutOverflow(observed, read.toLong())
                if (observed > limits.maxInflatedEntryBytes) {
                    reject(XlsxRejectionCode.ZIP_ENTRY_TOO_LARGE)
                }
                crc.update(buffer, 0, read)
            }
        }
        if (observed != entry.size || (entry.crc >= 0 && crc.value != entry.crc)) {
            reject(XlsxRejectionCode.CORRUPT_PACKAGE)
        }
        return observed
    }

    private fun inspectXml(
        entryName: String,
        input: InputStream,
        facts: PackageFacts,
    ) {
        val factory = SAXParserFactory.newInstance().apply {
            isNamespaceAware = true
            isXIncludeAware = false
            setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true)
            setFeature(DISALLOW_DOCTYPE, true)
            setFeature(EXTERNAL_GENERAL_ENTITIES, false)
            setFeature(EXTERNAL_PARAMETER_ENTITIES, false)
            setFeature(LOAD_EXTERNAL_DTD, false)
        }
        val reader = factory.newSAXParser().xmlReader.apply {
            setProperty(XMLConstants.ACCESS_EXTERNAL_DTD, "")
            setProperty(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "")
            entityResolver = org.xml.sax.EntityResolver { _, _ ->
                throw SAXException("External entities are forbidden")
            }
            errorHandler = ThrowingErrorHandler
            contentHandler = PackageSecurityHandler(entryName, limits, deadline, facts)
        }
        reader.parse(InputSource(ForbiddenXmlDeclarationInputStream(input)))
    }

    private fun rejectKnownUnsafePart(caseFoldedName: String) {
        if (caseFoldedName.startsWith("xl/chartsheets/")) {
            reject(XlsxRejectionCode.UNSUPPORTED_SHEET_TYPE)
        }
        if (
            caseFoldedName.endsWith(".bin") ||
            caseFoldedName.startsWith("customui/") ||
            UNSAFE_ACTIVE_PREFIXES.any(caseFoldedName::startsWith) ||
            UNSAFE_ACTIVE_PARTS.contains(caseFoldedName)
        ) {
            reject(XlsxRejectionCode.ACTIVE_CONTENT)
        }
        if (
            UNSAFE_EXTERNAL_PREFIXES.any(caseFoldedName::startsWith) ||
            UNSAFE_EXTERNAL_PARTS.contains(caseFoldedName)
        ) {
            reject(XlsxRejectionCode.EXTERNAL_CONTENT)
        }
    }

    private fun requireCoreParts(entryNames: Set<String>) {
        if (!entryNames.containsAll(REQUIRED_CORE_PARTS)) {
            reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
        }
    }

    private fun isXmlPart(name: String): Boolean {
        val folded = name.lowercase(Locale.ROOT)
        return folded.endsWith(".xml") || folded.endsWith(".rels")
    }

    private fun addWithoutOverflow(left: Long, right: Long): Long {
        if (right < 0 || left > Long.MAX_VALUE - right) {
            reject(XlsxRejectionCode.CORRUPT_PACKAGE)
        }
        return left + right
    }

    private class PackageSecurityHandler(
        private val entryName: String,
        private val limits: XlsxImportLimits,
        private val deadline: XlsxDeadline,
        private val facts: PackageFacts,
    ) : DefaultHandler() {
        private val foldedEntryName = entryName.lowercase(Locale.ROOT)
        private val isWorksheetPart =
            foldedEntryName.startsWith("xl/worksheets/") && foldedEntryName.endsWith(".xml")
        private val relationshipIds = mutableSetOf<String>()
        private var insideSharedString = false
        private var insideSharedStringText = false
        private var sharedStringCharacters = 0
        private var insideWorksheetCell = false
        private var worksheetCellUsesSharedString = false
        private var worksheetCellValueSeen = false
        private var worksheetCellTextCharacters = 0
        private var activeWorksheetTextElement: String? = null
        private var activeWorksheetTextCharacters = 0
        private val sharedStringIndexText = StringBuilder()
        private var xmlDepth = 0
        private var requiredRootSeen = false

        override fun startElement(
            uri: String?,
            localName: String?,
            qName: String?,
            attributes: Attributes,
        ) {
            deadline.check()
            for (index in 0 until attributes.length) {
                if (attributes.getValue(index).length > limits.maxCellCharacters) {
                    reject(XlsxRejectionCode.CELL_TEXT_TOO_LONG)
                }
            }
            val elementName = localName?.takeIf(String::isNotEmpty) ?: qName.orEmpty().substringAfter(':')
            inspectDocumentRoot(elementName)
            validateElementNamespace(uri.orEmpty())
            xmlDepth = Math.addExact(xmlDepth, 1)

            when {
                foldedEntryName == "[content_types].xml" -> inspectContentType(elementName, attributes)
                foldedEntryName.endsWith(".rels") -> inspectRelationship(elementName, attributes)
                foldedEntryName == "xl/workbook.xml" -> inspectWorkbook(elementName, attributes)
                foldedEntryName.startsWith("xl/worksheets/") -> inspectWorksheet(elementName, attributes)
            }
            if (foldedEntryName == "xl/sharedstrings.xml") {
                inspectSharedStringsStart(elementName)
            }
            if (isWorksheetPart) {
                inspectWorksheetTextStart(elementName, attributes)
            }
            if (
                foldedEntryName == "xl/styles.xml" &&
                STYLE_RECORD_ELEMENTS.contains(elementName)
            ) {
                facts.styleRecordCount = Math.addExact(facts.styleRecordCount, 1L)
                if (facts.styleRecordCount > limits.maxStyleRecords) {
                    reject(XlsxRejectionCode.TOO_MANY_STYLE_RECORDS)
                }
            }
        }

        override fun characters(
            ch: CharArray,
            start: Int,
            length: Int,
        ) {
            deadline.check()
            if (length == 0) return
            if (insideSharedStringText) {
                sharedStringCharacters = Math.addExact(sharedStringCharacters, length)
                if (sharedStringCharacters > limits.maxCellCharacters) {
                    reject(XlsxRejectionCode.CELL_TEXT_TOO_LONG)
                }
                addSourceTextCharacters(length)
            }
            if (activeWorksheetTextElement != null) {
                activeWorksheetTextCharacters = Math.addExact(activeWorksheetTextCharacters, length)
                if (activeWorksheetTextCharacters > limits.maxCellCharacters) {
                    reject(XlsxRejectionCode.CELL_TEXT_TOO_LONG)
                }
                if (insideWorksheetCell) {
                    worksheetCellTextCharacters = Math.addExact(worksheetCellTextCharacters, length)
                    if (worksheetCellTextCharacters > limits.maxCellCharacters) {
                        reject(XlsxRejectionCode.CELL_TEXT_TOO_LONG)
                    }
                }
                if (activeWorksheetTextElement == "v" && worksheetCellUsesSharedString) {
                    sharedStringIndexText.append(ch, start, length)
                }
                addSourceTextCharacters(length)
            }
        }

        override fun endElement(
            uri: String?,
            localName: String?,
            qName: String?,
        ) {
            val elementName = localName?.takeIf(String::isNotEmpty) ?: qName.orEmpty().substringAfter(':')
            if (foldedEntryName == "xl/sharedstrings.xml") {
                inspectSharedStringsEnd(elementName)
            }
            if (isWorksheetPart) {
                inspectWorksheetTextEnd(elementName)
            }
            xmlDepth = Math.subtractExact(xmlDepth, 1)
            if (xmlDepth < 0) reject(XlsxRejectionCode.CORRUPT_PACKAGE)
        }

        override fun endDocument() {
            if (
                insideSharedString ||
                insideSharedStringText ||
                insideWorksheetCell ||
                activeWorksheetTextElement != null ||
                xmlDepth != 0 ||
                (requiredRootElement() != null && !requiredRootSeen)
            ) {
                reject(XlsxRejectionCode.CORRUPT_PACKAGE)
            }
        }

        private fun inspectDocumentRoot(elementName: String) {
            val requiredRoot = requiredRootElement() ?: return
            if (xmlDepth != 0) {
                if (elementName == requiredRoot) {
                    reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                }
                return
            }
            if (requiredRootSeen || elementName != requiredRoot) {
                reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
            }
            requiredRootSeen = true
        }

        private fun requiredRootElement(): String? = when {
            foldedEntryName == "[content_types].xml" -> "Types"
            foldedEntryName.endsWith(".rels") -> "Relationships"
            foldedEntryName == "xl/workbook.xml" -> "workbook"
            isWorksheetPart -> "worksheet"
            foldedEntryName == "xl/sharedstrings.xml" -> "sst"
            foldedEntryName == "xl/styles.xml" -> "styleSheet"
            CANONICAL_THEME_PART.matches(foldedEntryName) -> "theme"
            else -> null
        }

        private fun validateElementNamespace(namespaceUri: String) {
            val valid = when {
                foldedEntryName == "[content_types].xml" -> namespaceUri == PACKAGE_CONTENT_TYPES_NAMESPACE
                foldedEntryName.endsWith(".rels") -> namespaceUri == PACKAGE_RELATIONSHIPS_NAMESPACE
                foldedEntryName == "xl/workbook.xml" ||
                    foldedEntryName == "xl/sharedstrings.xml" ||
                    foldedEntryName == "xl/styles.xml" ||
                    isWorksheetPart -> namespaceUri == SPREADSHEET_NAMESPACE
                CANONICAL_THEME_PART.matches(foldedEntryName) -> namespaceUri == DRAWING_NAMESPACE
                else -> true
            }
            if (!valid) reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
        }

        private fun inspectSharedStringsStart(elementName: String) {
            when (elementName) {
                "si" -> {
                    if (insideSharedString || insideSharedStringText) {
                        reject(XlsxRejectionCode.CORRUPT_PACKAGE)
                    }
                    insideSharedString = true
                    sharedStringCharacters = 0
                    facts.sharedStringCount = Math.addExact(facts.sharedStringCount, 1L)
                    val maximumPossibleCells = Math.multiplyExact(
                        limits.maxSemanticRows.toLong(),
                        limits.maxColumns.toLong(),
                    )
                    val effectiveSharedStringLimit = minOf(
                        limits.maxSharedStringItems.toLong(),
                        maximumPossibleCells,
                    )
                    if (facts.sharedStringCount > effectiveSharedStringLimit) {
                        reject(XlsxRejectionCode.TOO_MANY_SHARED_STRINGS)
                    }
                }
                "t" -> {
                    if (!insideSharedString || insideSharedStringText) {
                        reject(XlsxRejectionCode.CORRUPT_PACKAGE)
                    }
                    insideSharedStringText = true
                }
            }
        }

        private fun inspectSharedStringsEnd(elementName: String) {
            when (elementName) {
                "t" -> {
                    if (!insideSharedString || !insideSharedStringText) {
                        reject(XlsxRejectionCode.CORRUPT_PACKAGE)
                    }
                    insideSharedStringText = false
                }
                "si" -> {
                    if (!insideSharedString || insideSharedStringText) {
                        reject(XlsxRejectionCode.CORRUPT_PACKAGE)
                    }
                    insideSharedString = false
                }
            }
        }

        private fun inspectWorksheetTextStart(
            elementName: String,
            attributes: Attributes,
        ) {
            when {
                elementName == "c" -> {
                    if (insideWorksheetCell || activeWorksheetTextElement != null) {
                        reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
                    }
                    insideWorksheetCell = true
                    worksheetCellUsesSharedString = attributes.value("t") == "s"
                    worksheetCellValueSeen = false
                    worksheetCellTextCharacters = 0
                }
                elementName in CELL_BUFFERED_TEXT_ELEMENTS -> {
                    if (!insideWorksheetCell || activeWorksheetTextElement != null) {
                        reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
                    }
                    if (elementName == "v" && worksheetCellValueSeen) {
                        reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
                    }
                    if (elementName == "t" && worksheetCellUsesSharedString) {
                        reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
                    }
                    if (elementName == "v") worksheetCellValueSeen = true
                    activeWorksheetTextElement = elementName
                    activeWorksheetTextCharacters = 0
                    sharedStringIndexText.setLength(0)
                }
                elementName in HEADER_FOOTER_TEXT_ELEMENTS -> {
                    if (insideWorksheetCell || activeWorksheetTextElement != null) {
                        reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
                    }
                    activeWorksheetTextElement = elementName
                    activeWorksheetTextCharacters = 0
                }
            }
        }

        private fun inspectWorksheetTextEnd(elementName: String) {
            when {
                elementName in POI_BUFFERED_WORKSHEET_TEXT_ELEMENTS -> {
                    if (activeWorksheetTextElement != elementName) {
                        reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
                    }
                    if (elementName == "v" && worksheetCellUsesSharedString) {
                        val indexText = sharedStringIndexText.toString()
                        val index = indexText.takeIf(SHARED_STRING_INDEX::matches)?.toIntOrNull()
                            ?: reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
                        facts.maximumSharedStringReference = maxOf(
                            facts.maximumSharedStringReference,
                            index,
                        )
                    }
                    activeWorksheetTextElement = null
                    activeWorksheetTextCharacters = 0
                    sharedStringIndexText.setLength(0)
                }
                elementName == "c" -> {
                    if (
                        !insideWorksheetCell ||
                        activeWorksheetTextElement != null ||
                        (worksheetCellUsesSharedString && !worksheetCellValueSeen)
                    ) {
                        reject(XlsxRejectionCode.MALFORMED_WORKSHEET)
                    }
                    insideWorksheetCell = false
                    worksheetCellUsesSharedString = false
                    worksheetCellValueSeen = false
                    worksheetCellTextCharacters = 0
                }
            }
        }

        private fun addSourceTextCharacters(length: Int) {
            facts.sourceTextCharacters = Math.addExact(facts.sourceTextCharacters, length.toLong())
            if (facts.sourceTextCharacters > limits.maxTotalTextCharacters) {
                reject(XlsxRejectionCode.TOTAL_TEXT_SIZE_EXCEEDED)
            }
        }

        private fun inspectContentType(
            elementName: String,
            attributes: Attributes,
        ) {
            if (elementName != "Override" && elementName != "Default") return
            val contentType = attributes.value("ContentType")?.trim()
                ?.takeIf(String::isNotEmpty)
                ?: reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
            val foldedContentType = contentType.lowercase(Locale.ROOT)
            if (ACTIVE_CONTENT_TYPE_MARKERS.any(foldedContentType::contains)) {
                reject(XlsxRejectionCode.ACTIVE_CONTENT)
            }
            if (EXTERNAL_CONTENT_TYPE_MARKERS.any(foldedContentType::contains)) {
                reject(XlsxRejectionCode.EXTERNAL_CONTENT)
            }
            val extension = attributes.value("Extension")?.trim()
            if (elementName == "Default" && extension?.equals("bin", true) == true) {
                reject(XlsxRejectionCode.ACTIVE_CONTENT)
            }
            val partName = attributes.value("PartName")?.trim()
            if (elementName == "Override") {
                if (partName == null) reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                if (!partName.startsWith('/') || partName.length == 1) {
                    reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                }
                val normalizedPartName = Normalizer.normalize(partName, Normalizer.Form.NFC)
                if (!facts.contentTypeOverrideIdentities.add(unicodeCaseFold(normalizedPartName))) {
                    reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                }
                facts.explicitContentTypeParts += normalizedPartName.removePrefix("/")
            } else {
                val normalizedExtension = extension?.lowercase(Locale.ROOT)
                    ?.takeIf(String::isNotEmpty)
                    ?: reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                if (!facts.contentTypeDefaultExtensions.add(normalizedExtension)) {
                    reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                }
            }
            if (partName == "/xl/workbook.xml") {
                facts.workbookContentTypeCount += 1
                if (contentType != XLSX_WORKBOOK_CONTENT_TYPE) {
                    reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                }
            }
            if (
                elementName == "Default" &&
                attributes.value("Extension")?.equals("xml", ignoreCase = true) == true &&
                contentType == XLSX_WORKBOOK_CONTENT_TYPE
            ) {
                facts.workbookDefaultContentTypeCount += 1
            }
            if (partName != null && partName.startsWith("/xl/worksheets/")) {
                val normalizedPartName = partName.removePrefix("/")
                if (
                    !CANONICAL_WORKSHEET_PART.matches(normalizedPartName) ||
                    contentType != XLSX_WORKSHEET_CONTENT_TYPE ||
                    !facts.worksheetContentTypeTargets.add(normalizedPartName)
                ) {
                    reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                }
            }
            when (contentType) {
                XLSX_SHARED_STRINGS_CONTENT_TYPE -> {
                    if (partName != "/xl/sharedStrings.xml") {
                        reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                    }
                    facts.sharedStringsContentTypeCount += 1
                }
                XLSX_STYLES_CONTENT_TYPE -> {
                    if (partName != "/xl/styles.xml") {
                        reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                    }
                    facts.stylesContentTypeCount += 1
                }
                XLSX_THEME_CONTENT_TYPE -> {
                    val normalizedPartName = partName?.removePrefix("/")
                        ?: reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                    if (
                        !CANONICAL_THEME_PART.matches(normalizedPartName) ||
                        !facts.themeContentTypeTargets.add(normalizedPartName)
                    ) {
                        reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                    }
                }
            }
        }

        private fun inspectRelationship(
            elementName: String,
            attributes: Attributes,
        ) {
            if (elementName != "Relationship") return
            val targetMode = attributes.value("TargetMode")?.trim()
            if (targetMode?.equals("External", ignoreCase = true) == true) {
                reject(XlsxRejectionCode.EXTERNAL_CONTENT)
            }
            val type = attributes.value("Type")?.trim()
                ?.takeIf(String::isNotEmpty)
                ?: reject(XlsxRejectionCode.CORRUPT_PACKAGE)
            val foldedType = type.lowercase(Locale.ROOT)
            if (
                UNSAFE_RELATIONSHIP_MARKERS.any(foldedType::contains) ||
                foldedType.endsWith("/package")
            ) {
                reject(XlsxRejectionCode.EXTERNAL_CONTENT)
            }
            val target = attributes.value("Target")?.trim()
                ?.takeIf(String::isNotEmpty)
                ?: reject(XlsxRejectionCode.CORRUPT_PACKAGE)
            if (target.indexOf('\u0000') >= 0 || '\\' in target) {
                reject(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME)
            }
            val resolved = resolveInternalRelationshipTarget(entryName, target)
            val relationshipId = attributes.value("Id")?.trim()
                ?.takeIf(String::isNotEmpty)
                ?: reject(XlsxRejectionCode.CORRUPT_PACKAGE)
            if (!relationshipIds.add(relationshipId)) {
                reject(XlsxRejectionCode.CORRUPT_PACKAGE)
            }
            when {
                type in WORKSHEET_RELATIONSHIP_TYPES -> {
                    if (
                        foldedEntryName != "xl/_rels/workbook.xml.rels" ||
                        !CANONICAL_WORKSHEET_PART.matches(resolved)
                    ) {
                        reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                    }
                    if (!facts.worksheetRelationshipIds.add(relationshipId)) {
                        reject(XlsxRejectionCode.CORRUPT_PACKAGE)
                    }
                    if (!facts.worksheetTargets.add(resolved)) {
                        reject(XlsxRejectionCode.CORRUPT_PACKAGE)
                    }
                }
                type in SHARED_STRINGS_RELATIONSHIP_TYPES -> {
                    if (
                        foldedEntryName != "xl/_rels/workbook.xml.rels" ||
                        resolved != "xl/sharedStrings.xml"
                    ) {
                        reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                    }
                    facts.sharedStringsRelationshipCount += 1
                }
                type in STYLES_RELATIONSHIP_TYPES -> {
                    if (
                        foldedEntryName != "xl/_rels/workbook.xml.rels" ||
                        resolved != "xl/styles.xml"
                    ) {
                        reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                    }
                    facts.stylesRelationshipCount += 1
                }
                type in THEME_RELATIONSHIP_TYPES -> {
                    if (
                        foldedEntryName != "xl/_rels/workbook.xml.rels" ||
                        !CANONICAL_THEME_PART.matches(resolved) ||
                        !facts.themeRelationshipTargets.add(resolved)
                    ) {
                        reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                    }
                }
                type in OFFICE_DOCUMENT_RELATIONSHIP_TYPES -> {
                    if (
                        foldedEntryName != "_rels/.rels" ||
                        resolved != "xl/workbook.xml"
                    ) {
                        reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                    }
                    facts.officeDocumentRelationshipCount += 1
                }
                type in UNSUPPORTED_SHEET_RELATIONSHIP_TYPES -> {
                    reject(XlsxRejectionCode.UNSUPPORTED_SHEET_TYPE)
                }
                RESERVED_RELATIONSHIP_SUFFIXES.any(foldedType::endsWith) -> {
                    reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
                }
            }
        }

        private fun inspectWorkbook(
            elementName: String,
            attributes: Attributes,
        ) {
            if (elementName == "externalReferences") {
                reject(XlsxRejectionCode.EXTERNAL_CONTENT)
            }
            if (elementName != "sheet") return
            facts.sheetCount += 1
            if (facts.sheetCount > limits.maxSheets) {
                reject(XlsxRejectionCode.TOO_MANY_SHEETS)
            }
            val relationshipId = attributes.value("id") ?: reject(XlsxRejectionCode.CORRUPT_PACKAGE)
            if (!facts.workbookSheetRelationshipIds.add(relationshipId)) {
                reject(XlsxRejectionCode.CORRUPT_PACKAGE)
            }
            val state = attributes.value("state")
            if (state != null && !state.equals("visible", ignoreCase = true)) {
                reject(XlsxRejectionCode.HIDDEN_SHEET)
            }
            val sheetName = attributes.value("name") ?: reject(XlsxRejectionCode.INVALID_SHEET_NAME)
            if (
                sheetName.isBlank() || sheetName.codePointCount(0, sheetName.length) > 31 ||
                sheetName.any { it in INVALID_EXCEL_SHEET_NAME_CHARACTERS } ||
                sheetName.startsWith('\'') || sheetName.endsWith('\'')
            ) reject(XlsxRejectionCode.INVALID_SHEET_NAME)
        }

        private fun inspectWorksheet(
            elementName: String,
            attributes: Attributes,
        ) {
            when (elementName) {
                "f" -> reject(XlsxRejectionCode.FORMULA_CELL)
                "row" -> {
                    if (attributes.isTrue("hidden") || attributes.isZero("ht")) {
                        reject(XlsxRejectionCode.HIDDEN_ROW)
                    }
                }
                "col" -> {
                    if (attributes.isTrue("hidden") || attributes.isZero("width")) {
                        reject(XlsxRejectionCode.HIDDEN_COLUMN)
                    }
                }
                "sheetFormatPr" -> {
                    if (attributes.isTrue("zeroHeight") || attributes.isZero("defaultRowHeight")) {
                        reject(XlsxRejectionCode.HIDDEN_ROW)
                    }
                    if (attributes.isZero("defaultColWidth")) {
                        reject(XlsxRejectionCode.HIDDEN_COLUMN)
                    }
                }
                "oleObjects", "controls", "legacyDrawing", "legacyDrawingHF" -> {
                    reject(XlsxRejectionCode.ACTIVE_CONTENT)
                }
                "c" -> {
                    val reference = attributes.value("r") ?: reject(XlsxRejectionCode.INVALID_CELL_REFERENCE)
                    val column = parseColumnNumber(reference)
                    if (column > limits.maxColumns) reject(XlsxRejectionCode.TOO_MANY_COLUMNS)
                }
            }
        }

        private fun Attributes.value(name: String): String? =
            getValue(name) ?: (0 until length)
                .firstOrNull { getLocalName(it) == name }
                ?.let(::getValue)

        private fun Attributes.isTrue(name: String): Boolean =
            when (value(name)?.trim()?.lowercase(Locale.ROOT)) {
                "1", "true" -> true
                else -> false
            }

        private fun Attributes.isZero(name: String): Boolean =
            value(name)?.trim()?.toBigDecimalOrNull()?.compareTo(java.math.BigDecimal.ZERO) == 0
    }

    private data class PackageFacts(
        var workbookContentTypeCount: Int = 0,
        var workbookDefaultContentTypeCount: Int = 0,
        var officeDocumentRelationshipCount: Int = 0,
        var sheetCount: Int = 0,
        var sourceTextCharacters: Long = 0,
        var sharedStringCount: Long = 0,
        var styleRecordCount: Long = 0,
        var sharedStringsRelationshipCount: Int = 0,
        var stylesRelationshipCount: Int = 0,
        var sharedStringsContentTypeCount: Int = 0,
        var stylesContentTypeCount: Int = 0,
        var maximumSharedStringReference: Int = -1,
        val worksheetRelationshipIds: MutableSet<String> = mutableSetOf(),
        val workbookSheetRelationshipIds: MutableSet<String> = mutableSetOf(),
        val worksheetTargets: MutableSet<String> = mutableSetOf(),
        val worksheetContentTypeTargets: MutableSet<String> = mutableSetOf(),
        val themeRelationshipTargets: MutableSet<String> = mutableSetOf(),
        val themeContentTypeTargets: MutableSet<String> = mutableSetOf(),
        val explicitContentTypeParts: MutableSet<String> = mutableSetOf(),
        val contentTypeOverrideIdentities: MutableSet<String> = mutableSetOf(),
        val contentTypeDefaultExtensions: MutableSet<String> = mutableSetOf(),
    ) {
        fun validate(entryNames: Set<String>) {
            val worksheetParts = entryNames.filterTo(mutableSetOf()) {
                CANONICAL_WORKSHEET_PART.matches(it)
            }
            val hasSharedStringsPart = "xl/sharedStrings.xml" in entryNames
            val hasStylesPart = "xl/styles.xml" in entryNames
            val themeParts = entryNames.filterTo(mutableSetOf()) {
                CANONICAL_THEME_PART.matches(it)
            }
            if (
                !workbookContentTypeIsSafelyBound(entryNames) ||
                officeDocumentRelationshipCount != 1 ||
                sheetCount < 1 ||
                worksheetRelationshipIds != workbookSheetRelationshipIds ||
                worksheetTargets != worksheetParts ||
                worksheetContentTypeTargets != worksheetTargets ||
                sheetCount != worksheetTargets.size ||
                !optionalPartIsExactlyBound(
                    hasSharedStringsPart,
                    sharedStringsRelationshipCount,
                    sharedStringsContentTypeCount,
                ) ||
                !optionalPartIsExactlyBound(
                    hasStylesPart,
                    stylesRelationshipCount,
                    stylesContentTypeCount,
                ) ||
                maximumSharedStringReference.toLong() >= sharedStringCount ||
                themeRelationshipTargets != themeParts ||
                themeContentTypeTargets != themeParts ||
                themeParts.size > 1
            ) {
                reject(XlsxRejectionCode.INVALID_PACKAGE_TYPE)
            }
        }

        private fun workbookContentTypeIsSafelyBound(entryNames: Set<String>): Boolean {
            if (workbookContentTypeCount == 1 && workbookDefaultContentTypeCount == 0) return true
            if (workbookContentTypeCount != 0 || workbookDefaultContentTypeCount != 1) return false
            val partsUsingDefaultXmlType = entryNames
                .asSequence()
                .filter { it.endsWith(".xml", ignoreCase = true) }
                .filterNot { it == "[Content_Types].xml" }
                .filterNot(explicitContentTypeParts::contains)
                .toSet()
            return partsUsingDefaultXmlType == setOf("xl/workbook.xml")
        }

        private fun optionalPartIsExactlyBound(
            partExists: Boolean,
            relationshipCount: Int,
            contentTypeCount: Int,
        ): Boolean =
            if (partExists) {
                relationshipCount == 1 && contentTypeCount == 1
            } else {
                relationshipCount == 0 && contentTypeCount == 0
            }
    }

    private object ThrowingErrorHandler : org.xml.sax.ErrorHandler {
        override fun warning(exception: SAXParseException) = Unit

        override fun error(exception: SAXParseException): Nothing = throw exception

        override fun fatalError(exception: SAXParseException): Nothing = throw exception
    }

    companion object {
        private const val DISALLOW_DOCTYPE = "http://apache.org/xml/features/disallow-doctype-decl"
        private const val EXTERNAL_GENERAL_ENTITIES = "http://xml.org/sax/features/external-general-entities"
        private const val EXTERNAL_PARAMETER_ENTITIES = "http://xml.org/sax/features/external-parameter-entities"
        private const val LOAD_EXTERNAL_DTD = "http://apache.org/xml/features/nonvalidating/load-external-dtd"
        private const val XLSX_WORKBOOK_CONTENT_TYPE =
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"
        private const val XLSX_WORKSHEET_CONTENT_TYPE =
            "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"
        private const val XLSX_SHARED_STRINGS_CONTENT_TYPE =
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"
        private const val XLSX_STYLES_CONTENT_TYPE =
            "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"
        private const val XLSX_THEME_CONTENT_TYPE =
            "application/vnd.openxmlformats-officedocument.theme+xml"

        private val DRIVE_PREFIX = Regex("^[A-Za-z]:")
        private val REQUIRED_CORE_PARTS = setOf(
            "[Content_Types].xml",
            "_rels/.rels",
            "xl/workbook.xml",
            "xl/_rels/workbook.xml.rels",
        )
        private val WORKBOOK_METADATA_PARTS = REQUIRED_CORE_PARTS
        private val UNSAFE_ACTIVE_PREFIXES = listOf(
            "xl/activex/",
            "xl/ctrlprops/",
            "xl/dialogsheets/",
            "xl/embeddings/",
            "xl/macrosheets/",
            "xl/oleobjects/",
        )
        private val UNSAFE_ACTIVE_PARTS = setOf(
            "xl/vbaproject.bin",
            "xl/vbadata.xml",
        )
        private val UNSAFE_EXTERNAL_PREFIXES = listOf(
            "xl/externallinks/",
            "xl/querytables/",
            "xl/model/",
        )
        private val UNSAFE_EXTERNAL_PARTS = setOf(
            "xl/connections.xml",
        )
        private val ACTIVE_CONTENT_TYPE_MARKERS = listOf(
            "macroenabled",
            "vba",
            "activex",
            "oleobject",
            "ms-office.package",
        )
        private val EXTERNAL_CONTENT_TYPE_MARKERS = listOf(
            "externallink",
            "connections",
            "querytable",
        )
        private val UNSAFE_RELATIONSHIP_MARKERS = listOf(
            "/externallink",
            "/externalconnection",
            "/connections",
            "/querytable",
            "/oleobject",
            "/activex",
            "/vbaproject",
        )
        private const val PACKAGE_CONTENT_TYPES_NAMESPACE =
            "http://schemas.openxmlformats.org/package/2006/content-types"
        private const val PACKAGE_RELATIONSHIPS_NAMESPACE =
            "http://schemas.openxmlformats.org/package/2006/relationships"
        private const val SPREADSHEET_NAMESPACE =
            "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        private const val DRAWING_NAMESPACE =
            "http://schemas.openxmlformats.org/drawingml/2006/main"
        private const val TRANSITIONAL_OFFICE_RELATIONSHIP_BASE =
            "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        private const val STRICT_OFFICE_RELATIONSHIP_BASE =
            "http://purl.oclc.org/ooxml/officeDocument/relationships"
        private fun officeRelationshipTypes(suffix: String): Set<String> = setOf(
            "$TRANSITIONAL_OFFICE_RELATIONSHIP_BASE/$suffix",
            "$STRICT_OFFICE_RELATIONSHIP_BASE/$suffix",
        )
        private val WORKSHEET_RELATIONSHIP_TYPES = officeRelationshipTypes("worksheet")
        private val SHARED_STRINGS_RELATIONSHIP_TYPES = officeRelationshipTypes("sharedStrings")
        private val STYLES_RELATIONSHIP_TYPES = officeRelationshipTypes("styles")
        private val THEME_RELATIONSHIP_TYPES = officeRelationshipTypes("theme")
        private val OFFICE_DOCUMENT_RELATIONSHIP_TYPES = officeRelationshipTypes("officeDocument")
        private val UNSUPPORTED_SHEET_RELATIONSHIP_TYPES = setOf(
            *officeRelationshipTypes("chartsheet").toTypedArray(),
            *officeRelationshipTypes("dialogsheet").toTypedArray(),
            *officeRelationshipTypes("macrosheet").toTypedArray(),
        )
        private val RESERVED_RELATIONSHIP_SUFFIXES = setOf(
            "/worksheet",
            "/sharedstrings",
            "/styles",
            "/theme",
            "/officedocument",
            "/chartsheet",
            "/dialogsheet",
            "/macrosheet",
        )
        private val CELL_BUFFERED_TEXT_ELEMENTS = setOf("v", "t")
        private val HEADER_FOOTER_TEXT_ELEMENTS = setOf(
            "oddHeader",
            "oddFooter",
            "evenHeader",
            "evenFooter",
            "firstHeader",
            "firstFooter",
        )
        private val POI_BUFFERED_WORKSHEET_TEXT_ELEMENTS =
            CELL_BUFFERED_TEXT_ELEMENTS + HEADER_FOOTER_TEXT_ELEMENTS
        private val SHARED_STRING_INDEX = Regex("^[0-9]+$")
        private val CANONICAL_WORKSHEET_PART = Regex("^xl/worksheets/[^/]+[.]xml$")
        private val CANONICAL_THEME_PART = Regex("^xl/theme/theme[1-9][0-9]*[.]xml$")
        private val STYLE_RECORD_ELEMENTS = setOf(
            "numFmt",
            "font",
            "fill",
            "border",
            "xf",
            "cellStyle",
            "dxf",
            "tableStyle",
        )
    }
}

private fun resolveInternalRelationshipTarget(
    relationshipPartName: String,
    rawTarget: String,
): String {
    val withoutFragment = rawTarget.substringBefore('#').substringBefore('?')
    if (withoutFragment.isEmpty()) reject(XlsxRejectionCode.CORRUPT_PACKAGE)
    val uri = try {
        java.net.URI(withoutFragment)
    } catch (_: java.net.URISyntaxException) {
        throw XlsxRejectedException(XlsxRejectionCode.CORRUPT_PACKAGE)
    }
    if (uri.isAbsolute || uri.rawAuthority != null) {
        reject(XlsxRejectionCode.EXTERNAL_CONTENT)
    }
    val decodedPath = uri.path ?: reject(XlsxRejectionCode.CORRUPT_PACKAGE)
    val base = when {
        relationshipPartName == "_rels/.rels" -> emptyList()
        "/_rels/" in relationshipPartName -> {
            val prefix = relationshipPartName.substringBefore("/_rels/")
            val ownerFile = relationshipPartName.substringAfterLast('/').removeSuffix(".rels")
            (if (prefix.isEmpty()) emptyList() else prefix.split('/')) + ownerFile
        }
        else -> reject(XlsxRejectionCode.CORRUPT_PACKAGE)
    }.dropLast(1)

    val result = if (decodedPath.startsWith('/')) mutableListOf() else base.toMutableList()
    decodedPath.trimStart('/').split('/').forEach { segment ->
        when (segment) {
            "", "." -> Unit
            ".." -> if (result.isEmpty()) {
                reject(XlsxRejectionCode.INVALID_ZIP_ENTRY_NAME)
            } else {
                result.removeAt(result.lastIndex)
            }
            else -> result += segment
        }
    }
    if (result.isEmpty()) reject(XlsxRejectionCode.CORRUPT_PACKAGE)
    return Normalizer.normalize(result.joinToString("/"), Normalizer.Form.NFC)
}

private fun unicodeCaseFold(value: String): String =
    Normalizer.normalize(
        value.uppercase(Locale.ROOT).lowercase(Locale.ROOT),
        Normalizer.Form.NFC,
    )

internal fun parseColumnNumber(reference: String): Int {
    if (!CELL_REFERENCE.matches(reference)) reject(XlsxRejectionCode.INVALID_CELL_REFERENCE)
    val rowNumber = reference.dropWhile(Char::isLetter).toIntOrNull()
        ?: reject(XlsxRejectionCode.INVALID_CELL_REFERENCE)
    if (rowNumber !in 1..MAX_XLSX_ROW_NUMBER) reject(XlsxRejectionCode.INVALID_CELL_REFERENCE)
    var result = 0
    reference.takeWhile(Char::isLetter).forEach { letter ->
        result = Math.addExact(Math.multiplyExact(result, 26), letter.code - 'A'.code + 1)
    }
    return result
}

internal fun reject(code: XlsxRejectionCode): Nothing = throw XlsxRejectedException(code)

private val CELL_REFERENCE = Regex("^[A-Z]{1,3}[1-9][0-9]{0,6}$")
private const val MAX_XLSX_ROW_NUMBER = 1_048_576
private val INVALID_EXCEL_SHEET_NAME_CHARACTERS = setOf('\\', '/', '?', '*', '[', ']', ':')
