package kwz.love2d.launcher.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

class KristalRuntimeTest {

    @Test
    fun catalogUsesOnlyOfficialLoveRuntimeAssets() {
        val releases = KristalRuntimeCatalogService.parseCatalog(
            """
            [
              {
                "tag_name": "v0.10.0",
                "draft": false,
                "prerelease": false,
                "published_at": "2026-06-23T00:00:00Z",
                "assets": [
                  {"name":"example-project.zip","size":1,"browser_download_url":"https://github.com/KristalTeam/Kristal/releases/download/v0.10.0/example-project.zip"},
                  {"name":"kristal-0.10.0-win.zip","size":2,"browser_download_url":"https://github.com/KristalTeam/Kristal/releases/download/v0.10.0/kristal-0.10.0-win.zip"},
                  {"name":"kristal-0.10.0-love.zip","size":3,"digest":"sha256:6a5760290e05da51fd23ba7811c9c1fbe7bccf872ea58ce44ba1417692dc0093","browser_download_url":"https://github.com/KristalTeam/Kristal/releases/download/v0.10.0/kristal-0.10.0-love.zip"}
                ]
              },
              {
                "tag_name": "v0.8.1",
                "draft": false,
                "prerelease": false,
                "assets": [
                  {"name":"kristal-0.8.1.love","size":4,"browser_download_url":"https://github.com/KristalTeam/Kristal/releases/download/v0.8.1/kristal-0.8.1.love"}
                ]
              }
            ]
            """.trimIndent()
        )

        assertEquals(listOf("v0.10.0", "v0.8.1"), releases.map { it.tag })
        assertEquals("kristal-0.10.0-love.zip", releases.first().assetName)
        assertEquals("6a5760290e05da51fd23ba7811c9c1fbe7bccf872ea58ce44ba1417692dc0093", releases.first().sha256)
    }

    @Test
    fun loveWrapperExtractionFindsNestedKristalPackage() {
        val directory = Files.createTempDirectory("kristal-runtime-test").toFile()
        try {
            val runtime = File(directory, "source.love")
            createZip(runtime, mapOf("main.lua" to "return true", "src/kristal.lua" to "return {}"))
            val wrapper = File(directory, "wrapper.zip")
            ZipOutputStream(FileOutputStream(wrapper)).use { output ->
                output.putNextEntry(ZipEntry("kristal-0.10.0/kristal.love"))
                runtime.inputStream().use { it.copyTo(output) }
                output.closeEntry()
            }

            val extracted = File(directory, "extracted.love")
            KristalRuntimeInstaller.extractLoveRuntime(wrapper, extracted)

            assertTrue(KristalRuntimeStorage.hasRootMainLua(extracted))
            ZipFile(extracted).use { assertTrue(it.getEntry("src/kristal.lua") != null) }
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun packageWithoutRootMainLuaIsRejected() {
        val directory = Files.createTempDirectory("kristal-runtime-invalid-test").toFile()
        try {
            val runtime = File(directory, "invalid.love")
            createZip(runtime, mapOf("folder/main.lua" to "return true"))
            assertFalse(KristalRuntimeStorage.hasRootMainLua(runtime))
        } finally {
            directory.deleteRecursively()
        }
    }

    private fun createZip(file: File, entries: Map<String, String>) {
        ZipOutputStream(FileOutputStream(file)).use { output ->
            entries.forEach { (name, content) ->
                output.putNextEntry(ZipEntry(name))
                output.write(content.toByteArray())
                output.closeEntry()
            }
        }
    }
}
