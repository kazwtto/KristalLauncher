package kwz.love2d.launcher.util

import android.content.Context
import kwz.love2d.launcher.R
import kwz.love2d.launcher.model.BuiltInPatchDefinition
import kwz.love2d.launcher.model.PatchDisplayItem
import kwz.love2d.launcher.model.PatchOrigin
import kwz.love2d.launcher.model.PatchTrust

object PatchRegistry {

    val builtInPatches = listOf(
        BuiltInPatchDefinition(
            id = PatchManager.PATCH_TEXT,
            nameRes = R.string.patch_text_title,
            descriptionRes = R.string.patch_text_desc,
            useCasesRes = R.array.patch_text_use_cases,
            defaultEnabled = true,
            warningOnEnableRes = R.string.patch_text_warning
        ),
        BuiltInPatchDefinition(
            id = PatchManager.PATCH_FULLSCREEN,
            nameRes = R.string.patch_fullscreen_title,
            descriptionRes = R.string.patch_fullscreen_desc,
            useCasesRes = R.array.patch_fullscreen_use_cases,
            defaultEnabled = true
        ),
        BuiltInPatchDefinition(
            id = PatchManager.PATCH_SHADERS,
            nameRes = R.string.patch_shaders_title,
            descriptionRes = R.string.patch_shaders_desc,
            useCasesRes = R.array.patch_shaders_use_cases,
            defaultEnabled = true,
            warningOnDisableRes = R.string.patch_shaders_warning
        ),
        BuiltInPatchDefinition(
            id = PatchManager.PATCH_GAMEPAD,
            nameRes = R.string.patch_gamepad_title,
            descriptionRes = R.string.patch_gamepad_desc,
            useCasesRes = R.array.patch_gamepad_use_cases,
            defaultEnabled = true,
            category = "controls"
        ),
        BuiltInPatchDefinition(
            id = PatchManager.PATCH_BORDERS,
            nameRes = R.string.patch_borders_title,
            descriptionRes = R.string.patch_borders_desc,
            useCasesRes = R.array.patch_borders_use_cases,
            defaultEnabled = true,
            category = "graphics"
        ),
        BuiltInPatchDefinition(
            id = PatchManager.PATCH_RGBA16,
            nameRes = R.string.patch_rgba16_title,
            descriptionRes = R.string.patch_rgba16_desc,
            useCasesRes = R.array.patch_rgba16_use_cases,
            defaultEnabled = false,
            category = "graphics"
        ),
        BuiltInPatchDefinition(
            id = PatchManager.PATCH_PHYSFS,
            nameRes = R.string.patch_physfs_title,
            descriptionRes = R.string.patch_physfs_desc,
            useCasesRes = R.array.patch_physfs_use_cases,
            defaultEnabled = false
        ),
        BuiltInPatchDefinition(
            id = PatchManager.PATCH_NIL_ARITHMETIC,
            nameRes = R.string.patch_nil_arithmetic_title,
            descriptionRes = R.string.patch_nil_arithmetic_desc,
            useCasesRes = R.array.patch_nil_arithmetic_use_cases,
            defaultEnabled = false
        )
    )

    fun findBuiltIn(id: String): BuiltInPatchDefinition? = builtInPatches.find { it.id == id }

    fun getBuiltInDisplayItems(context: Context): List<PatchDisplayItem> = builtInPatches.map { patch ->
        PatchDisplayItem(
            id = patch.id,
            version = "${kwz.love2d.launcher.BuildConfig.VERSION_NAME}",
            name = context.getString(patch.nameRes),
            description = context.getString(patch.descriptionRes),
            useCases = context.resources.getStringArray(patch.useCasesRes).toList(),
            author = context.getString(R.string.patch_author_launcher),
            category = patch.category,
            origin = PatchOrigin.BUILT_IN,
            trust = PatchTrust.BUILT_IN,
            capabilities = listOf("staged_package"),
            dependencies = emptyList(),
            conflicts = emptyList(),
            installed = true,
            enabled = PatchManager.isGlobalPatchEnabled(context, patch.id)
        )
    }
}
