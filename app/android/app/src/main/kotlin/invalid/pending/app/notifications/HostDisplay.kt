package invalid.pending.app.notifications

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction

/**
 * Cómo se muestra un dominio (T-5, CA-009-14): port de `displayHost` y `webAddressHost` de
 * `lib/domain/services/host_display.dart`. `test/fixtures/notifications/hosts.txt` lo comparte con
 * Dart y las dos pruebas (JUnit y `notification_parity_test.dart`) deben dar lo mismo.
 *
 * - Sin caracteres de control ni de cambio de dirección, y en minúsculas.
 * - Cada etiqueta, legible si usa un solo alfabeto; en punycode (`xn--…`) si los mezcla. Una
 *   etiqueta que ya llega en punycode se descodifica para decidirlo.
 * - Con `dropWww`, sin el `www.` del principio si detrás queda un dominio con punto.
 *
 * Núcleo puro: sin `android.*`.
 */
object HostDisplay {
    // C0, DEL, C1 y los de dirección del texto (LRM, RLM, ALM, LRE a RLO, LRI a PDI).
    private val unsafe = Regex("[\\u0000-\\u001F\\u007F-\\u009F\\u200E\\u200F\\u061C\\u202A-\\u202E\\u2066-\\u2069]")

    private fun stripUnsafeChars(text: String): String = unsafe.replace(text, "")

    /** El dominio [host] tal como se enseña; `""` si no queda nada. */
    fun displayHost(host: String, dropWww: Boolean = false): String {
        var shown = stripUnsafeChars(decodePercent(host)).lowercase()
        // `www.com` se queda entero: nunca se muestra un sufijo suelto.
        if (dropWww && shown.startsWith("www.") && shown.indexOf('.', 4) > 4) {
            shown = shown.substring(4)
        }
        return shown.split('.').joinToString(".") { displayLabel(it) }
    }

    /**
     * El dominio de la dirección guardada de una tarea web, como en la barra (sin `www.`), o
     * `null` si no tiene dominio o no se puede leer. Las direcciones guardadas ya están validadas
     * (CA-009-02): aquí basta con sacar la autoridad; lo raro da `null`, nunca una excepción.
     */
    fun webAddressHost(url: String?): String? {
        if (url == null) return null
        val schemeEnd = url.indexOf("://")
        if (schemeEnd <= 0 || !isScheme(url.substring(0, schemeEnd))) return null
        val rest = url.substring(schemeEnd + 3)
        val end = rest.indexOfFirst { it == '/' || it == '?' || it == '#' }
        val authority = if (end < 0) rest else rest.substring(0, end)
        if (authority.any { it.code <= 0x20 || it in "<>\"\\^`{|}" }) return null

        val hostPort = authority.substringAfterLast('@')
        val host: String
        if (hostPort.startsWith("[")) {
            val close = hostPort.indexOf(']')
            if (close < 0) return null
            val after = hostPort.substring(close + 1)
            if (after.isNotEmpty() && !isPort(after)) return null
            host = hostPort.substring(1, close)
        } else {
            val colon = hostPort.lastIndexOf(':')
            if (colon < 0) {
                host = hostPort
            } else {
                if (!isPort(hostPort.substring(colon))) return null
                host = hostPort.substring(0, colon)
            }
        }
        val shown = displayHost(host, dropWww = true)
        return shown.ifEmpty { null }
    }

    private fun isScheme(s: String): Boolean =
        (s[0] in 'a'..'z' || s[0] in 'A'..'Z') &&
            s.all { it in 'a'..'z' || it in 'A'..'Z' || it in '0'..'9' || it == '+' || it == '-' || it == '.' }

    /** `:` seguido de cifras (o de nada). */
    private fun isPort(s: String): Boolean = s.startsWith(":") && s.drop(1).all { it in '0'..'9' }

    /** `Uri.decodeComponent`: los `%XX` como UTF-8; si está mal formado, el texto tal cual. */
    private fun decodePercent(s: String): String {
        if (!s.contains('%')) return s
        val out = StringBuilder()
        val bytes = ByteArrayOutputStream()

        fun flush(): Boolean {
            if (bytes.size() == 0) return true
            val decoder =
                Charsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
            try {
                out.append(decoder.decode(ByteBuffer.wrap(bytes.toByteArray())))
            } catch (_: CharacterCodingException) {
                return false
            }
            bytes.reset()
            return true
        }

        var i = 0
        while (i < s.length) {
            val c = s[i]
            if (c == '%') {
                val hi = if (i + 2 < s.length) hexValue(s[i + 1]) else -1
                val lo = if (i + 2 < s.length) hexValue(s[i + 2]) else -1
                if (hi < 0 || lo < 0) return s
                bytes.write(hi * 16 + lo)
                i += 3
            } else {
                if (!flush()) return s
                out.append(c)
                i++
            }
        }
        if (!flush()) return s
        return out.toString()
    }

    private fun hexValue(c: Char): Int =
        when (c) {
            in '0'..'9' -> c - '0'
            in 'a'..'f' -> c - 'a' + 10
            in 'A'..'F' -> c - 'A' + 10
            else -> -1
        }

    private fun displayLabel(label: String): String {
        val unicode = if (label.startsWith("xn--")) fromPunycodeLabel(label) else label
        // Punycode mal formado o que esconde caracteres peligrosos: tal cual llegó.
        if (unicode == null || stripUnsafeChars(unicode) != unicode) return label
        return if (mixesScripts(unicode)) toPunycodeLabel(unicode) else unicode
    }

    private fun mixesScripts(label: String): Boolean {
        val scripts = mutableSetOf<String>()
        label.codePoints().forEach { r -> script(r)?.let(scripts::add) }
        return scripts.size > 1
    }

    /** Alfabeto de una letra; `null` para dígitos, guiones y lo que no es letra. */
    private fun script(r: Int): String? {
        if ((r in 0x41..0x5A) || (r in 0x61..0x7A)) return "latin"
        if (r < 0x80) return null
        if ((r in 0xC0..0x24F) || (r in 0x1E00..0x1EFF)) return "latin"
        if (r in 0x370..0x3FF) return "greek"
        if (r in 0x400..0x52F) return "cyrillic"
        if (r in 0x530..0x58F) return "armenian"
        if (r in 0x590..0x5FF) return "hebrew"
        if (r in 0x600..0x6FF) return "arabic"
        // Resto: por bloques de 128 (basta para detectar la mezcla).
        return "block${r shr 7}"
    }

    // Parámetros de punycode (RFC 3492 §5).
    private const val BASE = 36
    private const val T_MIN = 1
    private const val T_MAX = 26
    private const val SKEW = 38
    private const val DAMP = 700
    private const val INITIAL_BIAS = 72
    private const val INITIAL_N = 0x80

    private fun adapt(delta: Long, numPoints: Int, first: Boolean): Int {
        var d = if (first) delta / DAMP else delta / 2
        d += d / numPoints
        var k = 0
        while (d > ((BASE - T_MIN) * T_MAX) / 2) {
            d /= (BASE - T_MIN)
            k += BASE
        }
        return (k + (BASE - T_MIN + 1) * d / (d + SKEW)).toInt()
    }

    private fun threshold(k: Int, bias: Int): Int =
        if (k <= bias) T_MIN else if (k >= bias + T_MAX) T_MAX else k - bias

    private fun digit(d: Int): Char = if (d < 26) ('a' + d) else ('0' + (d - 26))

    /** Codifica una etiqueta de dominio en punycode (RFC 3492) con el prefijo `xn--`; ASCII, tal cual. */
    fun toPunycodeLabel(label: String): String {
        val input = label.codePoints().toArray()
        if (input.all { it < 0x80 }) return label

        val out = StringBuilder()
        input.filter { it < 0x80 }.forEach { out.appendCodePoint(it) }
        val basic = out.length
        var handled = basic
        if (basic > 0) out.append('-')
        var n = INITIAL_N
        var delta = 0L
        var bias = INITIAL_BIAS
        while (handled < input.size) {
            val m = input.filter { it >= n }.min()
            delta += (m - n).toLong() * (handled + 1)
            n = m
            for (c in input) {
                if (c < n) delta++
                if (c == n) {
                    var q = delta
                    var k = BASE
                    while (true) {
                        val t = threshold(k, bias)
                        if (q < t) break
                        out.append(digit((t + (q - t) % (BASE - t)).toInt()))
                        q = (q - t) / (BASE - t)
                        k += BASE
                    }
                    out.append(digit(q.toInt()))
                    bias = adapt(delta, handled + 1, handled == basic)
                    delta = 0
                    handled++
                }
            }
            delta++
            n++
        }
        return "xn--$out"
    }

    /** Descodifica una etiqueta `xn--…` (RFC 3492). `null` si no empieza por `xn--`, está mal formada o no es Unicode válido. */
    fun fromPunycodeLabel(label: String): String? {
        val lower = label.lowercase()
        if (!lower.startsWith("xn--")) return null
        val input = lower.substring(4)
        val dash = input.lastIndexOf('-')
        val output = mutableListOf<Int>()
        for (j in 0 until (if (dash < 0) 0 else dash)) {
            val c = input[j].code
            if (c >= 0x80) return null
            output.add(c)
        }

        fun value(c: Char): Int =
            when (c) {
                in 'a'..'z' -> c - 'a'
                in '0'..'9' -> c - '0' + 26
                else -> -1
            }

        var n = INITIAL_N.toLong()
        var i = 0L
        var bias = INITIAL_BIAS
        var pos = if (dash < 0) 0 else dash + 1
        val limit = 0x10FFFFL * 64
        while (pos < input.length) {
            val oldI = i
            var w = 1L
            var k = BASE
            while (true) {
                if (pos >= input.length) return null
                val d = value(input[pos++])
                if (d < 0) return null
                i += d * w
                val t = threshold(k, bias)
                if (d < t) break
                w *= (BASE - t)
                // Etiquetas absurdas: se descartan antes de desbordar.
                if (i > limit || w > limit) return null
                k += BASE
            }
            bias = adapt(i - oldI, output.size + 1, oldI == 0L)
            n += i / (output.size + 1)
            i %= (output.size + 1)
            if (n > 0x10FFFF || (n in 0xD800..0xDFFF)) return null
            output.add(i.toInt(), n.toInt())
            i++
        }
        if (output.all { it < 0x80 }) return null
        val sb = StringBuilder()
        output.forEach { sb.appendCodePoint(it) }
        return sb.toString()
    }
}
