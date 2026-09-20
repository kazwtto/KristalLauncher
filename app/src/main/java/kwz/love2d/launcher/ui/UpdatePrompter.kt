package kwz.love2d.launcher.ui

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.view.LayoutInflater
import android.widget.TextView
import android.widget.Toast
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.R
import kwz.love2d.launcher.BuildConfig
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.UpdateCheckResult
import kwz.love2d.launcher.util.showThemed

object UpdatePrompter {

    fun show(activity: Activity, result: UpdateCheckResult, showCurrentStatus: Boolean) {
        when (result) {
            is UpdateCheckResult.Available -> {
                val update = result.update
                val notes = update.releaseNotes.takeIf { it.isNotBlank() }
                    ?: activity.getString(R.string.update_no_release_notes)
                val dialogContext = ThemeManager.themedContext(activity)
                val content = LayoutInflater.from(dialogContext)
                    .inflate(R.layout.dialog_update_available, null, false)
                content.findViewById<TextView>(R.id.tvUpdateCurrentVersion).text =
                    activity.getString(R.string.update_current_version, BuildConfig.VERSION_NAME)
                content.findViewById<TextView>(R.id.tvUpdateNewVersion).text =
                    activity.getString(R.string.update_new_version, update.version)
                content.findViewById<TextView>(R.id.tvUpdateReleaseTitle).apply {
                    text = update.title
                    visibility = if (update.title.isBlank()) android.view.View.GONE else android.view.View.VISIBLE
                }
                content.findViewById<TextView>(R.id.tvUpdateReleaseNotes).text = notes
                ThemeManager.applyDeltaruneStyle(dialogContext, content)
                MaterialAlertDialogBuilder(dialogContext)
                    .setTitle(activity.getString(R.string.update_available_title, update.version))
                    .setView(content)
                    .setPositiveButton(R.string.update_download) { _, _ -> openUrl(activity, update.downloadUrl) }
                    .setNeutralButton(R.string.update_view_release) { _, _ -> openUrl(activity, update.releaseUrl) }
                    .setNegativeButton(R.string.update_later, null)
                    .create()
                    .also { dialog ->
                        dialog.showThemed()
                        ThemeManager.applyDialogTheme(dialog)
                    }
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
