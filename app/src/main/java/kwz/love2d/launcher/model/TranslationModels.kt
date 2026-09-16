package kwz.love2d.launcher.model

import java.io.File

data class TranslationProject(
    val id: String,
    val gameStableId: String,
    val gameProjectId: String?,
    val gameTitle: String,
    val gameVersion: String?,
    val sourceFingerprint: String,
    val sourceRoot: String,
    val targetRoot: String,
    val sourceLanguage: String,
    val targetLanguage: String,
    val createdAt: Long,
    val updatedAt: Long,
    val totalEntries: Int = 0,
    val translatedEntries: Int = 0
)

data class TranslationEntry(
    val projectId: String,
    val id: String,
    val sourceText: String,
    val translatedText: String,
    val filePath: String,
    val fileHash: String,
    val startOffset: Int,
    val endOffset: Int,
    val line: Int,
    val kind: String,
    val context: String
)

data class ExtractedTranslation(
    val fingerprint: String,
    val sourceRoot: String,
    val targetRoot: String,
    val entries: List<TranslationEntry>
)

data class TranslationReplacement(
    val entryId: String,
    val fileHash: String,
    val startOffset: Int,
    val endOffset: Int,
    val sourceText: String,
    val translatedText: String
)

data class TranslationFileReplacement(
    val sourceSha256: String,
    val translatedSha256: String,
    val file: File
)

data class TranslationPlan(
    val projectId: String,
    val targetLanguage: String,
    val sourceFingerprint: String,
    val replacementsByPath: Map<String, List<TranslationReplacement>> = emptyMap(),
    val filesByPath: Map<String, TranslationFileReplacement> = emptyMap()
)

data class CommunityTranslationFile(
    val source: String,
    val target: String,
    val sourceSha256: String,
    val translatedSha256: String
)

data class CommunityTranslationManifest(
    val schemaVersion: Int,
    val id: String,
    val version: String,
    val name: LocalizedText,
    val description: LocalizedText,
    val author: String,
    val gameProjectId: String,
    val gameVersion: String,
    val sourceLanguage: String,
    val targetLanguage: String,
    val minimumLauncherVersion: String?,
    val files: List<CommunityTranslationFile>
)

data class CatalogTranslation(
    val manifest: CommunityTranslationManifest,
    val packageUrl: String,
    val sha256: String
)

data class InstalledCommunityTranslation(
    val manifest: CommunityTranslationManifest,
    val directory: File,
    val sha256: String
)

sealed class CommunityTranslationInstallResult {
    data class Success(val translation: InstalledCommunityTranslation) : CommunityTranslationInstallResult()
    data class Failure(val reason: String) : CommunityTranslationInstallResult()
}
