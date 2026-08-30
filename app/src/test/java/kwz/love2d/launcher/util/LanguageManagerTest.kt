package kwz.love2d.launcher.util

import org.junit.Assert.assertEquals
import org.junit.Test

class LanguageManagerTest {

    @Test
    fun explicitLauncherLanguageOverridesDeviceLanguageForGamepad() {
        assertEquals("pt", LanguageManager.resolveGamepadLanguage("pt", "en"))
        assertEquals("en", LanguageManager.resolveGamepadLanguage("en", "pt"))
        assertEquals("es", LanguageManager.resolveGamepadLanguage("es", "pt"))
    }

    @Test
    fun deviceOptionUsesSupportedDeviceLanguageAndFallsBackToEnglish() {
        assertEquals("pt", LanguageManager.resolveGamepadLanguage("system", "pt-BR"))
        assertEquals("es", LanguageManager.resolveGamepadLanguage("system", "es"))
        assertEquals("en", LanguageManager.resolveGamepadLanguage("system", "ja"))
    }
}
