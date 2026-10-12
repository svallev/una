package invalid.pending.app.notifications

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.os.CancellationSignal
import java.io.File

/**
 * Lee la base de la app **solo en lectura** con el SQLite del sistema (plan §3.3). Abre
 * `<dataDir>/app_flutter/una.sqlite` —el almacenamiento cifrado por credenciales, la misma ruta que
 * `getApplicationDocumentsDirectory()` en `open_database_native.dart`, **no** el «device protected»
 * de la copia derivada—, así que antes del primer desbloqueo no abre (`SQLITE_CANTOPEN`) y el
 * lector lo trata como ilegible (CA-019-30). `OPEN_READONLY`, `PRAGMA query_only` y una consulta
 * constante ([TaskQuery.CURRENT_TASK_SQL]): no escribe nunca ni usa nada del usuario.
 *
 * Cualquier excepción sale tal cual hacia [BoundedTaskReader], que la convierte en «ilegible» sin
 * registrar nada (CA-019-23). Es la segunda copia de SQLite del proceso (P-019-12, residual
 * aceptado por el propietario).
 */
class SqliteRowSource(context: Context) : TaskRowSource {
    private val file = File(context.applicationInfo.dataDir, "app_flutter/una.sqlite")
    private val signal = CancellationSignal()
    private var db: SQLiteDatabase? = null

    private fun database(): SQLiteDatabase =
        db
            ?: SQLiteDatabase
                .openDatabase(
                    file.path,
                    null,
                    SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS,
                ).also {
                    db = it
                    it.execSQL("PRAGMA query_only = ON")
                }

    override fun userVersion(): Int = database().version

    override fun rows(): List<TaskRow> {
        val out = ArrayList<TaskRow>(2)
        database().rawQuery(TaskQuery.CURRENT_TASK_SQL, null, signal).use { cursor ->
            // La consulta devuelve como mucho dos filas; el tope es una defensa más.
            while (cursor.moveToNext() && out.size < MAX_ROWS) {
                out +=
                    TaskRow(
                        body = cursor.text(0),
                        hasAttachment = cursor.getInt(1) == 1,
                        kind = cursor.text(2),
                        origin = cursor.text(3),
                        url = cursor.text(4),
                    )
            }
        }
        return out
    }

    override fun cancel() = signal.cancel()

    override fun close() {
        db?.close()
        db = null
    }

    private fun Cursor.text(column: Int): String? = if (isNull(column)) null else getString(column)

    private companion object {
        const val MAX_ROWS = 4
    }
}
