package kwz.love2d.launcher.util

import android.content.Context
import android.util.AtomicFile
import kwz.love2d.launcher.BuildConfig
import kwz.love2d.launcher.model.CatalogPatch
import kwz.love2d.launcher.model.LocalizedText
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

sealed class PatchCatalogResult {
    data class Success(
        val patches: List<CatalogPatch>,
        val fromCache: Boolean
    ) : PatchCatalogResult()

    data class Failure(val reason: String) : PatchCatalogResult()
}

object PatchCatalogService {

    private const val MAX_CATALOG_BYTES = 1024 * 1024
    private const val MAX_CATALOG_PATCHES = 200
    private const val CACHE_FILE_NAME = "patch_catalog.json"
    private const val MAX_CACHE_AGE_MS = 7L * 24 * 60 * 60 * 1000
    private val checksumPattern = Regex("^[a-fA-F0-9]{64}$")

    fun fetch(context: Context): PatchCatalogResult {
        return try {
            val catalogJson = downloadCatalog()
            val parsed = parseCatalog(catalogJson)
            writeCacheAtomically(cacheFile(context), catalogJson)
            PatchCatalogResult.Success(parsed, fromCache = false)
        } catch (networkError: Exception) {
            val cached = cacheFile(context)
            val cacheAge = System.currentTimeMillis() - cached.lastModified()
            if (cached.isFile && cacheAge in 0..MAX_CACHE_AGE_MS) {
                runCatching { parseCatalog(cached.readText(Charsets.UTF_8)) }
                    .fold(
                        onSuccess = { PatchCatalogResult.Success(it, fromCache = true) },
                        onFailure = {
                            PatchCatalogResult.Failure(networkError.message ?: "Patch catalog is unavailable")
                        }
                    )
            } else {
                PatchCatalogResult.Failure(networkError.message ?: "Patch catalog is unavailable")
            }
        }
    }

    private fun downloadCatalog(): String {
        val connection = URL(BuildConfig.PATCH_CATALOG_URL).openConnection() as HttpURLConnection
        connection.connectTimeout = 12_000
        connection.readTimeout = 20_000
        connection.instanceFollowRedirects = true
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("User-Agent", "KristalLauncher/${BuildConfig.VERSION_NAME}")
        return try {
            val responseCode = connection.responseCode
            require(responseCode in 200..299) { "Catalog request failed with HTTP $responseCode" }
            require(connection.url.protocol.equals("https", ignoreCase = true)) {
                "Catalog redirect left HTTPS"
            }
            connection.inputStream.buffered().use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(16 * 1024)
                var total = 0
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    total += read
                    require(total <= MAX_CATALOG_BYTES) { "Patch catalog is too large" }
                    output.write(buffer, 0, read)
                }
                output.toString(Charsets.UTF_8.name())
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun parseCatalog(json: String): List<CatalogPatch> {
        val root = JSONObject(json)
        require(root.optInt("schemaVersion", -1) == 1) { "Unsupported patch catalog version" }
        val array = root.optJSONArray("patches") ?: throw IllegalArgumentException("Catalog is missing patches")
        require(array.length() <= MAX_CATALOG_PATCHES) { "Patch catalog contains too many entries" }

        return buildList {
            val ids = mutableSetOf<String>()
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                val manifest = PatchManifestParser.parse(item, requireOperations = false)
                require(ids.add(manifest.id)) { "Duplicate patch in catalog: ${manifest.id}" }

                val packagePath = item.optString("package", "").trim()
                require(PatchManifestParser.isSafeArchivePath(packagePath)) {
                    "Invalid package path for ${manifest.id}"
                }
                val checksum = item.optString("sha256", "").trim()
                require(checksumPattern.matches(checksum)) { "Invalid checksum for ${manifest.id}" }

                add(
                    CatalogPatch(
                        manifest = manifest,
                        packageUrl = URL(URL(BuildConfig.PATCH_CATALOG_URL), packagePath).toString(),
                        sha256 = checksum.lowercase(),
                        releaseNotes = parseOptionalLocalizedText(item.opt("releaseNotes"))
                    )
                )
            }
        }.sortedBy { it.manifest.name.values["en"] ?: it.manifest.id }
    }

    private fun parseOptionalLocalizedText(value: Any?): LocalizedText? {
        if (value == null) return null
        val values = linkedMapOf<String, String>()
        when (value) {
            is String -> if (value.isNotBlank()) values["en"] = value.trim()
            is JSONObject -> value.keys().forEach { locale ->
                val text = value.optString(locale, "").trim()
                if (text.isNotBlank()) values[locale] = text
            }
        }
        return values.takeIf { it.isNotEmpty() }?.let(::LocalizedText)
    }

    private fun cacheFile(context: Context): File = File(context.cacheDir, CACHE_FILE_NAME)

    private fun writeCacheAtomically(file: File, value: String) {
        val atomicFile = AtomicFile(file)
        val output = atomicFile.startWrite()
        try {
            output.write(value.toByteArray(Charsets.UTF_8))
            output.fd.sync()
            atomicFile.finishWrite(output)
        } catch (error: Throwable) {
            atomicFile.failWrite(output)
            throw error
        }
    }
}
