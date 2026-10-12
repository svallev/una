package invalid.pending.app.notifications

import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** El orquestador con programador y notificador falsos (plan §3.2, §5). */
class WakeHandlerTest {
    // --- CA-019-11: alarmas siempre inexactas -------------------------------------------------

    @Test
    fun `CA-019-11 el programador solo ofrece alarmas inexactas`() {
        val names = AlarmScheduler::class.java.methods.map { it.name.lowercase() }.toSet()
        assertTrue(names.any { it.contains("inexact") })
        // Nada de "exact" que no sea "inexact", ni de setAlarmClock.
        assertTrue(names.none { it.replace("inexact", "").contains("exact") })
        assertTrue(names.none { it.contains("alarmclock") })
    }

    // --- CA-019-12: los cambios se aplican al momento ----------------------------------------

    @Test
    fun `CA-019-12 encender a las 08 50 arma la de las 08 55 de hoy`() {
        val rig = Rig(at(14, 8, 50), config = cfg(1, on = false))
        assertTrue(rig.configure(cfg(1), at(14, 8, 50)))
        assertEquals(at(14, 8, 55), rig.scheduler.last)
        assertEquals(cfg(1), rig.store.state.config)
    }

    @Test
    fun `CA-019-12 encender a las 09 00 arma la siguiente (la de manana con 1 al dia)`() {
        val rig = Rig(at(14, 9), config = cfg(1, on = false))
        assertTrue(rig.configure(cfg(1)))
        assertEquals(at(15, 8, 55), rig.scheduler.last)
    }

    @Test
    fun `CA-019-12 encender a las 09 00 con 3 al dia arma la de las 13 55`() {
        val rig = Rig(at(14, 9), config = cfg(3, on = false))
        assertTrue(rig.configure(cfg(3)))
        assertEquals(at(14, 13, 55), rig.scheduler.last)
    }

    @Test
    fun `CA-019-12 encender a las 20 00 arma la de manana`() {
        val rig = Rig(at(14, 20), config = cfg(3, on = false))
        assertTrue(rig.configure(cfg(3)))
        assertEquals(at(15, 8, 55), rig.scheduler.last)
    }

    @Test
    fun `CA-019-12 de 1 a 3 a las 10 00 hoy llegan la de las 13 55 y la de las 18 55, no la de las 08 55`() {
        val rig = Rig(at(14, 10), config = cfg(1), lastAttended = at(14, 8, 56))
        assertTrue(rig.configure(cfg(3)))
        assertEquals(at(14, 13, 55), rig.scheduler.last)
        // Lo que ya paso hoy no se recupera: ni al volver a mirar lo perdido (sin alarma ni arranque).
        assertEquals(at(14, 10), rig.store.lastAttended)
        rig.wake(WakeReason.BOOT_COMPLETED, at(14, 10, 5))
        assertTrue(rig.notifier.shown.isEmpty())
        // Llega la de las 13:55, luego la de las 18:55.
        rig.wake(WakeReason.ALARM, at(14, 13, 56))
        assertEquals(1, rig.notifier.shown.size)
        assertEquals(at(14, 18, 55), rig.scheduler.last)
        rig.wake(WakeReason.ALARM, at(14, 18, 56))
        assertEquals(2, rig.notifier.shown.size)
        assertEquals(at(15, 8, 55), rig.scheduler.last)
    }

    @Test
    fun `CA-019-12 de 3 a 1 a las 07 00 las que sobran no se arman nunca`() {
        val rig = Rig(at(14, 7), config = cfg(3), lastAttended = at(13, 20))
        assertTrue(rig.configure(cfg(1)))
        assertEquals(at(14, 8, 55), rig.scheduler.last)
        rig.wake(WakeReason.ALARM, at(14, 8, 56))
        assertEquals(1, rig.notifier.shown.size)
        // La siguiente es la de manana: ni la de las 13:55 ni la de las 18:55 de hoy.
        assertEquals(at(15, 8, 55), rig.scheduler.last)
        assertFalse(rig.scheduler.armed.contains(at(14, 13, 55)))
        assertFalse(rig.scheduler.armed.contains(at(14, 18, 55)))
    }

    @Test
    fun `CA-019-12 apagar cancela la alarma y quita la notificacion de la bandeja`() {
        val rig = Rig(at(14, 10), config = cfg(3), lastAttended = at(14, 8, 56))
        assertTrue(rig.configure(cfg(3, on = false)))
        assertEquals(1, rig.scheduler.cancels)
        assertEquals(1, rig.notifier.cancelDelivered)
        assertFalse(rig.store.state.config.on)
        // Una alarma que se colara estando apagado no hace nada.
        val armedBefore = rig.scheduler.armed.size
        rig.wake(WakeReason.ALARM, at(14, 13, 56))
        assertTrue(rig.notifier.shown.isEmpty())
        assertEquals(armedBefore, rig.scheduler.armed.size)
        assertEquals(0, rig.reader.reads)
    }

    @Test
    fun `CA-019-12 configurar apagado sobre apagado (arranque de la app) no toca la bandeja ni anota nada`() {
        val rig = Rig(at(14, 10), config = cfg(3, on = false), lastAttended = at(14, 8, 56))
        assertTrue(rig.configure(cfg(3, on = false)))
        assertEquals(1, rig.scheduler.cancels)
        assertEquals(0, rig.notifier.cancelDelivered)
        assertEquals(at(14, 8, 56), rig.store.lastAttended)
    }

    @Test
    fun `CA-019-12 apagado tres dias y encendido a las 16 00 no recupera nada hasta la siguiente`() {
        val rig = Rig(at(14, 16), config = cfg(3, on = false), lastAttended = at(11, 20))
        assertTrue(rig.configure(cfg(3)))
        assertEquals(at(14, 18, 55), rig.scheduler.last)
        rig.wake(WakeReason.BOOT_COMPLETED, at(14, 16, 1))
        assertTrue(rig.notifier.shown.isEmpty())
    }

    @Test
    fun `CA-019-14 de 1 a 3 a las 16 00 no sale la de las 13 55`() {
        val rig = Rig(at(14, 16), config = cfg(1), lastAttended = at(14, 8, 56))
        assertTrue(rig.configure(cfg(3)))
        rig.wake(WakeReason.BOOT_COMPLETED, at(14, 16, 1))
        assertTrue(rig.notifier.shown.isEmpty())
        assertEquals(at(14, 18, 55), rig.scheduler.last)
    }

    @Test
    fun `configure con los mismos ajustes (arranque de la app) rearma pero no avanza la ultima hora`() {
        val rig = Rig(at(14, 16), config = cfg(3), lastAttended = at(13, 20))
        assertTrue(rig.configure(cfg(3)))
        assertEquals(at(14, 18, 55), rig.scheduler.last)
        assertEquals(at(13, 20), rig.store.lastAttended)
        // Y no evalua lo perdido: eso es solo de la alarma y del arranque del movil.
        assertTrue(rig.notifier.shown.isEmpty())
    }

    @Test
    fun `configure sin ultima hora valida la fija a ahora`() {
        for (last in listOf(null, at(14, 18))) {
            val rig = Rig(at(14, 16), config = cfg(3), lastAttended = last)
            assertTrue(rig.configure(cfg(3)))
            assertEquals("last=$last", at(14, 16), rig.store.lastAttended)
        }
    }

    @Test
    fun `cambiar solo el idioma no avanza la ultima hora`() {
        val rig = Rig(at(14, 16), config = cfg(3), lastAttended = at(13, 20))
        assertTrue(rig.configure(cfg(3, lang = LanguageChoice.EN)))
        assertEquals(at(13, 20), rig.store.lastAttended)
        assertEquals(LanguageChoice.EN, rig.store.state.config.language)
    }

    @Test
    fun `todo o nada - si falla escribir o programar, devuelve false`() {
        val rig = Rig(at(14, 9), config = cfg(1, on = false))
        rig.store.failConfigWrite = true
        assertFalse(rig.configure(cfg(1)))
        assertTrue(rig.scheduler.armed.isEmpty())
        assertFalse(rig.store.state.config.on)

        val rig2 = Rig(at(14, 9), config = cfg(1, on = false))
        rig2.scheduler.failArm = true
        assertFalse(rig2.configure(cfg(1)))
    }

    @Test
    fun `una cantidad fuera de 1 a 3 se rechaza sin tocar nada`() {
        for (bad in listOf(0, 4, -1)) {
            val rig = Rig(at(14, 9), config = cfg(1, on = false))
            assertFalse(rig.configure(cfg(bad)))
            assertTrue(rig.store.written.isEmpty())
            assertTrue(rig.scheduler.armed.isEmpty())
        }
    }

    // --- CA-019-13: los despertares ----------------------------------------------------------

    @Test
    fun `CA-019-13 cada despertar vuelve a pedir la proxima hora`() {
        for (reason in WakeReason.values().filter { it != WakeReason.LOCALE_CHANGED }) {
            val rig = Rig(at(14, 16), config = cfg(3), lastAttended = at(13, 20))
            rig.wake(reason)
            assertEquals("$reason", at(14, 18, 55), rig.scheduler.last)
            assertEquals("$reason", 1, rig.scheduler.armed.size)
        }
    }

    @Test
    fun `CA-019-13 el cambio de hora o de huso lejos del arranque no notifica y avanza la ultima`() {
        for (reason in listOf(WakeReason.TIME_SET, WakeReason.TIMEZONE_CHANGED)) {
            val rig = Rig(at(14, 16), config = cfg(3), lastAttended = at(13, 20))
            rig.wake(reason)
            assertTrue("$reason", rig.notifier.shown.isEmpty())
            assertEquals("$reason", at(14, 16), rig.store.lastAttended)
            assertEquals("$reason", 0, rig.reader.reads)
        }
    }

    @Test
    fun `CA-019-13 TIME_SET justo tras el arranque notifica lo del reinicio`() {
        val rig = Rig(at(14, 16), config = cfg(1), lastAttended = at(13, 20))
        rig.clock.sinceBoot = Duration.ofSeconds(90)
        rig.wake(WakeReason.TIME_SET)
        assertEquals(1, rig.notifier.shown.size)
    }

    @Test
    fun `CA-019-13 el cambio de idioma solo refresca el canal`() {
        val rig = Rig(at(14, 16), config = cfg(3), lastAttended = at(13, 20))
        rig.wake(WakeReason.LOCALE_CHANGED)
        assertEquals(1, rig.notifier.channelRefreshes)
        assertTrue(rig.notifier.shown.isEmpty())
        assertTrue(rig.scheduler.armed.isEmpty())
        assertEquals(at(13, 20), rig.store.lastAttended)
    }

    @Test
    fun `CA-019-13 con el ajuste apagado todo despertar es un no-op total`() {
        for (reason in WakeReason.values()) {
            val rig = Rig(at(14, 16), config = cfg(3, on = false), lastAttended = at(13, 20))
            rig.wake(reason)
            assertTrue("$reason", rig.store.written.isEmpty())
            assertTrue("$reason", rig.scheduler.armed.isEmpty())
            assertEquals("$reason", 0, rig.scheduler.cancels)
            assertEquals("$reason", 0, rig.notifier.channelRefreshes)
            assertTrue("$reason", rig.notifier.shown.isEmpty())
        }
    }

    // --- CA-019-14: perdidas -------------------------------------------------------------------

    @Test
    fun `CA-019-14 reinicio a las 16 00 con 1 y con 3 al dia muestra una sola notificacion`() {
        for (perDay in listOf(1, 3)) {
            val rig = Rig(at(14, 16), config = cfg(perDay), lastAttended = at(13, 20))
            rig.wake(WakeReason.BOOT_COMPLETED)
            assertEquals("perDay=$perDay", 1, rig.notifier.shown.size)
            assertEquals("perDay=$perDay", at(14, 16), rig.store.lastAttended)
        }
    }

    @Test
    fun `CA-019-14 una hora saltada por app a la vista no se recupera despues`() {
        val rig = Rig(at(14, 9), config = cfg(1), lastAttended = at(13, 20), foregroundAt = at(14, 8, 58))
        rig.wake(WakeReason.ALARM, at(14, 9))
        assertTrue(rig.notifier.shown.isEmpty())
        rig.wake(WakeReason.BOOT_COMPLETED, at(14, 16))
        assertTrue(rig.notifier.shown.isEmpty())
    }

    @Test
    fun `CA-019-14 las horas debidas del interruptor apagado no se recuperan al encender`() {
        val rig = Rig(at(14, 16), config = cfg(1, on = false), lastAttended = at(11, 9))
        rig.configure(cfg(1))
        rig.wake(WakeReason.BOOT_COMPLETED, at(14, 16, 1))
        assertTrue(rig.notifier.shown.isEmpty())
    }

    // --- CA-019-15 / 16 / 19a: lo que se muestra ------------------------------------------------

    @Test
    fun `CA-019-15 la decision se toma al llegar la hora, no al programar`() {
        val rig = Rig(at(14, 8, 50), config = cfg(2, on = false), task = TaskRead.Task(txt("Tarea")))
        rig.configure(cfg(2))
        // Se completa la ultima tarea a las 08:50: a las 08:55 no sale nada.
        rig.reader.result = TaskRead.NoTask
        rig.wake(WakeReason.ALARM, at(14, 8, 56))
        assertTrue(rig.notifier.shown.isEmpty())
        // Se crea una a las 08:56: a las 13:55 si.
        rig.reader.result = TaskRead.Task(txt("Nueva"))
        rig.wake(WakeReason.ALARM, at(14, 13, 56))
        assertEquals(Display.Full(txt("Nueva")), rig.notifier.shown.single().display)
    }

    @Test
    fun `CA-019-16 sale la tarea que sea la actual al llegar, no la de cuando se programo`() {
        val rig = Rig(at(14, 8, 50), config = cfg(1), lastAttended = at(13, 20), task = TaskRead.Task(txt("Vieja")))
        rig.reader.result = TaskRead.Task(txt("Nueva"))
        rig.wake(WakeReason.ALARM, at(14, 8, 56))
        assertEquals(Display.Full(txt("Nueva")), rig.notifier.shown.single().display)
    }

    @Test
    fun `CA-019-16 la tarea sin etiqueta se muestra con la version generica`() {
        val rig = Rig(at(14, 9), config = cfg(1), lastAttended = at(13, 20), task = TaskRead.Task(null))
        rig.wake(WakeReason.ALARM)
        assertEquals(Display.Generic, rig.notifier.shown.single().display)
    }

    @Test
    fun `CA-019-19a indicador reciente no notifica, viejo si, ausente si`() {
        val recent = Rig(at(14, 9), config = cfg(1), lastAttended = at(13, 20), foregroundAt = at(14, 8, 50))
        recent.wake(WakeReason.ALARM)
        assertTrue(recent.notifier.shown.isEmpty())

        val old = Rig(at(14, 9), config = cfg(1), lastAttended = at(13, 20), foregroundAt = at(14, 8, 40))
        old.wake(WakeReason.ALARM)
        assertEquals(1, old.notifier.shown.size)

        val none = Rig(at(14, 9), config = cfg(1), lastAttended = at(13, 20), foregroundAt = null)
        none.wake(WakeReason.ALARM)
        assertEquals(1, none.notifier.shown.size)
    }

    @Test
    fun `CA-019-19a tras un reinicio el indicador se limpia y se notifica`() {
        val rig = Rig(at(14, 9), config = cfg(1), lastAttended = at(13, 20), foregroundAt = at(14, 8, 59))
        rig.clock.sinceBoot = Duration.ofSeconds(40)
        rig.wake(WakeReason.LOCKED_BOOT_COMPLETED)
        assertEquals(1, rig.notifier.shown.size)
        assertNull(rig.store.state.foregroundAt)
    }

    @Test
    fun `CA-019-19a sin permiso o con el canal apagado no se muestra, pero la hora cuenta como atendida`() {
        val rig = Rig(at(14, 9), config = cfg(1), lastAttended = at(13, 20))
        rig.notifier.canNotify = false
        rig.wake(WakeReason.ALARM)
        assertTrue(rig.notifier.shown.isEmpty())
        assertEquals(at(14, 9), rig.store.lastAttended)
        assertEquals(at(15, 8, 55), rig.scheduler.last)
    }

    // --- CA-019-22 (una sola, sin acciones: lo demas es del Poster) y CA-019-23 (sin texto fuera) -

    @Test
    fun `CA-019-18 con varias horas debidas sale una sola notificacion`() {
        val rig = Rig(at(14, 20), config = cfg(3), lastAttended = at(12, 20))
        rig.wake(WakeReason.BOOT_COMPLETED)
        assertEquals(1, rig.notifier.shown.size)
    }

    @Test
    fun `CA-019-23 el texto de la tarea solo llega al notificador, nunca a la copia ni al programador`() {
        val secret = "TEXTO-SECRETO-4711"
        val rig = Rig(at(14, 9), config = cfg(3), lastAttended = at(13, 20), task = TaskRead.Task(txt(secret)))
        rig.wake(WakeReason.ALARM)
        assertEquals(Display.Full(txt(secret)), rig.notifier.shown.single().display)
        assertTrue(rig.store.written.none { it.contains(secret) })
        assertTrue(rig.scheduler.armed.none { it.toString().contains(secret) })
        assertFalse(rig.store.state.toString().contains(secret))
    }

    @Test
    fun `CA-019-23 la copia derivada solo recibe configuracion, ultima hora e indicador`() {
        val rig = Rig(at(14, 9), config = cfg(3), lastAttended = at(13, 20), foregroundAt = at(14, 8, 0))
        rig.configure(cfg(2))
        rig.wake(WakeReason.ALARM, at(14, 19))
        rig.wake(WakeReason.LOCKED_BOOT_COMPLETED, at(15, 9))
        val kinds = rig.store.written.map { it.substringBefore(':') }.toSet()
        assertEquals(setOf("config", "lastAttended", "foregroundAt"), kinds)
    }

    // --- Robustez -------------------------------------------------------------------------------

    @Test
    fun `si mostrar falla la hora queda atendida y la siguiente armada, sin propagar`() {
        val rig = Rig(at(14, 9), config = cfg(1), lastAttended = at(13, 20))
        rig.notifier.showFailure = IllegalStateException("texto-secreto")
        rig.wake(WakeReason.ALARM)
        assertEquals(at(14, 9), rig.store.lastAttended)
        assertEquals(at(15, 8, 55), rig.scheduler.last)
    }

    @Test
    fun `si leer la tarea lanza, sale la version generica`() {
        val rig = Rig(at(14, 9), config = cfg(1), lastAttended = at(13, 20))
        rig.reader.failure = RuntimeException("texto-secreto")
        rig.wake(WakeReason.ALARM)
        assertEquals(Display.Generic, rig.notifier.shown.single().display)
    }

    @Test
    fun `el idioma elegido viaja a la notificacion junto al del sistema`() {
        val rig = Rig(
            at(14, 9),
            config = cfg(1, lang = LanguageChoice.ES),
            lastAttended = at(13, 20),
        )
        rig.locale.tags = listOf("en-GB", "fr")
        rig.wake(WakeReason.ALARM)
        val shown = rig.notifier.shown.single()
        assertEquals("Tarea actual", shown.text.title.text)
        assertTrue(shown.text.title.marked)
        assertEquals("Current task", shown.channel.name)
    }

    @Test
    fun `CA-019-21 el idioma es el del momento de llegar, no el de cuando se programo`() {
        val rig = Rig(at(14, 8, 50), config = cfg(1), lastAttended = at(13, 20))
        rig.locale.tags = listOf("en-GB")
        rig.configure(cfg(1))
        // Antes de llegar la hora, el móvil pasa a español.
        rig.locale.tags = listOf("es-ES")
        rig.wake(WakeReason.ALARM, at(14, 9))
        val shown = rig.notifier.shown.single()
        assertEquals("Tarea actual", shown.text.title.text)
        assertFalse(shown.text.title.marked)
    }

    @Test
    fun `CA-019-16 la etiqueta de cada tipo llega en el idioma de la app`() {
        val rig = Rig(at(14, 9), config = cfg(1, lang = LanguageChoice.EN), lastAttended = at(13, 20), task = TaskRead.Task(TaskLabel.Photo))
        rig.locale.tags = listOf("es-ES")
        rig.wake(WakeReason.ALARM)
        val shown = rig.notifier.shown.single()
        assertEquals("Photo", shown.text.body.text)
        assertTrue(shown.text.body.marked)
    }

    @Test
    fun `CA-019-18 todas las notificaciones usan el mismo identificador y el mismo canal`() {
        val rig = Rig(at(14, 9), config = cfg(3), lastAttended = at(13, 20))
        rig.wake(WakeReason.ALARM)
        rig.reader.result = TaskRead.Task(TaskLabel.Pdf)
        rig.wake(WakeReason.ALARM, at(14, 19))
        rig.reader.result = TaskRead.Unreadable
        rig.wake(WakeReason.ALARM, at(15, 9))
        assertEquals(3, rig.notifier.shown.size)
        assertEquals(1, rig.notifier.shown.map { it.id }.toSet().size)
        assertEquals(1, rig.notifier.shown.map { it.channel }.toSet().size)
        assertTrue(rig.notifier.shown.all { it.actions.isEmpty() && !it.showBadge })
    }

    @Test
    fun `CA-019-17 la version publica nunca lleva la etiqueta, que si va en la completa`() {
        val secret = "SECRETO-7"
        val rig = Rig(at(14, 9), config = cfg(1), lastAttended = at(13, 20), task = TaskRead.Task(txt(secret)))
        rig.wake(WakeReason.ALARM)
        val shown = rig.notifier.shown.single()
        assertEquals(secret, shown.text.body.text)
        assertFalse(shown.text.publicTitle.text.contains(secret))
        assertFalse(shown.text.publicBody.text.contains(secret))
        assertFalse(shown.channel.name.contains(secret) || shown.channel.description.contains(secret))
    }
}
