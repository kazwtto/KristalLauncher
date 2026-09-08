package kwz.love2d.launcher

import android.os.Bundle
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kwz.love2d.launcher.adapter.KristalRuntimeAdapter
import kwz.love2d.launcher.model.KristalRuntimeCatalogResult
import kwz.love2d.launcher.model.KristalRuntimeDisplayItem
import kwz.love2d.launcher.model.KristalRuntimeInstallResult
import kwz.love2d.launcher.model.KristalRuntimeInstallStage
import kwz.love2d.launcher.model.KristalRuntimeRelease
import kwz.love2d.launcher.util.KristalRuntimeCatalogService
import kwz.love2d.launcher.util.KristalRuntimeInstaller
import kwz.love2d.launcher.util.KristalRuntimeRepository
import kwz.love2d.launcher.util.KristalRuntimeStorage
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.showThemed
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runInterruptible
import kotlinx.coroutines.withContext

class KristalRuntimeSettingsActivity : AppCompatActivity() {

    private lateinit var adapter: KristalRuntimeAdapter
    private lateinit var recyclerView: RecyclerView
    private lateinit var catalogProgress: ProgressBar
    private lateinit var emptyState: LinearLayout
    private lateinit var emptyMessage: TextView
    private var releases = emptyList<KristalRuntimeRelease>()
    private var catalogJob: Job? = null
    private var installJob: Job? = null
    private var installingTag: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeManager.applyActivityTheme(this)
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_kristal_runtime_settings)

        recyclerView = findViewById(R.id.rvKristalRuntimes)
        catalogProgress = findViewById(R.id.runtimeCatalogProgress)
        emptyState = findViewById(R.id.runtimeEmptyState)
        emptyMessage = findViewById(R.id.tvRuntimeEmptyMessage)
        adapter = KristalRuntimeAdapter(::handleAction, ::confirmRemove)
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter
        recyclerView.itemAnimator = null

        findViewById<ImageView>(R.id.btnBack).setOnClickListener { finishWithAnimation() }
        findViewById<ImageView>(R.id.btnRefreshRuntimes).setOnClickListener { loadCatalog() }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = finishWithAnimation()
        })

        showItems()
        loadCatalog()
    }

    override fun onResume() {
        super.onResume()
        showItems()
    }

    private fun loadCatalog() {
        if (catalogJob?.isActive == true) return
        catalogProgress.visibility = if (adapter.itemCount == 0) View.VISIBLE else View.GONE
        emptyState.visibility = View.GONE
        catalogJob = lifecycleScope.launch {
            when (val result = withContext(Dispatchers.IO) {
                KristalRuntimeCatalogService.fetch(this@KristalRuntimeSettingsActivity)
            }) {
                is KristalRuntimeCatalogResult.Success -> {
                    releases = result.releases
                    showItems()
                    if (result.fromCache) {
                        Toast.makeText(
                            this@KristalRuntimeSettingsActivity,
                            R.string.kristal_runtime_catalog_cached,
                            Toast.LENGTH_LONG
                        ).show()
                    }
                }
                is KristalRuntimeCatalogResult.Failure -> {
                    showItems()
                    if (adapter.itemCount == 0) {
                        emptyState.visibility = View.VISIBLE
                        emptyMessage.text = getString(R.string.kristal_runtime_catalog_error, result.reason)
                    } else {
                        Toast.makeText(
                            this@KristalRuntimeSettingsActivity,
                            getString(R.string.kristal_runtime_catalog_error, result.reason),
                            Toast.LENGTH_LONG
                        ).show()
                    }
                }
            }
            catalogProgress.visibility = View.GONE
            catalogJob = null
        }
    }

    private fun showItems() {
        val items = KristalRuntimeRepository.displayItems(this, releases)
        adapter.submitItems(items)
        if (items.isNotEmpty()) {
            emptyState.visibility = View.GONE
            recyclerView.visibility = View.VISIBLE
        }
    }

    private fun handleAction(item: KristalRuntimeDisplayItem) {
        if (installJob?.isActive == true) return
        if (item.installed != null) {
            if (KristalRuntimeStorage.select(this, item.tag)) {
                showItems()
                Toast.makeText(this, R.string.kristal_runtime_selection_saved, Toast.LENGTH_SHORT).show()
            }
            return
        }
        val release = item.release ?: return
        installJob = lifecycleScope.launch {
            installingTag = release.tag
            adapter.setOperation(release.tag, KristalRuntimeInstallStage.DOWNLOADING)
            val result = try {
                runInterruptible(Dispatchers.IO) {
                    KristalRuntimeInstaller.install(
                        context = this@KristalRuntimeSettingsActivity,
                        release = release,
                        onStageChanged = { stage ->
                            runOnUiThread {
                                if (installingTag == release.tag) {
                                    adapter.setOperation(release.tag, stage)
                                }
                            }
                        },
                        onDownloadProgress = { downloaded, total ->
                            runOnUiThread {
                                if (installingTag == release.tag) {
                                    adapter.setOperation(
                                        release.tag,
                                        KristalRuntimeInstallStage.DOWNLOADING,
                                        downloaded,
                                        total
                                    )
                                }
                            }
                        }
                    )
                }
            } finally {
                installingTag = null
                adapter.setOperation(null)
            }
            when (result) {
                is KristalRuntimeInstallResult.Success -> {
                    showItems()
                    Toast.makeText(
                        this@KristalRuntimeSettingsActivity,
                        getString(R.string.kristal_runtime_install_success, result.runtime.version),
                        Toast.LENGTH_LONG
                    ).show()
                }
                is KristalRuntimeInstallResult.Failure -> Toast.makeText(
                    this@KristalRuntimeSettingsActivity,
                    getString(R.string.kristal_runtime_install_failed, result.reason),
                    Toast.LENGTH_LONG
                ).show()
            }
            installJob = null
        }
    }

    private fun confirmRemove(item: KristalRuntimeDisplayItem) {
        val runtime = item.installed ?: return
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.kristal_runtime_remove_title)
            .setMessage(getString(R.string.kristal_runtime_remove_message, runtime.version))
            .setPositiveButton(R.string.kristal_runtime_remove) { _, _ ->
                if (KristalRuntimeStorage.remove(this, runtime.tag)) {
                    showItems()
                    Toast.makeText(this, R.string.kristal_runtime_removed, Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(this, R.string.kristal_runtime_remove_failed, Toast.LENGTH_LONG).show()
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .showThemed()
    }

    private fun finishWithAnimation() = NavigationAnimations.finish(this)
}
