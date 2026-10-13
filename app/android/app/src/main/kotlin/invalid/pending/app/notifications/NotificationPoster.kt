package invalid.pending.app.notifications

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.text.SpannableString
import android.text.Spanned
import android.text.style.LocaleSpan
import androidx.core.app.NotificationCompat
import invalid.pending.app.MainActivity
import invalid.pending.app.R
import java.util.Locale

/**
 * El `Poster` de Android (plan §1, §3.4): **solo traduce** un [NotificationSpec] que el núcleo
 * construyó y JUnit comprobó a objetos del sistema; no decide nada. Un canal único, la versión
 * completa (privada, con `BigTextStyle` para leer los 120 caracteres con texto grande), la versión
 * pública (genérica) para el móvil bloqueado con el contenido oculto, `LocaleSpan` donde el núcleo
 * marcó el idioma, `setLocalOnly`, un identificador fijo, sin acciones ni insignia, y un
 * `PendingIntent` explícito e inmutable que lleva el `nonce` de [ActivationNonce].
 *
 * Sin registro de nada (CA-019-23); los fallos salen hacia [WakeHandler], que los trata.
 */
class NotificationPoster(
    private val context: Context,
    private val strings: NotificationStringSource,
    private val systemLocale: SystemLocale,
) : Notifier {
    private val manager: NotificationManager
        get() = requireNotNull(context.getSystemService(NotificationManager::class.java)) { "sin NotificationManager" }

    /** Permiso concedido (Android 13+), avisos de la app no apagados y canal no apagado. No crea el canal. */
    override fun canNotify(): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (!manager.areNotificationsEnabled()) return false
        val channel = manager.getNotificationChannel(NotificationSpec.CHANNEL_ID)
        return channel == null || channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    override fun show(spec: NotificationSpec) {
        require(spec.actions.isEmpty() && !spec.showBadge) { "sin acciones ni insignia (CA-019-18)" }
        ensureChannel(spec.channel)
        manager.notify(spec.id, build(spec))
    }

    /** Quita la notificación de la bandeja y el `nonce` que la acompañaba. */
    override fun cancelDelivered() {
        ActivationNonce.clear()
        manager.cancel(NotificationSpec.ID)
    }

    /** Nombre y descripción del canal en el idioma **del sistema** (CA-019-21); también lo crea si no existe. */
    override fun refreshChannel() = ensureChannel()

    /**
     * Crea el canal (o actualiza su nombre y descripción: el resto lo decide el usuario en los
     * Ajustes del sistema y Android no lo cambia al volver a crearlo). Se llama al encender y con la
     * primera notificación.
     */
    fun ensureChannel() {
        val spec = NotificationSpec.build(Display.Generic, LanguageChoice.SYSTEM, systemLocale.languageTags(), strings)
        ensureChannel(spec.channel)
    }

    private fun ensureChannel(spec: ChannelSpec) {
        // Importancia por defecto y **sin tocar** sonido, vibración ni luz: la app no pone nada propio
        // y se oye lo que el usuario tenga para el canal en el sistema (CA-019-22).
        require(!spec.sound && !spec.vibration && !spec.lights) { "sin sonido, vibración ni luz propios (CA-019-22)" }
        val channel = NotificationChannel(spec.id, spec.name, NotificationManager.IMPORTANCE_DEFAULT)
        channel.description = spec.description
        channel.setShowBadge(spec.showBadge)
        channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        manager.createNotificationChannel(channel)
    }

    private fun build(spec: NotificationSpec): Notification {
        val text = spec.text
        val body = span(text.body)
        val publicVersion =
            NotificationCompat
                .Builder(context, spec.channel.id)
                .setSmallIcon(R.drawable.ic_stat_una)
                .setColor(accent())
                .setContentTitle(span(text.publicTitle))
                .setContentText(span(text.publicBody))
                .build()
        val builder =
            NotificationCompat
                .Builder(context, spec.channel.id)
                .setSmallIcon(R.drawable.ic_stat_una)
                .setColor(accent())
                .setContentTitle(span(text.title))
                .setContentText(body)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setPublicVersion(publicVersion)
                .setLocalOnly(spec.localOnly)
                .setAutoCancel(true)
                .setOnlyAlertOnce(false)
                .setContentIntent(contentIntent())
        if (spec.bigText) builder.setStyle(NotificationCompat.BigTextStyle().bigText(body))
        return builder.build()
    }

    /** El amarillo del icono (`palette.classic.0`), el mismo recurso que genera `gen_icons.dart`. */
    private fun accent(): Int = context.getColor(R.color.ic_launcher_background)

    /** El texto con su idioma marcado para el lector de pantalla, solo si el núcleo lo pidió (CA-019-21). */
    private fun span(piece: Piece): CharSequence {
        val language = piece.language
        if (!piece.marked || language == null || piece.text.isEmpty()) return piece.text
        return SpannableString(piece.text).apply {
            setSpan(LocaleSpan(Locale.forLanguageTag(language.tag)), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    /**
     * Tocarla abre la app: `PendingIntent` **explícito** a `MainActivity`, acción fija y un `nonce`
     * nuevo. `UPDATE_CURRENT` es necesario: la igualdad de un `PendingIntent` ignora los extras, y
     * sin ello el sistema reutilizaría el anterior con el `nonce` viejo. `IMMUTABLE`: nadie puede
     * cambiarlo. Sin datos de la tarea ni otros parámetros (CA-019-20).
     */
    private fun contentIntent(): PendingIntent {
        val intent =
            Intent(context, MainActivity::class.java)
                .setAction(ActivationNonce.ACTION)
                .putExtra(ActivationNonce.EXTRA, ActivationNonce.issue())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        /** Distinto del de la alarma (1): son `PendingIntent` de otro tipo, pero así no hay duda. */
        const val REQUEST_CODE = 2
    }
}
