package kwz.love2d.launcher

import kwz.love2d.launcher.ui.ControllerNavigationActivity

import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.widget.EditText
import android.widget.ImageButton
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import kwz.love2d.launcher.adapter.TranslationCompletionFilter
import kwz.love2d.launcher.adapter.TranslationEntryAdapter
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.TranslationManager

class TranslationEditorActivity : ControllerNavigationActivity() {
    private lateinit var projectId: String
    private lateinit var adapter: TranslationEntryAdapter
    private lateinit var progress: TextView
    private var externalEditPending = false
    private var externalEditFile: java.io.File? = null
    private var boundKinds: List<String> = emptyList()

    private val exportDocument = registerForActivityResult(
        ActivityResultContracts.CreateDocument("application/zip")
    ) { uri ->
        if (uri == null) return@registerForActivityResult
        runCatching { TranslationManager.exportProject(this, projectId, uri) }
            .onSuccess { Toast.makeText(this, R.string.translation_export_success, Toast.LENGTH_LONG).show() }
            .onFailure {
                Toast.makeText(
                    this,
                    R.string.translation_export_failed,
                    Toast.LENGTH_LONG
                ).show()
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeManager.applyActivityTheme(this)
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_translation_editor)
        projectId = intent.getStringExtra(EXTRA_PROJECT_ID) ?: run { finish(); return }
        val project = TranslationManager.project(this, projectId) ?: run { finish(); return }

        findViewById<TextView>(R.id.tvTranslationEditorTitle).text = project.gameTitle
        progress = findViewById(R.id.tvTranslationEditorProgress)
        adapter = TranslationEntryAdapter { entry ->
            NavigationAnimations.start(
                this,
                Intent(this, TranslationEntryActivity::class.java)
                    .putExtra(TranslationEntryActivity.EXTRA_PROJECT_ID, projectId)
                    .putExtra(TranslationEntryActivity.EXTRA_ENTRY_ID, entry.id)
            )
        }
        findViewById<RecyclerView>(R.id.rvTranslationEntries).apply {
            layoutManager = LinearLayoutManager(this@TranslationEditorActivity)
            adapter = this@TranslationEditorActivity.adapter
            itemAnimator = null
        }
        findViewById<EditText>(R.id.etTranslationSearch).addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                adapter.filter(s?.toString().orEmpty())
            }
            override fun afterTextChanged(s: Editable?) = Unit
        })
        findViewById<MaterialButtonToggleGroup>(R.id.translationCompletionFilters)
            .addOnButtonCheckedListener { _, checkedId, isChecked ->
                if (!isChecked) return@addOnButtonCheckedListener
                adapter.filterCompletion(
                    when (checkedId) {
                        R.id.filterTranslationPending -> TranslationCompletionFilter.PENDING
                        R.id.filterTranslationTranslated -> TranslationCompletionFilter.TRANSLATED
                        else -> TranslationCompletionFilter.ALL
                    }
                )
            }
        findViewById<ImageButton>(R.id.btnTranslationEditorBack).setOnClickListener {
            NavigationAnimations.finish(this)
        }
        findViewById<ImageButton>(R.id.btnExportTranslation).setOnClickListener {
            exportDocument.launch("${safeFileName(project.gameTitle)}-${project.targetLanguage}.kllang")
        }
        findViewById<ImageButton>(R.id.btnEditTranslationExternal).setOnClickListener {
            openExternalEditor()
        }
        findViewById<ImageButton>(R.id.btnTranslationSettings).setOnClickListener {
            NavigationAnimations.start(
                this,
                Intent(this, TranslationSettingsActivity::class.java)
                    .putExtra(TranslationSettingsActivity.EXTRA_PROJECT_ID, projectId)
            )
        }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = NavigationAnimations.finish(this@TranslationEditorActivity)
        })
    }

    override fun onResume() {
        super.onResume()
        if (!::adapter.isInitialized) return
        if (externalEditPending) {
            externalEditPending = false
            externalEditFile?.let { file ->
                runCatching { TranslationManager.importEditableJson(this, projectId, file) }
                    .onSuccess { changed ->
                        if (changed > 0) {
                            Toast.makeText(
                                this,
                                getString(R.string.translation_external_changes_applied, changed),
                                Toast.LENGTH_LONG
                            ).show()
                        }
                    }
                    .onFailure {
                        Toast.makeText(this, R.string.translation_external_sync_failed, Toast.LENGTH_LONG).show()
                    }
            }
        }
        val project = TranslationManager.project(this, projectId)
        if (project == null) {
            finish()
            return
        }
        findViewById<TextView>(R.id.tvTranslationEditorTitle).text = project.gameTitle
        val entries = TranslationManager.entries(this, projectId)
        adapter.submit(entries)
        bindKindFilters(adapter.availableKinds())
        val translated = entries.count { it.translatedText.isNotBlank() }
        progress.text = getString(R.string.translation_progress, translated, entries.size)
    }

    private fun bindKindFilters(kinds: List<String>) {
        if (kinds == boundKinds) return
        boundKinds = kinds
        val group = findViewById<MaterialButtonToggleGroup>(R.id.translationKindFilters)
        group.clearOnButtonCheckedListeners()
        group.removeAllViews()
        val options = listOf("" to getString(R.string.translation_filter_all_types)) + kinds.map { it to it }
        options.forEachIndexed { index, (value, label) ->
            val button = layoutInflater.inflate(
                R.layout.item_translation_kind_filter,
                group,
                false
            ) as MaterialButton
            button.id = View.generateViewId()
            button.text = label
            button.tag = value
            group.addView(button)
            if (index == 0) group.check(button.id)
        }
        group.addOnButtonCheckedListener { buttonGroup, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            val selected = buttonGroup.findViewById<MaterialButton>(checkedId)
            adapter.filterKind(selected.tag?.toString()?.takeIf(String::isNotBlank))
        }
        ThemeManager.applyDeltaruneStyle(this, group)
    }

    private fun openExternalEditor() {
        runCatching {
            val file = TranslationManager.exportEditableJson(this, projectId)
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_EDIT)
                .setDataAndType(uri, "application/json")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            check(intent.resolveActivity(packageManager) != null) { "No JSON editor is installed" }
            externalEditFile = file
            externalEditPending = true
            startActivity(Intent.createChooser(intent, getString(R.string.translation_edit_external)))
        }.onFailure {
            externalEditPending = false
            Toast.makeText(this, R.string.translation_external_editor_unavailable, Toast.LENGTH_LONG).show()
        }
    }

    private fun safeFileName(value: String) = value.replace(Regex("[^A-Za-z0-9._-]"), "_").take(80)

    companion object {
        const val EXTRA_PROJECT_ID = "translation_project_id"
    }
}
