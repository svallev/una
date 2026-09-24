package dev.spike.onetask.una_spikes

import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import java.util.concurrent.Executors
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.webkit.CookieManager
import android.webkit.WebResourceError
import android.net.http.SslError
import android.webkit.SslErrorHandler
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebStorage
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

// SPIKE (código desechable).
// S1: reportFullyDrawn. S3: abrir documentos con el visor del sistema (FileProvider, solo lectura).
// S4: captura de página completa con una WebView fuera de pantalla y endurecida.
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Necesario para dibujar la página completa (no solo el viewport). Antes de crear WebViews.
        WebView.enableSlowWholeDocumentDraw()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "spike/perf")
            .setMethodCallHandler { call, result ->
                if (call.method == "reportFullyDrawn") { reportFullyDrawn(); result.success(null) } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "spike/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openFile" -> openFile(call.argument<String>("path")!!, call.argument<String>("mime")!!, result)
                    "snapshot" -> snapshot(
                        call.argument<String>("url")!!,
                        call.argument<String>("out")!!,
                        call.argument<Int>("maxHeightPx") ?: 16000,
                        result,
                    )
                    "sanitizeImage" -> sanitizeImage(
                        call.argument<String>("in")!!, call.argument<String>("outDir")!!,
                        call.argument<Int>("screenPx")!!, result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    // ─── S5: ImageSanitizer nativo ──────────────────────────────────────────
    // Decodifica (aplicando la orientación EXIF) y recodifica a JPEG. Bitmap.compress
    // no escribe metadatos: EXIF/GPS/XMP desaparecen. Se ejecuta fuera del hilo principal.
    private val io = Executors.newSingleThreadExecutor()

    private fun decodeOriented(file: File, maxLong: Int): Bitmap {
        if (Build.VERSION.SDK_INT >= 28) {
            val src = ImageDecoder.createSource(file)
            return ImageDecoder.decodeBitmap(src) { dec, info, _ ->
                val w = info.size.width; val h = info.size.height
                val long = maxOf(w, h)
                if (long > maxLong) dec.setTargetSize(w * maxLong / long, h * maxLong / long)
                dec.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        }
        // API 26–27: BitmapFactory + rotación manual según ExifInterface.
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, opts)
        var sample = 1
        while (maxOf(opts.outWidth, opts.outHeight) / (sample * 2) >= maxLong) sample *= 2
        val bmp = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
        val deg = when (ExifInterface(file.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f; ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f; else -> 0f
        }
        return if (deg == 0f) bmp else Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, Matrix().apply { postRotate(deg) }, true)
    }

    private fun scaled(b: Bitmap, maxW: Int): Bitmap =
        if (b.width <= maxW) b else Bitmap.createScaledBitmap(b, maxW, b.height * maxW / b.width, true)

    private fun sanitizeImage(inPath: String, outDir: String, screenPx: Int, result: MethodChannel.Result) {
        io.execute {
            try {
                val t0 = System.currentTimeMillis()
                val ms = mutableMapOf<String, Any>()
                val original = decodeOriented(File(inPath), 4096)
                ms["decode"] = System.currentTimeMillis() - t0
                val out = mutableMapOf<String, Any>()
                for ((name, bmp, q) in listOf(
                    Triple("original", original, 88),
                    Triple("display", scaled(original, screenPx), 88),
                    Triple("thumb", scaled(original, 256), 80),
                )) {
                    val f = File(outDir, "$name.jpg")
                    FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.JPEG, q, it) }
                    out[name] = f.path
                    out["${name}WxH"] = "${bmp.width}x${bmp.height}"
                    out["${name}Bytes"] = f.length()
                    ms["encode_$name"] = System.currentTimeMillis() - t0
                }
                ms["total"] = System.currentTimeMillis() - t0
                out["ms"] = ms
                runOnUiThread { result.success(out) }
            } catch (e: Throwable) {
                runOnUiThread { result.error("sanitize_error", "${e.javaClass.simpleName}: ${e.message}", null) }
            }
        }
    }

    // ─── S3: visor del sistema ──────────────────────────────────────────────
    private fun openFile(path: String, mime: String, result: MethodChannel.Result) {
        val uri = FileProvider.getUriForFile(this, "$packageName.files", File(path))
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) // solo lectura, sin escritura
        }
        try {
            startActivity(Intent.createChooser(intent, null))
            // El selector siempre existe; comprobamos si hay alguna app que lo gestione.
            val handlers = packageManager.queryIntentActivities(intent, 0)
            result.success(if (handlers.isEmpty()) "no_app" else "opened:${handlers.size}")
        } catch (e: ActivityNotFoundException) {
            result.success("no_app")
        }
    }

    // ─── S4: captura de página completa ─────────────────────────────────────
    @SuppressLint("SetJavaScriptEnabled")
    private fun snapshot(url: String, outPath: String, maxHeightPx: Int, result: MethodChannel.Result) {
        val main = Handler(Looper.getMainLooper())
        val width = resources.displayMetrics.widthPixels
        val viewport = resources.displayMetrics.heightPixels
        val t0 = System.currentTimeMillis()
        val wv = WebView(this)
        var done = false
        fun finish(value: Any?, error: String? = null) {
            if (done) return
            done = true
            main.post {
                wv.stopLoading(); wv.destroy()
                CookieManager.getInstance().removeAllCookies(null)
                WebStorage.getInstance().deleteAllData()
                if (error != null) result.error(error, null, null) else result.success(value)
            }
        }
        with(wv.settings) {
            javaScriptEnabled = true           // la mayoría de webs lo necesitan
            allowFileAccess = false            // sin file://
            allowContentAccess = false         // sin content://
            domStorageEnabled = true
            setGeolocationEnabled(false)
            mediaPlaybackRequiresUserGesture = true
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            saveFormData = false
        }
        // Sin addJavascriptInterface: no hay puente con la app.
        CookieManager.getInstance().setAcceptThirdPartyCookies(wv, false)
        wv.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val s = request.url.scheme ?: ""
                return !(s == "https" || s == "http") // bloquear intent:, tel:, file:, javascript:…
            }
            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame) finish(null, "load_error:${error.errorCode}:${error.description}")
            }
            // Un certificado no válido NO llega a onReceivedError: sin esto se guardaría una página en blanco.
            override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {
                handler.cancel() // nunca se acepta un certificado inválido
                finish(null, "ssl_error:${error.primaryError}")
            }
            override fun onReceivedHttpError(view: WebView, request: WebResourceRequest, response: WebResourceResponse) {
                if (request.isForMainFrame && response.statusCode >= 400) finish(null, "http_error:${response.statusCode}")
            }
            override fun onPageFinished(view: WebView, finishedUrl: String) {
                // Margen para imágenes perezosas y fuentes.
                main.postDelayed({
                    if (done) return@postDelayed
                    view.evaluateJavascript(
                        "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
                    ) { h ->
                        val cssHeight = h.toFloatOrNull() ?: 0f
                        val fullPx = (cssHeight * resources.displayMetrics.density).toInt().coerceAtLeast(viewport)
                        val heightPx = fullPx.coerceAtMost(maxHeightPx)
                        view.measure(
                            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                            View.MeasureSpec.makeMeasureSpec(heightPx, View.MeasureSpec.EXACTLY),
                        )
                        view.layout(0, 0, width, heightPx)
                        main.postDelayed({
                            try {
                                val bmp = Bitmap.createBitmap(width, heightPx, Bitmap.Config.RGB_565)
                                view.draw(Canvas(bmp))
                                FileOutputStream(outPath).use { bmp.compress(Bitmap.CompressFormat.JPEG, 85, it) }
                                bmp.recycle()
                                finish(mapOf(
                                    "path" to outPath, "width" to width, "height" to heightPx,
                                    "fullHeight" to fullPx, "partial" to (fullPx > heightPx),
                                    "finalUrl" to finishedUrl, "title" to (view.title ?: ""),
                                    "bytes" to File(outPath).length(), "ms" to (System.currentTimeMillis() - t0),
                                ))
                            } catch (e: Throwable) {
                                finish(null, "draw_error:${e.javaClass.simpleName}:${e.message}")
                            }
                        }, 300)
                    }
                }, 1200)
            }
        }
        // Viewport inicial del tamaño de la pantalla (fuera de la jerarquía de vistas).
        wv.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(viewport, View.MeasureSpec.EXACTLY),
        )
        wv.layout(0, 0, width, viewport)
        wv.loadUrl(url)
        main.postDelayed({ finish(null, "timeout") }, 20000)
    }
}
