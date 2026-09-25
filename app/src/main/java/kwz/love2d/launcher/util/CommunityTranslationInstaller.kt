package kwz.love2d.launcher.util

import android.content.Context
import kwz.love2d.launcher.BuildConfig
import kwz.love2d.launcher.model.CatalogTranslation
import kwz.love2d.launcher.model.CommunityTranslationInstallResult
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.ZipFile

enum class CommunityTranslationInstallStage {
    DOWNLOADING,
    VALIDATING,
    INSTALLING
}

object CommunityTranslationInstaller {
    private const val MAX_PACKAGE_BYTES = 16L * 1024 * 1024
    private const val MAX_EXTRACTED_BYTES = 32L * 1024 * 1024
    private const val MAX_ENTRY_COUNT = 512
    private const val BUFFER_SIZE = 64 * 1024

    fun install(
        context: Context,
        catalogItem: CatalogTranslation,
        onStageChanged: (CommunityTranslationInstallStage) -> Unit = {},
        onProgress: (downloaded: Long, total: Long) -> Unit = { _, _ -> }
    ): CommunityTranslationInstallResult = runCatching {
        IdentifierPolicy.requireTranslationId(catalogItem.manifest.id, "Catalog translation ID")
        IdentifierPolicy.requirePackageVersion(catalogItem.manifest.version, "Catalog translation version")
        require(IdentifierPolicy.isSha256(catalogItem.sha256)) { "Catalog translation checksum is invalid" }
        require(catalogItem.packageUrl.startsWith("https://")) { "Translation downloads must use HTTPS" }
        onStageChanged(CommunityTranslationInstallStage.DOWNLOADING)
        val stagingRoot = File(
            CommunityTranslationStorage.stagingDirectory(context),
            UUID.randomUUID().toString()
        ).apply { mkdirs() }
        try {
            val packageFile = File(stagingRoot, "package.kllang")
            val actualSha256 = download(catalogItem.packageUrl, packageFile, onProgress)
            require(actualSha256 == catalogItem.sha256) { "Translation checksum does not match the catalog" }
            onStageChanged(CommunityTranslationInstallStage.VALIDATING)
            val content = File(stagingRoot, "content").apply { mkdirs() }
            val manifest = extractAndValidate(packageFile, content)
            IdentifierPolicy.requireTranslationId(manifest.id)
            IdentifierPolicy.requirePackageVersion(manifest.version, "Translation version")
            require(manifest.id == catalogItem.manifest.id && manifest.version == catalogItem.manifest.version) {
                "Translation package identity does not match the catalog"
            }
            require(manifest.gameProjectId == catalogItem.manifest.gameProjectId) {
                "Translation package targets a different game"
            }
            manifest.minimumLauncherVersion?.let { minimum ->
                require(!VersionUtils.isNewer(minimum, BuildConfig.VERSION_NAME)) {
                    "Translation requires a newer Kristal Launcher version"
                }
            }
            CommunityTranslationStorage.writeInstallationMetadata(content, actualSha256)

            onStageChanged(CommunityTranslationInstallStage.INSTALLING)
            val translationsRoot = CommunityTranslationStorage.rootDirectory(context).canonicalFile
            val idDirectory = File(translationsRoot, manifest.id).canonicalFile
            require(idDirectory.parentFile == translationsRoot) { "Translation ID resolves outside translation storage" }
            idDirectory.mkdirs()
            val destination = File(idDirectory, manifest.version).canonicalFile
            require(destination.parentFile == idDirectory) { "Invalid translation installation path" }
            if (destination.exists()) destination.deleteRecursively()
            require(content.renameTo(destination)) { "Translation package could not be installed" }
            val installed = CommunityTranslationStorage.readInstalled(destination)
                ?: error("Installed translation could not be verified")
            idDirectory.listFiles().orEmpty()
                .filter { it.isDirectory && it.canonicalFile != destination }
                .forEach(File::deleteRecursively)
            CommunityTranslationInstallResult.Success(installed)
        } finally {
            stagingRoot.deleteRecursively()
        }
    }.getOrElse { CommunityTranslationInstallResult.Failure(it.message ?: "Translation installation failed") }

    private fun download(
        url: String,
        destination: File,
        onProgress: (downloaded: Long, total: Long) -> Unit
    ): String {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 30_000
        connection.instanceFollowRedirects = true
        connection.useCaches = false
        connection.setRequestProperty("Accept", "application/octet-stream")
        connection.setRequestProperty("User-Agent", "KristalLauncher/${BuildConfig.VERSION_NAME}")
        return try {
            require(connection.responseCode in 200..299) {
                "Translation download failed with HTTP ${connection.responseCode}"
            }
            require(connection.url.protocol.equals("https", ignoreCase = true)) {
                "Translation download redirect left HTTPS"
            }
            val declaredSize = connection.contentLengthLong
            require(declaredSize < 0 || declaredSize <= MAX_PACKAGE_BYTES) { "Translation package is too large" }
            val digest = MessageDigest.getInstance("SHA-256")
            var downloaded = 0L
            BufferedInputStream(connection.inputStream).use { input ->
                FileOutputStream(destination).use { output ->
                    val buffer = ByteArray(BUFFER_SIZE)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        downloaded += read
                        require(downloaded <= MAX_PACKAGE_BYTES) { "Translation package is too large" }
                        digest.update(buffer, 0, read)
                        output.write(buffer, 0, read)
                        onProgress(downloaded, declaredSize)
                    }
                }
            }
            require(downloaded > 0) { "Translation download is empty" }
            digest.digest().joinToString("") { "%02x".format(it) }
        } finally {
            connection.disconnect()
        }
    }

    private fun extractAndValidate(packageFile: File, destination: File) = ZipFile(packageFile).use { zip ->
        val entries = zip.entries().toList()
        require(entries.size <= MAX_ENTRY_COUNT) { "Translation package contains too many files" }
        val names = mutableSetOf<String>()
        entries.forEach { entry ->
            require(PatchManifestParser.isSafeArchivePath(entry.name)) { "Unsafe translation package path" }
            require(names.add(entry.name.trimEnd('/').lowercase())) { "Duplicate translation package path" }
        }
        val manifestEntry = entries.firstOrNull { it.name == "translation.json" && !it.isDirectory }
            ?: error("Translation package is missing translation.json")
        require(manifestEntry.size in 1..(256 * 1024L)) { "Translation manifest has an invalid size" }
        val manifestJson = zip.getInputStream(manifestEntry).bufferedReader(Charsets.UTF_8).use { it.readText() }
        val manifest = CommunityTranslationManifestParser.parse(manifestJson)
        val allowedFiles = manifest.files.mapTo(mutableSetOf("translation.json")) { it.source }
        manifest.textsFile?.let(allowedFiles::add)
        require(entries.filterNot { it.isDirectory }.all { it.name in allowedFiles }) {
            "Translation package contains undeclared files"
        }

        var extractedBytes = 0L
        entries.filterNot { it.isDirectory }.forEach { entry ->
            val output = CommunityTranslationStorage.safeChild(destination, entry.name)
            output.parentFile?.mkdirs()
            zip.getInputStream(entry).use { input ->
                FileOutputStream(output).use { stream ->
                    val buffer = ByteArray(BUFFER_SIZE)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        extractedBytes += read
                        require(extractedBytes <= MAX_EXTRACTED_BYTES) { "Translation package expands too far" }
                        stream.write(buffer, 0, read)
                    }
                }
            }
        }
        manifest.files.forEach { file ->
            val payload = CommunityTranslationStorage.safeChild(destination, file.source)
            require(payload.isFile && TranslationExtractor.sha256(payload.readBytes()) == file.translatedSha256) {
                "Translation payload checksum is invalid: ${file.target}"
            }
            if (file.target.endsWith(".json", ignoreCase = true)) {
                require(JSONObject(payload.readText(Charsets.UTF_8)).length() > 0) {
                    "Translation JSON is empty: ${file.target}"
                }
            }
        }
        manifest.textsFile?.let { relativePath ->
            val payload = CommunityTranslationStorage.safeChild(destination, relativePath)
            require(payload.isFile && payload.length() in 2..(16L * 1024 * 1024)) {
                "Translation text payload is invalid"
            }
            require(TranslationExtractor.sha256(payload.readBytes()) == manifest.textsSha256) {
                "Translation text payload checksum is invalid"
            }
            CommunityTranslationTextParser.parse(payload.readText(Charsets.UTF_8))
        }
        manifest
    }
}
