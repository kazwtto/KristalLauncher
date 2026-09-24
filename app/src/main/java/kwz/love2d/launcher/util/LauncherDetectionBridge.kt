package kwz.love2d.launcher.util

import kwz.love2d.launcher.BuildConfig
import kotlinx.coroutines.CancellationException
import org.apache.commons.compress.archivers.zip.ZipArchiveEntry
import org.apache.commons.compress.archivers.zip.ZipArchiveOutputStream
import org.apache.commons.compress.archivers.zip.ZipFile as CommonsZipFile
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FilterInputStream
import java.io.InputStream
import java.util.Locale
import java.util.zip.ZipFile

/** Installs the launcher bridge after all optional package transformations have finished. */
object LauncherDetectionBridge {
    private const val API_VERSION = 1
    private const val MAX_ARCHIVE_ENTRIES = 20_000
    private const val MAX_MAIN_BYTES = 16 * 1024 * 1024

    internal fun fingerprint(): String =
        "${BuildConfig.VERSION_NAME}|${BuildConfig.VERSION_CODE}|$API_VERSION"

    internal fun writeInstrumentedGame(
        sourceFile: File,
        outputFile: File,
        environment: LauncherEnvironmentInfo
    ) {
        require(sourceFile.isFile && sourceFile.length() > 0L) { "Staged game is unavailable" }
        require(sourceFile.canonicalFile != outputFile.canonicalFile) {
            "Launcher bridge output must not replace its source"
        }

        outputFile.delete()
        var hasMainLua = false
        val existingEntries = mutableSetOf<String>()
        CommonsZipFile.builder().setFile(sourceFile).get().use { sourceZip ->
            ZipArchiveOutputStream(outputFile).use { outputZip ->
                val entries = sourceZip.entries
                var entryCount = 0
                while (entries.hasMoreElements()) {
                    ensureNotInterrupted()
                    val entry = entries.nextElement()
                    entryCount++
                    require(entryCount <= MAX_ARCHIVE_ENTRIES) { "Staged game contains too many entries" }
                    require(PatchManifestParser.isSafeArchivePath(entry.name)) {
                        "Unsafe path in staged game: ${entry.name}"
                    }
                    val normalizedName = entry.name.lowercase(Locale.ROOT)
                    require(existingEntries.add(normalizedName)) {
                        "Duplicate entry in staged game: ${entry.name}"
                    }

                    if (!entry.isDirectory && normalizedName == "main.lua") {
                        hasMainLua = true
                        val original = sourceZip.getInputStream(entry).use(::readMainLimited)
                        val instrumented = appendLuaFooter(original, buildHook(environment))
                        val outputEntry = ZipArchiveEntry(entry.name).apply { time = entry.time }
                        outputZip.putArchiveEntry(outputEntry)
                        outputZip.write(instrumented)
                        outputZip.closeArchiveEntry()
                    } else {
                        sourceZip.getRawInputStream(entry).use { rawInput ->
                            outputZip.addRawArchiveEntry(entry, InterruptibleInputStream(rawInput))
                        }
                    }
                }
            }
        }
        require(hasMainLua) { "The staged package does not contain main.lua" }
        validateOutput(outputFile)
    }

    internal fun buildHook(environment: LauncherEnvironmentInfo): String {
        val activePatches = environment.activePatchIds.joinToString(", ") { luaString(it) }
        val runtime = if (environment.runtimeVersion != null || environment.runtimeTag != null) {
            """
            {
                tag = ${luaString(environment.runtimeTag)},
                version = ${luaString(environment.runtimeVersion)}
            }
            """.trimIndent()
        } else {
            "nil"
        }
        return """
        -- [[ START: KRISTAL LAUNCHER DETECTION ]] --
        do
            local original_get_mod_option = Kristal and Kristal.getModOption
            if type(original_get_mod_option) == "function" then
                Kristal.getModOption = function(key, ...)
                    if key == "kristalLauncher" then
                        return true
                    end
                    if key == "kristalLauncher.info" then
                        return {
                            name = "Kristal Launcher",
                            version = ${luaString(BuildConfig.VERSION_NAME)},
                            versionCode = ${BuildConfig.VERSION_CODE},
                            apiVersion = $API_VERSION,
                            platform = "Android",
                            game = {
                                packageType = ${luaString(environment.packageType)},
                                isKristalMod = ${environment.isKristalMod},
                                version = ${luaString(environment.gameVersion)},
                                engineVersion = ${luaString(environment.engineVersion)}
                            },
                            runtime = $runtime,
                            patches = {
                                enabled = ${environment.activePatchIds.isNotEmpty()},
                                active = { $activePatches }
                            },
                            translation = {
                                enabled = ${environment.translationLanguage != null},
                                language = ${luaString(environment.translationLanguage)}
                            }
                        }
                    end
                    return original_get_mod_option(key, ...)
                end
            end
        end
        -- [[ END: KRISTAL LAUNCHER DETECTION ]] --
        """.trimIndent()
    }

    internal fun appendLuaFooter(original: ByteArray, addition: String): ByteArray {
        val source = original.toString(Charsets.UTF_8)
        val returnStatement = Regex("(?m)^[\\t ]*return(?:[\\t ]|$)")
            .findAll(source)
            .lastOrNull { match ->
                source.substring(match.range.first)
                    .lineSequence()
                    .drop(1)
                    .all { line -> line.isBlank() || line.trimStart().startsWith("--") }
            }
        val footer = "\n$addition\n"
        return if (returnStatement == null) {
            (source + footer).toByteArray(Charsets.UTF_8)
        } else {
            source.substring(0, returnStatement.range.first).toByteArray(Charsets.UTF_8) +
                footer.toByteArray(Charsets.UTF_8) +
                source.substring(returnStatement.range.first).toByteArray(Charsets.UTF_8)
        }
    }

    private fun readMainLimited(input: InputStream): ByteArray {
        val output = ByteArrayOutputStream(minOf(MAX_MAIN_BYTES, 64 * 1024))
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0
        while (true) {
            ensureNotInterrupted()
            val read = input.read(buffer)
            if (read < 0) break
            total += read
            require(total <= MAX_MAIN_BYTES) { "main.lua exceeds the launcher bridge size limit" }
            output.write(buffer, 0, read)
        }
        return output.toByteArray()
    }

    private fun luaString(value: String?): String {
        if (value == null) return "nil"
        return buildString(value.length + 2) {
            append('"')
            value.forEach { character ->
                when (character) {
                    '\\' -> append("\\\\")
                    '"' -> append("\\\"")
                    '\n' -> append("\\n")
                    '\r' -> append("\\r")
                    '\t' -> append("\\t")
                    else -> {
                        if (character.code < 32 || character.code == 127) {
                            append("\\")
                            append(character.code.toString().padStart(3, '0'))
                        } else {
                            append(character)
                        }
                    }
                }
            }
            append('"')
        }
    }

    private fun validateOutput(file: File) {
        require(file.isFile && file.length() > 0L) { "Launcher bridge output is empty" }
        ZipFile(file).use { zip ->
            require(zip.getEntry("main.lua") != null) { "Launcher bridge output is missing main.lua" }
        }
    }

    private fun ensureNotInterrupted() {
        if (Thread.currentThread().isInterrupted) {
            throw CancellationException("Launcher bridge cancelled")
        }
    }

    private class InterruptibleInputStream(input: InputStream) : FilterInputStream(input) {
        override fun read(): Int {
            ensureNotInterrupted()
            return super.read()
        }

        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            ensureNotInterrupted()
            return super.read(buffer, offset, length)
        }
    }
}

internal data class LauncherEnvironmentInfo(
    val packageType: String,
    val isKristalMod: Boolean,
    val gameVersion: String?,
    val engineVersion: String?,
    val runtimeTag: String?,
    val runtimeVersion: String?,
    val activePatchIds: List<String>,
    val translationLanguage: String?
)
