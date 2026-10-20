package kwz.love2d.launcher.util

import kwz.love2d.launcher.model.CommunityTranslationFont
import org.json.JSONObject
import java.io.File

/** Bounded bitmap assets only; translation fonts cannot inject scripts or arbitrary files. */
object TranslationFonts {
    fun read(directory: File, fonts: List<CommunityTranslationFont>): Map<String, ByteArray> =
        fonts.associate { font ->
            require(font.source in setOf("fonts/plain.png", "fonts/plain.json")) { "Invalid translation font path" }
            val file = CommunityTranslationStorage.safeChild(directory, font.source)
            require(file.isFile && file.length() in 1..1_048_576) { "Invalid translation font size" }
            val bytes = file.readBytes()
            require(TranslationExtractor.sha256(bytes) == font.sha256) { "Translation font checksum mismatch" }
            if (font.source.endsWith(".json")) {
                val settings = JSONObject(bytes.toString(Charsets.UTF_8))
                require(settings.getString("glyphs").length in 1..4096) { "Invalid font glyph mapping" }
                require(settings.optInt("lineSpacing", 20) in 1..256) { "Invalid font line spacing" }
                require(!settings.has("fallbacks")) { "Translation font cannot reference undeclared fonts" }
            } else {
                val signature = byteArrayOf(137.toByte(), 80, 78, 71, 13, 10, 26, 10)
                require(bytes.size >= 24 && bytes.copyOfRange(0, 8).contentEquals(signature)) { "Invalid bitmap font image" }
                val dimensions = java.nio.ByteBuffer.wrap(bytes, 16, 8)
                val width = dimensions.int
                val height = dimensions.int
                require(width in 1..32768 && height in 1..128 && width.toLong() * height <= 2_097_152) {
                    "Bitmap font dimensions exceed the supported size"
                }
            }
            font.source.removePrefix("fonts/") to bytes
        }
}
