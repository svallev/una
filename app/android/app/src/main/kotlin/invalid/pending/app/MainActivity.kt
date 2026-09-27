package invalid.pending.app

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var images: ImageImport? = null
    private var rotation: ImageRotation? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        images = ImageImport(this).also {
            MethodChannel(messenger, ImageImport.CHANNEL).setMethodCallHandler(it)
        }
        // Enlaces de un PDF (spec 008).
        MethodChannel(messenger, LinkOpener.CHANNEL).setMethodCallHandler(LinkOpener(this))
        val imageRotation = ImageRotation(this).also { rotation = it }
        // Pantalla encendida mientras se ve un adjunto (spec 007, CA-007-12) y
        // giro de la tarea actual con imagen (CA-007-11).
        MethodChannel(messenger, "una/screen").setMethodCallHandler { call, result ->
            when (call.method) {
                "rotateWithImage" -> {
                    imageRotation.follow(call.arguments == true)
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
        rotation?.pause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        rotation?.resume()
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
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
