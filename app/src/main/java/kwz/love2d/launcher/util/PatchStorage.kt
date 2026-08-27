package kwz.love2d.launcher.util

import android.content.Context
import android.util.AtomicFile
import kwz.love2d.launcher.model.InstalledPatch
import kwz.love2d.launcher.model.PatchOrigin
import org.json.JSONObject
import java.io.File

object PatchStorage {

    private const val PATCHES_DIRECTORY = "patches"
    private const val INSTALLATION_METADATA = ".installation.json"

    fun rootDirectory(context: Context): File = File(context.filesDir, PATCHES_DIRECTORY).apply { mkdirs() }

    fun stagingDirectory(context: Context): File = File(rootDirectory(context), ".installing").apply { mkdirs() }

    fun getInstalledPatches(context: Context): List<InstalledPatch> {
        val root = rootDirectory(context)
        return root.listFiles()
            .orEmpty()
            .asSequence()
            .filter { it.isDirectory && !it.name.startsWith('.') }
            .mapNotNull { patchDirectory -> newestInstalledVersion(patchDirectory) }
            .sortedBy { it.manifest.id }
            .toList()
    }

    fun findInstalledPatch(context: Context, id: String): InstalledPatch? {
        return getInstalledPatches(context).find { it.manifest.id == id }
    }

    fun uninstall(context: Context, id: String): Boolean {
        if (!PatchManifestParser.isSafeArchivePath(id)) return false
        val root = rootDirectory(context).canonicalFile
        val target = File(root, id).canonicalFile
        if (target.parentFile != root || !target.exists()) return false
        return target.deleteRecursively()
    }

    fun writeInstallationMetadata(
        directory: File,
        origin: PatchOrigin,
        sha256: String
    ) {
        val metadata = JSONObject()
            .put("origin", origin.name)
            .put("sha256", sha256)
        val atomicFile = AtomicFile(File(directory, INSTALLATION_METADATA))
        val output = atomicFile.startWrite()
        try {
            output.write(metadata.toString().toByteArray(Charsets.UTF_8))
            output.fd.sync()
            atomicFile.finishWrite(output)
        } catch (error: Throwable) {
            atomicFile.failWrite(output)
            throw error
        }
    }

    private fun newestInstalledVersion(patchDirectory: File): InstalledPatch? {
        return patchDirectory.listFiles()
            .orEmpty()
            .asSequence()
            .filter { it.isDirectory }
            .mapNotNull { parseInstalledVersion(it) }
            .maxWithOrNull { left, right ->
                VersionUtils.compare(left.manifest.version, right.manifest.version)
            }
    }

    private fun parseInstalledVersion(directory: File): InstalledPatch? {
        return runCatching {
            val manifestFile = File(directory, "patch.json")
            if (!manifestFile.isFile || manifestFile.length() > 256 * 1024L) return null
            val manifest = PatchManifestParser.parse(manifestFile.readText(Charsets.UTF_8))
            if (manifest.id != directory.parentFile?.name || manifest.version != directory.name) return null

            val metadataFile = File(directory, INSTALLATION_METADATA)
            val metadata = if (metadataFile.isFile) JSONObject(metadataFile.readText(Charsets.UTF_8)) else JSONObject()
            val origin = runCatching {
                PatchOrigin.valueOf(metadata.optString("origin", PatchOrigin.IMPORTED.name))
            }.getOrDefault(PatchOrigin.IMPORTED)

            InstalledPatch(
                manifest = manifest,
                directory = directory,
                origin = origin,
                sha256 = metadata.optString("sha256", "").takeIf { it.isNotBlank() }
            )
        }.getOrNull()
    }
}
