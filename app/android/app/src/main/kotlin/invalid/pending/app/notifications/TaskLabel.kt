package invalid.pending.app.notifications

/**
 * El único acceso a «segmentar por letras» (plan §1): devuelve los límites, en unidades UTF-16 y en
 * orden creciente, entre letras completas (un emoji con ZWJ, una letra con su acento o una bandera
 * son una). En la app lo implementa ICU de Android; en las pruebas JVM, un doble.
 */
interface GraphemeSplitter {
    /** Incluye 0 y `text.length`; `boundaries.size - 1` es el número de letras. */
    fun boundaries(text: String): IntArray
}

/** Una fila de adjunto tal como está en la base (acotada en SQL, plan §3.3); todo puede faltar. */
data class AttachmentSnapshot(val kind: String?, val origin: String?, val url: String?)

/** La tarea actual leída de la base: su texto y hasta dos filas de adjuntos (basta para «uno» o «varios»). */
data class TaskSnapshot(val body: String?, val attachments: List<AttachmentSnapshot>)

/**
 * La etiqueta de la tarea en la notificación (CA-019-16, D25). Lo que es texto fijo de la app
 * («Foto», «Imagen», «PDF») va como tipo y se traduce al mostrar ([NotificationText]); el texto de
 * la tarea y el dominio se dejan tal como están escritos.
 */
sealed interface TaskLabel {
    /** El texto del usuario, ya sin saltos de línea y recortado. */
    data class Text(val value: String) : TaskLabel

    data object Photo : TaskLabel

    data object Image : TaskLabel

    data object Pdf : TaskLabel

    /** El dominio de una tarea web, ya como en la barra de la tarea ([HostDisplay.webAddressHost]). */
    data class Domain(val host: String) : TaskLabel

    companion object {
        /** Letras visibles del texto antes del «…» (Q-019-9). */
        const val MAX_LETTERS = 120

        const val ELLIPSIS = "\u2026"

        /**
         * La etiqueta de [task], o `null` si no la tiene (la notificación completa dice entonces lo
         * mismo que la genérica): un grupo de fotos, una mezcla rara, un adjunto de tipo u origen
         * desconocido, o una web sin dirección legible, siempre sin texto. **El texto manda sobre
         * cualquier adjunto**, también web.
         */
        fun of(task: TaskSnapshot, splitter: GraphemeSplitter): TaskLabel? {
            val text = cleanText(task.body)
            if (text.isNotEmpty()) return Text(truncate(text, splitter))

            val row = task.attachments.singleOrNull() ?: return null
            return when (row.kind to row.origin) {
                "image" to "camera" -> Photo
                "image" to "gallery" -> Image
                "pdf" to "file" -> Pdf
                "web" to "url" -> HostDisplay.webAddressHost(row.url)?.let(::Domain)
                else -> null
            }
        }

        private fun isBreak(c: Char) = c == '\n' || c == '\r' || c == '\u000B' || c == '\u000C' || c == '\u0085' || c == '\u2028' || c == '\u2029'

        /**
         * El texto en una línea: cada tramo con saltos de línea (y los espacios que lo rodean) pasa a
         * un espacio, y sin espacios en los extremos. Solo espacios o saltos = `""` (sin texto).
         */
        private fun cleanText(body: String?): String {
            if (body == null) return ""
            val out = StringBuilder(body.length)
            var i = 0
            while (i < body.length) {
                val c = body[i]
                if (isBreak(c)) {
                    // Los espacios de antes del salto sobran; los de después se saltan.
                    while (out.isNotEmpty() && out.last().isWhitespace()) out.setLength(out.length - 1)
                    while (i < body.length && (isBreak(body[i]) || body[i].isWhitespace())) i++
                    out.append(' ') // un espacio sobrante en un extremo lo quita el `trim` final
                } else {
                    out.append(c)
                    i++
                }
            }
            return out.toString().trim { it.isWhitespace() }
        }

        private fun truncate(text: String, splitter: GraphemeSplitter): String {
            // Hasta 120 unidades UTF-16 no puede haber más de 120 letras: no hace falta separarlas.
            if (text.length <= MAX_LETTERS) return text
            val bounds = splitter.boundaries(text)
            if (bounds.size - 1 <= MAX_LETTERS) return text
            var cut = bounds[MAX_LETTERS]
            // Un separador defectuoso no debe dejar media pareja sustituta.
            if (cut in 1 until text.length && Character.isHighSurrogate(text[cut - 1]) && Character.isLowSurrogate(text[cut])) {
                cut--
            }
            return text.substring(0, cut) + ELLIPSIS
        }
    }
}
