package invalid.pending.app.notifications

import java.time.Duration
import java.time.Instant
import java.time.ZoneId

/** Por qué se despertó el receptor (plan §3.2: lista blanca de difusiones y la alarma propia). */
enum class WakeReason {
    ALARM,
    LOCKED_BOOT_COMPLETED,
    BOOT_COMPLETED,
    PACKAGE_REPLACED,
    TIME_SET,
    TIMEZONE_CHANGED,
    LOCALE_CHANGED,
}

/** El idioma **elegido** para la notificación (015, ADR-0023): `system`, `es` o `en`. */
enum class LanguageChoice(val stored: String) {
    SYSTEM("system"),
    ES("es"),
    EN("en"),
    ;

    companion object {
        /** Entrada no fiable: cualquier cosa que no sea exactamente `es` o `en` es `system` (CA-019-05). */
        fun fromStored(raw: Any?): LanguageChoice =
            entries.firstOrNull { it.stored == raw } ?: SYSTEM
    }
}

/** Lo que Dart guardó para programar los avisos (copia derivada, CA-019-23). */
data class NotificationConfig(val on: Boolean, val perDay: Int, val language: LanguageChoice) {
    companion object {
        /** Falta o ilegible = apagado (CA-019-05, CA-019-23). */
        val OFF = NotificationConfig(on = false, perDay = NotificationTimes.MIN_PER_DAY, LanguageChoice.SYSTEM)
    }
}

/** Resultado de leer la tarea actual al llegar la hora (CA-019-15, 16, 30). */
sealed interface TaskRead {
    /** Hay tarea actual; [label] es su etiqueta ya calculada o `null` si no tiene (grupo, adjunto raro). */
    data class Task(val label: TaskLabel?) : TaskRead

    /** La base se leyó y no queda ninguna tarea pendiente. */
    data object NoTask : TaskRead

    /** No se pudo leer (antes del primer desbloqueo, base ocupada, corrupta, esquema ajeno…). */
    data object Unreadable : TaskRead
}

/** Qué versión de la notificación sale (CA-019-16, 17, 30). */
sealed interface Display {
    /** La completa, con la etiqueta de la tarea (la pública sigue siendo la genérica). */
    data class Full(val label: TaskLabel) : Display

    /** «Tarea actual» / «Tienes una tarea pendiente.» sin ninguna parte de la tarea. */
    data object Generic : Display
}

/** Todo lo que [WakeDecision.decide] necesita; la lectura de la tarea es perezosa (solo si hace falta). */
data class WakeInput(
    val reason: WakeReason,
    val sinceBoot: Duration,
    val config: NotificationConfig,
    val lastAttended: Instant?,
    val foregroundAt: Instant?,
    val now: Instant,
    val zone: ZoneId,
    val canNotify: Boolean,
    val readTask: () -> TaskRead,
)

/**
 * Lo que hay que hacer: [display] (`null` = no mostrar nada), la nueva «última hora atendida»
 * ([newLastAttended], `null` = dejarla como está) y la siguiente hora a armar ([next], `null` =
 * no tocar la alarma).
 */
data class WakeOutcome(
    val display: Display?,
    val newLastAttended: Instant?,
    val next: Instant?,
) {
    companion object {
        val NOTHING = WakeOutcome(null, null, null)
    }
}

/**
 * La decisión al despertar, **pura** (plan §3.2, CA-019-12 a 15, 19a, 30): sin reloj, sin
 * almacén y sin Android; el [WakeHandler] le da todo hecho.
 */
object WakeDecision {
    /** N de P-019-5: un indicador de «a la vista» con más de 12 min se ignora (ante la duda, se notifica). */
    val FOREGROUND_FRESH: Duration = Duration.ofMinutes(12)

    /** Un cambio de hora o de huso en los 3 primeros minutos tras el arranque se trata como el arranque (NTP). */
    val BOOT_WINDOW: Duration = Duration.ofMinutes(3)

    fun decide(input: WakeInput): WakeOutcome {
        val now = input.now
        val config = input.config
        // Con el ajuste apagado el receptor es un no-op total (no reprograma ni anota nada).
        if (!config.on) return WakeOutcome.NOTHING
        // El cambio de idioma solo refresca el canal (lo hace el orquestador).
        if (input.reason == WakeReason.LOCALE_CHANGED) return WakeOutcome.NOTHING

        val next = Slots.next(now, input.zone, config.perDay)

        // Solo estos despertares implican que el proceso o el móvil estuvieron parados y miran lo perdido.
        val evaluatesMissed =
            when (input.reason) {
                WakeReason.ALARM,
                WakeReason.LOCKED_BOOT_COMPLETED,
                WakeReason.BOOT_COMPLETED,
                WakeReason.PACKAGE_REPLACED -> true
                WakeReason.TIME_SET,
                WakeReason.TIMEZONE_CHANGED -> input.sinceBoot < BOOT_WINDOW
                WakeReason.LOCALE_CHANGED -> false
            }
        // Un cambio de hora o de huso lejos del arranque no recupera nada (CL-019-4): avanza y reprograma.
        if (!evaluatesMissed) return WakeOutcome(null, now, next)

        // Una «última hora» futura o ilegible se ignora (CA-019-14).
        val last = input.lastAttended?.takeIf { !it.isAfter(now) }
        val due =
            if (input.reason == WakeReason.ALARM && last == null) {
                // La propia alarma es la prueba de que una hora toca: no se traga la notificación
                // por faltar o ser ilegible la copia.
                Slots.latestAtOrBefore(now, input.zone, config.perDay)
            } else {
                Slots.latestDue(now, last, input.zone, config.perDay)
            }
        if (due == null) return WakeOutcome(null, null, next)

        // Saltada a propósito: sigue «atendida» y no se recupera después (CA-019-14).
        if (foregroundFresh(input) || !input.canNotify) return WakeOutcome(null, now, next)

        val display: Display? =
            if (input.reason == WakeReason.LOCKED_BOOT_COMPLETED) {
                // La base no se puede abrir hasta el primer desbloqueo: ni se intenta (CA-019-30).
                Display.Generic
            } else {
                when (val read = input.readTask()) {
                    is TaskRead.NoTask -> null
                    is TaskRead.Unreadable -> Display.Generic
                    is TaskRead.Task -> read.label?.let { Display.Full(it) } ?: Display.Generic
                }
            }
        return WakeOutcome(display, now, next)
    }

    private fun foregroundFresh(input: WakeInput): Boolean {
        val at = input.foregroundAt ?: return false
        // En un arranque del móvil la app no puede estar a la vista, diga lo que diga el indicador.
        if (input.reason == WakeReason.LOCKED_BOOT_COMPLETED || input.reason == WakeReason.BOOT_COMPLETED) {
            return false
        }
        val boot = input.now.minus(input.sinceBoot)
        if (!at.isAfter(boot)) return false
        if (at.isAfter(input.now)) return false
        return Duration.between(at, input.now) <= FOREGROUND_FRESH
    }
}
