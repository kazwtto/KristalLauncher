package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.TranslationReplacement
import org.json.JSONObject

/** Keeps menu selectors canonical; translated labels belong exclusively to rendering. */
object TranslationSafety {
    const val REVISION = "canonical-menu-labels-2"
    const val RUNTIME_PATH = "kristal_launcher/translation_labels.lua"
    data class JsonLabel(val original: String, val translated: String)
    private data class Argument(val owner: String, val kind: String, val start: Int, val end: Int)

    internal fun isRenderer(path: String): Boolean {
        val normalized = path.lowercase()
        return normalized == "src/engine/game/battle/ui/battleui.lua" ||
            normalized == "src/engine/game/battle/battleui.lua" ||
            normalized.endsWith("/scripts/lightbattle/ui/lightbattleui.lua") ||
            normalized == "src/engine/game/shop.lua"
    }

    internal fun jsonLabels(original: ByteArray, translated: ByteArray): Map<String, JsonLabel> {
        val before = JSONObject(original.toString(Charsets.UTF_8))
        val after = JSONObject(translated.toString(Charsets.UTF_8))
        return buildMap {
            before.keys().forEach { id ->
                val source = before.optJSONObject(id)?.opt("english") as? String
                val target = after.optJSONObject(id)?.opt("english") as? String
                if (source != null && target != null && source != target) put(id, JsonLabel(source, target))
            }
        }
    }

    internal fun protect(
        source: ByteArray,
        replacements: List<TranslationReplacement>,
        json: Map<String, JsonLabel> = emptyMap()
    ): List<TranslationReplacement> {
        val text = source.toString(Charsets.UTF_8)
        val tokens = TranslationExtractor.lexStrings(text)
        val mask = text.toCharArray()
        tokens.forEach { for (i in it.start until it.end) mask[i] = ' ' }
        TranslationExtractor.maskComments(text, mask)
        val code = String(mask)
        val functions = Regex("\\bfunction\\b").findAll(code).map { it.range.first }.toList()
        var scopeIndex = -1
        val getter = Regex("^function\\s+[A-Za-z_][A-Za-z0-9_.]*:getXAction\\s*\\(")
        val returnPrefix = Regex("\\breturn\\s*$")
        val protected = (arguments(code) + tokens.mapNotNull { token ->
            while (scopeIndex + 1 < functions.size && functions[scopeIndex + 1] < token.start) scopeIndex++
            val scope = functions.getOrNull(scopeIndex)
            if (scope != null && getter.containsMatchIn(code.substring(scope, minOf(scope + 160, code.length))) &&
                returnPrefix.containsMatchIn(code.substring(maxOf(0, token.start - 80), token.start))) {
                Argument("self", "act", token.start, token.end)
            } else null
        }).map { argument ->
            var start = argument.start
            var end = argument.end
            while (start < end && text[start].isWhitespace()) start++
            while (end > start && text[end - 1].isWhitespace()) end--
            argument.copy(start = start, end = end)
        }
        val structuralValues = tokens.filter { token ->
            val left = code.substring(maxOf(0, token.start - 100), token.start)
            val right = code.substring(token.end, minOf(code.length, token.end + 100))
            Regex("(?:==|~=)\\s*$").containsMatchIn(left) ||
                Regex("^\\s*(?:==|~=)").containsMatchIn(right) ||
                (Regex("\\[\\s*$").containsMatchIn(left) && Regex("^\\s*]").containsMatchIn(right)) ||
                Regex("(?:removeAct|getAct|hasAct|startTalk)\\s*\\(\\s*$").containsMatchIn(left)
        }.map { it.value }.toSet()
        val contexts = if (structuralValues.isEmpty()) emptyMap() else {
            TranslationExtractor.extractFile("scripts/battle/enemies/menu_safety.lua", text)
                .associateBy { it.startOffset }
        }
        val result = replacements.filterNot { replacement ->
            protected.any { replacement.startOffset < it.end && replacement.endOffset > it.start } ||
                (replacement.sourceText in structuralValues &&
                    contexts[replacement.startOffset]?.context?.let { context ->
                        SAFE_DISPLAY_CALLS.any { context.startsWith("call:$it:") }
                    } != true)
        }.toMutableList()
        protected.forEach { argument ->
            val expression = text.substring(argument.start, argument.end)
            val inside = tokens.filter { it.start >= argument.start && it.end <= argument.end }
            val exact = replacements.singleOrNull {
                it.startOffset == argument.start && it.endOffset == argument.end
            }
            val lookup = Regex("^\\s*_s\\s*\\(").containsMatchIn(expression)
            val jsonLabel = if (lookup) inside.firstOrNull()?.value?.let(json::get) else null
            val literal = inside.singleOrNull()?.takeIf {
                it.start == argument.start && it.end == argument.end
            }
            if (jsonLabel != null && jsonLabel.original.startsWith("Ⓥ")) {
                val spans = lookupArguments(code, argument.start, argument.end)
                // Pass the game's original variable-name/value arguments unchanged. Its
                // existing UnconcateText evaluator resolves each label, not the selector ID.
                if (spans.size >= 2) {
                    val variables = if (spans.size > 2) {
                        text.substring(spans[2].first, spans.last().last + 1)
                    } else "nil"
                    val target = safeDynamicLabel(jsonLabel)
                    val dynamic = "__kristal_launcher_translation.dynamic(${argument.owner}, ${quote(argument.kind)}, " +
                        "${quote(jsonLabel.original)}, ${quote(target)}, $variables)"
                    result += TranslationReplacement("menu-label-${argument.start}", TranslationExtractor.sha256(source),
                        argument.start, argument.end, jsonLabel.original, jsonLabel.original, expression, dynamic)
                }
                return@forEach
            }
            val canonical = jsonLabel?.original ?: literal?.let { exact?.sourceText ?: it.value }
            val translated = jsonLabel?.translated ?: exact?.translatedText?.takeIf(String::isNotBlank)
            // Unknown/dynamic selectors stay untouched rather than guessing a reverse mapping.
            if (canonical != null && translated != null && canonical != translated) {
                require(TranslationManager.validationError(canonical, translated) == null) {
                    "Menu label changed control tags or placeholders"
                }
                val originalValue = if (jsonLabel != null) quote(canonical) else expression
                val label = "__kristal_launcher_translation.label(${argument.owner}, ${quote(argument.kind)}, " +
                    "$originalValue, ${quote(translated)})"
                result += TranslationReplacement(
                    "menu-label-${argument.start}", TranslationExtractor.sha256(source),
                    argument.start, argument.end, canonical, canonical, expression, label
                )
            }
        }
        return result
    }

    private fun lookupArguments(code: String, start: Int, end: Int): List<IntRange> = buildList {
        val open = code.indexOf('(', start)
        if (open < 0 || open >= end) return@buildList
        var argumentStart = open + 1
        var depth = 0
        for (i in argumentStart until end) {
            val c = code[i]
            if ((c == ',' || c == ')') && depth == 0) {
                add(argumentStart until i)
                if (c == ')') break
                argumentStart = i + 1
            } else when (c) {
                '(', '{', '[' -> depth++
                ')', '}', ']' -> depth--
            }
        }
    }

    private fun safeDynamicLabel(label: JsonLabel): String {
        fun structure(value: String): String {
            val expression = value.removePrefix("Ⓥ").replace("\\\"", "\"")
            val mask = expression.toCharArray()
            TranslationExtractor.lexStrings(expression).forEach { for (i in it.start until it.end) mask[i] = ' ' }
            TranslationExtractor.maskComments(expression, mask)
            return String(mask).filterNot(Char::isWhitespace)
        }
        return label.translated.takeIf {
            it.startsWith("Ⓥ") && structure(it) == structure(label.original) &&
                TranslationManager.validationError(label.original, it) == null
        } ?: label.original
    }

    /** Rendering expressions only, never ACT callbacks or registration tables. */
    internal fun render(source: ByteArray, path: String): ByteArray {
        val normalized = path.lowercase()
        val battle = isRenderer(normalized) && normalized != "src/engine/game/shop.lua"
        val shop = normalized == "src/engine/game/shop.lua"
        if (!battle && !shop) return source
        val text = source.toString(Charsets.UTF_8)
        val mask = text.toCharArray()
        TranslationExtractor.lexStrings(text).forEach { for (i in it.start until it.end) mask[i] = ' ' }
        TranslationExtractor.maskComments(text, mask)
        val code = String(mask)
        val matches = if (battle) {
            Regex("\\bitem\\.name\\b").findAll(code).toList()
        } else {
            // Restrict shop labels to the dedicated renderer, not startTalk or input handling.
            val start = code.indexOf("function Shop:drawTalkMenu(")
            if (start < 0) return source
            val end = code.indexOf("\nfunction ", start + 1).let { if (it < 0) code.length else it }
            Regex("\\bv\\[1]").findAll(code).filter { it.range.first in start until end }.toList()
        }
        var result = text
        matches.asReversed().forEach { match ->
            val expression = if (battle) {
                "__kristal_launcher_translation.display(item.highlight, \"act\", item.name)"
            } else {
                "__kristal_launcher_translation.display(self, \"talk\", v[1])"
            }
            result = result.replaceRange(match.range, expression)
        }
        if (battle) {
            // These names are returned by getXAction, not registered ACT entries.
            val xact = "Game.battle.selected_xaction.name"
            val maskedResult = result.toCharArray()
            TranslationExtractor.lexStrings(result).forEach { for (i in it.start until it.end) maskedResult[i] = ' ' }
            TranslationExtractor.maskComments(result, maskedResult)
            Regex("Game\\.battle\\.selected_xaction\\.name\\b").findAll(String(maskedResult))
                .toList().asReversed().forEach { match ->
                    result = result.replaceRange(match.range,
                        "__kristal_launcher_translation.display(enemy, \"act\", $xact)")
                }
        }
        return result.toByteArray(Charsets.UTF_8)
    }

    private fun arguments(code: String): List<Argument> = buildList {
        val call = Regex("\\b([A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)*):" +
            "(registerAct|registerShortAct|registerActFor|registerShortActFor|registerTalk|registerTalkAfter|replaceTalk)\\s*\\(")
        call.findAll(code).forEach { match ->
            val method = match.groupValues[2]
            val index = if (method.endsWith("ActFor")) 1 else 0
            var start = match.range.last + 1
            var argument = 0
            var depth = 0
            for (i in start until code.length) {
                val c = code[i]
                if ((c == ',' || c == ')') && depth == 0) {
                    if (argument == index) {
                        // Whitespace in the mask includes literals, so trim against the real
                        // source later; positions here retain the entire argument span.
                        add(Argument(match.groupValues[1], if (method.contains("Talk")) "talk" else "act", start, i))
                        break
                    }
                    start = i + 1
                    argument++
                } else when (c) {
                    '(', '{', '[' -> depth++
                    ')', '}', ']' -> depth--
                }
            }
        }
    }

    internal fun quote(value: String): String = buildString {
        append('"')
        value.forEach { c -> append(when (c) {
            '\\' -> "\\\\"; '"' -> "\\\""; '\n' -> "\\n"; '\r' -> "\\r"; '\t' -> "\\t"
            else -> if (c.code < 32) "\\${c.code.toString().padStart(3, '0')}" else c.toString()
        }) }
        append('"')
    }

    private val SAFE_DISPLAY_CALLS = setOf(
        "text", "boardText", "battlerText", "gonerText", "showText", "infoText",
        "startDialogue", "Text", "DialogueText", "setText", "addText", "TrophyMessage"
    )
}
