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
import java.io.File
import java.security.MessageDigest
import java.util.Locale
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
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
        if (!IdentifierPolicy.isLocalProjectId(projectId)) null
        else TranslationDatabase.get(context).project(projectId)

    fun entries(context: Context, projectId: String) =
        if (!IdentifierPolicy.isLocalProjectId(projectId)) emptyList()
        else TranslationDatabase.get(context).entries(projectId)

    fun entry(context: Context, projectId: String, entryId: String) =
        if (!IdentifierPolicy.isLocalProjectId(projectId) || !IdentifierPolicy.isTranslationEntryId(entryId)) null
        else TranslationDatabase.get(context).entry(projectId, entryId)

    fun updateEntry(context: Context, projectId: String, entryId: String, translation: String) {
        IdentifierPolicy.requireLocalProjectId(projectId)
        IdentifierPolicy.requireTranslationEntryId(entryId)
        TranslationDatabase.get(context).updateTranslation(projectId, entryId, translation)
    }

    fun createProject(
        context: Context,
        game: LoveGame,
        targetLanguage: String = Locale.getDefault().toLanguageTag()
    ): TranslationProject {
        val normalizedLanguage = normalizeLanguageTag(targetLanguage)
        require(IdentifierPolicy.isLanguageTag(normalizedLanguage)) { "Target language is invalid" }
        require(game.engineVer.isNullOrBlank() || !game.translationRoot.isNullOrBlank() || game.isKristalMod) {
            "A game/mod content root could not be identified safely"
        }
        val sourceArchive = GameLauncher.materializeTranslationSource(context, game)
        val extracted = TranslationExtractor.extract(sourceArchive, game)
        require(extracted.entries.isNotEmpty()) { "No player-facing game/mod text was found" }
        val now = System.currentTimeMillis()
        val id = sha256("${game.stableId}|$normalizedLanguage|$now").take(24)
        val project = TranslationProject(
            id = id,
            name = defaultProjectName(game.title, normalizedLanguage),
            author = "",
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

    fun updateProject(
        context: Context,
        projectId: String,
        name: String,
        author: String,
        targetLanguage: String
    ) {
        val normalizedName = name.trim().take(100)
        val normalizedAuthor = author.trim().take(80)
        val normalizedLanguage = normalizeLanguageTag(targetLanguage)
        require(normalizedName.isNotBlank()) { "Project name is required" }
        require(IdentifierPolicy.isLanguageTag(normalizedLanguage)) { "Target language is invalid" }
        require(project(context, projectId) != null) { "Translation project is unavailable" }
        TranslationDatabase.get(context).updateProject(
            projectId,
            normalizedName,
            normalizedAuthor,
            normalizedLanguage
        )
    }

    fun clearProject(context: Context, projectId: String) {
        require(project(context, projectId) != null) { "Translation project is unavailable" }
        TranslationDatabase.get(context).clearTranslations(projectId)
    }

    fun deleteProject(context: Context, projectId: String) {
        val project = project(context, projectId) ?: return
        if (selectedProjectId(context, project.gameStableId) == projectId) {
            clearSelection(context, project.gameStableId)
        }
        TranslationDatabase.get(context).deleteProject(projectId)
    }

    fun importProject(context: Context, game: LoveGame, source: Uri): TranslationProject {
        val files = mutableMapOf<String, ByteArray>()
        context.contentResolver.openInputStream(source)?.use { input ->
            ZipInputStream(input.buffered()).use { zip ->
                var totalBytes = 0
                var entry = zip.nextEntry
                while (entry != null) {
                    if (!entry.isDirectory && entry.name in setOf("translation.json", "texts.json")) {
                        val bytes = zip.readBytesLimited(MAX_IMPORT_FILE_BYTES)
                        totalBytes += bytes.size
                        require(totalBytes <= MAX_IMPORT_TOTAL_BYTES) { "Translation package is too large" }
                        files[entry.name] = bytes
                    }
                    zip.closeEntry()
                    entry = zip.nextEntry
                }
            }
        } ?: error("Unable to read the translation package")

        val manifest = JSONObject(files["translation.json"]?.toString(Charsets.UTF_8)
            ?: error("Translation manifest is missing"))
        val texts = JSONObject(files["texts.json"]?.toString(Charsets.UTF_8)
            ?: error("Translation texts are missing"))
        require(manifest.optInt("schemaVersion") == 1) { "Unsupported translation package" }
        require(manifest.opt("id") is String) { "Translation project ID is invalid" }
        IdentifierPolicy.requireLocalProjectId(manifest.optString("id"))
        require(manifest.opt("sourceFingerprint") is String) { "Translation source fingerprint is invalid" }
        require(IdentifierPolicy.isSha256(manifest.optString("sourceFingerprint"))) {
            "Translation source fingerprint is invalid"
        }
        require(manifest.opt("gameProjectId") is String) { "Translation game ID is invalid" }
        require(manifest.optString("gameProjectId").equals(game.projectId, ignoreCase = true)) {
            "Translation belongs to another game"
        }
        val sourceArchive = GameLauncher.materializeTranslationSource(context, game)
        val extracted = TranslationExtractor.extract(sourceArchive, game)
        require(extracted.fingerprint == manifest.optString("sourceFingerprint")) {
            "Translation does not match these game files"
        }
        require(manifest.opt("targetLanguage") is String) { "Translation language is invalid" }
        val language = normalizeLanguageTag(manifest.optString("targetLanguage"))
        require(IdentifierPolicy.isLanguageTag(language)) { "Translation language is invalid" }
        val now = System.currentTimeMillis()
        val id = sha256("${game.stableId}|$language|$now").take(24)
        val importedEntries = extracted.entries.map { entry ->
            val imported = texts.optJSONObject(entry.id)
            val value = imported?.optString("translation").orEmpty()
            val sourceMatches = imported?.optString("sourceHash") == sha256(entry.sourceText)
            entry.copy(
                projectId = id,
                translatedText = value.takeIf {
                    sourceMatches && validationError(entry.sourceText, it) == null
                }.orEmpty()
            )
        }
        val project = TranslationProject(
            id = id,
            name = manifest.optString("name").trim().takeIf(String::isNotBlank)
                ?: defaultProjectName(game.title, language),
            author = manifest.optString("author").trim().take(80),
            gameStableId = game.stableId,
            gameProjectId = game.projectId,
            gameTitle = game.title,
            gameVersion = manifest.optString("gameVersion").trim().takeIf(String::isNotBlank),
            sourceFingerprint = extracted.fingerprint,
            sourceRoot = extracted.sourceRoot,
            targetRoot = extracted.targetRoot,
            sourceLanguage = normalizeLanguageTag(manifest.optString("sourceLanguage", "en")),
            targetLanguage = language,
            createdAt = now,
            updatedAt = now,
            totalEntries = importedEntries.size,
            translatedEntries = importedEntries.count { it.translatedText.isNotBlank() }
        )
        TranslationDatabase.get(context).insertProject(project, importedEntries)
        selectProject(context, game.stableId, id)
        return project
    }

    fun selectedProjectId(context: Context, gameStableId: String): String? =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(selectionKey(gameStableId), null)
            ?.takeIf(IdentifierPolicy::isLocalProjectId)

    fun selectProject(context: Context, gameStableId: String, projectId: String?) {
        if (projectId != null) {
            IdentifierPolicy.requireLocalProjectId(projectId)
            require(project(context, projectId)?.gameStableId == gameStableId) {
                "Translation project does not belong to this game"
            }
        }
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().apply {
            remove(packageSelectionKey(gameStableId))
            if (projectId == null) remove(selectionKey(gameStableId)) else putString(selectionKey(gameStableId), projectId)
        }.apply()
    }

    fun selectedCommunityTranslationId(context: Context, gameStableId: String): String? =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(packageSelectionKey(gameStableId), null)
            ?.takeIf(IdentifierPolicy::isTranslationId)

    fun selectCommunityTranslation(
        context: Context,
        gameStableId: String,
        translationId: String?
    ) {
        if (translationId != null) {
            IdentifierPolicy.requireTranslationId(translationId)
            require(CommunityTranslationStorage.installed(context, translationId) != null) {
                "Community translation is not installed"
            }
        }
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
        if (project.gameStableId != game.stableId) return "original"
        val entries = entries(context, projectId)
        val content = entries.asSequence()
            .filter { it.translatedText.isNotBlank() }
            .joinToString("\n") { "${it.id}:${sha256(it.translatedText)}" }
        return sha256("${project.id}|${project.sourceFingerprint}|$content")
    }

    fun activePlan(context: Context, game: LoveGame): TranslationPlan? {
        selectedCommunityTranslation(context, game)?.let { installed ->
            IdentifierPolicy.requireTranslationId(installed.manifest.id)
            IdentifierPolicy.requirePackageVersion(installed.manifest.version, "Translation version")
            val targetRoot = translationTargetRoot(game) ?: return null
            return communityPlan(installed, targetRoot)
        }

        val projectId = selectedProjectId(context, game.stableId) ?: return null
        val project = project(context, projectId) ?: return null
        if (project.gameStableId != game.stableId) return null
        IdentifierPolicy.requireLocalProjectId(project.id)
        require(IdentifierPolicy.isSha256(project.sourceFingerprint)) {
            "Translation source fingerprint is invalid"
        }
        val replacements = entries(context, projectId)
            .asSequence()
            .filter { it.translatedText.isNotBlank() }
            .groupBy { entry ->
                IdentifierPolicy.requireTranslationEntryId(entry.id)
                require(entry.projectId == project.id) { "Translation entry belongs to another project" }
                require(IdentifierPolicy.isSha256(entry.fileHash)) { "Translation source hash is invalid" }
                require(validationError(entry.sourceText, entry.translatedText) == null) {
                    "Translation entry contains invalid placeholders or control tags"
                }
                val target = listOf(project.targetRoot.trim('/'), entry.filePath.trim('/'))
                    .filter(String::isNotBlank)
                    .joinToString("/")
                    .lowercase(Locale.ROOT)
                require(PatchManifestParser.isSafeArchivePath(target)) {
                    "Translation entry target is unsafe"
                }
                target
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

    internal fun communityPlan(installed: InstalledCommunityTranslation, targetRoot: String): TranslationPlan {
        val replacements = installed.manifest.textsFile?.let { relativePath ->
            val textFile = CommunityTranslationStorage.safeChild(installed.directory, relativePath)
            CommunityTranslationTextParser.parse(textFile.readText(Charsets.UTF_8)).mapKeys { (relative, _) ->
                listOf(targetRoot.trim('/'), relative.trim('/'))
                    .filter(String::isNotBlank)
                    .joinToString("/")
                    .lowercase(Locale.ROOT)
                    .also { require(PatchManifestParser.isSafeArchivePath(it)) }
            }
        }.orEmpty()
        val files = installed.manifest.files.associate { entry ->
            val target = listOf(
                targetRoot.trim('/').takeIf { entry.scope == "game" }.orEmpty(),
                entry.target.trim('/')
            )
                .filter(String::isNotBlank)
                .joinToString("/")
                .lowercase(Locale.ROOT)
            require(PatchManifestParser.isSafeArchivePath(target)) {
                "Translation target path is unsafe"
            }
            target to TranslationFileReplacement(
                sourceSha256 = entry.sourceSha256,
                translatedSha256 = entry.translatedSha256,
                file = CommunityTranslationStorage.safeChild(installed.directory, entry.source)
            )
        }
        require(files.size == installed.manifest.files.size) { "Duplicate translation file target" }
        require(files.keys.intersect(replacements.keys).isEmpty()) {
            "Translation replaces and edits the same game file"
        }
        return TranslationPlan(
            projectId = installed.manifest.id,
            targetLanguage = installed.manifest.targetLanguage,
            sourceFingerprint = installed.sha256,
            replacementsByPath = replacements,
            filesByPath = files
        )
    }

    private fun selectedCommunityTranslation(
        context: Context,
        game: LoveGame
    ): InstalledCommunityTranslation? {
        val id = selectedCommunityTranslationId(context, game.stableId) ?: return null
        IdentifierPolicy.requireTranslationId(id)
        val installed = CommunityTranslationStorage.installed(context, id) ?: return null
        val manifest = installed.manifest
        IdentifierPolicy.requireTranslationId(manifest.id)
        IdentifierPolicy.requirePackageVersion(manifest.version, "Translation version")
        if (!manifest.gameProjectId.equals(game.projectId, ignoreCase = true)) return null
        return installed
    }

    private fun translationTargetRoot(game: LoveGame): String? {
        if (game.isKristalMod) {
            val id = game.projectId?.takeIf(String::isNotBlank) ?: return null
            require(IdentifierPolicy.isGameProjectId(id)) { "Game project ID is invalid" }
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
            val translated = if (replacement.replacementExpression != null) {
                require(replacement.originalExpression != null) { "Translation source expression is missing" }
                require(text.substring(replacement.startOffset, replacement.endOffset) == replacement.originalExpression) {
                    "Translation source expression changed: ${replacement.entryId}"
                }
                require(validationError(replacement.sourceText, replacement.translatedText) == null) {
                    "Translation changed placeholders or control tags"
                }
                replacement.replacementExpression
            } else {
                validateAndQuote(replacement.sourceText, replacement.translatedText)
            }
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
        IdentifierPolicy.requireLocalProjectId(projectId)
        val project = project(context, projectId) ?: error("Translation project is unavailable")
        val translatedEntries = entries(context, projectId).filter { it.translatedText.isNotBlank() }
        val manifest = JSONObject()
            .put("schemaVersion", 1)
            .put("id", project.id)
            .put("name", project.name)
            .put("author", project.author)
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

    fun exportEditableJson(context: Context, projectId: String): File {
        IdentifierPolicy.requireLocalProjectId(projectId)
        require(project(context, projectId) != null) { "Translation project is unavailable" }
        val document = JSONObject()
        entries(context, projectId).forEach { entry ->
            document.put(
                entry.id,
                JSONObject()
                    .put("source", entry.sourceText)
                    .put("translation", entry.translatedText)
            )
        }
        val directory = File(context.filesDir, "external_translations").apply { mkdirs() }
        val file = File(directory, "$projectId.json")
        file.writeText(document.toString(2), Charsets.UTF_8)
        return file
    }

    fun importEditableJson(context: Context, projectId: String, source: File): Int {
        IdentifierPolicy.requireLocalProjectId(projectId)
        require(source.isFile && source.length() in 1..MAX_EDITABLE_JSON_BYTES) {
            "Editable translation file is invalid"
        }
        require(project(context, projectId) != null) { "Translation project is unavailable" }
        val document = JSONObject(source.readText(Charsets.UTF_8))
        val existing = entries(context, projectId).associateBy { it.id }
        val importedValues = linkedMapOf<String, String>()
        val ids = document.keys()
        while (ids.hasNext()) {
            val id = ids.next()
            IdentifierPolicy.requireTranslationEntryId(id)
            val entry = existing[id] ?: error("Unknown translation entry: $id")
            val item = document.optJSONObject(id)
                ?: error("Translation entry must be an object: $id")
            require(item.opt("source") is String && item.getString("source") == entry.sourceText) {
                "Original text changed for entry: $id"
            }
            require(item.opt("translation") is String) { "Translation must be text for entry: $id" }
            val value = item.getString("translation")
            require(value.isBlank() || validationError(entry.sourceText, value) == null) {
                "Invalid translated text for entry: $id"
            }
            importedValues[id] = value
        }
        val changed = importedValues.filter { (id, value) -> existing.getValue(id).translatedText != value }
        if (changed.isNotEmpty()) {
            TranslationDatabase.get(context).updateTranslations(projectId, changed)
        }
        return changed.size
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
    private fun defaultProjectName(gameTitle: String, languageTag: String): String {
        val locale = Locale.forLanguageTag(languageTag)
        val language = locale.getDisplayName(Locale.getDefault())
            .replaceFirstChar { it.titlecase(Locale.getDefault()) }
            .ifBlank { languageTag }
        return "$gameTitle — $language".take(100)
    }

    private fun ZipInputStream.readBytesLimited(limit: Int): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val count = read(buffer)
            if (count < 0) break
            require(output.size() + count <= limit) { "Translation package entry is too large" }
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }
    private fun sha256(value: String) = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }

    // A percent followed by ordinary prose ("50% in battle", "33% de resistência")
    // is not a printf placeholder. Deliberately exclude the space flag here so
    // natural percentages cannot make a valid translation fail validation.
    private val PRINTF = Regex("%(?:[-+#0]*\\d*(?:\\.\\d+)?[cdiouxXeEfgGaAspq])")
    private val CONTROL_TAG = Regex("\\[([A-Za-z_][A-Za-z0-9_]*)(?::[^]]*)?]")
    private const val MAX_IMPORT_FILE_BYTES = 4 * 1024 * 1024
    private const val MAX_IMPORT_TOTAL_BYTES = 8 * 1024 * 1024
    private const val MAX_EDITABLE_JSON_BYTES = 16L * 1024 * 1024
}
