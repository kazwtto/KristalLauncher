package kwz.love2d.launcher.adapter

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.progressindicator.LinearProgressIndicator
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.KristalRuntimeDisplayItem
import kwz.love2d.launcher.model.KristalRuntimeInstallStage
import kwz.love2d.launcher.util.ThemeManager
import java.util.Locale

class KristalRuntimeAdapter(
    private val onAction: (KristalRuntimeDisplayItem) -> Unit,
    private val onRemove: (KristalRuntimeDisplayItem) -> Unit
) : RecyclerView.Adapter<KristalRuntimeAdapter.RuntimeViewHolder>() {

    private var items = emptyList<KristalRuntimeDisplayItem>()
    private var activeTag: String? = null
    private var stage: KristalRuntimeInstallStage? = null
    private var downloadedBytes: Long = 0L
    private var totalBytes: Long = -1L

    fun submitItems(newItems: List<KristalRuntimeDisplayItem>) {
        val oldItems = items
        val nextItems = newItems.toList()
        val diff = DiffUtil.calculateDiff(object : DiffUtil.Callback() {
            override fun getOldListSize() = oldItems.size
            override fun getNewListSize() = nextItems.size
            override fun areItemsTheSame(oldPosition: Int, newPosition: Int) =
                oldItems[oldPosition].tag == nextItems[newPosition].tag
            override fun areContentsTheSame(oldPosition: Int, newPosition: Int) =
                oldItems[oldPosition] == nextItems[newPosition]
        })
        items = nextItems
        diff.dispatchUpdatesTo(this)
    }

    fun setOperation(
        tag: String?,
        newStage: KristalRuntimeInstallStage? = null,
        downloaded: Long = 0L,
        total: Long = -1L
    ) {
        val affected = setOfNotNull(activeTag, tag)
        activeTag = tag
        stage = newStage
        downloadedBytes = downloaded
        totalBytes = total
        affected.forEach { affectedTag ->
            items.indexOfFirst { it.tag == affectedTag }.takeIf { it >= 0 }?.let(::notifyItemChanged)
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RuntimeViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_kristal_runtime, parent, false)
        ThemeManager.applyDeltaruneStyle(parent.context, view)
        return RuntimeViewHolder(view)
    }

    override fun onBindViewHolder(holder: RuntimeViewHolder, position: Int) = holder.bind(items[position])

    override fun getItemCount() = items.size

    inner class RuntimeViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val version: TextView = itemView.findViewById(R.id.tvRuntimeVersion)
        private val metadata: TextView = itemView.findViewById(R.id.tvRuntimeMetadata)
        private val recommended: TextView = itemView.findViewById(R.id.tvRuntimeRecommended)
        private val progress: LinearProgressIndicator = itemView.findViewById(R.id.runtimeDownloadProgress)
        private val action: MaterialButton = itemView.findViewById(R.id.btnRuntimeAction)
        private val remove: ImageButton = itemView.findViewById(R.id.btnRemoveRuntime)

        fun bind(item: KristalRuntimeDisplayItem) {
            val context = itemView.context
            version.text = context.getString(R.string.kristal_runtime_version, item.version)
            val isActive = activeTag == item.tag
            metadata.text = if (isActive && stage == KristalRuntimeInstallStage.DOWNLOADING) {
                if (totalBytes > 0L) {
                    context.getString(
                        R.string.kristal_runtime_download_progress,
                        formatBytes(downloadedBytes),
                        formatBytes(totalBytes)
                    )
                } else {
                    context.getString(
                        R.string.kristal_runtime_downloaded_amount,
                        formatBytes(downloadedBytes)
                    )
                }
            } else {
                buildList {
                    val size = item.release?.sizeBytes ?: item.installed?.file?.length() ?: 0L
                    if (size > 0L) add(formatBytes(size))
                    if (item.release?.prerelease == true) {
                        add(context.getString(R.string.kristal_runtime_prerelease))
                    }
                }.joinToString(" · ")
            }

            recommended.visibility = if (item.recommended) View.VISIBLE else View.GONE

            progress.visibility = if (isActive) View.VISIBLE else View.GONE
            if (isActive && stage == KristalRuntimeInstallStage.DOWNLOADING && totalBytes > 0L) {
                progress.isIndeterminate = false
                progress.max = 1000
                progress.progress = ((downloadedBytes * 1000L) / totalBytes).coerceIn(0L, 1000L).toInt()
            } else {
                progress.isIndeterminate = true
            }

            remove.visibility = if (item.installed != null && !isActive) View.VISIBLE else View.GONE
            remove.setOnClickListener { onRemove(item) }

            action.isEnabled = activeTag == null && !(item.selected && item.installed != null)
            action.setText(
                when {
                    isActive -> when (stage) {
                        KristalRuntimeInstallStage.VALIDATING -> R.string.kristal_runtime_validating
                        KristalRuntimeInstallStage.INSTALLING -> R.string.kristal_runtime_installing
                        else -> R.string.kristal_runtime_downloading
                    }
                    item.installed == null -> R.string.kristal_runtime_download
                    item.selected -> R.string.kristal_runtime_selected
                    else -> R.string.kristal_runtime_select
                }
            )
            action.setOnClickListener { onAction(item) }
        }

        private fun formatBytes(bytes: Long): String {
            val megabytes = bytes / (1024.0 * 1024.0)
            return String.format(Locale.getDefault(), "%.1f MB", megabytes)
        }
    }
}
