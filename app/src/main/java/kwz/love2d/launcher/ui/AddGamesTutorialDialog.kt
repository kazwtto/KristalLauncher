package kwz.love2d.launcher.ui

import android.animation.ValueAnimator
import android.content.Context
import android.os.Build
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.core.widget.NestedScrollView
import com.google.android.material.button.MaterialButton
import com.google.android.material.color.MaterialColors
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.R
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.showThemed

object AddGamesTutorialDialog {

    private data class TutorialPage(
        val title: Int,
        val body: Int,
        val tip: Int,
        val illustrationTitle: Int,
        val illustrationSubtitle: Int,
        val iconAttribute: Int,
        val fallbackIcon: Int
    )

    fun show(context: Context, folderAlreadySelected: Boolean, onChooseFolder: () -> Unit) {
        val view = LayoutInflater.from(context).inflate(
            R.layout.dialog_add_games_tutorial,
            FrameLayout(context),
            false
        )
        ThemeManager.applyDeltaruneStyle(context, view)

        val pages = tutorialPages()
        val root = view.findViewById<LinearLayout>(R.id.tutorialRoot)
        val scroll = view.findViewById<NestedScrollView>(R.id.tutorialScroll)
        val pageContent = view.findViewById<LinearLayout>(R.id.tutorialPageContent)
        val illustrationIcon = view.findViewById<ImageView>(R.id.ivTutorialIllustration)
        val illustrationTitle = view.findViewById<TextView>(R.id.tvTutorialIllustrationTitle)
        val illustrationSubtitle = view.findViewById<TextView>(R.id.tvTutorialIllustrationSubtitle)
        val pageTitle = view.findViewById<TextView>(R.id.tvTutorialPageTitle)
        val pageBody = view.findViewById<TextView>(R.id.tvTutorialPageBody)
        val pageTip = view.findViewById<TextView>(R.id.tvTutorialPageTip)
        val stepLabel = view.findViewById<TextView>(R.id.tvTutorialStep)
        val dots = view.findViewById<LinearLayout>(R.id.tutorialDots)
        val previousButton = view.findViewById<MaterialButton>(R.id.btnTutorialPrevious)
        val nextButton = view.findViewById<MaterialButton>(R.id.btnTutorialNext)
        val closeButton = view.findViewById<ImageButton>(R.id.btnTutorialClose)
        val animationsEnabled = ThemeManager.areAnimationsEnabled(context) &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || ValueAnimator.areAnimatorsEnabled())

        val dialog = MaterialAlertDialogBuilder(context).setView(view).create()
        var pageIndex = 0

        fun renderPage(direction: Int = 0) {
            val page = pages[pageIndex]
            stepLabel.text = context.getString(R.string.tutorial_step_counter, pageIndex + 1, pages.size)
            illustrationIcon.setImageResource(
                ThemeManager.resolveDrawableResource(context, page.iconAttribute, page.fallbackIcon)
            )
            illustrationTitle.setText(page.illustrationTitle)
            illustrationSubtitle.setText(page.illustrationSubtitle)
            pageTitle.setText(page.title)
            pageBody.setText(page.body)
            pageTip.setText(page.tip)
            previousButton.visibility = if (pageIndex == 0) View.INVISIBLE else View.VISIBLE

            if (pageIndex == pages.lastIndex) {
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

            renderDots(context, dots, pageIndex, pages.size)
            scroll.scrollTo(0, 0)
            constrainHeightOnlyWhenNecessary(root, scroll, pageContent)
            if (animationsEnabled && direction != 0) {
                pageContent.animate().cancel()
                pageContent.alpha = 0.72f
                pageContent.translationX = context.dp(if (direction > 0) 16 else -16).toFloat()
                pageContent.animate()
                    .alpha(1f)
                    .translationX(0f)
                    .setDuration(PAGE_TRANSITION_DURATION_MS)
                    .start()
            } else {
                pageContent.alpha = 1f
                pageContent.translationX = 0f
            }
        }

        closeButton.setOnClickListener { dialog.dismiss() }
        previousButton.setOnClickListener {
            if (pageIndex > 0) {
                pageIndex--
                renderPage(-1)
            }
        }
        nextButton.setOnClickListener {
            if (pageIndex < pages.lastIndex) {
                pageIndex++
                renderPage(1)
            } else {
                dialog.dismiss()
                if (!folderAlreadySelected) onChooseFolder()
            }
        }

        dialog.setOnShowListener {
            val metrics = context.resources.displayMetrics
            val width = context.dp(680).coerceAtMost((metrics.widthPixels * 0.96f).toInt())
            dialog.window?.setLayout(width, ViewGroup.LayoutParams.WRAP_CONTENT)
            constrainHeightOnlyWhenNecessary(root, scroll, pageContent)
        }

        renderPage()
        dialog.showThemed()
    }

    private fun tutorialPages(): List<TutorialPage> = listOf(
        TutorialPage(R.string.tutorial_step_1_title, R.string.tutorial_step_1_body,
            R.string.tutorial_step_1_tip, R.string.tutorial_mock_games_folder,
            R.string.tutorial_mock_games_path, R.attr.kristalIconFolder, R.drawable.ic_folder),
        TutorialPage(R.string.tutorial_step_2_title, R.string.tutorial_step_2_body,
            R.string.tutorial_step_2_tip, R.string.tutorial_supported_files,
            R.string.tutorial_supported_extensions, R.attr.kristalIconGamepad, R.drawable.ic_gamepad),
        TutorialPage(R.string.tutorial_step_3_title, R.string.tutorial_step_3_body,
            R.string.tutorial_step_3_tip, R.string.select_folder,
            R.string.tutorial_mock_games_path, R.attr.kristalIconFolder, R.drawable.ic_folder),
        TutorialPage(R.string.tutorial_step_4_title, R.string.tutorial_step_4_body,
            R.string.tutorial_step_4_tip, R.string.tutorial_mock_use_folder,
            R.string.tutorial_mock_games_folder, R.attr.kristalIconFolder, R.drawable.ic_folder),
        TutorialPage(R.string.tutorial_step_5_title, R.string.tutorial_step_5_body,
            R.string.tutorial_step_5_tip, R.string.tutorial_mock_library_ready,
            R.string.tutorial_mock_engine_kristal, R.attr.kristalIconGamepad, R.drawable.ic_gamepad)
    )

    private fun constrainHeightOnlyWhenNecessary(
        root: View,
        scroll: NestedScrollView,
        pageContent: View
    ) {
        root.post {
            val maximumHeight = (root.resources.displayMetrics.heightPixels * MAXIMUM_SCREEN_HEIGHT_RATIO).toInt()
            val fixedContentHeight = (root.measuredHeight - scroll.measuredHeight).coerceAtLeast(0)
            val naturalHeight = fixedContentHeight + pageContent.measuredHeight
            if (naturalHeight <= maximumHeight) {
                scroll.layoutParams = scroll.layoutParams.apply { height = ViewGroup.LayoutParams.WRAP_CONTENT }
                scroll.isVerticalScrollBarEnabled = false
                return@post
            }

            scroll.layoutParams = scroll.layoutParams.apply {
                height = (maximumHeight - fixedContentHeight)
                    .coerceAtLeast(root.context.dp(MINIMUM_PAGE_HEIGHT_DP))
            }
            scroll.isVerticalScrollBarEnabled = true
        }
    }

    private fun renderDots(context: Context, container: LinearLayout, activePage: Int, pageCount: Int) {
        container.removeAllViews()
        repeat(pageCount) { index ->
            val active = index == activePage
            container.addView(View(context).apply {
                layoutParams = LinearLayout.LayoutParams(
                    context.dp(if (active) 20 else 7), context.dp(7)
                ).apply {
                    marginStart = context.dp(3)
                    marginEnd = context.dp(3)
                }
                background = android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                    cornerRadius = context.dp(if (ThemeManager.isDeltaruneTheme(context)) 1 else 4).toFloat()
                    setColor(
                        MaterialColors.getColor(
                            context,
                            if (active) com.google.android.material.R.attr.colorPrimary
                            else com.google.android.material.R.attr.colorOutline,
                            ContextCompat.getColor(context, if (active) R.color.m3_primary else R.color.m3_outline)
                        )
                    )
                }
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            })
        }
    }

    private fun Context.dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private const val PAGE_TRANSITION_DURATION_MS = 160L
    private const val MAXIMUM_SCREEN_HEIGHT_RATIO = 0.88f
    private const val MINIMUM_PAGE_HEIGHT_DP = 180
}
