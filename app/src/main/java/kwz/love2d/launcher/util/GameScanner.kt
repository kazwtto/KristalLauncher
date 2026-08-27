package kwz.love2d.launcher.util

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import kwz.love2d.launcher.model.LoveGame
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import java.util.Collections
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.coroutineContext

object GameScanner {

    private const val MAX_CONCURRENT_PARSERS = 3
    private const val PROGRESS_BATCH_SIZE = 8

    suspend fun scanGamesInFolder(
        context: Context,
        folderUri: Uri,
        cachedGames: List<LoveGame> = emptyList(),
        onProgress: (suspend (List<LoveGame>) -> Unit)? = null
    ): List<LoveGame> = withContext(Dispatchers.IO) {
        val rootFolder = DocumentFile.fromTreeUri(context, folderUri) ?: return@withContext emptyList()
        val files = rootFolder.listFiles().filter(::isSupportedGameFile)
        val cachedByUri = cachedGames.associateBy { it.stableId }
        val games = Collections.synchronizedList(mutableListOf<LoveGame>())
        val pendingFiles = mutableListOf<GameFileCandidate>()

        files.forEach { file ->
            coroutineContext.ensureActive()
            val size = file.length()
            val lastModified = file.lastModified()
            val cached = cachedByUri[file.uri.toString()]
            val reliableTimestampMatches = lastModified > 0L && cached?.lastModified == lastModified
            if (cached != null && cached.sizeBytes == size && reliableTimestampMatches) {
                games.add(cached)
            } else {
                pendingFiles += GameFileCandidate(file, size, lastModified)
            }
        }

        emitProgress(games, onProgress)
        val semaphore = Semaphore(MAX_CONCURRENT_PARSERS)
        val completed = AtomicInteger(0)

        supervisorScope {
            pendingFiles.map { candidate ->
                async {
                    semaphore.withPermit {
                        coroutineContext.ensureActive()
                        try {
                            LoveMetadataParser.parseLoveFile(
                                context = context,
                                document = candidate.document,
                                sizeBytes = candidate.sizeBytes,
                                lastModified = candidate.lastModified
                            )
                        } catch (error: CancellationException) {
                            throw error
                        } catch (error: Exception) {
                            error.printStackTrace()
                            null
                        }
                    }?.also(games::add)

                    val completedCount = completed.incrementAndGet()
                    if (completedCount == 1 || completedCount % PROGRESS_BATCH_SIZE == 0) {
                        emitProgress(games, onProgress)
                    }
                }
            }.awaitAll()
        }

        games.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.title })
            .also { onProgress?.invoke(it) }
    }

    private fun isSupportedGameFile(file: DocumentFile): Boolean {
        if (!file.isFile) return false
        val name = file.name?.lowercase(Locale.ROOT) ?: return false
        return name.endsWith(".love") || name.endsWith(".exe") || name.endsWith(".zip")
    }

    private suspend fun emitProgress(
        games: MutableList<LoveGame>,
        callback: (suspend (List<LoveGame>) -> Unit)?
    ) {
        if (callback == null || games.isEmpty()) return
        val snapshot = synchronized(games) {
            games.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.title })
        }
        callback(snapshot)
    }

    private data class GameFileCandidate(
        val document: DocumentFile,
        val sizeBytes: Long,
        val lastModified: Long
    )
}
