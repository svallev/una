package invalid.pending.app.notifications

import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Cálculo de horas de notificación sobre `java.time` (mínimo API 26). Todo en la zona **actual del
 * móvil**: las horas son del reloj de pared (CA-019-10, CL-019-4). El día de un cambio de horario
 * cada hora existe una sola vez; en un hueco (la hora no existe) `ZonedDateTime` la desplaza hacia
 * delante, y en un solape toma la primera.
 */
object Slots {
    /** La primera hora de las configuradas **estrictamente después** de [now]; `null` si [perDay] no vale. */
    fun next(now: Instant, zone: ZoneId, perDay: Int): Instant? =
        candidates(now, zone, perDay).filter { it.isAfter(now) }.minOrNull()

    /** La más reciente de las configuradas que es ≤ [now]; `null` si [perDay] no vale. */
    fun latestAtOrBefore(now: Instant, zone: ZoneId, perDay: Int): Instant? =
        candidates(now, zone, perDay).filter { !it.isAfter(now) }.maxOrNull()

    /**
     * La hora **debida** (CA-019-14): la más reciente ≤ [now] y > [lastAttended]. Una sola, aunque
     * hayan pasado varias. Sin [lastAttended], o con una futura, no se recupera nada.
     */
    fun latestDue(now: Instant, lastAttended: Instant?, zone: ZoneId, perDay: Int): Instant? {
        if (lastAttended == null || lastAttended.isAfter(now)) return null
        val latest = latestAtOrBefore(now, zone, perDay) ?: return null
        return latest.takeIf { it.isAfter(lastAttended) }
    }

    /** Las horas de ayer, hoy y mañana (locales a [now] en [zone]): cubre cualquier búsqueda. */
    private fun candidates(now: Instant, zone: ZoneId, perDay: Int): List<Instant> {
        val times = NotificationTimes.forCount(perDay)
        if (times.isEmpty()) return emptyList()
        val today = now.atZone(zone).toLocalDate()
        return (-1L..1L).flatMap { offset ->
            val date = today.plusDays(offset)
            times.map { ZonedDateTime.of(date, it, zone).toInstant() }
        }
    }
}
