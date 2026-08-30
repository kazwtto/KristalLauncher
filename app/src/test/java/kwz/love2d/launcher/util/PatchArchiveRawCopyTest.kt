package kwz.love2d.launcher.util

import org.apache.commons.compress.archivers.zip.ZipArchiveOutputStream
import org.apache.commons.compress.archivers.zip.ZipFile as CommonsZipFile
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import java.nio.file.Files
import java.util.Random
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

class PatchArchiveRawCopyTest {

    @Test
    fun preservesUnchangedCompressedEntryWithoutRecompression() {
        val directory = Files.createTempDirectory("patch-raw-copy-test").toFile()
        val source = directory.resolve("source.love")
        val output = directory.resolve("output.love")
        val payload = ByteArray(512 * 1024).also { Random(42).nextBytes(it) }
        try {
            ZipOutputStream(source.outputStream()).use { zip ->
                zip.putNextEntry(ZipEntry("assets/data.bin"))
                zip.write(payload)
                zip.closeEntry()
            }

            CommonsZipFile.builder().setFile(source).get().use { sourceZip ->
                val entry = requireNotNull(sourceZip.getEntry("assets/data.bin"))
                ZipArchiveOutputStream(output).use { outputZip ->
                    PatchManager.copyRawEntry(sourceZip, entry, outputZip)
                }
            }

            CommonsZipFile.builder().setFile(source).get().use { sourceZip ->
                CommonsZipFile.builder().setFile(output).get().use { outputZip ->
                    val sourceEntry = requireNotNull(sourceZip.getEntry("assets/data.bin"))
                    val outputEntry = outputZip.getEntry("assets/data.bin")
                    assertNotNull(outputEntry)
                    assertEquals(sourceEntry.compressedSize, outputEntry!!.compressedSize)
                    assertArrayEquals(
                        sourceZip.getRawInputStream(sourceEntry).use { it.readBytes() },
                        outputZip.getRawInputStream(outputEntry).use { it.readBytes() }
                    )
                }
            }
            ZipFile(output).use { zip ->
                val entry = requireNotNull(zip.getEntry("assets/data.bin"))
                assertArrayEquals(payload, zip.getInputStream(entry).use { it.readBytes() })
            }
        } finally {
            directory.deleteRecursively()
        }
    }
}
