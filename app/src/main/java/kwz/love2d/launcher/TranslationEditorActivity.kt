package kwz.love2d.launcher

import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.widget.EditText
import android.widget.ImageButton
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import kwz.love2d.launcher.adapter.TranslationEntryAdapter
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.TranslationManager

class TranslationEditorActivity : AppCompatActivity() {
    private lateinit var projectId: String
    private lateinit var adapter: TranslationEntryAdapter
    private lateinit var progress: TextView

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

        findViewById<TextView>(R.id.tvTranslationEditorTitle).text =
            getString(R.string.translation_editor_for_game, project.gameTitle)
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
        findViewById<ImageButton>(R.id.btnTranslationEditorBack).setOnClickListener {
            NavigationAnimations.finish(this)
        }
        findViewById<ImageButton>(R.id.btnExportTranslation).setOnClickListener {
            exportDocument.launch("${safeFileName(project.gameTitle)}-${project.targetLanguage}.kllang")
        }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = NavigationAnimations.finish(this@TranslationEditorActivity)
        })
    }

    override fun onResume() {
        super.onResume()
        if (!::adapter.isInitialized) return
        val entries = TranslationManager.entries(this, projectId)
        adapter.submit(entries)
        val translated = entries.count { it.translatedText.isNotBlank() }
        progress.text = getString(R.string.translation_progress, translated, entries.size)
    }

    private fun safeFileName(value: String) = value.replace(Regex("[^A-Za-z0-9._-]"), "_").take(80)

    companion object {
        const val EXTRA_PROJECT_ID = "translation_project_id"
    }
}
