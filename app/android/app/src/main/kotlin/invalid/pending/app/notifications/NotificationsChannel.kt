package invalid.pending.app.notifications

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Duration

/** El latido sobre un `Handler` del hilo principal (un solo mensaje pendiente). */
class HandlerHeartbeatTimer : HeartbeatTimer {
    private val handler = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null

    override fun schedule(delay: Duration, action: () -> Unit) {
        cancel()
        val task = Runnable { action() }
        pending = task
        handler.postDelayed(task, delay.toMillis())
    }

    override fun cancel() {
        pending?.let(handler::removeCallbacks)
        pending = null
    }
}

/**
 * Canal `una/notifications` con Dart (spec 019, plan §3.5, CA-019-07, 09, 19b, 20). Solo adapta:
 * la validación está en [ChannelArguments], la petición del permiso en [PermissionRequests], el
 * «a la vista» en [ForegroundTracker] y la programación en [WakeHandler].
 *
 * Métodos: `canNotify`, `requestPermission` (`{granted, dialogShown}`), `configure`
 * (`{on, perDay, lang}`), `cancelDelivered`, `setForeground` (bool) y `openSystemSettings`.
 * Hacia Dart: `openCurrentTask`, solo con el `nonce` vigente ([ActivationNonce]).
 *
 * Un argumento inválido o cualquier fallo contestan con un error **sin texto** (`result.error(code,
 * null, null)`): nada del contenido ni de la excepción sale hacia Dart ni al registro (CA-019-23).
 */
class NotificationsChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "una/notifications"
        const val REQUEST_CODE = 0x4e01
        private const val INVALID = "invalid_argument"
        private const val FAILED = "failed"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val requests = PermissionRequests()
    private val context = activity.applicationContext

    // Perezosos: crear el canal en `configureFlutterEngine` no debe añadir trabajo al arranque (P2,
    // CA-019-24); la copia derivada y el `Poster` se abren con la primera llamada que los necesita.
    private val poster by lazy { NotificationPoster(context, ResourceStrings(context), AndroidSystemLocale) }
    private val tracker by lazy { ForegroundTracker(AndroidClock, DerivedStores.open(context), HandlerHeartbeatTimer()) }
    private var trackerReady = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "canNotify" -> result.success(poster.canNotify())
                "requestPermission" -> requestPermission(result)
                "configure" -> configure(call.arguments, result)
                "cancelDelivered" -> {
                    poster.cancelDelivered()
                    result.success(null)
                }
                "setForeground" -> {
                    val visible = ChannelArguments.parseForeground(call.arguments)
                    if (visible == null) {
                        result.error(INVALID, null, null)
                    } else {
                        trackerReady = true
                        tracker.setVisible(visible)
                        result.success(null)
                    }
                }
                "openSystemSettings" -> result.success(openSystemSettings())
                else -> result.notImplemented()
            }
        } catch (_: Throwable) {
            // Sin texto ni registro (CA-019-23): Dart solo sabe que falló.
            result.error(FAILED, null, null)
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        val granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || hasRuntimePermission()
        if (!PermissionRequests.needsPrompt(Build.VERSION.SDK_INT, granted)) {
            // Android 12 o anterior, o permiso ya concedido: nada que preguntar; vale lo que diga el sistema.
            result.success(PermissionReply(granted = poster.canNotify(), dialogShown = false).toMap())
            return
        }
        val registered =
            requests.begin { reply ->
                val allowed = reply.granted && poster.canNotify()
                result.success(reply.copy(granted = allowed).toMap())
            }
        if (!registered) {
            result.success(PermissionReply(granted = false, dialogShown = false).toMap())
            return
        }
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
    }

    private fun hasRuntimePermission(): Boolean =
        activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun configure(arguments: Any?, result: MethodChannel.Result) {
        val config = ChannelArguments.parseConfigure(arguments)
        if (config == null) {
            result.error(INVALID, null, null)
            return
        }
        if (config.on) poster.ensureChannel()
        val handler = WakeRuntime.create(context)
        if (!handler.configure(config)) {
            result.error(FAILED, null, null)
            return
        }
        trackerReady = true
        tracker.onConfigured()
        result.success(null)
    }

    /** `false` si no hay a dónde ir (ningún ajuste de notificaciones que lo atienda). */
    private fun openSystemSettings(): Boolean {
        val intent =
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
        return try {
            activity.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    // --- Lo que le cuenta la actividad ---

    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        requests.onResult(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        return true
    }

    fun onWindowFocusChanged(hasFocus: Boolean) = requests.onFocusChanged(hasFocus)

    // Sin `setForeground` ni `configure` todavía no hay nada que limpiar ni que restaurar.
    fun onStop() {
        if (trackerReady) tracker.onStop()
    }

    fun onResume() {
        if (trackerReady) tracker.onResume()
    }

    /** La orden de abrir la tarea actual: solo si la intención trae la acción exacta y el `nonce` vigente. */
    fun onNewIntent(intent: Intent?) {
        if (intent == null) return
        // La actividad está exportada: se mira la acción antes de tocar los extras, y unos extras que
        // no se puedan leer (un `Parcelable` ajeno) se ignoran en vez de tumbar el proceso.
        if (intent.action != ActivationNonce.ACTION) return
        val accepted =
            try {
                ActivationNonce.accept(intent.action, intent.getStringExtra(ActivationNonce.EXTRA))
            } catch (_: Throwable) {
                false
            }
        if (!accepted) return
        channel.invokeMethod("openCurrentTask", null)
    }

    /** La actividad se va: una petición pendiente vale «no concedido» y el latido se para. */
    fun dispose() {
        try {
            requests.abandon()
        } catch (_: Throwable) {
            // El motor ya se va: nadie recibe la respuesta.
        }
        if (trackerReady) tracker.dispose()
        channel.setMethodCallHandler(null)
    }
}
