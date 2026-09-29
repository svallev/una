package invalid.pending.app

import android.content.Context
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.net.http.SslError
import android.os.Build
import android.os.Message
import android.view.KeyEvent
import android.webkit.ClientCertRequest
import android.webkit.CookieManager
import android.webkit.HttpAuthHandler
import android.webkit.RenderProcessGoneDetail
import android.webkit.SafeBrowsingResponse
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebStorage
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

/**
 * Canal `una/webview` (spec 009, plan §1, T-4): la parte del endurecimiento de
 * la WebView de la tarea web que no da la API de `webview_flutter`. Trabaja con
 * la instancia nativa que devuelve `WebViewFlutterAndroidExternalApi.getWebView`
 * (el identificador es `AndroidWebViewController.webViewIdentifier`).
 *
 * - `harden`: ajustes (sin archivos ni contenido, sin datos de formularios,
 *   sin contenido mixto, Safe Browsing, sin ventanas nuevas), descargas
 *   bloqueadas (CL-009-4), sin depuración en *release* y el envoltorio del
 *   cliente (ADR-0017). Se llama **después** de `setNavigationDelegate`, que
 *   vuelve a poner el cliente y el `DownloadListener` del paquete. Lee todo de
 *   vuelta y devuelve si quedó puesto.
 * - `state`: los ajustes y si el envoltorio sigue puesto (comprobación).
 * - `clearData`: cookies, almacenamiento web y caché (CA-009-13).
 * - `destroy`: destruye la WebView tras el fallo de su proceso (ADR-0017).
 *
 * Avisa a Dart con `renderProcessGone`, `downloadBlocked` y, antes de cada
 * petición de navegación del marco principal, `mainFrameRequest` (si es una
 * redirección del servidor, T-009-12). Nunca envía ni registra direcciones ni
 * contenido de páginas (CL-009-9).
 */
class WebViewHardening : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "una/webview"
    }

    private var binding: FlutterPlugin.FlutterPluginBinding? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = binding
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        this.binding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "harden" -> {
                val view = webView(call) ?: return result.success(false)
                result.success(harden(view, idOf(call)))
            }
            "state" -> {
                val view = webView(call) ?: return result.success(null)
                result.success(state(view))
            }
            "destroy" -> {
                webView(call)?.destroy()
                result.success(null)
            }
            "clearData" -> clearData(if (call.hasArgument("id")) webView(call) else null, result)
            else -> result.notImplemented()
        }
    }

    private fun idOf(call: MethodCall): Long = call.argument<Number>("id")?.toLong() ?: -1

    private fun webView(call: MethodCall): WebView? {
        val binding = binding ?: return null
        val id = call.argument<Number>("id")?.toLong() ?: return null
        return WebViewFlutterAndroidExternalApi.getWebView(binding, id)
    }

    private fun harden(view: WebView, id: Long): Boolean {
        view.settings.apply {
            allowFileAccess = false
            allowContentAccess = false
            @Suppress("DEPRECATION")
            saveFormData = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            safeBrowsingEnabled = true
            setSupportMultipleWindows(false)
        }
        // Sustituye al del paquete, que convertía la descarga en una petición de
        // navegación. No se descarga nada: se avisa a Dart ("no es una página").
        view.setDownloadListener { _, _, _, _, _ ->
            channel?.invokeMethod("downloadBlocked", mapOf("id" to id))
        }
        if (!isDebuggable(view.context)) WebView.setWebContentsDebuggingEnabled(false)
        val client = view.webViewClient
        if (client !is RenderGoneClient) {
            view.webViewClient = RenderGoneClient(
                client,
                onGone = { crashed ->
                    channel?.invokeMethod(
                        "renderProcessGone",
                        mapOf("id" to id, "crashed" to crashed),
                    )
                },
                onMainFrameRequest = { redirect ->
                    channel?.invokeMethod(
                        "mainFrameRequest",
                        mapOf("id" to id, "redirect" to redirect),
                    )
                },
            )
        }
        return state(view).values.all { it }
    }

    /** Todo `true` si la WebView está como la deja [harden]. */
    private fun state(view: WebView): Map<String, Boolean> {
        val s = view.settings
        return mapOf(
            "noFileAccess" to !s.allowFileAccess,
            "noContentAccess" to !s.allowContentAccess,
            @Suppress("DEPRECATION")
            "noFormData" to !s.saveFormData,
            "noMixedContent" to (s.mixedContentMode == WebSettings.MIXED_CONTENT_NEVER_ALLOW),
            "safeBrowsing" to s.safeBrowsingEnabled,
            "noMultipleWindows" to !s.supportMultipleWindows(),
            "wrapped" to (view.webViewClient is RenderGoneClient),
        )
    }

    private fun isDebuggable(context: Context): Boolean =
        context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    /**
     * Borra lo que haya dejado cualquier página: cookies, almacenamiento web
     * (localStorage, IndexedDB…) y la caché de disco y de memoria, que es común
     * a todas las WebView de la app. Sin una WebView viva (el arranque), se usa
     * una temporal. Responde `true` cuando las cookies ya se han borrado y
     * guardado en disco.
     */
    private fun clearData(view: WebView?, result: MethodChannel.Result) {
        val context = binding?.applicationContext ?: return result.success(false)
        try {
            WebStorage.getInstance().deleteAllData()
            if (view != null) {
                view.clearCache(true)
            } else {
                WebView(context).apply {
                    clearCache(true)
                    destroy()
                }
            }
            val cookies = CookieManager.getInstance()
            cookies.removeAllCookies {
                cookies.flush()
                result.success(true)
            }
        } catch (e: RuntimeException) {
            // Sin WebView en el sistema (desactivada o actualizándose): sin
            // registrar nada; con la marca, se reintenta en el siguiente arranque.
            result.success(false)
        }
    }
}

/**
 * Envoltorio del `WebViewClient` de `webview_flutter_android` (ADR-0017): le
 * reenvía **todos** los métodos del *framework* y solo añade
 * `onRenderProcessGone`, que el paquete no implementa (sin él, Android cierra la
 * app cuando muere el proceso de la página). Devuelve `true` y avisa para que
 * Dart destruya esta WebView y cree otra. Si el paquete pasa a usar métodos
 * nuevos del cliente, hay que reenviarlos aquí (R-21).
 *
 * Además, sin cambiar nada de lo que hace el paquete, avisa **antes** de
 * pasarle cada petición del marco principal si es una redirección del servidor
 * (`WebResourceRequest.isRedirect`), que el paquete no da a Dart: así la carga
 * inicial sigue las del servidor y no una navegación de la página que llegue
 * antes de `onPageStarted` (T-009-12, ADR-0018). El aviso sale por el mismo
 * hilo y antes que el del paquete, así que llega antes a Dart.
 */
class RenderGoneClient(
    private val inner: WebViewClient,
    private val onGone: (crashed: Boolean) -> Unit,
    private val onMainFrameRequest: (redirect: Boolean) -> Unit,
) : WebViewClient() {
    override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
        onGone(detail.didCrash())
        return true
    }

    @Deprecated("Del framework; se reenvía igual")
    @Suppress("DEPRECATION")
    override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean =
        inner.shouldOverrideUrlLoading(view, url)

    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
        if (request.isForMainFrame) onMainFrameRequest(request.isRedirect)
        return inner.shouldOverrideUrlLoading(view, request)
    }

    override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) =
        inner.onPageStarted(view, url, favicon)

    override fun onPageFinished(view: WebView, url: String) = inner.onPageFinished(view, url)

    override fun onLoadResource(view: WebView, url: String) = inner.onLoadResource(view, url)

    override fun onPageCommitVisible(view: WebView, url: String) =
        inner.onPageCommitVisible(view, url)

    @Deprecated("Del framework; se reenvía igual")
    @Suppress("DEPRECATION")
    override fun shouldInterceptRequest(view: WebView, url: String): WebResourceResponse? =
        inner.shouldInterceptRequest(view, url)

    override fun shouldInterceptRequest(
        view: WebView,
        request: WebResourceRequest,
    ): WebResourceResponse? = inner.shouldInterceptRequest(view, request)

    @Deprecated("Del framework; se reenvía igual")
    @Suppress("DEPRECATION")
    override fun onTooManyRedirects(view: WebView, cancelMsg: Message, continueMsg: Message) =
        inner.onTooManyRedirects(view, cancelMsg, continueMsg)

    @Deprecated("Del framework; se reenvía igual")
    @Suppress("DEPRECATION")
    override fun onReceivedError(
        view: WebView,
        errorCode: Int,
        description: String?,
        failingUrl: String?,
    ) = inner.onReceivedError(view, errorCode, description, failingUrl)

    override fun onReceivedError(
        view: WebView,
        request: WebResourceRequest,
        error: WebResourceError,
    ) = inner.onReceivedError(view, request, error)

    override fun onReceivedHttpError(
        view: WebView,
        request: WebResourceRequest,
        errorResponse: WebResourceResponse,
    ) = inner.onReceivedHttpError(view, request, errorResponse)

    override fun onFormResubmission(view: WebView, dontResend: Message, resend: Message) =
        inner.onFormResubmission(view, dontResend, resend)

    override fun doUpdateVisitedHistory(view: WebView, url: String, isReload: Boolean) =
        inner.doUpdateVisitedHistory(view, url, isReload)

    override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) =
        inner.onReceivedSslError(view, handler, error)

    override fun onReceivedClientCertRequest(view: WebView, request: ClientCertRequest) =
        inner.onReceivedClientCertRequest(view, request)

    override fun onReceivedHttpAuthRequest(
        view: WebView,
        handler: HttpAuthHandler,
        host: String,
        realm: String,
    ) = inner.onReceivedHttpAuthRequest(view, handler, host, realm)

    override fun shouldOverrideKeyEvent(view: WebView, event: KeyEvent): Boolean =
        inner.shouldOverrideKeyEvent(view, event)

    override fun onUnhandledKeyEvent(view: WebView, event: KeyEvent) =
        inner.onUnhandledKeyEvent(view, event)

    override fun onScaleChanged(view: WebView, oldScale: Float, newScale: Float) =
        inner.onScaleChanged(view, oldScale, newScale)

    override fun onReceivedLoginRequest(
        view: WebView,
        realm: String,
        account: String?,
        args: String,
    ) = inner.onReceivedLoginRequest(view, realm, account, args)

    override fun onSafeBrowsingHit(
        view: WebView,
        request: WebResourceRequest,
        threatType: Int,
        callback: SafeBrowsingResponse,
    ) {
        // Solo existe desde la API 27; antes no se llama.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            inner.onSafeBrowsingHit(view, request, threatType, callback)
        }
    }
}
