package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.InstalledCommunityTranslation
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

/** Applies published translations to private desktop copies without an Android context. */
class OfflineTranslationReviewTest {
    @Test
    fun appliesPublishedPackagesToOriginalGames() {
        val plugged = System.getenv("KL_TRANSLATION_AUDIT_GAME") ?: return
        val cooking = System.getenv("KL_TRANSLATION_AUDIT_COOKING") ?: return
        val repository = File(System.getProperty("user.dir"), "..").canonicalFile
        val output = File(repository, "artifacts/translation-review").apply { mkdirs() }
        val catalog = JSONObject(File(repository, "translations/catalog.json").readText())
            .getJSONArray("translations")
        val reviews = JSONArray()
        for ((translationId, original, root) in listOf(
            Triple("plugged-dream.pt-br", plugged, "mods/plugged_dream"),
            Triple("cooking-with-kindness.pt-br", cooking, "mods/CookingwithKindness"),
            Triple("cooking-with-kindness.es", cooking, "mods/CookingwithKindness")
        )) {
            val catalogEntry = (0 until catalog.length()).map { catalog.getJSONObject(it) }
                .single { it.getString("id") == translationId }
            val packageName = catalogEntry.getString("package").removePrefix("packages/")
            val originalFile = File(original)
            val originalHash = originalFile.inputStream().use { TranslationExtractor.sha256(it.readBytes()) }
            val packageFile = File(repository, "translations/packages/$packageName")
            val packageHash = TranslationExtractor.sha256(packageFile.readBytes())
            assertEquals("Catalog package checksum", catalogEntry.getString("sha256"), packageHash)
            val scratch = File(output, packageName.removeSuffix(".kllang")).apply { mkdirs() }
            val manifest = ZipFile(packageFile).use { pkg ->
                val manifest = CommunityTranslationManifestParser.parse(pkg.getInputStream(pkg.getEntry("translation.json"))
                    .bufferedReader().use { it.readText() })
                val payloads = manifest.files.map { it.source } + listOfNotNull(manifest.textsFile) + manifest.fonts.map { it.source }
                for (path in payloads) {
                    require(PatchManifestParser.isSafeArchivePath(path))
                    val file = File(scratch, path).apply { requireNotNull(parentFile).mkdirs() }
                    file.writeBytes(pkg.getInputStream(pkg.getEntry(path)).use { it.readBytes() })
                }
                manifest.textsFile?.let {
                    assertEquals(manifest.textsSha256, TranslationExtractor.sha256(File(scratch, it).readBytes()))
                }
                manifest
            }
            val plan = TranslationManager.communityPlan(InstalledCommunityTranslation(manifest, scratch, packageHash), root)
            val target = File(output, packageName.removeSuffix(".kllang") + ".love")
            require(target.canonicalPath != originalFile.canonicalPath)
            val changed = JSONArray()
            val seen = mutableSetOf<String>()
            var protectedLabels = 0
            ZipFile(originalFile).use { game ->
                require(game.getEntry(TranslationSafety.RUNTIME_PATH) == null)
                val labels = plan.filesByPath["dialoguedump.json"]?.let { replacement ->
                    val bytes = game.getInputStream(game.getEntry("dialoguedump.json")).use { it.readBytes() }
                    TranslationSafety.jsonLabels(bytes, TranslationManager.applyFileReplacement(bytes, replacement))
                }.orEmpty()
                ZipOutputStream(target.outputStream().buffered()).use { zip ->
                    game.entries().asSequence().forEach { entry ->
                        val key = entry.name.lowercase(java.util.Locale.ROOT)
                        seen.add(key)
                        val source = game.getInputStream(entry).use { it.readBytes() }
                        var result = plan.fontsByPath.entries.firstOrNull { it.key.equals(key, ignoreCase = true) }?.value
                            ?: plan.filesByPath[key]?.let { TranslationManager.applyFileReplacement(source, it) } ?: source
                        val replacements = plan.replacementsByPath[key].orEmpty()
                        val protectJson = labels.isNotEmpty() && key.startsWith(root.lowercase() + "/scripts/") && key.endsWith(".lua")
                        if (replacements.isNotEmpty() || protectJson) {
                            result = TranslationManager.applyToLua(result, replacements, labels)
                        }
                        if (TranslationSafety.isRenderer(key)) result = TranslationSafety.render(result, key)
                        if (key == "main.lua") result = ("__kristal_launcher_translation = require(\"kristal_launcher.translation_labels\")\n"
                            .toByteArray() + result)
                        if (!result.contentEquals(source)) {
                            val guards = Regex("__kristal_launcher_translation\\.label\\(")
                                .findAll(result.toString(Charsets.UTF_8)).count()
                            protectedLabels += guards
                            changed.put(JSONObject().put("path", entry.name).put("protectedLabels", guards)
                                .put("beforeSha256", TranslationExtractor.sha256(source))
                                .put("afterSha256", TranslationExtractor.sha256(result)))
                        }
                        zip.putNextEntry(ZipEntry(entry.name).apply { time = entry.time })
                        zip.write(result)
                        zip.closeEntry()
                    }
                    plan.fontsByPath.filterKeys { it.lowercase(java.util.Locale.ROOT) !in seen }.forEach { (path, bytes) ->
                        zip.putNextEntry(ZipEntry(path))
                        zip.write(bytes)
                        zip.closeEntry()
                    }
                    zip.putNextEntry(ZipEntry(TranslationSafety.RUNTIME_PATH))
                    zip.write(File(repository, "app/src/main/assets/translation_labels.lua").readBytes())
                    zip.closeEntry()
                }
            }
            assertTrue("All replacement targets exist", seen.containsAll(plan.filesByPath.keys + plan.replacementsByPath.keys))
            assertEquals("Original game is unchanged", originalHash,
                originalFile.inputStream().use { TranslationExtractor.sha256(it.readBytes()) })
            ZipFile(target).use { result ->
                assertNotNull(result.getEntry(TranslationSafety.RUNTIME_PATH))
                plan.fontsByPath.forEach { (path, bytes) ->
                    assertNotNull("Case-preserving font target exists: $path", result.getEntry(path))
                    assertArrayEquals(bytes, result.getInputStream(result.getEntry(path)).use { it.readBytes() })
                }
                result.entries().asSequence().forEach { result.getInputStream(it).use { stream -> stream.readBytes() } }
            }
            reviews.put(JSONObject().put("package", packageName).put("original", original)
                .put("originalSha256", originalHash).put("output", target.absolutePath)
                .put("outputSha256", TranslationExtractor.sha256(target.readBytes()))
                .put("protectedLabels", protectedLabels).put("changed", changed))
            // Only final game copies and their report need to remain on disk.
            require(scratch.canonicalPath.startsWith(output.canonicalPath + File.separator))
            scratch.walkBottomUp().forEach { require(it.delete()) }
        }
        File(output, "application-report.json").writeText(JSONObject().put("reviews", reviews).toString(2))
    }
}
