package invalid.pending.app

import android.app.Activity
import android.content.pm.ActivityInfo
import android.provider.Settings
import android.view.OrientationEventListener

/**
 * Giro de la tarea actual con imagen o con PDF (specs 007 y 008, CA-008-11):
 * son las únicas pantallas que giran. Pedir `SCREEN_ORIENTATION_USER` no basta
 * en HyperOS: su sensor de orientación del sistema no avisa hasta el siguiente
 * toque. Mientras se ve, se lee el acelerómetro, como hacen las galerías, y se
 * fija la orientación. Con el bloqueo de rotación del sistema activo, se queda
 * en vertical. Sin permisos.
 *
 * "Volver a vertical" ([backToPortrait]) fija el vertical aunque el móvil siga
 * en horizontal, hasta que el móvil pase por la zona vertical. Ese estado
 * sobrevive a salir de la tarea: si se vuelve con el móvil aún en horizontal,
 * se ve en vertical. Un único estado ([following], [heldPortrait]) para que el
 * sensor y el botón no se pisen.
 */
class AttachmentRotation(private val activity: Activity) {
    private var following = false
    private var heldPortrait = false

    private val listener = object : OrientationEventListener(activity) {
        override fun onOrientationChanged(degrees: Int) {
            if (degrees == ORIENTATION_UNKNOWN) return // Plano sobre la mesa.
            // Márgenes entre zonas para que no oscile cerca de los 45°.
            val zone = when (degrees) {
                in 0..30, in 330..359 -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                in 60..120 -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                in 240..300 -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                else -> return // Boca abajo o entre zonas: sin cambios.
            }
            // El móvil ha pasado por vertical: vuelve a girar solo.
            if (zone == ActivityInfo.SCREEN_ORIENTATION_PORTRAIT) heldPortrait = false
            if (!following) {
                // Solo se escuchaba para saber si pasa por vertical.
                if (!heldPortrait) disable()
                return
            }
            val target = if (heldPortrait || !autoRotate()) {
                ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            } else {
                zone
            }
            if (activity.requestedOrientation != target) activity.requestedOrientation = target
        }
    }

    private fun autoRotate(): Boolean =
        Settings.System.getInt(activity.contentResolver, Settings.System.ACCELEROMETER_ROTATION, 0) == 1

    /** La tarea actual con imagen o PDF se ve ([on] = true) o deja de verse. */
    fun follow(on: Boolean) {
        following = on
        if (!on || heldPortrait) activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        resume()
    }

    /** "Volver a vertical": vertical ya, aunque el móvil siga en horizontal. */
    fun backToPortrait() {
        heldPortrait = true
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        resume()
    }

    /** En segundo plano no se lee el sensor. */
    fun pause() = listener.disable()

    fun resume() {
        if ((following || heldPortrait) && listener.canDetectOrientation()) {
            listener.enable()
        } else {
            listener.disable()
        }
    }
}
