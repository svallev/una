package invalid.pending.app.notifications

/**
 * Los textos nativos de la notificación en un idioma (los 7 de `tool/gen_android_strings.dart`,
 * generados de los mismos ARB que la app, CA-019-21 y 27).
 */
data class NotificationStrings(
    val channelName: String,
    val channelDescription: String,
    val title: String,
    val publicText: String,
    val photo: String,
    val image: String,
    val pdf: String,
)

/** De dónde salen los textos de cada idioma: los recursos `values`/`values-es` en la app, un doble en las pruebas. */
interface NotificationStringSource {
    fun strings(language: AppLanguage): NotificationStrings
}

/**
 * Un trozo de texto de la notificación. [language] es el de la app para el texto fijo y `null`
 * para lo que escribió el usuario o el dominio (idioma desconocido). [marked]: el `Poster` lo
 * marca con su idioma para el lector de pantalla (`LocaleSpan`); solo si el idioma de la app no es
 * el primero del sistema y solo con texto fijo.
 */
data class Piece(val text: String, val language: AppLanguage?, val marked: Boolean) {
    init {
        require(!marked || language != null) { "una pieza marcada necesita idioma" }
    }
}

/**
 * Todo el texto de **una** notificación (CA-019-16, 17, 21): el título y el cuerpo de la versión
 * completa y los de la **versión pública** (la genérica, sin ninguna parte de la tarea).
 *
 * Se construye al llegar la hora, con el idioma de ese momento (no el de cuando se programó).
 */
data class NotificationText(
    val title: Piece,
    val body: Piece,
    val publicTitle: Piece,
    val publicBody: Piece,
) {
    companion object {
        fun build(
            display: Display,
            choice: LanguageChoice,
            systemTags: List<String>,
            source: NotificationStringSource,
        ): NotificationText {
            val language = Language.resolve(choice, systemTags)
            val strings = source.strings(language)
            val marked = Language.needsMark(language, systemTags)

            fun fixed(text: String) = Piece(text, language, marked)

            val title = fixed(strings.title)
            val generic = fixed(strings.publicText)
            val body =
                when (display) {
                    is Display.Generic -> generic
                    is Display.Full ->
                        when (val label = display.label) {
                            is TaskLabel.Text -> Piece(label.value, null, false)
                            is TaskLabel.Domain -> Piece(label.host, null, false)
                            is TaskLabel.Photo -> fixed(strings.photo)
                            is TaskLabel.Image -> fixed(strings.image)
                            is TaskLabel.Pdf -> fixed(strings.pdf)
                        }
                }
            return NotificationText(title = title, body = body, publicTitle = title, publicBody = generic)
        }
    }
}
