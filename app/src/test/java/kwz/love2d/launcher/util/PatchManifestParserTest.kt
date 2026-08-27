package kwz.love2d.launcher.util

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PatchManifestParserTest {

    @Test
    fun acceptsPortableRelativeArchivePaths() {
        assertTrue(PatchManifestParser.isSafeArchivePath("payload/scripts/runtime.lua"))
        assertTrue(PatchManifestParser.isSafeArchivePath("assets/icon.png"))
    }

    @Test
    fun rejectsTraversalAbsoluteAndWindowsPaths() {
        assertFalse(PatchManifestParser.isSafeArchivePath("../main.lua"))
        assertFalse(PatchManifestParser.isSafeArchivePath("payload/../main.lua"))
        assertFalse(PatchManifestParser.isSafeArchivePath("/main.lua"))
        assertFalse(PatchManifestParser.isSafeArchivePath("C:/main.lua"))
        assertFalse(PatchManifestParser.isSafeArchivePath("payload\\main.lua"))
        assertFalse(PatchManifestParser.isSafeArchivePath("payload//main.lua"))
    }
}
