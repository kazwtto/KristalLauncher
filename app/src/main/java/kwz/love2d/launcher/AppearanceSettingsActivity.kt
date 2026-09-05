package kwz.love2d.launcher

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView
import com.google.android.material.color.MaterialColors
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.radiobutton.MaterialRadioButton
import kwz.love2d.launcher.ui.DeltaruneSquareSwitch
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager

class AppearanceSettingsActivity : AppCompatActivity() {

    private var applyingTheme = false

    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeManager.applyActivityTheme(this)
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_appearance_settings)

        findViewById<ImageView>(R.id.btnBack).setOnClickListener { finishWithAnimation() }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = finishWithAnimation()
        })

        val deltaruneOptions = findViewById<LinearLayout>(R.id.deltaruneAmoledOptions)
        val deltaruneAmoledSwitch = findViewById<DeltaruneSquareSwitch>(R.id.switchDeltaruneAmoled).apply {
            setChecked(ThemeManager.isDeltaruneAmoledEnabled(this@AppearanceSettingsActivity))
            setOnCheckedChangeListener { _, enabled ->
                if (enabled == ThemeManager.isDeltaruneAmoledEnabled(this@AppearanceSettingsActivity)) return@setOnCheckedChangeListener
                beginThemeApply {
                    ThemeManager.setDeltaruneAmoledEnabled(this@AppearanceSettingsActivity, enabled)
                    recreateIfAlive()
                }
            }
        }
        deltaruneOptions.setOnClickListener { deltaruneAmoledSwitch.toggle() }

        val themeChoices = listOf(
            themeChoice(R.id.themeDeviceCard, R.id.themeDevice, ThemeManager.THEME_SYSTEM),
            themeChoice(R.id.themeLightCard, R.id.themeLight, ThemeManager.THEME_LIGHT),
            themeChoice(R.id.themeDarkCard, R.id.themeDark, ThemeManager.THEME_DARK),
            themeChoice(
                R.id.themeDeltaruneCard,
                R.id.themeDeltarune,
                ThemeManager.THEME_DELTARUNE,
                R.id.themeDeltaruneRow
            )
        )

        fun updateThemeSelection(selectedValue: String) {
            updateSelection(themeChoices, selectedValue)
            deltaruneOptions.visibility = if (selectedValue == ThemeManager.THEME_DELTARUNE) {
                View.VISIBLE
            } else {
                View.GONE
            }
        }

        updateThemeSelection(ThemeManager.getCurrentTheme(this))
        themeChoices.forEach { choice ->
            choice.clickTarget.setOnClickListener {
                if (applyingTheme || choice.value == ThemeManager.getCurrentTheme(this)) return@setOnClickListener
                updateThemeSelection(choice.value)
                beginThemeApply {
                    ThemeManager.setTheme(this, choice.value)
                    recreateIfAlive()
                }
            }
        }

        val animationsSwitch = findViewById<MaterialSwitch>(R.id.switchAnimations).apply {
            isChecked = ThemeManager.areAnimationsEnabled(this@AppearanceSettingsActivity)
            setOnCheckedChangeListener { _, enabled ->
                ThemeManager.setAnimationsEnabled(this@AppearanceSettingsActivity, enabled)
            }
        }
        val animationsDeltaruneSwitch = findViewById<DeltaruneSquareSwitch>(R.id.switchAnimationsDeltarune).apply {
            setChecked(ThemeManager.areAnimationsEnabled(this@AppearanceSettingsActivity))
            setOnCheckedChangeListener { _, enabled ->
                ThemeManager.setAnimationsEnabled(this@AppearanceSettingsActivity, enabled)
            }
        }
        val isDeltarune = ThemeManager.isDeltaruneTheme(this)
        animationsSwitch.visibility = if (isDeltarune) View.GONE else View.VISIBLE
        animationsDeltaruneSwitch.visibility = if (isDeltarune) View.VISIBLE else View.GONE

        val motionCard = findViewById<View>(R.id.motionCard)
        motionCard.setOnClickListener {
            if (isDeltarune) animationsDeltaruneSwitch.toggle() else animationsSwitch.toggle()
        }

        NavigationAnimations.showContent(
            findViewById<View>(R.id.appearanceSummary),
            findViewById(R.id.themeOptions),
            motionCard
        )
    }

    private fun themeChoice(
        cardId: Int,
        radioId: Int,
        value: String,
        clickTargetId: Int? = null
    ): ThemeChoice {
        val card = findViewById<MaterialCardView>(cardId)
        return ThemeChoice(
            card = card,
            indicator = findViewById(radioId),
            clickTarget = if (clickTargetId != null) findViewById<View>(clickTargetId) else card,
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

    private fun beginThemeApply(action: () -> Unit) {
        if (applyingTheme) return
        applyingTheme = true
        val overlay = createThemeLoadingOverlay()
        val decor = window.decorView as? ViewGroup
        decor?.addView(
            overlay,
            ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        )
        overlay.bringToFront()
        overlay.postDelayed(action, 48L)
    }

    private fun createThemeLoadingOverlay(): View {
        val density = resources.displayMetrics.density
        val themed = ThemeManager.themedContext(this)
        val surface = MaterialColors.getColor(
            themed,
            com.google.android.material.R.attr.colorSurface,
            getColor(R.color.m3_surface)
        )
        val onSurface = MaterialColors.getColor(
            themed,
            com.google.android.material.R.attr.colorOnSurface,
            getColor(R.color.m3_on_surface)
        )
        val outline = MaterialColors.getColor(
            themed,
            com.google.android.material.R.attr.colorOutline,
            getColor(R.color.m3_outline)
        )

        return FrameLayout(this).apply {
            setBackgroundColor(Color.argb(150, 0, 0, 0))
            isClickable = true
            isFocusable = true
            elevation = 1000f * density

            val panel = LinearLayout(this@AppearanceSettingsActivity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(20), dp(16), dp(20), dp(16))
                background = GradientDrawable().apply {
                    setColor(surface)
                    cornerRadius = if (ThemeManager.isDeltaruneTheme(this@AppearanceSettingsActivity)) 0f else dp(16).toFloat()
                    setStroke(dp(1), outline)
                }

                addView(ProgressBar(this@AppearanceSettingsActivity), LinearLayout.LayoutParams(dp(32), dp(32)))
                addView(TextView(this@AppearanceSettingsActivity).apply {
                    text = getString(R.string.loading_game)
                    setTextColor(onSurface)
                    textSize = 14f
                    setPadding(dp(12), 0, 0, 0)
                })
            }
            addView(
                panel,
                FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT).apply {
                    gravity = Gravity.CENTER
                }
            )
            ThemeManager.applyDeltaruneStyle(this@AppearanceSettingsActivity, panel)
        }
    }

    private fun recreateIfAlive() {
        if (!isFinishing && !isDestroyed) recreate()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun finishWithAnimation() {
        NavigationAnimations.finish(this)
    }

    private data class ThemeChoice(
        val card: MaterialCardView,
        val indicator: MaterialRadioButton,
        val clickTarget: View,
        val value: String
    )
}
