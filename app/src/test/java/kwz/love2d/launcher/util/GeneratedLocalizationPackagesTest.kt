package kwz.love2d.launcher.util

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import java.util.zip.ZipFile

class GeneratedLocalizationPackagesTest {
    private val repositoryRoot = File(System.getProperty("user.dir"), "..").canonicalFile

    @Test
    fun parsesRussianEnginePatch() {
        val file = File(repositoryRoot, "patches/packages/kristal-ru-1.0.0.klpatch")
        ZipFile(file).use { zip ->
            val json = zip.getInputStream(zip.getEntry("patch.json"))
                .bufferedReader(Charsets.UTF_8)
                .use { it.readText() }
            val manifest = PatchManifestParser.parse(json)
            assertEquals("kristal.ru", manifest.id)
            assertEquals(86, manifest.operations.size)
        }
    }

    @Test
    fun parsesEverySpanishGameTranslation() {
        val packages = mapOf(
            "funtown-es-1.0.0.kllang" to 277,
            "godhome-es-1.0.0.kllang" to 302,
            "crockerplayable-es-1.0.0.kllang" to 406,
            "friendless-es-1.0.0.kllang" to 552,
            "chapter-5-weird-es-1.0.0.kllang" to 1_861,
            "starrune-es-1.0.0.kllang" to 8_734,
            "vs-kris-es-1.0.0.kllang" to 202,
            "goofball-mod-es-1.0.0.kllang" to 502,
        )
        packages.forEach { (name, expectedEntries) ->
            val file = File(repositoryRoot, "translations/packages/$name")
            ZipFile(file).use { zip ->
                val manifestJson = zip.getInputStream(zip.getEntry("translation.json"))
                    .bufferedReader(Charsets.UTF_8)
                    .use { it.readText() }
                assertEquals("es", CommunityTranslationManifestParser.parse(manifestJson).targetLanguage)
                val textsJson = zip.getInputStream(zip.getEntry("texts.json"))
                    .bufferedReader(Charsets.UTF_8)
                    .use { it.readText() }
                val parsed = CommunityTranslationTextParser.parse(textsJson)
                assertEquals(expectedEntries, parsed.values.sumOf { it.size })
            }
        }
    }
}
