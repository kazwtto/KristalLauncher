package kwz.love2d.launcher.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class TranslationExtractorTest {

    @Test
    fun extractsOnlyPlayerFacingStrings() {
        val source = """
            -- Text("This comment is not dialogue")
            local asset = "sprites/hero"
            cutscene:text("Hello, traveler!")
            cutscene:choicer({"Continue", "Leave"})
            self.description = "A visible item description"
            Game:setFlag("technical_flag", true)
        """.trimIndent()

        val entries = TranslationExtractor.extractFile("scripts/cutscene.lua", source)
        val texts = entries.map { it.sourceText }

        assertTrue("Hello, traveler!" in texts)
        assertTrue("Continue" in texts)
        assertTrue("Leave" in texts)
        assertTrue("A visible item description" in texts)
        assertFalse("This comment is not dialogue" in texts)
        assertFalse("sprites/hero" in texts)
        assertFalse("technical_flag" in texts)
    }

    @Test
    fun explicitModRootNeverReturnsEngineText() {
        val directory = Files.createTempDirectory("translation-root-test").toFile()
        val archive = directory.resolve("game.love")
        try {
            ZipOutputStream(archive.outputStream()).use { zip ->
                fun entry(path: String, source: String) {
                    zip.putNextEntry(ZipEntry(path))
                    zip.write(source.toByteArray())
                    zip.closeEntry()
                }
                entry("src/engine/menu.lua", "Text(\"Engine settings\")")
                entry("libraries/framework/ui.lua", "Text(\"Library label\")")
                entry("mods/demo/scripts/story.lua", "Text(\"Game dialogue\")")
                entry("mods/other/scripts/story.lua", "Text(\"Other mod dialogue\")")
            }

            val result = TranslationExtractor.extract(
                sourceArchive = archive,
                sourceRoot = "mods/demo",
                targetRoot = "mods/demo"
            )

            assertEquals(listOf("Game dialogue"), result.entries.map { it.sourceText })
            assertTrue(result.entries.all { it.filePath == "scripts/story.lua" })
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun appliesOnlyValidatedOffsetsFromTheSameSourceFile() {
        val source = "Text(\"Start game\")\nText(\"Quit\")"
        val entries = TranslationExtractor.extractFile("scripts/menu.lua", source)
        val translated = entries.map { entry ->
            kwz.love2d.launcher.model.TranslationReplacement(
                entryId = entry.id,
                fileHash = entry.fileHash,
                startOffset = entry.startOffset,
                endOffset = entry.endOffset,
                sourceText = entry.sourceText,
                translatedText = when (entry.sourceText) {
                    "Start game" -> "Iniciar jogo"
                    else -> "Sair"
                }
            )
        }

        val output = TranslationManager.applyToLua(source.toByteArray(), translated).toString(Charsets.UTF_8)
        assertEquals("Text(\"Iniciar jogo\")\nText(\"Sair\")", output)
    }
}
