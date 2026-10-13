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
            val existing = pendingIntent(PendingIntent.FLAG_NO_CREATE) ?: return
            context.getSystemService(AlarmManager::class.java)?.cancel(existing)
        } catch (_: Throwable) {
            // Sin registro (CA-019-23): la defensa de CA-019-02 no muestra nada si el ajuste está apagado.
        }
    }

    private fun pendingIntent(): PendingIntent =
        pendingIntent(PendingIntent.FLAG_UPDATE_CURRENT) ?: error("PendingIntent")

    private fun pendingIntent(mode: Int): PendingIntent? {
        val intent = Intent(context, WakeReceiver::class.java).setAction(WakeActions.ALARM)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            mode or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        const val REQUEST_CODE = 1
    }
}
