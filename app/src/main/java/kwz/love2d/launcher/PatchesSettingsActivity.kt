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
import kwz.love2d.launcher.util.PatchManager
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.PatchPackageInstaller
import kwz.love2d.launcher.util.PatchRegistry
import kwz.love2d.launcher.util.PatchRepository
import kwz.love2d.launcher.util.PatchStorage
import kotlinx.coroutines.Dispatchers
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

    private val importPatchLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) confirmAndImport(uri)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
            tabs.check(R.id.btnDiscoverTab)
            loadCatalog(force = true)
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
                showItems(catalogItems)
            } else {
                loadCatalog(force = false)
            }
        }

        tabs.check(R.id.btnInstalledTab)
    }

    override fun onResume() {
        super.onResume()
        if (currentTab == Tab.INSTALLED) showInstalledPatches()
    }

    private fun showInstalledPatches() {
        showItems(PatchRepository.installedDisplayItems(this))
    }

    private fun loadCatalog(force: Boolean) {
        if (!force && catalogLoaded) {
            showItems(catalogItems)
            return
        }
        setLoading(true)
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                PatchCatalogService.fetch(this@PatchesSettingsActivity)
            }
            setLoading(false)
            when (result) {
                is PatchCatalogResult.Success -> {
                    catalogItems = PatchRepository.catalogDisplayItems(this@PatchesSettingsActivity, result.patches)
                    catalogLoaded = true
                    showItems(catalogItems)
                    if (result.fromCache) {
                        Toast.makeText(this@PatchesSettingsActivity, R.string.patch_catalog_cached, Toast.LENGTH_LONG).show()
                    }
                }
                is PatchCatalogResult.Failure -> {
                    showEmpty(
                        getString(R.string.patch_catalog_unavailable),
                        getString(R.string.patch_catalog_error, result.reason)
                    )
                }
            }
        }
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
                    .show()
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
                .show()
        } else {
            PatchManager.setGlobalPatchEnabled(this, item.id, enabled)
            refreshCurrentTab()
        }
    }

    private fun handleCatalogAction(item: PatchDisplayItem) {
        val catalogPatch = item.catalogPatch ?: return
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
                setLoading(true)
                lifecycleScope.launch {
                    val result = withContext(Dispatchers.IO) {
                        PatchPackageInstaller.installFromCatalog(
                            this@PatchesSettingsActivity,
                            catalogPatch.packageUrl,
                            catalogPatch.sha256,
                            catalogPatch.manifest.id,
                            catalogPatch.manifest.version
                        )
                    }
                    setLoading(false)
                    handleInstallResult(result, enableAfterInstall = item.installed && item.enabled)
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
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
            .show()
    }

    private fun handleInstallResult(result: PatchInstallResult, enableAfterInstall: Boolean) {
        when (result) {
            is PatchInstallResult.Success -> {
                PatchManager.setGlobalPatchEnabled(this, result.patch.manifest.id, enableAfterInstall)
                Toast.makeText(
                    this,
                    getString(R.string.patch_install_success, result.patch.manifest.name.resolve(this)),
                    Toast.LENGTH_LONG
                ).show()
                catalogLoaded = false
                tabs.check(R.id.btnInstalledTab)
                showInstalledPatches()
            }
            is PatchInstallResult.Failure -> {
                MaterialAlertDialogBuilder(this)
                    .setTitle(R.string.patch_install_failed)
                    .setMessage(result.reason)
                    .setPositiveButton(R.string.ok, null)
                    .show()
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
        dialog.show()
    }

    private fun showPatchUseCases(item: PatchDisplayItem) {
        val useCases = item.useCases.ifEmpty { listOf(getString(R.string.patch_use_cases_empty)) }
        MaterialAlertDialogBuilder(this)
            .setTitle(getString(R.string.patch_use_cases_title, item.name))
            .setItems(useCases.toTypedArray(), null)
            .setPositiveButton(R.string.ok, null)
            .show()
    }

    private fun confirmUninstall(item: PatchDisplayItem) {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.patch_uninstall_confirm_title)
            .setMessage(getString(R.string.patch_uninstall_confirm_message, item.name))
            .setPositiveButton(R.string.patch_uninstall) { _, _ ->
                PatchManager.setGlobalPatchEnabled(this, item.id, false)
                if (PatchStorage.uninstall(this, item.id)) {
                    Toast.makeText(this, R.string.patch_uninstalled, Toast.LENGTH_SHORT).show()
                    catalogLoaded = false
                    showInstalledPatches()
                } else {
                    Toast.makeText(this, R.string.patch_uninstall_failed, Toast.LENGTH_LONG).show()
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun refreshCurrentTab() {
        if (currentTab == Tab.INSTALLED) {
            showInstalledPatches()
        } else if (catalogLoaded) {
            catalogItems = catalogItems.map { current ->
                current.copy(enabled = PatchManager.isGlobalPatchEnabled(this, current.id))
            }
            showItems(catalogItems)
        }
    }

    private fun showItems(items: List<PatchDisplayItem>) {
        setLoading(false)
        if (items.isEmpty()) {
            val title = if (currentTab == Tab.DISCOVER) R.string.patch_catalog_empty else R.string.patch_installed_empty
            val message = if (currentTab == Tab.DISCOVER) R.string.patch_catalog_empty_message else R.string.patch_installed_empty_message
            showEmpty(getString(title), getString(message))
        } else {
            emptyState.visibility = View.GONE
            recyclerView.visibility = View.VISIBLE
            adapter.submitItems(items)
        }
    }

    private fun showEmpty(title: String, message: String) {
        adapter.submitItems(emptyList())
        recyclerView.visibility = View.GONE
        emptyTitle.text = title
        emptyMessage.text = message
        emptyState.visibility = View.VISIBLE
    }

    private fun setLoading(loading: Boolean) {
        progress.visibility = if (loading) View.VISIBLE else View.GONE
        recyclerView.visibility = if (loading) View.INVISIBLE else recyclerView.visibility
        emptyState.visibility = if (loading) View.GONE else emptyState.visibility
        tabs.isEnabled = !loading
        importButton.isEnabled = !loading
    }

    private enum class Tab {
        INSTALLED,
        DISCOVER
    }

    private fun finishWithAnimation() {
        NavigationAnimations.finish(this)
    }
}
