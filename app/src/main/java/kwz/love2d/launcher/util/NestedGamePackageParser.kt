package kwz.love2d.launcher.util

import android.content.Context
import androidx.documentfile.provider.DocumentFile
import kwz.love2d.launcher.model.LoveGame
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.Locale
import java.util.UUID
import java.util.zip.ZipInputStream

/** Finds complete .love or fused .exe packages stored inside a wrapper ZIP. */
object NestedGamePackageParser {

    private const val MAX_ARCHIVE_ENTRIES = 10_000
    private const val MAX_NESTED_GAMES = 32
    private const val MAX_NESTED_PACKAGE_BYTES = 2L * 1024 * 1024 * 1024
    private const val COPY_BUFFER_SIZE = 1024 * 1024

    fun parsePackages(
        context: Context,
        document: DocumentFile,
        sourceSizeBytes: Long,
        sourceLastModified: Long
    ): List<LoveGame> {
        val sourceName = document.name ?: return emptyList()
        if (!sourceName.endsWith(".zip", ignoreCase = true) &&
            !sourceName.endsWith(".exe", ignoreCase = true)
        ) return emptyList()

        val temporaryRoot = File(context.cacheDir, "nested_game_scan/${UUID.randomUUID()}")
        if (!temporaryRoot.mkdirs()) return emptyList()

        return try {
            openOuterArchive(context, document, sourceName)?.use { source ->
                ZipInputStream(source).use { archive ->
                    val games = mutableListOf<LoveGame>()
                    val normalizedEntries = mutableSetOf<String>()
                    var entryCount = 0
                    var gameCandidateCount = 0
                    var entry = archive.nextEntry
                    while (entry != null) {
                        entryCount++
                        require(entryCount <= MAX_ARCHIVE_ENTRIES) {
                            "Wrapper archive contains too many entries"
                        }
                        val entryPath = entry.name
                        require(PatchManifestParser.isSafeArchivePath(entryPath)) {
                            "Unsafe path in wrapper archive"
                        }
                        val normalizedPath = entryPath.trimEnd('/').lowercase(Locale.ROOT)
                        require(normalizedEntries.add(normalizedPath)) {
                            "Wrapper archive contains duplicate entries"
                        }

                        if (!entry.isDirectory && isGamePackage(entryPath)) {
                            gameCandidateCount++
                            require(gameCandidateCount <= MAX_NESTED_GAMES) {
                                "Wrapper archive contains too many game packages"
                            }
                            val safeFileName = entryPath.substringAfterLast('/')
                                .replace(Regex("[^A-Za-z0-9._ -]"), "_")
                                .ifBlank { "nested.love" }
                            val extractedFile = File(temporaryRoot, safeFileName)
                            val copiedBytes = copyEntry(archive, extractedFile)
                            val parsed = LoveMetadataParser.parseLoveFile(
                                context = context,
                                document = DocumentFile.fromFile(extractedFile),
                                sizeBytes = copiedBytes,
                                lastModified = sourceLastModified
                            )
                            if (parsed != null) {
                                games += parsed.copy(
                                    fileName = sourceName,
                                    uri = document.uri,
                                    archiveEntryPath = entryPath,
                                    sizeBytes = sourceSizeBytes,
                                    lastModified = sourceLastModified
                                )
                            }
                            extractedFile.delete()
                        }
                        archive.closeEntry()
                        entry = archive.nextEntry
                    }
                    games
                }
            }.orEmpty()
        } catch (error: Exception) {
            error.printStackTrace()
            emptyList()
        } finally {
            temporaryRoot.deleteRecursively()
        }
    }

    private fun openOuterArchive(
        context: Context,
        document: DocumentFile,
        sourceName: String
    ): InputStream? {
        var input = context.contentResolver.openInputStream(document.uri)?.buffered(COPY_BUFFER_SIZE)
            ?: return null
        if (!sourceName.endsWith(".exe", ignoreCase = true)) return input

        val zipOffset = input.use(LoveMetadataParser::findZipOffset)
        if (zipOffset < 0L) return null
        input = context.contentResolver.openInputStream(document.uri)?.buffered(COPY_BUFFER_SIZE)
            ?: return null
        skipFully(input, zipOffset)
        return input
    }

    private fun copyEntry(input: InputStream, destination: File): Long {
        var total = 0L
        val buffer = ByteArray(COPY_BUFFER_SIZE)
        FileOutputStream(destination).use { output ->
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
                require(total <= MAX_NESTED_PACKAGE_BYTES) { "Nested game package is too large" }
                output.write(buffer, 0, read)
            }
            output.fd.sync()
        }
        return total
    }

    private fun skipFully(input: InputStream, byteCount: Long) {
        var remaining = byteCount
        while (remaining > 0L) {
            val skipped = input.skip(remaining)
            if (skipped > 0L) {
                remaining -= skipped
            } else if (input.read() >= 0) {
                remaining--
            } else {
                throw IllegalArgumentException("Executable ended before its embedded ZIP")
            }
        }
    }

    internal fun isGamePackage(path: String): Boolean {
        val lower = path.lowercase(Locale.ROOT)
        return lower.endsWith(".love") || lower.endsWith(".exe")
    }
}
