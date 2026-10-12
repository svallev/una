package invalid.pending.app.notifications

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

// Ayudas de las pruebas de la etiqueta y los textos (spec 019, T-019-05). Sin `android.*`.

/** Una línea de un archivo de casos compartido con Dart (`app/test/fixtures/notifications/`). */
data class FixtureCase(val file: String, val line: Int, val columns: List<String>) {
    override fun toString() = "$file:$line"
}

object Fixtures {
    // El directorio de trabajo de las pruebas JVM es el del módulo (`app/android/app`).
    private val dir = File("../../test/fixtures/notifications")

    /** Los casos de [name] (texto plano, columnas separadas por TABULADOR; `#` y vacías se ignoran). */
    fun cases(name: String, columns: Int): List<FixtureCase> {
        val file = File(dir, name)
        require(file.isFile) { "falta ${file.absolutePath}" }
        return file.readLines(Charsets.UTF_8).mapIndexedNotNull { i, line ->
            if (line.isEmpty() || line.startsWith("#")) return@mapIndexedNotNull null
            val parts = line.split("\t")
            require(parts.size == columns) { "$name:${i + 1} no tiene $columns columnas" }
            FixtureCase(name, i + 1, parts)
        }
    }

    private val escape = Regex("""\\(u[0-9a-fA-F]{4}|\\|t|n|r)""")

    /** Desescapa `\uXXXX`, `\\`, `\t`, `\n` y `\r` (el mismo formato que lee Dart). */
    fun unescape(s: String): String =
        escape.replace(s) { m ->
            val e = m.groupValues[1]
            when (e[0]) {
                'u' -> e.substring(1).toInt(16).toChar().toString()
                't' -> "\t"
                'n' -> "\n"
                'r' -> "\r"
                else -> "\\"
            }
        }

    /** `<null>` = `null`; si no, el texto desescapado. */
    fun nullable(s: String): String? = if (s == "<null>") null else unescape(s)
}

/**
 * Separador de letras de las pruebas. En la app es `android.icu.text.BreakIterator`; aquí no hay
 * ICU y `java.text.BreakIterator` de un JDK 17 (el de CI) no une las secuencias con ZWJ, así que
 * este doble cubre lo que importa a la etiqueta: marcas combinadas, selectores de variación,
 * modificadores de color de piel, ZWJ, banderas (pares de indicadores regionales), etiquetas y
 * CR LF. La partición real con ICU se mira en el emulador (T-019-14).
 */
object TestGraphemeSplitter : GraphemeSplitter {
    private const val ZWJ = 0x200D

    override fun boundaries(text: String): IntArray {
        val cuts = mutableListOf(0)
        var i = 0
        while (i < text.length) {
            var cp = text.codePointAt(i)
            var end = i + Character.charCount(cp)
            if (cp == '\r'.code && end < text.length && text[end] == '\n') {
                end++
            } else if (isRegional(cp) && end < text.length && isRegional(text.codePointAt(end))) {
                end += Character.charCount(text.codePointAt(end))
            }
            while (end < text.length) {
                cp = text.codePointAt(end)
                val size = Character.charCount(cp)
                if (cp == ZWJ) {
                    end += size
                    if (end < text.length) end += Character.charCount(text.codePointAt(end))
                } else if (isExtender(cp)) {
                    end += size
                } else {
                    break
                }
            }
            cuts += end
            i = end
        }
        return cuts.toIntArray()
    }

    private fun isRegional(cp: Int) = cp in 0x1F1E6..0x1F1FF

    private fun isExtender(cp: Int): Boolean =
        when (Character.getType(cp)) {
            Character.NON_SPACING_MARK.toInt(),
            Character.ENCLOSING_MARK.toInt(),
            Character.COMBINING_SPACING_MARK.toInt() -> true
            else -> cp in 0x1F3FB..0x1F3FF || cp in 0xE0020..0xE007F
        }
}

/** Los textos nativos **reales**: lee los `strings.xml` que genera `gen_android_strings.dart`. */
object ResourceStrings : NotificationStringSource {
    private val res = File("src/main/res")

    private fun load(folder: String): NotificationStrings {
        val file = File(res, "$folder/notification_strings.xml")
        require(file.isFile) { "falta ${file.absolutePath}" }
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
        val nodes = doc.getElementsByTagName("string")
        val map =
            (0 until nodes.length).associate {
                val n = nodes.item(it)
                n.attributes.getNamedItem("name").nodeValue to n.textContent.replace("\\'", "'")
            }

        fun get(key: String) = requireNotNull(map[key]) { "falta $key en $folder" }
        return NotificationStrings(
            channelName = get("notification_channel_name"),
            channelDescription = get("notification_channel_description"),
            title = get("notification_title"),
            publicText = get("notification_public"),
            photo = get("attachment_photo"),
            image = get("attachment_image"),
            pdf = get("attachment_pdf"),
        )
    }

    private val es = load("values-es")
    private val en = load("values")

    override fun strings(language: AppLanguage): NotificationStrings =
        when (language) {
            AppLanguage.ES -> es
            AppLanguage.EN -> en
        }
}
