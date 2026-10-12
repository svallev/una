package invalid.pending.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** CA-019-16, CL-019-13 a 15: la etiqueta de la tarea actual, sobre la implementación real. */
class TaskLabelTest {
    private fun label(task: TaskSnapshot, splitter: GraphemeSplitter = TestGraphemeSplitter) =
        TaskLabel.of(task, splitter)

    private fun text(body: String?, vararg rows: AttachmentSnapshot) = TaskSnapshot(body, rows.toList())

    private fun expect(spec: String): TaskLabel? =
        when {
            spec == "none" -> null
            spec == "photo" -> TaskLabel.Photo
            spec == "image" -> TaskLabel.Image
            spec == "pdf" -> TaskLabel.Pdf
            spec.startsWith("text:") -> TaskLabel.Text(Fixtures.unescape(spec.removePrefix("text:")))
            spec.startsWith("domain:") -> TaskLabel.Domain(Fixtures.unescape(spec.removePrefix("domain:")))
            else -> error("esperado desconocido: $spec")
        }

    private fun attachments(raw: String): List<AttachmentSnapshot> =
        if (raw == "-") {
            emptyList()
        } else {
            raw.split(" | ").map {
                val (kind, origin, url) = it.split(",", limit = 3)
                AttachmentSnapshot(Fixtures.nullable(kind), Fixtures.nullable(origin), Fixtures.nullable(url))
            }
        }

    @Test
    fun `CA-019-16 labels txt - cada caso`() {
        val cases = Fixtures.cases("labels.txt", 4)
        assertTrue("faltan casos", cases.size > 40)
        for (case in cases) {
            val (name, body, rows, expected) = case.columns
            val task = TaskSnapshot(Fixtures.nullable(body), attachments(rows))
            assertEquals("$case $name", expect(expected), label(task))
        }
    }

    // --- El recorte: 120 letras completas y «…» ---

    @Test
    fun `CA-019-16 120 letras exactas no llevan puntos suspensivos`() {
        val body = "a".repeat(120)
        assertEquals(TaskLabel.Text(body), label(text(body)))
    }

    @Test
    fun `CA-019-16 121 letras se recortan a 120 mas puntos suspensivos`() {
        val body = "a".repeat(120) + "b"
        assertEquals(TaskLabel.Text("a".repeat(120) + "…"), label(text(body)))
    }

    @Test
    fun `CL-019-13 un texto de 10000 caracteres sale en 120 letras`() {
        val body = "Palabra ".repeat(1250)
        assertEquals(10_000, body.length)
        val result = label(text(body)) as TaskLabel.Text
        assertEquals(121, result.value.length)
        assertTrue(result.value.endsWith("…"))
        assertEquals(body.trim().take(120), result.value.dropLast(1))
    }

    @Test
    fun `CL-019-13 un texto de 10000 caracteres con saltos de linea sale sin saltos`() {
        val body = "linea\n".repeat(1700)
        val result = label(text(body)) as TaskLabel.Text
        assertFalse(result.value.contains('\n'))
        assertEquals(121, result.value.length)
    }

    @Test
    fun `CL-019-13 el recorte cuenta letras completas, no unidades UTF-16`() {
        // 120 emojis fuera del plano básico (2 unidades cada uno): caben los 120.
        val grin = "\uD83D\uDE00"
        assertEquals(TaskLabel.Text(grin.repeat(120)), label(text(grin.repeat(120))))
        assertEquals(TaskLabel.Text(grin.repeat(120) + "…"), label(text(grin.repeat(121))))
    }

    @Test
    fun `CL-019-13 no parte un emoji con ZWJ en la frontera del recorte`() {
        // Familia: \uD83D\uDC68\u200D\uD83D\uDC69\u200D\uD83D\uDC67 = 3 emojis unidos con ZWJ (una sola letra para el separador).
        val family = "\uD83D\uDC68\u200D\uD83D\uDC69\u200D\uD83D\uDC67"
        val body = "a".repeat(119) + family + "b"
        val result = label(text(body)) as TaskLabel.Text
        assertEquals("a".repeat(119) + family + "…", result.value)
        // Y desplazado una letra: la familia ya no cabe y se descarta entera.
        val shifted = "a".repeat(120) + family
        assertEquals(TaskLabel.Text("a".repeat(120) + "…"), label(text(shifted)))
    }

    @Test
    fun `CL-019-13 no separa una letra de su acento ni una bandera`() {
        val eAcute = "e\u0301" // e + acento combinado
        val flag = "\uD83C\uDDEA\uD83C\uDDF8" // bandera de España
        val body = "a".repeat(119) + eAcute + flag
        assertEquals(TaskLabel.Text("a".repeat(119) + eAcute + "…"), label(text(body)))
        val body2 = "a".repeat(119) + flag + "z"
        assertEquals(TaskLabel.Text("a".repeat(119) + flag + "…"), label(text(body2)))
    }

    @Test
    fun `CL-019-13 un separador que corta un par sustituto no lo deja partido`() {
        // Un separador defectuoso que corta en mitad de un par: el texto nunca acaba en media pareja.
        val broken =
            object : GraphemeSplitter {
                override fun boundaries(text: String) = IntArray(text.length + 1) { it }
            }
        val grin = "\uD83D\uDE00"
        // Con una «a» delante, la unidad 120 cae entre las dos mitades de un par.
        val result = label(text("a" + grin.repeat(100)), broken) as TaskLabel.Text
        assertFalse(Character.isHighSurrogate(result.value.dropLast(1).last()))
        assertEquals("…", result.value.takeLast(1))
    }

    @Test
    fun `CL-019-13 escritura de derecha a izquierda se deja tal cual`() {
        val arabic = "مرحبا" // marhaba
        assertEquals(TaskLabel.Text(arabic), label(text(arabic)))
    }

    @Test
    fun `CA-019-16 un texto corto no necesita separar letras`() {
        var calls = 0
        val spy =
            object : GraphemeSplitter {
                override fun boundaries(text: String): IntArray {
                    calls++
                    return TestGraphemeSplitter.boundaries(text)
                }
            }
        assertEquals(TaskLabel.Text("Hola"), label(text("Hola"), spy))
        assertTrue(calls <= 1)
    }

    @Test
    fun `CA-019-16 una tarea sin texto no usa el separador`() {
        val never =
            object : GraphemeSplitter {
                override fun boundaries(text: String): IntArray = error("no debe llamarse")
            }
        assertEquals(TaskLabel.Photo, label(text(null, AttachmentSnapshot("image", "camera", null)), never))
    }

    @Test
    fun `CA-019-16 sin texto ni adjuntos no hay etiqueta`() {
        assertNull(label(text(null)))
    }

    @Test
    fun `CA-019-16 el dominio sale entero, sin www, y el texto manda aun en una web`() {
        val web = AttachmentSnapshot("web", "url", "https://www.example.com/a")
        assertEquals(TaskLabel.Domain("example.com"), label(text(null, web)))
        assertEquals(TaskLabel.Text("Leer esto"), label(text("Leer esto", web)))
    }

    @Test
    fun `CL-019-14 la etiqueta no depende de que el archivo exista`() {
        // La etiqueta solo mira tipo y origen: nada de rutas, anchos ni estado de la foto.
        assertEquals(TaskLabel.Photo, label(text(null, AttachmentSnapshot("image", "camera", "ruta/que/no/existe.jpg"))))
    }
}
