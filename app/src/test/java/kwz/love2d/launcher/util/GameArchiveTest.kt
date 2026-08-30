package kwz.love2d.launcher.util

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class GameArchiveTest {

    @Test
    fun readsEntriesThroughTheCentralDirectory() {
        val directory = Files.createTempDirectory("game-archive-test").toFile()
        val archiveFile = directory.resolve("game.love")
        try {
            ZipOutputStream(archiveFile.outputStream()).use { zip ->
                repeat(1_000) { index ->
                    zip.putNextEntry(ZipEntry("assets/$index.txt"))
                    zip.write("ignored".toByteArray())
                    zip.closeEntry()
                }
                zip.putNextEntry(ZipEntry("mods/demo/mod.json"))
                zip.write("{\"name\":\"Demo\"}".toByteArray())
                zip.closeEntry()
            }

            GameArchive.open(archiveFile).use { archive ->
                assertEquals(GameArchive.AccessMode.DIRECT_FILE, archive.accessMode)
                assertEquals(GameArchive.Backend.PLATFORM_ZIP_FILE, archive.backend)
                val entries = archive.entries()
                assertEquals(1_001, entries.size)
                val metadata = entries.single { it.name == "mods/demo/mod.json" }
                assertEquals(
                    "{\"name\":\"Demo\"}",
                    archive.open(metadata).bufferedReader().use { it.readText() }
                )
            }
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun readsSelfExtractingArchivePreamble() {
        val directory = Files.createTempDirectory("game-executable-test").toFile()
        val executable = directory.resolve("game.exe")
        try {
            val zipBytes = ByteArrayOutputStream().also { bytes ->
                ZipOutputStream(bytes).use { zip ->
                    zip.putNextEntry(ZipEntry("main.lua"))
                    zip.write("return true".toByteArray())
                    zip.closeEntry()
                }
            }.toByteArray()
            executable.outputStream().use { output ->
                output.write("MZmock-executable".toByteArray())
                output.write(zipBytes)
            }

            GameArchive.open(executable).use { archive ->
                assertEquals(
                    setOf("game.exe"),
                    directory.listFiles().orEmpty().mapTo(linkedSetOf()) { it.name }
                )
                val mainLua = archive.entries().single { it.name == "main.lua" }
                assertEquals(
                    "return true",
                    archive.open(mainLua).bufferedReader().use { it.readText() }
                )
            }
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun readsCompleteMetadataAndIconFromRenamedLoveZip() {
        val directory = Files.createTempDirectory("renamed-love-test").toFile()
        val renamedLove = directory.resolve("distribution.zip")
        val iconBytes = byteArrayOf(0x01, 0x23, 0x45, 0x67)
        try {
            ZipOutputStream(renamedLove.outputStream()).use { zip ->
                writeEntry(zip, "examples/template/main.lua", "return true")
                writeEntry(zip, "release/game/main.lua", "return true")
                writeEntry(zip, "release/game/conf.lua", "function love.conf(t) t.window.title='Fallback' end")
                writeEntry(
                    zip,
                    "release/game/mods/real/mod.json",
                    """{"name":"Complete Game","subtitle":"Complete Subtitle","version":"v1.2.3","engineVer":"v0.10.0","author":"Author"}"""
                )
                zip.putNextEntry(ZipEntry("release/game/mods/real/icon.png"))
                zip.write(iconBytes)
                zip.closeEntry()
            }

            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(renamedLove))
            assertEquals("Complete Game", metadata.title)
            assertEquals("Complete Subtitle", metadata.subtitle)
            assertEquals("v1.2.3", metadata.version)
            assertEquals("v0.10.0", metadata.engineVersion)
            assertEquals("Author", metadata.author)
            assertArrayEquals(iconBytes, metadata.iconBytes)
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun readsGameMetadataBelowANonCanonicalFolderRoot() {
        val directory = Files.createTempDirectory("folder-wrapped-love-test").toFile()
        val archiveFile = directory.resolve("folder-wrapped.love")
        val iconBytes = byteArrayOf(0x11, 0x22, 0x33)
        try {
            ZipOutputStream(archiveFile.outputStream()).use { zip ->
                writeEntry(zip, "../ignored/main.lua", "return false")
                writeEntry(zip, "./Release\\Game\\main.lua", "return true")
                writeEntry(
                    zip,
                    "./Release\\Game\\mods\\actual\\mod.json",
                    """{"name":"Folder Wrapped","subtitle":"Below the root","version":"v4.2.0"}"""
                )
                zip.putNextEntry(ZipEntry("./Release\\Game\\mods\\actual\\icon.png"))
                zip.write(iconBytes)
                zip.closeEntry()
            }

            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(archiveFile))
            assertEquals("Folder Wrapped", metadata.title)
            assertEquals("Below the root", metadata.subtitle)
            assertEquals("v4.2.0", metadata.version)
            assertArrayEquals(iconBytes, metadata.iconBytes)
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun readsKristalJsonCommentsWithoutDamagingUrls() {
        val sanitized = LoveMetadataParser.stripJsonComments(
            """
            {
              // Kristal template comment
              "name": "Commented Game",
              "website": "https://example.com/path//kept",
              /* another template comment */
              "version": "v1.0.0"
            }
            """.trimIndent()
        )

        assertTrue("Line comments were not removed", "template comment" !in sanitized)
        assertTrue("Block comments were not removed", "another template" !in sanitized)
        assertTrue("URL content was damaged", "https://example.com/path//kept" in sanitized)
    }

    @Test
    fun ignoresAModSourceThatDoesNotContainALoveGame() {
        val directory = Files.createTempDirectory("mod-source-test").toFile()
        val modSource = directory.resolve("prince-of-darkness.love")
        try {
            ZipOutputStream(modSource.outputStream()).use { zip ->
                writeEntry(
                    zip,
                    "ralsei_prince_of_darkness/mod.json",
                    """{"name":"Ralsei: Prince of Darkness","version":"v1.5.0"}"""
                )
                writeEntry(zip, "ralsei_prince_of_darkness/preview/icon_1.png", "preview")
            }

            assertNull(LoveMetadataParser.inspectArchive(modSource))
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    private fun writeEntry(zip: ZipOutputStream, path: String, value: String) {
        zip.putNextEntry(ZipEntry(path))
        zip.write(value.toByteArray(Charsets.UTF_8))
        zip.closeEntry()
    }
}
