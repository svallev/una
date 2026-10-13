package invalid.pending.app.notifications

import java.util.Locale

/** Los dos idiomas de la app (010): lo que puede salir en una notificación. */
enum class AppLanguage(val tag: String) {
    ES("es"),
    EN("en"),
}

/**
 * El idioma de la notificación (CA-019-21) y cuándo se marca para el lector de pantalla. Es la
 * regla de la 010 (`resolveAppLocale` de Dart): se usa el primer idioma del sistema que la app
 * admita (`es-*` y `ca-*` → español; `en-*` → inglés); sin ninguno (también `gl`, `eu` o los de
 * derecha a izquierda), inglés. Con «Español» o «English» elegidos en Ajustes no se mira el sistema.
 *
 * Núcleo puro: sin `android.*`; los idiomas del sistema llegan por [SystemLocale].
 */
object Language {
    fun resolve(choice: LanguageChoice, systemTags: List<String>): AppLanguage =
        when (choice) {
            LanguageChoice.ES -> AppLanguage.ES
            LanguageChoice.EN -> AppLanguage.EN
            LanguageChoice.SYSTEM -> resolveSystem(systemTags)
        }

    private fun resolveSystem(systemTags: List<String>): AppLanguage {
        for (tag in systemTags) {
            when (primaryLanguage(tag)) {
                "es", "ca" -> return AppLanguage.ES
                "en" -> return AppLanguage.EN
            }
        }
        return AppLanguage.EN
    }

    /** El primer idioma del sistema (`es`, `ca`, `en`…), `null` si no hay ninguno legible. */
    fun firstSystemLanguage(systemTags: List<String>): String? =
        systemTags.firstNotNullOfOrNull { primaryLanguage(it) }

    /**
     * ¿Hay que marcar con su idioma el texto fijo de la notificación? Sí cuando el idioma de la
     * app **no** es el primero del sistema (el lector usaría la voz equivocada); el catalán se
     * lee en español pero su voz es catalana, así que también se marca.
     */
    fun needsMark(app: AppLanguage, systemTags: List<String>): Boolean =
        firstSystemLanguage(systemTags) != app.tag

    /** `es-ES` / `es_ES` / `ES` → `es`; vacío → `null`. */
    private fun primaryLanguage(tag: String): String? =
        tag.trim()
            .lowercase(Locale.ROOT)
            .split('-', '_')
            .first()
            .takeIf { it.isNotEmpty() }
}
