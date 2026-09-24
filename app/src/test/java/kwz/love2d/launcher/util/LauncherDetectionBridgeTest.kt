package kwz.love2d.launcher.util

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

class LauncherDetectionBridgeTest {

    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun usesOnlyExistingGetModOptionMethod() {
        val hook = LauncherDetectionBridge.buildHook(environment())

        assertTrue(hook.contains("Kristal.getModOption = function(key, ...)"))
        assertTrue(hook.contains("key == \"kristalLauncher\""))
        assertTrue(hook.contains("key == \"kristalLauncher.info\""))
        assertTrue(hook.contains("version = \"1.2.3\\npreview\""))
        assertTrue(hook.contains("active = { \"patch_fullscreen\", \"example.patch\" }"))
        assertTrue(hook.contains("language = \"pt-BR\""))
        assertTrue(hook.contains("return original_get_mod_option(key, ...)"))
        assertTrue(hook.contains("_G.KristalLauncher").not())
    }

    @Test
    fun insertsBridgeBeforeFinalModuleReturn() {
        val result = LauncherDetectionBridge.appendLuaFooter(
            "local game = {}\nreturn game\n".toByteArray(),
            "install_bridge()"
        ).toString(Charsets.UTF_8)

        assertTrue(result.indexOf("install_bridge()") < result.indexOf("return game"))
        assertEquals(1, Regex("return game").findAll(result).count())
    }

    @Test
    fun instrumentsMainAndPreservesUnrelatedEntries() {
        val source = temporaryFolder.newFile("source.love")
        val output = temporaryFolder.newFile("output.love").apply { delete() }
        val asset = byteArrayOf(0, 1, 2, 3, 127, -1)
        ZipOutputStream(source.outputStream()).use { zip ->
            zip.putNextEntry(ZipEntry("main.lua"))
            zip.write("Kristal = { getModOption = function() end }\n".toByteArray())
            zip.closeEntry()
            zip.putNextEntry(ZipEntry("assets/data.bin"))
            zip.write(asset)
            zip.closeEntry()
        }

        LauncherDetectionBridge.writeInstrumentedGame(source, output, environment())

        ZipFile(output).use { zip ->
            val main = zip.getInputStream(zip.getEntry("main.lua")).use { it.readBytes() }
                .toString(Charsets.UTF_8)
            assertTrue(main.contains("key == \"kristalLauncher\""))
            assertTrue(main.contains("key == \"kristalLauncher.info\""))
            assertArrayEquals(
                asset,
                zip.getInputStream(zip.getEntry("assets/data.bin")).use { it.readBytes() }
            )
        }
    }

    private fun environment() = LauncherEnvironmentInfo(
        packageType = "mod",
        isKristalMod = true,
        gameVersion = "1.2.3\npreview",
        engineVersion = "0.10.0-dev",
        runtimeTag = "v0.10.0",
        runtimeVersion = "0.10.0",
        activePatchIds = listOf("patch_fullscreen", "example.patch"),
        translationLanguage = "pt-BR"
    )
}
