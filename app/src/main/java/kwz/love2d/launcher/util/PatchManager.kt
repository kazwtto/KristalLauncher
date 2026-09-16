package kwz.love2d.launcher.util

import android.content.Context
import android.graphics.Color
import androidx.core.content.ContextCompat
import kwz.love2d.launcher.BuildConfig
import com.google.android.material.color.MaterialColors
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.InstalledPatch
import kwz.love2d.launcher.model.PatchApplicationResult
import kwz.love2d.launcher.model.PatchOperation
import kwz.love2d.launcher.model.TranslationPlan
import org.apache.commons.compress.archivers.zip.ZipArchiveEntry
import org.apache.commons.compress.archivers.zip.ZipArchiveOutputStream
import org.apache.commons.compress.archivers.zip.ZipFile as CommonsZipFile
import java.io.File
import java.io.FilterInputStream
import java.io.InputStream
import java.security.MessageDigest
import java.util.Locale
import java.util.zip.ZipFile
import kotlinx.coroutines.CancellationException

object PatchManager {

    const val PATCH_FULLSCREEN = "patch_fullscreen"
    const val PATCH_SHADERS = "patch_shaders"
    const val PATCH_GAMEPAD = "patch_gamepad"
    const val PATCH_RGBA16 = "patch_rgba16"
    const val PATCH_PHYSFS = "patch_physfs"
    const val PATCH_NIL_ARITHMETIC = "patch_nil_arithmetic"
    const val PATCH_BORDERS = "patch_borders"
    const val PATCH_TEXT = "patch_text"

    const val MODE_GLOBAL = 0
    const val MODE_FORCE_ENABLED = 1
    const val MODE_FORCE_DISABLED = 2

    private const val GAMEPAD_ASSET_ROOT = "gamepad"
    private const val GAMEPAD_ARCHIVE_ROOT = "kristal_launcher/gamepad"
    private const val PATCH_SCRIPT_ARCHIVE_PATH = "kristal_launcher/android_patches.lua"
    private const val MAX_ARCHIVE_ENTRIES = 20_000
    private const val MAX_TRANSFORMED_ENTRY_BYTES = 16 * 1024 * 1024
    private const val MAX_TOTAL_UNCOMPRESSED_BYTES = 1024L * 1024 * 1024

    val ALL_PATCH_KEYS = listOf(
        PATCH_TEXT,
        PATCH_FULLSCREEN,
        PATCH_SHADERS,
        PATCH_GAMEPAD,
        PATCH_BORDERS,
        PATCH_RGBA16,
        PATCH_PHYSFS,
        PATCH_NIL_ARITHMETIC
    )

    fun isGlobalPatchEnabled(context: Context, patchKey: String): Boolean {
        val defaultEnabled = PatchRegistry.findBuiltIn(patchKey)?.defaultEnabled ?: false
        val preferences = context.getSharedPreferences("launcher_prefs", Context.MODE_PRIVATE)
        return preferences.getBoolean("global_$patchKey", defaultEnabled)
    }

    fun setGlobalPatchEnabled(context: Context, patchKey: String, enabled: Boolean) {
        context.getSharedPreferences("launcher_prefs", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("global_$patchKey", enabled)
            .apply()
    }

    fun getGamePatchMode(context: Context, gameFileName: String, patchKey: String): Int {
        val preferences = context.getSharedPreferences("launcher_prefs", Context.MODE_PRIVATE)
        return preferences.getInt(gamePreferenceKey(gameFileName, patchKey), MODE_GLOBAL)
    }

    fun setGamePatchMode(context: Context, gameFileName: String, patchKey: String, mode: Int) {
        require(mode in MODE_GLOBAL..MODE_FORCE_DISABLED) { "Invalid patch mode: $mode" }
        context.getSharedPreferences("launcher_prefs", Context.MODE_PRIVATE)
            .edit()
            .putInt(gamePreferenceKey(gameFileName, patchKey), mode)
            .apply()
    }

    fun isPatchEnabledForGame(context: Context, gameFileName: String, patchKey: String): Boolean {
        return when (getGamePatchMode(context, gameFileName, patchKey)) {
            MODE_FORCE_ENABLED -> true
            MODE_FORCE_DISABLED -> false
            else -> isGlobalPatchEnabled(context, patchKey)
        }
    }

    fun hasAnyPatchEnabled(context: Context, gameFileName: String): Boolean {
        val externalIds = PatchStorage.getInstalledPatches(context).map { it.manifest.id }
        return (ALL_PATCH_KEYS + externalIds).any { isPatchEnabledForGame(context, gameFileName, it) }
    }

    fun getPatchStateFingerprint(context: Context, gameFileName: String): String {
        val builtInState = ALL_PATCH_KEYS.map { id ->
            "$id:${isPatchEnabledForGame(context, gameFileName, id)}"
        }
        val externalState = PatchStorage.getInstalledPatches(context).map { patch ->
            "${patch.manifest.id}:${patch.manifest.version}:${isPatchEnabledForGame(context, gameFileName, patch.manifest.id)}"
        }
        val gamepadRuntimeState = if (isPatchEnabledForGame(context, gameFileName, PATCH_GAMEPAD)) {
            val runtimeConfig = getGamepadRuntimeConfig(context)
            listOf(
                "gamepadLanguage:${runtimeConfig.language}",
                "gamepadAccent:${Integer.toHexString(runtimeConfig.accentColor)}"
            )
        } else {
            emptyList()
        }
        return (builtInState + externalState + gamepadRuntimeState).sorted().joinToString("|")
    }

    /**
     * Writes a patched copy without mutating [sourceFile].
     *
     * Unchanged ZIP entries are copied in their already-compressed form. Only the few entries a
     * patch changes are inflated and compressed again, which avoids spending CPU on the game's
     * audio, sprites, and other unchanged assets.
     */
    fun writePatchedGame(
        context: Context,
        sourceFile: File,
        outputFile: File,
        gameFileName: String,
        translationPlan: TranslationPlan? = null
    ): PatchApplicationResult {
        val builtInFlags = BuiltInFlags(
            fullscreen = isPatchEnabledForGame(context, gameFileName, PATCH_FULLSCREEN),
            shaders = isPatchEnabledForGame(context, gameFileName, PATCH_SHADERS),
            gamepad = isPatchEnabledForGame(context, gameFileName, PATCH_GAMEPAD),
            rgba16 = isPatchEnabledForGame(context, gameFileName, PATCH_RGBA16),
            physFs = isPatchEnabledForGame(context, gameFileName, PATCH_PHYSFS),
            nilArithmetic = isPatchEnabledForGame(context, gameFileName, PATCH_NIL_ARITHMETIC),
            borders = isPatchEnabledForGame(context, gameFileName, PATCH_BORDERS),
            text = isPatchEnabledForGame(context, gameFileName, PATCH_TEXT)
        )

        return try {
            val externalPatches = resolveEnabledExternalPatches(context, gameFileName)
            if (!builtInFlags.anyEnabled && externalPatches.isEmpty() && translationPlan == null) {
                return PatchApplicationResult.Success(emptyList())
            }

            require(sourceFile.isFile && sourceFile.length() > 0L) { "Staged game is unavailable" }
            require(sourceFile.canonicalFile != outputFile.canonicalFile) {
                "Patched output must not replace its source"
            }
            outputFile.delete()
            val rewriteResult = rewriteStagedPackage(
                context,
                sourceFile,
                outputFile,
                builtInFlags,
                externalPatches,
                translationPlan
            )
            validateStagedPackage(outputFile)
            validateExternalPatchTargets(outputFile, rewriteResult.externalTargetDigests)

            val applied = buildList {
                if (builtInFlags.text && rewriteResult.textPatchChanged) add(PATCH_TEXT)
                if (builtInFlags.fullscreen) add(PATCH_FULLSCREEN)
                if (builtInFlags.shaders) add(PATCH_SHADERS)
                if (builtInFlags.gamepad) add(PATCH_GAMEPAD)
                if (builtInFlags.borders) add(PATCH_BORDERS)
                if (builtInFlags.rgba16) add(PATCH_RGBA16)
                if (builtInFlags.physFs) add(PATCH_PHYSFS)
                if (builtInFlags.nilArithmetic) add(PATCH_NIL_ARITHMETIC)
                addAll(externalPatches.map { it.manifest.id })
            }
            PatchApplicationResult.Success(applied)
        } catch (error: CancellationException) {
            outputFile.delete()
            throw error
        } catch (error: Exception) {
            outputFile.delete()
            PatchApplicationResult.Failure(
                reason = error.message ?: "Patch pipeline failed",
                cause = error
            )
        }
    }

    private fun rewriteStagedPackage(
        context: Context,
        sourceFile: File,
        outputFile: File,
        builtInFlags: BuiltInFlags,
        externalPatches: List<InstalledPatch>,
        translationPlan: TranslationPlan?
    ): RewriteResult {
        val resolvedOperations = externalPatches.flatMap { patch ->
            patch.manifest.operations.map { operation -> ResolvedOperation(patch, operation) }
        }
        validateOperationCollisions(resolvedOperations)
        val operationsByTarget = resolvedOperations.groupBy { it.operation.target.lowercase(Locale.ROOT) }
        val processedOperations = mutableSetOf<ResolvedOperation>()
        val existingEntries = mutableSetOf<String>()
        val externalTargetDigests = mutableMapOf<String, String>()
        val appliedTranslationFiles = mutableSetOf<String>()
        var hasMainLua = false
        var textPatchChanged = false
        var entryCount = 0
        var totalUncompressed = 0L

        CommonsZipFile.builder().setFile(sourceFile).get().use { sourceZip ->
            ZipArchiveOutputStream(outputFile).use { zipOutput ->
                val entries = sourceZip.entries
                while (entries.hasMoreElements()) {
                    ensureNotInterrupted()
                    val entry = entries.nextElement()
                    entryCount++
                    require(entryCount <= MAX_ARCHIVE_ENTRIES) { "Staged game contains too many entries" }
                    val entryName = entry.name
                    val normalizedName = entryName.lowercase(Locale.ROOT)
                    require(PatchManifestParser.isSafeArchivePath(entryName)) {
                        "Unsafe path in staged game: $entryName"
                    }
                    require(existingEntries.add(normalizedName)) { "Duplicate entry in staged game: $entryName" }
                    if (normalizedName == "main.lua") hasMainLua = true

                    val targetOperations = operationsByTarget[normalizedName].orEmpty()
                    val translationReplacements = translationPlan?.replacementsByPath?.get(normalizedName).orEmpty()
                    val translationFile = translationPlan?.filesByPath?.get(normalizedName)
                    val needsTransformation = normalizedName == "main.lua" ||
                        (builtInFlags.text && normalizedName in textPatchTargets) ||
                        targetOperations.isNotEmpty() ||
                        translationReplacements.isNotEmpty() ||
                        translationFile != null

                    if (needsTransformation) {
                        var bytes = sourceZip.getInputStream(entry).use { input ->
                            readEntryBytesLimited(input, MAX_TRANSFORMED_ENTRY_BYTES)
                        }
                        totalUncompressed += bytes.size
                        if (translationFile != null) {
                            bytes = TranslationManager.applyFileReplacement(bytes, translationFile)
                            appliedTranslationFiles += normalizedName
                        }
                        if (translationReplacements.isNotEmpty()) {
                            bytes = TranslationManager.applyToLua(bytes, translationReplacements)
                        }
                        if (normalizedName == "main.lua") {
                            // Kristal compiles its built-in shaders while main.lua loads
                            // engine modules. Install only that hook before the game code;
                            // the rest still runs from the normal Lua footer, after setup.
                            if (builtInFlags.shaders) {
                                val header = buildEarlyShaderBootstrap() + "\n"
                                bytes = header.toByteArray(Charsets.UTF_8) + bytes
                            }
                            if (builtInFlags.hasDeferredRuntimePatches) {
                                bytes = appendLuaFooter(bytes, buildBuiltInBootstrap(context, builtInFlags))
                            }
                        }
                        if (builtInFlags.text && normalizedName in textPatchTargets) {
                            val patched = applyBuiltInTextPatch(bytes)
                            bytes = patched.bytes
                            textPatchChanged = textPatchChanged || patched.changed
                        }
                        targetOperations.forEach { resolved ->
                            bytes = applyExternalOperation(bytes, resolved, targetExists = true)
                            processedOperations.add(resolved)
                        }
                        if (targetOperations.isNotEmpty()) {
                            externalTargetDigests[normalizedName] = sha256(bytes)
                        }
                        require(bytes.size <= MAX_TRANSFORMED_ENTRY_BYTES) {
                            "Patched file is too large: $entryName"
                        }
                        writeArchiveEntry(zipOutput, entryName, bytes, entry.time)
                    } else {
                        val entrySize = entry.size
                        require(entrySize >= 0L) { "Staged game contains an entry with unknown size: $entryName" }
                        totalUncompressed += entrySize
                        require(totalUncompressed <= MAX_TOTAL_UNCOMPRESSED_BYTES) {
                            "Staged game expands beyond the supported size"
                        }
                        copyRawEntry(sourceZip, entry, zipOutput)
                    }
                    require(totalUncompressed <= MAX_TOTAL_UNCOMPRESSED_BYTES) {
                        "Staged game expands beyond the supported size"
                    }
                }

                require(hasMainLua) { "The staged package does not contain main.lua" }
                val missingTranslationFiles = translationPlan?.filesByPath.orEmpty().keys - appliedTranslationFiles
                require(missingTranslationFiles.isEmpty()) {
                    "Translation targets are missing from this game: ${missingTranslationFiles.first()}"
                }

                if (builtInFlags.hasRuntimePatches) {
                    injectAndroidPatchesScript(context, zipOutput, existingEntries)
                }
                if (builtInFlags.gamepad) {
                    injectGamepadAssets(context, zipOutput, existingEntries)
                }

                writeMissingOperationTargets(
                    resolvedOperations.filterNot { it in processedOperations },
                    zipOutput,
                    existingEntries,
                    externalTargetDigests
                )
            }
        }
        return RewriteResult(textPatchChanged, externalTargetDigests)
    }

    /** Copies an unchanged entry without inflating or recompressing its payload. */
    internal fun copyRawEntry(
        sourceZip: CommonsZipFile,
        entry: ZipArchiveEntry,
        outputZip: ZipArchiveOutputStream
    ) {
        sourceZip.getRawInputStream(entry).use { rawInput ->
            outputZip.addRawArchiveEntry(entry, InterruptibleInputStream(rawInput))
        }
    }

    private fun writeMissingOperationTargets(
        operations: List<ResolvedOperation>,
        zipOutput: ZipArchiveOutputStream,
        existingEntries: MutableSet<String>,
        externalTargetDigests: MutableMap<String, String>
    ) {
        operations.groupBy { it.operation.target.lowercase(Locale.ROOT) }
            .forEach { (normalizedTarget, targetOperations) ->
                var bytes: ByteArray? = null
                targetOperations.forEach { resolved ->
                    val operation = resolved.operation
                    when {
                        operation.type == "inject" -> {
                            require(bytes == null) { "Multiple patches create ${operation.target}" }
                            bytes = readOperationSource(resolved)
                        }
                        bytes != null -> {
                            bytes = applyExternalOperation(bytes!!, resolved, targetExists = true)
                        }
                        operation.required -> {
                            throw IllegalArgumentException(
                                "Patch ${resolved.patch.manifest.id} requires missing file ${operation.target}"
                            )
                        }
                    }
                }

                bytes?.let { outputBytes ->
                    require(outputBytes.size <= MAX_TRANSFORMED_ENTRY_BYTES) {
                        "Patched file is too large: ${targetOperations.first().operation.target}"
                    }
                    require(existingEntries.add(normalizedTarget)) {
                        "Patch target already exists: ${targetOperations.first().operation.target}"
                    }
                    writeArchiveEntry(zipOutput, targetOperations.first().operation.target, outputBytes)
                    externalTargetDigests[normalizedTarget] = sha256(outputBytes)
                }
            }
    }

    private fun readEntryBytesLimited(input: InputStream, maximumBytes: Int): ByteArray {
        val output = java.io.ByteArrayOutputStream(minOf(maximumBytes, 64 * 1024))
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0
        while (true) {
            ensureNotInterrupted()
            val read = input.read(buffer)
            if (read < 0) break
            total += read
            require(total <= maximumBytes) { "Patch target expands beyond the supported size" }
            output.write(buffer, 0, read)
        }
        return output.toByteArray()
    }

    private fun applyExternalOperation(
        original: ByteArray,
        resolved: ResolvedOperation,
        targetExists: Boolean
    ): ByteArray {
        val operation = resolved.operation
        return when (operation.type) {
            "inject" -> {
                require(operation.replaceExisting || !targetExists) {
                    "Patch ${resolved.patch.manifest.id} attempted to overwrite ${operation.target}"
                }
                readOperationSource(resolved)
            }
            "append_text" -> {
                val addition = readOperationSource(resolved).toString(Charsets.UTF_8)
                if (operation.target.equals("main.lua", ignoreCase = true)) {
                    appendLuaFooter(original, addition)
                } else {
                    appendUtf8(original, addition)
                }
            }
            "replace_text" -> {
                val text = original.toString(Charsets.UTF_8)
                val find = operation.find.orEmpty()
                if (operation.required) {
                    require(text.contains(find)) {
                        "Patch ${resolved.patch.manifest.id} could not find its target text in ${operation.target}"
                    }
                }
                text.replace(find, operation.replace.orEmpty()).toByteArray(Charsets.UTF_8)
            }
            else -> throw IllegalArgumentException("Unsupported patch operation: ${operation.type}")
        }
    }

    private fun readOperationSource(resolved: ResolvedOperation): ByteArray {
        val sourcePath = resolved.operation.source
            ?: throw IllegalArgumentException("Patch operation is missing a source file")
        val root = resolved.patch.directory.canonicalFile
        val sourceFile = File(root, sourcePath).canonicalFile
        require(sourceFile.path.startsWith(root.path + File.separator) && sourceFile.isFile) {
            "Patch source file is unavailable: $sourcePath"
        }
        require(sourceFile.length() <= 10L * 1024 * 1024) { "Patch source file is too large: $sourcePath" }
        return sourceFile.readBytes()
    }

    private fun validateOperationCollisions(operations: List<ResolvedOperation>) {
        operations.groupBy { it.operation.target.lowercase(Locale.ROOT) }.forEach { (target, targetOperations) ->
            val injectOperations = targetOperations.filter { it.operation.type == "inject" }
            require(injectOperations.size <= 1) { "Multiple patches inject the same file: $target" }
        }
    }

    private fun resolveEnabledExternalPatches(context: Context, gameFileName: String): List<InstalledPatch> {
        val installed = PatchStorage.getInstalledPatches(context).associateBy { it.manifest.id }
        val enabled = installed.values.filter {
            isPatchEnabledForGame(context, gameFileName, it.manifest.id)
        }.associateBy { it.manifest.id }

        enabled.values.forEach { patch ->
            patch.manifest.minimumLauncherVersion?.let { minimumVersion ->
                require(!VersionUtils.isNewer(minimumVersion, BuildConfig.VERSION_NAME)) {
                    "Patch ${patch.manifest.id} requires launcher $minimumVersion or newer"
                }
            }
            patch.manifest.dependencies.forEach { dependency ->
                val dependencyEnabled = if (dependency in ALL_PATCH_KEYS) {
                    isPatchEnabledForGame(context, gameFileName, dependency)
                } else {
                    dependency in enabled
                }
                require(dependencyEnabled) {
                    "Patch ${patch.manifest.id} requires enabled patch $dependency"
                }
            }
            patch.manifest.conflicts.forEach { conflict ->
                val conflictEnabled = if (conflict in ALL_PATCH_KEYS) {
                    isPatchEnabledForGame(context, gameFileName, conflict)
                } else {
                    conflict in enabled
                }
                require(!conflictEnabled) { "Patch ${patch.manifest.id} conflicts with $conflict" }
            }
        }

        val ordered = mutableListOf<InstalledPatch>()
        val visiting = mutableSetOf<String>()
        val visited = mutableSetOf<String>()

        fun visit(id: String) {
            if (id in visited) return
            require(visiting.add(id)) { "Circular patch dependency involving $id" }
            val patch = enabled[id] ?: return
            patch.manifest.dependencies.filter { it in enabled }.sorted().forEach(::visit)
            visiting.remove(id)
            visited.add(id)
            ordered.add(patch)
        }

        enabled.values.sortedWith(compareBy({ it.manifest.priority }, { it.manifest.id }))
            .forEach { visit(it.manifest.id) }
        return ordered
    }

    private fun buildBuiltInBootstrap(context: Context, flags: BuiltInFlags): String {
        val gamepadRuntimeConfig = getGamepadRuntimeConfig(context)
        val accent = gamepadRuntimeConfig.accentColor
        return """

        -- [[ START: KRISTAL LAUNCHER COMPATIBILITY PATCHES ]] --
        _G.PATCH_FULLSCREEN = ${flags.fullscreen}
        _G.PATCH_SHADERS = ${flags.shaders}
        _G.PATCH_GAMEPAD = ${flags.gamepad}
        _G.PATCH_RGBA16 = ${flags.rgba16}
        _G.PATCH_PHYSFS = ${flags.physFs}
        _G.PATCH_NIL_ARITHMETIC = ${flags.nilArithmetic}
        _G.PATCH_BORDERS = ${flags.borders}
        _G.PATCH_TEXT = ${flags.text}
        _G.KRISTAL_LAUNCHER_LANGUAGE = "${gamepadRuntimeConfig.language}"
        _G.KRISTAL_LAUNCHER_ACCENT = {
            ${Color.red(accent)} / 255,
            ${Color.green(accent)} / 255,
            ${Color.blue(accent)} / 255
        }
        require("kristal_launcher.android_patches").apply()
        -- [[ END: KRISTAL LAUNCHER COMPATIBILITY PATCHES ]] --
        """.trimIndent()
    }

    // Only the shader wrapper is safe and necessary before main.lua. Calling the
    // patch module in this mode leaves callbacks and Kristal-dependent patches
    // untouched until the footer invokes its regular apply() method.
    private fun buildEarlyShaderBootstrap(): String {
        return """
        -- [[ START: KRISTAL LAUNCHER EARLY SHADER PATCH ]] --
        _G.PATCH_SHADERS = true
        require("kristal_launcher.android_patches").apply(true)
        -- [[ END: KRISTAL LAUNCHER EARLY SHADER PATCH ]] --
        """.trimIndent()
    }

    private fun applyBuiltInTextPatch(original: ByteArray): TextPatchResult {
        var luaCode = original.toString(Charsets.UTF_8)
        val originalCode = luaCode
        luaCode = luaCode.replace(
            Regex("if\\s+self\\.width\\s*~=\\s*self\\.canvas:getWidth\\(\\)\\s+or\\s+self\\.height\\s*~=\\s*self\\.canvas:getHeight\\(\\)\\s*then\\s*(self\\.canvas\\s*=\\s*love\\.graphics\\.newCanvas\\(self\\.width,\\s*self\\.height\\))\\s*end"),
            "$1"
        )

        // Clear the canvas outside the active scissor and then restore the previous state.
        val safeClear = """
            local sx, sy, sw, sh = love.graphics.getScissor()
            love.graphics.setScissor()
            love.graphics.clear(0, 0, 0, 0)
            if sx then love.graphics.setScissor(sx, sy, sw, sh) end
        """.trimIndent()
        luaCode = luaCode.replace(
            Regex("if\\s+clear\\s*then\\s*love\\.graphics\\.clear\\(\\)\\s*end"),
            "if clear then\n$safeClear\nend"
        )
        return TextPatchResult(
            bytes = luaCode.toByteArray(Charsets.UTF_8),
            changed = luaCode != originalCode
        )
    }

    private fun appendUtf8(original: ByteArray, addition: String): ByteArray {
        return (original.toString(Charsets.UTF_8) + "\n" + addition).toByteArray(Charsets.UTF_8)
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

    private fun injectAndroidPatchesScript(
        context: Context,
        zipOutput: ZipArchiveOutputStream,
        existingEntries: MutableSet<String>
    ) {
        val assetName = "android_patches.lua"
        val normalizedTarget = PATCH_SCRIPT_ARCHIVE_PATH.lowercase(Locale.ROOT)
        require(existingEntries.add(normalizedTarget)) {
            "The game already contains the reserved launcher patch namespace"
        }
        context.assets.open(assetName).use { input ->
            writeArchiveEntry(zipOutput, PATCH_SCRIPT_ARCHIVE_PATH, input)
        }
    }

    private fun injectGamepadAssets(
        context: Context,
        zipOutput: ZipArchiveOutputStream,
        existingEntries: MutableSet<String>
    ) {
        val rootFiles = context.assets.list(GAMEPAD_ASSET_ROOT).orEmpty()
        require("main.lua" in rootFiles) { "Gamepad assets are missing main.lua" }
        copyAssetFolderToZip(context, GAMEPAD_ASSET_ROOT, "", zipOutput, existingEntries)
    }

    private fun copyAssetFolderToZip(
        context: Context,
        assetPath: String,
        targetPrefix: String,
        zipOutput: ZipArchiveOutputStream,
        existingEntries: MutableSet<String>
    ) {
        val files = context.assets.list(assetPath).orEmpty()
        for (file in files) {
            ensureNotInterrupted()
            val childAssetPath = if (assetPath.isEmpty()) file else "$assetPath/$file"
            val childTargetName = if (targetPrefix.isEmpty()) file else "$targetPrefix/$file"
            val childFiles = context.assets.list(childAssetPath)
            if (!childFiles.isNullOrEmpty()) {
                copyAssetFolderToZip(context, childAssetPath, childTargetName, zipOutput, existingEntries)
            } else {
                val zipPath = "$GAMEPAD_ARCHIVE_ROOT/$childTargetName"
                val normalizedTarget = zipPath.lowercase(Locale.ROOT)
                require(existingEntries.add(normalizedTarget)) {
                    "The game already contains reserved launcher gamepad file $zipPath"
                }
                context.assets.open(childAssetPath).use { input ->
                    writeArchiveEntry(zipOutput, zipPath, input)
                }
            }
        }
    }

    private fun writeArchiveEntry(
        zipOutput: ZipArchiveOutputStream,
        entryName: String,
        bytes: ByteArray,
        sourceTime: Long = -1L
    ) {
        zipOutput.putArchiveEntry(ZipArchiveEntry(entryName).apply {
            if (sourceTime >= 0L) time = sourceTime
        })
        zipOutput.write(bytes)
        zipOutput.closeArchiveEntry()
    }

    private fun writeArchiveEntry(
        zipOutput: ZipArchiveOutputStream,
        entryName: String,
        input: InputStream
    ) {
        zipOutput.putArchiveEntry(ZipArchiveEntry(entryName))
        copyInterruptibly(input, zipOutput)
        zipOutput.closeArchiveEntry()
    }

    private fun copyInterruptibly(input: InputStream, output: java.io.OutputStream) {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            ensureNotInterrupted()
            val read = input.read(buffer)
            if (read < 0) return
            output.write(buffer, 0, read)
        }
    }

    private fun ensureNotInterrupted() {
        if (Thread.currentThread().isInterrupted) {
            throw CancellationException("Patch application cancelled")
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

    private fun validateStagedPackage(file: File) {
        require(file.isFile && file.length() > 0L) { "Patched package is empty" }
        ZipFile(file).use { zip ->
            require(zip.getEntry("main.lua") != null) { "Patched package is missing main.lua" }
        }
    }

    /**
     * Reopens only the files touched by external patches and verifies their final bytes. A patch
     * is reported as applied only after the staged archive contains exactly what the rewrite pass
     * produced; an incomplete or corrupted write therefore cannot silently launch.
     */
    internal fun validateExternalPatchTargets(file: File, expectedDigests: Map<String, String>) {
        if (expectedDigests.isEmpty()) return
        ZipFile(file).use { zip ->
            val entriesByName = zip.entries().asSequence()
                .filterNot { it.isDirectory }
                .associateBy { it.name.lowercase(Locale.ROOT) }
            expectedDigests.forEach { (target, expectedDigest) ->
                val entry = entriesByName[target]
                    ?: throw IllegalArgumentException("Patched package is missing external target $target")
                val actualBytes = zip.getInputStream(entry).use { input ->
                    readEntryBytesLimited(input, MAX_TRANSFORMED_ENTRY_BYTES)
                }
                require(sha256(actualBytes) == expectedDigest) {
                    "External patch verification failed for $target"
                }
            }
        }
    }

    private fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes)
        .joinToString("") { "%02x".format(it) }

    private fun gamePreferenceKey(gameId: String, patchKey: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(gameId.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
        return "game_${digest.take(32)}_$patchKey"
    }

    private fun getGamepadRuntimeConfig(context: Context): GamepadRuntimeConfig {
        val themedContext = ThemeManager.themedContext(context)
        val language = LanguageManager.resolveGamepadLanguage(
            selectedLanguage = LanguageManager.getCurrentLanguage(context),
            deviceLanguage = context.resources.configuration.locales[0]?.language
        )
        return GamepadRuntimeConfig(
            language = language,
            accentColor = MaterialColors.getColor(
                themedContext,
                com.google.android.material.R.attr.colorPrimary,
                ContextCompat.getColor(context, R.color.m3_primary)
            )
        )
    }

    private data class GamepadRuntimeConfig(
        val language: String,
        val accentColor: Int
    )

    private data class BuiltInFlags(
        val fullscreen: Boolean,
        val shaders: Boolean,
        val gamepad: Boolean,
        val rgba16: Boolean,
        val physFs: Boolean,
        val nilArithmetic: Boolean,
        val borders: Boolean,
        val text: Boolean
    ) {
        val anyEnabled: Boolean
            get() = fullscreen || shaders || gamepad || rgba16 || physFs || nilArithmetic || borders || text

        val hasRuntimePatches: Boolean
            get() = fullscreen || shaders || gamepad || rgba16 || physFs || nilArithmetic || borders

        val hasDeferredRuntimePatches: Boolean
            get() = fullscreen || gamepad || rgba16 || physFs || nilArithmetic || borders
    }

    private data class ResolvedOperation(
        val patch: InstalledPatch,
        val operation: PatchOperation
    )

    private data class RewriteResult(
        val textPatchChanged: Boolean,
        val externalTargetDigests: Map<String, String>
    )

    private data class TextPatchResult(
        val bytes: ByteArray,
        val changed: Boolean
    )

    private val textPatchTargets = setOf(
        "src/engine/objects/text.lua",
        "src/engine/objects/dialoguetext.lua"
    )
}
