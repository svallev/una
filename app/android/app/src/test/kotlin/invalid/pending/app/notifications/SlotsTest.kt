package invalid.pending.app.notifications

import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.util.TimeZone
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SlotsTest {
    private val savedZone = TimeZone.getDefault()

    @After
    fun restoreZone() = TimeZone.setDefault(savedZone)

    // --- CA-019-10: las horas y cuántas -------------------------------------------------------

    @Test
    fun `CA-019-10 las horas fijas para 1, 2 y 3 al dia`() {
        assertEquals(listOf(LocalTime.of(8, 55)), NotificationTimes.forCount(1))
        assertEquals(listOf(LocalTime.of(8, 55), LocalTime.of(13, 55)), NotificationTimes.forCount(2))
        assertEquals(
            listOf(LocalTime.of(8, 55), LocalTime.of(13, 55), LocalTime.of(18, 55)),
            NotificationTimes.forCount(3),
        )
    }

    @Test
    fun `CA-019-05 una cantidad fuera de 1 a 3 no tiene horas`() {
        for (bad in listOf(0, 4, -1, Int.MIN_VALUE, Int.MAX_VALUE)) {
            assertTrue("perDay=$bad", NotificationTimes.forCount(bad).isEmpty())
            assertNull("perDay=$bad", Slots.next(at(14, 10), MADRID, bad))
            assertNull("perDay=$bad", Slots.latestAtOrBefore(at(14, 10), MADRID, bad))
            assertNull("perDay=$bad", Slots.latestDue(at(14, 10), at(13, 0), MADRID, bad))
        }
    }

    @Test
    fun `CA-019-10 la proxima hora para cada hora del dia y cada cantidad`() {
        for (perDay in 1..3) {
            val slots = NotificationTimes.forCount(perDay)
            for (hour in 0..23) {
                for (minute in listOf(0, 30, 55)) {
                    val now = at(14, hour, minute)
                    val local = LocalTime.of(hour, minute)
                    val expected =
                        slots.firstOrNull { it.isAfter(local) }?.let { at(14, it.hour, it.minute) }
                            ?: at(15, 8, 55)
                    assertEquals("perDay=$perDay $local", expected, Slots.next(now, MADRID, perDay))
                }
            }
        }
    }

    @Test
    fun `CA-019-10 la respuesta no depende de la zona del test`() {
        val expected = Slots.next(at(14, 10), MADRID, 3)
        for (id in listOf("UTC", "Asia/Tokyo", "America/Los_Angeles", "Pacific/Kiritimati")) {
            TimeZone.setDefault(TimeZone.getTimeZone(id))
            assertEquals(id, expected, Slots.next(at(14, 10), MADRID, 3))
        }
    }

    @Test
    fun `CA-019-10 estrictamente despues de ahora (la hora exacta ya no cuenta)`() {
        assertEquals(at(14, 13, 55), Slots.next(at(14, 8, 55), MADRID, 2))
        assertEquals(at(15, 8, 55), Slots.next(at(14, 8, 55), MADRID, 1))
        // Un milisegundo antes todavia es la de las 08:55.
        assertEquals(at(14, 8, 55), Slots.next(at(14, 8, 55).minusMillis(1), MADRID, 1))
    }

    @Test
    fun `CA-019-10 la hora es del reloj del movil en su zona`() {
        // 10:00 en Madrid es 17:00 en Singapur (+8): ahi ya pasaron las 08:55 y las 13:55.
        val singapore = ZoneId.of("Asia/Singapore")
        val now = at(14, 10, zone = MADRID)
        assertEquals(at(14, 18, 55, singapore), Slots.next(now, singapore, 3))
        assertEquals(at(15, 8, 55, singapore), Slots.next(now, singapore, 1))
    }

    // --- CL-019-4: horario de verano ---------------------------------------------------------

    @Test
    fun `CL-019-4 el dia del cambio de hora llegan las mismas horas del reloj, cada una una vez`() {
        for ((month, day) in listOf(3 to 29, 10 to 25)) {
            var cursor = at(day - 1, 20, month = month, year = 2026)
            val seen = mutableListOf<Instant>()
            repeat(6) {
                val next = Slots.next(cursor, MADRID, 3)!!
                assertTrue(next.isAfter(cursor))
                seen += next
                cursor = next
            }
            val local = seen.map { it.atZone(MADRID).toLocalTime() }
            assertEquals(
                listOf(
                    LocalTime.of(8, 55), LocalTime.of(13, 55), LocalTime.of(18, 55),
                    LocalTime.of(8, 55), LocalTime.of(13, 55), LocalTime.of(18, 55),
                ),
                local,
            )
            assertEquals(seen.size, seen.toSet().size)
            // Entre las 08:55 del dia del cambio y las del dia siguiente pasan 23 o 25 horas, no 24.
            assertEquals(day, seen[0].atZone(MADRID).dayOfMonth)
        }
    }

    // --- Lo debido: la mas reciente <= ahora y > ultima atendida (CA-019-14) --------------------

    @Test
    fun `CA-019-14 con 1 al dia, a las 16 00 la debida es la de las 08 55`() {
        assertEquals(at(14, 8, 55), Slots.latestDue(at(14, 16), at(13, 20), MADRID, 1))
    }

    @Test
    fun `CA-019-14 con 3 al dia, a las 16 00 solo la de las 13 55`() {
        assertEquals(at(14, 13, 55), Slots.latestDue(at(14, 16), at(13, 20), MADRID, 3))
    }

    @Test
    fun `CA-019-14 a las 20 00 con 3 al dia, solo la de las 18 55`() {
        assertEquals(at(14, 18, 55), Slots.latestDue(at(14, 20), at(13, 20), MADRID, 3))
    }

    @Test
    fun `CA-019-14 sin ultima hora guardada no se recupera nada`() {
        assertNull(Slots.latestDue(at(14, 16), null, MADRID, 3))
    }

    @Test
    fun `CA-019-14 una ultima hora futura no recupera nada`() {
        assertNull(Slots.latestDue(at(14, 16), at(14, 16).plusSeconds(1), MADRID, 3))
        assertNull(Slots.latestDue(at(14, 16), at(20, 9), MADRID, 3))
    }

    @Test
    fun `CA-019-14 lo ya atendido no se repite, ni la hora exacta de la ultima`() {
        // Atendida a las 08:56: con 1 al dia, a las 16:00 no hay nada debido.
        assertNull(Slots.latestDue(at(14, 16), at(14, 8, 56), MADRID, 1))
        // Atendida justo a las 13:55: la de las 13:55 no es > ultima.
        assertNull(Slots.latestDue(at(14, 16), at(14, 13, 55), MADRID, 2))
        // Un instante antes: si es debida.
        assertEquals(
            at(14, 13, 55),
            Slots.latestDue(at(14, 16), at(14, 13, 55).minusMillis(1), MADRID, 2),
        )
    }

    @Test
    fun `CA-019-14 la hora exacta de ahora ya es debida`() {
        assertEquals(at(14, 13, 55), Slots.latestDue(at(14, 13, 55), at(14, 9), MADRID, 2))
    }

    @Test
    fun `CA-019-14 latestAtOrBefore da la mas reciente aunque no haya ultima hora`() {
        assertEquals(at(14, 13, 55), Slots.latestAtOrBefore(at(14, 16), MADRID, 3))
        assertEquals(at(13, 18, 55), Slots.latestAtOrBefore(at(14, 7), MADRID, 3))
        assertEquals(at(14, 8, 55), Slots.latestAtOrBefore(at(14, 8, 55), MADRID, 1))
    }

    @Test
    fun `CA-019-14 la zona cambiada +8 h no inventa horas debidas`() {
        // Ultima atendida: ahora mismo (10:00 de Madrid). En Singapur son las 16:00: nada debido.
        val singapore = ZoneId.of("Asia/Singapore")
        val now = at(14, 10)
        assertNull(Slots.latestDue(now, now, singapore, 3))
    }
}
