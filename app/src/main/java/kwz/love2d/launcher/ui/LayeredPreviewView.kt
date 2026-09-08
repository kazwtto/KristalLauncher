package kwz.love2d.launcher.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import kotlin.math.roundToInt

class LayeredPreviewView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { isFilterBitmap = false }
    private val source = Rect()
    private val destination = RectF()
    private var layers: List<Bitmap> = emptyList()

    fun setLayers(value: List<Bitmap>) {
        layers = value.filterNot(Bitmap::isRecycled)
        visibility = if (layers.isEmpty()) GONE else VISIBLE
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width <= 0 || height <= 0) return
        destination.set(0f, 0f, width.toFloat(), height.toFloat())
        val bitmap = layers.firstOrNull() ?: return
        configureCenterCrop(bitmap)
        canvas.drawBitmap(bitmap, source, destination, paint)
    }

    private fun configureCenterCrop(bitmap: Bitmap) {
        val viewRatio = width.toFloat() / height
        val bitmapRatio = bitmap.width.toFloat() / bitmap.height
        if (bitmapRatio > viewRatio) {
            val sourceWidth = (bitmap.height * viewRatio).roundToInt().coerceAtMost(bitmap.width)
            val left = (bitmap.width - sourceWidth) / 2
            source.set(left, 0, left + sourceWidth, bitmap.height)
        } else {
            val sourceHeight = (bitmap.width / viewRatio).roundToInt().coerceAtMost(bitmap.height)
            val top = (bitmap.height - sourceHeight) / 2
            source.set(0, top, bitmap.width, top + sourceHeight)
        }
    }
}
