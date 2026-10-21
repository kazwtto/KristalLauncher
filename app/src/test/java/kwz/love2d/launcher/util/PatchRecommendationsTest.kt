package kwz.love2d.launcher.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PatchRecommendationsTest {
    @Test fun readmeGamesResolveToTheirDocumentedPatches() {
        assertTrue(PatchManager.PATCH_NIL_ARITHMETIC in
            PatchRecommendations.forGame("chapter_5_weird", "v1.3.1"))
        assertTrue(PatchManager.PATCH_RGBA16 in
            PatchRecommendations.forGame("starrunefinal", "v2.0.0"))
        assertTrue(PatchManager.PATCH_SHADERS in
            PatchRecommendations.forGame("godhome", null))
        assertTrue("cooking-with-kindness.mobile-performance" in
            PatchRecommendations.forGame("cooking-with-kindness", "DEMO v1.0.6"))
    }

    @Test fun dedicatedOptimizationDoesNotMatchAnotherGameVersion() {
        assertFalse("cooking-with-kindness.mobile-performance" in
            PatchRecommendations.forGame("cooking-with-kindness", "DEMO v1.0.7"))
        assertFalse("cooking-with-kindness.mobile-performance" in
            PatchRecommendations.forGame("cooking-with-kindness", null))
    }

    @Test fun recommendationsRequireAnExactValidProjectId() {
        assertEquals(emptyMap<String, PatchRecommendations.Recommendation>(),
            PatchRecommendations.forGame("godhome-remake", null))
        assertEquals(emptyMap<String, PatchRecommendations.Recommendation>(),
            PatchRecommendations.forGame("../godhome", null))
        assertEquals(emptyMap<String, PatchRecommendations.Recommendation>(),
            PatchRecommendations.forGame(null, null))
    }
}
