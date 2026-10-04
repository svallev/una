package invalid.pending.app

import android.content.Context
import android.os.Build
import android.view.accessibility.AccessibilityManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Canal `una/a11y` (spec 014, CA-014-06; ADR-0021): cuánto tiempo pide el
 * sistema para la card de deshacer. Solo lee `AccessibilityManager` (sin
 * permisos, sin escribir nada, sin oyentes y sin logcat) y devuelve dos
 * hechos; la regla de la duración está en Dart (`UndoDuration`):
 * - `recommendedMs`: el "Tiempo para actuar" para un aviso de 4 s con controles
 *   y texto (`getRecommendedTimeoutMillis`, Android 10 o posterior); null antes,
 *   que el sistema no lo tiene;
 * - `serviceEnabled`: si hay algún servicio de accesibilidad activo (`isEnabled`).
 *   No se guarda ni se registra: dejaría deducir que se usa tecnología de apoyo.
 * Un solo método, `timeouts`, sin argumentos; el resto, `notImplemented`.
 */
class AccessibilityTimeouts(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "una/a11y"

        /** Lo que dura la card por defecto (token `undoWindow`); fijo, no llega de Dart. */
        private const val UNDO_WINDOW_MS = 4000
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "timeouts" -> result.success(timeouts())
            else -> result.notImplemented()
        }
    }

    private fun timeouts(): Map<String, Any?> {
        val none = mapOf("recommendedMs" to null, "serviceEnabled" to false)
        val manager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
            ?: return none
        return try {
            val recommended = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                manager.getRecommendedTimeoutMillis(
                    UNDO_WINDOW_MS,
                    AccessibilityManager.FLAG_CONTENT_CONTROLS or AccessibilityManager.FLAG_CONTENT_TEXT,
                )
            } else {
                null
            }
            mapOf("recommendedMs" to recommended, "serviceEnabled" to manager.isEnabled)
        } catch (e: RuntimeException) {
            // Un fallo del sistema es "nada que alargar" (4 s), sin dejarlo en logcat.
            none
        }
    }
}
