package kwz.love2d.launcher.util

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.documentfile.provider.DocumentFile
import kwz.love2d.launcher.model.LoveGame
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.Locale
import java.util.zip.ZipInputStream

object LoveMetadataParser {

    private const val MAX_METADATA_BYTES = 1024 * 1024
    private const val MAX_ICON_BYTES = 2 * 1024 * 1024
    private const val MAX_ICON_DIMENSION = 192
    private const val MAX_ENTRY_COUNT = 10_000
    private const val MAX_MOD_CANDIDATES = 256
    private const val MAX_MOD_ICON_CANDIDATES = 16
    private const val MAX_TOTAL_UNCOMPRESSED_BYTES = 2L * 1024 * 1024 * 1024
    private const val MAX_SOURCE_ICON_DIMENSION = 16_384
    private val PLACEHOLDER_MOD_TITLES = setOf("example mod", "exemple mod")

    fun parseLoveFile(
        context: Context,
        document: DocumentFile,
        sizeBytes: Long = document.length(),
        lastModified: Long = document.lastModified()
    ): LoveGame? {
        val fileName = document.name ?: return null
        val isExecutable = fileName.endsWith(".exe", ignoreCase = true)
        val modCandidates = mutableListOf<ModCandidate>()
        val modIcons = linkedMapOf<String, Bitmap>()
        var rootIcon: Bitmap? = null
        var confTitle: String? = null
        var hasMainLua = false
        var entryCount = 0
        val normalizedEntries = mutableSetOf<String>()
        val archiveBudget = ArchiveBudget(MAX_TOTAL_UNCOMPRESSED_BYTES)

        try {
            var input = context.contentResolver.openInputStream(document.uri)?.buffered() ?: return null
            if (isExecutable) {
                val offset = input.use(::findZipOffset)
                if (offset < 0L) return null
                input = context.contentResolver.openInputStream(document.uri)?.buffered() ?: return null
                skipBytesFully(input, offset)
            }

            ZipInputStream(input).use { zip ->
                var entry = zip.nextEntry
                while (entry != null) {
                    entryCount++
                    require(entryCount <= MAX_ENTRY_COUNT) { "Game archive contains too many entries" }
                    val rawPath = entry.name
                    require(PatchManifestParser.isSafeArchivePath(rawPath)) { "Unsafe game archive path" }
                    val path = normalizeArchivePath(rawPath)
                    require(normalizedEntries.add(path.trimEnd('/'))) {
                        "Game archive contains duplicate entries"
                    }
                    if (!entry.isDirectory) {
                        val parts = path.split('/').filter(String::isNotBlank)
                        val relativeParts = parts
                        val relativePath = relativeParts.joinToString("/")
                        if (relativePath == "main.lua") hasMainLua = true
                        var entryConsumed = false

                        val modsIndex = relativeParts.indexOf("mods")
                        val isDirectModFile = modsIndex == 0 && relativeParts.size == 3
                        val modFolder = if (isDirectModFile) {
                            relativeParts.take(2).joinToString("/")
                        } else {
                            null
                        }

                        when {
                            isDirectModFile && relativeParts.last() == "mod.json" -> {
                                val content = readEntryBytes(zip, MAX_METADATA_BYTES, archiveBudget)
                                    ?.toString(Charsets.UTF_8)
                                    .orEmpty()
                                entryConsumed = true
                                runCatching {
                                    val json = JSONObject(content)
                                    val name = json.optString("name").trim()
                                    if (name.isNotBlank() && modCandidates.size < MAX_MOD_CANDIDATES) {
                                        modCandidates += ModCandidate(
                                            folder = modFolder.orEmpty(),
                                            name = name,
                                            subtitle = json.optString("subtitle").takeIf(String::isNotBlank),
                                            version = json.optString("version").takeIf(String::isNotBlank),
                                            engineVersion = json.optString("engineVer").takeIf(String::isNotBlank),
                                            author = json.optString("author").takeIf(String::isNotBlank)
                                        )
                                    }
                                }
                            }
                            isDirectModFile && relativeParts.last() in ICON_FILE_NAMES &&
                                modIcons.size < MAX_MOD_ICON_CANDIDATES -> {
                                readEntryBytes(zip, MAX_ICON_BYTES, archiveBudget)?.let(::decodeSampledBitmap)?.let { bitmap ->
                                    if (modIcons.putIfAbsent(modFolder.orEmpty(), bitmap) != null) bitmap.recycle()
                                }
                                entryConsumed = true
                            }
                            relativeParts.size == 1 && relativeParts.last() in ICON_FILE_NAMES && rootIcon == null -> {
                                rootIcon = readEntryBytes(zip, MAX_ICON_BYTES, archiveBudget)?.let(::decodeSampledBitmap)
                                entryConsumed = true
                            }
                            relativePath == "conf.lua" && confTitle == null -> {
                                confTitle = readEntryBytes(zip, MAX_METADATA_BYTES, archiveBudget)
                                    ?.toString(Charsets.UTF_8)
                                    ?.let(::extractTitleFromConfLua)
                                entryConsumed = true
                            }
                        }
                        if (!entryConsumed) drainEntry(zip, archiveBudget)
                    }
                    zip.closeEntry()
                    entry = zip.nextEntry
                }
            }
        } catch (error: Exception) {
            error.printStackTrace()
            modIcons.values.forEach(Bitmap::recycle)
            rootIcon?.recycle()
            return null
        }

        if (entryCount == 0 || !hasMainLua) {
            modIcons.values.forEach(Bitmap::recycle)
            rootIcon?.recycle()
            return null
        }

        val selectedMod = modCandidates
            .filterNot { isPlaceholderModTitle(it.name) }
            .minByOrNull { it.folder.lowercase(Locale.ROOT) }
        val selectedIcon = selectedMod?.folder?.let(modIcons::get) ?: rootIcon
        modIcons.values.filter { it !== selectedIcon }.forEach(Bitmap::recycle)
        if (rootIcon !== selectedIcon) rootIcon?.recycle()

        val cleanName = fileName.replace(Regex("(?i)\\.(love|zip|exe)$"), "")
        val title = selectedMod?.name
            ?: confTitle?.takeIf {
                it.trim().lowercase(Locale.ROOT) != "kristal" && !isPlaceholderModTitle(it)
            }
            ?: cleanName

        return LoveGame(
            title = title,
            fileName = fileName,
            uri = document.uri,
            icon = selectedIcon,
            sizeBytes = sizeBytes,
            lastModified = lastModified,
            subtitle = selectedMod?.subtitle,
            version = selectedMod?.version,
            engineVer = selectedMod?.engineVersion,
            author = selectedMod?.author
        )
    }

    private fun normalizeArchivePath(path: String): String {
        return path.replace('\\', '/').trimStart('/').lowercase(Locale.ROOT)
    }

    private fun readEntryBytes(
        input: InputStream,
        maximumBytes: Int,
        budget: ArchiveBudget
    ): ByteArray? {
        val output = ByteArrayOutputStream(minOf(maximumBytes, 32 * 1024))
        val buffer = ByteArray(16 * 1024)
        var total = 0
        var tooLarge = false
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            budget.account(count)
            total += count
            if (total <= maximumBytes) {
                output.write(buffer, 0, count)
            } else {
                tooLarge = true
            }
        }
        return if (tooLarge) null else output.toByteArray()
    }

    private fun drainEntry(input: InputStream, budget: ArchiveBudget) {
        val buffer = ByteArray(16 * 1024)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) return
            budget.account(count)
        }
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

    private fun skipBytesFully(inputStream: InputStream, bytesToSkip: Long) {
        var remaining = bytesToSkip
        while (remaining > 0L) {
            val skipped = inputStream.skip(remaining)
            if (skipped > 0L) {
                remaining -= skipped
            } else if (inputStream.read() >= 0) {
                remaining--
            } else {
                throw IllegalArgumentException("Executable ended before the embedded archive")
            }
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

    private fun isPlaceholderModTitle(title: String): Boolean {
        return title.trim()
            .lowercase(Locale.ROOT)
            .replace(Regex("\\s+"), " ") in PLACEHOLDER_MOD_TITLES
    }

    private data class ModCandidate(
        val folder: String,
        val name: String,
        val subtitle: String?,
        val version: String?,
        val engineVersion: String?,
        val author: String?
    )

    private class ArchiveBudget(private val limit: Long) {
        private var consumed = 0L

        fun account(byteCount: Int) {
            consumed += byteCount
            require(consumed <= limit) { "Game archive expands beyond the metadata scan limit" }
        }
    }

    private val ICON_FILE_NAMES = setOf("icon.png", "bigicon.png", "icon.jpg", "icon.jpeg")
}
