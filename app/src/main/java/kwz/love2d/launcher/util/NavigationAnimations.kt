package kwz.love2d.launcher.util

import android.app.Activity
import android.content.Intent

object NavigationAnimations {

    @Suppress("DEPRECATION")
    fun start(activity: Activity, intent: Intent) {
        activity.startActivity(intent)
        activity.overridePendingTransition(0, 0)
    }

    @Suppress("DEPRECATION")
    fun finish(activity: Activity) {
        activity.finish()
        activity.overridePendingTransition(0, 0)
    }
}
