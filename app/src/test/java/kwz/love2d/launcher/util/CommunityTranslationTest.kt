package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.TranslationFileReplacement
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files

class CommunityTranslationTest {
    @Test
    fun parsesCatalogEntryForOneExactGameVersion() {
        val result = CommunityTranslationCatalogService.parseCatalog(
            """
            {
              "schemaVersion": 1,
              "translations": [{
                "schemaVersion": 1,
                "id": "plugged-dream.pt-br",
                "version": "1.0.0",
                "name": {"en": "Plugged Dream in Portuguese"},
                "description": {"en": "Community translation"},
                "author": "kazwtto",
                "gameProjectId": "plugged_dream",
                "gameVersion": "v1.3.0",
                "sourceLanguage": "en",
                "targetLanguage": "pt-BR",
                "minimumLauncherVersion": "0.17.40",
                "package": "packages/plugged-dream-ptbr-1.0.0.kllang",
                "sha256": "${"a".repeat(64)}"
              }]
            }
            """.trimIndent()
        )

        assertEquals(1, result.size)
        assertEquals("plugged_dream", result.single().manifest.gameProjectId)
        assertEquals("v1.3.0", result.single().manifest.gameVersion)
        assertTrue(result.single().packageUrl.endsWith("/translations/packages/plugged-dream-ptbr-1.0.0.kllang"))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsEngineFileTarget() {
        CommunityTranslationManifestParser.parse(
            """
            {
              "schemaVersion": 1,
              "id": "unsafe.translation",
              "version": "1.0.0",
              "name": "Unsafe",
              "description": "Unsafe",
              "author": "test",
              "gameProjectId": "demo_game",
              "gameVersion": "1.0.0",
              "sourceLanguage": "en",
              "targetLanguage": "pt-BR",
              "files": [{
                "source": "payload/src/engine/menu.lua",
                "target": "src/engine/menu.lua",
                "sourceSha256": "${"a".repeat(64)}",
                "translatedSha256": "${"b".repeat(64)}"
              }]
            }
            """.trimIndent()
        )
    }

    @Test
    fun replacesOnlyWhenOriginalAndPayloadHashesMatch() {
        val directory = Files.createTempDirectory("community-translation-test").toFile()
        try {
            val source = "Text(\"Start game\")".toByteArray()
            val translated = "Text(\"Iniciar jogo\")".toByteArray()
            val payload = directory.resolve("menu.lua").apply { writeBytes(translated) }
            val replacement = TranslationFileReplacement(
                sourceSha256 = TranslationExtractor.sha256(source),
                translatedSha256 = TranslationExtractor.sha256(translated),
                file = payload
            )

            assertEquals(
                translated.toString(Charsets.UTF_8),
                TranslationManager.applyFileReplacement(source, replacement).toString(Charsets.UTF_8)
            )
            val failure = runCatching {
                TranslationManager.applyFileReplacement("changed".toByteArray(), replacement)
            }
            assertTrue(failure.isFailure)
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }
}
