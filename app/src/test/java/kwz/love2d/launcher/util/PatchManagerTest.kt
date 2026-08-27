package kwz.love2d.launcher.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PatchManagerTest {

    @Test
    fun appendsFooterWhenMainHasNoFinalReturn() {
        val result = PatchManager.appendLuaFooter(
            "function love.load()\nend\n".toByteArray(),
            "require(\"patch\")"
        ).toString(Charsets.UTF_8)

        assertTrue(result.indexOf("require(\"patch\")") > result.indexOf("end"))
    }

    @Test
    fun insertsFooterBeforeFinalModuleReturn() {
        val result = PatchManager.appendLuaFooter(
            "local game = {}\n-- ready\nreturn game\n-- eof\n".toByteArray(),
            "require(\"patch\")"
        ).toString(Charsets.UTF_8)

        assertTrue(result.indexOf("require(\"patch\")") < result.indexOf("return game"))
        assertEquals(1, Regex("return game").findAll(result).count())
    }
}
