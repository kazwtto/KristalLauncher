package kwz.love2d.launcher.util

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import kwz.love2d.launcher.R

object LanguageManager {

    const val LANGUAGE_SYSTEM = "system"

    private const val PREF_NAME = "language_settings"
    private const val KEY_LANG = "app_language"

    fun setLanguage(context: Context, langCode: String) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_LANG, langCode).apply()

        applySavedLanguage(context)
    }

    fun getCurrentLanguage(context: Context): String {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_LANG, LANGUAGE_SYSTEM) ?: LANGUAGE_SYSTEM
    }

    fun applySavedLanguage(context: Context) {
        val language = getCurrentLanguage(context)
        val appLocales = if (language == LANGUAGE_SYSTEM) {
            LocaleListCompat.getEmptyLocaleList()
        } else {
            LocaleListCompat.forLanguageTags(language)
        }
        if (AppCompatDelegate.getApplicationLocales() != appLocales) {
            AppCompatDelegate.setApplicationLocales(appLocales)
        }
    }

    fun getLanguageDisplayName(context: Context): String {
        return when (getCurrentLanguage(context)) {
            "en" -> context.getString(R.string.lang_en)
            "es" -> context.getString(R.string.lang_es)
            "pt" -> context.getString(R.string.lang_pt)
            else -> context.getString(R.string.lang_device)
        }
    }
}
