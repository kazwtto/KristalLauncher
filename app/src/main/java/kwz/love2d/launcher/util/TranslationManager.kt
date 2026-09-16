package kwz.love2d.launcher.util

import android.content.Context
import android.net.Uri
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.model.InstalledCommunityTranslation
import kwz.love2d.launcher.model.TranslationFileReplacement
import kwz.love2d.launcher.model.TranslationPlan
import kwz.love2d.launcher.model.TranslationProject
import kwz.love2d.launcher.model.TranslationReplacement
import org.json.JSONObject
import java.io.BufferedOutputStream
import java.security.MessageDigest
import java.util.Locale
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

object TranslationManager {
    enum class ValidationError {
        FORMAT_PLACEHOLDER,
        CONTROL_TAG
    }

    private const val PREFERENCES = "community_translation_selection"

    fun projectsForGame(context: Context, gameStableId: String): List<TranslationProject> =
        TranslationDatabase.get(context).projectsForGame(gameStableId)

    fun project(context: Context, projectId: String): TranslationProject? =
        TranslationDatabase.get(context).project(projectId)

    fun entries(context: Context, projectId: String) =
        TranslationDatabase.get(context).entries(projectId)

    fun entry(context: Context, projectId: String, entryId: String) =
        TranslationDatabase.get(context).entry(projectId, entryId)

    fun updateEntry(context: Context, projectId: String, entryId: String, translation: String) {
        TranslationDatabase.get(context).updateTranslation(projectId, entryId, translation)
    }

    fun createProject(context: Context, game: LoveGame, targetLanguage: String): TranslationProject {
        val normalizedLanguage = normalizeLanguageTag(targetLanguage)
        require(normalizedLanguage.isNotBlank()) { "Target language is required" }
        require(game.engineVer.isNullOrBlank() || !game.translationRoot.isNullOrBlank() || game.isKristalMod) {
            "A game/mod content root could not be identified safely"
        }
        projectsForGame(context, game.stableId)
            .firstOrNull { it.targetLanguage.equals(normalizedLanguage, ignoreCase = true) }
            ?.let { return it }

        val sourceArchive = GameLauncher.materializeTranslationSource(context, game)
        val extracted = TranslationExtractor.extract(sourceArchive, game)
        require(extracted.entries.isNotEmpty()) { "No player-facing game/mod text was found" }
        val now = System.currentTimeMillis()
        val id = sha256("${game.stableId}|$normalizedLanguage|$now").take(24)
        val project = TranslationProject(
            id = id,
            gameStableId = game.stableId,
            gameProjectId = game.projectId,
            gameTitle = game.title,
            gameVersion = game.version,
            sourceFingerprint = extracted.fingerprint,
            sourceRoot = extracted.sourceRoot,
            targetRoot = extracted.targetRoot,
            sourceLanguage = "en",
            targetLanguage = normalizedLanguage,
            createdAt = now,
            updatedAt = now,
            totalEntries = extracted.entries.size,
            translatedEntries = 0
        )
        TranslationDatabase.get(context).insertProject(project, extracted.entries)
        selectProject(context, game.stableId, id)
        return project
    }

    fun selectedProjectId(context: Context, gameStableId: String): String? =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(selectionKey(gameStableId), null)

    fun selectProject(context: Context, gameStableId: String, projectId: String?) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().apply {
            remove(packageSelectionKey(gameStableId))
            if (projectId == null) remove(selectionKey(gameStableId)) else putString(selectionKey(gameStableId), projectId)
        }.apply()
    }

    fun selectedCommunityTranslationId(context: Context, gameStableId: String): String? =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(packageSelectionKey(gameStableId), null)

    fun selectCommunityTranslation(
        context: Context,
        gameStableId: String,
        translationId: String?
    ) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().apply {
            remove(selectionKey(gameStableId))
            if (translationId == null) remove(packageSelectionKey(gameStableId))
            else putString(packageSelectionKey(gameStableId), translationId)
        }.apply()
    }

    fun clearSelection(context: Context, gameStableId: String) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
            .remove(selectionKey(gameStableId))
            .remove(packageSelectionKey(gameStableId))
            .apply()
    }

    fun stateFingerprint(context: Context, game: LoveGame): String {
        selectedCommunityTranslation(context, game)?.let { installed ->
            return sha256("package|${installed.manifest.id}|${installed.manifest.version}|${installed.sha256}")
        }
        val projectId = selectedProjectId(context, game.stableId) ?: return "original"
        val project = project(context, projectId) ?: return "original"
        val entries = entries(context, projectId)
        val content = entries.asSequence()
            .filter { it.translatedText.isNotBlank() }
            .joinToString("\n") { "${it.id}:${sha256(it.translatedText)}" }
        return sha256("${project.id}|${project.sourceFingerprint}|$content")
    }

    fun activePlan(context: Context, game: LoveGame): TranslationPlan? {
        selectedCommunityTranslation(context, game)?.let { installed ->
            val targetRoot = translationTargetRoot(game) ?: return null
            val files = installed.manifest.files.associate { entry ->
                val target = listOf(targetRoot.trim('/'), entry.target.trim('/'))
                    .filter(String::isNotBlank)
                    .joinToString("/")
                    .lowercase(Locale.ROOT)
                target to TranslationFileReplacement(
                    sourceSha256 = entry.sourceSha256,
                    translatedSha256 = entry.translatedSha256,
                    file = CommunityTranslationStorage.safeChild(installed.directory, entry.source)
                )
            }
            return TranslationPlan(
                projectId = installed.manifest.id,
                targetLanguage = installed.manifest.targetLanguage,
                sourceFingerprint = installed.sha256,
                filesByPath = files
            )
        }

        val projectId = selectedProjectId(context, game.stableId) ?: return null
        val project = project(context, projectId) ?: return null
        val replacements = entries(context, projectId)
            .asSequence()
            .filter { it.translatedText.isNotBlank() }
            .groupBy { entry ->
                listOf(project.targetRoot.trim('/'), entry.filePath.trim('/'))
                    .filter(String::isNotBlank)
                    .joinToString("/")
                    .lowercase(Locale.ROOT)
            }
            .mapValues { (_, values) ->
                values.map { entry ->
                    TranslationReplacement(
                        entryId = entry.id,
                        fileHash = entry.fileHash,
                        startOffset = entry.startOffset,
                        endOffset = entry.endOffset,
                        sourceText = entry.sourceText,
                        translatedText = entry.translatedText
                    )
                }
            }
        if (replacements.isEmpty()) return null
        return TranslationPlan(project.id, project.targetLanguage, project.sourceFingerprint, replacements)
    }

    private fun selectedCommunityTranslation(
        context: Context,
        game: LoveGame
    ): InstalledCommunityTranslation? {
        val id = selectedCommunityTranslationId(context, game.stableId) ?: return null
        val installed = CommunityTranslationStorage.installed(context, id) ?: return null
        val manifest = installed.manifest
        if (!manifest.gameProjectId.equals(game.projectId, ignoreCase = true)) return null
        if (!manifest.gameVersion.equals(game.version, ignoreCase = true)) return null
        return installed
    }

    private fun translationTargetRoot(game: LoveGame): String? {
        if (game.isKristalMod) {
            val id = game.projectId?.takeIf(String::isNotBlank) ?: return null
            val folder = id.replace(Regex("[^A-Za-z0-9_.-]"), "_")
                .trim('_', '.')
                .takeIf(String::isNotBlank) ?: return null
            return "mods/$folder"
        }
        return game.translationRoot?.trim('/')
    }

    fun applyToLua(source: ByteArray, replacements: List<TranslationReplacement>): ByteArray {
        val fileHash = TranslationExtractor.sha256(source)
        require(replacements.all { it.fileHash == fileHash }) {
            "The game script changed after this translation was created"
        }
        var text = source.toString(Charsets.UTF_8)
        replacements.sortedByDescending(TranslationReplacement::startOffset).forEach { replacement ->
            require(replacement.startOffset in 0..text.length && replacement.endOffset in replacement.startOffset..text.length) {
                "Invalid translation location: ${replacement.entryId}"
            }
            val translated = validateAndQuote(replacement.sourceText, replacement.translatedText)
            text = text.replaceRange(replacement.startOffset, replacement.endOffset, translated)
        }
        return text.toByteArray(Charsets.UTF_8)
    }

    fun applyFileReplacement(source: ByteArray, replacement: TranslationFileReplacement): ByteArray {
        require(TranslationExtractor.sha256(source) == replacement.sourceSha256) {
            "Translation does not match this game version"
        }
        require(replacement.file.length() in 1..(8L * 1024 * 1024)) { "Translated script is too large" }
        val translated = replacement.file.readBytes()
        require(TranslationExtractor.sha256(translated) == replacement.translatedSha256) {
            "Installed translation file is corrupted"
        }
        return translated
    }

    fun exportProject(context: Context, projectId: String, destination: Uri) {
        val project = project(context, projectId) ?: error("Translation project is unavailable")
        val translatedEntries = entries(context, projectId).filter { it.translatedText.isNotBlank() }
        val manifest = JSONObject()
            .put("schemaVersion", 1)
            .put("id", project.id)
            .put("version", "1.0.0")
            .put("gameProjectId", project.gameProjectId)
            .put("gameTitle", project.gameTitle)
            .put("gameVersion", project.gameVersion)
            .put("sourceFingerprint", project.sourceFingerprint)
            .put("sourceLanguage", project.sourceLanguage)
            .put("targetLanguage", project.targetLanguage)
            .put("textFile", "texts.json")
            .put("imageSupport", false)
        val texts = JSONObject()
        translatedEntries.forEach { entry ->
            texts.put(
                entry.id,
                JSONObject()
                    .put("translation", entry.translatedText)
                    .put("sourceHash", sha256(entry.sourceText))
            )
        }
        context.contentResolver.openOutputStream(destination, "w")?.use { stream ->
            ZipOutputStream(BufferedOutputStream(stream)).use { zip ->
                zip.putNextEntry(ZipEntry("translation.json"))
                zip.write(manifest.toString(2).toByteArray(Charsets.UTF_8))
                zip.closeEntry()
                zip.putNextEntry(ZipEntry("texts.json"))
                zip.write(texts.toString(2).toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }
        } ?: error("Unable to create the translation package")
    }

    private fun validateAndQuote(source: String, translated: String): String {
        require(printfTokens(source) == printfTokens(translated)) {
            "Translation changed a format placeholder"
        }
        require(controlTags(source) == controlTags(translated)) {
            "Translation changed a control tag"
        }
        return buildString {
            append('"')
            translated.forEach { char ->
                append(
                    when (char) {
                        '\\' -> "\\\\"
                        '"' -> "\\\""
                        '\n' -> "\\n"
                        '\r' -> "\\r"
                        '\t' -> "\\t"
                        else -> char
                    }
                )
            }
            append('"')
        }
    }

    fun validationError(source: String, translated: String): ValidationError? = when {
        printfTokens(source) != printfTokens(translated) -> ValidationError.FORMAT_PLACEHOLDER
        controlTags(source) != controlTags(translated) -> ValidationError.CONTROL_TAG
        else -> null
    }

    private fun printfTokens(value: String) = PRINTF.findAll(value.replace("%%", "")).map { it.value }.toList()
    private fun controlTags(value: String) = CONTROL_TAG.findAll(value).map { it.groupValues[1] }.toList()
    private fun selectionKey(gameStableId: String) = "game_${sha256(gameStableId)}"
    private fun packageSelectionKey(gameStableId: String) = "package_${sha256(gameStableId)}"
    private fun normalizeLanguageTag(tag: String) = tag.trim().replace('_', '-').take(32)
    private fun sha256(value: String) = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }

    private val PRINTF = Regex("%(?:[-+ #0]*\\d*(?:\\.\\d+)?[cdiouxXeEfgGaAspq])")
    private val CONTROL_TAG = Regex("\\[([A-Za-z_][A-Za-z0-9_]*)(?::[^]]*)?]")
}
