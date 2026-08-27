package kwz.love2d.launcher.util

import android.content.Context
import android.net.Uri
import kwz.love2d.launcher.BuildConfig
import kwz.love2d.launcher.model.InstalledPatch
import kwz.love2d.launcher.model.PatchInstallResult
import kwz.love2d.launcher.model.PatchOrigin
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.ZipFile

object PatchPackageInstaller {

    private const val MAX_PACKAGE_SIZE = 25L * 1024 * 1024
    private const val MAX_EXTRACTED_SIZE = 75L * 1024 * 1024
    private const val MAX_ENTRY_COUNT = 512
    private const val BUFFER_SIZE = 64 * 1024
    private val supportedCapabilities = setOf(
        "staged_package",
        "inject_files",
        "edit_lua",
        "runtime_hook"
    )

    fun installFromUri(context: Context, uri: Uri): PatchInstallResult {
        return runCatching {
            val input = context.contentResolver.openInputStream(uri)
                ?: return PatchInstallResult.Failure("The selected file could not be opened")
            input.use { install(context, it, PatchOrigin.IMPORTED, null) }
        }.getOrElse { PatchInstallResult.Failure(it.message ?: "Patch import failed") }
    }

    fun installFromCatalog(
        context: Context,
        packageUrl: String,
        expectedSha256: String,
        expectedId: String,
        expectedVersion: String
    ): PatchInstallResult {
        return runCatching {
            require(packageUrl.startsWith("https://")) { "Patch downloads must use HTTPS" }
            val connection = URL(packageUrl).openConnection() as HttpURLConnection
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.instanceFollowRedirects = true
            connection.setRequestProperty("Accept", "application/octet-stream")
            connection.setRequestProperty("User-Agent", "KristalLauncher/${BuildConfig.VERSION_NAME}")
            try {
                val responseCode = connection.responseCode
                require(responseCode in 200..299) { "Patch download failed with HTTP $responseCode" }
                require(connection.url.protocol.equals("https", ignoreCase = true)) {
                    "Patch redirect left HTTPS"
                }
                val declaredLength = connection.contentLengthLong
                require(declaredLength < 0 || declaredLength <= MAX_PACKAGE_SIZE) { "Patch package is too large" }
                BufferedInputStream(connection.inputStream).use {
                    install(context, it, PatchOrigin.OFFICIAL, expectedSha256, expectedId, expectedVersion)
                }
            } finally {
                connection.disconnect()
            }
        }.getOrElse { PatchInstallResult.Failure(it.message ?: "Patch download failed") }
    }

    private fun install(
        context: Context,
        source: InputStream,
        origin: PatchOrigin,
        expectedSha256: String?,
        expectedId: String? = null,
        expectedVersion: String? = null
    ): PatchInstallResult {
        val stagingRoot = File(PatchStorage.stagingDirectory(context), UUID.randomUUID().toString())
        val extractionRoot = File(stagingRoot, "content")
        val packageFile = File(stagingRoot, "package.klpatch")

        return try {
            extractionRoot.mkdirs()
            val actualSha256 = copyWithSha256AndLimit(source, packageFile, MAX_PACKAGE_SIZE)
            if (!expectedSha256.isNullOrBlank()) {
                require(actualSha256.equals(expectedSha256, ignoreCase = true)) {
                    "The downloaded patch checksum does not match the catalog"
                }
            }

            val manifest = extractAndValidate(packageFile, extractionRoot)
            if (expectedId != null) require(manifest.id == expectedId) { "The package ID does not match the catalog" }
            if (expectedVersion != null) {
                require(manifest.version == expectedVersion) { "The package version does not match the catalog" }
            }
            manifest.minimumLauncherVersion?.let { minimumVersion ->
                require(!VersionUtils.isNewer(minimumVersion, BuildConfig.VERSION_NAME)) {
                    "This patch requires Kristal Launcher $minimumVersion or newer"
                }
            }
            require(manifest.capabilities.all { it in supportedCapabilities }) {
                "The patch requests an unsupported capability"
            }
            validateCapabilities(manifest.capabilities, manifest.operations.map { it.type })

            val patchParent = File(PatchStorage.rootDirectory(context), manifest.id).apply { mkdirs() }
            val destination = File(patchParent, manifest.version).canonicalFile
            require(destination.parentFile == patchParent.canonicalFile) {
                "The patch version resolves outside its installation directory"
            }
            if (destination.exists()) {
                return PatchInstallResult.Failure("This patch version is already installed")
            }

            PatchStorage.writeInstallationMetadata(extractionRoot, origin, actualSha256)
            require(extractionRoot.renameTo(destination)) { "The validated patch could not be installed" }
            patchParent.listFiles().orEmpty()
                .filter { it.isDirectory && it != destination }
                .forEach(File::deleteRecursively)

            PatchInstallResult.Success(
                InstalledPatch(
                    manifest = manifest,
                    directory = destination,
                    origin = origin,
                    sha256 = actualSha256
                )
            )
        } catch (error: Exception) {
            PatchInstallResult.Failure(error.message ?: "Invalid patch package")
        } finally {
            if (stagingRoot.exists()) stagingRoot.deleteRecursively()
        }
    }

    private fun extractAndValidate(packageFile: File, destination: File) = ZipFile(packageFile).use { zip ->
        val entries = zip.entries().toList()
        require(entries.size <= MAX_ENTRY_COUNT) { "Patch package contains too many files" }
        val normalizedNames = mutableSetOf<String>()
        entries.forEach { entry ->
            val normalized = entry.name.trimEnd('/').lowercase(java.util.Locale.ROOT)
            require(normalizedNames.add(normalized)) { "Patch package contains duplicate file: ${entry.name}" }
        }

        val manifestEntry = entries.find { it.name == "patch.json" && !it.isDirectory }
            ?: throw IllegalArgumentException("Patch package is missing patch.json")
        require(manifestEntry.size in 1..(256 * 1024L)) { "Patch manifest has an invalid size" }
        val manifestJson = zip.getInputStream(manifestEntry).bufferedReader(Charsets.UTF_8).use { it.readText() }
        val manifest = PatchManifestParser.parse(manifestJson)

        var totalExtracted = 0L
        val destinationRoot = destination.canonicalFile
        entries.forEach { entry ->
            require(PatchManifestParser.isSafeArchivePath(entry.name)) { "Unsafe file path in patch package" }
            if (entry.isDirectory) return@forEach

            val outputFile = File(destinationRoot, entry.name).canonicalFile
            require(outputFile.path.startsWith(destinationRoot.path + File.separator)) {
                "Patch file escapes the installation directory"
            }
            outputFile.parentFile?.mkdirs()
            zip.getInputStream(entry).use { input ->
                FileOutputStream(outputFile).use { output ->
                    val buffer = ByteArray(BUFFER_SIZE)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        totalExtracted += read
                        require(totalExtracted <= MAX_EXTRACTED_SIZE) { "Patch expands beyond the allowed size" }
                        output.write(buffer, 0, read)
                    }
                }
            }
        }

        manifest.operations.mapNotNull { it.source }.forEach { sourcePath ->
            val sourceFile = File(destinationRoot, sourcePath).canonicalFile
            require(sourceFile.path.startsWith(destinationRoot.path + File.separator) && sourceFile.isFile) {
                "Patch operation source is missing: $sourcePath"
            }
        }
        manifest
    }

    private fun validateCapabilities(capabilities: List<String>, operationTypes: List<String>) {
        if ("inject" in operationTypes) {
            require("inject_files" in capabilities) { "inject operations require the inject_files capability" }
        }
        if (operationTypes.any { it == "append_text" || it == "replace_text" }) {
            require("edit_lua" in capabilities) { "Text operations require the edit_lua capability" }
        }
    }

    private fun copyWithSha256AndLimit(input: InputStream, outputFile: File, limit: Long): String {
        val digest = MessageDigest.getInstance("SHA-256")
        var total = 0L
        FileOutputStream(outputFile).use { output ->
            val buffer = ByteArray(BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
                require(total <= limit) { "Patch package is too large" }
                digest.update(buffer, 0, read)
                output.write(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { byte -> "%02x".format(byte) }
    }
}
