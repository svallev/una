package dev.spike.onetask.una_spikes

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// SPIKE S1: canal mínimo para marcar "tarea visible" con reportFullyDrawn(),
// que el sistema registra en logcat como "Fully drawn" (TTFD real).
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "spike/perf")
            .setMethodCallHandler { call, result ->
                if (call.method == "reportFullyDrawn") {
                    reportFullyDrawn()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
