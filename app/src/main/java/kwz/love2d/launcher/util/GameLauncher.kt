package kwz.love2d.launcher.util

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.view.LayoutInflater
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.documentfile.provider.DocumentFile
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.model.PatchApplicationResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withContext
import java.io.File
import java.io.ByteArrayInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.io.SequenceInputStream
import java.security.MessageDigest
import java.util.Locale
import java.util.zip.ZipFile
import java.util.zip.ZipInputStream

object GameLauncher {

    private val launchMutex = Mutex()

    fun launchGame(activity: AppCompatActivity, game: LoveGame) {
        if (!launchMutex.tryLock()) {
            Toast.makeText(activity, R.string.game_launch_in_progress, Toast.LENGTH_SHORT).show()
            return
        }

        val dialogView = LayoutInflater.from(activity).inflate(R.layout.dialog_loading, null)
        val loadingMessage = dialogView.findViewById<TextView>(R.id.tvLoadingMessage)
        val dialog = MaterialAlertDialogBuilder(activity)
            .setView(dialogView)
            .setCancelable(false)
            .create()
        dialog.show()

        activity.lifecycleScope.launch {
            try {
                loadingMessage.text = activity.getString(R.string.preparing_game, game.title)

                val stagedFile = withContext(Dispatchers.IO) {
                    prepareStagedGame(activity.applicationContext, game)
                }
                if (!activity.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) return@launch

                configureLoveRuntime(stagedFile)
                val stagedUri = Uri.fromFile(stagedFile)
                val intent = Intent(Intent.ACTION_VIEW, stagedUri).apply {
                    setClassName(activity.packageName, "org.love2d.android.GameActivity")
                    setDataAndType(stagedUri, LOVE_MIME_TYPE)
                    putExtra("name", stagedFile.absolutePath)
                    putExtra("gamePath", stagedFile.absolutePath)
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
                runCatching { if (dialog.isShowing) dialog.dismiss() }
                launchMutex.unlock()
            }
        }
    }

    private fun prepareStagedGame(context: Context, game: LoveGame): File {
        val resolvedUri = resolveReadableUri(context, game)
            ?: throw GameLaunchException(R.string.error_game_file_unavailable)
        val metadata = queryMetadata(context, resolvedUri)
        val patchState = PatchManager.getPatchStateFingerprint(context, game.stableId)
        val appUpdateTime = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
        val effectiveSize = metadata.size.takeIf { it >= 0L } ?: game.sizeBytes
        val effectiveLastModified = metadata.lastModified.takeIf { it > 0L } ?: game.lastModified
        val sourceFingerprint = sha256(
            "${resolvedUri}|$effectiveSize|$effectiveLastModified|${game.archiveEntryPath.orEmpty()}"
        )
        val cacheKey = sha256("$sourceFingerprint|$patchState|$appUpdateTime")
        val stagedDirectory = File(context.filesDir, "staged").apply { mkdirs() }
        val stagedFile = File(stagedDirectory, "game_$cacheKey.love")

        val reusable = stagedFile.isFile && stagedFile.length() > 0L && runCatching {
            validateLovePackage(stagedFile)
        }.isSuccess
        if (!reusable) {
            stagedFile.delete()
            val temporaryFile = File(stagedDirectory, "${stagedFile.name}.copying")
            temporaryFile.delete()
            try {
                copyGamePayload(context, resolvedUri, game, temporaryFile)
                validateLovePackage(temporaryFile)
                when (val result = PatchManager.applyPatchesToStagedGame(context, temporaryFile, game.stableId)) {
                    is PatchApplicationResult.Success -> Unit
                    is PatchApplicationResult.Failure -> throw IllegalArgumentException(result.reason, result.cause)
                }
                validateLovePackage(temporaryFile)
                check(temporaryFile.renameTo(stagedFile)) { "Could not publish the staged game" }
            } finally {
                temporaryFile.delete()
            }
        }

        stagedDirectory.listFiles().orEmpty()
            .filter { it.isFile && it.extension.equals("love", true) && it != stagedFile }
            .sortedByDescending(File::lastModified)
            .drop(1)
            .forEach(File::delete)
        return stagedFile
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
                destination.fd.sync()
            }
        }
        if (outputFile.length() == 0L) throw GameLaunchException(R.string.error_empty_or_corrupt_game)
    }

    private fun copyNestedPackage(
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
        val targetPath = normalizeArchivePath(entryPath)
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
                if (!PatchManifestParser.isSafeArchivePath(rawPath)) {
                    throw GameLaunchException(R.string.error_empty_or_corrupt_game)
                }
                if (!entry.isDirectory && normalizeArchivePath(rawPath) == targetPath) {
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

    private fun configureLoveRuntime(stagedFile: File) {
        try {
            val gameActivityClass = Class.forName("org.love2d.android.GameActivity")
            val gamePathField = gameActivityClass.getDeclaredField("gamePath")
            gamePathField.isAccessible = true
            gamePathField.set(null, stagedFile.absolutePath)
        } catch (_: ReflectiveOperationException) {
            throw GameLaunchException(R.string.error_game_runtime_unavailable)
        }
    }

    private fun normalizeArchivePath(path: String): String {
        return path.replace('\\', '/').trimStart('/').lowercase(Locale.ROOT)
    }

    private fun sha256(value: String): String {
        return MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }

    private data class SourceMetadata(val size: Long, val lastModified: Long)

    private class GameLaunchException(val messageResource: Int) : Exception()

    private const val LOVE_MIME_TYPE = "application/x-love-game"
    private const val COPY_BUFFER_SIZE = 1024 * 1024
    private const val EXECUTABLE_SCAN_BUFFER_SIZE = 64 * 1024
    private const val MAX_WRAPPER_ENTRIES = 10_000
    private const val MAX_EXECUTABLE_PREFIX_BYTES = 256L * 1024 * 1024
    private val ZIP_LOCAL_HEADER = byteArrayOf(0x50, 0x4B, 0x03, 0x04)
}
