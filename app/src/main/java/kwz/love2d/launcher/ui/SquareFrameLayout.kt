package kwz.love2d.launcher.ui

import android.content.Context
import android.util.AttributeSet
import android.widget.FrameLayout

class SquareFrameLayout @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // Force the measured height to match the width for a square 1:1 frame.
        super.onMeasure(widthMeasureSpec, widthMeasureSpec)
    }
}
