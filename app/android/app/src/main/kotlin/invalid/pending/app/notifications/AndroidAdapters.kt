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
 * Las letras completas de un texto con ICU de Android (`android.icu`, API 24): un emoji con ZWJ, una
 * letra con su acento o una bandera son una. La partición real se mira en el emulador (T-019-14);
 * las pruebas JVM usan un doble (`TestGraphemeSplitter`).
 */
object IcuGraphemeSplitter : GraphemeSplitter {
    override fun boundaries(text: String): IntArray {
        val iterator = android.icu.text.BreakIterator.getCharacterInstance(Locale.ROOT)
        iterator.setText(text)
        val out = ArrayList<Int>()
        out += iterator.first()
        var next = iterator.next()
        while (next != android.icu.text.BreakIterator.DONE) {
            out += next
            next = iterator.next()
        }
        return out.toIntArray()
    }
}

/** Arma el orquestador con los adaptadores de Android. */
object WakeRuntime {
    fun create(context: Context): WakeHandler {
        val strings = ResourceStrings(context)
        return WakeHandler(
            clock = AndroidClock,
            store = DerivedStores.open(context),
            taskReader = BoundedTaskReader({ SqliteRowSource(context) }, IcuGraphemeSplitter),
            alarms = AlarmArm(context),
            notifier = NotificationPoster(context, strings, AndroidSystemLocale),
            systemLocale = AndroidSystemLocale,
            strings = strings,
        )
    }
}
