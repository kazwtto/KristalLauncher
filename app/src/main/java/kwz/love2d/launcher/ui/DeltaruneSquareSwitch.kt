package kwz.love2d.launcher.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Build
import android.util.AttributeSet
import android.view.View
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Checkable
import android.widget.Switch
import com.google.android.material.color.MaterialColors
import kwz.love2d.launcher.R

class DeltaruneSquareSwitch @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr), Checkable {

    private val density = resources.displayMetrics.density
    private val trackPaint = Paint()
    private val borderPaint = Paint().apply {
        style = Paint.Style.STROKE
        strokeWidth = density
    }
    private val thumbPaint = Paint()
    private val trackBounds = RectF()
    private var checked = false
    private var checkedChangeListener: ((DeltaruneSquareSwitch, Boolean) -> Unit)? = null

    init {
        isClickable = true
        isFocusable = true
        minimumWidth = dp(MINIMUM_TOUCH_SIZE_DP)
        minimumHeight = dp(MINIMUM_TOUCH_SIZE_DP)
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(
            resolveSize(dp(MINIMUM_TOUCH_SIZE_DP), widthMeasureSpec),
            resolveSize(dp(MINIMUM_TOUCH_SIZE_DP), heightMeasureSpec)
        )
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val enabledAlpha = if (isEnabled) 1f else 0.55f
        val primary = color(com.google.android.material.R.attr.colorPrimary, R.color.m3_primary)
        val onPrimary = color(com.google.android.material.R.attr.colorOnPrimary, R.color.m3_on_primary)
        val surfaceVariant = color(com.google.android.material.R.attr.colorSurfaceVariant, R.color.m3_surface_variant)
        val onSurface = color(com.google.android.material.R.attr.colorOnSurface, R.color.m3_on_surface)
        val onSurfaceVariant = color(
            com.google.android.material.R.attr.colorOnSurfaceVariant,
            R.color.m3_on_surface_variant
        )
        val outline = color(com.google.android.material.R.attr.colorOutline, R.color.m3_outline)

        val trackColor = if (checked) {
            withAlpha(primary, if (isEnabled) 0.72f else 0.35f)
        } else {
            withAlpha(surfaceVariant, enabledAlpha)
        }
        val borderColor = if (checked) primary else outline
        val thumbColor = when {
            !isEnabled -> withAlpha(onSurface, 0.35f)
            checked -> onPrimary
            else -> onSurfaceVariant
        }

        val trackWidth = dpF(TRACK_WIDTH_DP)
        val trackHeight = dpF(TRACK_HEIGHT_DP)
        val trackLeft = (width - trackWidth) / 2f
        val trackTop = (height - trackHeight) / 2f
        val borderInset = density * 0.5f
        trackBounds.set(
            trackLeft + borderInset,
            trackTop + borderInset,
            trackLeft + trackWidth - borderInset,
            trackTop + trackHeight - borderInset
        )
        trackPaint.color = trackColor
        borderPaint.color = borderColor
        canvas.drawRect(trackBounds, trackPaint)
        canvas.drawRect(trackBounds, borderPaint)

        val padding = dpF(3f)
        val thumbSize = dpF(16f)
        val left = if (checked) {
            trackLeft + trackWidth - padding - thumbSize
        } else {
            trackLeft + padding
        }
        val top = trackTop + (trackHeight - thumbSize) / 2f
        thumbPaint.color = thumbColor
        canvas.drawRect(left, top, left + thumbSize, top + thumbSize, thumbPaint)
    }

    override fun performClick(): Boolean {
        toggle()
        return super.performClick()
    }

    override fun setChecked(value: Boolean) {
        if (checked == value) return
        checked = value
        refreshDrawableState()
        invalidate()
        checkedChangeListener?.invoke(this, value)
    }

    override fun isChecked(): Boolean = checked

    override fun toggle() {
        setChecked(!checked)
    }

    override fun onCreateDrawableState(extraSpace: Int): IntArray {
        val drawableState = super.onCreateDrawableState(extraSpace + 1)
        if (checked) mergeDrawableStates(drawableState, CHECKED_STATE_SET)
        return drawableState
    }

    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        info.className = Switch::class.java.name
        info.isCheckable = true
        info.isChecked = checked
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            info.stateDescription = context.getString(
                if (checked) R.string.switch_state_on else R.string.switch_state_off
            )
        }
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        invalidate()
    }

    fun setOnCheckedChangeListener(listener: ((DeltaruneSquareSwitch, Boolean) -> Unit)?) {
        checkedChangeListener = listener
    }

    private fun color(attr: Int, fallback: Int): Int {
        return MaterialColors.getColor(this, attr, context.getColor(fallback))
    }

    private fun withAlpha(color: Int, alpha: Float): Int {
        return (color and 0x00FFFFFF) or ((255 * alpha.coerceIn(0f, 1f)).toInt() shl 24)
    }

    private fun dp(value: Int): Int = (value * density).toInt()
    private fun dpF(value: Float): Float = value * density

    private companion object {
        const val MINIMUM_TOUCH_SIZE_DP = 48
        const val TRACK_WIDTH_DP = 44f
        const val TRACK_HEIGHT_DP = 24f
        val CHECKED_STATE_SET = intArrayOf(android.R.attr.state_checked)
    }
}
