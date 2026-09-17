package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.CommunityTranslationFile
import kwz.love2d.launcher.model.CommunityTranslationManifest
import kwz.love2d.launcher.model.LocalizedText
import org.json.JSONObject

object CommunityTranslationManifestParser {
    fun parse(json: String, requireFiles: Boolean = true): CommunityTranslationManifest =
        parse(JSONObject(json), requireFiles)

    fun parse(root: JSONObject, requireFiles: Boolean = true): CommunityTranslationManifest {
        require(root.optInt("schemaVersion", -1) == 1) { "Unsupported translation package version" }
        val id = root.requiredString("id")
        IdentifierPolicy.requireTranslationId(id)
        val version = root.requiredString("version")
        IdentifierPolicy.requirePackageVersion(version, "Translation version")
        val gameProjectId = root.requiredString("gameProjectId")
        require(IdentifierPolicy.isGameProjectId(gameProjectId)) { "Invalid game project ID" }
        val targetLanguage = root.requiredString("targetLanguage").replace('_', '-')
        require(IdentifierPolicy.isLanguageTag(targetLanguage)) { "Invalid target language" }
        val sourceLanguage = root.optString("sourceLanguage", "en").trim().replace('_', '-')
        require(IdentifierPolicy.isLanguageTag(sourceLanguage)) { "Invalid source language" }

        val textsFile = root.optString("textsFile", "").trim().takeIf(String::isNotBlank)
        val textsSha256 = root.optString("textsSha256", "").trim().takeIf(String::isNotBlank)
        if (textsFile != null) {
            require(textsFile == "texts.json" && PatchManifestParser.isSafeArchivePath(textsFile)) {
                "Invalid translation text payload path"
            }
            require(textsSha256 != null && IdentifierPolicy.isSha256(textsSha256)) {
                "Invalid translation text payload checksum"
            }
        } else {
            require(textsSha256 == null) { "Translation text checksum has no payload" }
        }
        val filesArray = root.optJSONArray("files")
        if (requireFiles) require(textsFile != null || (filesArray != null && filesArray.length() > 0)) {
            "Translation package does not contain text replacements"
        }
        require((filesArray?.length() ?: 0) <= 512) { "Translation package contains too many files" }
        val targets = mutableSetOf<String>()
        val files = buildList {
            if (filesArray != null) for (index in 0 until filesArray.length()) {
                val item = filesArray.getJSONObject(index)
                val source = item.requiredString("source")
                val target = item.requiredString("target")
                require(PatchManifestParser.isSafeArchivePath(source) && source.startsWith("payload/")) {
                    "Invalid translation payload path"
                }
                require(isSafeGameTarget(target)) { "Translation target is outside game scripts: $target" }
                require(targets.add(target.lowercase())) { "Duplicate translation target: $target" }
                val sourceSha256 = item.requiredString("sourceSha256")
                val translatedSha256 = item.requiredString("translatedSha256")
                require(IdentifierPolicy.isSha256(sourceSha256) && IdentifierPolicy.isSha256(translatedSha256)) {
                    "Invalid translation file checksum"
                }
                add(
                    CommunityTranslationFile(
                        source = source,
                        target = target,
                        sourceSha256 = sourceSha256.lowercase(),
                        translatedSha256 = translatedSha256.lowercase()
                    )
                )
            }
        }

        val minimumLauncherVersion = root.optString("minimumLauncherVersion", "")
            .trim()
            .takeIf(String::isNotBlank)
        minimumLauncherVersion?.let {
            IdentifierPolicy.requirePackageVersion(it, "Minimum launcher version")
        }
        return CommunityTranslationManifest(
            schemaVersion = 1,
            id = id,
            version = version,
            name = parseLocalized(root.opt("name"), "Translation name"),
            description = parseLocalized(root.opt("description"), "Translation description"),
            author = root.requiredString("author").take(120),
            gameProjectId = gameProjectId,
            gameVersion = root.requiredString("gameVersion").also {
                require(it.length <= 64 && it.none(Char::isISOControl)) { "Invalid game version" }
            },
            sourceLanguage = sourceLanguage,
            targetLanguage = targetLanguage,
            minimumLauncherVersion = minimumLauncherVersion,
            textsFile = textsFile,
            textsSha256 = textsSha256?.lowercase(),
            files = files
        )
    }

    private fun parseLocalized(value: Any?, label: String): LocalizedText {
        val values = linkedMapOf<String, String>()
        when (value) {
            is String -> if (value.isNotBlank()) values["en"] = value.trim()
            is JSONObject -> value.keys().forEach { locale ->
                val text = value.optString(locale, "").trim()
                if (text.isNotBlank()) values[locale] = text.take(2_000)
            }
        }
        require(values.isNotEmpty()) { "$label is missing" }
        return LocalizedText(values)
    }

    private fun isSafeGameTarget(path: String): Boolean {
        if (!PatchManifestParser.isSafeArchivePath(path)) return false
        val normalized = path.replace('\\', '/').trimStart('/').lowercase()
        return normalized.startsWith("scripts/") && normalized.endsWith(".lua")
    }

    private fun JSONObject.requiredString(name: String): String =
        (opt(name) as? String)?.trim()?.takeIf(String::isNotBlank)
            ?: throw IllegalArgumentException("Missing or invalid $name")
}
