package invalid.pending.app

import android.app.Activity
import android.os.Build
import android.view.WindowManager

/**
 * Oculta el contenido de la app en "Recientes" (spec 011, CA-011-01) sin bloquear
 * las capturas con la app delante (CA-011-04). Sin canal, sin ajuste y sin Dart.
 *
 * - Android 13+ (mecanismo A): `setRecentsScreenshotEnabled(false)` una vez, en
 *   `onCreate`. No toca la ventana.
 * - Android 8-12 (mecanismo B): `FLAG_SECURE` solo mientras la actividad está en
 *   pausa (`onPause` lo pone, `onResume` lo quita). **[Suposición]** sin verificar
 *   en dispositivo hasta PD-10.
 *
 * Regla de desempate de la spec: las capturas mandan sobre el ocultado. Si en 8-12
 * B no oculta la miniatura sin dejar la marca puesta, se acepta verla ahí en la beta.
 */
class RecentsPrivacy(private val activity: Activity) {
    fun onCreate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.setRecentsScreenshotEnabled(false)
        }
    }

    fun onPause() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    fun onResume() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
