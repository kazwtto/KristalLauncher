package kwz.love2d.launcher

import android.os.Bundle
import android.widget.EditText
import android.widget.ImageButton
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputLayout
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.TranslationManager

class TranslationEntryActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeManager.applyActivityTheme(this)
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_translation_entry)
        val projectId = intent.getStringExtra(EXTRA_PROJECT_ID) ?: run { finish(); return }
        val entryId = intent.getStringExtra(EXTRA_ENTRY_ID) ?: run { finish(); return }
        val entry = TranslationManager.entry(this, projectId, entryId) ?: run { finish(); return }

        findViewById<TextView>(R.id.tvTranslationOriginal).text = entry.sourceText
        findViewById<TextView>(R.id.tvTranslationEntryContext).text = getString(
            R.string.translation_entry_context,
            entry.kind,
            entry.filePath,
            entry.line
        )
        val input = findViewById<EditText>(R.id.etTranslationValue)
        val inputLayout = findViewById<TextInputLayout>(R.id.translationInputLayout)
        input.setText(entry.translatedText)
        findViewById<MaterialButton>(R.id.btnSaveTranslationEntry).setOnClickListener {
            val value = input.text?.toString().orEmpty()
            val error = TranslationManager.validationError(entry.sourceText, value)
            inputLayout.error = when (error) {
                TranslationManager.ValidationError.FORMAT_PLACEHOLDER ->
                    getString(R.string.translation_error_format_placeholder)
                TranslationManager.ValidationError.CONTROL_TAG ->
                    getString(R.string.translation_error_control_tag)
                null -> null
            }
            if (error == null) {
                TranslationManager.updateEntry(this, projectId, entryId, value)
                NavigationAnimations.finish(this)
            }
        }
        findViewById<ImageButton>(R.id.btnTranslationEntryBack).setOnClickListener {
            NavigationAnimations.finish(this)
        }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = NavigationAnimations.finish(this@TranslationEntryActivity)
        })
    }

    companion object {
        const val EXTRA_PROJECT_ID = "translation_project_id"
        const val EXTRA_ENTRY_ID = "translation_entry_id"
    }
}
