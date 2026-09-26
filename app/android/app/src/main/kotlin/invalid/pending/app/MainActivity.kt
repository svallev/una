package invalid.pending.app

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var images: ImageImport? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        images = ImageImport(this).also {
            MethodChannel(messenger, ImageImport.CHANNEL).setMethodCallHandler(it)
        }
        // Pantalla encendida mientras se ve un adjunto (spec 007, CA-007-12).
        MethodChannel(messenger, "una/screen").setMethodCallHandler { call, result ->
            when (call.method) {
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
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
