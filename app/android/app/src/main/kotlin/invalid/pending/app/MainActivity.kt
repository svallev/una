package invalid.pending.app

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import invalid.pending.app.notifications.NotificationsChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var images: ImageImport? = null
    private var rotation: AttachmentRotation? = null
    private var notifications: NotificationsChannel? = null
    private val recents = RecentsPrivacy(this)

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        recents.onCreate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        images = ImageImport(this).also {
            MethodChannel(messenger, ImageImport.CHANNEL).setMethodCallHandler(it)
        }
        // Enlaces de un PDF (spec 008).
        MethodChannel(messenger, LinkOpener.CHANNEL).setMethodCallHandler(LinkOpener(this))
        // "Tiempo para actuar" del sistema para la card de deshacer (spec 014).
        MethodChannel(messenger, AccessibilityTimeouts.CHANNEL)
            .setMethodCallHandler(AccessibilityTimeouts(applicationContext))
        // Notificaciones de la tarea actual (spec 019): permiso, programación y "a la vista".
        notifications = NotificationsChannel(this, messenger)
        // Endurecimiento y limpieza de la WebView de la tarea web (spec 009). Como
        // plugin, para pedir la WebView al de `webview_flutter` (ya registrado).
        flutterEngine.plugins.add(WebViewHardening())
        val attachmentRotation = AttachmentRotation(this).also { rotation = it }
        // Pantalla encendida mientras se ve un adjunto (spec 007, CA-007-12) y
        // giro de la tarea actual con imagen o PDF (CA-008-11).
        MethodChannel(messenger, "una/screen").setMethodCallHandler { call, result ->
            when (call.method) {
                "rotateWithAttachment" -> {
                    attachmentRotation.follow(call.arguments == true)
                    result.success(null)
                }
                "keepOn" -> {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPause() {
        recents.onPause()
        rotation?.pause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        recents.onResume()
        rotation?.resume()
        notifications?.onResume()
    }

    // Spec 019, CA-019-19a: la app deja de estar a la vista en `onStop` (pantalla apagada, otra app
    // o inicio), no en `onPause`: el diálogo del permiso y la cortina de notificaciones pausan la
    // actividad sin sacar la app de la vista.
    override fun onStop() {
        notifications?.onStop()
        super.onStop()
    }

    // Spec 019, CA-019-20: tocar la notificación con la app viva. Solo cuenta la intención con la
    // acción exacta y el `nonce` vigente; cualquier otra se ignora sin efecto.
    override fun onNewIntent(intent: Intent) {
        notifications?.onNewIntent(intent)
        super.onNewIntent(intent)
    }

    // Spec 019, P-019-14: un cambio de foco entre pedir el permiso y su respuesta es la señal de que
    // salió el diálogo del sistema.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        notifications?.onWindowFocusChanged(hasFocus)
        super.onWindowFocusChanged(hasFocus)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (notifications?.onPermissionResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    @Deprecated("startActivityForResult: sin androidx.activity (sin dependencias nuevas)")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (images?.onActivityResult(requestCode, resultCode, data) != true) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        images?.dispose()
        images = null
        rotation?.follow(false)
        rotation = null
        notifications?.dispose()
        notifications = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
