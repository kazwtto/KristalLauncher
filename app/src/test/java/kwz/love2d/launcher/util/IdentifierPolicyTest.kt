package kwz.love2d.launcher.util

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class IdentifierPolicyTest {
    @Test
    fun acceptsExpectedIdentifiers() {
        assertTrue(IdentifierPolicy.isPatchId("kristal.performance"))
        assertTrue(IdentifierPolicy.isPatchId("patch_gamepad"))
        assertTrue(IdentifierPolicy.isTranslationId("plugged-dream.pt-br"))
        assertTrue(IdentifierPolicy.isGameProjectId("actual_game"))
        assertTrue(IdentifierPolicy.isLocalProjectId("0123456789abcdef01234567"))
        assertTrue(IdentifierPolicy.isTranslationEntryId("0123456789ab"))
        assertTrue(IdentifierPolicy.isPackageVersion("1.2.3-beta.1+android"))
    }

    @Test
    fun rejectsTraversalControlsAndMalformedValues() {
        listOf("../patch", "patch/evil", "patch\\evil", "Patch.Evil", "patch..", " patch.id")
            .forEach { assertFalse(IdentifierPolicy.isPatchId(it)) }
        listOf("..", "../translation", "translation/evil", "translation:", "translation\nname")
            .forEach { assertFalse(IdentifierPolicy.isTranslationId(it)) }
        assertFalse(IdentifierPolicy.isLocalProjectId("../../projects"))
        assertFalse(IdentifierPolicy.isTranslationEntryId("not-an-entry"))
        assertFalse(IdentifierPolicy.isPackageVersion("1.0/../../evil"))
        assertFalse(IdentifierPolicy.isPackageVersion("v1.0.0"))
    }

    @Test
    fun rejectsInvalidChecksumsAndLanguageTags() {
        assertTrue(IdentifierPolicy.isSha256("a".repeat(64)))
        assertFalse(IdentifierPolicy.isSha256("g".repeat(64)))
        assertTrue(IdentifierPolicy.isLanguageTag("pt-BR"))
        assertFalse(IdentifierPolicy.isLanguageTag("pt/BR"))
    }
}
