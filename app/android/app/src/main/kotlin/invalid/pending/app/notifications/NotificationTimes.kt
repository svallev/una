package invalid.pending.app.notifications

import java.time.LocalTime

/**
 * Las tres horas **fijas** a las que puede llegar una notificación, en hora local del móvil
 * (D25, CA-019-10): con 1 al día, la primera; con 2, las dos primeras; con 3, las tres.
 *
 * Es la fuente nativa de la verdad; la ayuda de Ajustes (Dart, `NotificationSchedule`) las repite y
 * una prueba de Dart compara ambas (plan §5). Núcleo puro: sin `android.*` (plan §1).
 */
object NotificationTimes {
    const val MIN_PER_DAY = 1
    const val MAX_PER_DAY = 3

    val ALL: List<LocalTime> =
        listOf(LocalTime.of(8, 55), LocalTime.of(13, 55), LocalTime.of(18, 55))

    /** Las horas de [perDay] notificaciones al día; vacío si no está en 1..3 (entrada no fiable). */
    fun forCount(perDay: Int): List<LocalTime> =
        if (isValidCount(perDay)) ALL.take(perDay) else emptyList()

    fun isValidCount(perDay: Int): Boolean = perDay in MIN_PER_DAY..MAX_PER_DAY
}
