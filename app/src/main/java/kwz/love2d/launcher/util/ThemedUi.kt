package kwz.love2d.launcher.util

import android.content.Context
import android.view.View
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
    return this
}

fun PopupMenu.showThemed(context: Context, anchor: View) {
    show()
    anchor.post { ThemeManager.applyPopupMenuTheme(context, this) }
}
