package kwz.love2d.launcher.util

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import kwz.love2d.launcher.model.LoveGame
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.util.Locale

object LoveMetadataParser {

    private const val MAX_METADATA_BYTES = 1024 * 1024
    private const val MAX_ICON_BYTES = 2 * 1024 * 1024
    private const val MAX_ICON_DIMENSION = 192
    private const val MAX_PREVIEW_BYTES = 8 * 1024 * 1024
    private const val MAX_PREVIEW_DIMENSION = 640
    private const val MAX_ENTRY_COUNT = 50_000
    private const val MAX_MOD_CANDIDATES = 256
    private const val MAX_SOURCE_ICON_DIMENSION = 16_384
    private val PLACEHOLDER_TITLES = setOf(
        "example mod",
        "exemple mod",
        "example project",
        "exemple project"
    )

    fun parseLoveFiles(
        context: Context,
        uri: Uri,
        fileName: String,
        sizeBytes: Long,
        lastModified: Long
    ): List<LoveGame> {
        parseLoveFile(context, uri, fileName, sizeBytes, lastModified)?.let { return listOf(it) }
        return NestedGamePackageParser.parsePackages(
            context = context,
            sourceUri = uri,
            sourceName = fileName,
            sourceSizeBytes = sizeBytes,
            sourceLastModified = lastModified
        )
    }

    fun parseLoveFile(
        context: Context,
        uri: Uri,
        fileName: String,
        sizeBytes: Long,
        lastModified: Long
    ): LoveGame? {
        return try {
            GameArchive.open(context, uri, fileName).use { archive ->
                parseArchive(archive, fileName, uri, sizeBytes, lastModified)
            }
        } catch (error: Exception) {
            error.printStackTrace()
            null
        }
    }

    internal fun parseLoveFile(
        file: File,
        fileName: String = file.name,
        sizeBytes: Long = file.length(),
        lastModified: Long = file.lastModified()
    ): LoveGame? {
        return try {
            GameArchive.open(file).use { archive ->
                parseArchive(
                    archive = archive,
                    fileName = fileName,
                    uri = Uri.fromFile(file),
                    sizeBytes = sizeBytes,
                    lastModified = lastModified
                )
            }
        } catch (error: Exception) {
            error.printStackTrace()
            null
        }
    }

    internal fun inspectArchive(
        file: File,
        fileName: String = file.name
    ): ParsedArchiveMetadata? {
        return GameArchive.open(file).use { archive ->
            readArchiveMetadata(archive, fileName)
        }
    }

    private fun parseArchive(
        archive: GameArchive,
        fileName: String,
        uri: Uri,
        sizeBytes: Long,
        lastModified: Long
    ): LoveGame? {
        val metadata = readArchiveMetadata(archive, fileName) ?: return null
        var selectedIcon: Bitmap? = null
        val selectedPreviews = mutableListOf<Bitmap>()
        try {
            selectedIcon = metadata.iconBytes?.let { decodeSampledBitmap(it, MAX_ICON_DIMENSION) }
            metadata.previewLayers.mapNotNullTo(selectedPreviews) {
                decodeSampledBitmap(it, MAX_PREVIEW_DIMENSION)
            }
            return LoveGame(
                title = metadata.title,
                fileName = fileName,
                uri = uri,
                icon = selectedIcon,
                previewBackgrounds = selectedPreviews.toList(),
                sizeBytes = sizeBytes,
                lastModified = lastModified,
                subtitle = metadata.subtitle,
                description = metadata.description,
                version = metadata.version,
                engineVer = metadata.engineVersion,
                author = metadata.author,
                projectId = metadata.projectId,
                chapter = metadata.chapter,
                startMap = metadata.startMap,
                party = metadata.party
            )
        } catch (error: Exception) {
            selectedIcon?.recycle()
            selectedPreviews.forEach(Bitmap::recycle)
            throw error
        }
    }

    private fun readArchiveMetadata(
        archive: GameArchive,
        fileName: String
    ): ParsedArchiveMetadata? {
        val entries = archive.entries(MAX_ENTRY_COUNT)
        if (entries.isEmpty()) return null

        val indexedEntries = entries.mapNotNull { entry ->
            val path = normalizeReadableArchivePath(entry.name) ?: return@mapNotNull null
            IndexedEntry(
                entry = entry,
                path = path
            )
        }

        val archivePaths = indexedEntries
            .filterNot { it.entry.isDirectory }
            .map(IndexedEntry::path)
        val gameRoot = LoveArchiveNormalizer.findGameRoot(archivePaths) ?: return null
        val modsPrefix = childPath(gameRoot, "mods/")

        val modCandidates = indexedEntries.asSequence()
            .filter { indexed ->
                if (indexed.entry.isDirectory || !indexed.path.startsWith(modsPrefix)) {
                    false
                } else {
                    val relativePath = indexed.path.removePrefix(modsPrefix)
                    relativePath.endsWith("/mod.json") && relativePath.count { it == '/' } == 1
                }
            }
            .take(MAX_MOD_CANDIDATES)
            .mapNotNull { indexed ->
                readEntryBytes(archive, indexed.entry, MAX_METADATA_BYTES)
                    ?.toString(Charsets.UTF_8)
                    ?.let(::parseModCandidate)
                    ?.copy(folder = indexed.path.substringBeforeLast('/'))
            }
            .toList()

        val confTitle = indexedEntries
            .find { it.path == childPath(gameRoot, "conf.lua") && !it.entry.isDirectory }
            ?.let { readEntryBytes(archive, it.entry, MAX_METADATA_BYTES) }
            ?.toString(Charsets.UTF_8)
            ?.let(::extractTitleFromConfLua)
            ?.takeUnless(::isIgnoredFallbackTitle)

        val targetModId = findTargetModId(archive, indexedEntries, gameRoot)
        val selectedMod = selectModCandidate(modCandidates, targetModId, confTitle)

        val iconEntry = selectedMod
            ?.let { findPreferredIcon(indexedEntries, it.folder) }
            ?: findPreferredIcon(indexedEntries, gameRoot)
        val iconBytes = iconEntry?.let { readEntryBytes(archive, it.entry, MAX_ICON_BYTES) }
        val previewEntry = selectedMod
            ?.let { findLargestPreviewBackground(indexedEntries, it.folder) }
            ?: selectedMod?.let {
                findPreviewScriptBackground(archive, indexedEntries, gameRoot, it.folder)
            }
            ?: selectedMod?.let {
                findEntry(indexedEntries, childPath(it.folder, DEFAULT_PREVIEW_BACKGROUND))
            }
            ?: findLargestPreviewBackground(indexedEntries, gameRoot)
            ?: indexedEntries.find {
                !it.entry.isDirectory &&
                    it.path == childPath(gameRoot, DEFAULT_PREVIEW_BACKGROUND)
            }
        val previewLayers = previewEntry
            ?.let { readEntryBytes(archive, it.entry, MAX_PREVIEW_BYTES) }
            ?.let(::listOf)
            .orEmpty()
        val cleanName = fileName.replace(Regex("(?i)\\.(love|zip|exe)$"), "")

        return ParsedArchiveMetadata(
            title = selectedMod?.name ?: confTitle ?: cleanName,
            subtitle = selectedMod?.subtitle,
            description = selectedMod?.description,
            version = selectedMod?.version,
            engineVersion = selectedMod?.engineVersion,
            author = selectedMod?.author,
            projectId = selectedMod?.id,
            chapter = selectedMod?.chapter,
            startMap = selectedMod?.startMap,
            party = selectedMod?.party.orEmpty(),
            iconBytes = iconBytes,
            previewLayers = previewLayers
        )
    }

    private fun parseModCandidate(content: String): ModCandidate? {
        return runCatching {
            val json = JSONObject(stripJsonComments(content.removePrefix("\uFEFF")))
            val name = json.optString("name").trim()
            if (name.isBlank()) return null
            ModCandidate(
                folder = "",
                id = json.optString("id").trim().takeIf(String::isNotBlank),
                name = name,
                subtitle = json.optString("subtitle").trim().takeIf(String::isNotBlank),
                description = json.optString("description").trim().takeIf(String::isNotBlank),
                version = json.optString("version").trim().takeIf(String::isNotBlank),
                engineVersion = json.optString("engineVer").trim().takeIf(String::isNotBlank),
                author = parseAuthor(json),
                chapter = json.opt("chapter")
                    ?.takeUnless { it == JSONObject.NULL }
                    ?.toString()
                    ?.trim()
                    ?.takeIf(String::isNotBlank),
                startMap = json.optString("map").trim().takeIf(String::isNotBlank),
                party = json.optJSONArray("party")?.let { members ->
                    buildList {
                        for (index in 0 until members.length()) {
                            members.optString(index).trim().takeIf(String::isNotBlank)?.let(::add)
                        }
                    }
                }.orEmpty(),
                hidden = json.optBoolean("hidden", false)
            )
        }.getOrNull()
    }

    private fun parseAuthor(json: JSONObject): String? {
        json.optString("author").trim().takeIf(String::isNotBlank)?.let { return it }
        return json.optJSONArray("authors")?.let { authors ->
            buildList {
                for (index in 0 until authors.length()) {
                    authors.optString(index).trim().takeIf(String::isNotBlank)?.let(::add)
                }
            }.joinToString(", ").takeIf(String::isNotBlank)
        }
    }

    private fun findTargetModId(
        archive: GameArchive,
        entries: List<IndexedEntry>,
        gameRoot: String
    ): String? {
        for (relativePath in TARGET_MOD_SOURCE_PATHS) {
            val source = findEntry(entries, childPath(gameRoot, relativePath)) ?: continue
            val content = readEntryBytes(archive, source.entry, MAX_LUA_CONFIG_BYTES)
                ?.toString(Charsets.UTF_8)
                ?: continue
            TARGET_MOD_ASSIGNMENT.find(content)?.groupValues?.getOrNull(2)?.let { return it }
        }
        return null
    }

    private fun selectModCandidate(
        candidates: List<ModCandidate>,
        targetModId: String?,
        confTitle: String?
    ): ModCandidate? {
        val usable = candidates.filterNot { isPlaceholderTitle(it.name) }
        targetModId?.let { target ->
            usable.firstOrNull { candidate ->
                candidate.id.equals(target, ignoreCase = true) ||
                    candidate.folder.substringAfterLast('/').equals(target, ignoreCase = true)
            }?.let { return it }
        }

        val visible = usable.filterNot(ModCandidate::hidden).ifEmpty { usable }
        confTitle?.let { title ->
            val normalizedTitle = normalizeTitle(title)
            visible.firstOrNull { normalizeTitle(it.name) == normalizedTitle }
                ?.let { return it }
        }
        return visible.singleOrNull()
            ?: visible.minByOrNull { it.folder.lowercase(Locale.ROOT) }
    }

    /** Removes JSONC comments without touching comment markers inside quoted strings. */
    internal fun stripJsonComments(content: String): String {
        val output = StringBuilder(content.length)
        var index = 0
        var inString = false
        var escaped = false
        var lineComment = false
        var blockComment = false

        while (index < content.length) {
            val current = content[index]
            val next = content.getOrNull(index + 1)
            when {
                lineComment -> {
                    if (current == '\n' || current == '\r') {
                        lineComment = false
                        output.append(current)
                    }
                }
                blockComment -> {
                    when {
                        current == '*' && next == '/' -> {
                            blockComment = false
                            index++
                        }
                        current == '\n' || current == '\r' -> output.append(current)
                    }
                }
                inString -> {
                    output.append(current)
                    when {
                        escaped -> escaped = false
                        current == '\\' -> escaped = true
                        current == '"' -> inString = false
                    }
                }
                current == '"' -> {
                    inString = true
                    output.append(current)
                }
                current == '/' && next == '/' -> {
                    lineComment = true
                    index++
                }
                current == '/' && next == '*' -> {
                    blockComment = true
                    index++
                }
                else -> output.append(current)
            }
            index++
        }
        return output.toString()
    }

    private fun findPreferredIcon(
        entries: List<IndexedEntry>,
        parent: String
    ): IndexedEntry? {
        val previewPrefix = childPath(parent, "preview/")
        entries.asSequence()
            .filter { indexed ->
                if (indexed.entry.isDirectory || !indexed.path.startsWith(previewPrefix)) {
                    return@filter false
                }
                val relativePath = indexed.path.removePrefix(previewPrefix)
                '/' !in relativePath && isPreviewIconFile(relativePath)
            }
            .sortedWith(
                compareBy<IndexedEntry> { previewIconOrder(it.path.substringAfterLast('/')) }
                    .thenBy { it.path }
            )
            .firstOrNull()
            ?.let { return it }

        return ICON_FILE_NAMES.firstNotNullOfOrNull { iconName ->
            val expectedPath = childPath(parent, iconName)
            entries.find { !it.entry.isDirectory && it.path == expectedPath }
        }
    }

    private fun isPreviewIconFile(fileName: String): Boolean {
        val extension = fileName.substringAfterLast('.', missingDelimiterValue = "")
        return fileName.startsWith("icon") && extension in PREVIEW_IMAGE_EXTENSIONS
    }

    private fun previewIconOrder(fileName: String): Int {
        val stem = fileName.substringBeforeLast('.')
        if (stem == "icon") return 0
        return PREVIEW_ICON_NUMBER.matchEntire(stem)
            ?.groupValues
            ?.getOrNull(1)
            ?.toIntOrNull()
            ?.plus(1)
            ?: Int.MAX_VALUE
    }

    private fun findLargestPreviewBackground(
        entries: List<IndexedEntry>,
        parent: String
    ): IndexedEntry? {
        val previewPrefix = childPath(parent, "preview/")
        return entries.asSequence()
            .filter { indexed ->
                if (indexed.entry.isDirectory || indexed.entry.size !in 0..MAX_PREVIEW_BYTES.toLong()) {
                    return@filter false
                }
                if (indexed.path == childPath(parent, "bg.png")) return@filter true
                if (!indexed.path.startsWith(previewPrefix)) return@filter false
                val relativePath = indexed.path.removePrefix(previewPrefix)
                '/' !in relativePath &&
                    relativePath.startsWith("bg") &&
                    relativePath.endsWith(".png")
            }
            .maxWithOrNull(compareBy<IndexedEntry> { it.entry.size }.thenByDescending { it.path })
    }

    private fun findPreviewScriptBackground(
        archive: GameArchive,
        entries: List<IndexedEntry>,
        gameRoot: String,
        modFolder: String
    ): IndexedEntry? {
        val script = PREVIEW_SCRIPT_PATHS.firstNotNullOfOrNull { relativePath ->
            findEntry(entries, childPath(modFolder, relativePath))
        } ?: return null
        val source = readEntryBytes(archive, script.entry, MAX_LUA_CONFIG_BYTES)
            ?.toString(Charsets.UTF_8)
            ?.let(::stripLuaLineComments)
            ?: return null

        return PREVIEW_IMAGE_ASSIGNMENT.findAll(source)
            .mapNotNull { match ->
                val variableName = match.groupValues[1]
                if (!isBackgroundVariable(variableName)) return@mapNotNull null
                val expression = match.groupValues[2]
                val referencedPath = QUOTED_PREVIEW_IMAGE.find(expression)
                    ?.groupValues
                    ?.getOrNull(1)
                    ?: return@mapNotNull null
                resolvePreviewReference(
                    entries = entries,
                    gameRoot = gameRoot,
                    modFolder = modFolder,
                    expression = expression,
                    referencedPath = referencedPath
                )
            }
            .filter { it.entry.size in 0..MAX_PREVIEW_BYTES.toLong() }
            .maxWithOrNull(compareBy<IndexedEntry> { it.entry.size }.thenByDescending { it.path })
    }

    private fun stripLuaLineComments(content: String): String {
        return content.lineSequence().joinToString("\n") { line ->
            var quote: Char? = null
            var escaped = false
            var index = 0
            while (index < line.length - 1) {
                val current = line[index]
                when {
                    escaped -> escaped = false
                    current == '\\' && quote != null -> escaped = true
                    quote != null && current == quote -> quote = null
                    quote == null && (current == '\'' || current == '"') -> quote = current
                    quote == null && current == '-' && line[index + 1] == '-' -> {
                        return@joinToString line.substring(0, index)
                    }
                }
                index++
            }
            line
        }
    }

    private fun isBackgroundVariable(variableName: String): Boolean {
        val normalized = variableName.lowercase(Locale.ROOT)
        return normalized == "bg" ||
            normalized.startsWith("bg_") ||
            normalized.endsWith("_bg") ||
            "background" in normalized
    }

    private fun resolvePreviewReference(
        entries: List<IndexedEntry>,
        gameRoot: String,
        modFolder: String,
        expression: String,
        referencedPath: String
    ): IndexedEntry? {
        val normalizedReference = normalizeReadableArchivePath(referencedPath.trimStart('/'))
            ?: return null
        val isModRelative = "mod.path" in expression ||
            "self.base_path" in expression ||
            PREVIEW_PATH_HELPER.containsMatchIn(expression)
        val resolvedPath = when {
            normalizedReference.startsWith("mods/") -> childPath(gameRoot, normalizedReference)
            isModRelative -> childPath(modFolder, normalizedReference)
            normalizedReference.startsWith("assets/") -> childPath(gameRoot, normalizedReference)
            else -> childPath(modFolder, normalizedReference)
        }
        return findEntry(entries, resolvedPath)
    }

    private fun findEntry(entries: List<IndexedEntry>, path: String): IndexedEntry? {
        return entries.find { !it.entry.isDirectory && it.path == path }
    }

    private fun childPath(parent: String, child: String): String {
        return if (parent.isBlank()) child else "$parent/$child"
    }

    private fun normalizeReadableArchivePath(path: String): String? {
        if (path.isBlank() || path.length > MAX_ARCHIVE_PATH_LENGTH) return null
        val parts = path.replace('\\', '/')
            .split('/')
            .filter { it.isNotBlank() && it != "." }
        if (parts.isEmpty() || parts.any { it == ".." }) return null
        return parts.joinToString("/").lowercase(Locale.ROOT)
    }

    private fun readEntryBytes(
        archive: GameArchive,
        entry: GameArchive.Entry,
        maximumBytes: Int
    ): ByteArray? {
        if (entry.size !in 0..maximumBytes.toLong()) return null
        val output = ByteArrayOutputStream(minOf(maximumBytes, 32 * 1024))
        val buffer = ByteArray(16 * 1024)
        var total = 0
        archive.open(entry).use { input ->
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                total += count
                if (total > maximumBytes) return null
                output.write(buffer, 0, count)
            }
        }
        return output.toByteArray()
    }

    private fun decodeSampledBitmap(bytes: ByteArray, maximumDimension: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth !in 1..MAX_SOURCE_ICON_DIMENSION ||
            bounds.outHeight !in 1..MAX_SOURCE_ICON_DIMENSION
        ) return null
        var sampleSize = 1
        while (bounds.outWidth / sampleSize > maximumDimension * 2 ||
            bounds.outHeight / sampleSize > maximumDimension * 2
        ) {
            sampleSize *= 2
        }
        val decoded = BitmapFactory.decodeByteArray(
            bytes,
            0,
            bytes.size,
            BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
        ) ?: return null
        val largest = maxOf(decoded.width, decoded.height)
        if (largest <= maximumDimension) return decoded
        val scale = maximumDimension.toFloat() / largest
        return Bitmap.createScaledBitmap(
            decoded,
            (decoded.width * scale).toInt().coerceAtLeast(1),
            (decoded.height * scale).toInt().coerceAtLeast(1),
            true
        ).also { if (it !== decoded) decoded.recycle() }
    }

    fun findZipOffset(inputStream: InputStream): Long {
        val buffer = ByteArray(8192)
        var totalOffset = 0L
        var b0 = -1
        var b1 = -1
        var b2 = -1
        while (true) {
            val bytesRead = inputStream.read(buffer)
            if (bytesRead < 0) return -1L
            for (index in 0 until bytesRead) {
                val current = buffer[index].toInt() and 0xFF
                if (b0 == 0x50 && b1 == 0x4B && b2 == 0x03 && current == 0x04) {
                    return totalOffset + index - 3
                }
                b0 = b1
                b1 = b2
                b2 = current
            }
            totalOffset += bytesRead
        }
    }

    private fun extractTitleFromConfLua(content: String): String? {
        return Regex("""t(?:\.window)?\.title\s*=\s*["']([^"']+)["']""")
            .find(content)
            ?.groupValues
            ?.get(1)
            ?: Regex("""t\.identity\s*=\s*["']([^"']+)["']""")
                .find(content)
                ?.groupValues
                ?.get(1)
    }

    private fun isIgnoredFallbackTitle(title: String): Boolean {
        return normalizeTitle(title) == "kristal" || isPlaceholderTitle(title)
    }

    internal fun isPlaceholderTitle(title: String): Boolean {
        return normalizeTitle(title) in PLACEHOLDER_TITLES
    }

    private fun normalizeTitle(title: String): String {
        return title.trim()
            .lowercase(Locale.ROOT)
            .replace(Regex("\\s+"), " ")
    }

    private data class IndexedEntry(
        val entry: GameArchive.Entry,
        val path: String
    )

    private data class ModCandidate(
        val folder: String,
        val id: String?,
        val name: String,
        val subtitle: String?,
        val description: String?,
        val version: String?,
        val engineVersion: String?,
        val author: String?,
        val chapter: String?,
        val startMap: String?,
        val party: List<String>,
        val hidden: Boolean
    )

    internal data class ParsedArchiveMetadata(
        val title: String,
        val subtitle: String?,
        val description: String?,
        val version: String?,
        val engineVersion: String?,
        val author: String?,
        val projectId: String?,
        val chapter: String?,
        val startMap: String?,
        val party: List<String>,
        val iconBytes: ByteArray?,
        val previewLayers: List<ByteArray>
    )

    private val ICON_FILE_NAMES = listOf("icon.png", "bigicon.png", "icon.jpg", "icon.jpeg")
    private val PREVIEW_IMAGE_EXTENSIONS = setOf("png", "jpg", "jpeg", "webp")
    private val PREVIEW_ICON_NUMBER = Regex("icon(?:[_ -]?(\\d+))")
    private val TARGET_MOD_ASSIGNMENT = Regex(
        """(?m)^\s*TARGET_MOD\s*=\s*([\"'])([^\"']+)\1"""
    )
    private val TARGET_MOD_SOURCE_PATHS = listOf(
        "src/engine/vendcust.lua",
        "src/engine/statevars.lua",
        "src/engine/menu/menu.lua",
        "src/engine/menu/mainmenu.lua",
        "main.lua"
    )
    private val PREVIEW_SCRIPT_PATHS = listOf("preview/preview.lua", "preview.lua")
    private val PREVIEW_IMAGE_ASSIGNMENT = Regex(
        """^\s*(?:self\.)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*love\.graphics\.newImage\s*\((.{0,512}?)\)""",
        setOf(RegexOption.MULTILINE, RegexOption.DOT_MATCHES_ALL)
    )
    private val QUOTED_PREVIEW_IMAGE = Regex(
        """[\"']([^\"']+\.(?:png|jpg|jpeg|webp))[\"']""",
        RegexOption.IGNORE_CASE
    )
    private val PREVIEW_PATH_HELPER = Regex("""\bp\s*\(""")
    private const val DEFAULT_PREVIEW_BACKGROUND = "assets/sprites/kristal/title_bg_wave.png"
    private const val MAX_LUA_CONFIG_BYTES = 256 * 1024
    private const val MAX_ARCHIVE_PATH_LENGTH = 1_024
}
