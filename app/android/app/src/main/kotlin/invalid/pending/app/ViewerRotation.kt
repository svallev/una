package invalid.pending.app

import android.app.Activity
import android.content.pm.ActivityInfo
import android.provider.Settings
import android.view.OrientationEventListener

/**
 * Giro del visor (spec 007, CA-007-11). Pedir `SCREEN_ORIENTATION_USER` no basta
 * en HyperOS: su sensor de orientación del sistema no avisa hasta el siguiente
 * toque. Se lee el acelerómetro, como hacen las galerías, sin permisos:
 * - con la tarea actual con imagen a la vista ([watch]), girar el móvil a
 *   horizontal avisa a la app ([onLandscape]) para que abra el visor;
 * - con el visor abierto ([follow]), se fija la orientación.
 * Con el bloqueo de rotación del sistema activo, todo queda en vertical.
 */
class ViewerRotation(
    private val activity: Activity,
    private val onLandscape: () -> Unit,
) {
    private var watching = false
    private var following = false
    private var wasLandscape = false

    private val listener = object : OrientationEventListener(activity) {
        override fun onOrientationChanged(degrees: Int) {
            if (degrees == ORIENTATION_UNKNOWN) return // Plano sobre la mesa.
            val target = if (!autoRotate()) {
                ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            } else {
                // Márgenes entre zonas para que no oscile cerca de los 45°.
                when (degrees) {
                    in 0..30, in 330..359 -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                    in 60..120 -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                    in 240..300 -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                    else -> return // Boca abajo o entre zonas: sin cambios.
                }
            }
            val landscape = target != ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            if (following) {
                if (activity.requestedOrientation != target) activity.requestedOrientation = target
            } else if (watching && landscape && !wasLandscape) {
                onLandscape()
            }
            wasLandscape = landscape
        }
    }

    private fun autoRotate(): Boolean =
        Settings.System.getInt(activity.contentResolver, Settings.System.ACCELEROMETER_ROTATION, 0) == 1

    /** La tarea actual con imagen se ve ([on] = true) o deja de verse. */
    fun watch(on: Boolean) {
        // [wasLandscape] guarda la última lectura, también con el visor
        // abierto: cerrado con "Cerrar" en horizontal, no se reabre hasta
        // volver a vertical y girar otra vez.
        watching = on
        update()
    }

    /** El visor se abre ([on] = true) o se cierra. */
    fun follow(on: Boolean) {
        following = on
        if (!on) activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        update()
    }

    /** En segundo plano no se lee el sensor. */
    fun pause() = listener.disable()

    fun resume() = update()

    private fun update() {
        if ((watching || following) && listener.canDetectOrientation()) {
            listener.enable()
        } else {
            listener.disable()
        }
    }
}
