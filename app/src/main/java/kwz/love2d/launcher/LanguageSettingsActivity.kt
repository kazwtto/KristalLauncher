package kwz.love2d.launcher

import android.os.Bundle
import android.view.View
import android.widget.ImageView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView
import com.google.android.material.radiobutton.MaterialRadioButton
import kwz.love2d.launcher.util.LanguageManager
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager

class LanguageSettingsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeManager.applyActivityTheme(this)
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_language_settings)

        findViewById<ImageView>(R.id.btnBack).setOnClickListener { finishWithAnimation() }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = finishWithAnimation()
        })

        val choices = listOf(
            languageChoice(R.id.languageDeviceCard, R.id.languageDevice, LanguageManager.LANGUAGE_SYSTEM),
            languageChoice(R.id.languagePortugueseCard, R.id.languagePortuguese, "pt"),
            languageChoice(R.id.languageEnglishCard, R.id.languageEnglish, "en"),
            languageChoice(R.id.languageSpanishCard, R.id.languageSpanish, "es")
        )
        updateSelection(choices, LanguageManager.getCurrentLanguage(this))
        choices.forEach { choice ->
            choice.card.setOnClickListener {
                if (choice.value != LanguageManager.getCurrentLanguage(this)) {
                    updateSelection(choices, choice.value)
                    LanguageManager.setLanguage(this, choice.value)
                }
            }
        }

        NavigationAnimations.showContent(
            findViewById<View>(R.id.languageSummary),
            findViewById(R.id.languageOptions)
        )
    }

    private fun languageChoice(cardId: Int, radioId: Int, value: String): LanguageChoice {
        return LanguageChoice(
            card = findViewById(cardId),
            indicator = findViewById(radioId),
            value = value
        )
    }

    private fun updateSelection(choices: List<LanguageChoice>, selectedValue: String) {
        choices.forEach { choice ->
            val selected = choice.value == selectedValue
            choice.card.isChecked = selected
            choice.indicator.isChecked = selected
        }
    }

    private fun finishWithAnimation() {
        NavigationAnimations.finish(this)
    }

    private data class LanguageChoice(
        val card: MaterialCardView,
        val indicator: MaterialRadioButton,
        val value: String
    )
}
