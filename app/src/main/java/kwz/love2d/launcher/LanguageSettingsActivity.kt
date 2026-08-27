package kwz.love2d.launcher

import android.os.Bundle
import android.view.View
import android.widget.ImageView
import android.widget.RadioGroup
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import kwz.love2d.launcher.util.LanguageManager
import kwz.love2d.launcher.util.NavigationAnimations

class LanguageSettingsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_language_settings)

        findViewById<ImageView>(R.id.btnBack).setOnClickListener { finishWithAnimation() }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = finishWithAnimation()
        })

        val languageOptions = findViewById<RadioGroup>(R.id.languageOptions)
        val checkedId = when (LanguageManager.getCurrentLanguage(this)) {
            "pt" -> R.id.languagePortuguese
            "en" -> R.id.languageEnglish
            "es" -> R.id.languageSpanish
            else -> R.id.languageDevice
        }
        languageOptions.check(checkedId)
        languageOptions.setOnCheckedChangeListener { _, id ->
            val language = when (id) {
                R.id.languagePortuguese -> "pt"
                R.id.languageEnglish -> "en"
                R.id.languageSpanish -> "es"
                else -> LanguageManager.LANGUAGE_SYSTEM
            }
            if (language != LanguageManager.getCurrentLanguage(this)) {
                LanguageManager.setLanguage(this, language)
            }
        }

        NavigationAnimations.revealSequentially(
            this,
            findViewById<View>(R.id.languageIntroCard),
            languageOptions
        )
    }

    private fun finishWithAnimation() {
        NavigationAnimations.finish(this)
    }
}
