package invalid.pending.app.notifications

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

// Falsos y ayudas compartidos por las pruebas JVM del núcleo (spec 019, plan §5). Sin `android.*`.

val MADRID: ZoneId = ZoneId.of("Europe/Madrid")

/** Un instante a partir de una fecha y hora **locales** de [zone] (por defecto Madrid, CEST en octubre). */
fun at(
    day: Int,
    hour: Int,
    minute: Int = 0,
    zone: ZoneId = MADRID,
    month: Int = 10,
    year: Int = 2026,
): Instant =
    ZonedDateTime.of(LocalDate.of(year, month, day), LocalTime.of(hour, minute), zone).toInstant()

/** Reloj falso: el instante, la zona y el tiempo desde el arranque los mueve la prueba. */
class FakeClock(
    var now: Instant,
    var zone: ZoneId = MADRID,
    var sinceBoot: Duration = Duration.ofHours(5),
) : Clock {
    override fun now(): Instant = now

    override fun zone(): ZoneId = zone

    override fun sinceBoot(): Duration = sinceBoot
}

/** Copia derivada falsa: guarda el estado y anota qué se escribe y con qué texto. */
class FakeStore(
    var state: DerivedState = DerivedState(NotificationConfig.OFF, null, null),
) : DerivedStore {
    /** Todo lo escrito, en texto, para buscar contenido que no debe estar (CA-019-23). */
    val written = mutableListOf<String>()
    var failConfigWrite = false

    override fun read(): DerivedState = state

    override fun writeConfig(config: NotificationConfig): Boolean {
        written += "config:$config"
        if (failConfigWrite) return false
        state = state.copy(config = config)
        return true
    }

    override fun writeLastAttended(at: Instant) {
        written += "lastAttended:$at"
        state = state.copy(lastAttended = at)
    }

    override fun writeForegroundAt(at: Instant?) {
        written += "foregroundAt:$at"
        state = state.copy(foregroundAt = at)
    }

    val lastAttended: Instant? get() = state.lastAttended
}

class FakeTaskReader(
    var result: TaskRead = TaskRead.NoTask,
    var failure: Throwable? = null,
) : TaskReader {
    var reads = 0

    override fun read(): TaskRead {
        reads++
        failure?.let { throw it }
        return result
    }
}

/** Programador falso: solo existe la llamada inexacta (CA-019-11). */
class FakeScheduler : AlarmScheduler {
    val armed = mutableListOf<Instant>()
    var cancels = 0
    var failArm = false

    override fun scheduleInexact(at: Instant): Boolean {
        if (failArm) return false
        armed += at
        return true
    }

    override fun cancel() {
        cancels++
    }

    val last: Instant? get() = armed.lastOrNull()
}

class FakeNotifier : Notifier {
    var canNotify = true
    val shown = mutableListOf<NotificationRequest>()
    var delivered = 0
    var cancelDelivered = 0
    var channelRefreshes = 0
    var showFailure: Throwable? = null

    override fun canNotify(): Boolean = canNotify

    override fun show(request: NotificationRequest) {
        showFailure?.let { throw it }
        shown += request
        delivered++
    }

    override fun cancelDelivered() {
        cancelDelivered++
    }

    override fun refreshChannel() {
        channelRefreshes++
    }
}

class FakeLocale(var tags: List<String> = listOf("en")) : SystemLocale {
    override fun languageTags(): List<String> = tags
}

/** Todo el montaje de un [WakeHandler] con falsos. */
class Rig(
    now: Instant,
    config: NotificationConfig = NotificationConfig(true, 1, LanguageChoice.SYSTEM),
    lastAttended: Instant? = null,
    foregroundAt: Instant? = null,
    task: TaskRead = TaskRead.Task("Llamar a Marta"),
) {
    val clock = FakeClock(now)
    val store = FakeStore(DerivedState(config, lastAttended, foregroundAt))
    val reader = FakeTaskReader(task)
    val scheduler = FakeScheduler()
    val notifier = FakeNotifier()
    val locale = FakeLocale()
    val handler = WakeHandler(clock, store, reader, scheduler, notifier, locale)

    fun wake(reason: WakeReason, now: Instant = clock.now) {
        clock.now = now
        handler.onWake(reason)
    }

    fun configure(config: NotificationConfig, now: Instant = clock.now): Boolean {
        clock.now = now
        return handler.configure(config)
    }
}

fun cfg(perDay: Int, on: Boolean = true, lang: LanguageChoice = LanguageChoice.SYSTEM) =
    NotificationConfig(on, perDay, lang)
