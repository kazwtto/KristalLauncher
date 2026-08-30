package kwz.love2d.launcher.util

import androidx.core.content.FileProvider
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kwz.love2d.launcher.BuildConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

@RunWith(AndroidJUnit4::class)
class GameArchiveDescriptorTest {

    @Test
    fun readsThroughContentDescriptorWithoutCreatingArchiveCopies() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val stagedDirectory = File(context.filesDir, "staged").apply { mkdirs() }
        val archiveFile = File(stagedDirectory, "descriptor-test.love")
        val archiveCache = File(context.cacheDir, "game_archive_index")
        archiveFile.delete()
        archiveCache.deleteRecursively()

        try {
            ZipOutputStream(archiveFile.outputStream()).use { zip ->
                zip.putNextEntry(ZipEntry("main.lua"))
                zip.write("return true".toByteArray())
                zip.closeEntry()
                zip.putNextEntry(ZipEntry("mods/test/mod.json"))
                zip.write("{\"name\":\"Descriptor Game\"}".toByteArray())
                zip.closeEntry()
            }
            val uri = FileProvider.getUriForFile(
                context,
                "${BuildConfig.APPLICATION_ID}.fileprovider",
                archiveFile
            )

            GameArchive.open(context, uri, archiveFile.name)
                .use { archive ->
                    assertEquals(GameArchive.AccessMode.DIRECT_DESCRIPTOR, archive.accessMode)
                    assertEquals(GameArchive.Backend.PLATFORM_ZIP_FILE, archive.backend)
                    val metadataEntry = archive.entries().single { it.name == "mods/test/mod.json" }
                    assertEquals(
                        "{\"name\":\"Descriptor Game\"}",
                        archive.open(metadataEntry).bufferedReader().use { it.readText() }
                    )
                    assertFalse("The reader created a top-level archive cache", archiveCache.exists())
                }
        } finally {
            assertTrue(archiveFile.delete() || !archiveFile.exists())
        }
    }
}
