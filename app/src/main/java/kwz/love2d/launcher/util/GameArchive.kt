package kwz.love2d.launcher.util

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.os.ParcelFileDescriptor
import org.apache.commons.compress.archivers.zip.ZipArchiveEntry
import org.apache.commons.compress.archivers.zip.ZipFile as CommonsZipFile
import java.io.Closeable
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.channels.SeekableByteChannel
import java.util.zip.ZipEntry
import java.util.zip.ZipFile as PlatformZipFile

/**
 * Random-access reader for .love, .zip, and fused LÖVE .exe packages.
 *
 * Android's native ZipFile is preferred because it indexes the central directory substantially
 * faster than a pure Kotlin/Java reader. Content URIs are opened through their existing Linux file
 * descriptor, without copying the archive. Apache Commons Compress remains as the compatibility
 * backend for providers or self-extracting archives rejected by the platform reader.
 */
internal class GameArchive private constructor(
    private val platformZipFile: PlatformZipFile?,
    private val portableZipFile: CommonsZipFile?,
    private val ownedResource: Closeable?,
    internal val accessMode: AccessMode,
    internal val backend: Backend
) : Closeable {

    internal enum class AccessMode {
        DIRECT_FILE,
        DIRECT_DESCRIPTOR
    }

    internal enum class Backend {
        PLATFORM_ZIP_FILE,
        COMMONS_COMPRESS
    }

    data class Entry internal constructor(
        val name: String,
        val isDirectory: Boolean,
        val size: Long,
        internal val platformSource: ZipEntry? = null,
        internal val portableSource: ZipArchiveEntry? = null
    )

    fun entries(maximumCount: Int = Int.MAX_VALUE): List<Entry> = buildList {
        require(maximumCount >= 0) { "Maximum entry count must not be negative" }
        platformZipFile?.entries()?.let { entries ->
            while (entries.hasMoreElements()) {
                require(size < maximumCount) { "Game archive contains too many entries" }
                val source = entries.nextElement()
                add(
                    Entry(
                        name = source.name,
                        isDirectory = source.isDirectory,
                        size = source.size,
                        platformSource = source
                    )
                )
            }
            return@buildList
        }

        val entries = requireNotNull(portableZipFile).entries
        while (entries.hasMoreElements()) {
            require(size < maximumCount) { "Game archive contains too many entries" }
            val source = entries.nextElement()
            add(
                Entry(
                    name = source.name,
                    isDirectory = source.isDirectory,
                    size = source.size,
                    portableSource = source
                )
            )
        }
    }

    fun open(entry: Entry): InputStream {
        entry.platformSource?.let { source ->
            return requireNotNull(platformZipFile).getInputStream(source)
        }
        val source = requireNotNull(entry.portableSource)
        val zipFile = requireNotNull(portableZipFile)
        require(zipFile.canReadEntryData(source)) {
            "Unsupported ZIP entry compression or encryption: ${entry.name}"
        }
        return zipFile.getInputStream(source)
    }

    override fun close() {
        try {
            platformZipFile?.close() ?: portableZipFile?.close()
        } finally {
            runCatching { ownedResource?.close() }
        }
    }

    companion object {
        fun open(context: Context, uri: Uri, fileName: String): GameArchive {
            if (uri.scheme == ContentResolver.SCHEME_FILE) {
                return open(File(requireNotNull(uri.path) { "File URI has no path" }))
            }

            openWithPlatformDescriptor(context, uri)?.let { return it }
            return openWithPortableDescriptor(context, uri, fileName)
        }

        fun open(file: File): GameArchive {
            try {
                return GameArchive(
                    platformZipFile = PlatformZipFile(file),
                    portableZipFile = null,
                    ownedResource = null,
                    accessMode = AccessMode.DIRECT_FILE,
                    backend = Backend.PLATFORM_ZIP_FILE
                )
            } catch (_: Exception) {
                // Commons Compress supports ZIP preambles and edge cases rejected by ZipFile.
            }

            val stream = FileInputStream(file)
            return try {
                verifySeekable(stream.channel)
                GameArchive(
                    platformZipFile = null,
                    portableZipFile = openPortableZip(stream.channel),
                    ownedResource = stream,
                    accessMode = AccessMode.DIRECT_FILE,
                    backend = Backend.COMMONS_COMPRESS
                )
            } catch (error: Exception) {
                runCatching { stream.close() }
                throw error
            }
        }

        private fun openWithPlatformDescriptor(context: Context, uri: Uri): GameArchive? {
            val descriptor = context.contentResolver.openFileDescriptor(uri, "r") ?: return null
            return try {
                val descriptorPath = File("/proc/self/fd/${descriptor.fd}")
                GameArchive(
                    platformZipFile = PlatformZipFile(descriptorPath),
                    portableZipFile = null,
                    ownedResource = null,
                    accessMode = AccessMode.DIRECT_DESCRIPTOR,
                    backend = Backend.PLATFORM_ZIP_FILE
                )
            } catch (_: Exception) {
                null
            } finally {
                runCatching { descriptor.close() }
            }
        }

        private fun openWithPortableDescriptor(
            context: Context,
            uri: Uri,
            fileName: String
        ): GameArchive {
            val stream = context.contentResolver.openFileDescriptor(uri, "r")
                ?.let(ParcelFileDescriptor::AutoCloseInputStream)
                ?: throw IllegalArgumentException("Unable to open a file descriptor for $fileName")
            return try {
                verifySeekable(stream.channel)
                GameArchive(
                    platformZipFile = null,
                    portableZipFile = openPortableZip(stream.channel),
                    ownedResource = stream,
                    accessMode = AccessMode.DIRECT_DESCRIPTOR,
                    backend = Backend.COMMONS_COMPRESS
                )
            } catch (error: Exception) {
                runCatching { stream.close() }
                throw error
            }
        }

        @Suppress("DEPRECATION")
        private fun openPortableZip(channel: SeekableByteChannel): CommonsZipFile =
            CommonsZipFile(channel)

        private fun verifySeekable(channel: SeekableByteChannel) {
            val originalPosition = channel.position()
            val size = channel.size()
            val probePosition = if (size > 0L) size - 1L else 0L
            channel.position(probePosition)
            if (size > 0L) {
                require(channel.read(ByteBuffer.allocate(1)) == 1) {
                    "The selected document provider does not expose random access"
                }
            }
            channel.position(originalPosition)
        }
    }
}
