package kwz.love2d.launcher

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.PopupMenu
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.DefaultItemAnimator
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.google.android.material.button.MaterialButton
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton
import com.google.android.material.floatingactionbutton.FloatingActionButton
import kwz.love2d.launcher.adapter.GameAdapter
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.util.FavoritesManager
import kwz.love2d.launcher.util.FolderPermissionManager
import kwz.love2d.launcher.util.GameCacheManager
import kwz.love2d.launcher.util.GameLauncher
import kwz.love2d.launcher.util.KristalRuntimeStorage
import kwz.love2d.launcher.util.GameScanner
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.showThemed
import kwz.love2d.launcher.util.UpdateChecker
import kwz.love2d.launcher.util.UpdateCheckResult
import kwz.love2d.launcher.ui.AddGamesTutorialDialog
import kwz.love2d.launcher.ui.UpdatePrompter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AppCompatActivity() {

    private lateinit var rvGames: RecyclerView
    private lateinit var swipeRefresh: SwipeRefreshLayout
    private lateinit var progressBar: ProgressBar
    private lateinit var emptyStateLayout: LinearLayout
    private lateinit var tvEmptyState: TextView
    private lateinit var tvSelectedFolderPath: TextView
    private lateinit var btnSelectFolderEmpty: MaterialButton
    private lateinit var etSearch: EditText
    private lateinit var btnFilter: ImageView
    private lateinit var fabAddGames: ExtendedFloatingActionButton
    private lateinit var fabKristalRuntime: FloatingActionButton
    private lateinit var bottomNavigation: BottomNavigationView
    private lateinit var topAppBar: MaterialToolbar

    private var gameAdapter: GameAdapter? = null
    private var allGamesList: List<LoveGame> = emptyList()
    private var displayedGamesList: List<LoveGame> = emptyList()
    private var selectedFolderUri: Uri? = null
    private var isGridView = false
    private var currentTabId = R.id.navigation_library
    private var scanJob: Job? = null

    private val folderPickerLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri: Uri? ->
        if (uri != null) {
            try {
                FolderPermissionManager.replaceFolder(this, uri)
            } catch (_: SecurityException) {
                MaterialAlertDialogBuilder(this)
                    .setMessage(R.string.folder_permission_error)
                    .setPositiveButton(R.string.ok, null)
                    .showThemed()
                return@registerForActivityResult
            }
            selectedFolderUri = uri
            allGamesList = emptyList()
            displayedGamesList = emptyList()
            displayGames(emptyList())
            scanFolder(uri)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeManager.applyActivityTheme(this)
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_main)

        topAppBar = findViewById(R.id.topAppBar)
        setSupportActionBar(topAppBar)
        supportActionBar?.setDisplayShowTitleEnabled(false)

        rvGames = findViewById(R.id.rvGames)
        swipeRefresh = findViewById(R.id.swipeRefresh)
        progressBar = findViewById(R.id.progressBar)
        emptyStateLayout = findViewById(R.id.emptyStateLayout)
        tvEmptyState = findViewById(R.id.tvEmptyState)
        tvSelectedFolderPath = findViewById(R.id.tvSelectedFolderPath)
        btnSelectFolderEmpty = findViewById(R.id.btnSelectFolderEmpty)
        etSearch = findViewById(R.id.etSearch)
        btnFilter = findViewById(R.id.btnFilter)
        fabAddGames = findViewById(R.id.fabAddGames)
        fabKristalRuntime = findViewById(R.id.fabKristalRuntime)
        bottomNavigation = findViewById(R.id.bottomNavigation)

        val prefs = getSharedPreferences("launcher_prefs", Context.MODE_PRIVATE)
        isGridView = prefs.getBoolean("is_grid_view", false)

        setupRecyclerView()
        setupBottomNavigation()

        swipeRefresh.setOnRefreshListener {
            val uri = selectedFolderUri
            if (uri != null) {
                scanFolder(uri, forceRefresh = true)
            } else {
                swipeRefresh.isRefreshing = false
                folderPickerLauncher.launch(null)
            }
        }

        btnSelectFolderEmpty.setOnClickListener {
            folderPickerLauncher.launch(null)
        }

        fabAddGames.setOnClickListener {
            folderPickerLauncher.launch(null)
        }

        fabKristalRuntime.setOnClickListener {
            KristalRuntimeStorage.selectedRuntime(this)?.let { runtime ->
                GameLauncher.launchKristalRuntime(this, runtime)
            } ?: updateKristalRuntimeButton()
        }

        btnFilter.setOnClickListener { view ->
            showFilterMenu(view)
        }

        etSearch.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                filterGames(s?.toString() ?: "")
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        // Display the primary metadata cache immediately while a fresh scan runs.
        selectedFolderUri = FolderPermissionManager.getSavedFolderUri(this)
        val uri = selectedFolderUri

        if (uri != null) {
            scanFolder(uri, loadCache = true)
        } else {
            displayGames(emptyList())
        }

        checkForUpdatesAutomatically()
    }

    private fun checkForUpdatesAutomatically() {
        if (!UpdateChecker.shouldRunAutomaticCheck(this)) return
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) { UpdateChecker.check(this@MainActivity) }
            if (lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.STARTED) &&
                result is UpdateCheckResult.Available &&
                UpdateChecker.shouldNotify(this@MainActivity, result.update.version)
            ) {
                UpdateChecker.markNotified(this@MainActivity, result.update.version)
                UpdatePrompter.show(this@MainActivity, result, showCurrentStatus = false)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        updateKristalRuntimeButton()
        lifecycleScope.launch(Dispatchers.IO) {
            GameCacheManager.clearRuntimeGameCopies(this@MainActivity)
        }
        rvGames.itemAnimator = if (ThemeManager.areAnimationsEnabled(this)) {
            DefaultItemAnimator().apply { supportsChangeAnimations = false }
        } else {
            null
        }
        val newUri = FolderPermissionManager.getSavedFolderUri(this)
        if (newUri?.toString() != selectedFolderUri?.toString()) {
            selectedFolderUri = newUri
            if (newUri != null) {
                allGamesList = emptyList()
                displayedGamesList = emptyList()
                displayGames(emptyList())
                scanFolder(newUri)
            } else {
                allGamesList = emptyList()
                displayGames(emptyList())
            }
        } else {
            applyCurrentTabFilter()
        }
    }

    private fun updateKristalRuntimeButton() {
        fabKristalRuntime.visibility = if (KristalRuntimeStorage.selectedRuntime(this) != null) {
            View.VISIBLE
        } else {
            View.GONE
        }
    }

    private fun setupBottomNavigation() {
        bottomNavigation.selectedItemId = R.id.navigation_library
        bottomNavigation.setOnItemSelectedListener { item ->
            currentTabId = item.itemId
            applyCurrentTabFilter()
            true
        }
    }

    private fun applyCurrentTabFilter() {
        val filtered = when (currentTabId) {
            R.id.navigation_library -> allGamesList
            R.id.navigation_recent -> {
                val recentGameIds = FavoritesManager.getRecentGameIds(this)
                if (recentGameIds.isEmpty()) {
                    emptyList()
                } else {
                    val gamesById = allGamesList.associateBy { it.stableId }
                    recentGameIds.mapNotNull { id ->
                        gamesById[id] ?: allGamesList.find { it.fileName == id }
                    }
                }
            }
            R.id.navigation_favorites -> {
                val favoriteSet = FavoritesManager.getFavoriteGameIds(this)
                allGamesList.filter { it.stableId in favoriteSet || it.fileName in favoriteSet }
            }
            else -> allGamesList
        }
        displayedGamesList = filtered
        filterGames(etSearch.text.toString())
    }

    private fun showFilterMenu(view: View) {
        val popup = PopupMenu(this, view)
        popup.menu.add(0, 1, 0, R.string.sort_by_name)
        popup.menu.add(0, 2, 1, R.string.sort_by_size)
        popup.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                1 -> {
                    allGamesList = allGamesList.sortedBy { it.title }
                    applyCurrentTabFilter()
                    true
                }
                2 -> {
                    allGamesList = allGamesList.sortedByDescending { it.sizeBytes }
                    applyCurrentTabFilter()
                    true
                }
                else -> false
            }
        }
        popup.showThemed(this, view)
    }

    private fun setupRecyclerView() {
        // Dynamic span count based on screen width to avoid huge cards on tablets
        val displayMetrics = resources.displayMetrics
        val screenWidthDp = displayMetrics.widthPixels / displayMetrics.density
        // Ideal card width is ~160dp. Max 8 columns to prevent tiny cards
        val spanCount = (screenWidthDp / 160f).toInt().coerceIn(2, 8)

        if (isGridView) {
            // Together with the card's 6 dp margin, this keeps the outer card edges
            // aligned with the search bar while reducing each two-column card by ~5%.
            val horizontalGridPadding = (10f * displayMetrics.density).toInt()
            rvGames.setPaddingRelative(
                horizontalGridPadding,
                rvGames.paddingTop,
                horizontalGridPadding,
                rvGames.paddingBottom
            )
            rvGames.layoutManager = GridLayoutManager(this, spanCount)
        } else {
            rvGames.setPaddingRelative(
                0,
                rvGames.paddingTop,
                0,
                rvGames.paddingBottom
            )
            rvGames.layoutManager = LinearLayoutManager(this)
        }

        if (gameAdapter == null) {
            gameAdapter = GameAdapter(
                context = this,
                games = displayedGamesList,
                isGridView = isGridView,
                onGameClick = { game ->
                    GameLauncher.launchGame(this, game)
                },
                onFavoriteToggled = {
                    applyCurrentTabFilter()
                }
            )
            rvGames.adapter = gameAdapter
        } else {
            gameAdapter?.setGridView(isGridView)
        }

        rvGames.itemAnimator = if (ThemeManager.areAnimationsEnabled(this)) {
            DefaultItemAnimator().apply { supportsChangeAnimations = false }
        } else {
            null
        }
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.main_menu, menu)

        val modeItem = menu.findItem(R.id.action_view_mode)
        if (isGridView) {
            modeItem?.setIcon(
                ThemeManager.resolveDrawableResource(
                    this,
                    R.attr.kristalIconViewList,
                    R.drawable.ic_view_list
                )
            )
        } else {
            modeItem?.setIcon(
                ThemeManager.resolveDrawableResource(
                    this,
                    R.attr.kristalIconViewGrid,
                    R.drawable.ic_view_grid
                )
            )
        }

        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.action_view_mode -> {
                isGridView = !isGridView
                saveViewMode(isGridView)
                setupRecyclerView()
                displayGames(displayedGamesList)
                invalidateOptionsMenu()
                true
            }
            R.id.action_settings -> {
                NavigationAnimations.start(this, Intent(this, SettingsActivity::class.java))
                true
            }
            R.id.action_patches -> {
                NavigationAnimations.start(this, Intent(this, PatchesSettingsActivity::class.java))
                true
            }
            R.id.action_help -> {
                AddGamesTutorialDialog.show(
                    context = this,
                    folderAlreadySelected = selectedFolderUri != null,
                    onChooseFolder = { folderPickerLauncher.launch(null) }
                )
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    private fun scanFolder(
        folderUri: Uri,
        loadCache: Boolean = false,
        forceRefresh: Boolean = false
    ) {
        scanJob?.cancel()
        tvSelectedFolderPath.text = folderUri.path

        if (allGamesList.isEmpty()) {
            progressBar.visibility = View.VISIBLE
            emptyStateLayout.visibility = View.GONE
            rvGames.visibility = View.GONE
        } else {
            swipeRefresh.isRefreshing = true
        }

        val newScanJob = lifecycleScope.launch(start = CoroutineStart.LAZY) {
            try {
                var cachedGames = allGamesList
                if (loadCache) {
                    cachedGames = withContext(Dispatchers.IO) {
                        GameCacheManager.getCachedGames(
                            context = this@MainActivity,
                            folderUri = folderUri,
                            loadIcons = true
                        )
                    }
                    if (cachedGames.isNotEmpty() && selectedFolderUri == folderUri) {
                        allGamesList = cachedGames
                        applyCurrentTabFilter()
                        progressBar.visibility = View.GONE
                    }
                }

                val scanResult = GameScanner.scanGamesInFolder(
                    context = this@MainActivity,
                    folderUri = folderUri,
                    cachedGames = cachedGames,
                    forceRefresh = forceRefresh
                )
                val games = scanResult.games

                if (selectedFolderUri == folderUri) {
                    allGamesList = games
                    applyCurrentTabFilter()
                    progressBar.visibility = View.GONE
                    swipeRefresh.isRefreshing = false
                    if (scanResult.failedFiles.isNotEmpty()) {
                        Toast.makeText(
                            this@MainActivity,
                            getString(
                                R.string.games_scan_partial_failure,
                                scanResult.failedFiles.joinToString()
                            ),
                            Toast.LENGTH_LONG
                        ).show()
                    }
                }
                withContext(Dispatchers.IO) {
                    GameCacheManager.saveGamesCache(this@MainActivity, folderUri, games)
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                error.printStackTrace()
                if (error is SecurityException) {
                    FolderPermissionManager.clearFolder(this@MainActivity)
                    selectedFolderUri = null
                    allGamesList = emptyList()
                    applyCurrentTabFilter()
                }
                MaterialAlertDialogBuilder(this@MainActivity)
                    .setTitle(R.string.error_title)
                    .setMessage(getString(R.string.folder_scan_error, error.message ?: error.javaClass.simpleName))
                    .setPositiveButton(R.string.ok, null)
                    .showThemed()
            } finally {
                if (scanJob === kotlin.coroutines.coroutineContext[Job]) {
                    progressBar.visibility = View.GONE
                    swipeRefresh.isRefreshing = false
                }
            }
        }
        scanJob = newScanJob
        newScanJob.start()
    }

    private fun filterGames(query: String) {
        val filtered = if (query.isBlank()) {
            displayedGamesList
        } else {
            displayedGamesList.filter { it.title.contains(query, ignoreCase = true) || it.fileName.contains(query, ignoreCase = true) }
        }
        displayGames(filtered)
    }

    private fun displayGames(games: List<LoveGame>) {
        if (games.isEmpty()) {
            rvGames.visibility = View.GONE
            if (progressBar.visibility != View.VISIBLE) {
                emptyStateLayout.visibility = View.VISIBLE
            }

            if (selectedFolderUri == null) {
                tvEmptyState.setText(R.string.select_folder_dialog_title)
                tvSelectedFolderPath.setText(R.string.select_folder_prompt)
                btnSelectFolderEmpty.visibility = View.VISIBLE
            } else if (currentTabId == R.id.navigation_favorites) {
                tvEmptyState.setText(R.string.no_favorite_games)
                tvSelectedFolderPath.setText(R.string.no_favorite_games_hint)
                btnSelectFolderEmpty.visibility = View.GONE
            } else if (currentTabId == R.id.navigation_recent) {
                tvEmptyState.setText(R.string.no_recent_games)
                tvSelectedFolderPath.setText(R.string.no_recent_games_hint)
                btnSelectFolderEmpty.visibility = View.GONE
            } else {
                tvEmptyState.setText(R.string.no_games_found)
                tvSelectedFolderPath.text = selectedFolderUri?.path
                btnSelectFolderEmpty.visibility = View.GONE
            }
        } else {
            emptyStateLayout.visibility = View.GONE
            rvGames.visibility = View.VISIBLE
            gameAdapter?.updateGames(games)
        }
    }

    private fun saveViewMode(isGrid: Boolean) {
        val prefs = getSharedPreferences("launcher_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("is_grid_view", isGrid).apply()
    }
}
