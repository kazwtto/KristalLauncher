package kwz.love2d.launcher.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import android.widget.Checkable
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
    private var checked = false
    private var checkedChangeListener: ((DeltaruneSquareSwitch, Boolean) -> Unit)? = null

    init {
        isClickable = true
        isFocusable = true
        minimumWidth = dp(44)
        minimumHeight = dp(24)
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(
            resolveSize(dp(44), widthMeasureSpec),
            resolveSize(dp(24), heightMeasureSpec)
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

        val borderInset = density * 0.5f
        val track = RectF(
            borderInset,
            borderInset,
            width - borderInset,
            height - borderInset
        )
        trackPaint.color = trackColor
        borderPaint.color = borderColor
        canvas.drawRect(track, trackPaint)
        canvas.drawRect(track, borderPaint)

        val padding = dpF(3f)
        val thumbSize = dpF(16f)
        val left = if (checked) width - padding - thumbSize else padding
        val top = (height - thumbSize) / 2f
        thumbPaint.color = thumbColor
        canvas.drawRect(left, top, left + thumbSize, top + thumbSize, thumbPaint)
    }

    override fun performClick(): Boolean {
        super.performClick()
        toggle()
        return true
    }

    override fun setChecked(value: Boolean) {
        if (checked == value) return
        checked = value
        refreshDrawableState()
        invalidate()
        checkedChangeListener?.invoke(this, value)
        sendAccessibilityEvent(android.view.accessibility.AccessibilityEvent.TYPE_VIEW_CLICKED)
    }

    override fun isChecked(): Boolean = checked

    override fun toggle() {
        setChecked(!checked)
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
}
