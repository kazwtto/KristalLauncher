package kwz.love2d.launcher.util

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import kwz.love2d.launcher.model.LoveGame
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import java.util.Locale
import kotlin.coroutines.coroutineContext

/**
 * Atomic game indexer.
 *
 * One DocumentsContract query fingerprints the folder. Complete cached entries are reused and
 * changed packages are enriched off the main thread with bounded concurrency. The caller receives
 * one complete snapshot, never a sequence of provisional cards.
 */
object GameScanner {

    private const val MAX_CONCURRENT_PARSERS = 2

    data class ScanResult(
        val games: List<LoveGame>,
        val failedFiles: List<String>
    )

    suspend fun scanGamesInFolder(
        context: Context,
        folderUri: Uri,
        cachedGames: List<LoveGame> = emptyList(),
        forceRefresh: Boolean = false
    ): ScanResult = withContext(Dispatchers.IO) {
        val files = querySupportedGameFiles(context, folderUri)
        val cachedBySourceUri = cachedGames.groupBy { it.uri.toString() }
        val resultsBySource = HashMap<String, List<LoveGame>>()
        val pendingFiles = mutableListOf<GameFileCandidate>()

        files.forEach { file ->
            coroutineContext.ensureActive()
            val sourceKey = file.uri.toString()
            val cachedForSource = cachedBySourceUri[sourceKey].orEmpty()
            val sourceHasVersion = file.sizeBytes > 0L || file.lastModified > 0L
            val sizesMatch = cachedForSource.isNotEmpty() && cachedForSource.all { it.sizeBytes == file.sizeBytes }
            val timestampsMatch = cachedForSource.isNotEmpty() && cachedForSource.all {
                (file.lastModified > 0L && it.lastModified == file.lastModified) ||
                    (file.lastModified <= 0L && it.lastModified <= 0L)
            }
            val cacheMatches = !forceRefresh &&
                sourceHasVersion &&
                sizesMatch &&
                timestampsMatch

            if (cacheMatches) {
                resultsBySource[sourceKey] = cachedForSource
            } else {
                pendingFiles += file
            }
        }

        val semaphore = Semaphore(MAX_CONCURRENT_PARSERS)
        val parsedCandidates = supervisorScope {
            pendingFiles.map { candidate ->
                async {
                    semaphore.withPermit {
                        coroutineContext.ensureActive()
                        parseCandidate(context, candidate)
                    }
                }
            }.awaitAll()
        }

        val failedFiles = ArrayList<String>()
        parsedCandidates.forEach { result ->
            if (result.games.isNotEmpty()) {
                resultsBySource[result.sourceKey] = result.games
            } else {
                cachedBySourceUri[result.sourceKey]
                    ?.takeIf { it.isNotEmpty() }
                    ?.let { resultsBySource[result.sourceKey] = it }
                if (result.failedFileName != null) {
                    failedFiles += result.failedFileName
                }
            }
        }

        ScanResult(
            games = snapshot(resultsBySource),
            failedFiles = failedFiles.distinct().sortedWith(String.CASE_INSENSITIVE_ORDER)
        )
    }

    /**
     * Converts every per-file failure into a value before it reaches [awaitAll].
     *
     * `supervisorScope` alone is not enough: awaiting a failed deferred still throws to the
     * caller. Returning an outcome keeps a corrupt or unsupported package from aborting the
     * complete folder snapshot.
     */
    private fun parseCandidate(
        context: Context,
        candidate: GameFileCandidate
    ): CandidateParseResult {
        return try {
            CandidateParseResult(
                sourceKey = candidate.uri.toString(),
                games = LoveMetadataParser.parseLoveFiles(
                    context = context,
                    uri = candidate.uri,
                    fileName = candidate.name,
                    sizeBytes = candidate.sizeBytes,
                    lastModified = candidate.lastModified
                ),
                failedFileName = null
            )
        } catch (error: CancellationException) {
            throw error
        } catch (error: VirtualMachineError) {
            // An unrecoverable runtime failure cannot be safely converted into a partial scan.
            throw error
        } catch (_: Throwable) {
            CandidateParseResult(
                sourceKey = candidate.uri.toString(),
                games = emptyList(),
                failedFileName = candidate.name
            )
        }
    }

    private fun snapshot(resultsBySource: Map<String, List<LoveGame>>): List<LoveGame> {
        return resultsBySource.values
            .asSequence()
            .flatten()
            .sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.title })
            .toList()
    }

    private suspend fun querySupportedGameFiles(
        context: Context,
        folderUri: Uri
    ): List<GameFileCandidate> {
        if (TvGameLibrary.isLibraryUri(context, folderUri)) {
            return TvGameLibrary.directory(context)?.listFiles().orEmpty()
                .filter { it.isFile && isSupportedGameName(it.name) }
                .map { GameFileCandidate(Uri.fromFile(it), it.name, it.length(), it.lastModified()) }
        }
        return try {
            queryDocumentProvider(context, folderUri)
        } catch (error: SecurityException) {
            throw error
        } catch (error: Exception) {
            error.printStackTrace()
            queryDocumentFileFallback(context, folderUri)
        }
    }

    private suspend fun queryDocumentProvider(
        context: Context,
        folderUri: Uri
    ): List<GameFileCandidate> {
        val parentDocumentId = DocumentsContract.getTreeDocumentId(folderUri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(folderUri, parentDocumentId)
        val resolver = context.contentResolver
        val results = ArrayList<GameFileCandidate>(64)

        resolver.query(childrenUri, DOCUMENT_PROJECTION, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
            val modifiedColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)

            while (cursor.moveToNext()) {
                coroutineContext.ensureActive()
                val name = cursor.getString(nameColumn) ?: continue
                val mimeType = cursor.getString(mimeColumn)
                if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR || !isSupportedGameName(name)) continue
                val documentId = cursor.getString(idColumn) ?: continue
                results += GameFileCandidate(
                    uri = DocumentsContract.buildDocumentUriUsingTree(folderUri, documentId),
                    name = name,
                    sizeBytes = cursor.readLong(sizeColumn),
                    lastModified = cursor.readLong(modifiedColumn)
                )
            }
        } ?: throw IllegalStateException("The games folder provider returned no cursor")

        return results
    }

    private fun queryDocumentFileFallback(context: Context, folderUri: Uri): List<GameFileCandidate> {
        val rootFolder = DocumentFile.fromTreeUri(context, folderUri) ?: return emptyList()
        return rootFolder.listFiles().mapNotNull { file ->
            if (!file.isFile) return@mapNotNull null
            val name = file.name?.takeIf(::isSupportedGameName) ?: return@mapNotNull null
            GameFileCandidate(file.uri, name, file.length(), file.lastModified())
        }
    }

    private fun android.database.Cursor.readLong(column: Int): Long {
        return if (column >= 0 && !isNull(column)) getLong(column).coerceAtLeast(0L) else 0L
    }

    private fun isSupportedGameName(name: String): Boolean {
        val lowercaseName = name.lowercase(Locale.ROOT)
        return lowercaseName.endsWith(".love") || lowercaseName.endsWith(".exe") || lowercaseName.endsWith(".zip")
    }

    private data class GameFileCandidate(
        val uri: Uri,
        val name: String,
        val sizeBytes: Long,
        val lastModified: Long
    )

    private data class CandidateParseResult(
        val sourceKey: String,
        val games: List<LoveGame>,
        val failedFileName: String?
    )

    private val DOCUMENT_PROJECTION = arrayOf(
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_SIZE,
        DocumentsContract.Document.COLUMN_LAST_MODIFIED
    )
}
