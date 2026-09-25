package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.TranslationFileReplacement
import kwz.love2d.launcher.model.InstalledCommunityTranslation
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files

class CommunityTranslationTest {
    @Test
    fun combinesLuaTextsAndPackageRootJsonInOnePlan() {
        val directory = Files.createTempDirectory("community-translation-plan").toFile()
        try {
            directory.resolve("texts.json").writeText(
                """{
                  "a1b2c3d4e5f6": {
                    "file": "scripts/test.lua",
                    "fileHash": "${"a".repeat(64)}",
                    "startOffset": 0,
                    "endOffset": 3,
                    "source": "Hello",
                    "translation": "Olá",
                    "originalExpression": "\"Hello\"",
                    "replacementExpression": "\"Olá\""
                  }
                }""".trimIndent()
            )
            directory.resolve("payload").mkdirs()
            directory.resolve("payload/dialoguedump.json").writeText("{}")
            val manifest = CommunityTranslationManifestParser.parse(
                """{
                  "schemaVersion": 1,
                  "id": "cooking-with-kindness.pt-br",
                  "version": "1.0.1",
                  "name": "Cooking translation",
                  "description": "Cooking translation",
                  "author": "dev",
                  "gameProjectId": "cooking-with-kindness",
                  "gameVersion": "DEMO v1.0.6",
                  "sourceLanguage": "en",
                  "targetLanguage": "pt-BR",
                  "textsFile": "texts.json",
                  "textsSha256": "${"a".repeat(64)}",
                  "files": [{
                    "source": "payload/dialoguedump.json",
                    "target": "dialoguedump.json",
                    "scope": "package",
                    "sourceSha256": "${"b".repeat(64)}",
                    "translatedSha256": "${"c".repeat(64)}"
                  }]
                }""".trimIndent()
            )
            val installed = InstalledCommunityTranslation(manifest, directory, "d".repeat(64))
            val plan = TranslationManager.communityPlan(installed, "mods/CookingwithKindness")
            assertTrue("mods/cookingwithkindness/scripts/test.lua" in plan.replacementsByPath)
            assertTrue("dialoguedump.json" in plan.filesByPath)
        } finally {
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test
    fun acceptsGameDataJsonAndNarrowPackageRootJson() {
        val manifest = CommunityTranslationManifestParser.parse(
            """
            {
              "schemaVersion": 1,
              "id": "cooking-with-kindness.pt-br",
              "version": "1.0.1",
              "name": "Cooking translation",
              "description": "Cooking translation",
              "author": "dev",
              "gameProjectId": "cooking-with-kindness",
              "gameVersion": "DEMO v1.0.6",
              "sourceLanguage": "en",
              "targetLanguage": "pt-BR",
              "textsFile": "texts.json",
              "textsSha256": "${"a".repeat(64)}",
              "files": [
                {
                  "source": "payload/dialoguedump.json",
                  "target": "dialoguedump.json",
                  "scope": "package",
                  "sourceSha256": "${"b".repeat(64)}",
                  "translatedSha256": "${"c".repeat(64)}"
                },
                {
                  "source": "payload/data/dialogue.json",
                  "target": "data/dialogue.json",
                  "sourceSha256": "${"d".repeat(64)}",
                  "translatedSha256": "${"e".repeat(64)}"
                }
              ]
            }
            """.trimIndent()
        )
        assertEquals("package", manifest.files[0].scope)
        assertEquals("game", manifest.files[1].scope)
        assertEquals("texts.json", manifest.textsFile)
    }

    @Test
    fun rejectsArbitraryPackageRootJson() {
        assertThrows(IllegalArgumentException::class.java) {
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
                    "source": "payload/config.json",
                    "target": "config.json",
                    "scope": "package",
                    "sourceSha256": "${"a".repeat(64)}",
                    "translatedSha256": "${"b".repeat(64)}"
                  }]
                }
                """.trimIndent()
            )
        }
    }

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
