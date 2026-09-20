package kwz.love2d.launcher.adapter

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.card.MaterialCardView
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.CatalogTranslation
import kwz.love2d.launcher.model.TranslationProject

enum class TranslationItemAction {
    NONE,
    EDIT,
    DOWNLOAD,
    UPDATE
}

data class TranslationDisplayItem(
    val key: String,
    val name: String,
    val summary: String,
    val selected: Boolean,
    val selectable: Boolean,
    val action: TranslationItemAction,
    val versionWarning: String? = null,
    val localProject: TranslationProject? = null,
    val catalogTranslation: CatalogTranslation? = null,
    val communityTranslationId: String? = null
)

class CommunityTranslationAdapter(
    private val onSelect: (TranslationDisplayItem) -> Unit,
    private val onAction: (TranslationDisplayItem) -> Unit,
    private val onVersionWarning: (TranslationDisplayItem) -> Unit
) : RecyclerView.Adapter<CommunityTranslationAdapter.ViewHolder>() {
    private var items: List<TranslationDisplayItem> = emptyList()
    private var busyKey: String? = null
    private var busyText: String? = null

    fun update(items: List<TranslationDisplayItem>, busyKey: String? = null, busyText: String? = null) {
        this.items = items
        this.busyKey = busyKey
        this.busyText = busyText
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_translation_project, parent, false) as MaterialCardView
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size

    inner class ViewHolder(private val root: MaterialCardView) : RecyclerView.ViewHolder(root) {
        private val name: TextView = root.findViewById(R.id.tvTranslationLanguage)
        private val summary: TextView = root.findViewById(R.id.tvTranslationProgress)
        private val warning: ImageButton = root.findViewById(R.id.btnTranslationVersionWarning)
        private val edit: ImageButton = root.findViewById(R.id.btnEditTranslation)
        private val download: ImageButton = root.findViewById(R.id.btnDownloadTranslation)

        fun bind(item: TranslationDisplayItem) {
            val busy = busyKey == item.key
            name.text = item.name
            summary.text = if (busy) busyText ?: root.context.getString(R.string.translation_downloading) else item.summary
            root.isCheckable = item.selectable
            root.isChecked = item.selectable && item.selected
            warning.visibility = if (item.versionWarning != null) View.VISIBLE else View.GONE
            edit.visibility = if (item.action == TranslationItemAction.EDIT) View.VISIBLE else View.GONE
            download.visibility = if (
                item.action == TranslationItemAction.DOWNLOAD || item.action == TranslationItemAction.UPDATE
            ) View.VISIBLE else View.GONE
            download.isEnabled = !busy
            download.contentDescription = root.context.getString(
                if (item.action == TranslationItemAction.UPDATE) R.string.translation_update
                else R.string.translation_download
            )
            root.isEnabled = !busy
            root.alpha = if (busy) 0.8f else 1f
            root.setOnClickListener { if (item.selectable && !busy) onSelect(item) }
            warning.setOnClickListener { if (!busy && item.versionWarning != null) onVersionWarning(item) }
            edit.setOnClickListener { if (!busy) onAction(item) }
            download.setOnClickListener { if (!busy) onAction(item) }
        }
    }
}
