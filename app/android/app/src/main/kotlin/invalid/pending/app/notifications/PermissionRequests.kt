package invalid.pending.app.notifications

/** Lo que contesta `requestPermission` a Dart (plan §3.5, P-019-14). */
data class PermissionReply(val granted: Boolean, val dialogShown: Boolean) {
    fun toMap(): Map<String, Boolean> = mapOf("granted" to granted, "dialogShown" to dialogShown)
}

/**
 * La petición del permiso de notificaciones de Android 13+ que espera `onRequestPermissionsResult`
 * (plan §3.5). Núcleo puro: la actividad le cuenta los cambios de foco y el resultado.
 *
 * `dialogShown` es «la actividad perdió el foco entre la petición y la respuesta» (P-019-14): el
 * sistema no dice si salió el diálogo, esto es lo más cercano. Si la actividad se recrea con la
 * petición pendiente, [abandon] la resuelve como «no concedido» (nadie queda esperando).
 */
class PermissionRequests {
    private var reply: ((PermissionReply) -> Unit)? = null
    private var focusLost = false

    val pending: Boolean get() = reply != null

    /**
     * Registra la petición. `false` si ya hay una: la nueva no se registra (la primera sigue) y el
     * llamador contesta «no concedido» por su cuenta.
     */
    fun begin(onReply: (PermissionReply) -> Unit): Boolean {
        if (reply != null) return false
        reply = onReply
        focusLost = false
        return true
    }

    /** Un cambio de foco de la ventana; solo cuenta el que ocurre con una petición pendiente. */
    fun onFocusChanged(hasFocus: Boolean) {
        if (reply != null && !hasFocus) focusLost = true
    }

    /** La respuesta del sistema; sin petición pendiente se ignora. */
    fun onResult(granted: Boolean) {
        val onReply = reply ?: return
        val shown = focusLost
        reply = null
        focusLost = false
        onReply(PermissionReply(granted = granted, dialogShown = shown))
    }

    /** La actividad se destruye con la petición pendiente: «no concedido». */
    fun abandon() {
        val onReply = reply ?: return
        val shown = focusLost
        reply = null
        focusLost = false
        onReply(PermissionReply(granted = false, dialogShown = shown))
    }

    companion object {
        /** `POST_NOTIFICATIONS` es un permiso de ejecución desde Android 13 (API 33). */
        const val FIRST_SDK_WITH_PERMISSION = 33

        /** ¿Hay que pedir el permiso al usuario? Solo en Android 13+ y si aún no está concedido. */
        fun needsPrompt(sdk: Int, granted: Boolean): Boolean = sdk >= FIRST_SDK_WITH_PERMISSION && !granted
    }
}
