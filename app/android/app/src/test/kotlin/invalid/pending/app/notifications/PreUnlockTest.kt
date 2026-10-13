package invalid.pending.app.notifications

import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** CA-019-30: antes del primer desbloqueo la base no se abre y solo puede salir la version generica. */
class PreUnlockTest {
    private fun locked(
        lang: LanguageChoice = LanguageChoice.SYSTEM,
        failure: Throwable? = null,
        result: TaskRead = TaskRead.Task(txt("TEXTO-SECRETO")),
    ): Rig =
        Rig(
            at(14, 9),
            config = cfg(1, lang = lang),
            lastAttended = at(13, 20),
            task = result,
        ).also {
            it.clock.sinceBoot = Duration.ofSeconds(25)
            it.reader.failure = failure
        }

    @Test
    fun `CA-019-30 base que lanza al abrirse - sale la generica, sin texto de error ni de tarea`() {
        val rig = locked(failure = IllegalStateException("SQLITE_CANTOPEN texto-secreto"))
        rig.wake(WakeReason.ALARM)
        val shown = rig.notifier.shown.single()
        assertEquals(Display.Generic, shown.display)
        assertFalse(shown.toString().contains("SQLITE"))
        assertFalse(shown.toString().contains("SECRETO"))
    }

    @Test
    fun `CA-019-30 la hora se marca como atendida y se arma la siguiente`() {
        val rig = locked(failure = RuntimeException("x"))
        rig.wake(WakeReason.ALARM)
        assertEquals(at(14, 9), rig.store.lastAttended)
        assertEquals(at(15, 8, 55), rig.scheduler.last)
    }

    @Test
    fun `CA-019-30 el aviso de arranque bloqueado muestra la generica sin tocar la base`() {
        val rig = locked()
        rig.wake(WakeReason.LOCKED_BOOT_COMPLETED)
        assertEquals(Display.Generic, rig.notifier.shown.single().display)
        assertEquals(0, rig.reader.reads)
        assertEquals(at(15, 8, 55), rig.scheduler.last)
    }

    @Test
    fun `CA-019-30 base legible sin tareas - no sale nada`() {
        val rig = locked(result = TaskRead.NoTask)
        rig.wake(WakeReason.ALARM)
        assertTrue(rig.notifier.shown.isEmpty())
        assertEquals(at(14, 9), rig.store.lastAttended)
    }

    @Test
    fun `CA-019-30 base ilegible por otro motivo (Unreadable) tambien da la generica`() {
        val rig = locked(result = TaskRead.Unreadable)
        rig.wake(WakeReason.ALARM)
        assertEquals(Display.Generic, rig.notifier.shown.single().display)
    }

    @Test
    fun `CA-019-30 con el idioma elegido distinto del del sistema sale en el elegido`() {
        val rig = locked(lang = LanguageChoice.ES, failure = RuntimeException("x"))
        rig.locale.tags = listOf("en-US")
        rig.wake(WakeReason.ALARM)
        val shown = rig.notifier.shown.single()
        // Español elegido con el sistema en inglés: sale en español, marcado, y el canal en inglés.
        assertEquals("Tarea actual", shown.text.title.text)
        assertEquals("Tienes una tarea pendiente.", shown.text.body.text)
        assertTrue(shown.text.body.marked)
        assertEquals("Current task", shown.channel.name)
    }

    @Test
    fun `CA-019-30 lo que se guarda para reprogramar no contiene texto de tareas`() {
        val rig = locked(failure = RuntimeException("x"))
        rig.wake(WakeReason.LOCKED_BOOT_COMPLETED)
        rig.wake(WakeReason.ALARM, at(15, 8, 56))
        assertTrue(rig.store.written.none { it.contains("SECRETO") })
        assertTrue(rig.store.written.isNotEmpty())
        assertNull(rig.store.state.foregroundAt)
    }

    @Test
    fun `CA-019-30 una hora debida antes del desbloqueo sin que la alarma haya disparado tambien se avisa`() {
        // Reinicio a las 16:00, sin desbloquear: la perdida (08:55) sale como generica (CA-019-14).
        val rig = Rig(at(14, 16), config = cfg(1), lastAttended = at(13, 20))
        rig.clock.sinceBoot = Duration.ofSeconds(20)
        rig.wake(WakeReason.LOCKED_BOOT_COMPLETED)
        assertEquals(Display.Generic, rig.notifier.shown.single().display)
        // El aviso de arranque completo (BOOT_COMPLETED) ya no repite: la hora esta atendida.
        rig.clock.sinceBoot = Duration.ofSeconds(60)
        rig.wake(WakeReason.BOOT_COMPLETED, at(14, 16, 1))
        assertEquals(1, rig.notifier.shown.size)
    }
}
