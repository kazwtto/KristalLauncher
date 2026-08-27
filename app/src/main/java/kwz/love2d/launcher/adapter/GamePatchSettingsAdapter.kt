package kwz.love2d.launcher.adapter

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButtonToggleGroup
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.PatchDisplayItem
import kwz.love2d.launcher.model.PatchOrigin
import kwz.love2d.launcher.util.PatchManager

class GamePatchSettingsAdapter(
    private val context: Context,
    private val gameId: String,
    private val items: List<PatchDisplayItem>
) : RecyclerView.Adapter<GamePatchSettingsAdapter.GamePatchViewHolder>() {

    private val modes = items.associate { item ->
        item.id to PatchManager.getGamePatchMode(context, gameId, item.id)
    }.toMutableMap()

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): GamePatchViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_game_patch_setting, parent, false)
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
        private val name: TextView = itemView.findViewById(R.id.tvGamePatchName)
        private val description: TextView = itemView.findViewById(R.id.tvGamePatchDescription)
        private val effectiveState: TextView = itemView.findViewById(R.id.tvGamePatchEffectiveState)
        private val toggleGroup: MaterialButtonToggleGroup = itemView.findViewById(R.id.gamePatchModeGroup)
        private var boundPatchId: String? = null
        private var binding = false

        init {
            toggleGroup.addOnButtonCheckedListener { _, checkedId, isChecked ->
                if (!isChecked || binding) return@addOnButtonCheckedListener
                val patchId = boundPatchId ?: return@addOnButtonCheckedListener
                modes[patchId] = when (checkedId) {
                    R.id.btnGamePatchEnabled -> PatchManager.MODE_FORCE_ENABLED
                    R.id.btnGamePatchDisabled -> PatchManager.MODE_FORCE_DISABLED
                    else -> PatchManager.MODE_GLOBAL
                }
                updateEffectiveState(patchId)
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
            updateEffectiveState(item.id)
        }

        private fun updateEffectiveState(patchId: String) {
            val mode = modes[patchId] ?: PatchManager.MODE_GLOBAL
            effectiveState.text = when (mode) {
                PatchManager.MODE_FORCE_ENABLED -> context.getString(R.string.patch_game_effective_forced_enabled)
                PatchManager.MODE_FORCE_DISABLED -> context.getString(R.string.patch_game_effective_forced_disabled)
                else -> if (PatchManager.isGlobalPatchEnabled(context, patchId)) {
                    context.getString(R.string.patch_game_effective_inherited_enabled)
                } else {
                    context.getString(R.string.patch_game_effective_inherited_disabled)
                }
            }
        }
    }
}
