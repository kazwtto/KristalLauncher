package kwz.love2d.launcher.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.AttributeSet
import android.util.TypedValue
import android.view.View
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.color.MaterialColors
import kwz.love2d.launcher.R

class PatchSegmentedButtonGroup @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : MaterialButtonToggleGroup(context, attrs, defStyleAttr) {

    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = resources.displayMetrics.density
    }
    private val bounds = RectF()
    private val selectedPath = Path()

    init {
        setWillNotDraw(false)
        addOnButtonCheckedListener { _, _, _ -> invalidate() }
    }

    override fun dispatchDraw(canvas: Canvas) {
        super.dispatchDraw(canvas)
        if (width <= 0 || height <= 0) return

        val halfStroke = borderPaint.strokeWidth / 2f
        bounds.set(halfStroke, halfStroke, width - halfStroke, height - halfStroke)
        val cornerRadius = resolveCornerRadius()
        val outline = MaterialColors.getColor(
            this,
            com.google.android.material.R.attr.colorOutline
        )
        val primary = MaterialColors.getColor(
            this,
            com.google.android.material.R.attr.colorPrimary
        )

        borderPaint.color = outline
        canvas.drawRoundRect(bounds, cornerRadius, cornerRadius, borderPaint)

        visibleButtons().dropLast(1).forEach { button ->
            val dividerX = button.right.toFloat()
            canvas.drawLine(dividerX, halfStroke, dividerX, height - halfStroke, borderPaint)
        }

        val selected = visibleButtons().firstOrNull(MaterialButton::isChecked) ?: return
        val selectedBounds = RectF(
            selected.left.toFloat().coerceAtLeast(halfStroke),
            halfStroke,
            selected.right.toFloat().coerceAtMost(width - halfStroke),
            height - halfStroke
        )
        val roundsLeft = selected.left <= 0
        val roundsRight = selected.right >= width
        val radii = floatArrayOf(
            if (roundsLeft) cornerRadius else 0f,
            if (roundsLeft) cornerRadius else 0f,
            if (roundsRight) cornerRadius else 0f,
            if (roundsRight) cornerRadius else 0f,
            if (roundsRight) cornerRadius else 0f,
            if (roundsRight) cornerRadius else 0f,
            if (roundsLeft) cornerRadius else 0f,
            if (roundsLeft) cornerRadius else 0f
        )

        selectedPath.reset()
        selectedPath.addRoundRect(selectedBounds, radii, Path.Direction.CW)
        borderPaint.color = primary
        canvas.drawPath(selectedPath, borderPaint)
    }

    private fun visibleButtons(): List<MaterialButton> = buildList {
        for (index in 0 until childCount) {
            val child = getChildAt(index)
            if (child is MaterialButton && child.visibility == View.VISIBLE) add(child)
        }
    }

    private fun resolveCornerRadius(): Float {
        val value = TypedValue()
        if (!context.theme.resolveAttribute(R.attr.kristalCorner20, value, true)) return 0f
        return if (value.resourceId != 0) {
            resources.getDimension(value.resourceId)
        } else {
            TypedValue.complexToDimension(value.data, resources.displayMetrics)
        }
    }
}
