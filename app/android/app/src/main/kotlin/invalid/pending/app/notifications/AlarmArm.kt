package invalid.pending.app.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.time.Instant

/**
 * Arma la **única** alarma pendiente (plan §1): la de la próxima hora de notificación. Siempre
 * **inexacta** (`setAndAllowWhileIdle`, CA-019-11): la app no pide alarmas exactas ni ningún
 * permiso para ello, y el sistema puede agrupar y retrasar el aviso. El `PendingIntent` es
 * explícito (al [WakeReceiver] de esta app) e inmutable; nadie más puede cambiarlo.
 */
class AlarmArm(private val context: Context) : AlarmScheduler {
    override fun scheduleInexact(at: Instant): Boolean {
        return try {
            val manager = context.getSystemService(AlarmManager::class.java) ?: return false
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.toEpochMilli(), pendingIntent())
            true
        } catch (_: Throwable) {
            false
        }
    }

    override fun cancel() {
        try {
            // Sin crear nada: si no hay alarma programada, no hay nada que cancelar.
            val existing = pendingIntent(IntentSpecs.wakeAlarm(create = false)) ?: return
            context.getSystemService(AlarmManager::class.java)?.cancel(existing)
        } catch (_: Throwable) {
            // Sin registro (CA-019-23): la defensa de CA-019-02 no muestra nada si el ajuste está apagado.
        }
    }

    private fun pendingIntent(): PendingIntent =
        pendingIntent(IntentSpecs.wakeAlarm(create = true)) ?: error("PendingIntent")

    /** Traduce la descripción pura (CA-020-28): destino explícito, acción fija y los *flags* de [spec]. */
    private fun pendingIntent(spec: IntentSpec): PendingIntent? {
        require(spec.kind == PendingKind.BROADCAST && spec.target == PendingTarget.WAKE_RECEIVER) { "destino" }
        val intent = Intent(context, WakeReceiver::class.java).setAction(spec.action)
        return PendingIntent.getBroadcast(context, spec.requestCode, intent, spec.flags)
    }
}
