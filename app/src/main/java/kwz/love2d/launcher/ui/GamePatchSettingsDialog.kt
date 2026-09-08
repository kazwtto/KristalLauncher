package kwz.love2d.launcher.ui

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.Window
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.color.MaterialColors
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.R
import kwz.love2d.launcher.adapter.GamePatchSettingsAdapter
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.util.PatchRepository
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.showThemed

object GamePatchSettingsDialog {

    fun show(context: Context, game: LoveGame) {
        val dialogContext = ThemeManager.themedContext(context)
        val deltarune = ThemeManager.isDeltaruneTheme(dialogContext)
        val amoled = deltarune && ThemeManager.isDeltaruneAmoledEnabled(dialogContext)
        val inflationRoot = FrameLayout(dialogContext)
        val dialogView = LayoutInflater.from(dialogContext)
            .inflate(R.layout.dialog_game_patches, inflationRoot, false)
        val root = dialogView.findViewById<View>(R.id.gamePatchesDialogRoot)
        val title = dialogView.findViewById<TextView>(R.id.tvGamePatchesTitle)
        val recyclerView = dialogView.findViewById<RecyclerView>(R.id.rvGamePatches)
        val cancelButton = dialogView.findViewById<MaterialButton>(R.id.btnCancelGamePatches)
        val saveButton = dialogView.findViewById<MaterialButton>(R.id.btnSaveGamePatches)

        title.text = context.getString(R.string.game_patches_dialog_title, game.title)

        val surface = if (amoled) {
            Color.BLACK
        } else {
            MaterialColors.getColor(
                dialogContext,
                com.google.android.material.R.attr.colorSurface,
                context.getColor(R.color.m3_surface)
            )
        }
        val outline = if (amoled) {
            Color.WHITE
        } else {
            MaterialColors.getColor(
                dialogContext,
                com.google.android.material.R.attr.colorOutline,
                context.getColor(R.color.m3_outline)
            )
        }
        val density = dialogContext.resources.displayMetrics.density
        root.background = GradientDrawable().apply {
            setColor(surface)
            cornerRadius = if (deltarune) 0f else 18f * density
            setStroke((density + 0.5f).toInt().coerceAtLeast(1), outline)
        }
        recyclerView.setBackgroundColor(surface)

        val patches = PatchRepository.installedDisplayItems(context)
        val adapter = GamePatchSettingsAdapter(dialogContext, game.stableId, patches)
        recyclerView.layoutManager = LinearLayoutManager(dialogContext)
        recyclerView.adapter = adapter

        ThemeManager.applyDeltaruneStyle(dialogContext, dialogView)

        val dialog = Dialog(dialogContext)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
        dialog.setContentView(dialogView)
        dialog.setCanceledOnTouchOutside(true)

        cancelButton.setOnClickListener { dialog.dismiss() }
        saveButton.setOnClickListener {
            val unverified = adapter.newlyForcedUnverifiedPatches()
            if (unverified.isEmpty()) {
                adapter.save()
                Toast.makeText(context, R.string.patches_saved, Toast.LENGTH_SHORT).show()
                dialog.dismiss()
            } else {
                MaterialAlertDialogBuilder(dialogContext)
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
                    .showThemed()
            }
        }

        dialog.setOnShowListener {
            val window = dialog.window ?: return@setOnShowListener
            val metrics = dialogContext.resources.displayMetrics
            val margin = (24f * density).toInt()
            val maxWidth = (560f * density).toInt()
            val targetWidth = (metrics.widthPixels - margin * 2)
                .coerceAtLeast(1)
                .coerceAtMost(maxWidth)
            val availableHeight = (metrics.heightPixels - margin * 2).coerceAtLeast(1)

            window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            window.setGravity(Gravity.CENTER)
            window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            window.attributes = window.attributes.apply { dimAmount = 0.32f }
            window.setLayout(targetWidth, WindowManager.LayoutParams.WRAP_CONTENT)

            dialogView.post {
                val fixedContentHeight = (dialogView.height - recyclerView.height).coerceAtLeast(0)
                val availableRecyclerHeight = (availableHeight - fixedContentHeight).coerceAtLeast(0)
                if (recyclerView.height > availableRecyclerHeight) {
                    recyclerView.layoutParams = recyclerView.layoutParams.apply {
                        height = availableRecyclerHeight
                    }
                    recyclerView.requestLayout()
                }
                window.setLayout(targetWidth, WindowManager.LayoutParams.WRAP_CONTENT)
                ThemeManager.applyDeltaruneStyle(dialogContext, dialogView)
            }
        }

        dialog.show()
    }
}
