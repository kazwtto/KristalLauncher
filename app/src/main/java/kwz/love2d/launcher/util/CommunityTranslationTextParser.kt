package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.TranslationReplacement
import org.json.JSONObject

/** Parses text-only community packages. No Lua source file is accepted here. */
object CommunityTranslationTextParser {
    private const val MAX_ENTRIES = 50_000
    private const val MAX_OFFSET = 2 * 1024 * 1024
    private const val MAX_TEXT_LENGTH = 128 * 1024

    fun parse(json: String): Map<String, List<TranslationReplacement>> {
        val root = JSONObject(json)
        require(root.length() in 1..MAX_ENTRIES) { "Translation text entry count is invalid" }
        val byPath = linkedMapOf<String, MutableList<TranslationReplacement>>()
        val ids = root.keys()
        while (ids.hasNext()) {
            val id = ids.next()
            IdentifierPolicy.requireTranslationEntryId(id)
            val item = root.optJSONObject(id)
                ?: throw IllegalArgumentException("Translation entry must be an object: $id")
            val file = item.requiredString("file").replace('\\', '/')
            require(PatchManifestParser.isSafeArchivePath(file)) { "Unsafe translation target: $file" }
            require(file.startsWith("scripts/") && file.endsWith(".lua")) {
                "Translation target is outside game scripts: $file"
            }
            val fileHash = item.requiredString("fileHash").lowercase()
            require(IdentifierPolicy.isSha256(fileHash)) { "Invalid source hash for $id" }
            val start = item.optInt("startOffset", -1)
            val end = item.optInt("endOffset", -1)
            require(start in 0..MAX_OFFSET && end in (start + 1)..MAX_OFFSET) {
                "Invalid source range for $id"
            }
            val source = item.requiredText("source")
            val translation = item.requiredText("translation", allowBlank = true)
            val originalExpression = item.requiredText("originalExpression")
            val replacementExpression = item.requiredText("replacementExpression")
            require(source.length <= MAX_TEXT_LENGTH && translation.length <= MAX_TEXT_LENGTH) {
                "Translation text is too large: $id"
            }
            require(originalExpression.length <= MAX_TEXT_LENGTH && replacementExpression.length <= MAX_TEXT_LENGTH) {
                "Translation expression is too large: $id"
            }
            require(TranslationManager.validationError(source, translation) == null) {
                "Translation changed placeholders or control tags: $id"
            }
            byPath.getOrPut(file.lowercase()) { mutableListOf() }.add(
                TranslationReplacement(
                    id, fileHash, start, end, source, translation,
                    originalExpression, replacementExpression
                )
            )
        }
        byPath.values.forEach { entries ->
            require(entries.map { it.entryId }.toSet().size == entries.size)
            entries.sortedBy { it.startOffset }.zipWithNext().forEach { (left, right) ->
                require(right.startOffset >= left.endOffset) {
                    "Overlapping translation entries: ${left.entryId} and ${right.entryId}"
                }
            }
        }
        return byPath
    }

    private fun JSONObject.requiredString(name: String): String =
        (opt(name) as? String)?.trim()?.takeIf(String::isNotBlank)
            ?: throw IllegalArgumentException("Missing or invalid $name")

    private fun JSONObject.requiredText(name: String, allowBlank: Boolean = false): String {
        val value = opt(name) as? String
            ?: throw IllegalArgumentException("Missing or invalid $name")
        require(allowBlank || value.isNotBlank()) { "Missing or invalid $name" }
        return value
    }
}
