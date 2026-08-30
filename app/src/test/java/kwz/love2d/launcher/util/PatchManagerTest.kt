package kwz.love2d.launcher.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class PatchManagerTest {

    @get:Rule
    val temporaryFolder = TemporaryFolder()

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

    @Test
    fun verifiesExternalPatchBytesInStagedArchive() {
        val targetBytes = "return { patched = true }\n".toByteArray()
        val archive = temporaryFolder.newFile("staged.love")
        ZipOutputStream(FileOutputStream(archive)).use { output ->
            output.putNextEntry(ZipEntry("mods/example/runtime.lua"))
            output.write(targetBytes)
            output.closeEntry()
        }

        PatchManager.validateExternalPatchTargets(
            archive,
            mapOf("mods/example/runtime.lua" to sha256(targetBytes))
        )

        assertThrows(IllegalArgumentException::class.java) {
            PatchManager.validateExternalPatchTargets(
                archive,
                mapOf("mods/example/runtime.lua" to sha256("corrupted".toByteArray()))
            )
        }
    }

    private fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes)
        .joinToString("") { "%02x".format(it) }
}
