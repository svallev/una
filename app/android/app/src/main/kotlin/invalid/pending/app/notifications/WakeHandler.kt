package invalid.pending.app.notifications

import java.time.Duration
import java.time.Instant
import java.time.ZoneId

// Puertos del orquestador (plan §1, §3.2). Sin `android.*`: los adaptadores de Android (T-019-06 y
// siguientes) los implementan y las pruebas JVM usan falsos.

/** El reloj del móvil: instante, zona actual y tiempo desde el arranque (`elapsedRealtime`). */
interface Clock {
    fun now(): Instant

    fun zone(): ZoneId

    fun sinceBoot(): Duration
}

/** Lo guardado fuera de la base (CA-019-23). Ya validado: lo raro llega como apagado o `null`. */
data class DerivedState(
    val config: NotificationConfig,
    val lastAttended: Instant?,
    val foregroundAt: Instant?,
)

/** La copia derivada, accesible antes del primer desbloqueo. **Nunca** guarda texto de tareas. */
interface DerivedStore {
    fun read(): DerivedState

    /** Escribe de forma duradera; `false` si falló (forma parte del todo o nada de CA-019-02). */
    fun writeConfig(config: NotificationConfig): Boolean

    fun writeLastAttended(at: Instant)

    /** `null` = la app no está a la vista. */
    fun writeForegroundAt(at: Instant?)
}

/** Lee la tarea actual al llegar la hora; cualquier fallo es [TaskRead.Unreadable]. */
interface TaskReader {
    fun read(): TaskRead
}

/** Una sola alarma pendiente, **siempre inexacta** (CA-019-11): no existe una llamada exacta. */
interface AlarmScheduler {
    /** Pide (y sustituye la anterior) una alarma inexacta en [at]; `false` si el sistema no la admite. */
    fun scheduleInexact(at: Instant): Boolean

    fun cancel()
}

/** Lo que el notificador necesita para dibujar la notificación (el texto lo resuelve T-019-05). */
data class NotificationRequest(
    val display: Display,
    val language: LanguageChoice,
    val systemLanguageTags: List<String>,
)

interface Notifier {
    /** ¿Permiso concedido y canal no apagado? (no crea el canal). */
    fun canNotify(): Boolean

    fun show(request: NotificationRequest)

    /** Quita la notificación de la bandeja. */
    fun cancelDelivered()

    /** Refresca nombre y descripción del canal al cambiar el idioma del sistema (CA-019-21). */
    fun refreshChannel()
}

/** Los idiomas del sistema en orden de preferencia, como etiquetas BCP-47 (`es-ES`, `ca`, `en-GB`…). */
interface SystemLocale {
    fun languageTags(): List<String>
}

/**
 * El orquestador (plan §3.2): lee la copia derivada, decide con [WakeDecision], avisa y rearma.
 * Es la implementación que corre con la app cerrada; nada de la lógica vive en Dart.
 *
 * Sin registro de ningún tipo (CA-019-23): los fallos se tragan, no se anotan. El receptor de
 * Android lo envuelve además en `try/catch (Throwable)`.
 */
class WakeHandler(
    private val clock: Clock,
    private val store: DerivedStore,
    private val taskReader: TaskReader,
    private val alarms: AlarmScheduler,
    private val notifier: Notifier,
    private val systemLocale: SystemLocale,
) {
    /** Atiende un despertar: decide, anota la «última hora atendida», rearma la siguiente y muestra. */
    fun onWake(reason: WakeReason) {
        val state = store.read()
        if (!state.config.on) return // no-op total (plan §3.2)
        if (reason == WakeReason.LOCALE_CHANGED) {
            notifier.refreshChannel()
            return
        }

        val boot = reason == WakeReason.LOCKED_BOOT_COMPLETED || reason == WakeReason.BOOT_COMPLETED
        if (boot && state.foregroundAt != null) store.writeForegroundAt(null)

        val outcome =
            WakeDecision.decide(
                WakeInput(
                    reason = reason,
                    sinceBoot = clock.sinceBoot(),
                    config = state.config,
                    lastAttended = state.lastAttended,
                    foregroundAt = if (boot) null else state.foregroundAt,
                    now = clock.now(),
                    zone = clock.zone(),
                    canNotify = safeCanNotify(),
                    readTask = ::safeRead,
                ),
            )

        // Orden: primero lo que no debe repetirse ni perderse (última hora y siguiente alarma);
        // mostrar va al final porque puede tardar o fallar.
        outcome.newLastAttended?.let(store::writeLastAttended)
        outcome.next?.let { alarms.scheduleInexact(it) }
        outcome.display?.let { display ->
            try {
                notifier.show(NotificationRequest(display, state.config.language, systemLocale.languageTags()))
            } catch (_: Throwable) {
                // Sin registro (CA-019-23): la hora ya quedó atendida y la siguiente armada.
            }
        }
    }

    /**
     * Aplica la configuración que manda Dart (encender, cambiar, apagar o arranque de la app):
     * guarda, rearma o cancela. **No** evalúa lo perdido; si encender, apagar o cambiar la cantidad
     * modifica algo, la «última hora» avanza a ahora (CA-019-12, 14). `false` si falla cualquier
     * paso (Dart lo deshace).
     */
    fun configure(config: NotificationConfig): Boolean {
        if (!NotificationTimes.isValidCount(config.perDay)) return false
        val old = store.read()
        val now = clock.now()
        if (!store.writeConfig(config)) return false

        val lastUnusable = old.lastAttended == null || old.lastAttended.isAfter(now)
        val changed = old.config.on != config.on || old.config.perDay != config.perDay
        if (changed || lastUnusable) store.writeLastAttended(now)

        if (!config.on) {
            alarms.cancel()
            if (old.config.on) notifier.cancelDelivered()
            return true
        }
        val next = Slots.next(now, clock.zone(), config.perDay) ?: return false
        return alarms.scheduleInexact(next)
    }

    private fun safeCanNotify(): Boolean =
        try {
            notifier.canNotify()
        } catch (_: Throwable) {
            false
        }

    private fun safeRead(): TaskRead =
        try {
            taskReader.read()
        } catch (_: Throwable) {
            TaskRead.Unreadable
        }
}
