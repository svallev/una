package invalid.pending.app.notifications

import android.content.Context
import android.content.SharedPreferences
import java.time.Instant

/** Las cinco claves de la copia derivada y nada más (CA-019-23). Nunca texto de tareas ni el `nonce`. */
object DerivedKeys {
    const val ON = "on"
    const val PER_DAY = "perDay"
    const val LANG = "lang"
    const val LAST_ATTENDED = "lastAttended"
    const val FOREGROUND_AT = "foregroundAt"

    val ALL: Set<String> = setOf(ON, PER_DAY, LANG, LAST_ATTENDED, FOREGROUND_AT)
}

/** Lo mínimo de `SharedPreferences` que necesita la copia; las pruebas JVM usan un falso. */
interface KeyValueBacking {
    /** Todo lo guardado, tal cual (puede lanzar si el archivo está roto). */
    fun all(): Map<String, Any?>

    /** Escribe de forma duradera; `false` si falló. */
    fun commit(values: Map<String, Any>): Boolean

    /** Escribe en segundo plano (seguro en un receptor: Android espera a que acabe el trabajo en cola). */
    fun apply(values: Map<String, Any>)
}

/**
 * La copia derivada (plan §3.1, CA-019-23): el interruptor, la cantidad, el idioma elegido, la
 * «última hora atendida» y el indicador de «a la vista». Se lee como **entrada no fiable**
 * (CA-019-05): solo valen los valores exactos, lo raro equivale a apagado o a «sin dato».
 */
class PersistedDerivedStore(private val backing: KeyValueBacking) : DerivedStore {
    override fun read(): DerivedState {
        val all: Map<String, Any?> =
            try {
                backing.all()
            } catch (_: Throwable) {
                return DerivedState(NotificationConfig.OFF, null, null)
            }
        return DerivedState(
            config = decodeConfig(all),
            lastAttended = decodeInstant(all[DerivedKeys.LAST_ATTENDED]),
            foregroundAt = decodeInstant(all[DerivedKeys.FOREGROUND_AT]),
        )
    }

    override fun writeConfig(config: NotificationConfig): Boolean {
        if (!NotificationTimes.isValidCount(config.perDay)) return false
        return try {
            backing.commit(
                mapOf(
                    DerivedKeys.ON to config.on,
                    DerivedKeys.PER_DAY to config.perDay,
                    DerivedKeys.LANG to config.language.stored,
                ),
            )
        } catch (_: Throwable) {
            false
        }
    }

    override fun writeLastAttended(at: Instant) {
        write(DerivedKeys.LAST_ATTENDED, at.toEpochMilli())
    }

    override fun writeForegroundAt(at: Instant?) {
        write(DerivedKeys.FOREGROUND_AT, at?.toEpochMilli() ?: 0L)
    }

    private fun write(key: String, value: Long) {
        try {
            backing.apply(mapOf(key to value))
        } catch (_: Throwable) {
            // Sin registro (CA-019-23): una hora que no se guarda solo hace que se avise de más.
        }
    }

    private fun decodeConfig(all: Map<String, Any?>): NotificationConfig {
        // Solo el booleano `true` exacto enciende; con el ajuste apagado la cantidad no importa.
        if (all[DerivedKeys.ON] != true) return NotificationConfig.OFF
        val perDay = all[DerivedKeys.PER_DAY] as? Int
        if (perDay == null || !NotificationTimes.isValidCount(perDay)) return NotificationConfig.OFF
        return NotificationConfig(on = true, perDay = perDay, language = LanguageChoice.fromStored(all[DerivedKeys.LANG]))
    }

    /** Milisegundos desde 1970 como `Long` y mayores que 0; `0`, negativos o de otro tipo = sin dato. */
    private fun decodeInstant(raw: Any?): Instant? {
        val millis = raw as? Long ?: return null
        return if (millis > 0L) Instant.ofEpochMilli(millis) else null
    }
}

/** Adaptador de Android: una escritura por cambio, con el tipo exacto de cada valor. */
class SharedPreferencesBacking(private val prefs: SharedPreferences) : KeyValueBacking {
    override fun all(): Map<String, Any?> = prefs.all

    override fun commit(values: Map<String, Any>): Boolean = edit(values).commit()

    override fun apply(values: Map<String, Any>) {
        edit(values).apply()
    }

    private fun edit(values: Map<String, Any>): SharedPreferences.Editor {
        val editor = prefs.edit()
        for ((key, value) in values) {
            when (value) {
                is Boolean -> editor.putBoolean(key, value)
                is Int -> editor.putInt(key, value)
                is Long -> editor.putLong(key, value)
                is String -> editor.putString(key, value)
                else -> throw IllegalArgumentException("tipo no admitido")
            }
        }
        return editor
    }
}

object DerivedStores {
    /** Archivo de preferencias del almacenamiento «device protected», accesible antes del primer desbloqueo. */
    const val FILE = "una_notifications"

    /** Se abre sobre el almacenamiento protegido del dispositivo, no el cifrado por credenciales. */
    fun open(context: Context): DerivedStore {
        val protectedContext = context.createDeviceProtectedStorageContext()
        return PersistedDerivedStore(
            SharedPreferencesBacking(protectedContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)),
        )
    }
}
