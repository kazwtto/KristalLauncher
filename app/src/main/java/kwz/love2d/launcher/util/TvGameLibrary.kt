package kwz.love2d.launcher.util

import android.content.Context
import android.content.res.Configuration
import android.net.Uri
import java.io.File

/** App-owned game directory for TV systems without a usable document picker. */
object TvGameLibrary {
    fun isTelevision(context: Context): Boolean =
        context.resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK ==
            Configuration.UI_MODE_TYPE_TELEVISION

    fun directory(context: Context): File? =
        context.getExternalFilesDir("games")?.takeIf { it.isDirectory || it.mkdirs() }

    fun defaultFolderUri(context: Context): Uri? =
        if (isTelevision(context)) directory(context)?.let(Uri::fromFile) else null

    fun isLibraryUri(context: Context, uri: Uri): Boolean {
        if (uri.scheme != "file") return false
        val library = directory(context) ?: return false
        val path = uri.path ?: return false
        return runCatching { File(path).canonicalFile == library.canonicalFile }
            .getOrDefault(false)
    }
}
