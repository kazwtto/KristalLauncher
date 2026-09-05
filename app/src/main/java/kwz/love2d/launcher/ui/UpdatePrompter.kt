package kwz.love2d.launcher.ui

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.R
import kwz.love2d.launcher.util.UpdateCheckResult
import kwz.love2d.launcher.util.showThemed

object UpdatePrompter {

    fun show(activity: Activity, result: UpdateCheckResult, showCurrentStatus: Boolean) {
        when (result) {
            is UpdateCheckResult.Available -> {
                val update = result.update
                val notes = update.releaseNotes.takeIf { it.isNotBlank() }
                    ?: activity.getString(R.string.update_no_release_notes)
                MaterialAlertDialogBuilder(activity)
                    .setTitle(activity.getString(R.string.update_available_title, update.version))
                    .setMessage(activity.getString(R.string.update_available_message, notes))
                    .setPositiveButton(R.string.update_download) { _, _ -> openUrl(activity, update.downloadUrl) }
                    .setNeutralButton(R.string.update_view_release) { _, _ -> openUrl(activity, update.releaseUrl) }
                    .setNegativeButton(R.string.update_later, null)
                    .showThemed()
            }
            UpdateCheckResult.UpToDate -> if (showCurrentStatus) {
                MaterialAlertDialogBuilder(activity)
                    .setTitle(R.string.update_up_to_date_title)
                    .setMessage(R.string.update_up_to_date_message)
                    .setPositiveButton(R.string.ok, null)
                    .showThemed()
            }
            is UpdateCheckResult.Failure -> if (showCurrentStatus) {
                MaterialAlertDialogBuilder(activity)
                    .setTitle(R.string.update_check_failed_title)
                    .setMessage(activity.getString(R.string.update_check_failed_message, result.reason))
                    .setPositiveButton(R.string.ok, null)
                    .showThemed()
            }
        }
    }

    fun openUrl(activity: Activity, url: String) {
        try {
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(activity, R.string.error_no_browser, Toast.LENGTH_LONG).show()
        }
    }
}
