package kwz.love2d.launcher

import kwz.love2d.launcher.ui.ControllerNavigationActivity

import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.AutoCompleteTextView
import android.widget.EditText
import android.widget.ImageButton
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import com.google.android.material.button.MaterialButton
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.textfield.TextInputLayout
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.TranslationManager
import kwz.love2d.launcher.util.showThemed
import java.util.Locale

class TranslationSettingsActivity : ControllerNavigationActivity() {
    private lateinit var projectId: String
    private lateinit var nameInput: EditText
    private lateinit var authorInput: EditText
    private lateinit var languageInput: AutoCompleteTextView
    private lateinit var nameLayout: TextInputLayout
    private lateinit var languageLayout: TextInputLayout
    private lateinit var languages: List<LanguageOption>
    private var selectedLanguageTag: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeManager.applyActivityTheme(this)
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_translation_settings)
        projectId = intent.getStringExtra(EXTRA_PROJECT_ID) ?: run { finish(); return }
        val project = TranslationManager.project(this, projectId) ?: run { finish(); return }

        nameInput = findViewById(R.id.etTranslationProjectName)
        authorInput = findViewById(R.id.etTranslationProjectAuthor)
        languageInput = findViewById(R.id.etTranslationProjectLanguage)
        nameLayout = findViewById(R.id.translationProjectNameLayout)
        languageLayout = findViewById(R.id.translationProjectLanguageLayout)

        nameInput.setText(project.name)
        authorInput.setText(project.author)
        selectedLanguageTag = project.targetLanguage
        languages = availableLanguages(project.targetLanguage)
        languageInput.setAdapter(LanguageAdapter(languages.map { it.label }))
        languageInput.setText(
            languages.firstOrNull { it.tag.equals(project.targetLanguage, ignoreCase = true) }?.label
                ?: project.targetLanguage,
            false
        )
        languageInput.setOnItemClickListener { parent, _, position, _ ->
            val label = parent.getItemAtPosition(position)?.toString().orEmpty()
            selectedLanguageTag = languages.first { it.label == label }.tag
            languageLayout.error = null
        }
        languageInput.setOnClickListener { languageInput.showDropDown() }

        findViewById<ImageButton>(R.id.btnTranslationSettingsBack).setOnClickListener {
            NavigationAnimations.finish(this)
        }
        findViewById<MaterialButton>(R.id.btnSaveTranslationSettings).setOnClickListener {
            saveProject()
        }
        findViewById<MaterialButton>(R.id.btnClearTranslationProject).setOnClickListener {
            confirmClear()
        }
        findViewById<MaterialButton>(R.id.btnDeleteTranslationProject).setOnClickListener {
            confirmDelete()
        }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = NavigationAnimations.finish(this@TranslationSettingsActivity)
        })
    }

    private fun saveProject() {
        val name = nameInput.text?.toString().orEmpty().trim()
        val selected = languages.firstOrNull { it.label == languageInput.text?.toString() }
        if (name.isBlank()) {
            nameLayout.error = getString(R.string.translation_project_name_required)
            return
        }
        nameLayout.error = null
        if (selected == null && selectedLanguageTag.isBlank()) {
            languageLayout.error = getString(R.string.translation_project_language_required)
            return
        }
        languageLayout.error = null
        selected?.let { selectedLanguageTag = it.tag }
        runCatching {
            TranslationManager.updateProject(
                this,
                projectId,
                name,
                authorInput.text?.toString().orEmpty(),
                selectedLanguageTag
            )
        }.onSuccess {
            Toast.makeText(this, R.string.translation_settings_saved, Toast.LENGTH_SHORT).show()
        }.onFailure {
            Toast.makeText(this, R.string.translation_settings_save_failed, Toast.LENGTH_LONG).show()
        }
    }

    private fun confirmClear() {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.translation_clear_title)
            .setMessage(R.string.translation_clear_message)
            .setNegativeButton(R.string.cancel, null)
            .setPositiveButton(R.string.translation_clear_action) { _, _ ->
                TranslationManager.clearProject(this, projectId)
                Toast.makeText(this, R.string.translation_cleared, Toast.LENGTH_SHORT).show()
            }
            .create()
            .also { it.showThemed() }
    }

    private fun confirmDelete() {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.translation_delete_title)
            .setMessage(R.string.translation_delete_message)
            .setNegativeButton(R.string.cancel, null)
            .setPositiveButton(R.string.translation_delete_action) { _, _ ->
                TranslationManager.deleteProject(this, projectId)
                setResult(RESULT_OK)
                finish()
            }
            .create()
            .also { it.showThemed() }
    }

    private fun availableLanguages(currentTag: String): List<LanguageOption> {
        val displayLocale = Locale.getDefault()
        return (Locale.getAvailableLocales().asSequence()
            .filter { it.language.isNotBlank() }
            .map { Locale.forLanguageTag(it.toLanguageTag()) }
            .plus(Locale.forLanguageTag(currentTag))
            .distinctBy { it.toLanguageTag().lowercase(Locale.ROOT) }
            .map { locale ->
                val tag = locale.toLanguageTag()
                val name = locale.getDisplayName(displayLocale)
                    .replaceFirstChar { it.titlecase(displayLocale) }
                    .ifBlank { tag }
                LanguageOption(tag, "$name — $tag")
            }
            .sortedBy { it.label.lowercase(displayLocale) }
            .toList())
    }

    private data class LanguageOption(val tag: String, val label: String)

    private inner class LanguageAdapter(items: List<String>) :
        ArrayAdapter<String>(this, android.R.layout.simple_dropdown_item_1line, items) {

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View =
            super.getView(position, convertView, parent).also {
                ThemeManager.applyDeltaruneStyle(this@TranslationSettingsActivity, it)
            }

        override fun getDropDownView(position: Int, convertView: View?, parent: ViewGroup): View =
            super.getDropDownView(position, convertView, parent).also {
                ThemeManager.applyDeltaruneStyle(this@TranslationSettingsActivity, it)
            }
    }

    companion object {
        const val EXTRA_PROJECT_ID = "translation_project_id"
    }
}
