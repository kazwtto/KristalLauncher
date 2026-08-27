package kwz.love2d.launcher.ui

import android.content.Context
import android.view.LayoutInflater
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.R
import kwz.love2d.launcher.adapter.GamePatchSettingsAdapter
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.util.PatchRepository

object GamePatchSettingsDialog {

    fun show(context: Context, game: LoveGame) {
        val dialogView = LayoutInflater.from(context).inflate(R.layout.dialog_game_patches, null)
        val recyclerView = dialogView.findViewById<RecyclerView>(R.id.rvGamePatches)
        val patches = PatchRepository.installedDisplayItems(context)
        val adapter = GamePatchSettingsAdapter(context, game.stableId, patches)
        recyclerView.layoutManager = LinearLayoutManager(context)
        recyclerView.adapter = adapter

        val dialog = MaterialAlertDialogBuilder(context)
            .setTitle(context.getString(R.string.game_patches_dialog_title, game.title))
            .setView(dialogView)
            .setPositiveButton(R.string.save, null)
            .setNegativeButton(R.string.cancel, null)
            .create()

        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                val unverified = adapter.newlyForcedUnverifiedPatches()
                if (unverified.isEmpty()) {
                    adapter.save()
                    Toast.makeText(context, R.string.patches_saved, Toast.LENGTH_SHORT).show()
                    dialog.dismiss()
                } else {
                    MaterialAlertDialogBuilder(context)
                        .setTitle(R.string.warning_attention)
                        .setMessage(
                            context.getString(
                                R.string.patch_game_unverified_warning,
                                unverified.joinToString()
                            )
                        )
                        .setPositiveButton(R.string.enable) { _, _ ->
                            adapter.save()
                            Toast.makeText(context, R.string.patches_saved, Toast.LENGTH_SHORT).show()
                            dialog.dismiss()
                        }
                        .setNegativeButton(R.string.cancel, null)
                        .show()
                }
            }
        }
        dialog.show()
    }
}
