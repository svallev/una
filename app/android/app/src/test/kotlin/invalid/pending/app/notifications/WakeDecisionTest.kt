package invalid.pending.app.notifications

import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** La decision pura al despertar (plan §3.2): motivo, hora, ajustes y lectura de la tarea. */
class WakeDecisionTest {
    private fun input(
        reason: WakeReason,
        now: Instant,
        perDay: Int = 1,
        lastAttended: Instant? = null,
        foregroundAt: Instant? = null,
        canNotify: Boolean = true,
        sinceBoot: Duration = Duration.ofHours(5),
        zone: ZoneId = MADRID,
        on: Boolean = true,
        read: () -> TaskRead = { TaskRead.Task(txt("Llamar a Marta")) },
    ) = WakeInput(
        reason = reason,
        sinceBoot = sinceBoot,
        config = cfg(perDay, on),
        lastAttended = lastAttended,
        foregroundAt = foregroundAt,
        now = now,
        zone = zone,
        canNotify = canNotify,
        readTask = read,
    )

    private val full = Display.Full(txt("Llamar a Marta"))

    // --- CA-019-13: que despertares evaluan lo perdido -----------------------------------------

    @Test
    fun `CA-019-13 alarma, arranque (bloqueado y no) y actualizacion evaluan lo perdido`() {
        for (reason in listOf(
            WakeReason.ALARM,
            WakeReason.LOCKED_BOOT_COMPLETED,
            WakeReason.BOOT_COMPLETED,
            WakeReason.PACKAGE_REPLACED,
        )) {
            val out = WakeDecision.decide(input(reason, at(14, 16), lastAttended = at(13, 20)))
            assertTrue("$reason debe mostrar", out.display != null)
            assertEquals("$reason", at(14, 16), out.newLastAttended)
            assertEquals("$reason", at(15, 8, 55), out.next)
        }
    }

    @Test
    fun `CA-019-13 cambio de hora o de huso no recupera nada, solo avanza la ultima y reprograma`() {
        for (reason in listOf(WakeReason.TIME_SET, WakeReason.TIMEZONE_CHANGED)) {
            val out = WakeDecision.decide(input(reason, at(14, 16), lastAttended = at(13, 20)))
            assertNull("$reason", out.display)
            assertEquals("$reason", at(14, 16), out.newLastAttended)
            assertEquals("$reason", at(15, 8, 55), out.next)
        }
    }

    @Test
    fun `CA-019-13 TIME_SET justo tras el arranque se trata como el arranque`() {
        val justBooted = Duration.ofMinutes(2)
        for (reason in listOf(WakeReason.TIME_SET, WakeReason.TIMEZONE_CHANGED)) {
            val out =
                WakeDecision.decide(
                    input(reason, at(14, 16), lastAttended = at(13, 20), sinceBoot = justBooted),
                )
            assertEquals("$reason", full, out.display)
        }
        // A los 3 minutos exactos ya no.
        val late =
            WakeDecision.decide(
                input(
                    WakeReason.TIME_SET,
                    at(14, 16),
                    lastAttended = at(13, 20),
                    sinceBoot = Duration.ofMinutes(3),
                ),
            )
        assertNull(late.display)
    }

    @Test
    fun `CA-019-13 el cambio de idioma no decide nada`() {
        var reads = 0
        val out =
            WakeDecision.decide(
                input(WakeReason.LOCALE_CHANGED, at(14, 16), lastAttended = at(13, 20)) {
                    reads++
                    TaskRead.Task(txt("x"))
                },
            )
        assertNull(out.display)
        assertNull(out.newLastAttended)
        assertNull(out.next)
        assertEquals(0, reads)
    }

    // --- CA-019-14: la bateria de recuperacion --------------------------------------------------

    @Test
    fun `CA-019-14 reinicio a las 16 00 con 1 al dia muestra la de las 08 55 (una sola)`() {
        val out = WakeDecision.decide(
            input(WakeReason.BOOT_COMPLETED, at(14, 16), perDay = 1, lastAttended = at(13, 20)),
        )
        assertEquals(full, out.display)
        assertEquals(at(15, 8, 55), out.next)
    }

    @Test
    fun `CA-019-14 reinicio a las 16 00 con 3 al dia, solo la de las 13 55 y la siguiente es la de las 18 55`() {
        val out = WakeDecision.decide(
            input(WakeReason.BOOT_COMPLETED, at(14, 16), perDay = 3, lastAttended = at(13, 20)),
        )
        assertEquals(full, out.display)
        assertEquals(at(14, 18, 55), out.next)
    }

    @Test
    fun `CA-019-14 reinicio a las 20 00 con 3 al dia, solo una y la siguiente es la de manana`() {
        val out = WakeDecision.decide(
            input(WakeReason.BOOT_COMPLETED, at(14, 20), perDay = 3, lastAttended = at(13, 20)),
        )
        assertEquals(full, out.display)
        assertEquals(at(15, 8, 55), out.next)
    }

    @Test
    fun `CA-019-14 sin ultima hora guardada no se recupera nada al arrancar`() {
        val out = WakeDecision.decide(input(WakeReason.BOOT_COMPLETED, at(14, 16), lastAttended = null))
        assertNull(out.display)
        assertNull(out.newLastAttended)
        assertEquals(at(15, 8, 55), out.next)
    }

    @Test
    fun `CA-019-14 una ultima hora futura se ignora al arrancar`() {
        val out = WakeDecision.decide(
            input(WakeReason.BOOT_COMPLETED, at(14, 16), lastAttended = at(14, 18)),
        )
        assertNull(out.display)
    }

    @Test
    fun `CA-019-14 la alarma que dispara sin ultima hora valida muestra la hora que la armo`() {
        // La alarma es evidencia de que una hora toca: no se traga la notificacion.
        for (last in listOf<Instant?>(null, at(14, 12))) {
            val out = WakeDecision.decide(
                input(WakeReason.ALARM, at(14, 9, 3), lastAttended = last),
            )
            assertEquals("last=$last", full, out.display)
        }
    }

    @Test
    fun `CA-019-14 una alarma duplicada de una hora ya atendida no muestra nada`() {
        val out = WakeDecision.decide(
            input(WakeReason.ALARM, at(14, 9, 10), lastAttended = at(14, 9, 3)),
        )
        assertNull(out.display)
        assertNull(out.newLastAttended) // no habia hora debida: nada que avanzar
        assertEquals(at(15, 8, 55), out.next)
    }

    @Test
    fun `CA-019-14 huso +8 h a las 10 00 no recupera nada`() {
        val out = WakeDecision.decide(
            input(
                WakeReason.TIMEZONE_CHANGED,
                at(14, 10),
                perDay = 3,
                lastAttended = at(14, 8, 56),
                zone = ZoneId.of("Asia/Singapore"),
            ),
        )
        assertNull(out.display)
        assertEquals(at(14, 10), out.newLastAttended)
    }

    // --- CA-019-12: desde la configuracion (ver WakeHandlerTest) y CA-019-15: sin tareas ---------

    @Test
    fun `CA-019-15 sin tareas no se muestra nada, pero la hora cuenta como atendida`() {
        val out = WakeDecision.decide(
            input(WakeReason.ALARM, at(14, 9), lastAttended = at(13, 20)) { TaskRead.NoTask },
        )
        assertNull(out.display)
        assertEquals(at(14, 9), out.newLastAttended)
        assertEquals(at(15, 8, 55), out.next)
    }

    @Test
    fun `CA-019-16 una tarea sin etiqueta (grupo de fotos, adjunto raro) sale con las dos versiones iguales`() {
        val out = WakeDecision.decide(
            input(WakeReason.ALARM, at(14, 9), lastAttended = at(13, 20)) { TaskRead.Task(null) },
        )
        assertEquals(Display.Generic, out.display)
    }

    @Test
    fun `CA-019-30 base ilegible da la generica y la hora se marca como atendida`() {
        val out = WakeDecision.decide(
            input(WakeReason.ALARM, at(14, 9), lastAttended = at(13, 20)) { TaskRead.Unreadable },
        )
        assertEquals(Display.Generic, out.display)
        assertEquals(at(14, 9), out.newLastAttended)
    }

    @Test
    fun `CA-019-30 antes del primer desbloqueo no se intenta leer la base`() {
        var reads = 0
        val out = WakeDecision.decide(
            input(WakeReason.LOCKED_BOOT_COMPLETED, at(14, 16), lastAttended = at(13, 20)) {
                reads++
                TaskRead.Task(txt("secreto"))
            },
        )
        assertEquals(Display.Generic, out.display)
        assertEquals(0, reads)
    }

    @Test
    fun `no se lee la tarea si no hay nada que mostrar`() {
        var reads = 0
        val read = {
            reads++
            TaskRead.Task(txt("x"))
        }
        // sin hora debida
        WakeDecision.decide(input(WakeReason.ALARM, at(14, 9, 10), lastAttended = at(14, 9, 3), read = read))
        // ajuste apagado
        WakeDecision.decide(input(WakeReason.ALARM, at(14, 9), lastAttended = at(13, 20), on = false, read = read))
        // no puede notificar
        WakeDecision.decide(input(WakeReason.ALARM, at(14, 9), lastAttended = at(13, 20), canNotify = false, read = read))
        // app a la vista
        WakeDecision.decide(input(WakeReason.ALARM, at(14, 9), lastAttended = at(13, 20), foregroundAt = at(14, 8, 58), read = read))
        assertEquals(0, reads)
    }

    // --- CA-019-12/14: se salta a proposito ------------------------------------------------------

    @Test
    fun `ajuste apagado no hace nada (ni reprograma)`() {
        val out = WakeDecision.decide(input(WakeReason.ALARM, at(14, 9), lastAttended = at(13, 20), on = false))
        assertNull(out.display)
        assertNull(out.newLastAttended)
        assertNull(out.next)
    }

    @Test
    fun `no poder notificar salta la hora a proposito y sigue atendida`() {
        val out = WakeDecision.decide(
            input(WakeReason.ALARM, at(14, 9), lastAttended = at(13, 20), canNotify = false),
        )
        assertNull(out.display)
        assertEquals(at(14, 9), out.newLastAttended)
        assertEquals(at(15, 8, 55), out.next)
    }

    // --- CA-019-19a: con la app a la vista no se notifica --------------------------------------

    @Test
    fun `CA-019-19a indicador reciente, nada, y se avanza la ultima hora (no se recupera luego)`() {
        val out = WakeDecision.decide(
            input(WakeReason.ALARM, at(14, 9), lastAttended = at(13, 20), foregroundAt = at(14, 8, 58)),
        )
        assertNull(out.display)
        assertEquals(at(14, 9), out.newLastAttended)
    }

    @Test
    fun `CA-019-19a el limite es N = 12 minutos`() {
        val now = at(14, 9)
        val fresh = now.minus(Duration.ofMinutes(12))
        val stale = fresh.minusMillis(1)
        assertNull(WakeDecision.decide(input(WakeReason.ALARM, now, lastAttended = at(13, 20), foregroundAt = fresh)).display)
        assertEquals(
            full,
            WakeDecision.decide(input(WakeReason.ALARM, now, lastAttended = at(13, 20), foregroundAt = stale)).display,
        )
    }

    @Test
    fun `CA-019-19a un indicador futuro o ausente se ignora, ante la duda se notifica`() {
        val now = at(14, 9)
        for (fg in listOf<Instant?>(null, now.plusSeconds(30), now.plus(Duration.ofDays(2)))) {
            val out = WakeDecision.decide(input(WakeReason.ALARM, now, lastAttended = at(13, 20), foregroundAt = fg))
            assertEquals("fg=$fg", full, out.display)
        }
    }

    @Test
    fun `CA-019-19a un indicador viejo tras un reinicio no impide notificar`() {
        for (reason in listOf(WakeReason.LOCKED_BOOT_COMPLETED, WakeReason.BOOT_COMPLETED)) {
            // Reciente en el reloj, pero el movil acaba de arrancar: la app no puede estar a la vista.
            val out = WakeDecision.decide(
                input(
                    reason,
                    at(14, 9),
                    lastAttended = at(13, 20),
                    foregroundAt = at(14, 8, 58),
                    sinceBoot = Duration.ofSeconds(30),
                ),
            )
            assertTrue("$reason", out.display != null)
        }
    }

    // --- Siguiente hora --------------------------------------------------------------------------

    @Test
    fun `la siguiente hora es la primera configurada despues de ahora en la zona del movil`() {
        val out = WakeDecision.decide(input(WakeReason.ALARM, at(14, 13, 56), perDay = 3, lastAttended = at(14, 9)))
        assertEquals(at(14, 18, 55), out.next)
    }
}
