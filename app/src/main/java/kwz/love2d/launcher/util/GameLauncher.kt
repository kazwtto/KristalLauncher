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
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.model.PatchApplicationResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withContext
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.io.SequenceInputStream
import java.security.MessageDigest
import java.util.zip.ZipFile
import java.util.zip.ZipInputStream

object GameLauncher {

    private val launchMutex = Mutex()

    fun launchGame(activity: AppCompatActivity, game: LoveGame) {
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

                val stagedFile = withContext(Dispatchers.IO) {
                    prepareStagedGame(activity.applicationContext, game)
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

    private fun prepareStagedGame(context: Context, game: LoveGame): File {
        val resolvedUri = resolveReadableUri(context, game)
            ?: throw GameLaunchException(R.string.error_game_file_unavailable)
        val metadata = queryMetadata(context, resolvedUri)
        val patchState = PatchManager.getPatchStateFingerprint(context, game.stableId)
        val patchesEnabled = PatchManager.hasAnyPatchEnabled(context, game.stableId)
        val appUpdateTime = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
        val sourceFingerprint = if (metadata.lastModified > 0L && metadata.size >= 0L) {
            sha256("${resolvedUri}|${metadata.size}|${metadata.lastModified}|${game.archiveEntryPath.orEmpty()}")
        } else {
            val contentHash = context.contentResolver.openInputStream(resolvedUri)?.use(::sha256)
                ?: throw GameLaunchException(R.string.error_game_file_unavailable)
            sha256("$contentHash|${game.archiveEntryPath.orEmpty()}")
        }
        val baseKey = sha256("$sourceFingerprint|$appUpdateTime")
        val cacheKey = sha256("$baseKey|$patchState")
        val stagedDirectory = File(context.filesDir, "staged").apply { mkdirs() }
        val baseFile = File(stagedDirectory, "base_$baseKey.love")
        val stagedFile = File(stagedDirectory, "game_$cacheKey.love")

        val activeFile = if (patchesEnabled) stagedFile else baseFile
        if (isReusableStagedPackage(activeFile)) {
            trimStagedCopies(stagedDirectory, activeFile, baseFile)
            return activeFile
        }

        ensureBaseGame(context, resolvedUri, game, baseFile)
        if (!patchesEnabled) {
            trimStagedCopies(stagedDirectory, baseFile, baseFile)
            return baseFile
        }

        stagedFile.delete()
        val temporaryFile = File(stagedDirectory, "${stagedFile.name}.building")
        temporaryFile.delete()
        try {
            when (val result = PatchManager.writePatchedGame(context, baseFile, temporaryFile, game.stableId)) {
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
        baseFile: File
    ) {
        if (isReusableStagedPackage(baseFile)) return

        baseFile.delete()
        val temporaryFile = File(baseFile.parentFile, "${baseFile.name}.building")
        temporaryFile.delete()
        try {
            copyGamePayload(context, sourceUri, game, temporaryFile)
            try {
                LoveArchiveNormalizer.normalizeRootInPlace(temporaryFile)
            } catch (_: Exception) {
                throw GameLaunchException(R.string.error_empty_or_corrupt_game)
            }
            validateLovePackage(temporaryFile)
            check(temporaryFile.renameTo(baseFile)) { "Could not publish the staged game" }
        } finally {
            temporaryFile.delete()
        }
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
                    else -> source.copyTo(destination, COPY_BUFFER_SIZE)
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
                        archive.copyTo(destination, COPY_BUFFER_SIZE)
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
        payload.copyTo(destination, COPY_BUFFER_SIZE)
    }

    internal fun findExecutablePayload(source: InputStream): InputStream? {
        var matched = 0
        var scanned = 0L
        while (scanned < MAX_EXECUTABLE_PREFIX_BYTES) {
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
            val read = input.read(buffer)
            if (read < 0) break
            digest.update(buffer, 0, read)
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
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
}
