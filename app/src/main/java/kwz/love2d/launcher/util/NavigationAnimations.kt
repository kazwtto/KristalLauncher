package kwz.love2d.launcher.util

import android.app.Activity
import android.app.ActivityOptions
import android.animation.ValueAnimator
import android.content.Intent
import android.os.Build
import android.view.View
import com.google.android.material.transition.platform.MaterialSharedAxis

object NavigationAnimations {

    fun prepare(activity: Activity) {
        if (!shouldAnimate(activity)) return

        activity.window.enterTransition = sharedAxis(forward = true)
        activity.window.exitTransition = sharedAxis(forward = true)
        activity.window.reenterTransition = sharedAxis(forward = false)
        activity.window.returnTransition = sharedAxis(forward = false)
        activity.window.allowEnterTransitionOverlap = true
        activity.window.allowReturnTransitionOverlap = true
    }

    @Suppress("DEPRECATION")
    fun start(activity: Activity, intent: Intent) {
        if (shouldAnimate(activity)) {
            prepare(activity)
            val options = ActivityOptions.makeSceneTransitionAnimation(activity)
            activity.startActivity(intent, options.toBundle())
        } else {
            activity.startActivity(intent)
            activity.overridePendingTransition(0, 0)
        }
    }

    @Suppress("DEPRECATION")
    fun finish(activity: Activity) {
        if (shouldAnimate(activity)) {
            activity.finishAfterTransition()
        } else {
            activity.finish()
            activity.overridePendingTransition(0, 0)
        }
    }

    fun showContent(vararg views: View) {
        views.forEach { view ->
            view.animate().cancel()
            view.alpha = 1f
            view.translationY = 0f
        }
    }

    private fun sharedAxis(forward: Boolean): MaterialSharedAxis {
        return MaterialSharedAxis(MaterialSharedAxis.X, forward).apply {
            duration = PAGE_TRANSITION_DURATION_MS
        }
    }

    private fun shouldAnimate(activity: Activity): Boolean {
        if (!ThemeManager.areAnimationsEnabled(activity)) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O || ValueAnimator.areAnimatorsEnabled()
    }

    private const val PAGE_TRANSITION_DURATION_MS = 240L
}
