package kwz.love2d.launcher

import android.app.Activity
import android.app.Application
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import kwz.love2d.launcher.ui.LoveOverlayManager
import kwz.love2d.launcher.util.LanguageManager
import kwz.love2d.launcher.util.ThemeManager

class KristalApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        ThemeManager.applySavedTheme(this)
        LanguageManager.applySavedLanguage(this)

        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                if (activity is AppCompatActivity) {
                    ThemeManager.applyStatusBarTheme(activity)
                }
            }

            override fun onActivityStarted(activity: Activity) {
                if (activity is AppCompatActivity) {
                    if (!ThemeManager.ensureActivityTheme(activity)) return
                    ThemeManager.applyStatusBarTheme(activity)
                    ThemeManager.applyThemeDecor(activity)
                }
            }

            override fun onActivityResumed(activity: Activity) {
                if (activity is AppCompatActivity) {
                    ThemeManager.applyStatusBarTheme(activity)
                    ThemeManager.applyThemeDecor(activity)
                }

                try {
                    if (activity.javaClass.name == "org.love2d.android.GameActivity") {
                        LoveOverlayManager.attachOverlay(activity)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            override fun onActivityPaused(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
    }
}
