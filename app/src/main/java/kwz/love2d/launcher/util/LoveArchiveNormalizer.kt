package kwz.love2d.launcher.util

import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

object LoveArchiveNormalizer {

    internal fun findGameRoot(entryNames: Iterable<String>): String? {
        val paths = entryNames.asSequence()
            .map(::normalizePath)
            .filter(String::isNotBlank)
            .distinct()
            .toList()
        val pathSet = paths.toHashSet()
        val modManifestCounts = HashMap<String, Int>()
        paths.forEach { path ->
            val parts = path.split('/').filter(String::isNotBlank)
            if (parts.size >= 3 &&
                parts[parts.lastIndex - 2] == "mods" &&
                parts.last() == "mod.json"
            ) {
                val root = parts.dropLast(3).joinToString("/")
                modManifestCounts[root] = (modManifestCounts[root] ?: 0) + 1
            }
        }
        return paths.asSequence()
            .filter { it == MAIN_FILE || it.endsWith("/$MAIN_FILE") }
            .map { path -> path.substringBeforeLast('/', "") }
            .distinct()
            .sortedWith(
                compareByDescending<String> { root -> modManifestCounts[root] ?: 0 }
                    .thenByDescending { root -> childPath(root, "conf.lua") in pathSet }
                    .thenByDescending { root -> ICON_FILE_NAMES.any { childPath(root, it) in pathSet } }
                    .thenBy(::pathDepth)
                    .thenBy { it }
            )
            .firstOrNull()
    }

    /**
     * Moves a game stored below a common ZIP directory to the staged archive root.
     * The source passed here is already an app-private staging copy.
     */
    internal fun normalizeRootInPlace(archiveFile: File): Boolean {
        val entryNames = ZipFile(archiveFile).use { zip ->
            zip.entries().toList().filterNot { it.isDirectory }.map { it.name }
        }
        val gameRoot = findGameRoot(entryNames)
            ?: throw IllegalArgumentException("Game archive does not contain main.lua")
        if (gameRoot.isEmpty() && entryNames.any { it == MAIN_FILE }) return false

        val rootPartCount = if (gameRoot.isEmpty()) 0 else gameRoot.split('/').size
        val normalizedFile = File(archiveFile.parentFile, "${archiveFile.name}.normalizing")
        normalizedFile.delete()
        try {
            ZipFile(archiveFile).use { sourceZip ->
                ZipOutputStream(FileOutputStream(normalizedFile).buffered()).use { outputZip ->
                    val writtenPaths = mutableSetOf<String>()
                    sourceZip.entries().toList().forEach { sourceEntry ->
                        val canonicalSourcePath = canonicalizePath(sourceEntry.name)
                            ?: return@forEach
                        val normalizedSourcePath = canonicalSourcePath.lowercase(Locale.ROOT)
                        if (gameRoot.isNotEmpty() && normalizedSourcePath != gameRoot &&
                            !normalizedSourcePath.startsWith("$gameRoot/")
                        ) {
                            return@forEach
                        }

                        val originalParts = canonicalSourcePath.split('/')
                        val targetPath = originalParts.drop(rootPartCount).joinToString("/")
                        if (targetPath.isBlank()) return@forEach
                        require(PatchManifestParser.isSafeArchivePath(targetPath)) {
                            "Unsafe normalized game archive path"
                        }
                        if (!writtenPaths.add(normalizePath(targetPath))) return@forEach

                        val targetEntry = ZipEntry(if (sourceEntry.isDirectory) "$targetPath/" else targetPath)
                        if (sourceEntry.time >= 0L) targetEntry.time = sourceEntry.time
                        outputZip.putNextEntry(targetEntry)
                        if (!sourceEntry.isDirectory) {
                            sourceZip.getInputStream(sourceEntry).use { input ->
                                input.copyTo(outputZip, COPY_BUFFER_SIZE)
                            }
                        }
                        outputZip.closeEntry()
                    }
                }
            }

            require(normalizedFile.isFile && normalizedFile.length() > 0L) {
                "Normalized game archive is empty"
            }
            normalizedFile.inputStream().buffered().use { input ->
                FileOutputStream(archiveFile, false).use { output ->
                    input.copyTo(output, COPY_BUFFER_SIZE)
                    output.fd.sync()
                }
            }
            return true
        } finally {
            normalizedFile.delete()
        }
    }

    internal fun normalizePath(path: String): String {
        return canonicalizePath(path)?.lowercase(Locale.ROOT).orEmpty()
    }

    private fun canonicalizePath(path: String): String? {
        if (path.isBlank() || path.length > MAX_ARCHIVE_PATH_LENGTH || '\u0000' in path || ':' in path) {
            return null
        }
        val parts = path.replace('\\', '/')
            .split('/')
            .filter { it.isNotBlank() && it != "." }
        if (parts.isEmpty() || parts.any { it == ".." }) return null
        return parts.joinToString("/")
    }

    private fun pathDepth(path: String): Int = if (path.isEmpty()) 0 else path.count { it == '/' } + 1

    private fun childPath(parent: String, child: String): String {
        return if (parent.isBlank()) child else "$parent/$child"
    }

    private const val MAIN_FILE = "main.lua"
    private const val COPY_BUFFER_SIZE = 64 * 1024
    private const val MAX_ARCHIVE_PATH_LENGTH = 1_024
    private val ICON_FILE_NAMES = listOf("icon.png", "bigicon.png", "icon.jpg", "icon.jpeg")
}
