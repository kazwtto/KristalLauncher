package kwz.love2d.launcher.adapter

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.widget.PopupMenu
import androidx.recyclerview.widget.AsyncListDiffer
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import kwz.love2d.launcher.R
import kwz.love2d.launcher.GameDetailsActivity
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.ui.GamePatchSettingsDialog
import kwz.love2d.launcher.ui.LayeredPreviewView
import kwz.love2d.launcher.util.FavoritesManager
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.showThemed

class GameAdapter(
    private val context: Context,
    games: List<LoveGame>,
    private var isGridView: Boolean,
    private val onGameClick: (LoveGame) -> Unit,
    private val onFavoriteToggled: (() -> Unit)? = null
) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    companion object {
        const val TYPE_LIST = 0
        const val TYPE_GRID = 1
        private val GAME_DIFF = object : DiffUtil.ItemCallback<LoveGame>() {
            override fun areItemsTheSame(oldItem: LoveGame, newItem: LoveGame): Boolean {
                return oldItem.stableId == newItem.stableId
            }

            override fun areContentsTheSame(old: LoveGame, new: LoveGame): Boolean {
                return old.title == new.title &&
                    old.fileName == new.fileName &&
                    old.sizeBytes == new.sizeBytes &&
                    old.lastModified == new.lastModified &&
                    old.subtitle == new.subtitle &&
                    old.description == new.description &&
                    old.version == new.version &&
                    old.engineVer == new.engineVer &&
                    old.author == new.author &&
                    old.projectId == new.projectId &&
                    old.chapter == new.chapter &&
                    old.startMap == new.startMap &&
                    old.party == new.party &&
                    old.packageType == new.packageType &&
                    old.modArchiveRoot == new.modArchiveRoot &&
                    old.hasIcon == new.hasIcon &&
                    old.hasPreviewBackground == new.hasPreviewBackground
            }
        }
    }

    private val differ = AsyncListDiffer(this, GAME_DIFF).apply {
        submitList(games.toList())
    }

    override fun getItemViewType(position: Int): Int {
        return if (isGridView) TYPE_GRID else TYPE_LIST
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val layoutRes = if (viewType == TYPE_GRID) {
            R.layout.item_game_grid_card
        } else {
            R.layout.item_game_card
        }
        val view = LayoutInflater.from(parent.context).inflate(layoutRes, parent, false)
        ThemeManager.applyDeltaruneStyle(parent.context, view)
        return GameViewHolder(view)
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        val game = differ.currentList[position]
        (holder as GameViewHolder).bind(game)
    }

    override fun getItemCount(): Int = differ.currentList.size

    fun updateGames(newGames: List<LoveGame>) {
        differ.submitList(newGames.toList())
    }

    fun setGridView(isGrid: Boolean) {
        if (this.isGridView != isGrid) {
            this.isGridView = isGrid
            notifyItemRangeChanged(0, itemCount)
        }
    }

    inner class GameViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val ivGameIcon: ImageView = itemView.findViewById(R.id.ivGameIcon)
        private val ivGamePreview: LayeredPreviewView? = itemView.findViewById(R.id.ivGamePreview)
        private val gamePreviewScrim: View? = itemView.findViewById(R.id.gamePreviewScrim)
        private val tvGameTitle: TextView = itemView.findViewById(R.id.tvGameTitle)
        private val tvFileName: TextView? = itemView.findViewById(R.id.tvFileName)
        private val btnPlay: View? = itemView.findViewById(R.id.btnPlay)
        private val btnMenuMore: ImageView? = itemView.findViewById(R.id.btnMenuMore)

        // Additional Kristal metadata fields
        private val tvSubtitle: TextView? = itemView.findViewById(R.id.tvSubtitle)
        private val tvAuthor: TextView? = itemView.findViewById(R.id.tvAuthor)
        private val tvVersion: TextView? = itemView.findViewById(R.id.tvVersion)
        private val tvEngineVer: TextView? = itemView.findViewById(R.id.tvEngineVer)
        private val gameTagsContainer: View? = itemView.findViewById(R.id.gameTagsContainer)

        fun bind(game: LoveGame) {
            tvGameTitle.text = game.title
            tvFileName?.text = game.displayFileName

            if (!game.subtitle.isNullOrBlank()) {
                tvSubtitle?.text = game.subtitle
                tvSubtitle?.visibility = View.VISIBLE
            } else {
                tvSubtitle?.text = null
                tvSubtitle?.visibility = if (gameTagsContainer != null) View.GONE else View.INVISIBLE
            }

            if (!game.author.isNullOrBlank()) {
                tvAuthor?.text = context.getString(R.string.game_author, game.author)
                tvAuthor?.visibility = View.VISIBLE
            } else {
                tvAuthor?.visibility = View.GONE
            }

            if (!game.version.isNullOrBlank()) {
                tvVersion?.text = game.version
                tvVersion?.visibility = View.VISIBLE
            } else {
                tvVersion?.visibility = View.GONE
            }

            if (!game.engineVer.isNullOrBlank()) {
                tvEngineVer?.text = context.getString(R.string.game_engine_version, game.engineVer)
                tvEngineVer?.visibility = View.VISIBLE
            } else {
                tvEngineVer?.visibility = View.GONE
            }

            gameTagsContainer?.visibility = if (
                !game.version.isNullOrBlank() || !game.engineVer.isNullOrBlank()
            ) View.VISIBLE else View.GONE

            if (game.icon != null) {
                ivGameIcon.setImageBitmap(game.icon)
                (ivGameIcon.drawable as? android.graphics.drawable.BitmapDrawable)?.paint?.isFilterBitmap = false
                (ivGameIcon.drawable as? android.graphics.drawable.BitmapDrawable)?.setAntiAlias(false)
            } else {
                ivGameIcon.setImageResource(R.drawable.ic_launcher)
            }

            bindPreviewBackground(game)

            itemView.setOnClickListener {
                GameDetailsActivity.open(context, game)
            }
            itemView.isClickable = true

            btnPlay?.setOnClickListener {
                launch(game)
            }

            btnMenuMore?.setOnClickListener { view ->
                showPopupMenu(view, game)
            }
        }

        private fun bindPreviewBackground(game: LoveGame) {
            ivGamePreview?.setLayers(game.previewBackgrounds)
            gamePreviewScrim?.visibility = View.VISIBLE
        }

        private fun launch(game: LoveGame) {
            FavoritesManager.addRecentGame(context, game)
            onGameClick(game)
        }

        private fun showPopupMenu(view: View, game: LoveGame) {
            val popup = PopupMenu(context, view)
            val isFav = FavoritesManager.isFavorite(context, game)

            val favTitle = if (isFav) context.getString(R.string.remove_favorite) else context.getString(R.string.add_favorite)
            popup.menu.add(0, 2, 0, favTitle)
            popup.menu.add(0, 3, 1, context.getString(R.string.action_patches))

            popup.setOnMenuItemClickListener { menuItem ->
                when (menuItem.itemId) {
                    2 -> {
                        val added = FavoritesManager.toggleFavorite(context, game)
                        val msg = if (added) context.getString(R.string.add_favorite) else context.getString(R.string.remove_favorite)
                        Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                        onFavoriteToggled?.invoke()
                        true
                    }
                    3 -> {
                        GamePatchSettingsDialog.show(context, game)
                        true
                    }
                    else -> false
                }
            }
            popup.showThemed(context, view)
        }

    }

}
