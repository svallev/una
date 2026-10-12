package invalid.pending.app.notifications

import java.security.MessageDigest
import java.security.SecureRandom

/**
 * El `nonce` de la orden «abrir la tarea actual» (plan §3.4, P-019-4, CA-019-20, acota T-8).
 *
 * La notificación lleva un `PendingIntent` con una acción fija y este valor; `MainActivity` solo
 * avisa a Dart si la intención trae la acción exacta **y el `nonce` vigente**, de un solo uso. Así
 * otra app que lance la pantalla de entrada no puede forzar la vuelta a la tarea actual (y perder
 * un borrador). Vive **solo en la memoria del proceso**: nunca en la copia derivada (CA-019-23) ni
 * en el disco. Con la app cerrada no hace falta: la pantalla de entrada ya es la tarea actual.
 */
object ActivationNonce {
    /** Acción fija de la propia app, sin datos de la tarea ni otros parámetros (CA-019-20). */
    const val ACTION = "invalid.pending.app.action.OPEN_CURRENT_TASK"

    const val EXTRA = "nonce"

    private const val BYTES = 16 // 128 bits

    private val random = SecureRandom()
    private val lock = Any()
    private var current: String? = null

    /** Genera uno nuevo (sustituye al anterior) y lo devuelve para ponerlo en el `PendingIntent`. */
    fun issue(): String {
        val bytes = ByteArray(BYTES)
        random.nextBytes(bytes)
        val value = bytes.joinToString("") { "%02x".format(it) }
        synchronized(lock) { current = value }
        return value
    }

    /**
     * ¿Es [candidate] el `nonce` vigente? Si lo es, se gasta (un solo uso). Uno ajeno, vacío o
     * `null` se rechaza **sin** gastar el vigente.
     */
    fun consume(candidate: String?): Boolean {
        if (candidate == null) return false
        synchronized(lock) {
            val expected = current ?: return false
            val equal = MessageDigest.isEqual(expected.toByteArray(Charsets.UTF_8), candidate.toByteArray(Charsets.UTF_8))
            if (equal) current = null
            return equal
        }
    }

    /** Al quitar la notificación, apagar o aceptarlo: ya no vale ninguno. */
    fun clear() {
        synchronized(lock) { current = null }
    }
}
