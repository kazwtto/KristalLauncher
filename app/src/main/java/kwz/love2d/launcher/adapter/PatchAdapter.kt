package kwz.love2d.launcher.adapter

import android.content.res.ColorStateList
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.AsyncListDiffer
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.materialswitch.MaterialSwitch
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.PatchDisplayItem
import kwz.love2d.launcher.model.PatchOrigin
import kwz.love2d.launcher.model.PatchTrust

class PatchAdapter(
    private val onToggle: (PatchDisplayItem, Boolean) -> Unit,
    private val onAction: (PatchDisplayItem) -> Unit,
    private val onUseCases: (PatchDisplayItem) -> Unit,
    private val onDetails: (PatchDisplayItem) -> Unit
) : RecyclerView.Adapter<PatchAdapter.PatchViewHolder>() {

    private val differ = AsyncListDiffer(
        this,
        object : DiffUtil.ItemCallback<PatchDisplayItem>() {
            override fun areItemsTheSame(oldItem: PatchDisplayItem, newItem: PatchDisplayItem): Boolean {
                return oldItem.id == newItem.id
            }

            override fun areContentsTheSame(oldItem: PatchDisplayItem, newItem: PatchDisplayItem): Boolean {
                return oldItem == newItem
            }
        }
    )

    fun submitItems(newItems: List<PatchDisplayItem>) {
        differ.submitList(newItems.toList())
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): PatchViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_patch, parent, false)
        return PatchViewHolder(view)
    }

    override fun onBindViewHolder(holder: PatchViewHolder, position: Int) {
        holder.bind(differ.currentList[position])
    }

    override fun getItemCount(): Int = differ.currentList.size

    inner class PatchViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val name: TextView = itemView.findViewById(R.id.tvPatchName)
        private val version: TextView = itemView.findViewById(R.id.tvPatchVersion)
        private val description: TextView = itemView.findViewById(R.id.tvPatchDescription)
        private val metadata: TextView = itemView.findViewById(R.id.tvPatchMetadata)
        private val trustBadge: TextView = itemView.findViewById(R.id.tvPatchTrust)
        private val enabledSwitch: MaterialSwitch = itemView.findViewById(R.id.switchPatchEnabled)
        private val actionButton: MaterialButton = itemView.findViewById(R.id.btnPatchAction)
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
            val badgeColor = when (item.trust) {
                PatchTrust.BUILT_IN -> R.color.m3_primary_container
                PatchTrust.VERIFIED -> R.color.badge_demo_bg
                PatchTrust.UNVERIFIED -> R.color.patch_unverified_container
            }
            trustBadge.backgroundTintList = ColorStateList.valueOf(ContextCompat.getColor(context, badgeColor))
            trustBadge.setTextColor(
                ContextCompat.getColor(
                    context,
                    if (item.trust == PatchTrust.UNVERIFIED) R.color.patch_unverified_text else R.color.badge_demo_text
                )
            )

            enabledSwitch.setOnCheckedChangeListener(null)
            enabledSwitch.isChecked = item.enabled
            enabledSwitch.visibility = if (item.installed) View.VISIBLE else View.GONE
            enabledSwitch.setOnCheckedChangeListener { _, checked -> onToggle(item, checked) }

            when {
                !item.installed -> {
                    actionButton.visibility = View.VISIBLE
                    actionButton.isEnabled = true
                    actionButton.setText(R.string.patch_download)
                }
                item.updateAvailable -> {
                    actionButton.visibility = View.VISIBLE
                    actionButton.isEnabled = true
                    actionButton.setText(R.string.patch_update)
                }
                item.catalogPatch != null -> {
                    actionButton.visibility = View.VISIBLE
                    actionButton.isEnabled = false
                    actionButton.setText(R.string.patch_installed)
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
