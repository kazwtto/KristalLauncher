package kwz.love2d.launcher.util

import android.content.Context
import android.util.AtomicFile
import kwz.love2d.launcher.BuildConfig
import kwz.love2d.launcher.model.KristalRuntimeCatalogResult
import kwz.love2d.launcher.model.KristalRuntimeRelease
import org.json.JSONArray
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

object KristalRuntimeCatalogService {

    private const val CACHE_FILE_NAME = "kristal_runtime_releases.json"
    private const val MAX_RESPONSE_BYTES = 4 * 1024 * 1024
    private const val MAX_CACHE_AGE_MS = 7L * 24 * 60 * 60 * 1000
    private const val MAX_RELEASES = 100

    fun fetch(context: Context): KristalRuntimeCatalogResult {
        return try {
            val json = downloadCatalog()
            val releases = parseCatalog(json)
            writeCacheAtomically(cacheFile(context), json)
            KristalRuntimeCatalogResult.Success(releases, fromCache = false)
        } catch (networkError: Exception) {
            val cached = cacheFile(context)
            val age = System.currentTimeMillis() - cached.lastModified()
            if (cached.isFile && age in 0..MAX_CACHE_AGE_MS) {
                runCatching { parseCatalog(cached.readText(Charsets.UTF_8)) }
                    .fold(
                        onSuccess = { KristalRuntimeCatalogResult.Success(it, fromCache = true) },
                        onFailure = {
                            KristalRuntimeCatalogResult.Failure(
                                networkError.message ?: "Kristal release catalog is unavailable"
                            )
                        }
                    )
            } else {
                KristalRuntimeCatalogResult.Failure(
                    networkError.message ?: "Kristal release catalog is unavailable"
                )
            }
        }
    }

    private fun downloadCatalog(): String {
        val connection = URL(BuildConfig.KRISTAL_RELEASES_API_URL).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 30_000
        connection.instanceFollowRedirects = true
        connection.useCaches = false
        connection.setRequestProperty("Accept", "application/vnd.github+json")
        connection.setRequestProperty("X-GitHub-Api-Version", "2022-11-28")
        connection.setRequestProperty("User-Agent", "KristalLauncher/${BuildConfig.VERSION_NAME}")
        return try {
            require(connection.responseCode in 200..299) {
                "Release request failed with HTTP ${connection.responseCode}"
            }
            require(connection.url.protocol.equals("https", ignoreCase = true)) {
                "Release catalog redirect left HTTPS"
            }
            connection.inputStream.buffered().use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(16 * 1024)
                var total = 0
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    total += read
                    require(total <= MAX_RESPONSE_BYTES) { "Release catalog is too large" }
                    output.write(buffer, 0, read)
                }
                output.toString(Charsets.UTF_8.name())
            }
        } finally {
            connection.disconnect()
        }
    }

    internal fun parseCatalog(json: String): List<KristalRuntimeRelease> {
        val array = JSONArray(json)
        require(array.length() <= MAX_RELEASES) { "Release catalog contains too many entries" }
        return buildList {
            val tags = mutableSetOf<String>()
            for (index in 0 until array.length()) {
                val release = array.getJSONObject(index)
                if (release.optBoolean("draft", false)) continue
                val tag = release.optString("tag_name", "").trim()
                if (!SAFE_TAG.matches(tag) || !tags.add(tag)) continue

                val assets = release.optJSONArray("assets") ?: continue
                val candidates = buildList {
                    for (assetIndex in 0 until assets.length()) {
                        val asset = assets.getJSONObject(assetIndex)
                        val name = asset.optString("name", "").trim()
                        val url = asset.optString("browser_download_url", "").trim()
                        val size = asset.optLong("size", -1L)
                        if (isSupportedRuntimeAsset(name) && isOfficialDownloadUrl(url) && size > 0L) {
                            val digest = asset.optString("digest", "").trim()
                                .removePrefix("sha256:")
                                .takeIf { SHA256.matches(it) }
                            add(RuntimeAsset(name, url, size, digest))
                        }
                    }
                }
                val asset = candidates.minByOrNull { runtimeAssetPriority(it.name) } ?: continue
                add(
                    KristalRuntimeRelease(
                        tag = tag,
                        version = tag.removePrefix("v"),
                        assetName = asset.name,
                        downloadUrl = asset.url,
                        sizeBytes = asset.size,
                        sha256 = asset.sha256,
                        publishedAt = release.optString("published_at", "").takeIf(String::isNotBlank),
                        prerelease = release.optBoolean("prerelease", false)
                    )
                )
            }
        }.sortedWith { left, right -> VersionUtils.compare(right.version, left.version) }
    }

    internal fun isSupportedRuntimeAsset(name: String): Boolean {
        val normalized = name.lowercase()
        return normalized.startsWith("kristal-") &&
            (normalized.endsWith(".love") || normalized.endsWith("-love.zip"))
    }

    private fun runtimeAssetPriority(name: String): Int =
        if (name.lowercase().endsWith("-love.zip")) 0 else 1

    private fun isOfficialDownloadUrl(value: String): Boolean = runCatching {
        val url = URL(value)
        url.protocol.equals("https", ignoreCase = true) &&
            url.host.equals("github.com", ignoreCase = true) &&
            url.path.startsWith("/KristalTeam/Kristal/releases/download/")
    }.getOrDefault(false)

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

    private val SAFE_TAG = Regex("^[A-Za-z0-9._-]{1,80}$")
    private val SHA256 = Regex("^[a-fA-F0-9]{64}$")

    private data class RuntimeAsset(
        val name: String,
        val url: String,
        val size: Long,
        val sha256: String?
    )
}
