package kwz.love2d.launcher.util

import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File

class GameArchivePerformanceTest {

    @Test
    fun indexesAvailableRealPackagesWithinColdScanBudget() {
        val repositoryRoot = findRepositoryRoot()
        val archives = listOf("frostveil.love", "Godhome.love")
            .map(repositoryRoot::resolve)
            .filter(File::isFile)
        assumeTrue("No local real-game fixtures are available", archives.isNotEmpty())

        archives.forEach { archiveFile ->
            val startedAt = System.nanoTime()
            val parsed = requireNotNull(LoveMetadataParser.inspectArchive(archiveFile)) {
                "Metadata was not returned for ${archiveFile.name}"
            }
            val elapsedNanos = System.nanoTime() - startedAt
            val elapsedMillis = elapsedNanos / 1_000_000.0
            assertTrue("Title was empty for ${archiveFile.name}", parsed.title.isNotBlank())
            assertTrue(
                "Icon was not returned for ${archiveFile.name}",
                parsed.iconBytes?.isNotEmpty() == true
            )
            if (archiveFile.name.equals("frostveil.love", ignoreCase = true)) {
                assertTrue("Frostveil JSONC name was not parsed", parsed.title == "Frostveil")
                assertTrue("Frostveil subtitle was not parsed", parsed.subtitle == "Weird Route")
                assertTrue("Frostveil version was not parsed", parsed.version == "v1.3.1")
                assertTrue("Frostveil engine tag was not parsed", parsed.engineVersion == "v0.10.0-dev")
            }
            assertTrue(
                "Cold metadata scan exceeded 2 seconds for ${archiveFile.name}: $elapsedMillis ms",
                elapsedMillis < COLD_SCAN_BUDGET_MILLIS
            )
            println(
                "GAME_ARCHIVE_BENCHMARK " +
                    "file=${archiveFile.name} bytes=${archiveFile.length()} " +
                    "elapsedMs=${"%.3f".format(elapsedMillis)} title=${parsed.title} " +
                    "iconBytes=${parsed.iconBytes?.size ?: 0}"
            )
        }
    }

    private fun findRepositoryRoot(): File {
        val workingDirectory = File(requireNotNull(System.getProperty("user.dir"))).absoluteFile
        var current = workingDirectory
        repeat(4) {
            if (current.resolve("settings.gradle.kts").isFile) return current
            current = current.parentFile ?: return@repeat
        }
        return workingDirectory
    }

    private companion object {
        const val COLD_SCAN_BUDGET_MILLIS = 500.0
    }
}
