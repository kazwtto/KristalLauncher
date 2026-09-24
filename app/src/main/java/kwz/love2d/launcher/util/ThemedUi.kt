package kwz.love2d.launcher.util

import android.content.Context
import android.view.InputDevice
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.widget.PopupMenu
import com.google.android.material.dialog.MaterialAlertDialogBuilder

fun MaterialAlertDialogBuilder.showThemed(): AlertDialog {
    val dialog = create()
    return dialog.showThemed()
}

fun AlertDialog.showThemed(): AlertDialog {
    show()
    ThemeManager.applyDialogTheme(this)
    window?.decorView?.let(::makeDialogActionsFocusable)
    setOnKeyListener { dialog, keyCode, event ->
        if (event.action != KeyEvent.ACTION_DOWN) return@setOnKeyListener false
        val gamepad = event.source and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD ||
            event.source and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK
        if (!gamepad) return@setOnKeyListener false
        when (keyCode) {
            KeyEvent.KEYCODE_BUTTON_A -> window?.currentFocus?.performClick() == true
            KeyEvent.KEYCODE_BUTTON_B -> {
                dialog.dismiss()
                true
            }
            else -> false
        }
    }
    return this
}

private fun makeDialogActionsFocusable(view: View) {
    if (view.isClickable && view.isEnabled) view.isFocusable = true
    if (view is ViewGroup) {
        for (index in 0 until view.childCount) makeDialogActionsFocusable(view.getChildAt(index))
    }
}

fun PopupMenu.showThemed(context: Context, anchor: View) {
    show()
    anchor.post { ThemeManager.applyPopupMenuTheme(context, this) }
}
