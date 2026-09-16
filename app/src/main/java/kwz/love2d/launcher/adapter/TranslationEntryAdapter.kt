package kwz.love2d.launcher.adapter

import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.TranslationEntry

class TranslationEntryAdapter(
    private val onClick: (TranslationEntry) -> Unit
) : RecyclerView.Adapter<TranslationEntryAdapter.ViewHolder>() {

    private var allEntries: List<TranslationEntry> = emptyList()
    private var query: String = ""
    private var displayedEntries: List<TranslationEntry> = emptyList()

    fun submit(entries: List<TranslationEntry>) {
        allEntries = entries
        applyFilter()
    }

    fun filter(value: String) {
        query = value.trim()
        applyFilter()
    }

    private fun applyFilter() {
        displayedEntries = if (query.isBlank()) allEntries else allEntries.filter {
            it.sourceText.contains(query, ignoreCase = true) ||
                it.translatedText.contains(query, ignoreCase = true) ||
                it.filePath.contains(query, ignoreCase = true)
        }
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_translation_entry, parent, false) as ViewGroup
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(displayedEntries[position])
    override fun getItemCount(): Int = displayedEntries.size

    inner class ViewHolder(private val root: ViewGroup) : RecyclerView.ViewHolder(root) {
        private val source: TextView = root.findViewById(R.id.tvEntrySource)
        private val translation: TextView = root.findViewById(R.id.tvEntryTranslation)
        private val context: TextView = root.findViewById(R.id.tvEntryContext)

        fun bind(entry: TranslationEntry) {
            source.text = entry.sourceText
            translation.text = entry.translatedText.ifBlank {
                root.context.getString(R.string.translation_not_translated)
            }
            translation.alpha = if (entry.translatedText.isBlank()) 0.65f else 1f
            context.text = root.context.getString(
                R.string.translation_entry_context,
                entry.kind,
                entry.filePath,
                entry.line
            )
            root.setOnClickListener { onClick(entry) }
        }
    }
}
