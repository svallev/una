package invalid.pending.app.notifications

import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import android.os.SystemClock
import invalid.pending.app.R
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.util.Locale

// Adaptadores finos de Android para los puertos del núcleo (plan §1, punto 2). Sin lógica.

/** El reloj del móvil. */
object AndroidClock : Clock {
    override fun now(): Instant = Instant.now()

    override fun zone(): ZoneId = ZoneId.systemDefault()

    override fun sinceBoot(): Duration = Duration.ofMillis(SystemClock.elapsedRealtime())
}

/** Los idiomas del sistema en orden de preferencia (no los de la app: el elegido va en la copia derivada). */
object AndroidSystemLocale : SystemLocale {
    override fun languageTags(): List<String> {
        val locales = Resources.getSystem().configuration.locales
        return (0 until locales.size()).map { locales.get(it).toLanguageTag() }
    }
}

/** Los textos de `res/values` y `res/values-es` (generados de los ARB) en el idioma pedido, no en el del sistema. */
class ResourceStrings(private val context: Context) : NotificationStringSource {
    override fun strings(language: AppLanguage): NotificationStrings {
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(Locale.forLanguageTag(language.tag))
        val resources = context.createConfigurationContext(configuration).resources
        return NotificationStrings(
            channelName = resources.getString(R.string.notification_channel_name),
            channelDescription = resources.getString(R.string.notification_channel_description),
            title = resources.getString(R.string.notification_title),
            publicText = resources.getString(R.string.notification_public),
            photo = resources.getString(R.string.attachment_photo),
            image = resources.getString(R.string.attachment_image),
            pdf = resources.getString(R.string.attachment_pdf),
        )
    }
}

/**
 * Marcador hasta T-019-07 (lector de la base): ninguna tarea se lee todavía. Con
 * [PendingNotifier] no se muestra nada, así que da igual lo que devuelva.
 */
object PendingTaskReader : TaskReader {
    override fun read(): TaskRead = TaskRead.Unreadable
}

/** Marcador hasta T-019-07 (`NotificationPoster`): no puede notificar, así que cada hora sale como saltada. */
object PendingNotifier : Notifier {
    override fun canNotify(): Boolean = false

    override fun show(spec: NotificationSpec) = Unit

    override fun cancelDelivered() = Unit

    override fun refreshChannel() = Unit
}

/** Arma el orquestador con los adaptadores de Android. */
object WakeRuntime {
    fun create(context: Context): WakeHandler =
        WakeHandler(
            clock = AndroidClock,
            store = DerivedStores.open(context),
            taskReader = PendingTaskReader,
            alarms = AlarmArm(context),
            notifier = PendingNotifier,
            systemLocale = AndroidSystemLocale,
            strings = ResourceStrings(context),
        )
}
