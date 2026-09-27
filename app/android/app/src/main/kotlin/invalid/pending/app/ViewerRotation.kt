package invalid.pending.app

import android.app.Activity
import android.content.pm.ActivityInfo
import android.provider.Settings
import android.view.OrientationEventListener

/**
 * Giro del visor (spec 007, CA-007-11). Pedir `SCREEN_ORIENTATION_USER` no basta
 * en HyperOS: su sensor de orientación del sistema no avisa hasta el siguiente
 * toque. Mientras el visor está abierto se lee el acelerómetro y se fija la
 * orientación, como hacen las galerías. Con el bloqueo de rotación del
 * sistema activo, se queda en vertical. Sin permisos.
 */
class ViewerRotation(private val activity: Activity) {
    private var active = false

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
            if (activity.requestedOrientation != target) activity.requestedOrientation = target
        }
    }

    private fun autoRotate(): Boolean =
        Settings.System.getInt(activity.contentResolver, Settings.System.ACCELEROMETER_ROTATION, 0) == 1

    /** El visor se abre ([on] = true) o se cierra. */
    fun follow(on: Boolean) {
        active = on
        if (on) {
            resume()
        } else {
            listener.disable()
            activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        }
    }

    /** En segundo plano no se lee el sensor. */
    fun pause() = listener.disable()

    fun resume() {
        if (active && listener.canDetectOrientation()) listener.enable()
    }
}
