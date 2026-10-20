package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.TranslationReplacement
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.util.zip.ZipFile

class TranslationSafetyTest {
    private fun replacement(source: String, original: String, translated: String): TranslationReplacement {
        val expression = TranslationSafety.quote(original)
        val start = source.indexOf(expression)
        return TranslationReplacement("a1b2c3d4e5f6", TranslationExtractor.sha256(source.toByteArray()),
            start, start + expression.length, original, translated, expression, TranslationSafety.quote(translated))
    }

    @Test
    fun registrationNamesStayCanonicalWhileDescriptionsAndDialogueAreTranslated() {
        val source = """
            function Enemy:init()
                self:registerAct( "Shake" , "Mercy")
                self:registerShortActFor("ralsei", "Pet", "Touch")
            end
            function Enemy:onAct(battler, name)
                if name == "Shake" then self:removeAct("Shake"); return "Done" end
            end
        """.trimIndent()
        val result = TranslationManager.applyToLua(source.toByteArray(), listOf(
            replacement(source, "Shake", "Sacudir"), replacement(source, "Mercy", "Piedade"),
            replacement(source, "Pet", "Afagar")
        )).toString(Charsets.UTF_8)
        assertTrue(result.contains("label(self, \"act\", \"Shake\", \"Sacudir\")"))
        assertTrue(result.contains("label(self, \"act\", \"Pet\", \"Afagar\")"))
        assertTrue(result.contains("\"Piedade\""))
        assertTrue(result.contains("if name == \"Shake\" then self:removeAct(\"Shake\")"))
    }

    @Test
    fun jsonNamesAreProtectedWithoutChangingOrdinaryDialogueLookups() {
        val source = """
            self:registerAct(_s("act-pet", "Pet"))
            self:registerAct(_s("act-meow", "Meow"))
            cutscene:text(_s("dialogue", "Pet"))
            if name == "Pet" then return "Done" end
        """.trimIndent()
        val labels = TranslationSafety.jsonLabels(
            """{"act-pet":{"english":"Pet"},"act-meow":{"english":"Meow"}}""".toByteArray(),
            """{"act-pet":{"english":"Acariciar"},"act-meow":{"english":"Miar"}}""".toByteArray()
        )
        val result = TranslationManager.applyToLua(source.toByteArray(), emptyList(), labels).toString(Charsets.UTF_8)
        assertTrue(result.contains("label(self, \"act\", \"Pet\", \"Acariciar\")"))
        assertTrue(result.contains("cutscene:text(_s(\"dialogue\", \"Pet\"))"))
        assertTrue(result.contains("if name == \"Pet\""))
    }

    @Test
    fun dynamicJsonNamesKeepVariableArgumentsAndUseExpressionEvaluation() {
        val original = "Ⓥ\\\"Bribe \\\" .. self.bribe_cost .. \\\"G\\\""
        val translated = "Ⓥ\\\"Subornar \\\" .. self.bribe_cost .. \\\"G\\\""
        val source = "self:registerAct(_s(\"bribe\", \"fallback\", {\"self.bribe_cost\"}, self.bribe_cost))"
        val result = TranslationManager.applyToLua(source.toByteArray(), emptyList(),
            mapOf("bribe" to TranslationSafety.JsonLabel(original, translated))).toString(Charsets.UTF_8)
        assertTrue(result.contains("translation.dynamic(self, \"act\""))
        assertTrue(result.contains("{\"self.bribe_cost\"}, self.bribe_cost)"))
        assertFalse(result.contains("translation.label("))
        val unsafe = TranslationManager.applyToLua(source.toByteArray(), emptyList(),
            mapOf("bribe" to TranslationSafety.JsonLabel(original,
                translated.replace("self.bribe_cost", "self.other_flag")))).toString(Charsets.UTF_8)
        assertFalse(unsafe.contains("self.other_flag"))
    }

    @Test
    fun commentsAndStringsCannotCreateFakeRegistrationsOrRenderingTargets() {
        val source = """
            -- self:registerAct("Shake")
            local example = [=[self:registerAct("Pet")]=]
            self:registerAct("Talk")
        """.trimIndent()
        val result = TranslationManager.applyToLua(source.toByteArray(), listOf(replacement(source, "Talk", "Conversar")))
        assertTrue(result.toString(Charsets.UTF_8).contains("-- self:registerAct(\"Shake\")"))
        val renderer = """
            -- item.name must stay in this comment
            local example = "item.name"
            love.graphics.print(item.name)
            local width = font:getWidth(item.name)
        """.trimIndent()
        val rendered = TranslationSafety.render(renderer.toByteArray(), "src/engine/game/battle/ui/battleui.lua")
            .toString(Charsets.UTF_8)
        assertTrue(rendered.contains("local example = \"item.name\""))
        assertEquals(2, Regex("translation.display").findAll(rendered).count())
    }

    @Test
    fun writesExecutableRegressionFixture() {
        val source = """
            local enemy = {acts = {}}
            function enemy:registerAct(name) self.acts[name] = true end
            function enemy:removeAct(name) self.acts[name] = nil end
            function enemy:onAct(name)
                if name == "Shake" then
                    self:removeAct("Shake")
                    self:registerAct("Connect")
                    return "finished"
                elseif name == "Connect" then return "connected" end
            end
            enemy:registerAct("Shake")
            assert(enemy.acts.Shake and not enemy.acts.Sacudir)
            assert(__kristal_launcher_translation.display(enemy, "act", "Shake") == "Sacudir")
            assert(enemy:onAct("Shake") == "finished")
            assert(not enemy.acts.Shake and enemy.acts.Connect)
            assert(enemy:onAct("Connect") == "connected")
            assert(__kristal_launcher_translation.display(enemy, "act", "Connect") == "Conectar")
        """.trimIndent()
        val replacements = listOf("Shake" to "Sacudir", "Connect" to "Conectar").map { (original, translated) ->
            val needle = "registerAct(${TranslationSafety.quote(original)})"
            val start = source.indexOf(needle) + "registerAct(".length
            replacement(source, original, translated).copy(startOffset = start,
                endOffset = start + TranslationSafety.quote(original).length)
        }
        val result = TranslationManager.applyToLua(source.toByteArray(), replacements)
        val directory = File("build/translation-safety").apply { mkdirs() }
        directory.resolve("regression.lua").writeBytes(result)
        val renderer = "love.graphics.print(item.name); measured_width = font:getWidth(item.name)"
        directory.resolve("renderer.lua").writeBytes(TranslationSafety.render(renderer.toByteArray(),
            "src/engine/game/battle/ui/battleui.lua"))
    }

    @Test
    fun auditsPublishedPackageWhenOriginalGameIsProvided() {
        val original = System.getenv("KL_TRANSLATION_AUDIT_GAME") ?: return
        val repository = File(System.getProperty("user.dir"), "..").canonicalFile
        ZipFile(File(repository, "translations/packages/plugged-dream-ptbr-1.0.2.kllang")).use { pkg ->
            val replacements = CommunityTranslationTextParser.parse(pkg.getInputStream(pkg.getEntry("texts.json"))
                .bufferedReader().use { it.readText() })
            ZipFile(original).use { game ->
                val path = "scripts/battle/enemies/romb.lua"
                val source = game.getInputStream(game.getEntry("mods/plugged_dream/$path")).use { it.readBytes() }
                val result = TranslationManager.applyToLua(source, replacements.getValue(path)).toString(Charsets.UTF_8)
                assertTrue(result.contains("label(self, \"act\", \"Shake\", \"Sacudir\")"))
                assertTrue(result.contains("if name == \"Shake\""))
                assertTrue(result.contains("self:removeAct(\"Shake\")"))
                File("build/translation-safety").apply { mkdirs() }.resolve("published-romb.lua").writeText(result)
            }
        }
    }

    @Test
    fun auditsCookingJsonSelectorsWhenOriginalGameIsProvided() {
        val original = System.getenv("KL_TRANSLATION_AUDIT_COOKING") ?: return
        val repository = File(System.getProperty("user.dir"), "..").canonicalFile
        ZipFile(original).use { game ->
            val originalJson = game.getInputStream(game.getEntry("dialoguedump.json")).use { it.readBytes() }
            val directory = File("build/translation-safety/cooking").apply { mkdirs() }
            for (language in listOf("ptbr", "es")) {
                val translatedJson = File(repository,
                    "translations/sources/cooking-with-kindness-$language/payload/dialoguedump.json").readBytes()
                val labels = TranslationSafety.jsonLabels(originalJson, translatedJson)
                var count = 0
                game.entries().asSequence().filter {
                    it.name.startsWith("mods/CookingwithKindness/scripts/") && it.name.endsWith(".lua")
                }.forEach { entry ->
                    val source = game.getInputStream(entry).use { it.readBytes() }
                    val result = TranslationManager.applyToLua(source, emptyList(), labels)
                    if (!source.contentEquals(result)) {
                        count++
                        directory.resolve("$language-$count.lua").writeBytes(result)
                    }
                    if (entry.name.endsWith("scripts/battle/lightenemies/catamari.lua")) {
                        assertTrue(result.toString(Charsets.UTF_8).contains(
                            "label(self, \"act\", \"Pet\", \"Acariciar\")"))
                        assertTrue(result.toString(Charsets.UTF_8).contains("if name == \"Pet\""))
                    }
                }
                assertTrue("Cooking must protect JSON-backed registrations", count > 0)
            }
        }
    }

    @Test
    fun shopReplacementsAndXActionsKeepTheirSelectors() {
        val shop = """
            self:registerTalk("About you")
            self:replaceTalk("Goodbye", 1)
            self:registerTalkAfter("History", 1)
        """.trimIndent()
        val result = TranslationManager.applyToLua(shop.toByteArray(), listOf(
            replacement(shop, "About you", "Sobre você"), replacement(shop, "Goodbye", "Adeus"),
            replacement(shop, "History", "História")
        )).toString(Charsets.UTF_8)
        assertEquals(3, Regex("label\\(self, \"talk\"").findAll(result).count())
        val xact = "function Enemy:getXAction(battler)\n return \"Standard\"\nend"
        val fixed = TranslationManager.applyToLua(xact.toByteArray(), listOf(
            replacement(xact, "Standard", "Padrão")
        )).toString(Charsets.UTF_8)
        assertTrue(fixed.contains("return __kristal_launcher_translation.label(self, \"act\", \"Standard\", \"Padrão\")"))
    }

    @Test
    fun dynamicSelectorsAreNotPartiallyRenamed() {
        val source = "self:registerAct(\"Pet\" .. suffix)"
        val result = TranslationManager.applyToLua(source.toByteArray(), listOf(replacement(source, "Pet", "Afagar")))
        assertEquals(source, result.toString(Charsets.UTF_8))
    }

    @Test
    fun callbackTagsAndDynamicPlaceholdersKeepTheirArguments() {
        assertEquals("\\{lua\\d+\\}", TranslationManager.DYNAMIC_PLACEHOLDER_PATTERN)
        assertEquals(listOf("{lua1}", "{lua25}"), Regex(TranslationManager.DYNAMIC_PLACEHOLDER_PATTERN)
            .findAll("{lua1} and {lua25}").map { it.value }.toList())
        assertEquals(TranslationManager.ValidationError.CONTROL_TAG,
            TranslationManager.validationError("[func:finishAction]Hello", "[func:terminar]Olá"))
        assertEquals(TranslationManager.ValidationError.FORMAT_PLACEHOLDER,
            TranslationManager.validationError("Press {lua1}", "Aperte {lua2}"))
        assertNull(TranslationManager.validationError("[func:finishAction]Hello", "[func:finishAction]Olá"))
        assertNull(TranslationManager.validationError("[Angel]Hello", "[Anjo]Olá"))
        assertNull(TranslationManager.validationError("[Priority: High]", "[Prioridade: Alta]"))
        assertNull(TranslationManager.validationError("[react:Hello,10,20,angry,susie]",
            "[react:Olá,10,20,angry,susie]"))
        assertEquals(TranslationManager.ValidationError.CONTROL_TAG,
            TranslationManager.validationError("[react:Hello,10,20,angry,susie]",
                "[react:Olá,10,20,angry,ralsei]"))
    }

    @Test
    fun commentMarkersInsideLiteralsDoNotHideRealRegistrations() {
        val source = "local separator = \"---\"; self:registerAct(\"Pet\")"
        val fixed = TranslationManager.applyToLua(source.toByteArray(), listOf(replacement(source, "Pet", "Afagar")))
        assertTrue(fixed.toString(Charsets.UTF_8).contains("label(self, \"act\", \"Pet\", \"Afagar\")"))
    }

    @Test
    fun currentCatalogTextPackagesRemainReadableWithExecutableTagProtection() {
        val repository = File(System.getProperty("user.dir"), "..").canonicalFile
        val catalog = org.json.JSONObject(File(repository, "translations/catalog.json").readText())
            .getJSONArray("translations")
        for (index in 0 until catalog.length()) {
            val entry = catalog.getJSONObject(index)
            ZipFile(File(repository, "translations/${entry.getString("package")}")).use { pkg ->
                val text = pkg.getEntry("texts.json") ?: return@use
                CommunityTranslationTextParser.parse(pkg.getInputStream(text).bufferedReader().use { it.readText() })
            }
        }
    }

    @Test
    fun ambiguousStringChoicesKeepTheirLogicWhileOrdinaryDialogueStillTranslates() {
        val source = """
            local choice = cutscene:choicer({"Leave", "Stay"})
            if options[choice] == "Leave" then finish() end
            cutscene:text("Leave")
        """.trimIndent()
        val first = replacement(source, "Leave", "Sair")
        val lastStart = source.lastIndexOf("\"Leave\"")
        val last = first.copy(entryId = "b1b2c3d4e5f6", startOffset = lastStart, endOffset = lastStart + 7)
        val fixed = TranslationManager.applyToLua(source.toByteArray(), listOf(first, last)).toString(Charsets.UTF_8)
        assertTrue(fixed.contains("choicer({\"Leave\", \"Stay\"})"))
        assertTrue(fixed.contains("options[choice] == \"Leave\""))
        assertTrue(fixed.contains("cutscene:text(\"Sair\")"))
    }
}
