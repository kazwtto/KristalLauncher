package kwz.love2d.launcher.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VersionUtilsTest {

    @Test
    fun comparesSemanticVersionsAndPrefixes() {
        assertTrue(VersionUtils.isNewer("v1.2.0", "1.1.9"))
        assertEquals(0, VersionUtils.compare("1.2", "1.2.0"))
        assertEquals(0, VersionUtils.compare("1.2.0+build.7", "1.2.0+build.8"))
    }

    @Test
    fun releaseIsNewerThanPreRelease() {
        assertTrue(VersionUtils.isNewer("1.0.0", "1.0.0-rc.2"))
        assertFalse(VersionUtils.isNewer("1.0.0-beta.1", "1.0.0"))
        assertTrue(VersionUtils.isNewer("1.0.0-rc.10", "1.0.0-rc.2"))
    }
}
