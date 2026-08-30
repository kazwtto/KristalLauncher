package kwz.love2d.launcher.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

class LoveArchiveNormalizerTest {

    @Test
    fun findsRootAndNestedGameDirectories() {
        assertEquals("", LoveArchiveNormalizer.findGameRoot(listOf("main.lua", "assets/icon.png")))
        assertEquals("aa", LoveArchiveNormalizer.findGameRoot(listOf("AA/main.lua", "AA/conf.lua")))
        assertEquals("one/two", LoveArchiveNormalizer.findGameRoot(listOf("one/two/main.lua")))
    }

    @Test
    fun choosesTheGameRootWithKristalMetadataAcrossSiblingDirectories() {
        assertEquals(
            "release/game",
            LoveArchiveNormalizer.findGameRoot(
                listOf(
                    "examples/template/main.lua",
                    "release/game/main.lua",
                    "release/game/conf.lua",
                    "release/game/mods/demo/mod.json",
                    "release/game/mods/demo/icon.png"
                )
            )
        )
    }

    @Test
    fun recognizesGamePackagesAtAnyWrapperDepth() {
        assertTrue(NestedGamePackageParser.isGamePackage("game.love"))
        assertTrue(NestedGamePackageParser.isGamePackage("AA/subfolder/game.exe"))
        assertFalse(NestedGamePackageParser.isGamePackage("AA/readme.txt"))
    }

    @Test
    fun prefersLovePackagesWhenWrapperAlsoContainsExecutables() {
        assertEquals(
            listOf("AA/game.love"),
            NestedGamePackageParser.selectPreferredGamePackagePaths(
                listOf("AA/game.exe", "AA/game.love", "AA/readme.txt")
            )
        )
        assertEquals(
            listOf("AA/game.exe"),
            NestedGamePackageParser.selectPreferredGamePackagePaths(
                listOf("AA/game.exe", "AA/readme.txt")
            )
        )
    }

    @Test
    fun keepsIndependentGamesAcrossMultipleWrapperDirectories() {
        assertEquals(
            listOf("AA/game.love", "BB/other.exe", "CC/third.love"),
            NestedGamePackageParser.selectPreferredGamePackagePaths(
                listOf(
                    "AA/game.exe",
                    "AA/game.love",
                    "BB/other.exe",
                    "CC/third.love",
                    "docs/readme.txt"
                )
            )
        )
    }

    @Test
    fun recognizesTemplateProjectTitles() {
        assertTrue(LoveMetadataParser.isPlaceholderTitle("Example Project"))
        assertTrue(LoveMetadataParser.isPlaceholderTitle("  EXAMPLE   PROJECT "))
        assertFalse(LoveMetadataParser.isPlaceholderTitle("A real project"))
    }

    @Test
    fun movesNestedGameContentsToArchiveRoot() {
        val directory = Files.createTempDirectory("love-root-test").toFile()
        val archive = File(directory, "nested.zip")
        try {
            ZipOutputStream(archive.outputStream()).use { zip ->
                writeEntry(zip, "../ignored/main.lua", "return false")
                writeEntry(zip, "./AA\\main.lua", "return true")
                writeEntry(zip, "./AA\\mods\\demo\\mod.json", "{\"name\":\"Demo\"}")
                writeEntry(zip, "outside.txt", "ignored")
            }

            assertTrue(LoveArchiveNormalizer.normalizeRootInPlace(archive))
            ZipFile(archive).use { zip ->
                assertEquals("return true", zip.getInputStream(zip.getEntry("main.lua")).bufferedReader().readText())
                assertTrue(zip.getEntry("mods/demo/mod.json") != null)
                assertFalse(zip.getEntry("AA/main.lua") != null)
                assertFalse(zip.getEntry("outside.txt") != null)
            }
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun canonicalizesDotPrefixedRootEntries() {
        val directory = Files.createTempDirectory("love-dot-root-test").toFile()
        val archive = File(directory, "dot-root.love")
        try {
            ZipOutputStream(archive.outputStream()).use { zip ->
                writeEntry(zip, "./main.lua", "return true")
                writeEntry(zip, "./mods/demo/mod.json", "{\"name\":\"Demo\"}")
            }

            assertTrue(LoveArchiveNormalizer.normalizeRootInPlace(archive))
            ZipFile(archive).use { zip ->
                assertEquals("return true", zip.getInputStream(zip.getEntry("main.lua")).bufferedReader().readText())
                assertTrue(zip.getEntry("mods/demo/mod.json") != null)
            }
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun extractsGamePackageFromNestedWrapperDirectory() {
        val gamePackage = zipBytes {
            writeEntry(it, "main.lua", "return true")
            writeEntry(it, "conf.lua", "function love.conf(t) t.window.title = 'Nested' end")
            writeEntry(
                it,
                "mods/nested/mod.json",
                """{"name":"Nested Game","subtitle":"Inside multiple folders","version":"v2.0.0","engineVer":"v0.10.0"}"""
            )
            writeEntry(it, "mods/nested/icon.png", "nested-icon")
        }
        val wrapper = zipBytes { zip ->
            writeEntry(zip, "AA/documentation/readme.txt", "documentation")
            zip.putNextEntry(ZipEntry("./AA\\releases\\game.love"))
            zip.write(gamePackage)
            zip.closeEntry()
            writeEntry(zip, "BB/unrelated/data.txt", "unrelated")
        }
        val extracted = ByteArrayOutputStream()

        GameLauncher.copyNestedPackage(
            source = wrapper.inputStream(),
            outerFileName = "aa.zip",
            entryPath = "./AA\\releases\\game.love",
            destination = extracted
        )

        val directory = Files.createTempDirectory("nested-wrapper-test").toFile()
        val archive = File(directory, "game.love")
        try {
            archive.writeBytes(extracted.toByteArray())
            ZipFile(archive).use { zip ->
                assertEquals("return true", zip.getInputStream(zip.getEntry("main.lua")).bufferedReader().readText())
                assertTrue(zip.getEntry("conf.lua") != null)
            }
            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(archive))
            assertEquals("Nested Game", metadata.title)
            assertEquals("Inside multiple folders", metadata.subtitle)
            assertEquals("v2.0.0", metadata.version)
            assertEquals("v0.10.0", metadata.engineVersion)
            assertEquals("nested-icon", metadata.iconBytes?.toString(Charsets.UTF_8))
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun extractsFusedExecutableFromNestedWrapperDirectory() {
        val gamePackage = zipBytes {
            writeEntry(it, "main.lua", "return true")
            writeEntry(
                it,
                "mods/executable/mod.json",
                """{"name":"Nested Executable","subtitle":"Windows package","version":"v3.0.0"}"""
            )
            writeEntry(it, "mods/executable/icon.png", "executable-icon")
        }
        val executable = "MZmock-love-runtime".toByteArray() + gamePackage
        val wrapper = zipBytes { zip ->
            writeEntry(zip, "AA/readme.txt", "readme")
            zip.putNextEntry(ZipEntry("BB/windows/game.exe"))
            zip.write(executable)
            zip.closeEntry()
            writeEntry(zip, "CC/assets/data.txt", "data")
        }
        val extracted = ByteArrayOutputStream()

        GameLauncher.copyNestedPackage(
            source = wrapper.inputStream(),
            outerFileName = "distribution.zip",
            entryPath = "BB/windows/game.exe",
            destination = extracted
        )

        val directory = Files.createTempDirectory("nested-executable-test").toFile()
        val archive = File(directory, "game.love")
        try {
            archive.writeBytes(extracted.toByteArray())
            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(archive))
            assertEquals("Nested Executable", metadata.title)
            assertEquals("Windows package", metadata.subtitle)
            assertEquals("v3.0.0", metadata.version)
            assertEquals("executable-icon", metadata.iconBytes?.toString(Charsets.UTF_8))
        } finally {
            directory.deleteRecursively()
        }
    }

    private fun zipBytes(content: (ZipOutputStream) -> Unit): ByteArray {
        val output = ByteArrayOutputStream()
        ZipOutputStream(output).use(content)
        return output.toByteArray()
    }

    private fun writeEntry(zip: ZipOutputStream, path: String, value: String) {
        zip.putNextEntry(ZipEntry(path))
        zip.write(value.toByteArray(Charsets.UTF_8))
        zip.closeEntry()
    }
}
