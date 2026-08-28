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
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import kwz.love2d.launcher.R

object LoveOverlayManager {

    fun attachOverlay(activity: Activity) {
        try {
            val decorView = activity.window?.decorView as? ViewGroup ?: return

            decorView.post {
                try {
                    if (decorView.findViewWithTag<View>("love_overlay_container") != null) return@post

                    val density = activity.resources.displayMetrics.density

                    val overlayContainer = FrameLayout(activity).apply {
                        tag = "love_overlay_container"
                        setBackgroundColor(Color.parseColor("#99000000"))
                        visibility = View.GONE
                        isClickable = true
                        isFocusable = true
                        elevation = 100f * density
                    }

                    // Centered minimal overlay panel
                    val menuPanel = LinearLayout(activity).apply {
                        orientation = LinearLayout.VERTICAL
                        setPadding(
                            (24 * density).toInt(),
                            (24 * density).toInt(),
                            (24 * density).toInt(),
                            (24 * density).toInt()
                        )
                        // Keep the background transparent for the minimal layout.
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
                        text = activity.getString(R.string.overlay_menu_title)
                        setTextColor(Color.parseColor("#E3E2E6"))
                        textSize = 22f
                        gravity = Gravity.CENTER
                        typeface = Typeface.DEFAULT_BOLD
                        setPadding(0, 0, 0, (24 * density).toInt())
                    }

                    val btnExit = TextView(activity).apply {
                        text = activity.getString(R.string.overlay_exit_game)
                        setTextColor(Color.parseColor("#FFB4AB"))
                        textSize = 16f
                        gravity = Gravity.CENTER
                        typeface = Typeface.DEFAULT_BOLD
                        background = GradientDrawable().apply {
                            setColor(Color.parseColor("#410002"))
                            cornerRadius = 24 * density
                        }
                        setPadding(0, (16 * density).toInt(), 0, (16 * density).toInt())
                        setOnClickListener {
                            activity.finish()
                        }
                    }

                    val btnResume = TextView(activity).apply {
                        text = activity.getString(R.string.overlay_resume_game)
                        setTextColor(Color.parseColor("#E3E2E6"))
                        textSize = 16f
                        gravity = Gravity.CENTER
                        typeface = Typeface.DEFAULT_BOLD
                        background = GradientDrawable().apply {
                            setColor(Color.parseColor("#44474F"))
                            cornerRadius = 24 * density
                        }
                        setPadding(0, (16 * density).toInt(), 0, (16 * density).toInt())
                        val layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            setMargins(0, (12 * density).toInt(), 0, 0)
                        }
                        this.layoutParams = layoutParams
                        setOnClickListener {
                            hideOverlay(overlayContainer, menuPanel)
                        }
                    }

                    menuPanel.addView(titleText)
                    menuPanel.addView(btnExit)
                    menuPanel.addView(btnResume)

                    overlayContainer.addView(menuPanel, panelParams)

                    overlayContainer.setOnClickListener {
                        hideOverlay(overlayContainer, menuPanel)
                    }

                    menuPanel.setOnClickListener { /* Consume panel touches. */ }

                    decorView.addView(overlayContainer, FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    ))

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
            container.alpha = 1f
            panel.scaleX = 1f
            panel.scaleY = 1f
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hideOverlay(container: View, panel: View) {
        try {
            container.animate().cancel()
            panel.animate().cancel()
            container.alpha = 1f
            panel.scaleX = 1f
            panel.scaleY = 1f
            container.visibility = View.GONE
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private open class WindowCallbackAdapter(private val wrapped: Window.Callback) : Window.Callback by wrapped {
        override fun dispatchTouchEvent(event: MotionEvent): Boolean {
            return wrapped.dispatchTouchEvent(event)
        }
        
        override fun dispatchKeyEvent(event: KeyEvent): Boolean {
            return wrapped.dispatchKeyEvent(event)
        }
    }
}
