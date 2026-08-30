package kwz.love2d.launcher.util

import android.content.Context
import android.content.res.Configuration
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import kwz.love2d.launcher.R
import java.util.Locale

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

    /**
     * Creates a context that resolves resources using the launcher's saved locale.
     *
     * The embedded LÖVE activity does not inherit AppCompat's per-app locale, so its
     * resources otherwise follow only the device locale.
     */
    fun createLocalizedContext(context: Context): Context {
        val language = getCurrentLanguage(context)
        if (language == LANGUAGE_SYSTEM) return context

        val configuration = Configuration(context.resources.configuration).apply {
            setLocale(Locale.forLanguageTag(language))
        }
        return context.createConfigurationContext(configuration)
    }

    /**
     * Resolves the language embedded in the virtual gamepad package.
     *
     * The app preference must win here. `applicationContext.resources` can still expose the
     * device configuration after AppCompat applies a per-app locale, so reading only its locale
     * made the in-game controls ignore an explicitly selected launcher language.
     */
    internal fun resolveGamepadLanguage(
        selectedLanguage: String,
        deviceLanguage: String?
    ): String {
        val selected = selectedLanguage.lowercase(Locale.ROOT)
        if (selected in SUPPORTED_GAMEPAD_LANGUAGES) return selected

        val systemLanguage = deviceLanguage
            ?.lowercase(Locale.ROOT)
            ?.substringBefore('-')
            ?.substringBefore('_')
        return systemLanguage?.takeIf { it in SUPPORTED_GAMEPAD_LANGUAGES } ?: "en"
    }

    private val SUPPORTED_GAMEPAD_LANGUAGES = setOf("pt", "en", "es")
}
