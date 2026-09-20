package kwz.love2d.launcher.util

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.view.LayoutInflater
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.KristalRuntimeSettingsActivity
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.model.InstalledKristalRuntime
import kwz.love2d.launcher.model.PatchApplicationResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runInterruptible
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withContext
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.io.SequenceInputStream
import java.security.MessageDigest
import java.util.Locale
import java.util.zip.ZipFile
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

object GameLauncher {

    private val launchMutex = Mutex()

    fun launchKristalRuntime(activity: AppCompatActivity, runtime: InstalledKristalRuntime) {
        launchGame(
            activity,
            LoveGame(
                title = activity.getString(R.string.kristal_runtime_launch_title, runtime.version),
                fileName = runtime.file.name,
                uri = Uri.fromFile(runtime.file),
                sizeBytes = runtime.file.length(),
                lastModified = runtime.file.lastModified(),
                subtitle = activity.getString(R.string.kristal_runtime_title),
                version = runtime.version,
                engineVer = runtime.version
            )
        )
    }

    fun launchGame(activity: AppCompatActivity, game: LoveGame) {
        val kristalRuntime = if (game.isKristalMod) {
            KristalRuntimeStorage.selectedRuntimeForGame(activity, game.stableId) ?: run {
                showMissingKristalRuntimeDialog(activity, game)
                return
            }
        } else {
            null
        }
        if (!launchMutex.tryLock()) {
            Toast.makeText(activity, R.string.game_launch_in_progress, Toast.LENGTH_SHORT).show()
            return
        }

        val dialogContext = ThemeManager.themedContext(activity)
        val dialogView = LayoutInflater.from(dialogContext).inflate(R.layout.dialog_loading, null)
        ThemeManager.applyDeltaruneStyle(activity, dialogView)
        val loadingMessage = dialogView.findViewById<TextView>(R.id.tvLoadingMessage).apply {
            if (ThemeManager.isDeltaruneTheme(activity)) textSize = 13f
        }
        val dialog = MaterialAlertDialogBuilder(dialogContext)
            .setView(dialogView)
            .setNegativeButton(R.string.cancel, null)
            .setCancelable(false)
            .create()
        dialog.showThemed()
        ThemeManager.applyDialogTheme(dialog)

        val launchJob: Job = activity.lifecycleScope.launch {
            try {
                val patchesEnabled = withContext(Dispatchers.IO) {
                    PatchManager.hasAnyPatchEnabled(activity.applicationContext, game.stableId)
                }
                loadingMessage.text = activity.getString(
                    if (patchesEnabled) R.string.preparing_game_with_patches else R.string.preparing_game,
                    game.title
                )

                val stagedFile = runInterruptible(Dispatchers.IO) {
                    prepareStagedGame(activity.applicationContext, game, kristalRuntime)
                }
                if (!activity.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) return@launch

                configureLoveRuntime(stagedFile)
                val contentUri = FileProvider.getUriForFile(
                    activity,
                    "${activity.packageName}.fileprovider",
                    stagedFile
                )
                val intent = Intent(Intent.ACTION_VIEW, contentUri).apply {
                    setClassName(activity.packageName, "org.love2d.android.GameActivity")
                    setDataAndType(contentUri, LOVE_MIME_TYPE)
                    putExtra("name", stagedFile.absolutePath)
                    putExtra("gamePath", stagedFile.absolutePath)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(intent)
            } catch (error: CancellationException) {
                throw error
            } catch (error: GameLaunchException) {
                Toast.makeText(activity, error.messageResource, Toast.LENGTH_LONG).show()
            } catch (error: Exception) {
                error.printStackTrace()
                Toast.makeText(
                    activity,
                    activity.getString(R.string.error_loading_game, error.message ?: error.javaClass.simpleName),
                    Toast.LENGTH_LONG
                ).show()
            } finally {
                if (dialog.isShowing) dialog.dismiss()
                if (launchMutex.isLocked) launchMutex.unlock()
            }
        }

        dialog.getButton(AlertDialog.BUTTON_NEGATIVE).setOnClickListener {
            if (launchJob.isActive) {
                launchJob.cancel(CancellationException("Game launch cancelled by user"))
            }
            dialog.dismiss()
        }
    }

    private fun showMissingKristalRuntimeDialog(activity: AppCompatActivity, game: LoveGame) {
        val dialogContext = ThemeManager.themedContext(activity)
        MaterialAlertDialogBuilder(dialogContext)
            .setTitle(R.string.kristal_mod_runtime_required_title)
            .setMessage(activity.getString(R.string.kristal_mod_runtime_required_message, game.title))
            .setNegativeButton(R.string.cancel, null)
            .setPositiveButton(R.string.kristal_runtime_download) { _, _ ->
                activity.startActivity(Intent(activity, KristalRuntimeSettingsActivity::class.java))
            }
            .create()
            .also { dialog ->
                dialog.showThemed()
                ThemeManager.applyDialogTheme(dialog)
            }
    }

    /**
     * Restores the launch contract used by the known-working launcher snapshot.
     * The runtime receives both its current embed resource ID and the staged path;
     * the scoped content URI remains the source it opens in GameActivity.
     */
    private fun configureLoveRuntime(stagedFile: File) {
        try {
            val runtimeBooleanResources = Class.forName("org.love2d.android.i")
            runtimeBooleanResources.getDeclaredField("a").apply {
                isAccessible = true
                setInt(null, R.bool.embed)
            }

            val gameActivityClass = Class.forName("org.love2d.android.GameActivity")
            val gamePathField = gameActivityClass.getDeclaredField("gamePath")
            gamePathField.isAccessible = true
            gamePathField.set(null, stagedFile.absolutePath)
        } catch (_: ReflectiveOperationException) {
            throw GameLaunchException(R.string.error_incompatible_love_runtime)
        }
    }

    private fun prepareStagedGame(
        context: Context,
        game: LoveGame,
        kristalRuntime: InstalledKristalRuntime?
    ): File {
        val resolvedUri = resolveReadableUri(context, game)
            ?: throw GameLaunchException(R.string.error_game_file_unavailable)
        val metadata = queryMetadata(context, resolvedUri)
        val patchState = PatchManager.getPatchStateFingerprint(context, game.stableId)
        val patchesEnabled = PatchManager.hasAnyPatchEnabled(context, game.stableId)
        val translationPlan = TranslationManager.activePlan(context, game)
        val translationState = TranslationManager.stateFingerprint(context, game)
        val appUpdateTime = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
        val sourceFingerprint = if (metadata.lastModified > 0L && metadata.size >= 0L) {
            sha256("${resolvedUri}|${metadata.size}|${metadata.lastModified}|${game.archiveEntryPath.orEmpty()}")
        } else {
            val contentHash = context.contentResolver.openInputStream(resolvedUri)?.use(::sha256)
                ?: throw GameLaunchException(R.string.error_game_file_unavailable)
            sha256("$contentHash|${game.archiveEntryPath.orEmpty()}")
        }
        val runtimeFingerprint = kristalRuntime?.let {
            "${it.tag}|${it.file.length()}|${it.file.lastModified()}"
        }.orEmpty()
        val baseKey = sha256("$sourceFingerprint|$appUpdateTime|${game.packageType}|$runtimeFingerprint")
        val cacheKey = sha256("$baseKey|$patchState|$translationState")
        val stagedDirectory = File(context.filesDir, "staged").apply { mkdirs() }
        val baseFile = File(stagedDirectory, "base_$baseKey.love")
        val stagedFile = File(stagedDirectory, "game_$cacheKey.love")

        val transformationsEnabled = patchesEnabled || translationPlan != null
        val activeFile = if (transformationsEnabled) stagedFile else baseFile
        if (isReusableStagedPackage(activeFile)) {
            trimStagedCopies(stagedDirectory, activeFile, baseFile)
            return activeFile
        }

        ensureBaseGame(context, resolvedUri, game, kristalRuntime, baseFile)
        if (!transformationsEnabled) {
            trimStagedCopies(stagedDirectory, baseFile, baseFile)
            return baseFile
        }

        stagedFile.delete()
        val temporaryFile = File(stagedDirectory, "${stagedFile.name}.building")
        temporaryFile.delete()
        try {
            when (
                val result = PatchManager.writePatchedGame(
                    context,
                    baseFile,
                    temporaryFile,
                    game.stableId,
                    translationPlan
                )
            ) {
                is PatchApplicationResult.Success -> Unit
                is PatchApplicationResult.Failure -> throw IllegalArgumentException(result.reason, result.cause)
            }
            check(temporaryFile.renameTo(stagedFile)) { "Could not publish the patched game" }
        } finally {
            temporaryFile.delete()
        }
        trimStagedCopies(stagedDirectory, stagedFile, baseFile)
        return stagedFile
    }

    /**
     * Keeps a normalized private source copy separate from patched variants. Changing a patch now
     * reuses this local copy instead of reading the user's package from Storage Access Framework
     * again.
     */
    private fun ensureBaseGame(
        context: Context,
        sourceUri: Uri,
        game: LoveGame,
        kristalRuntime: InstalledKristalRuntime?,
        baseFile: File
    ) {
        if (isReusableStagedPackage(baseFile)) return

        baseFile.delete()
        val temporaryFile = File(baseFile.parentFile, "${baseFile.name}.building")
        temporaryFile.delete()
        try {
            if (game.isKristalMod) {
                val runtime = kristalRuntime
                    ?: throw GameLaunchException(R.string.kristal_mod_runtime_missing_error)
                val modId = game.projectId
                    ?.trim()
                    ?.takeIf(String::isNotBlank)
                    ?: game.modArchiveRoot
                        ?.substringAfterLast('/')
                        ?.takeIf(String::isNotBlank)
                    ?: throw GameLaunchException(R.string.kristal_mod_invalid_error)
                context.contentResolver.openInputStream(sourceUri)?.buffered(COPY_BUFFER_SIZE)?.use { modSource ->
                    writeKristalModPackage(
                        runtimeFile = runtime.file,
                        modSource = modSource,
                        modArchiveRoot = game.modArchiveRoot.orEmpty(),
                        modId = modId,
                        destination = temporaryFile
                    )
                } ?: throw GameLaunchException(R.string.error_game_file_unavailable)
            } else {
                copyGamePayload(context, sourceUri, game, temporaryFile)
                try {
                    LoveArchiveNormalizer.normalizeRootInPlace(temporaryFile)
                } catch (_: Exception) {
                    throw GameLaunchException(R.string.error_empty_or_corrupt_game)
                }
            }
            validateLovePackage(temporaryFile)
            check(temporaryFile.renameTo(baseFile)) { "Could not publish the staged game" }
        } finally {
            temporaryFile.delete()
        }
    }

    /** Materializes a private, normalized source archive for the translation editor. */
    internal fun materializeTranslationSource(context: Context, game: LoveGame): File {
        val directory = File(context.cacheDir, "translation_sources").apply { mkdirs() }
        val key = sha256("${game.stableId}|${game.sizeBytes}|${game.lastModified}|${game.packageType}")
        val destination = File(directory, "$key.zip")
        if (destination.isFile && destination.length() > 0L) return destination

        val sourceUri = resolveReadableUri(context, game)
            ?: throw GameLaunchException(R.string.error_game_file_unavailable)
        val temporary = File(directory, "$key.building")
        temporary.delete()
        try {
            if (game.isKristalMod) {
                context.contentResolver.openInputStream(sourceUri)?.use { input ->
                    FileOutputStream(temporary).buffered(COPY_BUFFER_SIZE).use { output ->
                        copyInterruptibly(input, output)
                    }
                } ?: throw GameLaunchException(R.string.error_game_file_unavailable)
            } else {
                copyGamePayload(context, sourceUri, game, temporary)
                LoveArchiveNormalizer.normalizeRootInPlace(temporary)
            }
            GameArchive.open(temporary).use { archive ->
                requireNotNull(archive.firstEntry()) { "The game/mod archive is empty" }
            }
            check(temporary.renameTo(destination)) { "Could not publish the translation source" }
            return destination
        } finally {
            temporary.delete()
        }
    }

    /** Builds a private runnable Kristal package without changing either source archive. */
    internal fun writeKristalModPackage(
        runtimeFile: File,
        modSource: InputStream,
        modArchiveRoot: String,
        modId: String,
        destination: File
    ) {
        val targetFolder = modId.replace(Regex("[^A-Za-z0-9_.-]"), "_")
            .trim('_', '.')
            .takeIf(String::isNotBlank)
            ?: throw IllegalArgumentException("The mod ID cannot be used as a folder name")
        val targetPrefix = "mods/$targetFolder/"
        val normalizedRoot = LoveArchiveNormalizer.normalizePath(modArchiveRoot).trimEnd('/')
        var configuredRuntime = false
        var copiedManifest = false

        ZipOutputStream(FileOutputStream(destination).buffered(COPY_BUFFER_SIZE)).use { output ->
            ZipFile(runtimeFile).use { runtime ->
                val runtimeEntries = runtime.entries().asSequence().toList()
                for (entry in runtimeEntries) {
                    ensureNotInterrupted()
                    val outputPath = canonicalArchivePath(entry.name) ?: continue
                    val pathKey = outputPath.lowercase(Locale.ROOT)
                    if (pathKey.startsWith(targetPrefix.lowercase(Locale.ROOT))) continue
                    val outputEntry = ZipEntry(if (entry.isDirectory) "$outputPath/" else outputPath)
                        .apply { time = entry.time }
                    output.putNextEntry(outputEntry)
                    if (!entry.isDirectory) {
                        runtime.getInputStream(entry).use { input ->
                            if (pathKey == "main.lua") {
                                val source = input.bufferedReader(Charsets.UTF_8).use { it.readText() }
                                val configured = configureKristalEntryPoint(source, modId)
                                output.write(configured.toByteArray(Charsets.UTF_8))
                                configuredRuntime = configured != source
                            } else {
                                copyInterruptibly(input, output)
                            }
                        }
                    }
                    output.closeEntry()
                }
            }
            if (!configuredRuntime) {
                throw IllegalArgumentException("The selected Kristal runtime has an unsupported main.lua")
            }

            ZipInputStream(modSource).use { modArchive ->
                var entry = modArchive.nextEntry
                var entryCount = 0
                val rootPartCount = normalizedRoot
                    .split('/')
                    .count(String::isNotBlank)
                while (entry != null) {
                    ensureNotInterrupted()
                    entryCount++
                    if (entryCount > MAX_WRAPPER_ENTRIES) {
                        throw IllegalArgumentException("The mod archive contains too many files")
                    }
                    val sourcePath = canonicalArchivePath(entry.name).orEmpty()
                    val sourcePathKey = sourcePath.lowercase(Locale.ROOT)
                    val relativePath = when {
                        normalizedRoot.isBlank() -> sourcePath
                        sourcePathKey == normalizedRoot -> ""
                        sourcePathKey.startsWith("$normalizedRoot/") ->
                            sourcePath.split('/').drop(rootPartCount).joinToString("/")
                        else -> ""
                    }
                    if (!entry.isDirectory && relativePath.isNotBlank()) {
                        val destinationPath = "$targetPrefix$relativePath"
                        output.putNextEntry(ZipEntry(destinationPath).apply { time = entry.time })
                        copyInterruptibly(modArchive, output)
                        output.closeEntry()
                        if (relativePath.equals("mod.json", ignoreCase = true)) copiedManifest = true
                    }
                    modArchive.closeEntry()
                    entry = modArchive.nextEntry
                }
            }
        }
        if (!copiedManifest) {
            destination.delete()
            throw IllegalArgumentException("The mod archive does not contain mod.json at its detected root")
        }
    }

    private fun configureKristalEntryPoint(source: String, modId: String): String {
        val escapedId = modId
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\r", "\\r")
            .replace("\n", "\\n")
        val configuration = "TARGET_MOD = \"$escapedId\"\nAUTO_MOD_START = true\n"
        val marker = KRISTAL_REQUIRE.find(source) ?: return source
        return source.substring(0, marker.range.first) + configuration + source.substring(marker.range.first)
    }

    private fun canonicalArchivePath(path: String): String? {
        if (path.isBlank() || path.length > 1_024 || '\u0000' in path || ':' in path) return null
        val parts = path.replace('\\', '/')
            .split('/')
            .filter { it.isNotBlank() && it != "." }
        if (parts.isEmpty() || parts.any { it == ".." }) return null
        return parts.joinToString("/")
    }

    private fun isReusableStagedPackage(file: File): Boolean {
        return file.isFile && file.length() > 0L && runCatching {
            validateLovePackage(file)
        }.isSuccess
    }

    private fun trimStagedCopies(stagedDirectory: File, activeFile: File, baseFile: File) {
        val protectedFiles = setOf(activeFile, baseFile)
        stagedDirectory.listFiles().orEmpty()
            .filter { file ->
                file.isFile && file.extension.equals("love", true) && file !in protectedFiles
            }
            .sortedByDescending(File::lastModified)
            .drop(MAX_ADDITIONAL_STAGED_VARIANTS)
            .forEach(File::delete)
    }

    private fun resolveReadableUri(context: Context, game: LoveGame): Uri? {
        if (canOpen(context, game.uri)) return game.uri
        val folder = FolderPermissionManager.getSavedFolderUri(context) ?: return null
        return runCatching {
            DocumentFile.fromTreeUri(context, folder)
                ?.listFiles()
                ?.firstOrNull { it.name == game.fileName }
                ?.uri
                ?.takeIf { canOpen(context, it) }
        }.getOrNull()
    }

    private fun canOpen(context: Context, uri: Uri): Boolean {
        return runCatching {
            context.contentResolver.openInputStream(uri)?.use { true } ?: false
        }.getOrDefault(false)
    }

    private fun queryMetadata(context: Context, uri: Uri): SourceMetadata {
        var size = -1L
        var lastModified = 0L
        runCatching {
            context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getColumnIndex(OpenableColumns.SIZE).takeIf { it >= 0 }?.let { size = cursor.getLong(it) }
                    cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                        .takeIf { it >= 0 }
                        ?.let { lastModified = cursor.getLong(it) }
                }
            }
        }
        return SourceMetadata(size, lastModified)
    }

    private fun copyGamePayload(context: Context, uri: Uri, game: LoveGame, outputFile: File) {
        val input = context.contentResolver.openInputStream(uri)?.buffered(COPY_BUFFER_SIZE)
            ?: throw GameLaunchException(R.string.error_game_file_unavailable)
        input.use { source ->
            FileOutputStream(outputFile).use { destination ->
                when {
                    game.archiveEntryPath != null -> copyNestedPackage(
                        source = source,
                        outerFileName = game.fileName,
                        entryPath = game.archiveEntryPath,
                        destination = destination
                    )
                    game.fileName.endsWith(".exe", ignoreCase = true) -> {
                        copyExecutablePayload(source, destination)
                    }
                    else -> copyInterruptibly(source, destination)
                }
            }
        }
        if (outputFile.length() == 0L) throw GameLaunchException(R.string.error_empty_or_corrupt_game)
    }

    internal fun copyNestedPackage(
        source: InputStream,
        outerFileName: String,
        entryPath: String,
        destination: OutputStream
    ) {
        val outerPayload = if (outerFileName.endsWith(".exe", ignoreCase = true)) {
            findExecutablePayload(source)
                ?: throw GameLaunchException(R.string.error_invalid_love_executable)
        } else {
            source
        }
        val targetPath = LoveArchiveNormalizer.normalizePath(entryPath)
        if (targetPath.isBlank()) throw GameLaunchException(R.string.error_nested_game_unavailable)
        var found = false
        var entryCount = 0
        ZipInputStream(outerPayload).use { archive ->
            var entry = archive.nextEntry
            while (entry != null) {
                entryCount++
                if (entryCount > MAX_WRAPPER_ENTRIES) {
                    throw GameLaunchException(R.string.error_empty_or_corrupt_game)
                }
                val rawPath = entry.name
                val normalizedPath = LoveArchiveNormalizer.normalizePath(rawPath)
                if (!entry.isDirectory && normalizedPath == targetPath) {
                    if (rawPath.endsWith(".exe", ignoreCase = true)) {
                        copyExecutablePayload(archive.buffered(EXECUTABLE_SCAN_BUFFER_SIZE), destination)
                    } else {
                        copyInterruptibly(archive, destination)
                    }
                    found = true
                    break
                }
                archive.closeEntry()
                entry = archive.nextEntry
            }
        }
        if (!found) throw GameLaunchException(R.string.error_nested_game_unavailable)
    }

    private fun copyExecutablePayload(source: InputStream, destination: OutputStream) {
        val payload = findExecutablePayload(source)
            ?: throw GameLaunchException(R.string.error_invalid_love_executable)
        copyInterruptibly(payload, destination)
    }

    internal fun findExecutablePayload(source: InputStream): InputStream? {
        var matched = 0
        var scanned = 0L
        while (scanned < MAX_EXECUTABLE_PREFIX_BYTES) {
            ensureNotInterrupted()
            val value = source.read()
            if (value < 0) return null
            scanned++
            matched = when {
                value.toByte() == ZIP_LOCAL_HEADER[matched] -> matched + 1
                value.toByte() == ZIP_LOCAL_HEADER[0] -> 1
                else -> 0
            }
            if (matched == ZIP_LOCAL_HEADER.size) {
                return SequenceInputStream(ByteArrayInputStream(ZIP_LOCAL_HEADER), source)
            }
        }
        return null
    }

    private fun validateLovePackage(file: File) {
        try {
            ZipFile(file).use { zip ->
                if (zip.getEntry("main.lua") == null) {
                    throw GameLaunchException(R.string.error_empty_or_corrupt_game)
                }
            }
        } catch (error: GameLaunchException) {
            throw error
        } catch (_: Exception) {
            throw GameLaunchException(R.string.error_empty_or_corrupt_game)
        }
    }

    private fun sha256(value: String): String = sha256(value.byteInputStream())

    private fun sha256(input: InputStream): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(COPY_BUFFER_SIZE)
        while (true) {
            ensureNotInterrupted()
            val read = input.read(buffer)
            if (read < 0) break
            digest.update(buffer, 0, read)
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun copyInterruptibly(source: InputStream, destination: OutputStream) {
        val buffer = ByteArray(COPY_BUFFER_SIZE)
        while (true) {
            ensureNotInterrupted()
            val read = source.read(buffer)
            if (read < 0) return
            destination.write(buffer, 0, read)
        }
    }

    private fun ensureNotInterrupted() {
        if (Thread.currentThread().isInterrupted) {
            throw CancellationException("Game launch cancelled")
        }
    }

    private data class SourceMetadata(val size: Long, val lastModified: Long)

    private class GameLaunchException(val messageResource: Int) : Exception()

    private const val LOVE_MIME_TYPE = "application/x-love-game"
    private const val COPY_BUFFER_SIZE = 1024 * 1024
    private const val EXECUTABLE_SCAN_BUFFER_SIZE = 64 * 1024
    private const val MAX_WRAPPER_ENTRIES = 50_000
    private const val MAX_EXECUTABLE_PREFIX_BYTES = 256L * 1024 * 1024
    private const val MAX_ADDITIONAL_STAGED_VARIANTS = 1
    private val ZIP_LOCAL_HEADER = byteArrayOf(0x50, 0x4B, 0x03, 0x04)
    private val KRISTAL_REQUIRE = Regex("(?m)^\\s*Kristal\\s*=\\s*require\\s*\\([\"']src\\.kristal[\"']\\)")
}
