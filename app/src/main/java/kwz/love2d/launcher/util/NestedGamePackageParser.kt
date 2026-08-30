package kwz.love2d.launcher.util

import android.content.Context
import android.net.Uri
import kwz.love2d.launcher.model.LoveGame
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.Locale
import java.util.UUID

object NestedGamePackageParser {
    private const val COPY_BUFFER_SIZE = 1_048_576
    private const val MAX_ARCHIVE_ENTRIES = 50_000
    private const val MAX_NESTED_GAMES = 32
    private const val MAX_NESTED_PACKAGE_BYTES = 2_147_483_648L

    fun parsePackages(
        context: Context,
        sourceUri: Uri,
        sourceName: String,
        sourceSizeBytes: Long,
        sourceLastModified: Long,
    ): List<LoveGame> {
        if (
            !sourceName.endsWith(".zip", ignoreCase = true) &&
            !sourceName.endsWith(".exe", ignoreCase = true)
        ) {
            return emptyList()
        }

        val temporaryRoot = File(context.cacheDir, "nested_game_scan/${UUID.randomUUID()}")
        if (!temporaryRoot.mkdirs()) return emptyList()

        return try {
            GameArchive.open(
                context = context,
                uri = sourceUri,
                fileName = sourceName
            ).use { archive ->
                val entries = archive.entries(MAX_ARCHIVE_ENTRIES)

                val packageEntries = entries.filter { !it.isDirectory && isGamePackage(it.name) }
                val preferredPaths = selectPreferredGamePackagePaths(packageEntries.map { it.name })
                val preferredPathSet = preferredPaths.mapTo(hashSetOf(), ::normalizePackagePath)
                val preferredEntries = packageEntries.filter {
                    normalizePackagePath(it.name) in preferredPathSet
                }

                require(preferredEntries.size <= MAX_NESTED_GAMES) {
                    "Wrapper archive contains too many game packages"
                }

                val preferredGames = parseEntries(
                    archive,
                    preferredEntries,
                    temporaryRoot,
                    sourceName,
                    sourceUri,
                    sourceSizeBytes,
                    sourceLastModified,
                )

                val parsedIdentities = preferredGames.mapNotNullTo(hashSetOf()) { game ->
                    game.archiveEntryPath?.let(::packageIdentity)
                }
                val fallbackExecutables = packageEntries.filter { entry ->
                    entry.name.endsWith(".exe", ignoreCase = true) &&
                        normalizePackagePath(entry.name) !in preferredPathSet &&
                        packageIdentity(entry.name) !in parsedIdentities
                }
                require(preferredEntries.size + fallbackExecutables.size <= MAX_NESTED_GAMES) {
                    "Wrapper archive contains too many game packages"
                }

                preferredGames + parseEntries(
                    archive,
                    fallbackExecutables,
                    temporaryRoot,
                    sourceName,
                    sourceUri,
                    sourceSizeBytes,
                    sourceLastModified,
                )
            }
        } catch (error: Exception) {
            error.printStackTrace()
            emptyList()
        } finally {
            temporaryRoot.deleteRecursively()
        }
    }

    private fun parseEntries(
        archive: GameArchive,
        entries: List<GameArchive.Entry>,
        temporaryRoot: File,
        sourceName: String,
        sourceUri: Uri,
        sourceSizeBytes: Long,
        sourceLastModified: Long,
    ): List<LoveGame> = entries.mapIndexedNotNull { index, entry ->
        parseEntry(
            archive = archive,
            entry = entry,
            index = index,
            temporaryRoot = temporaryRoot,
            sourceName = sourceName,
            sourceUri = sourceUri,
            sourceSizeBytes = sourceSizeBytes,
            sourceLastModified = sourceLastModified,
        )
    }

    /**
     * A wrapper may contain multiple packages. One malformed entry must not discard the other
     * valid packages in the same wrapper, or fail the parent folder scan.
     */
    private fun parseEntry(
        archive: GameArchive,
        entry: GameArchive.Entry,
        index: Int,
        temporaryRoot: File,
        sourceName: String,
        sourceUri: Uri,
        sourceSizeBytes: Long,
        sourceLastModified: Long,
    ): LoveGame? {
        var extractedFile: File? = null
        return try {
            require(entry.size in 0..MAX_NESTED_PACKAGE_BYTES) {
                "Nested game package is too large"
            }

            val entryPath = entry.name
            val nestedFileName = entryPath.substringAfterLast('/').ifBlank { "nested.love" }
            val safeFileName = Regex("[^A-Za-z0-9._ -]")
                .replace(nestedFileName, "_")
                .ifBlank { "nested.love" }
            val destinationFile = File(temporaryRoot, "${index + 1}_$safeFileName")
            extractedFile = destinationFile
            val copiedBytes = archive.open(entry).use { input ->
                copyEntry(input, destinationFile)
            }

            LoveMetadataParser.parseLoveFile(
                destinationFile,
                nestedFileName,
                copiedBytes,
                sourceLastModified,
            )?.copy(
                fileName = sourceName,
                uri = sourceUri,
                archiveEntryPath = entryPath,
                sizeBytes = sourceSizeBytes,
                lastModified = sourceLastModified,
            )
        } catch (_: Exception) {
            null
        } finally {
            extractedFile?.delete()
        }
    }

    private fun copyEntry(input: InputStream, destination: File): Long {
        var total = 0L
        val buffer = ByteArray(COPY_BUFFER_SIZE)
        FileOutputStream(destination).buffered(COPY_BUFFER_SIZE).use { output ->
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
                require(total <= MAX_NESTED_PACKAGE_BYTES) {
                    "Nested game package is too large"
                }
                output.write(buffer, 0, read)
            }
        }
        return total
    }

    internal fun selectPreferredGamePackagePaths(paths: List<String>): List<String> {
        val packages = paths.filter { isGamePackage(it) }
        return packages
            .groupByTo(linkedMapOf(), ::packageIdentity)
            .values
            .flatMap { variants ->
                variants.filter { it.endsWith(".love", ignoreCase = true) }
                    .ifEmpty { variants.filter { it.endsWith(".exe", ignoreCase = true) } }
            }
    }

    private fun packageIdentity(path: String): String {
        return normalizePackagePath(path).removeSuffix(".love").removeSuffix(".exe")
    }

    private fun normalizePackagePath(path: String): String {
        return path.replace('\\', '/').trimStart('/').lowercase(Locale.ROOT)
    }

    internal fun isGamePackage(path: String): Boolean {
        val lower = path.lowercase(Locale.ROOT)
        return lower.endsWith(".love") || lower.endsWith(".exe")
    }
}
