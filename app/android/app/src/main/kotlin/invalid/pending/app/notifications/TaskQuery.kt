package invalid.pending.app.notifications

import java.util.concurrent.Callable
import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Una fila de la consulta fija ([TaskQuery.CURRENT_TASK_SQL]): el texto de la tarea y, si tiene,
 * uno de sus adjuntos. Todo puede faltar o venir raro (una copia restaurada manipulada): se trata
 * como entrada no fiable.
 */
data class TaskRow(
    val body: String?,
    /** `false` = la tarea no tiene adjunto (el resto de columnas del adjunto se ignoran). */
    val hasAttachment: Boolean,
    val kind: String?,
    val origin: String?,
    val url: String?,
)

/**
 * La consulta de la tarea actual que corre con la app cerrada (plan §3.3, P-019-10) y cómo se
 * interpretan sus filas. Núcleo puro: sin `android.*`.
 *
 * **Contrato con la app:** `test/data/native_task_query_contract_test.dart` extrae el texto de
 * [CURRENT_TASK_SQL] de este archivo, lo ejecuta con drift sobre una base creada por las migraciones
 * y comprueba que da la misma tarea y el mismo primer adjunto que `TaskRepository.currentTask()`,
 * que su plan no recorre ninguna tabla entera y que [EXPECTED_USER_VERSION] es la `schemaVersion`
 * de la app. Cualquier cambio de esquema que la toque rompe la CI (ADR-0025).
 */
object TaskQuery {
    /** El `PRAGMA user_version` de la base de la app (`AppDatabase.schemaVersion`); otro valor = ilegible. */
    const val EXPECTED_USER_VERSION = 3

    /**
     * Constante, **sin parámetros del usuario**, solo lectura y compatible con SQLite 3.18 (Android 8:
     * sin funciones de ventana ni `RETURNING`). Copia el criterio de `DriftTaskRepository`: la primera
     * pendiente por `(rank, id)`. Acotada **en SQL** (una base manipulada no carga 10 MB): el texto
     * a 1000 letras (la etiqueta usa 120), la dirección a 2048, el tipo y el origen a 32, y de los
     * adjuntos las dos primeras filas por `(position, id)`, que bastan para saber «uno» o «varios».
     * La unión busca cada adjunto por clave (`IN (… LIMIT 2)`), sin recorrer la tabla.
     */
    const val CURRENT_TASK_SQL = """
SELECT substr(t.body, 1, 1000) AS body,
       a.id IS NOT NULL AS has_attachment,
       substr(a.kind, 1, 32) AS kind,
       substr(a.origin, 1, 32) AS origin,
       substr(a.source_url, 1, 2048) AS url
FROM tasks t
LEFT JOIN attachments a ON a.id IN (
    SELECT a2.id FROM attachments a2 WHERE a2.task_id = t.id ORDER BY a2.position, a2.id LIMIT 2)
WHERE t.id = (
    SELECT t2.id FROM tasks t2
    WHERE t2.status = 'pending' AND t2.deleted_at IS NULL
    ORDER BY t2.rank, t2.id LIMIT 1)
ORDER BY a.position, a.id
"""

    /**
     * Sin filas = no queda ninguna tarea. Si hay, la etiqueta sale de [TaskLabel.of]: el texto
     * manda; sin texto, **dos filas = grupo = sin etiqueta** (versión genérica), como un adjunto de
     * tipo u origen desconocido o una web sin dirección legible.
     */
    fun interpret(rows: List<TaskRow>, splitter: GraphemeSplitter): TaskRead {
        val first = rows.firstOrNull() ?: return TaskRead.NoTask
        val attachments =
            rows.filter { it.hasAttachment }.map { AttachmentSnapshot(it.kind, it.origin, it.url) }
        return TaskRead.Task(TaskLabel.of(TaskSnapshot(first.body, attachments), splitter))
    }
}

/** De dónde salen las filas: la base de Android en la app, un doble en las pruebas. Un uso y se cierra. */
interface TaskRowSource : AutoCloseable {
    /** El `PRAGMA user_version` de la base. */
    fun userVersion(): Int

    /** Las filas de [TaskQuery.CURRENT_TASK_SQL] (como mucho dos). */
    fun rows(): List<TaskRow>

    /** Interrumpe una consulta en curso (se llama desde otro hilo al vencer el plazo). */
    fun cancel()
}

/**
 * El [TaskReader] del receptor: abre la fuente, comprueba el esquema y lee, **todo dentro de un
 * plazo** (~3 s). Cualquier fallo —no abrir (antes del primer desbloqueo), esquema ajeno, base
 * ocupada o corrupta, plazo vencido, hasta un `Error`— es [TaskRead.Unreadable], sin registrar
 * nada (CA-019-23) y sin dejar salir el texto de la excepción.
 */
class BoundedTaskReader(
    private val open: () -> TaskRowSource,
    private val splitter: GraphemeSplitter,
    private val timeoutMillis: Long = DEFAULT_TIMEOUT_MILLIS,
) : TaskReader {
    override fun read(): TaskRead {
        val opened = AtomicReference<TaskRowSource?>()
        val work =
            FutureTask(
                Callable<TaskRead> {
                    open().also(opened::set).use { source ->
                        if (source.userVersion() != TaskQuery.EXPECTED_USER_VERSION) {
                            TaskRead.Unreadable
                        } else {
                            TaskQuery.interpret(source.rows(), splitter)
                        }
                    }
                },
            )
        return try {
            // Un hilo propio y de servicio: si la consulta no vuelve a tiempo, el receptor sigue.
            Thread(work).apply { isDaemon = true }.start()
            work.get(timeoutMillis, TimeUnit.MILLISECONDS)
        } catch (_: Throwable) {
            try {
                opened.get()?.cancel()
            } catch (_: Throwable) {
                // Sin registro (CA-019-23): da igual cómo acabó la cancelación.
            }
            work.cancel(true)
            TaskRead.Unreadable
        }
    }

    companion object {
        const val DEFAULT_TIMEOUT_MILLIS = 3000L
    }
}
