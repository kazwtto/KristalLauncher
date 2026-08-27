package kwz.love2d.launcher.util

import android.app.Activity
import android.animation.ValueAnimator
import android.content.Intent
import android.os.Build
import android.view.View
import android.view.animation.DecelerateInterpolator
import kwz.love2d.launcher.R

object NavigationAnimations {

    @Suppress("DEPRECATION")
    fun start(activity: Activity, intent: Intent) {
        activity.startActivity(intent)
        if (shouldAnimate(activity)) {
            activity.overridePendingTransition(R.anim.activity_enter, R.anim.activity_exit)
        } else {
            activity.overridePendingTransition(0, 0)
        }
    }

    @Suppress("DEPRECATION")
    fun finish(activity: Activity) {
        activity.finish()
        if (shouldAnimate(activity)) {
            activity.overridePendingTransition(R.anim.activity_return_enter, R.anim.activity_return_exit)
        } else {
            activity.overridePendingTransition(0, 0)
        }
    }

    fun revealSequentially(activity: Activity, vararg views: View) {
        if (!shouldAnimate(activity)) return

        val offset = 12f * activity.resources.displayMetrics.density
        views.forEachIndexed { index, view ->
            view.alpha = 0f
            view.translationY = offset
            view.animate()
                .alpha(1f)
                .translationY(0f)
                .setStartDelay(index * 45L)
                .setDuration(260L)
                .setInterpolator(DecelerateInterpolator(1.8f))
                .start()
        }
    }

    private fun shouldAnimate(activity: Activity): Boolean {
        if (!ThemeManager.areAnimationsEnabled(activity)) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O || ValueAnimator.areAnimatorsEnabled()
    }
}
