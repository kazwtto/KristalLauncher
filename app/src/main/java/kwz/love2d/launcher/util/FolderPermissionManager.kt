package kwz.love2d.launcher.util

import android.content.Context
import android.content.Intent
import android.net.Uri

object FolderPermissionManager {

    private const val PREFS_NAME = "launcher_prefs"
    private const val KEY_FOLDER_URI = "selected_folder_uri"
    private const val READ_PERMISSION = Intent.FLAG_GRANT_READ_URI_PERMISSION

    fun getSavedFolderUri(context: Context): Uri? {
        val value = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_FOLDER_URI, null)
            ?: return null
        return runCatching { Uri.parse(value) }.getOrNull()
    }

    @Throws(SecurityException::class)
    fun replaceFolder(context: Context, uri: Uri) {
        val previous = getSavedFolderUri(context)
        context.contentResolver.takePersistableUriPermission(uri, READ_PERMISSION)
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_FOLDER_URI, uri.toString())
            .apply()
        if (previous != null && previous != uri) {
            release(context, previous)
        }
    }

    fun clearFolder(context: Context) {
        getSavedFolderUri(context)?.let { release(context, it) }
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_FOLDER_URI)
            .apply()
    }

    private fun release(context: Context, uri: Uri) {
        runCatching {
            context.contentResolver.releasePersistableUriPermission(uri, READ_PERMISSION)
        }
    }
}
