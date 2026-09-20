package kwz.love2d.launcher.util

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Test

class PatchManifestParserTest {

    @Test
    fun parsesDedicatedGameProjectIds() {
        val manifest = PatchManifestParser.parse(
            """
            {
              "schemaVersion": 1,
              "id": "example.patch",
              "version": "1.0.0",
              "name": "Example",
              "description": "Example patch",
              "author": "dev",
              "compatibleGameProjectIds": ["game-id", "Game_Id"],
              "capabilities": ["inject_files"],
              "operations": [{
                "type": "inject",
                "source": "payload/file.lua",
                "target": "scripts/file.lua"
              }]
            }
            """.trimIndent()
        )

        assertEquals(listOf("game-id", "Game_Id"), manifest.compatibleGameProjectIds)
    }

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
