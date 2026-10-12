package invalid.pending.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** CA-019-17, 18 y 22: lo que el `Poster` de Android traduce, construido y comprobado en la JVM. */
class NotificationSpecTest {
    private fun spec(
        display: Display,
        choice: LanguageChoice = LanguageChoice.SYSTEM,
        tags: List<String> = listOf("es-ES"),
    ) = NotificationSpec.build(display, choice, tags, ResourceStrings)

    private val displays =
        listOf(
            Display.Generic,
            Display.Full(TaskLabel.Text("x")),
            Display.Full(TaskLabel.Photo),
            Display.Full(TaskLabel.Domain("example.com")),
        )

    @Test
    fun `CA-019-18 todas usan el mismo identificador`() {
        assertEquals(1, displays.map { spec(it).id }.toSet().size)
        assertEquals(NotificationSpec.ID, spec(Display.Generic).id)
    }

    @Test
    fun `CA-019-18 sin acciones ni insignia`() {
        for (d in displays) {
            val s = spec(d)
            assertTrue(s.actions.isEmpty())
            assertFalse(s.showBadge)
            assertFalse(s.channel.showBadge)
        }
    }

    @Test
    fun `CA-019-22 un solo canal, de importancia por defecto y sin sonido, vibracion ni luz propios`() {
        val channels = displays.map { spec(it).channel }
        assertEquals(1, channels.map { it.id }.toSet().size)
        assertEquals("current_task", channels.first().id)
        for (c in channels) {
            assertEquals(Importance.DEFAULT, c.importance)
            assertFalse(c.sound)
            assertFalse(c.vibration)
            assertFalse(c.lights)
            assertFalse(c.showBadge)
            assertEquals(Visibility.PRIVATE, c.lockscreenVisibility)
        }
    }

    @Test
    fun `CA-019-17 la completa es privada, local y con estilo expandible`() {
        for (d in displays) {
            val s = spec(d)
            assertEquals(Visibility.PRIVATE, s.visibility)
            assertTrue(s.localOnly)
            assertTrue(s.bigText)
        }
    }

    @Test
    fun `CA-019-17 cada notificacion lleva las dos versiones y la publica es la generica`() {
        val full = spec(Display.Full(TaskLabel.Text("SECRETO-7")))
        assertEquals("SECRETO-7", full.text.body.text)
        assertEquals("Tienes una tarea pendiente.", full.text.publicBody.text)
        assertEquals("Tarea actual", full.text.publicTitle.text)
        assertFalse(full.text.publicTitle.text.contains("SECRETO"))
        assertFalse(full.text.publicBody.text.contains("SECRETO"))
        assertEquals(Display.Full(TaskLabel.Text("SECRETO-7")), full.display)
        assertEquals(Display.Generic, spec(Display.Generic).display)
    }

    @Test
    fun `CA-019-21 el nombre y la descripcion del canal van en el idioma del sistema, no en el de la app`() {
        // La app en español (elegido) con el sistema en inglés: el canal, en inglés.
        val s = spec(Display.Generic, choice = LanguageChoice.ES, tags = listOf("en-US"))
        assertEquals("Current task", s.channel.name)
        assertEquals("Reminds you of your current task 1, 2 or 3 times a day, as set in Settings.", s.channel.description)
        assertEquals("Tarea actual", s.text.title.text)
        assertEquals("Tienes una tarea pendiente.", s.text.publicBody.text)
        // Al revés.
        val t = spec(Display.Generic, choice = LanguageChoice.EN, tags = listOf("es-ES"))
        assertEquals("Tarea actual", t.channel.name)
        assertEquals("Te recuerda tu tarea actual 1, 2 o 3 veces al día, según elijas en Ajustes.", t.channel.description)
        assertEquals("Current task", t.text.title.text)
    }

    @Test
    fun `CA-019-21 el canal usa la regla de la 010 para el idioma del sistema`() {
        assertEquals("Tarea actual", spec(Display.Generic, tags = listOf("ca-ES")).channel.name)
        assertEquals("Current task", spec(Display.Generic, tags = listOf("gl-ES")).channel.name)
        assertEquals("Current task", spec(Display.Generic, tags = emptyList()).channel.name)
    }
}
