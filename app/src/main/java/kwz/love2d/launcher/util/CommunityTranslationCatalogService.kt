package kwz.love2d.launcher.util

import android.content.Context
import android.util.AtomicFile
import kwz.love2d.launcher.BuildConfig
import kwz.love2d.launcher.model.CatalogTranslation
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

sealed class CommunityTranslationCatalogResult {
    data class Success(
        val translations: List<CatalogTranslation>,
        val fromCache: Boolean
    ) : CommunityTranslationCatalogResult()

    data class Failure(val reason: String) : CommunityTranslationCatalogResult()
}

object CommunityTranslationCatalogService {
    private const val MAX_CATALOG_BYTES = 512 * 1024
    private const val MAX_CATALOG_ENTRIES = 500
    private const val CACHE_FILE = "community_translation_catalog.json"
    private const val MAX_CACHE_AGE_MS = 7L * 24 * 60 * 60 * 1000
    private val checksum = Regex("^[a-fA-F0-9]{64}$")

    fun fetch(context: Context): CommunityTranslationCatalogResult = try {
        val json = downloadCatalog()
        val parsed = parseCatalog(json)
        writeCache(File(context.cacheDir, CACHE_FILE), json)
        CommunityTranslationCatalogResult.Success(parsed, fromCache = false)
    } catch (networkError: Exception) {
        val cache = File(context.cacheDir, CACHE_FILE)
        val age = System.currentTimeMillis() - cache.lastModified()
        if (cache.isFile && age in 0..MAX_CACHE_AGE_MS) {
            runCatching { parseCatalog(cache.readText(Charsets.UTF_8)) }.fold(
                onSuccess = { CommunityTranslationCatalogResult.Success(it, fromCache = true) },
                onFailure = {
                    CommunityTranslationCatalogResult.Failure(networkError.message ?: "Translation catalog unavailable")
                }
            )
        } else {
            CommunityTranslationCatalogResult.Failure(networkError.message ?: "Translation catalog unavailable")
        }
    }

    internal fun parseCatalog(json: String): List<CatalogTranslation> {
        val root = JSONObject(json)
        require(root.optInt("schemaVersion", -1) == 1) { "Unsupported translation catalog version" }
        val entries = root.optJSONArray("translations") ?: error("Translation catalog is missing entries")
        require(entries.length() <= MAX_CATALOG_ENTRIES) { "Translation catalog has too many entries" }
        val ids = mutableSetOf<String>()
        return buildList {
            for (index in 0 until entries.length()) {
                val item = entries.getJSONObject(index)
                val manifest = CommunityTranslationManifestParser.parse(item, requireFiles = false)
                require(ids.add(manifest.id)) { "Duplicate translation in catalog: ${manifest.id}" }
                val packagePath = item.optString("package", "").trim()
                require(PatchManifestParser.isSafeArchivePath(packagePath)) { "Invalid translation package path" }
                val packageChecksum = item.optString("sha256", "").trim()
                require(checksum.matches(packageChecksum)) { "Invalid translation package checksum" }
                add(
                    CatalogTranslation(
                        manifest = manifest,
                        packageUrl = URL(URL(BuildConfig.TRANSLATION_CATALOG_URL), packagePath).toString(),
                        sha256 = packageChecksum.lowercase()
                    )
                )
            }
        }
    }

    private fun downloadCatalog(): String {
        val connection = URL(BuildConfig.TRANSLATION_CATALOG_URL).openConnection() as HttpURLConnection
        connection.connectTimeout = 12_000
        connection.readTimeout = 20_000
        connection.instanceFollowRedirects = true
        connection.useCaches = false
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("Cache-Control", "no-cache, no-store")
        connection.setRequestProperty("User-Agent", "KristalLauncher/${BuildConfig.VERSION_NAME}")
        return try {
            require(connection.responseCode in 200..299) {
                "Translation catalog request failed with HTTP ${connection.responseCode}"
            }
            require(connection.url.protocol.equals("https", ignoreCase = true)) {
                "Translation catalog redirect left HTTPS"
            }
            connection.inputStream.buffered().use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(16 * 1024)
                var total = 0
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    total += read
                    require(total <= MAX_CATALOG_BYTES) { "Translation catalog is too large" }
                    output.write(buffer, 0, read)
                }
                output.toString(Charsets.UTF_8.name())
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun writeCache(file: File, value: String) {
        val atomic = AtomicFile(file)
        val output = atomic.startWrite()
        try {
            output.write(value.toByteArray(Charsets.UTF_8))
            output.fd.sync()
            atomic.finishWrite(output)
        } catch (error: Throwable) {
            atomic.failWrite(output)
            throw error
        }
    }
}
