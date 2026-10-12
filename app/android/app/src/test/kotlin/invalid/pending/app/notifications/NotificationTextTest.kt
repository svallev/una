package invalid.pending.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * CA-019-16, 17, 21 y 23: los textos de la notificación con los textos nativos **reales**
 * (`ResourceStrings` lee los `strings.xml` generados de los ARB).
 */
class NotificationTextTest {
    private val es = listOf("es-ES")
    private val en = listOf("en-US")

    private fun build(
        display: Display,
        choice: LanguageChoice = LanguageChoice.SYSTEM,
        tags: List<String> = es,
    ) = NotificationText.build(display, choice, tags, ResourceStrings)

    // --- Qué dice cada pieza ---

    @Test
    fun `CA-019-16 la completa lleva el titulo, la etiqueta de la tarea y la version publica generica`() {
        val text = build(Display.Full(TaskLabel.Text("Llamar a Marta")))
        assertEquals("Tarea actual", text.title.text)
        assertEquals("Llamar a Marta", text.body.text)
        assertEquals("Tarea actual", text.publicTitle.text)
        assertEquals("Tienes una tarea pendiente.", text.publicBody.text)
    }

    @Test
    fun `CA-019-16 Foto, Imagen y PDF salen en el idioma de la app`() {
        assertEquals("Foto", build(Display.Full(TaskLabel.Photo)).body.text)
        assertEquals("Imagen", build(Display.Full(TaskLabel.Image)).body.text)
        assertEquals("PDF", build(Display.Full(TaskLabel.Pdf)).body.text)
        assertEquals("Photo", build(Display.Full(TaskLabel.Photo), tags = en).body.text)
        assertEquals("Image", build(Display.Full(TaskLabel.Image), tags = en).body.text)
        assertEquals("PDF", build(Display.Full(TaskLabel.Pdf), tags = en).body.text)
    }

    @Test
    fun `CA-019-16 el dominio se deja tal cual, en cualquier idioma`() {
        assertEquals("example.com", build(Display.Full(TaskLabel.Domain("example.com"))).body.text)
        assertEquals("example.com", build(Display.Full(TaskLabel.Domain("example.com")), tags = en).body.text)
    }

    @Test
    fun `CA-019-16 la generica dice lo mismo en el cuerpo que la version publica`() {
        val text = build(Display.Generic)
        assertEquals("Tarea actual", text.title.text)
        assertEquals("Tienes una tarea pendiente.", text.body.text)
        assertEquals(text.publicBody, text.body)
        assertEquals(text.publicTitle, text.title)
    }

    // --- La versión pública ---

    @Test
    fun `CA-019-17 la version publica no lleva ninguna parte de la etiqueta`() {
        val secret = "SECRETO-7 www.ejemplo.test"
        for (label in listOf(
            TaskLabel.Text(secret),
            TaskLabel.Domain("ejemplo.test"),
            TaskLabel.Photo,
            TaskLabel.Image,
            TaskLabel.Pdf,
        )) {
            for (tags in listOf(es, en)) {
                val text = build(Display.Full(label), tags = tags)
                val generic = build(Display.Generic, tags = tags)
                assertEquals(generic.title.text, text.publicTitle.text)
                assertEquals(generic.body.text, text.publicBody.text)
                val full = text.body.text
                for (piece in listOf(text.publicTitle.text, text.publicBody.text)) {
                    assertFalse("$piece contiene $full", piece.contains(full))
                }
            }
        }
    }

    @Test
    fun `CA-019-17 la generica no contiene el texto de ninguna tarea`() {
        val text = build(Display.Generic)
        assertFalse(text.toString().contains("SECRETO"))
    }

    // --- Idioma y marca ---

    @Test
    fun `CA-019-21 con el idioma de la app igual al primero del sistema nada lleva marca`() {
        val text = build(Display.Full(TaskLabel.Photo), tags = es)
        for (p in listOf(text.title, text.body, text.publicTitle, text.publicBody)) {
            assertEquals(AppLanguage.ES, p.language)
            assertFalse(p.text, p.marked)
        }
    }

    @Test
    fun `CA-019-21 con otro idioma, titulo, etiqueta fija y version publica llevan marca`() {
        val text = build(Display.Full(TaskLabel.Pdf), choice = LanguageChoice.ES, tags = en)
        for (p in listOf(text.title, text.body, text.publicTitle, text.publicBody)) {
            assertEquals(p.text, AppLanguage.ES, p.language)
            assertTrue(p.text, p.marked)
        }
    }

    @Test
    fun `CA-019-21 el texto de usuario y el dominio no llevan marca ni idioma`() {
        for (label in listOf(TaskLabel.Text("hola"), TaskLabel.Domain("example.com"))) {
            val text = build(Display.Full(label), choice = LanguageChoice.ES, tags = en)
            assertNull(text.body.language)
            assertFalse(text.body.marked)
            // El resto sigue marcado: es texto fijo de la app.
            assertTrue(text.title.marked)
            assertTrue(text.publicTitle.marked)
            assertTrue(text.publicBody.marked)
        }
    }

    @Test
    fun `CA-019-21 la generica en el cuerpo tambien lleva marca`() {
        val text = build(Display.Generic, choice = LanguageChoice.EN, tags = es)
        assertEquals("You have a task waiting.", text.body.text)
        assertTrue(text.body.marked)
        assertEquals(AppLanguage.EN, text.body.language)
    }

    @Test
    fun `CA-019-21 el idioma elegido en Ajustes distinto del del sistema`() {
        val text = build(Display.Full(TaskLabel.Photo), choice = LanguageChoice.EN, tags = es)
        assertEquals("Current task", text.title.text)
        assertEquals("Photo", text.body.text)
        assertEquals("You have a task waiting.", text.publicBody.text)
        assertTrue(text.title.marked)
    }

    @Test
    fun `CA-019-21 el catalan abre en español y su voz es catalana, asi que se marca`() {
        val text = build(Display.Generic, tags = listOf("ca-ES"))
        assertEquals("Tarea actual", text.title.text)
        assertTrue(text.title.marked)
        assertEquals(AppLanguage.ES, text.title.language)
    }

    @Test
    fun `CA-019-21 el idioma es el del momento de construirla, no uno guardado antes`() {
        val display = Display.Generic
        assertEquals("Tarea actual", build(display, tags = es).title.text)
        assertEquals("Current task", build(display, tags = en).title.text)
    }

    @Test
    fun `una pieza marcada exige idioma`() {
        assertThrows(IllegalArgumentException::class.java) { Piece("x", null, true) }
        Piece("x", null, false)
        Piece("x", AppLanguage.ES, true)
    }
}
