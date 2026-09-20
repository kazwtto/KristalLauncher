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
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.color.MaterialColors
import com.google.android.material.card.MaterialCardView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.adapter.GamePatchSettingsAdapter
import kwz.love2d.launcher.adapter.CommunityTranslationAdapter
import kwz.love2d.launcher.adapter.TranslationDisplayItem
import kwz.love2d.launcher.adapter.TranslationItemAction
import kwz.love2d.launcher.model.CatalogTranslation
import kwz.love2d.launcher.model.CommunityTranslationInstallResult
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.model.GamePackageType
import kwz.love2d.launcher.model.CatalogPatch
import kwz.love2d.launcher.model.PatchDisplayItem
import kwz.love2d.launcher.model.PatchInstallResult
import kwz.love2d.launcher.util.FavoritesManager
import kwz.love2d.launcher.util.GameLauncher
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.PatchRepository
import kwz.love2d.launcher.util.PatchCatalogResult
import kwz.love2d.launcher.util.PatchCatalogService
import kwz.love2d.launcher.util.PatchPackageInstaller
import kwz.love2d.launcher.util.PatchManager
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.TranslationManager
import kwz.love2d.launcher.util.CommunityTranslationCatalogResult
import kwz.love2d.launcher.util.CommunityTranslationCatalogService
import kwz.love2d.launcher.util.CommunityTranslationInstallStage
import kwz.love2d.launcher.util.CommunityTranslationInstaller
import kwz.love2d.launcher.util.CommunityTranslationStorage
import kwz.love2d.launcher.util.VersionUtils
import kwz.love2d.launcher.util.KristalRuntimeStorage
import kwz.love2d.launcher.util.showThemed
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class GameDetailsActivity : AppCompatActivity() {

    private lateinit var game: LoveGame
    private lateinit var favoriteButton: ImageButton
    private lateinit var translationAdapter: CommunityTranslationAdapter
    private var catalogTranslations: List<CatalogTranslation> = emptyList()
    private var translationCatalogLoading = false
    private var translationBusyKey: String? = null
    private var translationBusyText: String? = null
    private lateinit var patchAdapter: GamePatchSettingsAdapter
    private var patchCatalog: List<CatalogPatch> = emptyList()
    private var patchCatalogJob: Job? = null
    private var installingPatchId: String? = null

    private val importTranslationDocument = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null && ::game.isInitialized) importTranslation(uri)
    }

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
        bindGame()
        bindActions()
        bindRuntimeSettings()
        bindPatchSettings()
        bindLanguageSettings()
        refreshFavorite()

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = NavigationAnimations.finish(this@GameDetailsActivity)
        })
    }

    override fun onResume() {
        super.onResume()
        if (::favoriteButton.isInitialized) refreshFavorite()
        if (::translationAdapter.isInitialized) refreshTranslations()
        if (::patchAdapter.isInitialized) refreshPatchSettings()
        if (::game.isInitialized) refreshRuntimeSelection()
    }

    private fun bindGame() {
        findViewById<TextView>(R.id.tvDetailsTitle).text = game.title
        findViewById<TextView>(R.id.tvDetailsDescription).text =
            game.description?.takeIf(String::isNotBlank)
                ?: game.subtitle?.takeIf(String::isNotBlank)
                ?: getString(R.string.game_details_no_description)
        bindOptionalText(findViewById(R.id.tvDetailsVersion), game.version)
        bindOptionalText(
            findViewById(R.id.tvDetailsEngine),
            game.engineVer?.let { getString(R.string.game_engine_version, it) }
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
    }

    private fun bindRuntimeSettings() {
        val button = findViewById<MaterialButton>(R.id.btnDetailsRuntime)
        button.visibility = if (game.isKristalMod) View.VISIBLE else View.GONE
        if (!game.isKristalMod) return
        button.setOnClickListener { showRuntimeSelector() }
        refreshRuntimeSelection()
    }

    private fun refreshRuntimeSelection() {
        if (!game.isKristalMod) return
        val runtime = KristalRuntimeStorage.selectedRuntimeForGame(this, game.stableId)
        findViewById<MaterialButton>(R.id.btnDetailsRuntime).text = runtime?.let {
            getString(R.string.game_runtime_selected, it.version)
        } ?: getString(R.string.game_runtime_not_installed)
    }

    private fun showRuntimeSelector() {
        val installed = KristalRuntimeStorage.installedRuntimes(this)
        if (installed.isEmpty()) {
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.game_runtime_choose)
                .setMessage(R.string.game_runtime_none_available)
                .setPositiveButton(R.string.kristal_runtime_download) { _, _ ->
                    startActivity(Intent(this, KristalRuntimeSettingsActivity::class.java))
                }
                .setNegativeButton(R.string.cancel, null)
                .showThemed()
            return
        }
        val global = KristalRuntimeStorage.selectedRuntime(this)
        val selectedOverrideTag = KristalRuntimeStorage.selectedRuntimeTagForGame(this, game.stableId)
        val labels = buildList {
            add(getString(R.string.game_runtime_use_default, global?.version ?: "—"))
            addAll(installed.map { getString(R.string.kristal_runtime_version, it.version) })
        }
        val checked = installed.indexOfFirst { it.tag == selectedOverrideTag }.let { index ->
            if (index < 0) 0 else index + 1
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.game_runtime_choose)
            .setSingleChoiceItems(labels.toTypedArray(), checked) { dialog, which ->
                val tag = installed.getOrNull(which - 1)?.tag
                KristalRuntimeStorage.selectForGame(this, game.stableId, tag)
                refreshRuntimeSelection()
                dialog.dismiss()
            }
            .setNeutralButton(R.string.game_runtime_manage) { _, _ ->
                startActivity(Intent(this, KristalRuntimeSettingsActivity::class.java))
            }
            .setNegativeButton(R.string.cancel, null)
            .showThemed()
    }

    private fun bindPatchSettings() {
        refreshPatchSettings()
        loadPatchCatalog()
    }

    private fun refreshPatchSettings() {
        val patches = PatchRepository.gameDisplayItems(this, game.projectId, patchCatalog)
        findViewById<TextView>(R.id.tvDetailsPatchesEmpty).visibility =
            if (patches.isEmpty()) View.VISIBLE else View.GONE
        findViewById<RecyclerView>(R.id.rvDetailsPatches).apply {
            visibility = if (patches.isEmpty()) View.GONE else View.VISIBLE
            layoutManager = LinearLayoutManager(this@GameDetailsActivity)
            patchAdapter = GamePatchSettingsAdapter(
                context = this@GameDetailsActivity,
                gameId = game.stableId,
                items = patches,
                saveImmediately = true,
                onCatalogAction = ::confirmCatalogPatchInstall
            )
            adapter = patchAdapter
            itemAnimator = null
            isNestedScrollingEnabled = false
        }
    }

    private fun loadPatchCatalog() {
        if (patchCatalogJob?.isActive == true) return
        patchCatalogJob = lifecycleScope.launch {
            when (val result = withContext(Dispatchers.IO) {
                PatchCatalogService.fetch(this@GameDetailsActivity)
            }) {
                is PatchCatalogResult.Success -> {
                    patchCatalog = result.patches
                    refreshPatchSettings()
                }
                is PatchCatalogResult.Failure -> Unit
            }
            patchCatalogJob = null
        }
    }

    private fun confirmCatalogPatchInstall(item: PatchDisplayItem) {
        val catalogPatch = item.catalogPatch ?: return
        MaterialAlertDialogBuilder(this)
            .setTitle(
                if (item.updateAvailable) R.string.patch_update_confirm_title
                else R.string.patch_download_confirm_title
            )
            .setMessage(
                getString(
                    if (item.updateAvailable) R.string.patch_update_confirm_message
                    else R.string.game_patch_download_confirm_message,
                    item.name,
                    item.version
                )
            )
            .setPositiveButton(
                if (item.updateAvailable) R.string.patch_update else R.string.patch_download
            ) { _, _ -> installCatalogPatchForGame(catalogPatch) }
            .setNegativeButton(R.string.cancel, null)
            .showThemed()
    }

    private fun installCatalogPatchForGame(catalogPatch: CatalogPatch) {
        if (installingPatchId != null) return
        installingPatchId = catalogPatch.manifest.id
        if (::patchAdapter.isInitialized) patchAdapter.setInstallingPatch(installingPatchId)
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                PatchPackageInstaller.installFromCatalog(
                    this@GameDetailsActivity,
                    catalogPatch.packageUrl,
                    catalogPatch.sha256,
                    catalogPatch.manifest.id,
                    catalogPatch.manifest.version
                )
            }
            installingPatchId = null
            when (result) {
                is PatchInstallResult.Success -> {
                    PatchManager.setGamePatchMode(
                        this@GameDetailsActivity,
                        game.stableId,
                        result.patch.manifest.id,
                        PatchManager.MODE_FORCE_ENABLED
                    )
                    Toast.makeText(
                        this@GameDetailsActivity,
                        getString(R.string.game_patch_install_success, result.patch.manifest.name.resolve(this@GameDetailsActivity)),
                        Toast.LENGTH_LONG
                    ).show()
                }
                is PatchInstallResult.Failure -> MaterialAlertDialogBuilder(this@GameDetailsActivity)
                    .setTitle(R.string.patch_install_failed)
                    .setMessage(result.reason)
                    .setPositiveButton(R.string.ok, null)
                    .showThemed()
            }
            refreshPatchSettings()
        }
    }

    private fun bindLanguageSettings() {
        val patchContent = findViewById<View>(R.id.detailsPatchesContent)
        val languageContent = findViewById<View>(R.id.detailsLanguagesContent)
        findViewById<MaterialButtonToggleGroup>(R.id.gameDetailsTabs)
            .addOnButtonCheckedListener { _, checkedId, isChecked ->
                if (!isChecked) return@addOnButtonCheckedListener
                val showLanguages = checkedId == R.id.tabDetailsLanguages
                patchContent.visibility = if (showLanguages) View.GONE else View.VISIBLE
                languageContent.visibility = if (showLanguages) View.VISIBLE else View.GONE
            }

        translationAdapter = CommunityTranslationAdapter(
            onSelect = { item ->
                item.localProject?.let { project ->
                    TranslationManager.selectProject(this, game.stableId, project.id)
                } ?: item.communityTranslationId?.let { id ->
                    TranslationManager.selectCommunityTranslation(this, game.stableId, id)
                }
                refreshTranslations()
            },
            onAction = { item ->
                item.localProject?.let { openTranslationEditor(it.id) }
                    ?: item.catalogTranslation?.let(::installCommunityTranslation)
            },
            onVersionWarning = { item ->
                MaterialAlertDialogBuilder(this)
                    .setTitle(R.string.translation_version_warning_title)
                    .setMessage(item.versionWarning)
                    .setPositiveButton(android.R.string.ok, null)
                    .create()
                    .also { it.showThemed() }
            }
        )
        findViewById<RecyclerView>(R.id.rvDetailsLanguages).apply {
            layoutManager = LinearLayoutManager(this@GameDetailsActivity)
            adapter = translationAdapter
            itemAnimator = null
        }
        findViewById<MaterialCardView>(R.id.cardOriginalLanguage).setOnClickListener {
            TranslationManager.clearSelection(this, game.stableId)
            refreshTranslations()
        }
        findViewById<MaterialButton>(R.id.btnCreateTranslation).setOnClickListener {
            createTranslation()
        }
        findViewById<MaterialButton>(R.id.btnImportTranslation).setOnClickListener {
            importTranslationDocument.launch(arrayOf("application/zip", "application/octet-stream"))
        }
        catalogTranslations = CommunityTranslationCatalogService.cachedTranslations(this)
        refreshTranslations()
        fetchCommunityTranslations()
    }

    private fun refreshTranslations() {
        val selectedProjectId = TranslationManager.selectedProjectId(this, game.stableId)
        val selectedCommunityId = TranslationManager.selectedCommunityTranslationId(this, game.stableId)
        val projects = TranslationManager.projectsForGame(this, game.stableId)
        val installed = CommunityTranslationStorage.installedForGame(this, game.projectId)
        val matchingCatalog = catalogTranslations
            .filter { it.manifest.gameProjectId.equals(game.projectId, ignoreCase = true) }
            .associateBy { it.manifest.id }
        val installedIds = installed.mapTo(mutableSetOf()) { it.manifest.id }
        val items = buildList {
            installed.sortedBy { it.manifest.name.resolve(this@GameDetailsActivity) }.forEach { translation ->
                val catalog = matchingCatalog[translation.manifest.id]
                val updateAvailable = catalog != null &&
                    VersionUtils.isNewer(catalog.manifest.version, translation.manifest.version)
                add(
                    TranslationDisplayItem(
                        key = "community:${translation.manifest.id}",
                        name = translation.manifest.name.resolve(this@GameDetailsActivity),
                        summary = getString(
                            R.string.translation_community_summary,
                            languageDisplayName(translation.manifest.targetLanguage),
                            translation.manifest.version,
                            translation.manifest.author
                        ),
                        selected = selectedCommunityId == translation.manifest.id,
                        selectable = true,
                        action = if (updateAvailable) TranslationItemAction.UPDATE else TranslationItemAction.NONE,
                        versionWarning = translationVersionWarning(translation.manifest.gameVersion),
                        catalogTranslation = catalog,
                        communityTranslationId = translation.manifest.id
                    )
                )
            }
            projects.forEach { project ->
                add(
                    TranslationDisplayItem(
                        key = "local:${project.id}",
                        name = project.name,
                        summary = getString(
                            R.string.translation_progress,
                            project.translatedEntries,
                            project.totalEntries
                        ),
                        selected = selectedProjectId == project.id,
                        selectable = true,
                        action = TranslationItemAction.EDIT,
                        versionWarning = translationVersionWarning(project.gameVersion),
                        localProject = project
                    )
                )
            }
            matchingCatalog.values
                .filterNot { it.manifest.id in installedIds }
                .sortedBy { it.manifest.name.resolve(this@GameDetailsActivity) }
                .forEach { catalog ->
                    add(
                        TranslationDisplayItem(
                            key = "community:${catalog.manifest.id}",
                            name = catalog.manifest.name.resolve(this@GameDetailsActivity),
                            summary = catalog.manifest.description.resolve(this@GameDetailsActivity),
                            selected = false,
                            selectable = false,
                            action = TranslationItemAction.DOWNLOAD,
                            versionWarning = translationVersionWarning(catalog.manifest.gameVersion),
                            catalogTranslation = catalog,
                            communityTranslationId = catalog.manifest.id
                        )
                    )
                }
        }
        findViewById<MaterialCardView>(R.id.cardOriginalLanguage).isChecked =
            selectedProjectId == null && selectedCommunityId == null
        translationAdapter.update(items, translationBusyKey, translationBusyText)
        findViewById<TextView>(R.id.tvDetailsLanguagesStatus).apply {
            visibility = if (!translationCatalogLoading && items.isEmpty()) View.VISIBLE else View.GONE
            text = getString(R.string.translation_none_available)
        }
    }

    private fun fetchCommunityTranslations() {
        translationCatalogLoading = true
        findViewById<ProgressBar>(R.id.progressTranslationScan).visibility = View.VISIBLE
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                CommunityTranslationCatalogService.fetch(this@GameDetailsActivity)
            }
            translationCatalogLoading = false
            findViewById<ProgressBar>(R.id.progressTranslationScan).visibility = View.GONE
            catalogTranslations = when (result) {
                is CommunityTranslationCatalogResult.Success -> result.translations
                is CommunityTranslationCatalogResult.Failure ->
                    CommunityTranslationCatalogService.cachedTranslations(this@GameDetailsActivity)
                        .ifEmpty { catalogTranslations }
            }
            refreshTranslations()
        }
    }

    private fun installCommunityTranslation(catalog: CatalogTranslation) {
        val key = "community:${catalog.manifest.id}"
        translationBusyKey = key
        translationBusyText = getString(R.string.translation_downloading)
        refreshTranslations()
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                CommunityTranslationInstaller.install(
                    this@GameDetailsActivity,
                    catalog,
                    onStageChanged = { stage ->
                        runOnUiThread {
                            translationBusyText = getString(
                                when (stage) {
                                    CommunityTranslationInstallStage.DOWNLOADING -> R.string.translation_downloading
                                    CommunityTranslationInstallStage.VALIDATING -> R.string.translation_validating
                                    CommunityTranslationInstallStage.INSTALLING -> R.string.translation_installing
                                }
                            )
                            refreshTranslations()
                        }
                    },
                    onProgress = { downloaded, total ->
                        runOnUiThread {
                            translationBusyText = if (total > 0L) {
                                getString(
                                    R.string.translation_download_progress,
                                    formatMegabytes(downloaded),
                                    formatMegabytes(total)
                                )
                            } else {
                                getString(R.string.translation_downloaded_amount, formatMegabytes(downloaded))
                            }
                            refreshTranslations()
                        }
                    }
                )
            }
            translationBusyKey = null
            translationBusyText = null
            when (result) {
                is CommunityTranslationInstallResult.Success -> {
                    TranslationManager.selectCommunityTranslation(
                        this@GameDetailsActivity,
                        game.stableId,
                        result.translation.manifest.id
                    )
                    refreshTranslations()
                }
                is CommunityTranslationInstallResult.Failure -> {
                    refreshTranslations()
                    MaterialAlertDialogBuilder(this@GameDetailsActivity)
                        .setTitle(R.string.translation_install_failed_title)
                        .setMessage(R.string.translation_install_failed)
                        .setPositiveButton(android.R.string.ok, null)
                        .create()
                        .also { it.showThemed() }
                }
            }
        }
    }

    private fun languageDisplayName(tag: String): String {
        val locale = java.util.Locale.forLanguageTag(tag)
        return locale.getDisplayName(locale).replaceFirstChar { it.titlecase(locale) }.ifBlank { tag }
    }

    private fun translationVersionWarning(translationVersion: String?): String? {
        val currentVersion = game.version?.trim().orEmpty()
        if (currentVersion.isBlank()) return null
        val expectedVersion = translationVersion?.trim().orEmpty()
        val versionsMatch = expectedVersion.isNotBlank() &&
            expectedVersion.trimStart('v', 'V')
                .equals(currentVersion.trimStart('v', 'V'), ignoreCase = true)
        if (versionsMatch) return null
        return getString(
            R.string.translation_version_warning_message,
            expectedVersion.ifBlank { getString(R.string.translation_version_unknown) },
            currentVersion
        )
    }

    private fun formatMegabytes(bytes: Long): String = String.format(
        java.util.Locale.getDefault(),
        "%.1f MB",
        bytes.coerceAtLeast(0L) / (1024.0 * 1024.0)
    )

    private fun createTranslation() {
        val progress = findViewById<ProgressBar>(R.id.progressTranslationScan)
        val createButton = findViewById<MaterialButton>(R.id.btnCreateTranslation)
        val importButton = findViewById<MaterialButton>(R.id.btnImportTranslation)
        progress.visibility = View.VISIBLE
        createButton.isEnabled = false
        importButton.isEnabled = false
        lifecycleScope.launch {
            val result = runCatching {
                withContext(Dispatchers.IO) {
                    TranslationManager.createProject(this@GameDetailsActivity, game)
                }
            }
            progress.visibility = View.GONE
            createButton.isEnabled = true
            importButton.isEnabled = true
            result.onSuccess { project ->
                refreshTranslations()
                openTranslationEditor(project.id)
            }.onFailure {
                MaterialAlertDialogBuilder(this@GameDetailsActivity)
                    .setTitle(R.string.translation_creation_failed_title)
                    .setMessage(R.string.translation_creation_failed)
                    .setPositiveButton(android.R.string.ok, null)
                    .create()
                    .also { it.showThemed() }
            }
        }
    }

    private fun importTranslation(uri: Uri) {
        val progress = findViewById<ProgressBar>(R.id.progressTranslationScan)
        val createButton = findViewById<MaterialButton>(R.id.btnCreateTranslation)
        val importButton = findViewById<MaterialButton>(R.id.btnImportTranslation)
        progress.visibility = View.VISIBLE
        createButton.isEnabled = false
        importButton.isEnabled = false
        lifecycleScope.launch {
            val result = runCatching {
                withContext(Dispatchers.IO) {
                    TranslationManager.importProject(this@GameDetailsActivity, game, uri)
                }
            }
            progress.visibility = View.GONE
            createButton.isEnabled = true
            importButton.isEnabled = true
            result.onSuccess { project ->
                refreshTranslations()
                openTranslationEditor(project.id)
            }.onFailure {
                MaterialAlertDialogBuilder(this@GameDetailsActivity)
                    .setTitle(R.string.translation_import_failed_title)
                    .setMessage(R.string.translation_import_failed)
                    .setPositiveButton(android.R.string.ok, null)
                    .create()
                    .also { dialog -> dialog.showThemed() }
            }
        }
    }

    private fun openTranslationEditor(projectId: String) {
        NavigationAnimations.start(
            this,
            Intent(this, TranslationEditorActivity::class.java)
                .putExtra(TranslationEditorActivity.EXTRA_PROJECT_ID, projectId)
        )
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
            party = intent.getStringArrayListExtra(EXTRA_PARTY).orEmpty(),
            packageType = runCatching {
                GamePackageType.valueOf(intent.getStringExtra(EXTRA_PACKAGE_TYPE).orEmpty())
            }.getOrDefault(GamePackageType.EXECUTABLE),
            modArchiveRoot = intent.getStringExtra(EXTRA_MOD_ARCHIVE_ROOT),
            translationRoot = intent.getStringExtra(EXTRA_TRANSLATION_ROOT)
        )
    }

    private fun bindOptionalText(view: TextView, value: String?) {
        view.text = value
        view.visibility = if (value.isNullOrBlank()) View.GONE else View.VISIBLE
    }

    companion object {
        private const val DETAILS_ICON_WIDTH_RATIO = 0.25f

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
                putExtra(EXTRA_PACKAGE_TYPE, game.packageType.name)
                putExtra(EXTRA_MOD_ARCHIVE_ROOT, game.modArchiveRoot)
                putExtra(EXTRA_TRANSLATION_ROOT, game.translationRoot)
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
        private const val EXTRA_PACKAGE_TYPE = "game_package_type"
        private const val EXTRA_MOD_ARCHIVE_ROOT = "game_mod_archive_root"
        private const val EXTRA_TRANSLATION_ROOT = "game_translation_root"
    }
}
