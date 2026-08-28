package kwz.love2d.launcher

import android.os.Bundle
import android.widget.ImageView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButtonToggleGroup
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

        val languageOptions = findViewById<MaterialButtonToggleGroup>(R.id.languageOptions)
        val checkedId = when (LanguageManager.getCurrentLanguage(this)) {
            "pt" -> R.id.languagePortuguese
            "en" -> R.id.languageEnglish
            "es" -> R.id.languageSpanish
            else -> R.id.languageDevice
        }
        languageOptions.check(checkedId)
        languageOptions.addOnButtonCheckedListener { _, id, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
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

    }

    private fun finishWithAnimation() {
        NavigationAnimations.finish(this)
    }
}
