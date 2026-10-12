package invalid.pending.app.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * El único receptor de los despertares (plan §3.2): no exportado, `directBootAware` (funciona antes
 * del primer desbloqueo) y con lista blanca de acciones ([WakeActions]); cualquier otra se ignora
 * sin evaluar nada. Delega todo en [WakeHandler], en un hilo con `goAsync()` y sin dejar salir
 * ningún error (`Throwable`) ni registrar nada (CA-019-23).
 */
class WakeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val reason = WakeActions.reasonFor(intent?.action) ?: return
        val pending = goAsync()
        val app = context.applicationContext ?: context
        try {
            Thread {
                try {
                    WakeRuntime.create(app).onWake(reason)
                } catch (_: Throwable) {
                    // El proceso del receptor no puede fallar; la próxima llegada reintenta.
                } finally {
                    pending?.finish()
                }
            }.start()
        } catch (_: Throwable) {
            pending?.finish()
        }
    }
}
