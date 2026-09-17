package kwz.love2d.launcher.util

/** Central validation for identifiers that cross package, storage, preference, or runtime boundaries. */
object IdentifierPolicy {
    private val patchId = Regex("^[a-z0-9]+(?:[._-][a-z0-9]+)+$")
    private val translationId = Regex("^[a-z0-9](?:[a-z0-9._-]{1,94}[a-z0-9])?$")
    private val gameProjectId = Regex("^[A-Za-z0-9](?:[A-Za-z0-9._-]{0,94}[A-Za-z0-9])?$")
    private val localProjectId = Regex("^[a-f0-9]{24}$")
    private val translationEntryId = Regex("^[a-f0-9]{12}$")
    private val packageVersion = Regex(
        "^[0-9]+(?:\\.[0-9]+){0,3}(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?(?:\\+[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?$"
    )
    private val sha256 = Regex("^[a-fA-F0-9]{64}$")
    private val languageTag = Regex("^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$")

    fun isPatchId(value: String): Boolean = value.length in 3..120 && patchId.matches(value)
    fun isTranslationId(value: String): Boolean = translationId.matches(value)
    fun isGameProjectId(value: String): Boolean = gameProjectId.matches(value)
    fun isLocalProjectId(value: String): Boolean = localProjectId.matches(value)
    fun isTranslationEntryId(value: String): Boolean = translationEntryId.matches(value)
    fun isPackageVersion(value: String): Boolean = value.length <= 64 && packageVersion.matches(value)
    fun isSha256(value: String): Boolean = sha256.matches(value)
    fun isLanguageTag(value: String): Boolean = value.length <= 32 && languageTag.matches(value)

    fun requirePatchId(value: String, label: String = "Patch ID"): String {
        require(isPatchId(value)) { "$label is invalid" }
        return value
    }

    fun requireTranslationId(value: String, label: String = "Translation ID"): String {
        require(isTranslationId(value)) { "$label is invalid" }
        return value
    }

    fun requireLocalProjectId(value: String): String {
        require(isLocalProjectId(value)) { "Translation project ID is invalid" }
        return value
    }

    fun requireTranslationEntryId(value: String): String {
        require(isTranslationEntryId(value)) { "Translation entry ID is invalid" }
        return value
    }

    fun requirePackageVersion(value: String, label: String = "Package version"): String {
        require(isPackageVersion(value)) { "$label is invalid" }
        return value
    }
}
