package kwz.love2d.launcher.util

import android.content.Context
import kwz.love2d.launcher.BuildConfig
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL

data class AppUpdateInfo(
    val version: String,
    val title: String,
    val releaseNotes: String,
    val releaseUrl: String,
    val downloadUrl: String
)

sealed class UpdateCheckResult {
    data class Available(val update: AppUpdateInfo) : UpdateCheckResult()
    data object UpToDate : UpdateCheckResult()
    data class Failure(val reason: String) : UpdateCheckResult()
}

object UpdateChecker {

    private const val PREFS_NAME = "launcher_prefs"
    private const val PREF_AUTOMATIC_UPDATES = "automatic_update_checks"
    private const val PREF_LAST_CHECK = "last_update_check"
    private const val PREF_LAST_NOTIFIED_VERSION = "last_notified_update_version"
    private const val AUTOMATIC_INTERVAL_MS = 24L * 60 * 60 * 1000
    private const val MAX_RESPONSE_BYTES = 1024 * 1024

    fun isAutomaticCheckEnabled(context: Context): Boolean {
        return preferences(context).getBoolean(PREF_AUTOMATIC_UPDATES, true)
    }

    fun setAutomaticCheckEnabled(context: Context, enabled: Boolean) {
        preferences(context).edit().putBoolean(PREF_AUTOMATIC_UPDATES, enabled).apply()
    }

    fun getLastCheckTime(context: Context): Long {
        return preferences(context).getLong(PREF_LAST_CHECK, 0L)
    }

    fun shouldRunAutomaticCheck(context: Context): Boolean {
        if (!isAutomaticCheckEnabled(context)) return false
        val elapsed = System.currentTimeMillis() - getLastCheckTime(context)
        return elapsed >= AUTOMATIC_INTERVAL_MS
    }

    fun shouldNotify(context: Context, version: String): Boolean {
        return preferences(context).getString(PREF_LAST_NOTIFIED_VERSION, null) != version
    }

    fun markNotified(context: Context, version: String) {
        preferences(context).edit().putString(PREF_LAST_NOTIFIED_VERSION, version).apply()
    }

    fun check(context: Context): UpdateCheckResult {
        val result = try {
            val release = fetchLatestRelease()
            if (release != null && VersionUtils.isNewer(release.version, BuildConfig.VERSION_NAME)) {
                UpdateCheckResult.Available(release)
            } else {
                UpdateCheckResult.UpToDate
            }
        } catch (error: Exception) {
            UpdateCheckResult.Failure(error.message ?: "Update check failed")
        }
        preferences(context).edit().putLong(PREF_LAST_CHECK, System.currentTimeMillis()).apply()
        return result
    }

    private fun fetchLatestRelease(): AppUpdateInfo? {
        val connection = URL("${BuildConfig.GITHUB_API_URL}/releases/latest").openConnection() as HttpURLConnection
        connection.connectTimeout = 12_000
        connection.readTimeout = 20_000
        connection.instanceFollowRedirects = true
        connection.setRequestProperty("Accept", "application/vnd.github+json")
        connection.setRequestProperty("X-GitHub-Api-Version", "2022-11-28")
        connection.setRequestProperty("User-Agent", "KristalLauncher/${BuildConfig.VERSION_NAME}")

        return try {
            val responseCode = connection.responseCode
            require(connection.url.protocol.equals("https", ignoreCase = true)) {
                "GitHub redirected the update request to an insecure URL"
            }
            if (responseCode == 404) return null
            require(responseCode in 200..299) {
                "GitHub returned HTTP $responseCode"
            }
            val json = JSONObject(readLimitedResponse(connection))
            val tagName = json.optString("tag_name", "").trim()
            require(tagName.isNotBlank()) { "The latest release does not have a version tag" }
            val releaseUrl = json.optString("html_url", BuildConfig.GITHUB_REPOSITORY_URL)
            val apkAssets = mutableListOf<Pair<String, String>>()
            val assets = json.optJSONArray("assets")
            if (assets != null) {
                for (index in 0 until assets.length()) {
                    val asset = assets.getJSONObject(index)
                    val name = asset.optString("name", "")
                    val url = asset.optString("browser_download_url", "")
                    if (name.endsWith(".apk", ignoreCase = true) && url.startsWith("https://")) {
                        apkAssets += name to url
                    }
                }
            }
            val apkUrl = apkAssets.firstOrNull {
                it.first.contains("KristalLauncher", ignoreCase = true) &&
                    it.first.contains("-release", ignoreCase = true)
            }?.second ?: apkAssets.firstOrNull {
                !it.first.contains("debug", ignoreCase = true)
            }?.second
            val safeReleaseUrl = releaseUrl.takeIf { it.startsWith("https://") }
                ?: BuildConfig.GITHUB_REPOSITORY_URL
            AppUpdateInfo(
                version = tagName.removePrefix("v").removePrefix("V"),
                title = json.optString("name", tagName).ifBlank { tagName },
                releaseNotes = json.optString("body", "").take(8_000),
                releaseUrl = safeReleaseUrl,
                downloadUrl = apkUrl ?: safeReleaseUrl
            )
        } finally {
            connection.disconnect()
        }
    }

    private fun readLimitedResponse(connection: HttpURLConnection): String {
        connection.inputStream.buffered().use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(16 * 1024)
            var total = 0
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
                require(total <= MAX_RESPONSE_BYTES) { "GitHub response is too large" }
                output.write(buffer, 0, read)
            }
            return output.toString(Charsets.UTF_8.name())
        }
    }

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
