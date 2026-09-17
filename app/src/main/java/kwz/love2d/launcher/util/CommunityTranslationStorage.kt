package kwz.love2d.launcher.util

import android.content.Context
import kwz.love2d.launcher.model.InstalledCommunityTranslation
import org.json.JSONObject
import java.io.File

object CommunityTranslationStorage {
    private const val ROOT_DIRECTORY = "community_translation_packages"
    private const val INSTALLATION_METADATA = ".installation.json"

    fun rootDirectory(context: Context): File = File(context.filesDir, ROOT_DIRECTORY).apply { mkdirs() }

    fun stagingDirectory(context: Context): File =
        File(context.cacheDir, "community_translation_staging").apply { mkdirs() }

    fun installed(context: Context): List<InstalledCommunityTranslation> =
        rootDirectory(context).listFiles().orEmpty()
            .filter { it.isDirectory && IdentifierPolicy.isTranslationId(it.name) }
            .flatMap { idDirectory ->
                idDirectory.listFiles().orEmpty()
                    .filter { it.isDirectory && IdentifierPolicy.isPackageVersion(it.name) }
            }
            .mapNotNull(::readInstalled)

    fun installed(context: Context, id: String): InstalledCommunityTranslation? =
        if (!IdentifierPolicy.isTranslationId(id)) null else installed(context).filter { it.manifest.id == id }
            .maxWithOrNull { left, right -> VersionUtils.compare(left.manifest.version, right.manifest.version) }

    fun installedForGame(context: Context, projectId: String?): List<InstalledCommunityTranslation> {
        if (projectId.isNullOrBlank() || !IdentifierPolicy.isGameProjectId(projectId)) return emptyList()
        return installed(context).filter { it.manifest.gameProjectId.equals(projectId, ignoreCase = true) }
    }

    fun readInstalled(directory: File): InstalledCommunityTranslation? = runCatching {
        val manifestFile = File(directory, "translation.json")
        val metadataFile = File(directory, INSTALLATION_METADATA)
        require(manifestFile.isFile && metadataFile.isFile)
        val manifest = CommunityTranslationManifestParser.parse(manifestFile.readText(Charsets.UTF_8))
        IdentifierPolicy.requireTranslationId(manifest.id)
        IdentifierPolicy.requirePackageVersion(manifest.version, "Translation version")
        require(manifest.id == directory.parentFile?.name && manifest.version == directory.name)
        val metadata = JSONObject(metadataFile.readText(Charsets.UTF_8))
        val sha256 = metadata.optString("sha256", "").trim()
        require(IdentifierPolicy.isSha256(sha256))
        manifest.files.forEach { file ->
            val payload = safeChild(directory, file.source)
            require(payload.isFile && payload.length() in 1..(8L * 1024 * 1024))
        }
        manifest.textsFile?.let { relativePath ->
            val payload = safeChild(directory, relativePath)
            require(payload.isFile && payload.length() in 2..(16L * 1024 * 1024))
            require(TranslationExtractor.sha256(payload.readBytes()) == manifest.textsSha256)
        }
        InstalledCommunityTranslation(manifest, directory, sha256.lowercase())
    }.getOrNull()

    fun writeInstallationMetadata(directory: File, sha256: String) {
        require(IdentifierPolicy.isSha256(sha256)) { "Translation package checksum is invalid" }
        File(directory, INSTALLATION_METADATA).writeText(
            JSONObject()
                .put("sha256", sha256.lowercase())
                .put("installedAt", System.currentTimeMillis())
                .toString(2),
            Charsets.UTF_8
        )
    }

    fun safeChild(root: File, relativePath: String): File {
        require(PatchManifestParser.isSafeArchivePath(relativePath)) {
            "Translation payload path is unsafe"
        }
        val canonicalRoot = root.canonicalFile
        val child = File(canonicalRoot, relativePath).canonicalFile
        require(child.path.startsWith(canonicalRoot.path + File.separator)) {
            "Translation payload escapes its installation directory"
        }
        return child
    }
}
