package kwz.love2d.launcher.util

import androidx.annotation.StringRes
import kwz.love2d.launcher.R
import java.util.Locale

/** Curated, game-specific recommendations documented in the repository README. */
object PatchRecommendations {
    data class Recommendation(
        val gameProjectId: String,
        val patchId: String,
        @StringRes val reasonRes: Int,
        val gameVersion: String? = null
    )

    private val rules = listOf(
        Recommendation("chapter_5_weird", PatchManager.PATCH_NIL_ARITHMETIC,
            R.string.patch_recommendation_frostveil),
        Recommendation("starrunefinal", PatchManager.PATCH_RGBA16,
            R.string.patch_recommendation_starrune),
        Recommendation("godhome", PatchManager.PATCH_SHADERS,
            R.string.patch_recommendation_godhome),
        Recommendation("cooking-with-kindness", "cooking-with-kindness.mobile-performance",
            R.string.patch_recommendation_cooking, "DEMO v1.0.6")
    )

    fun forGame(projectId: String?, version: String?): Map<String, Recommendation> {
        val id = projectId?.trim() ?: return emptyMap()
        if (!IdentifierPolicy.isGameProjectId(id)) return emptyMap()
        return rules.asSequence()
            .filter { it.gameProjectId.equals(id, ignoreCase = true) }
            .filter { rule ->
                rule.gameVersion == null || rule.gameVersion.lowercase(Locale.ROOT) ==
                    version?.trim()?.lowercase(Locale.ROOT)
            }
            .associateBy(Recommendation::patchId)
    }
}
