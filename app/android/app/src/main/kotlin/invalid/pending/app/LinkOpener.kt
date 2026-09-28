package invalid.pending.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Canal `una/links` (spec 008, CA-008-12): abre un enlace de un PDF ya
 * comprobado y confirmado en Dart (`LinkPolicy`). Solo tres intents, y solo si
 * hay una app que los atienda (I-7: si no, Android mostraría un selector vacío
 * y en inglés):
 * - `web`: `ACTION_VIEW` + `BROWSABLE`, solo `http`/`https`;
 * - `mail`: `ACTION_SENDTO` con el `mailto:` rehecho (sin adjuntos ni copias);
 * - `tel`: `ACTION_DIAL` (marca, no llama; sin permiso).
 * Devuelve false si no hay app. Nunca registra el enlace (CL-008-11).
 */
class LinkOpener(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "una/links"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "open") return result.notImplemented()
        val uri = Uri.parse(call.argument<String>("uri") ?: return result.success(false))
        val intent = when (call.argument<String>("kind")) {
            "web" -> {
                if (uri.scheme != "https" && uri.scheme != "http") return result.success(false)
                Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE)
            }
            "mail" -> {
                if (uri.scheme != "mailto") return result.success(false)
                Intent(Intent.ACTION_SENDTO, uri)
            }
            "tel" -> {
                if (uri.scheme != "tel") return result.success(false)
                Intent(Intent.ACTION_DIAL, uri)
            }
            else -> return result.success(false)
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (intent.resolveActivity(activity.packageManager) == null) return result.success(false)
        try {
            activity.startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        } catch (e: SecurityException) {
            result.success(false)
        }
    }
}
