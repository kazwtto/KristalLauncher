package kwz.love2d.launcher

import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.adapter.PatchAdapter
import kwz.love2d.launcher.model.PatchDisplayItem
import kwz.love2d.launcher.model.PatchInstallResult
import kwz.love2d.launcher.model.PatchOrigin
import kwz.love2d.launcher.util.PatchCatalogResult
import kwz.love2d.launcher.util.PatchCatalogService
import kwz.love2d.launcher.util.PatchInstallStage
import kwz.love2d.launcher.util.PatchManager
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.PatchPackageInstaller
import kwz.love2d.launcher.util.PatchRegistry
import kwz.love2d.launcher.util.PatchRepository
import kwz.love2d.launcher.util.PatchStorage
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.showThemed
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class PatchesSettingsActivity : AppCompatActivity() {

    private lateinit var adapter: PatchAdapter
    private lateinit var recyclerView: RecyclerView
    private lateinit var progress: ProgressBar
    private lateinit var emptyState: LinearLayout
    private lateinit var emptyTitle: TextView
    private lateinit var emptyMessage: TextView
    private lateinit var tabs: MaterialButtonToggleGroup
    private lateinit var importButton: MaterialButton

    private var currentTab = Tab.INSTALLED
    private var catalogItems: List<PatchDisplayItem> = emptyList()
    private var catalogLoaded = false
    private var catalogLoadJob: Job? = null
    private var installingPatchId: String? = null
    private val promptedPatchUpdates = mutableSetOf<String>()

    private val importPatchLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) confirmAndImport(uri)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeManager.applyActivityTheme(this)
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_patches_settings)

        recyclerView = findViewById(R.id.rvPatches)
        progress = findViewById(R.id.patchProgress)
        emptyState = findViewById(R.id.patchEmptyState)
        emptyTitle = findViewById(R.id.tvPatchEmptyTitle)
        emptyMessage = findViewById(R.id.tvPatchEmptyMessage)
        tabs = findViewById(R.id.patchTabs)
        importButton = findViewById(R.id.btnImportPatch)

        adapter = PatchAdapter(
            onToggle = ::handleToggle,
            onAction = ::handleCatalogAction,
            onUseCases = ::showPatchUseCases,
            onDetails = ::showPatchDetails
        )
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter
        recyclerView.itemAnimator = null

        findViewById<ImageView>(R.id.btnBack).setOnClickListener { finishWithAnimation() }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = finishWithAnimation()
        })
        findViewById<ImageView>(R.id.btnRefreshCatalog).setOnClickListener {
            if (currentTab == Tab.DISCOVER) {
                loadCatalog(force = true)
            } else {
                catalogLoaded = false
                tabs.check(R.id.btnDiscoverTab)
            }
        }
        importButton.setOnClickListener {
            importPatchLauncher.launch(
                arrayOf(
                    "application/zip",
                    "application/x-zip-compressed",
                    "application/octet-stream",
                    "*/*"
                )
            )
        }

        tabs.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            currentTab = if (checkedId == R.id.btnDiscoverTab) Tab.DISCOVER else Tab.INSTALLED
            importButton.visibility = if (currentTab == Tab.INSTALLED) View.VISIBLE else View.GONE
            if (currentTab == Tab.INSTALLED) {
                showInstalledPatches()
            } else if (catalogLoaded) {
                showItems(Tab.DISCOVER, catalogItems)
            } else {
                loadCatalog(force = false)
            }
        }

        tabs.check(R.id.btnInstalledTab)
        loadCatalog(force = false, background = true)
    }

    override fun onResume() {
        super.onResume()
        if (currentTab == Tab.INSTALLED) showInstalledPatches()
    }

    private fun showInstalledPatches() {
        showItems(Tab.INSTALLED, PatchRepository.installedDisplayItems(this))
    }

    private fun loadCatalog(force: Boolean, background: Boolean = false) {
        if (!force && catalogLoaded) {
            showItems(Tab.DISCOVER, catalogItems)
            showAvailablePatchUpdate()
            return
        }
        if (force) {
            catalogLoadJob?.cancel()
            catalogLoadJob = null
        } else if (catalogLoadJob?.isActive == true) {
            if (!background && currentTab == Tab.DISCOVER) setLoading(true)
            return
        }
        if (!background && currentTab == Tab.DISCOVER) setLoading(true)
        catalogLoadJob = lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                PatchCatalogService.fetch(this@PatchesSettingsActivity)
            }
            when (result) {
                is PatchCatalogResult.Success -> {
                    catalogItems = PatchRepository.catalogDisplayItems(this@PatchesSettingsActivity, result.patches)
                    catalogLoaded = true
                    showItems(Tab.DISCOVER, catalogItems)
                    showAvailablePatchUpdate()
                    if (result.fromCache) {
                        Toast.makeText(this@PatchesSettingsActivity, R.string.patch_catalog_cached, Toast.LENGTH_LONG).show()
                    }
                }
                is PatchCatalogResult.Failure -> {
                    showEmpty(
                        Tab.DISCOVER,
                        getString(R.string.patch_catalog_unavailable),
                        getString(R.string.patch_catalog_error, result.reason)
                    )
                }
            }
            catalogLoadJob = null
        }
    }

    private fun showAvailablePatchUpdate() {
        if (installingPatchId != null || isFinishing || isDestroyed) return
        val update = catalogItems.firstOrNull { item ->
            item.updateAvailable && promptedPatchUpdates.add("${item.id}:${item.version}")
        } ?: return
        val installedVersion = update.installedPatch?.manifest?.version ?: return
        val releaseNotes = update.catalogPatch?.releaseNotes
            ?.resolve(this)
            ?.takeIf(String::isNotBlank)
            ?: getString(R.string.patch_update_notes_unavailable)

        MaterialAlertDialogBuilder(this)
            .setTitle(getString(R.string.patch_update_available_title, update.name))
            .setMessage(
                getString(
                    R.string.patch_update_available_message,
                    installedVersion,
                    update.version,
                    releaseNotes
                )
            )
            .setPositiveButton(R.string.patch_update) { _, _ -> installCatalogPatch(update) }
            .setNegativeButton(R.string.update_later, null)
            .showThemed()
    }

    private fun handleToggle(item: PatchDisplayItem, enabled: Boolean) {
        if (enabled) {
            val activationProblems = PatchRepository.activationProblems(this, item.id)
            if (activationProblems.hasProblems) {
                val details = buildList {
                    if (activationProblems.missingDependencies.isNotEmpty()) {
                        add(getString(R.string.patch_missing_dependencies, activationProblems.missingDependencies.joinToString()))
                    }
                    if (activationProblems.enabledConflicts.isNotEmpty()) {
                        add(getString(R.string.patch_enabled_conflicts, activationProblems.enabledConflicts.joinToString()))
                    }
                }.joinToString("\n")
                MaterialAlertDialogBuilder(this)
                    .setTitle(R.string.patch_cannot_enable)
                    .setMessage(details)
                    .setPositiveButton(R.string.ok, null)
                    .setOnDismissListener { refreshCurrentTab() }
                    .showThemed()
                return
            }
        }

        val builtIn = PatchRegistry.findBuiltIn(item.id)
        val warningResource = when {
            enabled -> builtIn?.warningOnEnableRes
            else -> builtIn?.warningOnDisableRes
        }
        val requiresTrustConfirmation = enabled && item.origin == PatchOrigin.IMPORTED

        if (warningResource != null || requiresTrustConfirmation) {
            val message = warningResource?.let(::getString)
                ?: getString(R.string.patch_unverified_enable_warning, item.name)
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.warning_attention)
                .setMessage(message)
                .setPositiveButton(if (enabled) R.string.enable else R.string.disable) { _, _ ->
                    PatchManager.setGlobalPatchEnabled(this, item.id, enabled)
                    refreshCurrentTab()
                }
                .setNegativeButton(R.string.cancel) { _, _ -> refreshCurrentTab() }
                .setOnCancelListener { refreshCurrentTab() }
                .showThemed()
        } else {
            PatchManager.setGlobalPatchEnabled(this, item.id, enabled)
            refreshCurrentTab()
        }
    }

    private fun handleCatalogAction(item: PatchDisplayItem) {
        if (item.catalogPatch == null) return
        val title = if (item.updateAvailable) R.string.patch_update_confirm_title else R.string.patch_download_confirm_title
        val message = if (item.updateAvailable) {
            getString(R.string.patch_update_confirm_message, item.name, item.version)
        } else {
            getString(R.string.patch_download_confirm_message, item.name, item.version)
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(title)
            .setMessage(message)
            .setPositiveButton(if (item.updateAvailable) R.string.patch_update else R.string.patch_download) { _, _ ->
                installCatalogPatch(item)
            }
            .setNegativeButton(R.string.cancel, null)
            .showThemed()
    }

    private fun installCatalogPatch(item: PatchDisplayItem) {
        if (installingPatchId != null) return
        val catalogPatch = item.catalogPatch ?: return
        val patchId = item.id
        installingPatchId = patchId
        adapter.setInstallProgress(patchId, PatchInstallStage.DOWNLOADING)

        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                PatchPackageInstaller.installFromCatalog(
                    this@PatchesSettingsActivity,
                    catalogPatch.packageUrl,
                    catalogPatch.sha256,
                    catalogPatch.manifest.id,
                    catalogPatch.manifest.version
                ) { stage ->
                    runOnUiThread {
                        if (installingPatchId == patchId && !isDestroyed) {
                            adapter.setInstallProgress(patchId, stage)
                        }
                    }
                }
            }
            installingPatchId = null
            adapter.setInstallProgress(null)
            handleInstallResult(
                result,
                enableAfterInstall = item.installed && item.enabled,
                keepCatalogVisible = true
            )
        }
    }

    private fun confirmAndImport(uri: Uri) {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.patch_import_confirm_title)
            .setMessage(R.string.patch_import_confirm_message)
            .setPositiveButton(R.string.patch_import) { _, _ ->
                setLoading(true)
                lifecycleScope.launch {
                    val result = withContext(Dispatchers.IO) {
                        PatchPackageInstaller.installFromUri(this@PatchesSettingsActivity, uri)
                    }
                    setLoading(false)
                    handleInstallResult(result, enableAfterInstall = false)
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .showThemed()
    }

    private fun handleInstallResult(
        result: PatchInstallResult,
        enableAfterInstall: Boolean,
        keepCatalogVisible: Boolean = false
    ) {
        when (result) {
            is PatchInstallResult.Success -> {
                PatchManager.setGlobalPatchEnabled(this, result.patch.manifest.id, enableAfterInstall)
                Toast.makeText(
                    this,
                    getString(R.string.patch_install_success, result.patch.manifest.name.resolve(this)),
                    Toast.LENGTH_LONG
                ).show()
                if (keepCatalogVisible) {
                    catalogItems = catalogItems.map { current ->
                        if (current.id == result.patch.manifest.id) {
                            current.copy(
                                installed = true,
                                enabled = enableAfterInstall,
                                updateAvailable = false,
                                installedPatch = result.patch
                            )
                        } else {
                            current
                        }
                    }
                    catalogLoaded = true
                    if (currentTab == Tab.DISCOVER) {
                        showItems(Tab.DISCOVER, catalogItems)
                    } else {
                        showInstalledPatches()
                    }
                } else {
                    catalogLoaded = false
                    tabs.check(R.id.btnInstalledTab)
                    showInstalledPatches()
                }
            }
            is PatchInstallResult.Failure -> {
                MaterialAlertDialogBuilder(this)
                    .setTitle(R.string.patch_install_failed)
                    .setMessage(result.reason)
                    .setPositiveButton(R.string.ok, null)
                    .showThemed()
                refreshCurrentTab()
            }
        }
    }

    private fun showPatchDetails(item: PatchDisplayItem) {
        val capabilities = item.capabilities.takeIf { it.isNotEmpty() }?.joinToString() ?: getString(R.string.patch_none)
        val dependencies = item.dependencies.takeIf { it.isNotEmpty() }?.joinToString() ?: getString(R.string.patch_none)
        val conflicts = item.conflicts.takeIf { it.isNotEmpty() }?.joinToString() ?: getString(R.string.patch_none)
        val details = getString(
            R.string.patch_details_body,
            item.description,
            item.author,
            item.version,
            item.id,
            capabilities,
            dependencies,
            conflicts
        )

        val dialog = MaterialAlertDialogBuilder(this)
            .setTitle(item.name)
            .setMessage(details)
            .setPositiveButton(R.string.ok, null)

        if (item.installedPatch != null) {
            dialog.setNegativeButton(R.string.patch_uninstall) { _, _ -> confirmUninstall(item) }
        }
        dialog.showThemed()
    }

    private fun showPatchUseCases(item: PatchDisplayItem) {
        val useCases = item.useCases.ifEmpty { listOf(getString(R.string.patch_use_cases_empty)) }
        MaterialAlertDialogBuilder(this)
            .setTitle(getString(R.string.patch_use_cases_title, item.name))
            .setItems(useCases.toTypedArray(), null)
            .setPositiveButton(R.string.ok, null)
            .showThemed()
    }

    private fun confirmUninstall(item: PatchDisplayItem) {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.patch_uninstall_confirm_title)
            .setMessage(getString(R.string.patch_uninstall_confirm_message, item.name))
            .setPositiveButton(R.string.patch_uninstall) { _, _ ->
                PatchManager.setGlobalPatchEnabled(this, item.id, false)
                if (PatchStorage.uninstall(this, item.id)) {
                    Toast.makeText(this, R.string.patch_uninstalled, Toast.LENGTH_SHORT).show()
                    catalogItems = catalogItems.map { current ->
                        if (current.id == item.id) {
                            current.copy(
                                installed = false,
                                enabled = false,
                                updateAvailable = false,
                                installedPatch = null
                            )
                        } else {
                            current
                        }
                    }
                    if (currentTab == Tab.DISCOVER) {
                        showItems(Tab.DISCOVER, catalogItems)
                    } else {
                        showInstalledPatches()
                    }
                } else {
                    Toast.makeText(this, R.string.patch_uninstall_failed, Toast.LENGTH_LONG).show()
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .showThemed()
    }

    private fun refreshCurrentTab() {
        if (currentTab == Tab.INSTALLED) {
            showInstalledPatches()
        } else if (catalogLoaded) {
            catalogItems = catalogItems.map { current ->
                current.copy(enabled = PatchManager.isGlobalPatchEnabled(this, current.id))
            }
            showItems(Tab.DISCOVER, catalogItems)
        }
    }

    private fun showItems(tab: Tab, items: List<PatchDisplayItem>) {
        if (currentTab != tab) return
        progress.visibility = View.GONE
        if (items.isEmpty()) {
            val title = if (tab == Tab.DISCOVER) R.string.patch_catalog_empty else R.string.patch_installed_empty
            val message = if (tab == Tab.DISCOVER) R.string.patch_catalog_empty_message else R.string.patch_installed_empty_message
            showEmpty(tab, getString(title), getString(message))
        } else {
            emptyState.visibility = View.GONE
            adapter.submitItems(items)
            recyclerView.visibility = View.VISIBLE
        }
        tabs.isEnabled = true
        importButton.isEnabled = true
    }

    private fun showEmpty(tab: Tab, title: String, message: String) {
        if (currentTab != tab) return
        progress.visibility = View.GONE
        recyclerView.visibility = View.GONE
        emptyTitle.text = title
        emptyMessage.text = message
        emptyState.visibility = View.VISIBLE
        adapter.submitItems(emptyList())
        tabs.isEnabled = true
        importButton.isEnabled = true
    }

    private fun setLoading(loading: Boolean) {
        progress.visibility = if (loading) View.VISIBLE else View.GONE
        recyclerView.visibility = if (loading) View.INVISIBLE else recyclerView.visibility
        emptyState.visibility = if (loading) View.GONE else emptyState.visibility
        tabs.isEnabled = !loading
        importButton.isEnabled = !loading
        if (loading) adapter.submitItems(emptyList())
    }

    private enum class Tab {
        INSTALLED,
        DISCOVER
    }

    private fun finishWithAnimation() {
        NavigationAnimations.finish(this)
    }
}
