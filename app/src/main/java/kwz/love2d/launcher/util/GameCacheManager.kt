package kwz.love2d.launcher.util

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.AtomicFile
import kwz.love2d.launcher.model.LoveGame
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest

object GameCacheManager {

    private const val CACHE_FILE_NAME = "games_metadata.json"
    private const val ICONS_DIR_NAME = "cached_icons"
    private const val MAX_ICON_DIMENSION = 192
    private const val PREF_NAME = "game_cache_settings"
    private const val KEY_FOLDER_URI = "cached_folder_uri"
    private const val KEY_CACHE_SCHEMA = "cache_schema"
    private const val CACHE_SCHEMA_VERSION = 4

    fun hasCache(context: Context): Boolean {
        val cacheFile = File(context.filesDir, CACHE_FILE_NAME)
        return getCacheSchema(context) == CACHE_SCHEMA_VERSION && cacheFile.isFile && cacheFile.length() > 0
    }

    fun saveGamesCache(context: Context, folderUri: Uri, games: List<LoveGame>) {
        runCatching {
            val jsonArray = JSONArray()
            val iconDir = File(context.filesDir, ICONS_DIR_NAME).apply { mkdirs() }
            val retainedIcons = mutableSetOf<String>()

            for (game in games) {
                val jsonObject = JSONObject()
                    .put("title", game.title)
                    .put("fileName", game.fileName)
                    .put("uri", game.uri.toString())
                    .put("sizeBytes", game.sizeBytes)
                    .put("lastModified", game.lastModified)
                game.archiveEntryPath?.let { jsonObject.put("archiveEntryPath", it) }
                game.subtitle?.let { jsonObject.put("subtitle", it) }
                game.version?.let { jsonObject.put("version", it) }
                game.engineVer?.let { jsonObject.put("engineVer", it) }
                game.author?.let { jsonObject.put("author", it) }

                game.icon?.let { bitmap ->
                    val iconName = "${sha256(game.stableId)}_${game.lastModified}_${game.sizeBytes}.png"
                    val iconFile = File(iconDir, iconName)
                    retainedIcons += iconName
                    writeBitmapAtomically(iconFile, bitmap)
                    jsonObject.put("iconFile", iconName)
                }
                jsonArray.put(jsonObject)
            }

            writeTextAtomically(File(context.filesDir, CACHE_FILE_NAME), jsonArray.toString())
            context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_FOLDER_URI, folderUri.toString())
                .putInt(KEY_CACHE_SCHEMA, CACHE_SCHEMA_VERSION)
                .apply()

            iconDir.listFiles().orEmpty()
                .filter { it.isFile && it.name !in retainedIcons }
                .forEach(File::delete)
        }.onFailure(::reportRecoverableFailure)
    }

    fun getCachedGames(context: Context, folderUri: Uri? = null): List<LoveGame> {
        return runCatching {
            if (getCacheSchema(context) != CACHE_SCHEMA_VERSION) return emptyList()
            val cachedFolderUri = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                .getString(KEY_FOLDER_URI, null)
            if (folderUri != null && cachedFolderUri != folderUri.toString()) return emptyList()

            val cacheFile = File(context.filesDir, CACHE_FILE_NAME)
            if (!cacheFile.isFile || cacheFile.length() == 0L) return emptyList()
            val jsonArray = JSONArray(cacheFile.readText(Charsets.UTF_8))
            val iconDir = File(context.filesDir, ICONS_DIR_NAME)

            buildList {
                for (index in 0 until jsonArray.length()) {
                    val item = jsonArray.optJSONObject(index) ?: continue
                    val uriValue = item.optString("uri")
                    val fileName = item.optString("fileName")
                    if (uriValue.isBlank() || fileName.isBlank()) continue
                    val icon = item.optString("iconFile")
                        .takeIf(String::isNotBlank)
                        ?.let { File(iconDir, it) }
                        ?.takeIf(File::isFile)
                        ?.let(::decodeCachedIcon)
                    add(
                        LoveGame(
                            title = item.optString("title").ifBlank { fileName },
                            fileName = fileName,
                            uri = Uri.parse(uriValue),
                            archiveEntryPath = item.optString("archiveEntryPath")
                                .takeIf(String::isNotBlank),
                            icon = icon,
                            sizeBytes = item.optLong("sizeBytes", 0L),
                            lastModified = item.optLong("lastModified", 0L),
                            subtitle = item.optString("subtitle").takeIf(String::isNotBlank),
                            version = item.optString("version").takeIf(String::isNotBlank),
                            engineVer = item.optString("engineVer").takeIf(String::isNotBlank),
                            author = item.optString("author").takeIf(String::isNotBlank)
                        )
                    )
                }
            }
        }.onFailure(::reportRecoverableFailure).getOrDefault(emptyList())
    }

    fun clearCache(context: Context) {
        runCatching {
            File(context.filesDir, CACHE_FILE_NAME).delete()
            File(context.filesDir, ICONS_DIR_NAME).deleteRecursively()
            context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_FOLDER_URI)
                .remove(KEY_CACHE_SCHEMA)
                .apply()
            clearStagedGameCopies(context)
        }.onFailure(::reportRecoverableFailure)
    }

    fun clearRuntimeGameCopies(context: Context) {
        context.cacheDir.listFiles().orEmpty()
            .filter { it.isFile && it.name.startsWith("game_") && it.extension.equals("love", true) }
            .forEach(File::delete)
    }

    fun clearStagedGameCopies(context: Context) {
        File(context.filesDir, "staged").listFiles().orEmpty()
            .filter { it.isFile }
            .forEach(File::delete)
    }

    private fun decodeCachedIcon(iconFile: File): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(iconFile.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sampleSize = 1
        while (bounds.outWidth / sampleSize > MAX_ICON_DIMENSION * 2 ||
            bounds.outHeight / sampleSize > MAX_ICON_DIMENSION * 2
        ) {
            sampleSize *= 2
        }
        val decoded = BitmapFactory.decodeFile(
            iconFile.absolutePath,
            BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
        ) ?: return null
        val largest = maxOf(decoded.width, decoded.height)
        if (largest <= MAX_ICON_DIMENSION) return decoded
        val scale = MAX_ICON_DIMENSION.toFloat() / largest
        return Bitmap.createScaledBitmap(
            decoded,
            (decoded.width * scale).toInt().coerceAtLeast(1),
            (decoded.height * scale).toInt().coerceAtLeast(1),
            true
        ).also { if (it !== decoded) decoded.recycle() }
    }

    private fun writeBitmapAtomically(destination: File, bitmap: Bitmap) {
        val atomicFile = AtomicFile(destination)
        val output = atomicFile.startWrite()
        try {
            check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
            output.fd.sync()
            atomicFile.finishWrite(output)
        } catch (error: Exception) {
            atomicFile.failWrite(output)
            throw error
        }
    }

    private fun writeTextAtomically(destination: File, value: String) {
        val atomicFile = AtomicFile(destination)
        val output = atomicFile.startWrite()
        try {
            output.write(value.toByteArray(Charsets.UTF_8))
            output.fd.sync()
            atomicFile.finishWrite(output)
        } catch (error: Exception) {
            atomicFile.failWrite(output)
            throw error
        }
    }

    private fun sha256(value: String): String {
        return MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }

    private fun getCacheSchema(context: Context): Int {
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .getInt(KEY_CACHE_SCHEMA, 0)
    }

    private fun reportRecoverableFailure(error: Throwable) {
        if (error is Exception) {
            error.printStackTrace()
        } else {
            throw error
        }
    }
}
