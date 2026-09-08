package kwz.love2d.launcher

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButton
import com.google.android.material.color.MaterialColors
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.ui.GamePatchSettingsDialog
import kwz.love2d.launcher.util.FavoritesManager
import kwz.love2d.launcher.util.GameLauncher
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager

class GameDetailsActivity : AppCompatActivity() {

    private lateinit var game: LoveGame
    private lateinit var favoriteButton: ImageButton
    private lateinit var favoriteActionIcon: ImageView

    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeManager.applyActivityTheme(this)
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_game_details)

        game = resolveGame() ?: run {
            finish()
            return
        }

        favoriteButton = findViewById(R.id.btnDetailsFavoriteTop)
        favoriteActionIcon = findViewById(R.id.ivDetailsFavoriteAction)
        bindGame()
        bindActions()
        refreshFavorite()

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = NavigationAnimations.finish(this@GameDetailsActivity)
        })
    }

    override fun onResume() {
        super.onResume()
        if (::favoriteButton.isInitialized) refreshFavorite()
    }

    private fun bindGame() {
        findViewById<TextView>(R.id.tvDetailsTitle).text = game.title
        findViewById<TextView>(R.id.tvDetailsFileName).text = game.displayFileName
        findViewById<TextView>(R.id.tvDetailsAbout).text =
            game.description?.takeIf(String::isNotBlank)
                ?: game.subtitle?.takeIf(String::isNotBlank)
                ?: getString(R.string.game_details_no_description)
        bindOptionalText(findViewById(R.id.tvDetailsVersion), game.version)
        bindOptionalText(
            findViewById(R.id.tvDetailsEngine),
            game.engineVer?.let { getString(R.string.game_engine_version, it) }
        )

        val authorLabel = findViewById<TextView>(R.id.tvDetailsAuthorLabel)
        val author = findViewById<TextView>(R.id.tvDetailsAuthor)
        val hasAuthor = !game.author.isNullOrBlank()
        authorLabel.visibility = if (hasAuthor) View.VISIBLE else View.GONE
        author.visibility = if (hasAuthor) View.VISIBLE else View.GONE
        author.text = game.author

        bindMetadataRow(R.id.detailsProjectIdRow, R.id.tvDetailsProjectId, game.projectId)
        bindMetadataRow(R.id.detailsChapterRow, R.id.tvDetailsChapter, game.chapter)
        bindMetadataRow(R.id.detailsStartMapRow, R.id.tvDetailsStartMap, game.startMap)
        bindMetadataRow(
            R.id.detailsPartyRow,
            R.id.tvDetailsParty,
            game.party.takeIf { it.isNotEmpty() }?.joinToString(", ")
        )

        val icon = findViewById<ImageView>(R.id.ivDetailsIcon)
        val iconSize = (resources.displayMetrics.widthPixels * DETAILS_ICON_WIDTH_RATIO).toInt()
        icon.layoutParams = icon.layoutParams.apply {
            width = iconSize
            height = iconSize
        }
        findViewById<FrameLayout>(R.id.detailsHero).layoutParams =
            findViewById<FrameLayout>(R.id.detailsHero).layoutParams.apply {
                height = iconSize + (24 * resources.displayMetrics.density).toInt()
            }
        game.icon?.let { bitmap ->
            icon.setImageBitmap(bitmap)
            (icon.drawable as? BitmapDrawable)?.apply {
                paint.isFilterBitmap = false
                setAntiAlias(false)
            }
        } ?: icon.setImageResource(R.drawable.ic_launcher)
    }

    private fun bindActions() {
        findViewById<View>(R.id.btnDetailsClose).setOnClickListener {
            NavigationAnimations.finish(this)
        }
        favoriteButton.setOnClickListener { toggleFavorite() }
        findViewById<MaterialButton>(R.id.btnDetailsPlay).setOnClickListener {
            FavoritesManager.addRecentGame(this, game)
            GameLauncher.launchGame(this, game)
        }
        findViewById<View>(R.id.actionDetailsFavorite).setOnClickListener { toggleFavorite() }
        findViewById<View>(R.id.actionDetailsSettings).setOnClickListener {
            NavigationAnimations.start(this, Intent(this, SettingsActivity::class.java))
        }
        findViewById<View>(R.id.actionDetailsCompatibility).setOnClickListener {
            GamePatchSettingsDialog.show(this, game)
        }
        findViewById<View>(R.id.actionDetailsMore).apply {
            isEnabled = false
            isClickable = false
        }
    }

    private fun toggleFavorite() {
        FavoritesManager.toggleFavorite(this, game)
        refreshFavorite()
    }

    private fun refreshFavorite() {
        val selected = FavoritesManager.isFavorite(this, game)
        val color = MaterialColors.getColor(
            favoriteButton,
            if (selected) com.google.android.material.R.attr.colorPrimary
            else com.google.android.material.R.attr.colorOnSurfaceVariant
        )
        favoriteButton.imageTintList = ColorStateList.valueOf(color)
        favoriteButton.isSelected = selected
        favoriteActionIcon.imageTintList = ColorStateList.valueOf(color)
        favoriteActionIcon.isSelected = selected
    }

    private fun resolveGame(): LoveGame? {
        val requestedId = intent.getStringExtra(EXTRA_STABLE_ID)
        selectedGame?.takeIf { it.stableId == requestedId }?.let { return it }
        val title = intent.getStringExtra(EXTRA_TITLE) ?: return null
        val fileName = intent.getStringExtra(EXTRA_FILE_NAME) ?: return null
        val uri = intent.getStringExtra(EXTRA_URI)?.let(Uri::parse) ?: return null
        return LoveGame(
            title = title,
            fileName = fileName,
            uri = uri,
            archiveEntryPath = intent.getStringExtra(EXTRA_ARCHIVE_ENTRY),
            sizeBytes = intent.getLongExtra(EXTRA_SIZE, 0L),
            lastModified = intent.getLongExtra(EXTRA_LAST_MODIFIED, 0L),
            subtitle = intent.getStringExtra(EXTRA_SUBTITLE),
            description = intent.getStringExtra(EXTRA_DESCRIPTION),
            version = intent.getStringExtra(EXTRA_VERSION),
            engineVer = intent.getStringExtra(EXTRA_ENGINE_VERSION),
            author = intent.getStringExtra(EXTRA_AUTHOR),
            projectId = intent.getStringExtra(EXTRA_PROJECT_ID),
            chapter = intent.getStringExtra(EXTRA_CHAPTER),
            startMap = intent.getStringExtra(EXTRA_START_MAP),
            party = intent.getStringArrayListExtra(EXTRA_PARTY).orEmpty()
        )
    }

    private fun bindOptionalText(view: TextView, value: String?) {
        view.text = value
        view.visibility = if (value.isNullOrBlank()) View.GONE else View.VISIBLE
    }

    private fun bindMetadataRow(rowId: Int, valueId: Int, value: String?) {
        val hasValue = !value.isNullOrBlank()
        findViewById<View>(rowId).visibility = if (hasValue) View.VISIBLE else View.GONE
        findViewById<TextView>(valueId).text = value
    }

    companion object {
        private const val DETAILS_ICON_WIDTH_RATIO = 0.4f

        @Volatile
        private var selectedGame: LoveGame? = null

        fun open(context: Context, game: LoveGame) {
            selectedGame = game
            val intent = Intent(context, GameDetailsActivity::class.java).apply {
                putExtra(EXTRA_STABLE_ID, game.stableId)
                putExtra(EXTRA_TITLE, game.title)
                putExtra(EXTRA_FILE_NAME, game.fileName)
                putExtra(EXTRA_URI, game.uri.toString())
                putExtra(EXTRA_ARCHIVE_ENTRY, game.archiveEntryPath)
                putExtra(EXTRA_SIZE, game.sizeBytes)
                putExtra(EXTRA_LAST_MODIFIED, game.lastModified)
                putExtra(EXTRA_SUBTITLE, game.subtitle)
                putExtra(EXTRA_DESCRIPTION, game.description)
                putExtra(EXTRA_VERSION, game.version)
                putExtra(EXTRA_ENGINE_VERSION, game.engineVer)
                putExtra(EXTRA_AUTHOR, game.author)
                putExtra(EXTRA_PROJECT_ID, game.projectId)
                putExtra(EXTRA_CHAPTER, game.chapter)
                putExtra(EXTRA_START_MAP, game.startMap)
                putStringArrayListExtra(EXTRA_PARTY, ArrayList(game.party))
            }
            if (context is Activity) {
                NavigationAnimations.start(context, intent)
            } else {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
        }

        private const val EXTRA_STABLE_ID = "game_stable_id"
        private const val EXTRA_TITLE = "game_title"
        private const val EXTRA_FILE_NAME = "game_file_name"
        private const val EXTRA_URI = "game_uri"
        private const val EXTRA_ARCHIVE_ENTRY = "game_archive_entry"
        private const val EXTRA_SIZE = "game_size"
        private const val EXTRA_LAST_MODIFIED = "game_last_modified"
        private const val EXTRA_SUBTITLE = "game_subtitle"
        private const val EXTRA_DESCRIPTION = "game_description"
        private const val EXTRA_VERSION = "game_version"
        private const val EXTRA_ENGINE_VERSION = "game_engine_version"
        private const val EXTRA_AUTHOR = "game_author"
        private const val EXTRA_PROJECT_ID = "game_project_id"
        private const val EXTRA_CHAPTER = "game_chapter"
        private const val EXTRA_START_MAP = "game_start_map"
        private const val EXTRA_PARTY = "game_party"
    }
}
