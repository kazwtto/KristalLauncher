package kwz.love2d.launcher.util

import kwz.love2d.launcher.BuildConfig
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class UpdateCheckerTest {
    private fun release(version: String, prerelease: Boolean = false, draft: Boolean = false): JSONObject =
        JSONObject().put("tag_name", "v$version").put("prerelease", prerelease).put("draft", draft)
            .put("html_url", "https://github.com/kazwtto/KristalLauncher/releases/tag/v$version")

    private fun response(vararg releases: JSONObject): String = JSONArray(releases.toList()).toString()

    @Test
    fun stableChannelExcludesPrereleasesAndDrafts() {
        val result = UpdateChecker.parseReleaseResponse(response(
            release("0.20", prerelease = true), release("0.99", draft = true), release("0.19")
        ), includePrereleases = false)
        assertEquals("0.19", result?.version)
    }

    @Test
    fun optInSelectsNewestVersionNotApiArrayOrder() {
        val result = UpdateChecker.parseReleaseResponse(response(
            release("0.18"), release("0.19-rc.2", prerelease = true),
            release("0.19-rc.10", prerelease = true), release("0.17.99")
        ), includePrereleases = true)
        assertEquals("0.19-rc.10", result?.version)
    }

    @Test
    fun optInStillPrefersStableOverPrereleaseOfSameVersion() {
        val result = UpdateChecker.parseReleaseResponse(response(
            release("0.19-rc.10", prerelease = true), release("0.19"),
            release("1.0", prerelease = true, draft = true)
        ), includePrereleases = true)
        assertEquals("0.19", result?.version)
    }

    @Test
    fun allPrereleaseRepositoryRequiresOptIn() {
        val json = response(release("0.19-beta.1", prerelease = true))
        assertNull(UpdateChecker.parseReleaseResponse(json, includePrereleases = false))
        assertEquals("0.19-beta.1", UpdateChecker.parseReleaseResponse(json, includePrereleases = true)?.version)
        assertNull(UpdateChecker.parseReleaseResponse("[]", includePrereleases = true))
    }

    @Test
    fun supportsLatestStableObjectAndIgnoresMalformedTags() {
        assertEquals("0.19", UpdateChecker.parseReleaseResponse(release("0.19").toString(), false)?.version)
        assertNull(UpdateChecker.parseReleaseResponse(release("0.19", draft = true).toString(), true))
        assertEquals("0.19", UpdateChecker.parseReleaseResponse(response(
            release("nightly"), JSONObject().put("name", "No tag"), release("0.19")
        ), true)?.version)
    }

    @Test
    fun choosesReleaseApkAndRejectsInsecureLinks() {
        val json = release("0.19-beta.1", prerelease = true)
            .put("html_url", "http://example.com/release")
            .put("assets", JSONArray().put(JSONObject()
                .put("name", "KristalLauncher-v0.19-debug.apk")
                .put("browser_download_url", "https://example.com/debug.apk"))
                .put(JSONObject().put("name", "KristalLauncher-v0.19-release.apk")
                    .put("browser_download_url", "https://example.com/release.apk")))
        val result = UpdateChecker.parseReleaseResponse(response(json), true)
        assertEquals("https://example.com/release.apk", result?.downloadUrl)
        assertEquals(BuildConfig.GITHUB_REPOSITORY_URL, result?.releaseUrl)
        json.put("assets", JSONArray().put(JSONObject().put("name", "KristalLauncher-release.apk")
            .put("browser_download_url", "http://example.com/release.apk")))
        assertEquals(BuildConfig.GITHUB_REPOSITORY_URL,
            UpdateChecker.parseReleaseResponse(response(json), true)?.downloadUrl)
    }

    @Test
    fun endpointAndVersionComparisonPreserveStableDefaultsWithoutDowngrades() {
        assertEquals("/releases/latest", UpdateChecker.releaseEndpoint(false))
        assertEquals("/releases?per_page=100", UpdateChecker.releaseEndpoint(true))
        val result = UpdateChecker.parseReleaseResponse(response(release("0.18-rc.1", prerelease = true)), true)!!
        assertFalse(VersionUtils.isNewer(result.version, "0.18"))
        assertTrue(VersionUtils.isNewer("0.18", "0.18-rc.1"))
        assertTrue(VersionUtils.isNewer("0.18", "0.17.53"))
    }

    @Test
    fun rejectsUnexpectedResponseTypesAndOversizedReleaseLists() {
        assertThrows(IllegalStateException::class.java) { UpdateChecker.parseReleaseResponse("false", true) }
        val many = JSONArray()
        repeat(101) { many.put(release("0.19")) }
        assertThrows(IllegalArgumentException::class.java) { UpdateChecker.parseReleaseResponse(many.toString(), true) }
    }
}
