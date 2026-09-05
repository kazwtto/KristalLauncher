package kwz.love2d.launcher

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.google.android.material.button.MaterialButton
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.materialswitch.MaterialSwitch
import kwz.love2d.launcher.util.GameCacheManager
import kwz.love2d.launcher.util.FolderPermissionManager
import kwz.love2d.launcher.util.LanguageManager
import kwz.love2d.launcher.util.NavigationAnimations
import kwz.love2d.launcher.util.ThemeManager
import kwz.love2d.launcher.util.showThemed
import kwz.love2d.launcher.util.UpdateChecker
import kwz.love2d.launcher.ui.UpdatePrompter
import kwz.love2d.launcher.ui.DeltaruneSquareSwitch
import java.text.DateFormat
import java.util.Date
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class SettingsActivity : AppCompatActivity() {

    private lateinit var btnBack: ImageView
    private lateinit var btnLanguage: LinearLayout
    private lateinit var tvCurrentLanguage: TextView
    private lateinit var btnAppearance: LinearLayout
    private lateinit var tvCurrentTheme: TextView
    private lateinit var tvCurrentFolderPath: TextView
    private lateinit var btnChangeFolder: MaterialButton
    private lateinit var btnClearFolder: MaterialButton
    private lateinit var btnClearCache: LinearLayout
    private lateinit var btnOpenPatchesMenu: LinearLayout
    private lateinit var switchAutomaticUpdates: MaterialSwitch
    private lateinit var switchAutomaticUpdatesDeltarune: DeltaruneSquareSwitch
    private lateinit var tvAutomaticUpdatesDeltarune: TextView
    private lateinit var rowAutomaticUpdates: LinearLayout
    private lateinit var btnCheckUpdates: MaterialButton
    private lateinit var tvLastUpdateCheck: TextView

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
            updateFolderUI()
            Toast.makeText(this, R.string.change_folder, Toast.LENGTH_SHORT).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeManager.applyActivityTheme(this)
        super.onCreate(savedInstanceState)
        NavigationAnimations.prepare(this)
        setContentView(R.layout.activity_settings)

        btnBack = findViewById(R.id.btnBack)
        btnLanguage = findViewById(R.id.btnLanguage)
        tvCurrentLanguage = findViewById(R.id.tvCurrentLanguage)
        btnAppearance = findViewById(R.id.btnAppearance)
        tvCurrentTheme = findViewById(R.id.tvCurrentTheme)
        tvCurrentFolderPath = findViewById(R.id.tvCurrentFolderPath)
        btnChangeFolder = findViewById(R.id.btnChangeFolder)
        btnClearFolder = findViewById(R.id.btnClearFolder)
        btnClearCache = findViewById(R.id.btnClearCache)

        btnOpenPatchesMenu = findViewById(R.id.btnOpenPatchesMenu)
        switchAutomaticUpdates = findViewById(R.id.switchAutomaticUpdates)
        switchAutomaticUpdatesDeltarune = findViewById(R.id.switchAutomaticUpdatesDeltarune)
        tvAutomaticUpdatesDeltarune = findViewById(R.id.tvAutomaticUpdatesDeltarune)
        rowAutomaticUpdates = findViewById(R.id.rowAutomaticUpdates)
        btnCheckUpdates = findViewById(R.id.btnCheckUpdates)
        tvLastUpdateCheck = findViewById(R.id.tvLastUpdateCheck)
        findViewById<TextView>(R.id.tvAboutTitle).text = getString(R.string.about_title, BuildConfig.VERSION_NAME)

        btnBack.setOnClickListener { finishWithAnimation() }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = finishWithAnimation()
        })

        updateLanguageUI()
        updateFolderUI()
        updateLastUpdateCheckLabel()

        val automaticUpdatesEnabled = UpdateChecker.isAutomaticCheckEnabled(this)
        val deltarune = ThemeManager.isDeltaruneTheme(this)
        switchAutomaticUpdates.visibility = if (deltarune) android.view.View.GONE else android.view.View.VISIBLE
        tvAutomaticUpdatesDeltarune.visibility = if (deltarune) android.view.View.VISIBLE else android.view.View.GONE
        switchAutomaticUpdatesDeltarune.visibility = if (deltarune) android.view.View.VISIBLE else android.view.View.GONE

        switchAutomaticUpdates.isChecked = automaticUpdatesEnabled
        switchAutomaticUpdates.setOnCheckedChangeListener { _, enabled ->
            UpdateChecker.setAutomaticCheckEnabled(this, enabled)
        }
        switchAutomaticUpdatesDeltarune.setChecked(automaticUpdatesEnabled)
        switchAutomaticUpdatesDeltarune.setOnCheckedChangeListener { _, enabled ->
            UpdateChecker.setAutomaticCheckEnabled(this, enabled)
        }
        rowAutomaticUpdates.setOnClickListener {
            if (deltarune) switchAutomaticUpdatesDeltarune.toggle()
        }

        btnCheckUpdates.setOnClickListener { checkForUpdatesManually() }
        findViewById<MaterialButton>(R.id.btnOpenRepository).setOnClickListener {
            UpdatePrompter.openUrl(this, BuildConfig.GITHUB_REPOSITORY_URL)
        }

        btnOpenPatchesMenu.setOnClickListener {
            NavigationAnimations.start(this, Intent(this, PatchesSettingsActivity::class.java))
        }

        btnLanguage.setOnClickListener {
            NavigationAnimations.start(this, Intent(this, LanguageSettingsActivity::class.java))
        }

        btnAppearance.setOnClickListener {
            NavigationAnimations.start(this, Intent(this, AppearanceSettingsActivity::class.java))
        }

        btnChangeFolder.setOnClickListener {
            folderPickerLauncher.launch(null)
        }

        btnClearFolder.setOnClickListener {
            showClearFolderConfirmation()
        }

        btnClearCache.setOnClickListener {
            showClearCacheConfirmation()
        }
    }

    override fun onResume() {
        super.onResume()
        updateLanguageUI()
        tvCurrentTheme.text = ThemeManager.getThemeDisplayName(this)
    }

    private fun checkForUpdatesManually() {
        btnCheckUpdates.isEnabled = false
        btnCheckUpdates.setText(R.string.update_checking)
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                UpdateChecker.check(this@SettingsActivity)
            }
            btnCheckUpdates.isEnabled = true
            btnCheckUpdates.setText(R.string.update_check_now)
            updateLastUpdateCheckLabel()
            UpdatePrompter.show(this@SettingsActivity, result, showCurrentStatus = true)
        }
    }

    private fun updateLastUpdateCheckLabel() {
        val lastCheck = UpdateChecker.getLastCheckTime(this)
        tvLastUpdateCheck.text = if (lastCheck <= 0L) {
            getString(R.string.update_never_checked)
        } else {
            val formatted = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
                .format(Date(lastCheck))
            getString(R.string.update_last_checked, formatted)
        }
    }



    private fun updateLanguageUI() {
        tvCurrentLanguage.text = LanguageManager.getLanguageDisplayName(this)
    }

    private fun updateFolderUI() {
        val uri = FolderPermissionManager.getSavedFolderUri(this)
        if (uri != null) {
            tvCurrentFolderPath.text = uri.path ?: uri.toString()
        } else {
            tvCurrentFolderPath.setText(R.string.select_folder_dialog_title)
        }
    }

    private fun showClearFolderConfirmation() {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.clear_folder)
            .setMessage(R.string.select_folder_dialog_desc)
            .setPositiveButton(R.string.clear_folder) { _, _ ->
                FolderPermissionManager.clearFolder(this)
                lifecycleScope.launch(Dispatchers.IO) {
                    GameCacheManager.clearCache(this@SettingsActivity)
                }
                updateFolderUI()
                Toast.makeText(this, R.string.clear_folder, Toast.LENGTH_SHORT).show()
            }
            .setNegativeButton(R.string.cancel, null)
            .showThemed()
    }

    private fun showClearCacheConfirmation() {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.clear_cache)
            .setMessage(R.string.clear_cache_desc)
            .setPositiveButton(R.string.clear_cache) { _, _ ->
                lifecycleScope.launch {
                    withContext(Dispatchers.IO) {
                        GameCacheManager.clearCache(this@SettingsActivity)
                    }
                    Toast.makeText(this@SettingsActivity, R.string.clear_cache, Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .showThemed()
    }

    private fun finishWithAnimation() {
        NavigationAnimations.finish(this)
    }
}
