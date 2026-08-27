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
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.security.MessageDigest
import java.util.zip.ZipFile

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
                val patchesEnabled = withContext(Dispatchers.IO) {
                    PatchManager.hasAnyPatchEnabled(activity.applicationContext, game.stableId)
                }
                loadingMessage.text = activity.getString(
                    if (patchesEnabled) R.string.preparing_game_with_patches else R.string.preparing_game,
                    game.fileName
                )

                val stagedFile = withContext(Dispatchers.IO) {
                    prepareStagedGame(activity.applicationContext, game)
                }
                if (!activity.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) return@launch

                val contentUri = FileProvider.getUriForFile(
                    activity,
                    "${activity.packageName}.fileprovider",
                    stagedFile
                )
                val intent = Intent(Intent.ACTION_VIEW, contentUri).apply {
                    setClassName(activity.packageName, "org.love2d.android.GameActivity")
                    setDataAndType(contentUri, LOVE_MIME_TYPE)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
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
        val sourceFingerprint = if (metadata.lastModified > 0L && metadata.size >= 0L) {
            sha256("${resolvedUri}|${metadata.size}|${metadata.lastModified}")
        } else {
            context.contentResolver.openInputStream(resolvedUri)?.use(::sha256)
                ?: throw GameLaunchException(R.string.error_game_file_unavailable)
        }
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
                copyGamePayload(context, resolvedUri, game.fileName, temporaryFile)
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

    private fun copyGamePayload(context: Context, uri: Uri, fileName: String, outputFile: File) {
        val zipOffset = if (fileName.endsWith(".exe", ignoreCase = true)) {
            context.contentResolver.openInputStream(uri)?.buffered()?.use(LoveMetadataParser::findZipOffset)
                ?: -1L
        } else {
            0L
        }
        if (zipOffset < 0L) throw GameLaunchException(R.string.error_invalid_love_executable)

        val input = context.contentResolver.openInputStream(uri)?.buffered()
            ?: throw GameLaunchException(R.string.error_game_file_unavailable)
        input.use { source ->
            skipFully(source, zipOffset)
            FileOutputStream(outputFile).use { destination ->
                source.copyTo(destination, COPY_BUFFER_SIZE)
                destination.fd.sync()
            }
        }
        if (outputFile.length() == 0L) throw GameLaunchException(R.string.error_empty_or_corrupt_game)
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

    private fun skipFully(input: InputStream, byteCount: Long) {
        var remaining = byteCount
        while (remaining > 0L) {
            val skipped = input.skip(remaining)
            if (skipped > 0L) {
                remaining -= skipped
            } else if (input.read() >= 0) {
                remaining--
            } else {
                throw GameLaunchException(R.string.error_executable_stream)
            }
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
}
