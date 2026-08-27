package kwz.love2d.launcher.model

import androidx.annotation.StringRes
import androidx.annotation.ArrayRes

data class BuiltInPatchDefinition(
    val id: String,
    @StringRes val nameRes: Int,
    @StringRes val descriptionRes: Int,
    @ArrayRes val useCasesRes: Int,
    val defaultEnabled: Boolean,
    val category: String = "compatibility",
    @StringRes val warningOnEnableRes: Int? = null,
    @StringRes val warningOnDisableRes: Int? = null
)
