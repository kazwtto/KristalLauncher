package kwz.love2d.launcher.adapter

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.card.MaterialCardView
import com.google.android.material.color.MaterialColors
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.PatchDisplayItem
import kwz.love2d.launcher.model.PatchOrigin
import kwz.love2d.launcher.util.PatchManager
import kwz.love2d.launcher.util.ThemeManager

class GamePatchSettingsAdapter(
    private val context: Context,
    private val gameId: String,
    private val items: List<PatchDisplayItem>,
    private val saveImmediately: Boolean = false
) : RecyclerView.Adapter<GamePatchSettingsAdapter.GamePatchViewHolder>() {

    private val amoled = ThemeManager.isDeltaruneTheme(context) &&
        ThemeManager.isDeltaruneAmoledEnabled(context)

    private val modes = items.associate { item ->
        item.id to PatchManager.getGamePatchMode(context, gameId, item.id)
    }.toMutableMap()

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): GamePatchViewHolder {
        val view = LayoutInflater.from(context).inflate(R.layout.item_game_patch_setting, parent, false)
        ThemeManager.applyDeltaruneStyle(context, view)
        return GamePatchViewHolder(view)
    }

    override fun onBindViewHolder(holder: GamePatchViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    fun save() {
        modes.forEach { (patchId, mode) ->
            PatchManager.setGamePatchMode(context, gameId, patchId, mode)
        }
    }

    fun newlyForcedUnverifiedPatches(): List<String> {
        return items.filter { item ->
            item.origin == PatchOrigin.IMPORTED &&
                modes[item.id] == PatchManager.MODE_FORCE_ENABLED &&
                PatchManager.getGamePatchMode(context, gameId, item.id) != PatchManager.MODE_FORCE_ENABLED
        }.map { it.name }
    }

    inner class GamePatchViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val card = itemView as MaterialCardView
        private val cardContent: View = itemView.findViewById(R.id.gamePatchCardContent)
        private val name: TextView = itemView.findViewById(R.id.tvGamePatchName)
        private val description: TextView = itemView.findViewById(R.id.tvGamePatchDescription)
        private val toggleGroup: MaterialButtonToggleGroup = itemView.findViewById(R.id.gamePatchModeGroup)
        private val inheritButton: MaterialButton = itemView.findViewById(R.id.btnGamePatchInherit)
        private val enabledButton: MaterialButton = itemView.findViewById(R.id.btnGamePatchEnabled)
        private val disabledButton: MaterialButton = itemView.findViewById(R.id.btnGamePatchDisabled)
        private var boundPatchId: String? = null
        private var binding = false

        init {
            if (amoled) applyAmoledVisuals()
            toggleGroup.addOnButtonCheckedListener { _, checkedId, isChecked ->
                if (!isChecked || binding) return@addOnButtonCheckedListener
                val patchId = boundPatchId ?: return@addOnButtonCheckedListener
                modes[patchId] = when (checkedId) {
                    R.id.btnGamePatchEnabled -> PatchManager.MODE_FORCE_ENABLED
                    R.id.btnGamePatchDisabled -> PatchManager.MODE_FORCE_DISABLED
                    else -> PatchManager.MODE_GLOBAL
                }
                if (saveImmediately) {
                    PatchManager.setGamePatchMode(context, gameId, patchId, modes.getValue(patchId))
                }
                if (amoled) {
                    applyAmoledVisuals()
                    toggleGroup.post { applyAmoledVisuals() }
                }
            }
        }

        fun bind(item: PatchDisplayItem) {
            boundPatchId = item.id
            name.text = item.name
            description.text = item.description
            binding = true
            toggleGroup.check(
                when (modes[item.id]) {
                    PatchManager.MODE_FORCE_ENABLED -> R.id.btnGamePatchEnabled
                    PatchManager.MODE_FORCE_DISABLED -> R.id.btnGamePatchDisabled
                    else -> R.id.btnGamePatchInherit
                }
            )
            binding = false
            if (amoled) {
                applyAmoledVisuals()
                itemView.post { applyAmoledVisuals() }
            }
        }

        private fun applyAmoledVisuals() {
            val outline = MaterialColors.getColor(
                context,
                com.google.android.material.R.attr.colorOutline,
                context.getColor(R.color.m3_outline)
            )
            val primary = MaterialColors.getColor(
                context,
                com.google.android.material.R.attr.colorPrimary,
                context.getColor(R.color.m3_primary)
            )
            val primaryContainer = MaterialColors.getColor(
                context,
                com.google.android.material.R.attr.colorPrimaryContainer,
                context.getColor(R.color.m3_primary_container)
            )
            val onPrimaryContainer = MaterialColors.getColor(
                context,
                com.google.android.material.R.attr.colorOnPrimaryContainer,
                Color.WHITE
            )
            val onSurface = MaterialColors.getColor(
                context,
                com.google.android.material.R.attr.colorOnSurface,
                Color.WHITE
            )

            card.setCardBackgroundColor(Color.BLACK)
            card.backgroundTintList = ColorStateList.valueOf(Color.BLACK)
            card.strokeWidth = (context.resources.displayMetrics.density + 0.5f).toInt().coerceAtLeast(1)
            card.strokeColor = outline
            cardContent.setBackgroundColor(Color.BLACK)

            val checkedState = intArrayOf(android.R.attr.state_checked)
            val defaultState = intArrayOf()
            val states = arrayOf(checkedState, defaultState)
            val backgroundColors = ColorStateList(
                states,
                intArrayOf(primaryContainer, Color.BLACK)
            )
            val textColors = ColorStateList(
                states,
                intArrayOf(onPrimaryContainer, onSurface)
            )
            val strokeColors = ColorStateList(
                states,
                intArrayOf(primary, outline)
            )

            listOf(inheritButton, enabledButton, disabledButton).forEach { button ->
                button.backgroundTintList = backgroundColors
                button.setTextColor(textColors)
                button.strokeColor = strokeColors
                button.rippleColor = ColorStateList.valueOf(Color.TRANSPARENT)
                button.stateListAnimator = null
                button.elevation = 0f
                button.translationZ = 0f
                button.cornerRadius = 0
                button.invalidate()
            }
        }

    }
}
