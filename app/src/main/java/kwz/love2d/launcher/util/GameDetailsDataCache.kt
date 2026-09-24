package kwz.love2d.launcher.util

import android.content.Context
import kwz.love2d.launcher.model.CatalogPatch
import kwz.love2d.launcher.model.CatalogTranslation
import kwz.love2d.launcher.model.InstalledCommunityTranslation
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.model.PatchDisplayItem
import kwz.love2d.launcher.model.TranslationProject
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import java.util.concurrent.atomic.AtomicLong

/** Exact, read-only game-detail data prepared off the UI thread while Home is visible. */
object GameDetailsDataCache {
    data class Snapshot(
        val catalogPatches: List<CatalogPatch>,
        val patchItems: List<PatchDisplayItem>,
        val catalogTranslations: List<CatalogTranslation>,
        val installedTranslations: List<InstalledCommunityTranslation>,
        val projects: List<TranslationProject>
    )

    private data class Key(
        val stableId: String,
        val projectId: String?,
        val version: String?,
        val sizeBytes: Long,
        val lastModified: Long,
        val languageTag: String
    )

    @Volatile
    private var snapshots: Map<Key, Snapshot> = emptyMap()
    private val revision = AtomicLong()

    fun get(context: Context, game: LoveGame): Snapshot? = snapshots[key(context, game)]

    fun invalidate(game: LoveGame) {
        revision.incrementAndGet()
        snapshots = snapshots.filterKeys { it.stableId != game.stableId }
    }

    suspend fun warm(context: Context, games: List<LoveGame>) {
        val startingRevision = revision.get()
        if (games.isEmpty()) {
            snapshots = emptyMap()
            return
        }
        val catalogPatches = PatchCatalogService.cachedPatches(context)
        val installedPatchItems = PatchRepository.installedDisplayItems(context)
        val catalogPatchItems = PatchRepository.catalogDisplayItems(context, catalogPatches)
        val catalogTranslations = CommunityTranslationCatalogService.cachedTranslations(context)
        val installedTranslations = CommunityTranslationStorage.installed(context)
        val prepared = LinkedHashMap<Key, Snapshot>(games.size)
        games.forEach { game ->
            currentCoroutineContext().ensureActive()
            val translationsForGame = if (
                game.projectId != null && IdentifierPolicy.isGameProjectId(game.projectId)
            ) {
                installedTranslations.filter {
                    it.manifest.gameProjectId.equals(game.projectId, ignoreCase = true)
                }
            } else {
                emptyList()
            }
            prepared[key(context, game)] = Snapshot(
                catalogPatches = catalogPatches,
                patchItems = PatchRepository.gameDisplayItems(
                    game.projectId,
                    installedPatchItems,
                    catalogPatchItems
                ),
                catalogTranslations = catalogTranslations,
                installedTranslations = translationsForGame,
                projects = TranslationManager.projectsForGame(context, game.stableId)
            )
        }
        currentCoroutineContext().ensureActive()
        if (revision.get() == startingRevision) snapshots = prepared
    }

    private fun key(context: Context, game: LoveGame) = Key(
        game.stableId,
        game.projectId,
        game.version,
        game.sizeBytes,
        game.lastModified,
        context.resources.configuration.locales[0].toLanguageTag()
    )
}
