package kwz.love2d.launcher.util

import android.content.Context
import kwz.love2d.launcher.model.CatalogPatch
import kwz.love2d.launcher.model.PatchDisplayItem
import kwz.love2d.launcher.model.PatchOrigin
import kwz.love2d.launcher.model.PatchTrust

object PatchRepository {

    fun installedDisplayItems(context: Context): List<PatchDisplayItem> {
        val builtIn = PatchRegistry.getBuiltInDisplayItems(context)
        val external = PatchStorage.getInstalledPatches(context).map { patch ->
            PatchDisplayItem(
                id = patch.manifest.id,
                version = patch.manifest.version,
                name = patch.manifest.name.resolve(context),
                description = patch.manifest.description.resolve(context),
                useCases = patch.manifest.useCases.map { it.resolve(context) },
                author = patch.manifest.author,
                category = patch.manifest.category,
                compatibleGameProjectIds = patch.manifest.compatibleGameProjectIds,
                origin = patch.origin,
                trust = if (patch.origin == PatchOrigin.OFFICIAL) PatchTrust.VERIFIED else PatchTrust.UNVERIFIED,
                capabilities = patch.manifest.capabilities,
                dependencies = patch.manifest.dependencies,
                conflicts = patch.manifest.conflicts,
                installed = true,
                enabled = PatchManager.isGlobalPatchEnabled(context, patch.manifest.id),
                installedPatch = patch
            )
        }
        return builtIn + external.sortedBy { it.name.lowercase() }
    }

    fun catalogDisplayItems(context: Context, catalog: List<CatalogPatch>): List<PatchDisplayItem> {
        val installed = PatchStorage.getInstalledPatches(context).associateBy { it.manifest.id }
        return catalog.map { patch ->
            val installedPatch = installed[patch.manifest.id]
            PatchDisplayItem(
                id = patch.manifest.id,
                version = patch.manifest.version,
                name = patch.manifest.name.resolve(context),
                description = patch.manifest.description.resolve(context),
                useCases = patch.manifest.useCases.map { it.resolve(context) },
                author = patch.manifest.author,
                category = patch.manifest.category,
                compatibleGameProjectIds = patch.manifest.compatibleGameProjectIds,
                origin = PatchOrigin.OFFICIAL,
                trust = PatchTrust.VERIFIED,
                capabilities = patch.manifest.capabilities,
                dependencies = patch.manifest.dependencies,
                conflicts = patch.manifest.conflicts,
                installed = installedPatch != null,
                enabled = installedPatch?.let { PatchManager.isGlobalPatchEnabled(context, it.manifest.id) } ?: false,
                updateAvailable = installedPatch != null && VersionUtils.isNewer(
                    patch.manifest.version,
                    installedPatch.manifest.version
                ),
                catalogPatch = patch,
                installedPatch = installedPatch
            )
        }
    }

    fun gameDisplayItems(
        context: Context,
        gameProjectId: String?,
        catalog: List<CatalogPatch>
    ): List<PatchDisplayItem> {
        val installedItems = installedDisplayItems(context)
        val installedById = installedItems.associateBy(PatchDisplayItem::id)
        val catalogItems = catalogDisplayItems(context, catalog)
        val catalogById = catalogItems.associateBy(PatchDisplayItem::id)
        val projectId = gameProjectId?.trim().orEmpty()

        val dedicated = (installedItems + catalogItems)
            .asSequence()
            .filter { item -> item.compatibleGameProjectIds.any { it.equals(projectId, ignoreCase = true) } }
            .map { item -> catalogById[item.id] ?: installedById.getValue(item.id) }
            .distinctBy(PatchDisplayItem::id)
            .sortedBy { it.name.lowercase() }
            .toList()
        val generic = installedItems
            .filter { it.compatibleGameProjectIds.isEmpty() }
            .sortedBy { it.name.lowercase() }
        return dedicated + generic
    }

    fun activationProblems(context: Context, patchId: String): ActivationProblems {
        val installed = PatchStorage.getInstalledPatches(context).associateBy { it.manifest.id }
        val patch = installed[patchId] ?: return ActivationProblems()
        val missingDependencies = patch.manifest.dependencies.filter { dependency ->
            if (dependency in PatchManager.ALL_PATCH_KEYS) {
                !PatchManager.isGlobalPatchEnabled(context, dependency)
            } else {
                val installedDependency = installed[dependency]
                installedDependency == null || !PatchManager.isGlobalPatchEnabled(context, dependency)
            }
        }
        val enabledConflicts = patch.manifest.conflicts.filter { conflict ->
            PatchManager.isGlobalPatchEnabled(context, conflict)
        }
        return ActivationProblems(missingDependencies, enabledConflicts)
    }
}

data class ActivationProblems(
    val missingDependencies: List<String> = emptyList(),
    val enabledConflicts: List<String> = emptyList()
) {
    val hasProblems: Boolean
        get() = missingDependencies.isNotEmpty() || enabledConflicts.isNotEmpty()
}
