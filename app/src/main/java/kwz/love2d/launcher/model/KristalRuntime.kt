package kwz.love2d.launcher.model

import java.io.File

data class KristalRuntimeRelease(
    val tag: String,
    val version: String,
    val assetName: String,
    val downloadUrl: String,
    val sizeBytes: Long,
    val sha256: String?,
    val publishedAt: String?,
    val prerelease: Boolean
)

data class InstalledKristalRuntime(
    val tag: String,
    val version: String,
    val assetName: String,
    val sourceUrl: String,
    val installedAt: Long,
    val file: File
)

data class KristalRuntimeDisplayItem(
    val tag: String,
    val version: String,
    val release: KristalRuntimeRelease?,
    val installed: InstalledKristalRuntime?,
    val selected: Boolean,
    val recommended: Boolean
)

enum class KristalRuntimeInstallStage {
    DOWNLOADING,
    VALIDATING,
    INSTALLING
}

sealed class KristalRuntimeCatalogResult {
    data class Success(
        val releases: List<KristalRuntimeRelease>,
        val fromCache: Boolean
    ) : KristalRuntimeCatalogResult()

    data class Failure(val reason: String) : KristalRuntimeCatalogResult()
}

sealed class KristalRuntimeInstallResult {
    data class Success(val runtime: InstalledKristalRuntime) : KristalRuntimeInstallResult()
    data class Failure(val reason: String) : KristalRuntimeInstallResult()
}
