package kwz.love2d.launcher.model

import android.content.Context
import java.io.File
import java.util.Locale

enum class PatchOrigin {
    BUILT_IN,
    OFFICIAL,
    IMPORTED
}

enum class PatchTrust {
    BUILT_IN,
    VERIFIED,
    UNVERIFIED
}

data class LocalizedText(
    val values: Map<String, String>
) {
    fun resolve(context: Context): String {
        val locale = context.resources.configuration.locales[0] ?: Locale.ENGLISH
        val languageTag = locale.toLanguageTag()
        return values[languageTag]
            ?: values[locale.language]
            ?: values["en"]
            ?: values["pt-BR"]
            ?: values.values.firstOrNull()
            ?: ""
    }
}

data class PatchOperation(
    val type: String,
    val source: String? = null,
    val target: String,
    val find: String? = null,
    val replace: String? = null,
    val replaceExisting: Boolean = false,
    val required: Boolean = true
)

data class PatchManifest(
    val schemaVersion: Int,
    val id: String,
    val version: String,
    val name: LocalizedText,
    val description: LocalizedText,
    val useCases: List<LocalizedText>,
    val author: String,
    val category: String,
    val minimumLauncherVersion: String?,
    val capabilities: List<String>,
    val dependencies: List<String>,
    val conflicts: List<String>,
    val priority: Int,
    val operations: List<PatchOperation>
)

data class InstalledPatch(
    val manifest: PatchManifest,
    val directory: File,
    val origin: PatchOrigin,
    val sha256: String?
)

data class CatalogPatch(
    val manifest: PatchManifest,
    val packageUrl: String,
    val sha256: String,
    val releaseNotes: LocalizedText?
)

data class PatchDisplayItem(
    val id: String,
    val version: String,
    val name: String,
    val description: String,
    val useCases: List<String>,
    val author: String,
    val category: String,
    val origin: PatchOrigin,
    val trust: PatchTrust,
    val capabilities: List<String>,
    val dependencies: List<String>,
    val conflicts: List<String>,
    val installed: Boolean,
    val enabled: Boolean,
    val updateAvailable: Boolean = false,
    val catalogPatch: CatalogPatch? = null,
    val installedPatch: InstalledPatch? = null
)

sealed class PatchInstallResult {
    data class Success(val patch: InstalledPatch) : PatchInstallResult()
    data class Failure(val reason: String) : PatchInstallResult()
}

sealed class PatchApplicationResult {
    data class Success(val appliedPatchIds: List<String>) : PatchApplicationResult()
    data class Failure(val reason: String, val cause: Throwable? = null) : PatchApplicationResult()
}
