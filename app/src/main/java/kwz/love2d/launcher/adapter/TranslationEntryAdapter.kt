package kwz.love2d.launcher.adapter

import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.TranslationEntry

enum class TranslationCompletionFilter {
    ALL,
    PENDING,
    TRANSLATED
}

class TranslationEntryAdapter(
    private val onClick: (TranslationEntry) -> Unit
) : RecyclerView.Adapter<TranslationEntryAdapter.ViewHolder>() {

    private var allEntries: List<TranslationEntry> = emptyList()
    private var query: String = ""
    private var kind: String? = null
    private var completion = TranslationCompletionFilter.ALL
    private var displayedEntries: List<TranslationEntry> = emptyList()

    fun submit(entries: List<TranslationEntry>) {
        allEntries = entries
        applyFilter()
    }

    fun filter(value: String) {
        query = value.trim()
        applyFilter()
    }

    fun filterKind(value: String?) {
        kind = value
        applyFilter()
    }

    fun filterCompletion(value: TranslationCompletionFilter) {
        completion = value
        applyFilter()
    }

    fun availableKinds(): List<String> = allEntries.map(TranslationEntry::kind)
        .filter(String::isNotBlank)
        .distinct()
        .sorted()

    private fun applyFilter() {
        displayedEntries = allEntries.filter { entry ->
            val matchesQuery = query.isBlank() ||
                entry.sourceText.contains(query, ignoreCase = true) ||
                entry.translatedText.contains(query, ignoreCase = true) ||
                entry.filePath.contains(query, ignoreCase = true)
            val matchesKind = kind == null || entry.kind == kind
            val matchesCompletion = when (completion) {
                TranslationCompletionFilter.ALL -> true
                TranslationCompletionFilter.PENDING -> entry.translatedText.isBlank()
                TranslationCompletionFilter.TRANSLATED -> entry.translatedText.isNotBlank()
            }
            matchesQuery && matchesKind && matchesCompletion
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
