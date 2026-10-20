package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.InstalledCommunityTranslation
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.nio.file.Files
import java.util.zip.ZipFile

class TranslationFontsTest {
    private val repository = File(System.getProperty("user.dir"), "..").canonicalFile

    @Test
    fun everyCurrentPackageContainsTheVerifiedPairAndTargetsOnlyItsMod() {
        val catalog = JSONObject(File(repository, "translations/catalog.json").readText()).getJSONArray("translations")
        assertTrue(catalog.length() > 0)
        for (index in 0 until catalog.length()) {
            val item = catalog.getJSONObject(index)
            val directory = Files.createTempDirectory("translation-font-test").toFile()
            try {
                ZipFile(File(repository, "translations/${item.getString("package")}")).use { zip ->
                    val manifest = CommunityTranslationManifestParser.parse(zip.getInputStream(zip.getEntry("translation.json"))
                        .bufferedReader().use { it.readText() })
                    assertEquals("0.17.53", manifest.minimumLauncherVersion)
                    assertEquals(2, manifest.fonts.size)
                    for (path in manifest.fonts.map { it.source } + listOfNotNull(manifest.textsFile)) {
                        File(directory, path).apply { parentFile!!.mkdirs() }
                            .writeBytes(zip.getInputStream(zip.getEntry(path)).use { it.readBytes() })
                    }
                    val installed = InstalledCommunityTranslation(manifest, directory, item.getString("sha256"))
                    val plan = TranslationManager.communityPlan(installed, "mods/demo")
                    assertEquals(setOf("mods/demo/assets/fonts/plain.png", "mods/demo/assets/fonts/plain.json"), plan.fontsByPath.keys)
                    assertTrue(TranslationManager.communityPlan(installed, "mods/CookingwithKindness")
                        .fontsByPath.keys.all { it.startsWith("mods/CookingwithKindness/assets/fonts/") })
                    val metadata = JSONObject(plan.fontsByPath.getValue("mods/demo/assets/fonts/plain.json").toString(Charsets.UTF_8))
                    assertTrue(metadata.getString("glyphs").contains("ç"))
                    for (character in "áéíóúãõçñ¡¿«»ªº°€—–…") {
                        assertTrue("Missing PT/ES glyph: $character", metadata.getString("glyphs").contains(character))
                    }
                    File(directory, "fonts/plain.png").appendBytes(byteArrayOf(0))
                    assertThrows(IllegalArgumentException::class.java) { TranslationFonts.read(directory, manifest.fonts) }
                }
            } finally {
                directory.deleteRecursively()
            }
        }
    }

    @Test
    fun rejectsScriptTraversalDuplicateAndIncompleteFontDeclarations() {
        val source = File(repository, "translations/sources/goofball-mod-ptbr/translation.json").readText()
        for (path in listOf("../plain.png", "fonts/main.lua", "fonts/plain.json")) {
            val json = JSONObject(source)
            json.getJSONArray("fonts").getJSONObject(0).put("source", path)
            assertThrows(IllegalArgumentException::class.java) { CommunityTranslationManifestParser.parse(json) }
        }
        val incomplete = JSONObject(source)
        incomplete.getJSONArray("fonts").remove(1)
        assertThrows(IllegalArgumentException::class.java) { CommunityTranslationManifestParser.parse(incomplete) }
    }

    @Test
    fun legacyPackagesHaveNoFontOverrides() {
        val json = JSONObject(File(repository, "translations/sources/goofball-mod-ptbr/translation.json").readText())
        json.remove("fonts")
        assertTrue(CommunityTranslationManifestParser.parse(json).fonts.isEmpty())
    }
}
