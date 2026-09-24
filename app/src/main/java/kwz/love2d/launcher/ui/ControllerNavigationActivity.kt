package kwz.love2d.launcher.ui

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.content.res.Configuration
import android.util.TypedValue
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.view.inputmethod.InputMethodManager
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.color.MaterialColors
import kwz.love2d.launcher.R
import java.util.WeakHashMap

/** Shared keyboard and physical-controller navigation for launcher screens. */
open class ControllerNavigationActivity : AppCompatActivity() {
    private var focusOutline: FocusOutline? = null
    private var lastAxisDirection = 0
    private var lastAxisTime = 0L
    private var lastKeyDirection = 0
    private var lastKeyTime = 0L
    private var physicalNavigationActive = false
    private var editingField: EditText? = null
    private var lastInteractiveFocus: View? = null
    private val observedLists = WeakHashMap<RecyclerView, Boolean>()

    override fun onResume() {
        super.onResume()
        window.decorView.post {
            prepareFocusTargets(window.decorView)
            installFocusOutline()
            if (resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK ==
                Configuration.UI_MODE_TYPE_TELEVISION
            ) {
                physicalNavigationActive = true
                firstFocusTarget()?.requestFocusFromTouch()
                focusOutline?.invalidate()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) return super.dispatchKeyEvent(event)
        val gamepad = event.source and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD ||
            event.source and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK

        if (gamepad || event.keyCode in KeyEvent.KEYCODE_DPAD_UP..KeyEvent.KEYCODE_DPAD_RIGHT ||
            event.keyCode == KeyEvent.KEYCODE_TAB
        ) {
            physicalNavigationActive = true
            focusOutline?.invalidate()
        }

        when (event.keyCode) {
            KeyEvent.KEYCODE_BUTTON_A -> if (gamepad) {
                val focused = currentFocus ?: firstFocusTarget()
                if (focused is EditText && editingField !== focused) {
                    activateTextField(focused)
                    return true
                }
                return focused?.performClick() == true || super.dispatchKeyEvent(event)
            }
            KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_DPAD_CENTER -> {
                val field = currentFocus as? EditText
                if (field != null && editingField !== field) {
                    activateTextField(field)
                    return true
                }
            }
            KeyEvent.KEYCODE_BUTTON_X, KeyEvent.KEYCODE_MENU, KeyEvent.KEYCODE_F10 -> {
                if (event.keyCode == KeyEvent.KEYCODE_F10 && !event.isShiftPressed) {
                    return super.dispatchKeyEvent(event)
                }
                val focused = currentFocus ?: firstFocusTarget()
                val more = (focused as? ViewGroup)?.findViewById<View>(R.id.btnMenuMore)
                if (more?.isShown == true) return more.performClick()
                return focused?.showContextMenu() == true || super.dispatchKeyEvent(event)
            }
            KeyEvent.KEYCODE_BUTTON_B -> if (gamepad) {
                if (leaveTextField()) return true
                onBackPressedDispatcher.onBackPressed()
                return true
            }
            KeyEvent.KEYCODE_BUTTON_L1, KeyEvent.KEYCODE_PAGE_UP -> if (onTabDirection(-1)) return true
            KeyEvent.KEYCODE_BUTTON_R1, KeyEvent.KEYCODE_PAGE_DOWN -> if (onTabDirection(1)) return true
            KeyEvent.KEYCODE_ESCAPE -> {
                if (leaveTextField()) return true
                onBackPressedDispatcher.onBackPressed()
                return true
            }
            KeyEvent.KEYCODE_DEL -> if (currentFocus !is EditText) {
                onBackPressedDispatcher.onBackPressed()
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (currentFocus != null && currentFocus === editingField) {
                    return super.dispatchKeyEvent(event)
                }
                if (event.isCtrlPressed && event.keyCode == KeyEvent.KEYCODE_DPAD_LEFT &&
                    onTabDirection(-1)) return true
                if (event.isCtrlPressed && event.keyCode == KeyEvent.KEYCODE_DPAD_RIGHT &&
                    onTabDirection(1)) return true
                val direction = when (event.keyCode) {
                    KeyEvent.KEYCODE_DPAD_UP -> View.FOCUS_UP
                    KeyEvent.KEYCODE_DPAD_DOWN -> View.FOCUS_DOWN
                    KeyEvent.KEYCODE_DPAD_LEFT -> View.FOCUS_LEFT
                    else -> View.FOCUS_RIGHT
                }
                lastKeyDirection = direction
                lastKeyTime = event.eventTime
                moveFocus(direction)
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.action != MotionEvent.ACTION_MOVE ||
            event.source and InputDevice.SOURCE_JOYSTICK != InputDevice.SOURCE_JOYSTICK
        ) return super.onGenericMotionEvent(event)

        val x = dominantAxis(event.getAxisValue(MotionEvent.AXIS_X), event.getAxisValue(MotionEvent.AXIS_HAT_X))
        val y = dominantAxis(event.getAxisValue(MotionEvent.AXIS_Y), event.getAxisValue(MotionEvent.AXIS_HAT_Y))
        val direction = when {
            kotlin.math.abs(x) >= kotlin.math.abs(y) && x > 0.55f -> View.FOCUS_RIGHT
            kotlin.math.abs(x) >= kotlin.math.abs(y) && x < -0.55f -> View.FOCUS_LEFT
            y > 0.55f -> View.FOCUS_DOWN
            y < -0.55f -> View.FOCUS_UP
            else -> 0
        }
        if (direction == 0) {
            lastAxisDirection = 0
            return super.onGenericMotionEvent(event)
        }
        physicalNavigationActive = true
        focusOutline?.invalidate()
        val now = event.eventTime
        if (direction == lastKeyDirection && now - lastKeyTime in 0L..100L) return true
        if (direction != lastAxisDirection || now - lastAxisTime >= 220L) {
            lastAxisDirection = direction
            lastAxisTime = now
            moveFocus(direction)
        }
        return true
    }

    protected open fun firstFocusTarget(): View? {
        prepareFocusTargets(window.decorView)
        return findFirstFocusable(window.decorView)
    }

    protected open fun onTabDirection(direction: Int): Boolean = false

    protected open fun onDirectionalFocus(from: View, direction: Int): View? = null

    private fun leaveTextField(): Boolean {
        val field = currentFocus as? EditText ?: return false
        (getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager)
            ?.hideSoftInputFromWindow(field.windowToken, 0)
        field.clearFocus()
        editingField = null
        field.isCursorVisible = false
        (firstFocusTarget()?.takeIf { it !== field } ?: field.focusSearch(View.FOCUS_DOWN))
            ?.takeIf { it !== field }?.requestFocusFromTouch()
        return true
    }

    private fun activateTextField(field: EditText) {
        editingField = field
        field.isCursorVisible = true
        field.showSoftInputOnFocus = true
        field.requestFocusFromTouch()
        (getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager)
            ?.showSoftInput(field, InputMethodManager.SHOW_IMPLICIT)
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            physicalNavigationActive = false
            if (currentFocus !is EditText) currentFocus?.clearFocus()
            (currentFocus as? EditText)?.apply {
                editingField = this
                isCursorVisible = true
                showSoftInputOnFocus = true
            }
            focusOutline?.invalidate()
        }
        return super.dispatchTouchEvent(event)
    }

    private fun moveFocus(direction: Int) {
        prepareFocusTargets(window.decorView)
        val focused = currentFocus?.takeIf { it.isClickable }
            ?: lastInteractiveFocus?.takeIf {
                it.isAttachedToWindow && it.isShown && it.getGlobalVisibleRect(Rect())
            }
            ?: firstFocusTarget()
        if (focused == null) return
        if (!focused.hasFocus() && currentFocus == null) {
            requestInteractiveFocus(focused)
            return
        }
        val androidTarget = focused.focusSearch(direction)
        (onDirectionalFocus(focused, direction)
            ?: androidTarget?.takeIf { it.isClickable }
            ?: closestInteractiveTarget(focused, direction))
            ?.takeIf { it !== focused && it.isShown && it.isEnabled }
            ?.let(::requestInteractiveFocus)
    }

    private fun requestInteractiveFocus(target: View): Boolean {
        val focused = target.requestFocusFromTouch()
        if (focused) {
            target.requestRectangleOnScreen(Rect(0, 0, target.width, target.height), false)
        }
        return focused
    }

    private fun closestInteractiveTarget(from: View, direction: Int): View? {
        val origin = Rect()
        if (!from.getGlobalVisibleRect(origin)) return null
        var best: View? = null
        var bestScore = Int.MAX_VALUE
        fun visit(view: View) {
            if (view !== from && view.isClickable && view.isFocusable && view.isEnabled && view.isShown) {
                val bounds = Rect()
                if (view.getGlobalVisibleRect(bounds)) {
                    val dx = bounds.centerX() - origin.centerX()
                    val dy = bounds.centerY() - origin.centerY()
                    val major = when (direction) {
                        View.FOCUS_UP -> -dy
                        View.FOCUS_DOWN -> dy
                        View.FOCUS_LEFT -> -dx
                        else -> dx
                    }
                    if (major > 0) {
                        val minor = if (direction == View.FOCUS_UP || direction == View.FOCUS_DOWN) {
                            kotlin.math.abs(dx)
                        } else {
                            kotlin.math.abs(dy)
                        }
                        val score = major * 2 + minor
                        if (score < bestScore) {
                            bestScore = score
                            best = view
                        }
                    }
                }
            }
            if (view is ViewGroup) {
                for (index in 0 until view.childCount) visit(view.getChildAt(index))
            }
        }
        visit(window.decorView)
        return best
    }

    private fun prepareFocusTargets(view: View) {
        if (view.isClickable && view.isEnabled) {
            view.isFocusable = true
        }
        if (view is RecyclerView && observedLists.put(view, true) == null) {
            view.addOnChildAttachStateChangeListener(object : RecyclerView.OnChildAttachStateChangeListener {
                override fun onChildViewAttachedToWindow(child: View) = prepareFocusTargets(child)
                override fun onChildViewDetachedFromWindow(child: View) = Unit
            })
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) prepareFocusTargets(view.getChildAt(index))
        }
    }

    private fun findFirstFocusable(view: View): View? {
        if (view.isShown && view.isEnabled && view.isFocusable && view.isClickable) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findFirstFocusable(view.getChildAt(index))?.let { return it }
            }
        }
        return null
    }

    private fun installFocusOutline() {
        if (focusOutline != null) return
        val decor = window.decorView as? ViewGroup ?: return
        val outline = FocusOutline()
        focusOutline = outline
        decor.addView(outline, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        decor.viewTreeObserver.addOnGlobalFocusChangeListener { previous, focused ->
            if (focused?.isClickable == true) lastInteractiveFocus = focused
            else if (previous?.isClickable == true) lastInteractiveFocus = previous
            if (focused is EditText) {
                focused.isCursorVisible = !physicalNavigationActive
                focused.showSoftInputOnFocus = !physicalNavigationActive
                editingField = if (physicalNavigationActive) null else focused
            } else {
                editingField = null
            }
            outline.invalidate()
        }
        decor.viewTreeObserver.addOnGlobalLayoutListener { outline.invalidate() }
        decor.viewTreeObserver.addOnScrollChangedListener { outline.invalidate() }
    }

    private fun dominantAxis(stick: Float, hat: Float): Float =
        if (kotlin.math.abs(hat) > kotlin.math.abs(stick)) hat else stick

    private inner class FocusOutline : View(this@ControllerNavigationActivity) {
        private val rect = Rect()
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = resources.displayMetrics.density * 2f
        }

        init {
            isClickable = false
            isFocusable = false
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }

        override fun onDraw(canvas: Canvas) {
            if (!physicalNavigationActive) return
            val focused = currentFocus ?: return
            if (!focused.isShown || focused === this || !focused.getGlobalVisibleRect(rect)) return
            val location = IntArray(2)
            getLocationOnScreen(location)
            rect.offset(-location[0], -location[1])
            val inset = paint.strokeWidth / 2f + resources.displayMetrics.density
            if (rect.width() <= inset * 2 || rect.height() <= inset * 2) return
            paint.color = MaterialColors.getColor(this, com.google.android.material.R.attr.colorPrimary)
            val corner = TypedValue()
            val radius = if (theme.resolveAttribute(R.attr.kristalCorner24, corner, true)) {
                corner.getDimension(resources.displayMetrics)
            } else {
                0f
            }
            canvas.drawRoundRect(
                rect.left + inset, rect.top + inset, rect.right - inset, rect.bottom - inset,
                radius, radius, paint
            )
        }
    }
}
