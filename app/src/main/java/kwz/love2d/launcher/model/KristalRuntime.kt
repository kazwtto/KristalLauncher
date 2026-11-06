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
) {
    val channel: RuntimeChannel
        get() = RuntimeChannel.of(tag, assetName, prerelease)
}

/** Which kind of Kristal build a runtime is. */
enum class RuntimeChannel {
    STABLE,
    PRERELEASE,
    DEV;

    companion object {
        fun of(tag: String, assetName: String, prerelease: Boolean): RuntimeChannel {
            val text = "$tag $assetName".lowercase()
            return when {
                "dev" in text || "nightly" in text -> DEV
                prerelease || "beta" in text || "alpha" in text -> PRERELEASE
                else -> STABLE
            }
        }
    }
}

/** What the runtime list shows. ALL keeps every build visible. */
enum class RuntimeChannelFilter {
    ALL,
    STABLE,
    PRERELEASE,
    DEV;

    fun accepts(channel: RuntimeChannel): Boolean = when (this) {
        ALL -> true
        STABLE -> channel == RuntimeChannel.STABLE
        PRERELEASE -> channel == RuntimeChannel.PRERELEASE
        DEV -> channel == RuntimeChannel.DEV
    }
}

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
) {
    val channel: RuntimeChannel
        get() = release?.channel ?: RuntimeChannel.of(tag, "", false)
}

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
