package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.LocalizedText
import kwz.love2d.launcher.model.PatchManifest
import kwz.love2d.launcher.model.PatchOperation
import org.json.JSONArray
import org.json.JSONObject

object PatchManifestParser {

    const val SUPPORTED_SCHEMA_VERSION = 1
    private const val MAX_OPERATIONS = 128
    private const val MAX_TEXT_LENGTH = 64 * 1024
    private val supportedOperations = setOf("inject", "append_text", "replace_text")

    fun parse(json: String, requireOperations: Boolean = true): PatchManifest {
        return parse(JSONObject(json), requireOperations)
    }

    fun parse(root: JSONObject, requireOperations: Boolean = true): PatchManifest {
        val schemaVersion = root.optInt("schemaVersion", -1)
        require(schemaVersion == SUPPORTED_SCHEMA_VERSION) {
            "Unsupported patch schema version: $schemaVersion"
        }

        val id = root.requireShortString("id", 120)
        IdentifierPolicy.requirePatchId(id, "Patch identifier")

        val version = root.requireShortString("version", 64)
        IdentifierPolicy.requirePackageVersion(version, "Patch version")
        val name = parseLocalizedText(root, "name")
        val description = parseLocalizedText(root, "description")
        val useCases = parseLocalizedTextList(root.optJSONArray("useCases"))
        val author = root.requireShortString("author", 160)
        val category = root.optString("category", "compatibility").trim().ifBlank { "compatibility" }
        require(category.length <= 80) { "Patch category is too large" }
        val compatibleGameProjectIds = parseStringList(root.optJSONArray("compatibleGameProjectIds"))
        require(compatibleGameProjectIds.all(IdentifierPolicy::isGameProjectId)) {
            "Invalid compatible game project identifier"
        }
        val minimumLauncherVersion = root.optString("minimumLauncherVersion", "")
            .trim()
            .takeIf { it.isNotBlank() }
        minimumLauncherVersion?.let {
            IdentifierPolicy.requirePackageVersion(it, "Minimum launcher version")
        }

        val capabilities = parseStringList(root.optJSONArray("capabilities"))
        val dependencies = parseStringList(root.optJSONArray("dependencies"))
        val conflicts = parseStringList(root.optJSONArray("conflicts"))
        require(dependencies.all(IdentifierPolicy::isPatchId)) { "Invalid patch dependency identifier" }
        require(conflicts.all(IdentifierPolicy::isPatchId)) { "Invalid patch conflict identifier" }
        val priority = root.optInt("priority", 100).coerceIn(-10_000, 10_000)
        val operations = parseOperations(root.optJSONArray("operations"))

        if (requireOperations) {
            require(operations.isNotEmpty()) { "The patch does not declare any operations" }
        }

        return PatchManifest(
            schemaVersion = schemaVersion,
            id = id,
            version = version,
            name = name,
            description = description,
            useCases = useCases,
            author = author,
            category = category,
            compatibleGameProjectIds = compatibleGameProjectIds,
            minimumLauncherVersion = minimumLauncherVersion,
            capabilities = capabilities,
            dependencies = dependencies,
            conflicts = conflicts,
            priority = priority,
            operations = operations
        )
    }

    fun isSafeArchivePath(path: String): Boolean {
        val normalized = path.trimEnd('/')
        if (normalized.isBlank() || path.length > 240) return false
        if (normalized.startsWith('/') || normalized.startsWith('\\') || normalized.contains('\\') || normalized.contains(':')) return false
        val segments = normalized.split('/')
        return segments.none { it.isBlank() || it == "." || it == ".." }
    }

    private fun parseLocalizedText(root: JSONObject, key: String): LocalizedText {
        val value = root.opt(key) ?: throw IllegalArgumentException("Missing field: $key")
        val values = linkedMapOf<String, String>()
        when (value) {
            is String -> values["en"] = value.trim()
            is JSONObject -> value.keys().forEach { locale ->
                val text = value.optString(locale, "").trim()
                if (text.isNotBlank()) values[locale] = text
            }
            else -> throw IllegalArgumentException("Field $key must be a string or localized object")
        }
        require(values.isNotEmpty()) { "Field $key cannot be empty" }
        require(values.values.all { it.length <= MAX_TEXT_LENGTH }) { "Field $key is too large" }
        return LocalizedText(values)
    }

    private fun parseOperations(array: JSONArray?): List<PatchOperation> {
        if (array == null) return emptyList()
        require(array.length() <= MAX_OPERATIONS) { "Too many patch operations" }

        return buildList {
            for (index in 0 until array.length()) {
                val operation = array.getJSONObject(index)
                val type = operation.requireShortString("type", 40)
                require(type in supportedOperations) { "Unsupported patch operation: $type" }

                val target = operation.requireShortString("target", 240)
                require(isSafeArchivePath(target) && !target.endsWith('/')) { "Unsafe patch target: $target" }

                val source = operation.optString("source", "").trim().takeIf { it.isNotBlank() }
                if (type == "inject" || type == "append_text") {
                    require(source != null && isSafeArchivePath(source) && !source.endsWith('/') && source.startsWith("payload/")) {
                        "Operation $type requires a safe source under payload/"
                    }
                }

                val find = operation.optString("find", "").takeIf { it.isNotEmpty() }
                val replace = if (operation.has("replace")) operation.optString("replace", "") else null
                if (type == "replace_text") {
                    require(find != null && replace != null) {
                        "replace_text requires find and replace values"
                    }
                    require(find.length <= MAX_TEXT_LENGTH && replace.length <= MAX_TEXT_LENGTH) {
                        "replace_text content is too large"
                    }
                }

                add(
                    PatchOperation(
                        type = type,
                        source = source,
                        target = target,
                        find = find,
                        replace = replace,
                        replaceExisting = operation.optBoolean("replaceExisting", false),
                        required = operation.optBoolean("required", true)
                    )
                )
            }
        }
    }

    private fun parseLocalizedTextList(array: JSONArray?): List<LocalizedText> {
        if (array == null) return emptyList()
        require(array.length() <= 16) { "Too many patch use cases" }
        return buildList {
            for (index in 0 until array.length()) {
                val wrapper = JSONObject().put("value", array.get(index))
                add(parseLocalizedText(wrapper, "value"))
            }
        }
    }

    private fun parseStringList(array: JSONArray?): List<String> {
        if (array == null) return emptyList()
        require(array.length() <= 64) { "List contains too many items" }
        return buildList {
            for (index in 0 until array.length()) {
                val value = array.getString(index).trim()
                require(value.length <= 160) { "List item is too large" }
                if (value.isNotBlank()) add(value)
            }
        }.distinct()
    }

    private fun JSONObject.requireShortString(key: String, maxLength: Int): String {
        val raw = opt(key)
        require(raw is String) { "Field $key must be text" }
        val value = raw.trim()
        require(value.isNotBlank()) { "Missing field: $key" }
        require(value.length <= maxLength) { "Field $key is too large" }
        return value
    }
}
