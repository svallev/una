package invalid.pending.app

import android.app.Activity
import android.os.Build
import android.view.WindowManager

// PROVISIONAL (T-011-01, spec 011): solo para medir los dos mecanismos en el
// emulador. T-011-02 lo sustituye por la versión final. No es el código definitivo.
class RecentsPrivacy(private val activity: Activity) {
    fun onCreate() {
        if (MODE == "A" && Build.VERSION.SDK_INT >= 33) {
            activity.setRecentsScreenshotEnabled(false)
        }
    }

    fun onPause() {
        if (MODE == "B") activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    fun onResume() {
        if (MODE == "B") activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    private companion object {
        const val MODE = "A"
    }
}
