package invalid.pending.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Canal `una/links` (spec 008, CA-008-12; spec 012, CA-012-04): abre un enlace
 * ya comprobado en Dart y dice antes si hay app que lo abra. Por aquí pasan hoy
 * dos caminos, y no son iguales (CA-020-18):
 * - **Ajustes** (política, licencias, ayuda): **sin** confirmación (CA-015-12a);
 *   las direcciones son constantes de compilación y la regla `https` sin usuario
 *   (`privacyLink`) vive solo en Dart; repetirla aquí es un residual aceptado
 *   (012-S1).
 * - **Enlaces del PDF**: **sí** se confirman antes (`LinkPolicy`, CA-008-12) y
 *   admiten `http(s)`, `mailto:` y `tel:` (T-5).
 *
 * (Además, «Abrir en el navegador» de la tarea web manda aquí la dirección
 * guardada de la propia tarea, sin confirmar: spec 009 §5.)
 *
 * Solo tres intents, y solo si hay una app que los atienda (I-7: si no,
 * Android mostraría un selector vacío y en inglés):
 * - `web`: `ACTION_VIEW` + `BROWSABLE`, solo `http`/`https`;
 * - `mail`: `ACTION_SENDTO` con el `mailto:` rehecho (sin adjuntos ni copias);
 * - `tel`: `ACTION_DIAL` (marca, no llama; sin permiso).
 * Métodos: `open` (abre; false si no hay app) y `canOpen` (solo comprueba con el
 * mismo intent que `open`, sin `startActivity`). Nunca registra el enlace
 * (CL-008-11).
 */
class LinkOpener(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "una/links"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> result.success(open(call))
            "canOpen" -> result.success(resolvableIntent(call) != null)
            else -> result.notImplemented()
        }
    }

    /** El intent de la llamada, solo si es de un tipo permitido y hay app que lo atienda. */
    private fun resolvableIntent(call: MethodCall): Intent? {
        val uri = Uri.parse(call.argument<String>("uri") ?: return null)
        val intent = when (call.argument<String>("kind")) {
            "web" -> {
                if (uri.scheme != "https" && uri.scheme != "http") return null
                Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE)
            }
            "mail" -> {
                if (uri.scheme != "mailto") return null
                Intent(Intent.ACTION_SENDTO, uri)
            }
            "tel" -> {
                if (uri.scheme != "tel") return null
                Intent(Intent.ACTION_DIAL, uri)
            }
            else -> return null
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (intent.resolveActivity(activity.packageManager) == null) return null
        return intent
    }

    private fun open(call: MethodCall): Boolean {
        val intent = resolvableIntent(call) ?: return false
        return try {
            activity.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }
}
