package kwz.love2d.launcher.ui

import android.animation.ValueAnimator
import android.content.Context
import android.content.res.Configuration
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.view.animation.AnimationSet
import android.view.animation.DecelerateInterpolator
import android.view.animation.TranslateAnimation
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.ViewFlipper
import androidx.core.content.ContextCompat
import com.google.android.material.button.MaterialButton
import com.google.android.material.color.MaterialColors
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.R
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.showThemed

object AddGamesTutorialDialog {

    fun show(context: Context, folderAlreadySelected: Boolean, onChooseFolder: () -> Unit) {
        val view = LayoutInflater.from(context).inflate(R.layout.dialog_add_games_tutorial, null)
        ThemeManager.applyDeltaruneStyle(context, view)
        val root = view.findViewById<LinearLayout>(R.id.tutorialRoot)
        val header = view.findViewById<LinearLayout>(R.id.tutorialHeader)
        val flipper = view.findViewById<ViewFlipper>(R.id.tutorialFlipper)
        val stepLabel = view.findViewById<TextView>(R.id.tvTutorialStep)
        val footer = view.findViewById<LinearLayout>(R.id.tutorialFooter)
        val dots = view.findViewById<LinearLayout>(R.id.tutorialDots)
        val buttonRow = view.findViewById<LinearLayout>(R.id.tutorialButtonRow)
        val previousButton = view.findViewById<MaterialButton>(R.id.btnTutorialPrevious)
        val nextButton = view.findViewById<MaterialButton>(R.id.btnTutorialNext)
        val closeButton = view.findViewById<ImageButton>(R.id.btnTutorialClose)
        val pageCount = flipper.childCount
        val wideLayout = context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE ||
            context.resources.configuration.screenWidthDp >= 600
        val animationsEnabled = ThemeManager.areAnimationsEnabled(context) &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || ValueAnimator.areAnimatorsEnabled())

        require(pageCount > 0) { "Tutorial must contain at least one page" }

        if (wideLayout) {
            configureWideLayout(
                context,
                root,
                header,
                flipper,
                stepLabel,
                footer,
                dots,
                buttonRow,
                closeButton
            )
        }

        val dialog = MaterialAlertDialogBuilder(context)
            .setView(view)
            .create()

        var page = 0

        fun updatePage(direction: Int = 0) {
            configurePageAnimation(context, flipper, direction, animationsEnabled)
            flipper.displayedChild = page
            stepLabel.text = context.getString(R.string.tutorial_step_counter, page + 1, pageCount)
            previousButton.visibility = if (page == 0) View.INVISIBLE else View.VISIBLE

            if (page == pageCount - 1) {
                if (folderAlreadySelected) {
                    nextButton.setText(R.string.tutorial_done)
                    nextButton.icon = null
                } else {
                    nextButton.setText(R.string.tutorial_choose_folder_now)
                    nextButton.setIconResource(
                        ThemeManager.resolveDrawableResource(
                            context,
                            R.attr.kristalIconFolder,
                            R.drawable.ic_folder
                        )
                    )
                }
            } else {
                nextButton.setText(R.string.tutorial_next)
                nextButton.setIconResource(
                    ThemeManager.resolveDrawableResource(
                        context,
                        R.attr.kristalIconChevronRight,
                        R.drawable.ic_chevron_right
                    )
                )
            }

            renderDots(context, dots, page, pageCount)
        }

        closeButton.setOnClickListener { dialog.dismiss() }
        previousButton.setOnClickListener {
            if (page > 0) {
                page--
                updatePage(-1)
            }
        }
        nextButton.setOnClickListener {
            if (page < pageCount - 1) {
                page++
                updatePage(1)
            } else {
                dialog.dismiss()
                if (!folderAlreadySelected) {
                    onChooseFolder()
                }
            }
        }

        dialog.setOnShowListener {
            val metrics = context.resources.displayMetrics
            val maxWidth = if (wideLayout) context.dp(920) else context.dp(680)
            val width = maxWidth.coerceAtMost((metrics.widthPixels * 0.96f).toInt())
            dialog.window?.setLayout(width, ViewGroup.LayoutParams.WRAP_CONTENT)
        }

        updatePage()
        dialog.showThemed()
    }

    private fun configureWideLayout(
        context: Context,
        root: LinearLayout,
        header: LinearLayout,
        flipper: ViewFlipper,
        stepLabel: TextView,
        footer: LinearLayout,
        dots: LinearLayout,
        buttonRow: LinearLayout,
        closeButton: ImageButton
    ) {
        root.setPadding(root.paddingLeft, context.dp(10), root.paddingRight, 0)

        (stepLabel.parent as? ViewGroup)?.removeView(stepLabel)
        val closeIndex = header.indexOfChild(closeButton).coerceAtLeast(0)
        header.addView(
            stepLabel,
            closeIndex,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                marginStart = context.dp(12)
                marginEnd = context.dp(4)
            }
        )
        stepLabel.isSingleLine = true

        (flipper.layoutParams as? LinearLayout.LayoutParams)?.let {
            it.topMargin = context.dp(8)
            flipper.layoutParams = it
        }

        repeat(flipper.childCount) { index ->
            val page = flipper.getChildAt(index) as? LinearLayout ?: return@repeat
            if (page.childCount < 2) return@repeat

            val illustration = page.getChildAt(0)
            val contentViews = (1 until page.childCount).map { page.getChildAt(it) }

            page.removeAllViews()
            page.orientation = LinearLayout.HORIZONTAL
            page.gravity = Gravity.CENTER_VERTICAL

            val content = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            }

            contentViews.forEachIndexed { childIndex, child ->
                val oldParams = child.layoutParams as? LinearLayout.LayoutParams
                content.addView(
                    child,
                    LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    ).apply {
                        topMargin = if (childIndex == 0) 0 else oldParams?.topMargin ?: 0
                    }
                )
            }

            page.addView(content)
            page.addView(
                illustration,
                LinearLayout.LayoutParams(0, context.dp(184), 1.08f).apply {
                    marginStart = context.dp(20)
                }
            )
        }

        footer.setPadding(footer.paddingLeft, footer.paddingTop, footer.paddingRight, context.dp(8))

        (dots.layoutParams as? LinearLayout.LayoutParams)?.let {
            it.topMargin = context.dp(8)
            dots.layoutParams = it
        }
        (buttonRow.layoutParams as? LinearLayout.LayoutParams)?.let {
            it.topMargin = context.dp(4)
            buttonRow.layoutParams = it
        }
    }

    private fun configurePageAnimation(
        context: Context,
        flipper: ViewFlipper,
        direction: Int,
        animationsEnabled: Boolean
    ) {
        if (!animationsEnabled || direction == 0) {
            flipper.inAnimation = null
            flipper.outAnimation = null
            return
        }

        val distance = context.dp(28).toFloat()
        val incomingStart = if (direction > 0) distance else -distance
        val outgoingEnd = -incomingStart
        val interpolator = DecelerateInterpolator(1.6f)

        flipper.inAnimation = AnimationSet(true).apply {
            duration = PAGE_TRANSITION_DURATION_MS
            this.interpolator = interpolator
            addAnimation(AlphaAnimation(0f, 1f))
            addAnimation(
                TranslateAnimation(
                    Animation.ABSOLUTE,
                    incomingStart,
                    Animation.ABSOLUTE,
                    0f,
                    Animation.ABSOLUTE,
                    0f,
                    Animation.ABSOLUTE,
                    0f
                )
            )
        }
        flipper.outAnimation = AnimationSet(true).apply {
            duration = PAGE_TRANSITION_DURATION_MS
            this.interpolator = interpolator
            addAnimation(AlphaAnimation(1f, 0f))
            addAnimation(
                TranslateAnimation(
                    Animation.ABSOLUTE,
                    0f,
                    Animation.ABSOLUTE,
                    outgoingEnd,
                    Animation.ABSOLUTE,
                    0f,
                    Animation.ABSOLUTE,
                    0f
                )
            )
        }
    }

    private fun renderDots(
        context: Context,
        container: LinearLayout,
        activePage: Int,
        pageCount: Int
    ) {
        container.removeAllViews()
        repeat(pageCount) { index ->
            val active = index == activePage
            val width = if (active) 20 else 7
            val dot = View(context).apply {
                layoutParams = LinearLayout.LayoutParams(
                    context.dp(width),
                    context.dp(7)
                ).apply {
                    marginStart = context.dp(3)
                    marginEnd = context.dp(3)
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = context.dp(
                        if (ThemeManager.isDeltaruneTheme(context)) 1 else 4
                    ).toFloat()
                    setColor(
                        MaterialColors.getColor(
                            context,
                            if (active) {
                                com.google.android.material.R.attr.colorPrimary
                            } else {
                                com.google.android.material.R.attr.colorOutline
                            },
                            ContextCompat.getColor(
                                context,
                                if (active) R.color.m3_primary else R.color.m3_outline
                            )
                        )
                    )
                }
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            }
            container.addView(dot)
        }
    }

    private fun Context.dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private const val PAGE_TRANSITION_DURATION_MS = 220L
}
