package kwz.love2d.launcher.ui

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import kwz.love2d.launcher.R
import kwz.love2d.launcher.util.LanguageManager
import kwz.love2d.launcher.util.ThemeManager

object LoveOverlayManager {

    fun attachOverlay(activity: Activity) {
        try {
            val decorView = activity.window?.decorView as? ViewGroup ?: return

            decorView.post {
                try {
                    if (decorView.findViewWithTag<View>("love_overlay_container") != null) return@post

                    val density = activity.resources.displayMetrics.density
                    val localizedContext = LanguageManager.createLocalizedContext(activity)
                    val deltarune = ThemeManager.isDeltaruneTheme(activity)

                    val overlayContainer = FrameLayout(activity).apply {
                        tag = "love_overlay_container"
                        setBackgroundColor(Color.parseColor("#99000000"))
                        visibility = View.GONE
                        isClickable = true
                        isFocusable = true
                        elevation = 100f * density
                    }

                    val menuPanel = LinearLayout(activity).apply {
                        orientation = LinearLayout.VERTICAL
                        setPadding(
                            (24 * density).toInt(),
                            (24 * density).toInt(),
                            (24 * density).toInt(),
                            (24 * density).toInt()
                        )
                        background = null
                        elevation = 0f
                    }

                    val maxWidthPx = (320 * density).toInt()
                    val panelParams = FrameLayout.LayoutParams(
                        maxWidthPx,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.CENTER
                    }

                    val titleText = TextView(activity).apply {
                        text = localizedContext.getString(R.string.overlay_menu_title)
                        setTextColor(Color.parseColor("#E3E2E6"))
                        textSize = 22f
                        gravity = Gravity.CENTER
                        typeface = Typeface.DEFAULT_BOLD
                        setPadding(0, 0, 0, (24 * density).toInt())
                    }

                    val btnExit = TextView(activity).apply {
                        text = localizedContext.getString(R.string.overlay_exit_game)
                        setTextColor(Color.parseColor("#FFB4AB"))
                        textSize = 16f
                        gravity = Gravity.CENTER
                        typeface = Typeface.DEFAULT_BOLD
                        background = GradientDrawable().apply {
                            setColor(Color.parseColor("#410002"))
                            cornerRadius = if (deltarune) 0f else 24 * density
                        }
                        setPadding(0, (16 * density).toInt(), 0, (16 * density).toInt())
                        setOnClickListener { activity.finish() }
                    }

                    val btnResume = TextView(activity).apply {
                        text = localizedContext.getString(R.string.overlay_resume_game)
                        setTextColor(Color.parseColor("#E3E2E6"))
                        textSize = 16f
                        gravity = Gravity.CENTER
                        typeface = Typeface.DEFAULT_BOLD
                        background = GradientDrawable().apply {
                            setColor(Color.parseColor("#44474F"))
                            cornerRadius = if (deltarune) 0f else 24 * density
                        }
                        setPadding(0, (16 * density).toInt(), 0, (16 * density).toInt())
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            setMargins(0, (12 * density).toInt(), 0, 0)
                        }
                        setOnClickListener { hideOverlay(overlayContainer, menuPanel) }
                    }

                    menuPanel.addView(titleText)
                    menuPanel.addView(btnExit)
                    menuPanel.addView(btnResume)
                    if (deltarune) {
                        ThemeManager.applyDeltaruneStyle(activity, menuPanel)
                        menuPanel.post { ThemeManager.applyDeltaruneStyle(activity, menuPanel) }
                    }

                    overlayContainer.addView(menuPanel, panelParams)
                    overlayContainer.setOnClickListener { hideOverlay(overlayContainer, menuPanel) }
                    menuPanel.setOnClickListener { }

                    decorView.addView(
                        overlayContainer,
                        FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.MATCH_PARENT,
                            FrameLayout.LayoutParams.MATCH_PARENT
                        )
                    )

                    val originalCallback = activity.window.callback
                    activity.window.callback = object : WindowCallbackAdapter(originalCallback) {
                        override fun dispatchKeyEvent(event: KeyEvent): Boolean {
                            if (event.keyCode == KeyEvent.KEYCODE_BACK) {
                                if (event.action == KeyEvent.ACTION_UP) {
                                    if (overlayContainer.visibility == View.VISIBLE) {
                                        hideOverlay(overlayContainer, menuPanel)
                                    } else {
                                        showOverlay(overlayContainer, menuPanel)
                                    }
                                }
                                return true
                            }
                            return super.dispatchKeyEvent(event)
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun showOverlay(container: View, panel: View) {
        try {
            if (container.visibility == View.VISIBLE) return
            container.animate().cancel()
            panel.animate().cancel()
            container.visibility = View.VISIBLE
            if (!ThemeManager.areAnimationsEnabled(container.context)) {
                container.alpha = 1f
                panel.scaleX = 1f
                panel.scaleY = 1f
                return
            }
            container.alpha = 0f
            container.animate().alpha(1f).setDuration(150).start()

            panel.scaleX = 0.8f
            panel.scaleY = 0.8f
            panel.animate()
                .scaleX(1f)
                .scaleY(1f)
                .setDuration(250)
                .setInterpolator(OvershootInterpolator(1.2f))
                .start()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hideOverlay(container: View, panel: View) {
        try {
            container.animate().cancel()
            panel.animate().cancel()
            if (!ThemeManager.areAnimationsEnabled(container.context)) {
                container.alpha = 1f
                panel.scaleX = 1f
                panel.scaleY = 1f
                container.visibility = View.GONE
                return
            }
            panel.animate()
                .scaleX(0.8f)
                .scaleY(0.8f)
                .setDuration(150)
                .setInterpolator(AccelerateDecelerateInterpolator())
                .start()

            container.animate()
                .alpha(0f)
                .setDuration(150)
                .withEndAction { container.visibility = View.GONE }
                .start()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private open class WindowCallbackAdapter(private val wrapped: Window.Callback) : Window.Callback by wrapped {
        override fun dispatchTouchEvent(event: MotionEvent): Boolean = wrapped.dispatchTouchEvent(event)
        override fun dispatchKeyEvent(event: KeyEvent): Boolean = wrapped.dispatchKeyEvent(event)
    }
}
