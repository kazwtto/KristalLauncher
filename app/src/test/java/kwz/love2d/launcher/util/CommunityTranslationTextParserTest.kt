package kwz.love2d.launcher.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.json.JSONObject

class CommunityTranslationTextParserTest {
    @Test
    fun parsesTextOnlyReplacement() {
        val parsed = CommunityTranslationTextParser.parse(
            """{
              "a1b2c3d4e5f6": {
                "file": "scripts/world/test.lua",
                "fileHash": "${"a".repeat(64)}",
                "startOffset": 10,
                "endOffset": 17,
                "source": "Hello",
                "translation": "Olá",
                "originalExpression": "\"Hello\"",
                "replacementExpression": "\"Olá\""
              }
            }"""
        )

        val entry = parsed.getValue("scripts/world/test.lua").single()
        assertEquals("Hello", entry.sourceText)
        assertEquals("Olá", entry.translatedText)
    }

    @Test
    fun rejectsTargetsOutsideGameScripts() {
        assertThrows(IllegalArgumentException::class.java) {
            CommunityTranslationTextParser.parse(
                """{
                  "a1b2c3d4e5f6": {
                    "file": "../src/engine.lua",
                    "fileHash": "${"a".repeat(64)}",
                    "startOffset": 1,
                    "endOffset": 2,
                    "source": "A",
                    "translation": "B",
                    "originalExpression": "\"A\"",
                    "replacementExpression": "\"B\""
                  }
                }"""
            )
        }
    }

    @Test
    fun appliesOnlyTheDeclaredDynamicTextExpression() {
        val lua = "local x = \"Press \"..key..\"!\"\nreturn x"
        val original = "\"Press \"..key..\"!\""
        val start = lua.indexOf(original)
        val item = JSONObject()
            .put("file", "scripts/test.lua")
            .put("fileHash", TranslationExtractor.sha256(lua.toByteArray()))
            .put("startOffset", start)
            .put("endOffset", start + original.length)
            .put("source", "Press {lua1}!")
            .put("translation", "Aperte {lua1}!")
            .put("originalExpression", original)
            .put("replacementExpression", "\"Aperte \" .. (key) .. \"!\"")
        val parsed = CommunityTranslationTextParser.parse(
            JSONObject().put("a1b2c3d4e5f6", item).toString()
        )

        val result = TranslationManager.applyToLua(
            lua.toByteArray(),
            parsed.getValue("scripts/test.lua")
        ).toString(Charsets.UTF_8)

        assertEquals("local x = \"Aperte \" .. (key) .. \"!\"\nreturn x", result)
    }
}
