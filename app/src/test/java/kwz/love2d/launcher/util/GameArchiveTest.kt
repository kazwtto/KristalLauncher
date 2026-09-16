package kwz.love2d.launcher.util

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream
import kwz.love2d.launcher.model.GamePackageType

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
        val previewBytes = byteArrayOf(0x10, 0x20, 0x30, 0x40)
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
                writeEntry(zip, "release/game/mods/real/preview/bg_01.png", "secondary")
                zip.putNextEntry(ZipEntry("release/game/mods/real/preview/bg.png"))
                zip.write(previewBytes)
                zip.closeEntry()
            }

            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(renamedLove))
            assertEquals("Complete Game", metadata.title)
            assertEquals("Complete Subtitle", metadata.subtitle)
            assertEquals("v1.2.3", metadata.version)
            assertEquals("v0.10.0", metadata.engineVersion)
            assertEquals("Author", metadata.author)
            assertArrayEquals(iconBytes, metadata.iconBytes)
            assertEquals(1, metadata.previewLayers.size)
            assertArrayEquals("secondary".toByteArray(), metadata.previewLayers[0])
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun ignoresPreviewImagesThatAreNotBackgrounds() {
        val directory = Files.createTempDirectory("preview-fallback-test").toFile()
        val archiveFile = directory.resolve("preview-fallback.love")
        val previewBytes = byteArrayOf(0x51, 0x52, 0x53)
        try {
            ZipOutputStream(archiveFile.outputStream()).use { zip ->
                writeEntry(zip, "main.lua", "return true")
                writeEntry(zip, "mods/demo/mod.json", """{"name":"Preview Fallback"}""")
                zip.putNextEntry(ZipEntry("mods/demo/preview/forest-art.webp"))
                zip.write(previewBytes)
                zip.closeEntry()
            }

            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(archiveFile))
            assertTrue(metadata.previewLayers.isEmpty())
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun fallsBackToKristalTitleBackgroundWhenTheModHasNoBackground() {
        val directory = Files.createTempDirectory("default-preview-test").toFile()
        val archiveFile = directory.resolve("default-preview.love")
        val fallbackBytes = "default-kristal-background".toByteArray()
        try {
            ZipOutputStream(archiveFile.outputStream()).use { zip ->
                writeEntry(zip, "main.lua", "return true")
                writeEntry(zip, "mods/demo/mod.json", """{"name":"Default Preview"}""")
                zip.putNextEntry(ZipEntry("assets/sprites/kristal/title_bg_wave.png"))
                zip.write(fallbackBytes)
                zip.closeEntry()
            }

            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(archiveFile))
            assertEquals(1, metadata.previewLayers.size)
            assertArrayEquals(fallbackBytes, metadata.previewLayers.single())
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun targetModSelectsMetadataAndPreviewInsteadOfAlphabeticalFolder() {
        val directory = Files.createTempDirectory("target-mod-test").toFile()
        val archiveFile = directory.resolve("target-mod.love")
        val targetIcon = "target-icon".toByteArray()
        val largestBackground = "largest-target-background".toByteArray()
        try {
            ZipOutputStream(archiveFile.outputStream()).use { zip ->
                writeEntry(zip, "main.lua", "return true")
                writeEntry(zip, "src/engine/statevars.lua", "TARGET_MOD = \"actual_game\"")
                writeEntry(zip, "mods/aaa/mod.json", """{"id":"wrong","name":"Wrong Game"}""")
                writeEntry(zip, "mods/aaa/preview/bg.png", "wrong-background-is-deliberately-long")
                writeEntry(
                    zip,
                    "mods/zzz/mod.json",
                    """{"id":"actual_game","name":"Actual Game","version":"v2.0.0"}"""
                )
                zip.putNextEntry(ZipEntry("mods/zzz/preview/icon_01.png"))
                zip.write(targetIcon)
                zip.closeEntry()
                writeEntry(zip, "mods/zzz/preview/bg.png", "small")
                zip.putNextEntry(ZipEntry("mods/zzz/preview/bg_01.png"))
                zip.write(largestBackground)
                zip.closeEntry()
            }

            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(archiveFile))
            assertEquals("Actual Game", metadata.title)
            assertEquals("v2.0.0", metadata.version)
            assertEquals("mods/zzz", metadata.translationRoot)
            assertArrayEquals(targetIcon, metadata.iconBytes)
            assertArrayEquals(largestBackground, metadata.previewLayers.single())
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun previewScriptSelectsSemanticBackgroundInsteadOfLargerOverlay() {
        val directory = Files.createTempDirectory("script-preview-test").toFile()
        val archiveFile = directory.resolve("script-preview.love")
        val roomBackground = "room-background".toByteArray()
        try {
            ZipOutputStream(archiveFile.outputStream()).use { zip ->
                writeEntry(zip, "main.lua", "return true")
                writeEntry(zip, "mods/frozen/mod.json", """{"id":"frozen","name":"Frozen"}""")
                writeEntry(
                    zip,
                    "mods/frozen/preview/preview.lua",
                    """
                    local preview = {}
                    function preview:init(mod)
                        self.bg = love.graphics.newImage(mod.path.."/preview/room.png")
                        self.overlay = love.graphics.newImage(mod.path.."/preview/very_large_overlay.png")
                    end
                    return preview
                    """.trimIndent()
                )
                zip.putNextEntry(ZipEntry("mods/frozen/preview/room.png"))
                zip.write(roomBackground)
                zip.closeEntry()
                writeEntry(
                    zip,
                    "mods/frozen/preview/very_large_overlay.png",
                    "this-overlay-is-larger-but-is-not-a-background"
                )
                writeEntry(zip, "assets/sprites/kristal/title_bg_wave.png", "fallback")
            }

            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(archiveFile))
            assertArrayEquals(roomBackground, metadata.previewLayers.single())
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun previewScriptCanResolveAModRelativePathHelper() {
        val directory = Files.createTempDirectory("mod-preview-helper-test").toFile()
        val archiveFile = directory.resolve("mod-preview-helper.love")
        val modBackground = "mod-specific-wave".toByteArray()
        try {
            ZipOutputStream(archiveFile.outputStream()).use { zip ->
                writeEntry(zip, "main.lua", "return true")
                writeEntry(zip, "mods/crocker/mod.json", """{"id":"crocker","name":"Crocker"}""")
                writeEntry(
                    zip,
                    "mods/crocker/preview/preview.lua",
                    """
                    function preview:init(mod)
                        self.base_path = mod.path
                        local function p(file) return self.base_path .. "/" .. file end
                        self.background_image_wave = love.graphics.newImage(
                            p("assets/sprites/kristal/title_bg_wave.png")
                        )
                    end
                    """.trimIndent()
                )
                zip.putNextEntry(ZipEntry("mods/crocker/assets/sprites/kristal/title_bg_wave.png"))
                zip.write(modBackground)
                zip.closeEntry()
                writeEntry(zip, "assets/sprites/kristal/title_bg_wave.png", "global-fallback")
            }

            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(archiveFile))
            assertArrayEquals(modBackground, metadata.previewLayers.single())
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
    fun recognizesAStandaloneKristalModBelowAWrapperFolder() {
        val directory = Files.createTempDirectory("mod-source-test").toFile()
        val modSource = directory.resolve("prince-of-darkness.love")
        try {
            ZipOutputStream(modSource.outputStream()).use { zip ->
                writeEntry(
                    zip,
                    "ralsei_prince_of_darkness/mod.json",
                    """{"id":"ralsei_prince_of_darkness","name":"Ralsei: Prince of Darkness","version":"v1.5.0","author":null}"""
                )
                writeEntry(zip, "ralsei_prince_of_darkness/preview/icon_1.png", "preview")
            }

            val metadata = requireNotNull(LoveMetadataParser.inspectArchive(modSource))
            assertEquals("Ralsei: Prince of Darkness", metadata.title)
            assertEquals("ralsei_prince_of_darkness", metadata.projectId)
            assertEquals("ralsei_prince_of_darkness", metadata.modArchiveRoot)
            assertEquals("ralsei_prince_of_darkness", metadata.translationRoot)
            assertEquals(GamePackageType.KRISTAL_MOD, metadata.packageType)
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun buildsARunnablePrivateRuntimeWithTheStandaloneMod() {
        val directory = Files.createTempDirectory("standalone-mod-launch-test").toFile()
        val runtime = directory.resolve("kristal.love")
        val mod = directory.resolve("mod.zip")
        val combined = directory.resolve("combined.love")
        try {
            ZipOutputStream(runtime.outputStream()).use { zip ->
                writeEntry(
                    zip,
                    "main.lua",
                    "require(\"src.engine.vendcust\")\nKristal = require(\"src.kristal\")"
                )
                writeEntry(zip, "src/engine/vendcust.lua", "TARGET_MOD = nil\nAUTO_MOD_START = false")
            }
            ZipOutputStream(mod.outputStream()).use { zip ->
                writeEntry(zip, "release/mod.json", """{"id":"demo","name":"Demo"}""")
                writeEntry(zip, "release/scripts/world/MyCutscene.lua", "return true")
            }

            mod.inputStream().use { input ->
                GameLauncher.writeKristalModPackage(runtime, input, "release", "demo", combined)
            }

            ZipFile(combined).use { zip ->
                val mainLua = zip.getInputStream(zip.getEntry("main.lua"))
                    .bufferedReader()
                    .use { it.readText() }
                assertTrue(mainLua.contains("TARGET_MOD = \"demo\""))
                assertTrue(mainLua.contains("AUTO_MOD_START = true"))
                assertTrue(zip.getEntry("mods/demo/mod.json") != null)
                assertTrue(zip.getEntry("mods/demo/scripts/world/MyCutscene.lua") != null)
            }
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
