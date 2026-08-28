package kwz.love2d.launcher.model

import android.graphics.Bitmap
import android.net.Uri

data class LoveGame(
    val title: String,
    val fileName: String,
    val uri: Uri,
    val archiveEntryPath: String? = null,
    val icon: Bitmap? = null,
    val sizeBytes: Long = 0,
    val lastModified: Long = 0,
    val subtitle: String? = null,
    val version: String? = null,
    val engineVer: String? = null,
    val author: String? = null
) {
    val stableId: String
        get() = archiveEntryPath
            ?.let { "${uri}#archive-entry=${Uri.encode(it)}" }
            ?: uri.toString()

    val displayFileName: String
        get() = archiveEntryPath?.substringAfterLast('/') ?: fileName

    val hasIcon: Boolean
        get() = icon != null
}
