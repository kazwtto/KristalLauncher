package kwz.love2d.launcher

import android.os.Bundle
import android.widget.ImageView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButtonToggleGroup
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager

class AppearanceSettingsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_appearance_settings)

        findViewById<ImageView>(R.id.btnBack).setOnClickListener { finishWithAnimation() }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = finishWithAnimation()
        })

        val themeOptions = findViewById<MaterialButtonToggleGroup>(R.id.themeOptions)
        val checkedId = when (ThemeManager.getCurrentTheme(this)) {
            ThemeManager.THEME_LIGHT -> R.id.themeLight
            ThemeManager.THEME_DARK -> R.id.themeDark
            else -> R.id.themeDevice
        }
        themeOptions.check(checkedId)
        themeOptions.addOnButtonCheckedListener { _, id, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            val theme = when (id) {
                R.id.themeLight -> ThemeManager.THEME_LIGHT
                R.id.themeDark -> ThemeManager.THEME_DARK
                else -> ThemeManager.THEME_SYSTEM
            }
            if (theme != ThemeManager.getCurrentTheme(this)) {
                ThemeManager.setTheme(this, theme)
            }
        }

    }

    private fun finishWithAnimation() {
        NavigationAnimations.finish(this)
    }
}
