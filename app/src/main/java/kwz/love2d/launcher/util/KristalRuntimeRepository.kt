package kwz.love2d.launcher.util

import android.content.Context
import kwz.love2d.launcher.model.KristalRuntimeDisplayItem
import kwz.love2d.launcher.model.KristalRuntimeRelease
import kwz.love2d.launcher.model.RuntimeChannelFilter

object KristalRuntimeRepository {

    fun displayItems(
        context: Context,
        releases: List<KristalRuntimeRelease>,
        filter: RuntimeChannelFilter = RuntimeChannelFilter.ALL
    ): List<KristalRuntimeDisplayItem> {
        val installed = KristalRuntimeStorage.installedRuntimes(context).associateBy { it.tag }
        val selectedTag = KristalRuntimeStorage.selectedRuntime(context)?.tag
        val releaseByTag = releases.associateBy { it.tag }
        val recommendedTag = releases.firstOrNull { !it.prerelease }?.tag ?: releases.firstOrNull()?.tag
        return (releaseByTag.keys + installed.keys)
            .map { tag ->
                val release = releaseByTag[tag]
                val local = installed[tag]
                KristalRuntimeDisplayItem(
                    tag = tag,
                    version = release?.version ?: local?.version.orEmpty(),
                    release = release,
                    installed = local,
                    selected = tag == selectedTag,
                    recommended = tag == recommendedTag
                )
            }
            // Installed versions always stay visible so they can be selected or removed.
            .filter { it.installed != null || filter.accepts(it.channel) }
            .sortedWith(
                compareByDescending<KristalRuntimeDisplayItem> { it.installed != null }
                    .thenComparator { left, right -> VersionUtils.compare(right.version, left.version) }
            )
    }
}
