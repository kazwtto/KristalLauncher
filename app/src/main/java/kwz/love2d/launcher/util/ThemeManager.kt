package kwz.love2d.launcher.util

import android.app.Activity
import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.graphics.ColorUtils
import androidx.core.view.WindowCompat
import com.google.android.material.color.MaterialColors
import kwz.love2d.launcher.R

object ThemeManager {

    const val THEME_SYSTEM = "system"
    const val THEME_LIGHT = "light"
    const val THEME_DARK = "dark"

    private const val PREF_NAME = "appearance_settings"
    private const val KEY_THEME = "app_theme"
    private const val KEY_ANIMATIONS = "animations_enabled"

    fun applySavedTheme(context: Context) {
        val mode = when (getCurrentTheme(context)) {
            THEME_LIGHT -> AppCompatDelegate.MODE_NIGHT_NO
            THEME_DARK -> AppCompatDelegate.MODE_NIGHT_YES
            else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
        }
        if (AppCompatDelegate.getDefaultNightMode() != mode) {
            AppCompatDelegate.setDefaultNightMode(mode)
        }
    }

    fun setTheme(context: Context, theme: String) {
        require(theme in setOf(THEME_SYSTEM, THEME_LIGHT, THEME_DARK))
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_THEME, theme)
            .apply()
        applySavedTheme(context)
    }

    fun applyStatusBarTheme(activity: Activity) {
        val backgroundColor = MaterialColors.getColor(
            activity,
            android.R.attr.colorBackground,
            activity.getColor(R.color.m3_bg_dark)
        )
        activity.window.statusBarColor = backgroundColor
        WindowCompat.getInsetsController(activity.window, activity.window.decorView)
            .isAppearanceLightStatusBars = ColorUtils.calculateLuminance(backgroundColor) > 0.5
    }

    fun getCurrentTheme(context: Context): String {
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .getString(KEY_THEME, THEME_SYSTEM)
            ?: THEME_SYSTEM
    }

    fun getThemeDisplayName(context: Context): String = context.getString(
        when (getCurrentTheme(context)) {
            THEME_LIGHT -> R.string.theme_light
            THEME_DARK -> R.string.theme_dark
            else -> R.string.theme_device
        }
    )

    fun areAnimationsEnabled(context: Context): Boolean {
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_ANIMATIONS, true)
    }

    fun setAnimationsEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ANIMATIONS, enabled)
            .apply()
    }
}
