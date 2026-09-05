package kwz.love2d.launcher.model

import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Test

class LocalizedTextTest {

    @Test
    fun genericPortuguesePrefersBrazilianPortugueseBeforeEnglish() {
        val text = LocalizedText(
            linkedMapOf(
                "en" to "English",
                "pt-BR" to "Português"
            )
        )

        assertEquals("Português", text.resolve(Locale.forLanguageTag("pt")))
    }

    @Test
    fun genericSpanishMatchesRegionalSpanish() {
        val text = LocalizedText(
            linkedMapOf(
                "en" to "English",
                "es-ES" to "Español"
            )
        )

        assertEquals("Español", text.resolve(Locale.forLanguageTag("es")))
    }

    @Test
    fun localeKeysAreMatchedCaseInsensitivelyAndAcceptUnderscores() {
        val text = LocalizedText(
            linkedMapOf(
                "en" to "English",
                "PT_br" to "Português"
            )
        )

        assertEquals("Português", text.resolve(Locale.forLanguageTag("pt-BR")))
    }

    @Test
    fun exactRegionalLocaleWinsOverAnotherVariantOfSameLanguage() {
        val text = LocalizedText(
            linkedMapOf(
                "pt-BR" to "Brasil",
                "pt-PT" to "Portugal",
                "en" to "English"
            )
        )

        assertEquals("Portugal", text.resolve(Locale.forLanguageTag("pt-PT")))
    }

    @Test
    fun englishRemainsFallbackWhenRequestedLanguageIsUnavailable() {
        val text = LocalizedText(
            linkedMapOf(
                "pt-BR" to "Português",
                "en" to "English"
            )
        )

        assertEquals("English", text.resolve(Locale.forLanguageTag("fr-FR")))
    }
}
