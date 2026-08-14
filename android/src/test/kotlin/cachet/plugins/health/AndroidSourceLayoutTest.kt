package cachet.plugins.health

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidSourceLayoutTest {
    @Test
    fun kotlinSourceFilesStayUnderThreeHundredLines() {
        val sourceRoot = File("src")
        val offenders = sourceRoot
            .walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            .mapNotNull { file ->
                val lineCount = file.readLines().size
                if (lineCount > 300) "${file.path}: $lineCount" else null
            }
            .toList()

        assertTrue(
            "Kotlin files must be 300 lines or less. Offenders: $offenders",
            offenders.isEmpty(),
        )
    }
}
