package kwz.love2d.launcher.util

object VersionUtils {

    fun isNewer(candidate: String, current: String): Boolean = compare(candidate, current) > 0

    fun compare(left: String, right: String): Int {
        val leftVersion = parse(left)
        val rightVersion = parse(right)
        val maxSize = maxOf(leftVersion.numbers.size, rightVersion.numbers.size)

        for (index in 0 until maxSize) {
            val leftPart = leftVersion.numbers.getOrElse(index) { 0 }
            val rightPart = rightVersion.numbers.getOrElse(index) { 0 }
            if (leftPart != rightPart) return leftPart.compareTo(rightPart)
        }

        if (leftVersion.preRelease == rightVersion.preRelease) return 0
        if (leftVersion.preRelease == null) return 1
        if (rightVersion.preRelease == null) return -1
        return comparePreRelease(leftVersion.preRelease, rightVersion.preRelease)
    }

    private fun parse(raw: String): ParsedVersion {
        val normalized = raw.trim().removePrefix("v").removePrefix("V")
        val withoutBuildMetadata = normalized.substringBefore('+')
        val core = withoutBuildMetadata.substringBefore('-')
        val preRelease = withoutBuildMetadata.substringAfter('-', "").takeIf { it.isNotBlank() }
        val numbers = core.split('.').map { component ->
            component.takeWhile { it.isDigit() }.toIntOrNull() ?: 0
        }
        return ParsedVersion(numbers, preRelease)
    }

    private fun comparePreRelease(left: String, right: String): Int {
        val leftParts = left.split('.')
        val rightParts = right.split('.')
        val maxSize = maxOf(leftParts.size, rightParts.size)

        for (index in 0 until maxSize) {
            val leftPart = leftParts.getOrNull(index) ?: return -1
            val rightPart = rightParts.getOrNull(index) ?: return 1
            val leftNumber = leftPart.toIntOrNull()
            val rightNumber = rightPart.toIntOrNull()
            val comparison = when {
                leftNumber != null && rightNumber != null -> leftNumber.compareTo(rightNumber)
                leftNumber != null -> -1
                rightNumber != null -> 1
                else -> leftPart.compareTo(rightPart, ignoreCase = true)
            }
            if (comparison != 0) return comparison
        }
        return 0
    }

    private data class ParsedVersion(
        val numbers: List<Int>,
        val preRelease: String?
    )
}
