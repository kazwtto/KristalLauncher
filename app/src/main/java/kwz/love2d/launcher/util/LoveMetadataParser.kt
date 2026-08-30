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
        try {
            selectedIcon = metadata.iconBytes?.let(::decodeSampledBitmap)
            return LoveGame(
                title = metadata.title,
                fileName = fileName,
                uri = uri,
                icon = selectedIcon,
                sizeBytes = sizeBytes,
                lastModified = lastModified,
                subtitle = metadata.subtitle,
                version = metadata.version,
                engineVer = metadata.engineVersion,
                author = metadata.author
            )
        } catch (error: Exception) {
            selectedIcon?.recycle()
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

        val selectedMod = modCandidates
            .filterNot { isPlaceholderTitle(it.name) }
            .minByOrNull { it.folder.lowercase(Locale.ROOT) }

        val confTitle = indexedEntries
            .find { it.path == childPath(gameRoot, "conf.lua") && !it.entry.isDirectory }
            ?.let { readEntryBytes(archive, it.entry, MAX_METADATA_BYTES) }
            ?.toString(Charsets.UTF_8)
            ?.let(::extractTitleFromConfLua)
            ?.takeUnless(::isIgnoredFallbackTitle)

        val iconEntry = selectedMod
            ?.let { findPreferredIcon(indexedEntries, it.folder) }
            ?: findPreferredIcon(indexedEntries, gameRoot)
        val iconBytes = iconEntry?.let { readEntryBytes(archive, it.entry, MAX_ICON_BYTES) }
        val cleanName = fileName.replace(Regex("(?i)\\.(love|zip|exe)$"), "")

        return ParsedArchiveMetadata(
            title = selectedMod?.name ?: confTitle ?: cleanName,
            subtitle = selectedMod?.subtitle,
            version = selectedMod?.version,
            engineVersion = selectedMod?.engineVersion,
            author = selectedMod?.author,
            iconBytes = iconBytes
        )
    }

    private fun parseModCandidate(content: String): ModCandidate? {
        return runCatching {
            val json = JSONObject(stripJsonComments(content.removePrefix("\uFEFF")))
            val name = json.optString("name").trim()
            if (name.isBlank()) return null
            ModCandidate(
                folder = "",
                name = name,
                subtitle = json.optString("subtitle").trim().takeIf(String::isNotBlank),
                version = json.optString("version").trim().takeIf(String::isNotBlank),
                engineVersion = json.optString("engineVer").trim().takeIf(String::isNotBlank),
                author = json.optString("author").trim().takeIf(String::isNotBlank)
            )
        }.getOrNull()
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
        return ICON_FILE_NAMES.firstNotNullOfOrNull { iconName ->
            val expectedPath = childPath(parent, iconName)
            entries.find { !it.entry.isDirectory && it.path == expectedPath }
        }
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

    private fun decodeSampledBitmap(bytes: ByteArray): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth !in 1..MAX_SOURCE_ICON_DIMENSION ||
            bounds.outHeight !in 1..MAX_SOURCE_ICON_DIMENSION
        ) return null
        var sampleSize = 1
        while (bounds.outWidth / sampleSize > MAX_ICON_DIMENSION * 2 ||
            bounds.outHeight / sampleSize > MAX_ICON_DIMENSION * 2
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
        if (largest <= MAX_ICON_DIMENSION) return decoded
        val scale = MAX_ICON_DIMENSION.toFloat() / largest
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
        val name: String,
        val subtitle: String?,
        val version: String?,
        val engineVersion: String?,
        val author: String?
    )

    internal data class ParsedArchiveMetadata(
        val title: String,
        val subtitle: String?,
        val version: String?,
        val engineVersion: String?,
        val author: String?,
        val iconBytes: ByteArray?
    )

    private val ICON_FILE_NAMES = listOf("icon.png", "bigicon.png", "icon.jpg", "icon.jpeg")
    private const val MAX_ARCHIVE_PATH_LENGTH = 1_024
}
