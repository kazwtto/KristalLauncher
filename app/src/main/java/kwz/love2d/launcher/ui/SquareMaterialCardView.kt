package kwz.love2d.launcher.ui

import android.content.Context
import android.util.AttributeSet
import com.google.android.material.card.MaterialCardView

/** Keeps grid cards square regardless of the number of columns or screen width. */
class SquareMaterialCardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = com.google.android.material.R.attr.materialCardViewStyle
) : MaterialCardView(context, attrs, defStyleAttr) {

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
        val side = measuredWidth
        val exactSide = MeasureSpec.makeMeasureSpec(side, MeasureSpec.EXACTLY)
        super.onMeasure(exactSide, exactSide)
    }
}
