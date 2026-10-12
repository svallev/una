package invalid.pending.app.notifications

/** Importancia del canal: la de por defecto del sistema (CA-019-22); no hay otra a propósito. */
enum class Importance { DEFAULT }

/** Visibilidad con el móvil bloqueado: privada, con versión pública (CA-019-17). */
enum class Visibility { PRIVATE }

/**
 * El canal único (CA-019-22): sin sonido, vibración, luz ni insignia propios. Su nombre y
 * descripción van en el idioma del **sistema** (regla de la 010), no en el elegido en Ajustes:
 * salen en una pantalla del sistema que no admite marca de idioma (CA-019-21).
 */
data class ChannelSpec(
    val id: String,
    val name: String,
    val description: String,
    val importance: Importance,
    val sound: Boolean,
    val vibration: Boolean,
    val lights: Boolean,
    val showBadge: Boolean,
    val lockscreenVisibility: Visibility,
)

/**
 * Lo que el `Poster` de Android traduce a objetos del sistema (plan §1): identificador, canal,
 * acciones, insignia, visibilidad, versión pública, `localOnly` y estilo expandible. El núcleo lo
 * construye y JUnit lo comprueba (CA-017, 18, 22); el `Poster` no decide nada.
 */
data class NotificationSpec(
    val id: Int,
    val channel: ChannelSpec,
    val text: NotificationText,
    /** Qué versión es (completa con etiqueta o genérica). */
    val display: Display,
    val visibility: Visibility,
    /** No se envía a relojes enlazados ni a otros dispositivos. */
    val localOnly: Boolean,
    /** Estilo expandible para leer los 120 caracteres con texto grande (CA-019-16). */
    val bigText: Boolean,
    /** Sin botones de acción: tocarla basta (CA-019-18, 20). */
    val actions: List<String>,
    val showBadge: Boolean,
) {
    companion object {
        /** Siempre el mismo: la nueva sustituye a la anterior (CA-019-18). */
        const val ID = 1

        const val CHANNEL_ID = "current_task"

        fun build(
            display: Display,
            choice: LanguageChoice,
            systemTags: List<String>,
            source: NotificationStringSource,
        ): NotificationSpec {
            val systemStrings = source.strings(Language.resolve(LanguageChoice.SYSTEM, systemTags))
            return NotificationSpec(
                id = ID,
                channel =
                    ChannelSpec(
                        id = CHANNEL_ID,
                        name = systemStrings.channelName,
                        description = systemStrings.channelDescription,
                        importance = Importance.DEFAULT,
                        sound = false,
                        vibration = false,
                        lights = false,
                        showBadge = false,
                        lockscreenVisibility = Visibility.PRIVATE,
                    ),
                text = NotificationText.build(display, choice, systemTags, source),
                display = display,
                visibility = Visibility.PRIVATE,
                localOnly = true,
                bigText = true,
                actions = emptyList(),
                showBadge = false,
            )
        }
    }
}
