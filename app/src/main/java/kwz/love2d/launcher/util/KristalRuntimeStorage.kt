package kwz.love2d.launcher.util

import android.content.Context
import kwz.love2d.launcher.model.InstalledKristalRuntime
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipFile

object KristalRuntimeStorage {

    private const val ROOT_DIRECTORY = "kristal_runtimes"
    private const val PACKAGE_FILE = "kristal.love"
    private const val METADATA_FILE = "runtime.json"
    private const val PREFERENCES = "kristal_runtime_preferences"
    private const val SELECTED_TAG = "selected_tag"
    private const val GAME_SELECTED_TAG_PREFIX = "game_selected_tag_"

    fun installedRuntimes(context: Context): List<InstalledKristalRuntime> =
        rootDirectory(context).listFiles().orEmpty()
            .asSequence()
            .filter(File::isDirectory)
            .mapNotNull(::readRuntime)
            .sortedWith { left, right -> VersionUtils.compare(right.version, left.version) }
            .toList()

    fun selectedRuntime(context: Context): InstalledKristalRuntime? {
        val installed = installedRuntimes(context)
        val selectedTag = preferences(context).getString(SELECTED_TAG, null)
        val selected = installed.firstOrNull { it.tag == selectedTag }
        if (selected != null) return selected
        return installed.firstOrNull()?.also { fallback ->
            preferences(context).edit().putString(SELECTED_TAG, fallback.tag).apply()
        }
    }

    fun selectedRuntimeForGame(context: Context, gameId: String): InstalledKristalRuntime? {
        val installed = installedRuntimes(context)
        val selectedTag = preferences(context).getString(gameSelectionKey(gameId), null)
        return installed.firstOrNull { it.tag == selectedTag } ?: selectedRuntime(context)
    }

    fun selectedRuntimeTagForGame(context: Context, gameId: String): String? =
        preferences(context).getString(gameSelectionKey(gameId), null)

    fun selectForGame(context: Context, gameId: String, tag: String?): Boolean {
        if (tag == null) {
            preferences(context).edit().remove(gameSelectionKey(gameId)).apply()
            return true
        }
        val runtime = installedRuntimes(context).firstOrNull { it.tag == tag } ?: return false
        preferences(context).edit().putString(gameSelectionKey(gameId), runtime.tag).apply()
        return true
    }

    fun select(context: Context, tag: String): Boolean {
        val runtime = installedRuntimes(context).firstOrNull { it.tag == tag } ?: return false
        preferences(context).edit().putString(SELECTED_TAG, runtime.tag).apply()
        return true
    }

    fun remove(context: Context, tag: String): Boolean {
        val runtime = installedRuntimes(context).firstOrNull { it.tag == tag } ?: return false
        val removed = runtime.file.parentFile?.deleteRecursively() == true
        if (removed && preferences(context).getString(SELECTED_TAG, null) == tag) {
            val fallback = installedRuntimes(context).firstOrNull()
            preferences(context).edit().apply {
                if (fallback == null) remove(SELECTED_TAG) else putString(SELECTED_TAG, fallback.tag)
            }.apply()
        }
        return removed
    }

    internal fun rootDirectory(context: Context): File =
        File(context.filesDir, ROOT_DIRECTORY).apply { mkdirs() }

    internal fun stagingDirectory(context: Context): File =
        File(context.cacheDir, "kristal_runtime_staging").apply { mkdirs() }

    internal fun destinationDirectory(context: Context, tag: String): File =
        File(rootDirectory(context), sha256(tag))

    internal fun writeMetadata(
        directory: File,
        tag: String,
        version: String,
        assetName: String,
        sourceUrl: String
    ) {
        File(directory, METADATA_FILE).writeText(
            JSONObject()
                .put("schemaVersion", 1)
                .put("tag", tag)
                .put("version", version)
                .put("assetName", assetName)
                .put("sourceUrl", sourceUrl)
                .put("installedAt", System.currentTimeMillis())
                .toString(),
            Charsets.UTF_8
        )
    }

    internal fun packageFile(directory: File): File = File(directory, PACKAGE_FILE)

    internal fun readRuntime(directory: File): InstalledKristalRuntime? = runCatching {
        val packageFile = packageFile(directory)
        val metadataFile = File(directory, METADATA_FILE)
        if (!packageFile.isFile || packageFile.length() <= 0L || !metadataFile.isFile) return null
        if (!hasRootMainLua(packageFile)) return null
        val metadata = JSONObject(metadataFile.readText(Charsets.UTF_8))
        require(metadata.optInt("schemaVersion", -1) == 1)
        InstalledKristalRuntime(
            tag = metadata.getString("tag"),
            version = metadata.getString("version"),
            assetName = metadata.getString("assetName"),
            sourceUrl = metadata.getString("sourceUrl"),
            installedAt = metadata.getLong("installedAt"),
            file = packageFile
        )
    }.getOrNull()

    internal fun hasRootMainLua(file: File): Boolean = runCatching {
        ZipFile(file).use { zip ->
            zip.entries().asSequence().any { entry ->
                !entry.isDirectory && entry.name.replace('\\', '/').trimStart('/') == "main.lua"
            }
        }
    }.getOrDefault(false)

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    private fun gameSelectionKey(gameId: String): String = GAME_SELECTED_TAG_PREFIX + sha256(gameId)
}
