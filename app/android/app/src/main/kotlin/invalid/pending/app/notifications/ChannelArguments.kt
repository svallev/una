package invalid.pending.app.notifications

/**
 * Valida lo que llega de Dart por el canal `una/notifications` (plan §3.5, CA-019-05): también es
 * entrada no fiable. Solo valen los tipos y valores exactos; cualquier otra cosa es `null` y el
 * canal contesta con un error **sin texto** (CA-019-23). Núcleo puro, sin `android.*`.
 */
object ChannelArguments {
    /** `{on: bool, perDay: int 1..3, lang: 'system'|'es'|'en'}`; las claves de más se ignoran. */
    fun parseConfigure(arguments: Any?): NotificationConfig? {
        val map = arguments as? Map<*, *> ?: return null
        val on = map["on"] as? Boolean ?: return null
        // Solo `Int` exacto: la codificación estándar manda un entero pequeño como `Integer`;
        // un `Long`, un `Double` o un texto no son un valor de la cantidad.
        val perDay = map["perDay"] as? Int ?: return null
        if (!NotificationTimes.isValidCount(perDay)) return null
        val lang = map["lang"] as? String ?: return null
        val language = LanguageChoice.entries.firstOrNull { it.stored == lang } ?: return null
        return NotificationConfig(on = on, perDay = perDay, language = language)
    }

    /** `setForeground(bool)`. */
    fun parseForeground(arguments: Any?): Boolean? = arguments as? Boolean
}
