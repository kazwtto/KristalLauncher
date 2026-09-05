package kwz.love2d.launcher.util

import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.ColorDrawable
import android.util.TypedValue
import android.view.ContextThemeWrapper
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ListView
import android.widget.TextView
import androidx.annotation.AttrRes
import androidx.annotation.DrawableRes
import androidx.appcompat.app.AppCompatDelegate
import androidx.appcompat.widget.PopupMenu
import androidx.core.graphics.ColorUtils
import androidx.core.view.WindowCompat
import com.google.android.material.color.MaterialColors
import com.google.android.material.shape.Shapeable
import kwz.love2d.launcher.R
import java.lang.reflect.Method
import java.util.Collections
import java.util.WeakHashMap

object ThemeManager {

    const val THEME_SYSTEM = "system"
    const val THEME_LIGHT = "light"
    const val THEME_DARK = "dark"
    const val THEME_DELTARUNE = "deltarune"

    private const val PREF_NAME = "appearance_settings"
    private const val KEY_THEME = "app_theme"
    private const val KEY_ANIMATIONS = "animations_enabled"
    private const val KEY_DELTARUNE_AMOLED = "deltarune_amoled"
    private const val POPUP_TEXT_SIZE_SP = 12f

    private val supportedThemes = setOf(THEME_SYSTEM, THEME_LIGHT, THEME_DARK, THEME_DELTARUNE)

    private val appliedActivityThemes = Collections.synchronizedMap(WeakHashMap<Activity, String>())

    @Volatile
    private var pixelTypefacesInitialized = false

    @Volatile
    private var pixelTypefaces: PixelTypefaces? = null

    fun applySavedTheme(context: Context) {
        val mode = nightModeFor(getCurrentTheme(context))
        if (AppCompatDelegate.getDefaultNightMode() != mode) {
            AppCompatDelegate.setDefaultNightMode(mode)
        }
    }

    fun applyActivityTheme(activity: Activity) {
        val theme = getCurrentTheme(activity)
        activity.setTheme(
            when {
                theme != THEME_DELTARUNE -> R.style.Theme_KristalLauncher
                isDeltaruneAmoledEnabled(activity) -> R.style.Theme_KristalLauncher_Deltarune_Amoled
                else -> R.style.Theme_KristalLauncher_Deltarune
            }
        )
        appliedActivityThemes[activity] = themeFingerprint(activity)
    }

    fun ensureActivityTheme(activity: Activity): Boolean {
        val applied = appliedActivityThemes[activity] ?: return true
        if (applied == themeFingerprint(activity)) return true
        if (!activity.isFinishing && !activity.isDestroyed) activity.recreate()
        return false
    }

    fun setTheme(context: Context, theme: String) {
        require(theme in supportedThemes)

        preferences(context)
            .edit()
            .putString(KEY_THEME, theme)
            .commit()

        val targetMode = nightModeFor(theme)
        if (AppCompatDelegate.getDefaultNightMode() != targetMode) {
            AppCompatDelegate.setDefaultNightMode(targetMode)
        }
    }

    fun setDeltaruneAmoledEnabled(context: Context, enabled: Boolean) {
        preferences(context)
            .edit()
            .putBoolean(KEY_DELTARUNE_AMOLED, enabled)
            .commit()
    }

    fun isDeltaruneAmoledEnabled(context: Context): Boolean {
        return preferences(context).getBoolean(KEY_DELTARUNE_AMOLED, false)
    }

    fun applyStatusBarTheme(activity: Activity) {
        val backgroundColor = MaterialColors.getColor(
            activity,
            android.R.attr.colorBackground,
            activity.getColor(R.color.m3_bg_dark)
        )
        val useDarkIcons = ColorUtils.calculateLuminance(backgroundColor) > 0.5

        activity.window.statusBarColor = backgroundColor
        activity.window.navigationBarColor = backgroundColor
        WindowCompat.getInsetsController(activity.window, activity.window.decorView).apply {
            isAppearanceLightStatusBars = useDarkIcons
            isAppearanceLightNavigationBars = useDarkIcons
        }
    }

    fun applyThemeDecor(activity: Activity) {
        val decor = activity.window.decorView
        applyDeltaruneStyle(activity, decor)
        applyAmoledMainChrome(activity)
        decor.post {
            applyDeltaruneStyle(activity, decor)
            applyAmoledMainChrome(activity)
        }
    }


    private fun applyAmoledMainChrome(activity: Activity) {
        if (!isDeltaruneTheme(activity) || !isDeltaruneAmoledEnabled(activity)) return

        val bottomNavigationId = activity.resources.getIdentifier(
            "bottomNavigation",
            "id",
            activity.packageName
        )
        if (bottomNavigationId != 0) {
            activity.findViewById<View>(bottomNavigationId)?.let { bottomNavigation ->
                val applyBlackBackground = {
                    val black = ColorStateList.valueOf(Color.BLACK)
                    bottomNavigation.backgroundTintList = black
                    bottomNavigation.setBackgroundColor(Color.BLACK)
                    bottomNavigation.elevation = 0f
                    applyDeltaruneStyle(activity, bottomNavigation)
                }
                applyBlackBackground()
                bottomNavigation.post { applyBlackBackground() }
            }
        }

        val searchContainerId = activity.resources.getIdentifier(
            "searchContainer",
            "id",
            activity.packageName
        )
        if (searchContainerId != 0) {
            val searchContainer = activity.findViewById<View>(searchContainerId)
            if (searchContainer != null) {
                val outlineColor = MaterialColors.getColor(
                    activity,
                    com.google.android.material.R.attr.colorOutline,
                    activity.getColor(R.color.m3_outline)
                )
                val density: Float = activity.resources.displayMetrics.density
                val strokeWidth = (density + 0.5f).toInt().coerceAtLeast(1)
                searchContainer.background = GradientDrawable().apply {
                    setColor(Color.BLACK)
                    cornerRadius = 0f
                    setStroke(strokeWidth, outlineColor)
                }
            }
        }
    }

    fun themedContext(context: Context): Context {
        if (!isDeltaruneTheme(context)) return context
        return ContextThemeWrapper(
            context,
            if (isDeltaruneAmoledEnabled(context)) {
                R.style.Theme_KristalLauncher_Deltarune_Amoled
            } else {
                R.style.Theme_KristalLauncher_Deltarune
            }
        )
    }

    fun applyDialogTheme(dialog: Dialog) {
        if (!isDeltaruneTheme(dialog.context)) return

        val themed = themedContext(dialog.context)
        val amoled = isDeltaruneAmoledEnabled(dialog.context)
        val surfaceColor = if (amoled) {
            Color.BLACK
        } else {
            MaterialColors.getColor(
                themed,
                com.google.android.material.R.attr.colorSurface,
                dialog.context.getColor(R.color.m3_surface)
            )
        }
        val density = dialog.context.resources.displayMetrics.density
        val panelBackground = GradientDrawable().apply {
            setColor(surfaceColor)
            cornerRadius = 0f
            if (amoled) {
                setStroke((1f * density).toInt().coerceAtLeast(1), Color.WHITE)
            }
        }

        dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))

        val applyPanelStyle = {
            val panel = dialog.findViewById<View>(androidx.appcompat.R.id.parentPanel)
                ?: dialog.window?.decorView
            panel?.background = panelBackground
            panel?.clipToOutline = false
            dialog.window?.decorView?.let { applyDeltaruneStyle(dialog.context, it) }
        }

        applyPanelStyle()
        dialog.window?.decorView?.post { applyPanelStyle() }
    }

    fun applyPopupMenuTheme(context: Context, popupMenu: PopupMenu) {
        if (!isDeltaruneTheme(context)) return
        val listView = findPopupListView(popupMenu) ?: return
        listView.post {
            val typefaces = getPixelTypefaces(context)
            compactPopupTypography(listView, typefaces)
            applyDeltarunePopupBackground(context, listView)
        }
    }

    fun applyDeltaruneStyle(context: Context, root: View) {
        if (!isDeltaruneTheme(context)) return
        applyDeltaruneStyleRecursive(context, root, getPixelTypefaces(context))
    }

    @DrawableRes
    fun resolveDrawableResource(
        context: Context,
        @AttrRes attribute: Int,
        @DrawableRes fallback: Int
    ): Int {
        val value = TypedValue()
        return if (context.theme.resolveAttribute(attribute, value, true) && value.resourceId != 0) {
            value.resourceId
        } else {
            fallback
        }
    }

    fun isDeltaruneTheme(context: Context): Boolean {
        return getCurrentTheme(context) == THEME_DELTARUNE
    }


    fun getCurrentTheme(context: Context): String {
        val prefs = preferences(context)
        val stored = prefs.getString(KEY_THEME, THEME_SYSTEM) ?: THEME_SYSTEM
        val normalized = normalizeStoredTheme(stored)
        if (stored != normalized) prefs.edit().putString(KEY_THEME, normalized).apply()
        return normalized
    }

    fun getThemeDisplayName(context: Context): String = context.getString(
        when (getCurrentTheme(context)) {
            THEME_LIGHT -> R.string.theme_light
            THEME_DARK -> R.string.theme_dark
            THEME_DELTARUNE -> R.string.theme_deltarune
            else -> R.string.theme_device
        }
    )

    fun areAnimationsEnabled(context: Context): Boolean {
        return preferences(context).getBoolean(KEY_ANIMATIONS, true)
    }

    fun setAnimationsEnabled(context: Context, enabled: Boolean) {
        preferences(context)
            .edit()
            .putBoolean(KEY_ANIMATIONS, enabled)
            .apply()
    }

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

    private fun normalizeStoredTheme(theme: String): String = when {
        theme in supportedThemes -> theme
        theme.startsWith("delta") -> THEME_DELTARUNE
        else -> THEME_SYSTEM
    }

    private fun themeFingerprint(context: Context): String {
        val theme = getCurrentTheme(context)
        return if (theme == THEME_DELTARUNE) {
            "$theme:${isDeltaruneAmoledEnabled(context)}"
        } else {
            theme
        }
    }

    private fun nightModeFor(theme: String): Int = when (theme) {
        THEME_LIGHT -> AppCompatDelegate.MODE_NIGHT_NO
        THEME_DARK, THEME_DELTARUNE -> AppCompatDelegate.MODE_NIGHT_YES
        else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
    }

    private fun getPixelTypefaces(context: Context): PixelTypefaces? {
        if (pixelTypefacesInitialized) return pixelTypefaces

        synchronized(this) {
            if (!pixelTypefacesInitialized) {
                val fallback = loadTypeface(context, listOf("gamepad/fonts/main_mono.ttf"))
                val regular = loadTypeface(
                    context,
                    listOf("fonts/pixel_operator.ttf", "fonts/PixelOperator.ttf")
                ) ?: fallback
                val bold = loadTypeface(
                    context,
                    listOf("fonts/pixel_operator_bold.ttf", "fonts/PixelOperator-Bold.ttf")
                ) ?: regular?.let { Typeface.create(it, Typeface.BOLD) }
                val mono = loadTypeface(
                    context,
                    listOf("fonts/pixel_operator_mono.ttf", "fonts/PixelOperatorMono.ttf")
                ) ?: fallback ?: regular
                val monoBold = loadTypeface(
                    context,
                    listOf("fonts/pixel_operator_mono_bold.ttf", "fonts/PixelOperatorMono-Bold.ttf")
                ) ?: mono?.let { Typeface.create(it, Typeface.BOLD) }

                if (regular != null) {
                    pixelTypefaces = PixelTypefaces(
                        regular = regular,
                        bold = bold ?: Typeface.create(regular, Typeface.BOLD),
                        mono = mono ?: regular,
                        monoBold = monoBold ?: Typeface.create(mono ?: regular, Typeface.BOLD)
                    )
                }
                pixelTypefacesInitialized = true
            }
        }
        return pixelTypefaces
    }

    private fun loadTypeface(context: Context, candidates: List<String>): Typeface? {
        candidates.forEach { assetPath ->
            try {
                return Typeface.createFromAsset(context.assets, assetPath)
            } catch (_: RuntimeException) {
            }
        }
        return null
    }

    private fun applyDeltaruneStyleRecursive(
        context: Context,
        view: View,
        typefaces: PixelTypefaces?
    ) {
        squareDeltaruneShape(view)
        if (view is TextView && typefaces != null) {
            val style = view.typeface?.style ?: Typeface.NORMAL
            val bold = style and Typeface.BOLD != 0
            val metrics = context.resources.displayMetrics
            val compactTextThreshold = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 12f, metrics)
            val compactBoldThreshold = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 13.5f, metrics)
            val mono = view is Button || view.textSize < compactTextThreshold ||
                (bold && view.textSize <= compactBoldThreshold)

            view.typeface = when {
                mono && bold -> typefaces.monoBold
                mono -> typefaces.mono
                bold -> typefaces.bold
                else -> typefaces.regular
            }
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                applyDeltaruneStyleRecursive(context, view.getChildAt(index), typefaces)
            }
        }
    }

    private fun compactPopupTypography(
        view: View,
        typefaces: PixelTypefaces?
    ) {
        if (view is TextView) {
            view.setTextSize(TypedValue.COMPLEX_UNIT_SP, POPUP_TEXT_SIZE_SP)
            typefaces?.let {
                val bold = (view.typeface?.style ?: Typeface.NORMAL) and Typeface.BOLD != 0
                view.typeface = if (bold) it.monoBold else it.mono
            }
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                compactPopupTypography(view.getChildAt(index), typefaces)
            }
        }
    }

    private fun findPopupListView(popupMenu: PopupMenu): ListView? = runCatching {
        val helperField = PopupMenu::class.java.getDeclaredField("mPopup").apply { isAccessible = true }
        val helper = helperField.get(popupMenu) ?: return@runCatching null

        invokeNoArg(helper, "getListView")?.let { return@runCatching it as? ListView }
        val popup = invokeNoArg(helper, "getPopup") ?: runCatching {
            helper.javaClass.getDeclaredField("mPopup").apply { isAccessible = true }.get(helper)
        }.getOrNull()
        popup ?: return@runCatching null
        invokeNoArg(popup, "getListView") as? ListView
    }.getOrNull()

    private fun invokeNoArg(target: Any, methodName: String): Any? {
        val method = findMethod(target.javaClass, methodName) ?: return null
        method.isAccessible = true
        return method.invoke(target)
    }

    private fun findMethod(type: Class<*>, name: String): Method? {
        var current: Class<*>? = type
        while (current != null) {
            current.declaredMethods.firstOrNull {
                it.name == name && it.parameterTypes.isEmpty()
            }?.let { return it }
            current = current.superclass
        }
        return null
    }

    private fun applyDeltarunePopupBackground(context: Context, listView: ListView) {
        val surfaceColor = MaterialColors.getColor(
            themedContext(context),
            com.google.android.material.R.attr.colorSurface,
            context.getColor(R.color.m3_surface)
        )
        val background = GradientDrawable().apply {
            setColor(surfaceColor)
            cornerRadius = 0f
        }
        listView.background = background
        listView.dividerHeight = 0
        var currentParent = listView.parent
        while (currentParent is View) {
            val parentView = currentParent as View
            parentView.background = GradientDrawable().apply {
                setColor(surfaceColor)
                cornerRadius = 0f
            }
            currentParent = parentView.parent
        }
    }

    private fun squareDeltaruneShape(view: View) {
        if (view is Shapeable) {
            view.shapeAppearanceModel = view.shapeAppearanceModel
                .toBuilder()
                .setAllCornerSizes(0f)
                .build()
        }
        (view.background as? GradientDrawable)?.cornerRadius = 0f
    }

    private data class PixelTypefaces(
        val regular: Typeface,
        val bold: Typeface,
        val mono: Typeface,
        val monoBold: Typeface
    )
}
