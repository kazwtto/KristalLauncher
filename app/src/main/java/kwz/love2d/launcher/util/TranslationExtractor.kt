package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.ExtractedTranslation
import kwz.love2d.launcher.model.LoveGame
import kwz.love2d.launcher.model.TranslationEntry
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.Locale

/**
 * Extracts player-facing text only from the selected game/mod content root.
 * Kristal's src/, libraries/, runtime and launcher-injected files are never scanned.
 */
object TranslationExtractor {
    private const val MAX_ARCHIVE_ENTRIES = 250_000
    private const val MAX_LUA_FILE_BYTES = 2 * 1024 * 1024
    private const val MAX_TOTAL_LUA_BYTES = 64 * 1024 * 1024
    private const val MAX_TRANSLATION_ENTRIES = 50_000

    private val callRules = mapOf(
        "text" to setOf(0),
        "boardText" to setOf(0),
        "battlerText" to setOf(1),
        "gonerText" to setOf(0),
        "showText" to setOf(0),
        "infoText" to setOf(0),
        "startDialogue" to setOf(0),
        "Text" to setOf(0),
        "DialogueText" to setOf(0),
        "setText" to setOf(0),
        "addText" to setOf(0),
        "choicer" to setOf(0),
        "GonerChoice" to setOf(2),
        "registerAct" to setOf(0, 1),
        "registerShortAct" to setOf(0, 1),
        "registerTalk" to setOf(0),
        "TrophyMessage" to setOf(2, 3)
    )

    private val dialogueFields = setOf(
        "text", "texts", "dialogue", "dialogues", "dialogue_override", "text_override",
        "random_texts", "reactions", "check", "low_health_text", "spareable_text",
        "gameover_message", "no_end_message_text", "encounter_text", "current_encounter_text",
        "flavor_text"
    )

    private val uiFields = setOf(
        "comment", "description", "desc", "alt_description", "alt_desc", "effect", "shop",
        "use_name", "short_name", "cast_name", "title", "pre_title", "message", "prompt",
        "label", "caption", "battle_description", "menu_description", "choice_text"
    )

    private val excludedDirectories = setOf(
        "libraries", "library", "vendor", "node_modules", ".git", "kristal_launcher"
    )

    fun extract(sourceArchive: File, game: LoveGame): ExtractedTranslation {
        val sourceRoot = normalizePath(game.translationRoot.orEmpty()).trim('/')
        val targetRoot = if (game.isKristalMod) {
            val id = game.projectId?.takeIf(String::isNotBlank)
                ?: sourceRoot.substringAfterLast('/').takeIf(String::isNotBlank)
                ?: throw IllegalArgumentException("The mod does not have a translation target")
            "mods/${sanitizeFolderName(id)}"
        } else {
            sourceRoot
        }

        return extract(sourceArchive, sourceRoot, targetRoot)
    }

    internal fun extract(
        sourceArchive: File,
        sourceRoot: String,
        targetRoot: String
    ): ExtractedTranslation {

        val extracted = mutableListOf<TranslationEntry>()
        val fileFingerprints = mutableListOf<String>()
        var totalBytes = 0
        GameArchive.open(sourceArchive).use { archive ->
            val entries = archive.entries(MAX_ARCHIVE_ENTRIES)
            for (entry in entries) {
                if (entry.isDirectory || entry.size !in 0..MAX_LUA_FILE_BYTES.toLong()) continue
                val archivePath = safePath(entry.name) ?: continue
                val relativePath = relativeGamePath(archivePath, sourceRoot) ?: continue
                if (!isGameLuaPath(relativePath, sourceRoot.isNotBlank())) continue

                val bytes = archive.open(entry).use { readLimited(it, MAX_LUA_FILE_BYTES) }
                totalBytes += bytes.size
                require(totalBytes <= MAX_TOTAL_LUA_BYTES) { "Game scripts exceed the translation scan limit" }
                val source = bytes.toString(Charsets.UTF_8)
                val fileHash = sha256(bytes)
                fileFingerprints += "$relativePath:$fileHash"
                val candidates = extractFile(relativePath, source, fileHash)
                require(extracted.size + candidates.size <= MAX_TRANSLATION_ENTRIES) {
                    "Game contains too many translatable entries"
                }
                extracted += candidates
            }
        }

        val fingerprint = sha256(fileFingerprints.sorted().joinToString("\n").toByteArray())
        return ExtractedTranslation(
            fingerprint = fingerprint,
            sourceRoot = sourceRoot,
            targetRoot = targetRoot,
            entries = extracted
        )
    }

    internal fun extractFile(
        relativePath: String,
        source: String,
        fileHash: String = sha256(source.toByteArray())
    ): List<TranslationEntry> {
        val tokens = lexStrings(source)
        val mask = source.toCharArray()
        tokens.forEach { token ->
            for (index in token.start until token.end.coerceAtMost(mask.size)) mask[index] = ' '
        }
        maskComments(source, mask)
        val masked = String(mask)
        val occurrences = mutableMapOf<String, Int>()

        return tokens.mapNotNull { token ->
            if (token.value.isBlank() || isControlOnly(token.value)) return@mapNotNull null
            val classification = classify(relativePath, source, masked, token) ?: return@mapNotNull null
            val occurrenceKey = "${classification.first}\u001f${classification.second}\u001f${token.value}"
            val ordinal = occurrences.getOrDefault(occurrenceKey, 0)
            occurrences[occurrenceKey] = ordinal + 1
            val idMaterial = listOf(
                relativePath,
                classification.first,
                classification.second,
                token.value,
                ordinal.toString()
            ).joinToString("\u001f")
            TranslationEntry(
                projectId = "",
                id = sha1(idMaterial.toByteArray()).take(12),
                sourceText = token.value,
                translatedText = "",
                filePath = relativePath,
                fileHash = fileHash,
                startOffset = token.start,
                endOffset = token.end,
                line = token.line,
                kind = classification.first,
                context = classification.second
            )
        }
    }

    private fun classify(
        relativePath: String,
        source: String,
        mask: String,
        token: LuaStringToken
    ): Pair<String, String>? {
        enclosingCall(mask, token.start)?.let { call ->
            val accepted = callRules[call.name]
            if (accepted != null && call.argumentIndex in accepted) {
                val kind = when (call.name) {
                    "choicer", "GonerChoice" -> "choice"
                    "registerAct", "registerShortAct" -> "battle_ui"
                    "registerTalk" -> "shop_ui"
                    "infoText" -> "battle_text"
                    else -> "dialogue"
                }
                return kind to "call:${call.name}:arg${call.argumentIndex + 1}"
            }
        }

        val lineStart = source.lastIndexOf('\n', token.start - 1).let { if (it < 0) 0 else it + 1 }
        val left = mask.substring(lineStart, token.start)
        val field = FIELD_ASSIGNMENT.find(left)?.groupValues?.getOrNull(1)?.lowercase(Locale.ROOT)
        if (field != null) {
            when {
                field in dialogueFields || MAP_TEXT_FIELD.matches(field) ->
                    return "dialogue" to "field:$field"
                field in uiFields -> return "ui_text" to "field:$field"
                field == "name" && isVisibleNamePath(relativePath) ->
                    return "ui_text" to "field:name"
            }
        }
        return null
    }

    private fun enclosingCall(mask: String, position: Int): CallContext? {
        var depth = 0
        var index = position - 1
        var open = -1
        while (index >= 0 && position - index <= 2_048) {
            when (mask[index]) {
                ')' -> depth++
                '(' -> if (depth == 0) {
                    open = index
                    break
                } else depth--
            }
            index--
        }
        if (open < 0) return null
        val prefix = mask.substring(maxOf(0, open - 160), open)
        val name = CALL_NAME.find(prefix)?.groupValues?.getOrNull(1)?.substringAfterLast('.')?.substringAfterLast(':')
            ?: return null
        var argumentIndex = 0
        var nested = 0
        for (cursor in open + 1 until position) {
            when (mask[cursor]) {
                '(', '{', '[' -> nested++
                ')', '}', ']' -> if (nested > 0) nested--
                ',' -> if (nested == 0) argumentIndex++
            }
        }
        return CallContext(name, argumentIndex)
    }

    private fun lexStrings(source: String): List<LuaStringToken> {
        val result = mutableListOf<LuaStringToken>()
        var index = 0
        var line = 1
        while (index < source.length) {
            if (source.startsWith("--", index)) {
                val longComment = longBracket(source, index + 2)
                if (longComment != null) {
                    line += source.substring(index, longComment.second).count { it == '\n' }
                    index = longComment.second
                } else {
                    val end = source.indexOf('\n', index).let { if (it < 0) source.length else it }
                    index = end
                }
                continue
            }
            val quote = source[index]
            if (quote == '\'' || quote == '"') {
                val start = index
                val startLine = line
                index++
                val value = StringBuilder()
                while (index < source.length) {
                    val char = source[index++]
                    if (char == '\n') line++
                    if (char == quote) break
                    if (char == '\\' && index < source.length) {
                        val escaped = source[index++]
                        value.append(decodeEscape(escaped))
                    } else {
                        value.append(char)
                    }
                }
                result += LuaStringToken(start, index, value.toString(), startLine)
                continue
            }
            val longString = longBracket(source, index)
            if (longString != null) {
                val startLine = line
                val contentStart = longString.first
                val end = longString.second
                val value = source.substring(contentStart, end - longString.third.length)
                    .removePrefix("\r\n")
                    .removePrefix("\n")
                line += source.substring(index, end).count { it == '\n' }
                result += LuaStringToken(index, end, value, startLine)
                index = end
                continue
            }
            if (source[index] == '\n') line++
            index++
        }
        return result
    }

    private fun longBracket(source: String, start: Int): Triple<Int, Int, String>? {
        if (start >= source.length || source[start] != '[') return null
        var cursor = start + 1
        while (cursor < source.length && source[cursor] == '=') cursor++
        if (cursor >= source.length || source[cursor] != '[') return null
        val close = "]" + "=".repeat(cursor - start - 1) + "]"
        val contentStart = cursor + 1
        val closeStart = source.indexOf(close, contentStart)
        if (closeStart < 0) return Triple(contentStart, source.length, "")
        return Triple(contentStart, closeStart + close.length, close)
    }

    private fun maskComments(source: String, mask: CharArray) {
        var index = 0
        while (index < source.length - 1) {
            if (source[index] == '-' && source[index + 1] == '-') {
                val longComment = longBracket(source, index + 2)
                val end = longComment?.second
                    ?: source.indexOf('\n', index).let { if (it < 0) source.length else it }
                for (cursor in index until end.coerceAtMost(mask.size)) mask[cursor] = ' '
                index = end
            } else index++
        }
    }

    private fun relativeGamePath(path: String, root: String): String? {
        if (root.isBlank()) return path
        if (path.equals(root, ignoreCase = true)) return null
        val prefix = "$root/"
        return path.takeIf { it.startsWith(prefix, ignoreCase = true) }?.substring(prefix.length)
    }

    private fun isGameLuaPath(relativePath: String, hasExplicitModRoot: Boolean): Boolean {
        if (!relativePath.endsWith(".lua", ignoreCase = true)) return false
        val parts = relativePath.lowercase(Locale.ROOT).split('/')
        if (parts.any { it in excludedDirectories }) return false
        if (!hasExplicitModRoot && parts.firstOrNull() in setOf("src", "engine", "runtime")) return false
        return true
    }

    private fun isVisibleNamePath(path: String): Boolean {
        val normalized = path.lowercase(Locale.ROOT)
        return VISIBLE_NAME_PATHS.any(normalized::contains)
    }

    private fun isControlOnly(value: String): Boolean = CONTROL_ONLY.matches(value.trim())

    private fun safePath(path: String): String? {
        val normalized = normalizePath(path).trimStart('/')
        if (normalized.isBlank() || normalized.length > 1_024 || ':' in normalized) return null
        if (normalized.split('/').any { it == ".." }) return null
        return normalized
    }

    private fun normalizePath(path: String): String = path.replace('\\', '/').replace(Regex("/+"), "/")

    private fun sanitizeFolderName(value: String): String = value
        .replace(Regex("[^A-Za-z0-9_.-]"), "_")
        .trim('_', '.')
        .ifBlank { throw IllegalArgumentException("Invalid mod ID") }

    private fun readLimited(input: java.io.InputStream, limit: Int): ByteArray {
        val output = ByteArrayOutputStream(minOf(limit, 64 * 1024))
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            total += read
            require(total <= limit) { "Lua file exceeds the translation scan limit" }
            output.write(buffer, 0, read)
        }
        return output.toByteArray()
    }

    internal fun sha256(bytes: ByteArray): String = digest("SHA-256", bytes)
    private fun sha1(bytes: ByteArray): String = digest("SHA-1", bytes)
    private fun digest(algorithm: String, bytes: ByteArray): String =
        MessageDigest.getInstance(algorithm).digest(bytes).joinToString("") { "%02x".format(it) }

    private fun decodeEscape(value: Char): Char = when (value) {
        'n' -> '\n'
        'r' -> '\r'
        't' -> '\t'
        else -> value
    }

    private data class LuaStringToken(val start: Int, val end: Int, val value: String, val line: Int)
    private data class CallContext(val name: String, val argumentIndex: Int)

    private val FIELD_ASSIGNMENT = Regex("(?:self\\.)?([A-Za-z_][A-Za-z0-9_]*)\\s*=\\s*$")
    private val CALL_NAME = Regex("([A-Za-z_][A-Za-z0-9_.:]*)\\s*$")
    private val MAP_TEXT_FIELD = Regex("(?:text|dialogue|message)(?:\\d+(?:_\\d+)*)?", RegexOption.IGNORE_CASE)
    private val CONTROL_ONLY = Regex("""^(?:\s*\[[^]]+]\s*)+$""")
    private val VISIBLE_NAME_PATHS = listOf(
        "scripts/battle/enemies/", "scripts/data/items/", "scripts/data/spells/",
        "scripts/data/party/", "scripts/shops/"
    )
}
