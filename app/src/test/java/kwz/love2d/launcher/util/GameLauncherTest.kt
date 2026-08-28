package kwz.love2d.launcher.util

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GameLauncherTest {

    @Test
    fun preservesZipHeaderWhenExtractingFusedExecutablePayload() {
        val zipPayload = byteArrayOf(0x50, 0x4B, 0x03, 0x04, 0x10, 0x20, 0x30)
        val executable = byteArrayOf(0x4D, 0x5A, 0x01, 0x02) + zipPayload

        val extracted = GameLauncher.findExecutablePayload(executable.inputStream())

        assertArrayEquals(zipPayload, extracted?.readBytes())
    }

    @Test
    fun rejectsExecutableWithoutEmbeddedZip() {
        assertNull(GameLauncher.findExecutablePayload(byteArrayOf(0x4D, 0x5A).inputStream()))
    }
}
