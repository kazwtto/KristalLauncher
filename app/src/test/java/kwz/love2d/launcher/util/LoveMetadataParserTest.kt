package kwz.love2d.launcher.util

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LoveMetadataParserTest {

    @Test
    fun recognizesKristalTemplateProjectNames() {
        assertTrue(LoveMetadataParser.isPlaceholderTitle("Example Project"))
        assertTrue(LoveMetadataParser.isPlaceholderTitle("  EXEMPLE   PROJECT  "))
        assertTrue(LoveMetadataParser.isPlaceholderTitle("Example Mod"))
        assertFalse(LoveMetadataParser.isPlaceholderTitle("Example Project Redux"))
    }

    @Test
    fun recognizesNestedLoveAndExecutablePackages() {
        assertTrue(NestedGamePackageParser.isGamePackage("downloads/game.love"))
        assertTrue(NestedGamePackageParser.isGamePackage("bundle/windows/GAME.EXE"))
        assertFalse(NestedGamePackageParser.isGamePackage("bundle/main.lua"))
    }
}
