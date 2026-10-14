package invalid.pending.app.notifications

import android.app.PendingIntent
import android.content.Intent

/** Qué clase de componente recibe la orden. */
enum class PendingKind { BROADCAST, ACTIVITY }

/** Los únicos destinos posibles: componentes de **esta** app (los adaptadores los traducen a su clase). */
enum class PendingTarget { WAKE_RECEIVER, MAIN_ACTIVITY }

/**
 * La descripción pura de una orden (`PendingIntent`) que la app deja al sistema (CA-020-28, plan
 * §3.3, 12b). Es siempre **explícita** ([target] es un componente propio, nunca una acción que
 * resuelva otra app), de acción fija, sin datos y con [flags] que incluyen `FLAG_IMMUTABLE` y
 * nunca `FLAG_MUTABLE`. [nonceExtra] es el nombre del extra que lleva el `nonce` (el valor lo pone
 * el adaptador al crearla). Los adaptadores ([AlarmArm], [NotificationPoster]) solo traducen esto.
 */
data class IntentSpec(
    val kind: PendingKind,
    val target: PendingTarget,
    val action: String,
    val requestCode: Int,
    /** Los *flags* de `PendingIntent.get*`. */
    val flags: Int,
    /** Los *flags* del `Intent` (`FLAG_ACTIVITY_*`); 0 si no lleva. */
    val intentFlags: Int = 0,
    val nonceExtra: String? = null,
)

/** Las dos órdenes de la app (y ninguna más): la alarma de la próxima notificación y «abrir». */
object IntentSpecs {
    /** Distinto del de abrir: son `PendingIntent` de otro tipo, pero así no hay duda. */
    private const val ALARM_REQUEST_CODE = 1
    private const val OPEN_REQUEST_CODE = 2

    /**
     * La alarma inexacta que despierta al receptor. Con [create] a `false` (cancelar) no crea
     * nada: si no hay alarma programada, no hay nada que cancelar.
     */
    fun wakeAlarm(create: Boolean): IntentSpec =
        IntentSpec(
            kind = PendingKind.BROADCAST,
            target = PendingTarget.WAKE_RECEIVER,
            action = WakeActions.ALARM,
            requestCode = ALARM_REQUEST_CODE,
            flags = (if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE) or
                PendingIntent.FLAG_IMMUTABLE,
        )

    /**
     * Tocar la notificación abre la app: acción fija de [ActivationNonce] y un `nonce` nuevo.
     * `UPDATE_CURRENT` es necesario: la igualdad de un `PendingIntent` ignora los extras, y sin
     * ello el sistema reutilizaría el anterior con el `nonce` viejo. Sin datos de la tarea ni
     * otros parámetros (CA-019-20).
     */
    fun openCurrentTask(): IntentSpec =
        IntentSpec(
            kind = PendingKind.ACTIVITY,
            target = PendingTarget.MAIN_ACTIVITY,
            action = ActivationNonce.ACTION,
            requestCode = OPEN_REQUEST_CODE,
            flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            intentFlags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP,
            nonceExtra = ActivationNonce.EXTRA,
        )
}
