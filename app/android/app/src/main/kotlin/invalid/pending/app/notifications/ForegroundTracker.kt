package invalid.pending.app.notifications

import java.time.Duration

/** Un único latido pendiente; el adaptador de Android usa un `Handler` del hilo principal. */
interface HeartbeatTimer {
    /** Pide [action] dentro de [delay], sustituyendo cualquier latido pendiente. */
    fun schedule(delay: Duration, action: () -> Unit)

    fun cancel()
}

/**
 * «La app está a la vista» (plan §3.5, P-019-5, CA-019-19a): la hora `foregroundAt` de la copia
 * derivada, que el receptor lee para no avisar de lo que el usuario ya está viendo.
 *
 * - [setVisible] guarda lo que dice Dart (`setForeground`).
 * - [onStop] la limpia (cubre pantalla apagada, otra app e inicio) y [onResume] la restaura
 *   **solo si Dart la había marcado visible**. `onPause` no se usa: el diálogo del permiso y la
 *   cortina de notificaciones pausan la actividad sin sacar la app de la vista.
 * - Mientras esté a la vista y el ajuste encendido, un latido de [HEARTBEAT] la renueva: si el
 *   proceso muere con la app delante, pasados ~12 min vuelve a notificarse (ante la duda, se avisa).
 * - Con el ajuste apagado no se escribe nada (el receptor no hace nada con él apagado).
 *
 * Solo escribe `foregroundAt` (CA-019-23). Núcleo puro, sin `android.*`.
 */
class ForegroundTracker(
    private val clock: Clock,
    private val store: DerivedStore,
    private val timer: HeartbeatTimer,
) {
    private var dartVisible = false
    private var stopped = false

    fun setVisible(visible: Boolean) {
        dartVisible = visible
        refresh()
    }

    fun onStop() {
        stopped = true
        refresh()
    }

    fun onResume() {
        stopped = false
        if (dartVisible) refresh()
    }

    /** Tras `configure` desde Dart: el ajuste pudo cambiar (encender arranca el latido; apagar lo para). */
    fun onConfigured() = refresh()

    fun dispose() = timer.cancel()

    private fun refresh() {
        val state = store.read()
        if (!state.config.on) {
            timer.cancel()
            return
        }
        if (dartVisible && !stopped) {
            store.writeForegroundAt(clock.now())
            timer.schedule(HEARTBEAT, ::refresh)
        } else {
            timer.cancel()
            if (state.foregroundAt != null) store.writeForegroundAt(null)
        }
    }

    companion object {
        val HEARTBEAT: Duration = Duration.ofMinutes(5)
    }
}
