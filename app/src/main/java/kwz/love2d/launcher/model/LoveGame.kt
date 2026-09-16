package kwz.love2d.launcher.model

import android.graphics.Bitmap
import android.net.Uri

data class LoveGame(
    val title: String,
    val fileName: String,
    val uri: Uri,
    val archiveEntryPath: String? = null,
    val icon: Bitmap? = null,
    val previewBackgrounds: List<Bitmap> = emptyList(),
    val sizeBytes: Long = 0,
    val lastModified: Long = 0,
    val subtitle: String? = null,
    val description: String? = null,
    val version: String? = null,
    val engineVer: String? = null,
    val author: String? = null,
    val projectId: String? = null,
    val chapter: String? = null,
    val startMap: String? = null,
    val party: List<String> = emptyList(),
    val packageType: GamePackageType = GamePackageType.EXECUTABLE,
    val modArchiveRoot: String? = null,
    /** Archive path containing only this game's/mod's content, never the Kristal engine root. */
    val translationRoot: String? = null
) {
    val stableId: String
        get() = archiveEntryPath
            ?.let { "${uri}#archive-entry=${Uri.encode(it)}" }
            ?: uri.toString()

    val displayFileName: String
        get() = archiveEntryPath?.substringAfterLast('/') ?: fileName

    val hasIcon: Boolean
        get() = icon != null

    val hasPreviewBackground: Boolean
        get() = previewBackgrounds.isNotEmpty()

    val isKristalMod: Boolean
        get() = packageType == GamePackageType.KRISTAL_MOD
}

enum class GamePackageType {
    EXECUTABLE,
    KRISTAL_MOD
}
