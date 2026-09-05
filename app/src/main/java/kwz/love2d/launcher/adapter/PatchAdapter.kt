package kwz.love2d.launcher.adapter

import android.content.res.ColorStateList
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.color.MaterialColors
import com.google.android.material.progressindicator.CircularProgressIndicator
import com.google.android.material.materialswitch.MaterialSwitch
import kwz.love2d.launcher.ui.DeltaruneSquareSwitch
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.PatchDisplayItem
import kwz.love2d.launcher.model.PatchOrigin
import kwz.love2d.launcher.model.PatchTrust
import kwz.love2d.launcher.util.PatchInstallStage

class PatchAdapter(
    private val onToggle: (PatchDisplayItem, Boolean) -> Unit,
    private val onAction: (PatchDisplayItem) -> Unit,
    private val onUseCases: (PatchDisplayItem) -> Unit,
    private val onDetails: (PatchDisplayItem) -> Unit
) : RecyclerView.Adapter<PatchAdapter.PatchViewHolder>() {

    private var items: List<PatchDisplayItem> = emptyList()
    private var installingPatchId: String? = null
    private var installStage: PatchInstallStage? = null

    fun submitItems(newItems: List<PatchDisplayItem>, onCommitted: (() -> Unit)? = null) {
        val previousItems = items
        val nextItems = newItems.toList()
        val updates = DiffUtil.calculateDiff(object : DiffUtil.Callback() {
            override fun getOldListSize(): Int = previousItems.size

            override fun getNewListSize(): Int = nextItems.size

            override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
                return previousItems[oldItemPosition].id == nextItems[newItemPosition].id
            }

            override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
                return previousItems[oldItemPosition] == nextItems[newItemPosition]
            }
        })
        items = nextItems
        updates.dispatchUpdatesTo(this)
        onCommitted?.invoke()
    }

    fun setInstallProgress(patchId: String?, stage: PatchInstallStage? = null) {
        val affectedIds = listOfNotNull(installingPatchId, patchId).toSet()
        installingPatchId = patchId
        installStage = stage
        affectedIds.forEach { affectedId ->
            val position = items.indexOfFirst { it.id == affectedId }
            if (position >= 0) notifyItemChanged(position)
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): PatchViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_patch, parent, false)
        ThemeManager.applyDeltaruneStyle(parent.context, view)
        return PatchViewHolder(view)
    }

    override fun onBindViewHolder(holder: PatchViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    inner class PatchViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val name: TextView = itemView.findViewById(R.id.tvPatchName)
        private val version: TextView = itemView.findViewById(R.id.tvPatchVersion)
        private val description: TextView = itemView.findViewById(R.id.tvPatchDescription)
        private val metadata: TextView = itemView.findViewById(R.id.tvPatchMetadata)
        private val trustBadge: TextView = itemView.findViewById(R.id.tvPatchTrust)
        private val enabledSwitch: MaterialSwitch = itemView.findViewById(R.id.switchPatchEnabled)
        private val enabledSwitchDeltarune: DeltaruneSquareSwitch = itemView.findViewById(R.id.switchPatchEnabledDeltarune)
        private val actionButton: MaterialButton = itemView.findViewById(R.id.btnPatchAction)
        private val actionProgress: CircularProgressIndicator = itemView.findViewById(R.id.patchActionProgress)
        private val useCasesButton: MaterialButton = itemView.findViewById(R.id.btnPatchUseCases)

        fun bind(item: PatchDisplayItem) {
            val context = itemView.context
            name.text = item.name
            version.text = context.getString(R.string.patch_version, item.version)
            description.text = item.description
            metadata.text = context.getString(
                R.string.patch_metadata,
                item.author,
                localizedOrigin(item.origin)
            )

            trustBadge.text = localizedTrust(item.trust)
            val badgeBackgroundColor: Int
            val badgeTextColor: Int
            when (item.trust) {
                PatchTrust.BUILT_IN -> {
                    badgeBackgroundColor = MaterialColors.getColor(
                        itemView,
                        com.google.android.material.R.attr.colorPrimaryContainer
                    )
                    badgeTextColor = MaterialColors.getColor(
                        itemView,
                        com.google.android.material.R.attr.colorOnPrimaryContainer
                    )
                }
                PatchTrust.VERIFIED -> {
                    badgeBackgroundColor = ContextCompat.getColor(context, R.color.badge_demo_bg)
                    badgeTextColor = ContextCompat.getColor(context, R.color.badge_demo_text)
                }
                PatchTrust.UNVERIFIED -> {
                    badgeBackgroundColor = ContextCompat.getColor(context, R.color.patch_unverified_container)
                    badgeTextColor = ContextCompat.getColor(context, R.color.patch_unverified_text)
                }
            }
            trustBadge.backgroundTintList = ColorStateList.valueOf(badgeBackgroundColor)
            trustBadge.setTextColor(badgeTextColor)

            val deltarune = ThemeManager.isDeltaruneTheme(context)
            val showSwitch = item.installed

            enabledSwitch.setOnCheckedChangeListener(null)
            enabledSwitch.isChecked = item.enabled
            enabledSwitch.visibility = if (showSwitch && !deltarune) View.VISIBLE else View.GONE
            enabledSwitch.isEnabled = installingPatchId == null
            enabledSwitch.setOnCheckedChangeListener { _, checked -> onToggle(item, checked) }

            enabledSwitchDeltarune.setOnCheckedChangeListener(null)
            enabledSwitchDeltarune.setChecked(item.enabled)
            enabledSwitchDeltarune.visibility = if (showSwitch && deltarune) View.VISIBLE else View.GONE
            enabledSwitchDeltarune.isEnabled = installingPatchId == null
            enabledSwitchDeltarune.setOnCheckedChangeListener { _, checked -> onToggle(item, checked) }

            val isInstalling = installingPatchId == item.id
            actionProgress.visibility = if (isInstalling) View.VISIBLE else View.GONE
            when {
                isInstalling -> {
                    actionButton.visibility = View.VISIBLE
                    actionButton.isEnabled = false
                    actionButton.setText(
                        when (installStage) {
                            PatchInstallStage.VALIDATING -> R.string.patch_validating
                            PatchInstallStage.INSTALLING -> R.string.patch_installing
                            else -> R.string.patch_downloading
                        }
                    )
                }
                !item.installed -> {
                    actionButton.visibility = View.VISIBLE
                    actionButton.isEnabled = installingPatchId == null
                    actionButton.setText(R.string.patch_download)
                }
                item.updateAvailable -> {
                    actionButton.visibility = View.VISIBLE
                    actionButton.isEnabled = installingPatchId == null
                    actionButton.setText(R.string.patch_update)
                }
                else -> actionButton.visibility = View.GONE
            }

            actionButton.setOnClickListener { onAction(item) }
            useCasesButton.visibility = View.VISIBLE
            useCasesButton.setOnClickListener { onUseCases(item) }
            itemView.setOnClickListener { onDetails(item) }
        }

        private fun localizedOrigin(origin: PatchOrigin): String {
            return itemView.context.getString(
                when (origin) {
                    PatchOrigin.BUILT_IN -> R.string.patch_origin_built_in
                    PatchOrigin.OFFICIAL -> R.string.patch_origin_official
                    PatchOrigin.IMPORTED -> R.string.patch_origin_imported
                }
            )
        }

        private fun localizedTrust(trust: PatchTrust): String {
            return itemView.context.getString(
                when (trust) {
                    PatchTrust.BUILT_IN -> R.string.patch_trust_built_in
                    PatchTrust.VERIFIED -> R.string.patch_trust_verified
                    PatchTrust.UNVERIFIED -> R.string.patch_trust_unverified
                }
            )
        }
    }
}
