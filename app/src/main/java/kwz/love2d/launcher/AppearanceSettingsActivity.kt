package kwz.love2d.launcher

import android.os.Bundle
import android.view.View
import android.widget.ImageView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.radiobutton.MaterialRadioButton
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager

class AppearanceSettingsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_appearance_settings)

        findViewById<ImageView>(R.id.btnBack).setOnClickListener { finishWithAnimation() }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = finishWithAnimation()
        })

        val themeChoices = listOf(
            themeChoice(R.id.themeDeviceCard, R.id.themeDevice, ThemeManager.THEME_SYSTEM),
            themeChoice(R.id.themeLightCard, R.id.themeLight, ThemeManager.THEME_LIGHT),
            themeChoice(R.id.themeDarkCard, R.id.themeDark, ThemeManager.THEME_DARK)
        )
        updateSelection(themeChoices, ThemeManager.getCurrentTheme(this))
        themeChoices.forEach { choice ->
            choice.card.setOnClickListener {
                if (choice.value != ThemeManager.getCurrentTheme(this)) {
                    updateSelection(themeChoices, choice.value)
                    ThemeManager.setTheme(this, choice.value)
                }
            }
        }

        val animationsSwitch = findViewById<MaterialSwitch>(R.id.switchAnimations).apply {
            isChecked = ThemeManager.areAnimationsEnabled(this@AppearanceSettingsActivity)
            setOnCheckedChangeListener { _, enabled ->
                ThemeManager.setAnimationsEnabled(this@AppearanceSettingsActivity, enabled)
            }
        }
        val motionCard = findViewById<View>(R.id.motionCard)
        motionCard.setOnClickListener { animationsSwitch.toggle() }

        NavigationAnimations.showContent(
            findViewById<View>(R.id.appearanceSummary),
            findViewById(R.id.themeOptions),
            motionCard
        )
    }

    private fun themeChoice(cardId: Int, radioId: Int, value: String): ThemeChoice {
        return ThemeChoice(
            card = findViewById(cardId),
            indicator = findViewById(radioId),
            value = value
        )
    }

    private fun updateSelection(choices: List<ThemeChoice>, selectedValue: String) {
        choices.forEach { choice ->
            val selected = choice.value == selectedValue
            choice.card.isChecked = selected
            choice.indicator.isChecked = selected
        }
    }

    private fun finishWithAnimation() {
        NavigationAnimations.finish(this)
    }

    private data class ThemeChoice(
        val card: MaterialCardView,
        val indicator: MaterialRadioButton,
        val value: String
    )
}
