package kwz.love2d.launcher.util

import android.content.Context
import kwz.love2d.launcher.BuildConfig
import kwz.love2d.launcher.model.KristalRuntimeInstallResult
import kwz.love2d.launcher.model.KristalRuntimeInstallStage
import kwz.love2d.launcher.model.KristalRuntimeRelease
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.ZipFile

object KristalRuntimeInstaller {

    private const val MAX_DOWNLOAD_SIZE = 128L * 1024 * 1024
    private const val MAX_RUNTIME_SIZE = 256L * 1024 * 1024
    private const val BUFFER_SIZE = 64 * 1024
    private const val PROGRESS_UPDATE_INTERVAL_MS = 100L

    fun install(
        context: Context,
        release: KristalRuntimeRelease,
        onStageChanged: (KristalRuntimeInstallStage) -> Unit = {},
        onDownloadProgress: (downloaded: Long, total: Long) -> Unit = { _, _ -> }
    ): KristalRuntimeInstallResult = runCatching {
        require(release.downloadUrl.startsWith("https://")) { "Runtime downloads must use HTTPS" }
        val stagingDirectory = File(
            KristalRuntimeStorage.stagingDirectory(context),
            UUID.randomUUID().toString()
        ).apply { mkdirs() }
        try {
            val downloaded = File(stagingDirectory, "download")
            onStageChanged(KristalRuntimeInstallStage.DOWNLOADING)
            val actualSha256 = download(release.downloadUrl, downloaded, onDownloadProgress)
            release.sha256?.let { expectedSha256 ->
                require(actualSha256.equals(expectedSha256, ignoreCase = true)) {
                    "Runtime checksum does not match the official release"
                }
            }

            onStageChanged(KristalRuntimeInstallStage.VALIDATING)
            val runtimeFile = KristalRuntimeStorage.packageFile(stagingDirectory)
            if (release.assetName.endsWith("-love.zip", ignoreCase = true)) {
                extractLoveRuntime(downloaded, runtimeFile)
                downloaded.delete()
            } else {
                require(downloaded.renameTo(runtimeFile)) { "Downloaded runtime could not be prepared" }
            }
            require(KristalRuntimeStorage.hasRootMainLua(runtimeFile)) {
                "Downloaded runtime does not contain main.lua at its root"
            }
            KristalRuntimeStorage.writeMetadata(
                directory = stagingDirectory,
                tag = release.tag,
                version = release.version,
                assetName = release.assetName,
                sourceUrl = release.downloadUrl
            )

            onStageChanged(KristalRuntimeInstallStage.INSTALLING)
            val destination = KristalRuntimeStorage.destinationDirectory(context, release.tag)
            if (destination.exists()) destination.deleteRecursively()
            require(stagingDirectory.renameTo(destination)) { "Validated runtime could not be installed" }
            val installed = KristalRuntimeStorage.readRuntime(destination)
                ?: run {
                    destination.deleteRecursively()
                    error("Runtime installation could not be verified")
                }
            KristalRuntimeStorage.select(context, installed.tag)
            return KristalRuntimeInstallResult.Success(installed)
        } finally {
            if (stagingDirectory.exists()) stagingDirectory.deleteRecursively()
        }
    }.getOrElse { error ->
        KristalRuntimeInstallResult.Failure(error.message ?: "Runtime download failed")
    }

    private fun download(
        downloadUrl: String,
        outputFile: File,
        onProgress: (downloaded: Long, total: Long) -> Unit
    ): String {
        val connection = URL(downloadUrl).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 45_000
        connection.instanceFollowRedirects = true
        connection.useCaches = false
        connection.setRequestProperty("Accept", "application/octet-stream")
        connection.setRequestProperty("User-Agent", "KristalLauncher/${BuildConfig.VERSION_NAME}")
        try {
            require(connection.responseCode in 200..299) {
                "Runtime download failed with HTTP ${connection.responseCode}"
            }
            require(connection.url.protocol.equals("https", ignoreCase = true)) {
                "Runtime download redirect left HTTPS"
            }
            val declaredSize = connection.contentLengthLong
            require(declaredSize < 0L || declaredSize <= MAX_DOWNLOAD_SIZE) {
                "Runtime download is too large"
            }
            var downloaded = 0L
            var lastProgressUpdate = 0L
            val digest = MessageDigest.getInstance("SHA-256")
            BufferedInputStream(connection.inputStream).use { input ->
                FileOutputStream(outputFile).use { output ->
                    val buffer = ByteArray(BUFFER_SIZE)
                    while (true) {
                        if (Thread.currentThread().isInterrupted) error("Runtime download was cancelled")
                        val read = input.read(buffer)
                        if (read < 0) break
                        downloaded += read
                        require(downloaded <= MAX_DOWNLOAD_SIZE) { "Runtime download is too large" }
                        digest.update(buffer, 0, read)
                        output.write(buffer, 0, read)
                        val now = android.os.SystemClock.elapsedRealtime()
                        if (now - lastProgressUpdate >= PROGRESS_UPDATE_INTERVAL_MS ||
                            (declaredSize > 0L && downloaded >= declaredSize)
                        ) {
                            lastProgressUpdate = now
                            onProgress(downloaded, declaredSize)
                        }
                    }
                    output.fd.sync()
                }
            }
            require(downloaded > 0L) { "Runtime download is empty" }
            return digest.digest().joinToString("") { byte -> "%02x".format(byte) }
        } finally {
            connection.disconnect()
        }
    }

    internal fun extractLoveRuntime(wrapper: File, destination: File) {
        ZipFile(wrapper).use { zip ->
            val candidates = zip.entries().asSequence()
                .filter { !it.isDirectory && it.name.endsWith(".love", ignoreCase = true) }
                .sortedWith(
                    compareBy<java.util.zip.ZipEntry> {
                        if (it.name.substringAfterLast('/').equals("kristal.love", ignoreCase = true)) 0 else 1
                    }.thenBy { it.name.count { character -> character == '/' } }
                )
                .toList()
            val entry = candidates.firstOrNull()
                ?: throw IllegalArgumentException("Runtime archive does not contain kristal.love")
            require(entry.size in 1..MAX_RUNTIME_SIZE) { "Runtime package has an invalid size" }
            zip.getInputStream(entry).use { input ->
                FileOutputStream(destination).use { output ->
                    val buffer = ByteArray(BUFFER_SIZE)
                    var total = 0L
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        total += read
                        require(total <= MAX_RUNTIME_SIZE) { "Runtime package is too large" }
                        output.write(buffer, 0, read)
                    }
                    output.fd.sync()
                }
            }
        }
    }
}
