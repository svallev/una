package invalid.pending.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * CA-019-16, 30: lo que el receptor hace con las filas de la consulta fija (`TaskQuery`) y el lector
 * con plazo. La consulta en sí (columnas, plan, igualdad con `currentTask()`) la prueba Dart
 * (`native_task_query_contract_test.dart`); la lectura real con el SQLite de Android, el
 * emulador (T-019-14).
 */
class TaskQueryTest {
    private fun noAttachment(body: String?) = TaskRow(body, false, null, null, null)

    private fun row(body: String?, kind: String?, origin: String?, url: String? = null) =
        TaskRow(body, true, kind, origin, url)

    private fun read(vararg rows: TaskRow, splitter: GraphemeSplitter = TestGraphemeSplitter) =
        TaskQuery.interpret(rows.toList(), splitter)

    private fun label(read: TaskRead): TaskLabel? = (read as TaskRead.Task).label

    // --- Interpretar las filas ---

    @Test
    fun `CA-019-15 sin filas no hay tarea`() {
        assertEquals(TaskRead.NoTask, read())
    }

    @Test
    fun `CA-019-16 una tarea de texto lleva su texto como etiqueta`() {
        assertEquals(TaskLabel.Text("Llamar a Marta"), label(read(noAttachment("Llamar a Marta"))))
    }

    @Test
    fun `CA-019-16 foto de la camara, imagen de la galeria, PDF y dominio`() {
        assertEquals(TaskLabel.Photo, label(read(row(null, "image", "camera"))))
        assertEquals(TaskLabel.Image, label(read(row(null, "image", "gallery"))))
        assertEquals(TaskLabel.Pdf, label(read(row(null, "pdf", "file"))))
        assertEquals(
            TaskLabel.Domain("example.org"),
            label(read(row(null, "web", "url", "https://www.example.org/ruta?q=1"))),
        )
    }

    @Test
    fun `CA-019-16 el texto manda sobre cualquier adjunto, tambien web`() {
        assertEquals(TaskLabel.Text("Revisar"), label(read(row("Revisar", "image", "camera"))))
        assertEquals(TaskLabel.Text("Leer"), label(read(row("Leer", "web", "url", "https://example.org"))))
    }

    @Test
    fun `CA-019-16 un texto solo de espacios cuenta como sin texto`() {
        assertEquals(TaskLabel.Photo, label(read(row("  \n ", "image", "camera"))))
    }

    @Test
    fun `CA-019-16 dos filas de adjuntos son un grupo y no tienen etiqueta`() {
        val group = read(row(null, "image", "gallery"), row(null, "image", "gallery"))
        assertNull(label(group))
        // Una mezcla rara tampoco.
        assertNull(label(read(row(null, "image", "gallery"), row(null, "pdf", "file"))))
    }

    @Test
    fun `CA-019-16 un adjunto de tipo u origen desconocido o ilegible no tiene etiqueta`() {
        assertNull(label(read(row(null, "document", "file"))))
        assertNull(label(read(row(null, "image", "scanner"))))
        assertNull(label(read(row(null, null, null))))
        assertNull(label(read(row(null, "web", "url", null)))) // web sin dirección
        assertNull(label(read(row(null, "web", "url", "no es una url"))))
    }

    @Test
    fun `CA-019-16 una tarea sin texto ni adjunto sigue siendo tarea, sin etiqueta`() {
        assertEquals(TaskRead.Task(null), read(noAttachment(null)))
    }

    @Test
    fun `CA-019-16 el tipo de una fila sin adjunto no cuenta`() {
        // `has_attachment` = 0: el resto de columnas, aunque traigan algo, se ignoran.
        val weird = TaskRow(null, false, "image", "camera", null)
        assertEquals(TaskRead.Task(null), read(weird))
    }

    @Test
    fun `CA-019-16 un texto de 10000 caracteres (acotado a 1000 en SQL) sale en 120 letras mas puntos`() {
        val body = "abcdefghij".repeat(100) // lo que deja `substr(body, 1, 1000)`
        assertEquals(TaskLabel.Text("abcdefghij".repeat(12) + "…"), label(read(noAttachment(body))))
    }

    // --- La consulta: sus constantes ---

    @Test
    fun `CA-019-30 la version de esquema que espera es la 3`() {
        assertEquals(3, TaskQuery.EXPECTED_USER_VERSION)
    }

    @Test
    fun `CA-019-16 la consulta es de solo lectura y no lleva parametros ni plantillas`() {
        val sql = TaskQuery.CURRENT_TASK_SQL
        assertTrue(sql.trim().startsWith("SELECT"))
        for (banned in listOf("?", "$", ";")) {
            assertFalse("no debe contener $banned", sql.contains(banned))
        }
        // Palabras enteras: `deleted_at` es una columna, `DELETE` una sentencia.
        for (banned in listOf("INSERT", "UPDATE", "DELETE", "REPLACE", "PRAGMA", "ATTACH", "RETURNING", "OVER", "WITH")) {
            assertFalse("no debe contener $banned", Regex("\\b$banned\\b").containsMatchIn(sql.uppercase()))
        }
        assertTrue(sql.contains("LIMIT 2"))
    }

    // --- El lector con plazo ---

    private class FakeSource(
        var version: Int = TaskQuery.EXPECTED_USER_VERSION,
        var rows: List<TaskRow> = emptyList(),
        var versionFailure: Throwable? = null,
        var rowsFailure: Throwable? = null,
        var blockForMillis: Long = 0,
    ) : TaskRowSource {
        var versionReads = 0
        var rowReads = 0
        @Volatile var cancelled = false
        @Volatile var closed = false

        override fun userVersion(): Int {
            versionReads++
            versionFailure?.let { throw it }
            return version
        }

        override fun rows(): List<TaskRow> {
            rowReads++
            rowsFailure?.let { throw it }
            if (blockForMillis > 0) Thread.sleep(blockForMillis)
            return rows
        }

        override fun cancel() {
            cancelled = true
        }

        override fun close() {
            closed = true
        }
    }

    private fun reader(source: FakeSource, timeoutMillis: Long = 2000) =
        BoundedTaskReader({ source }, TestGraphemeSplitter, timeoutMillis)

    @Test
    fun `CA-019-16 lee la tarea y cierra la base`() {
        val source = FakeSource(rows = listOf(noAttachment("Llamar a Marta")))
        assertEquals(TaskRead.Task(TaskLabel.Text("Llamar a Marta")), reader(source).read())
        assertTrue(source.closed)
        assertFalse(source.cancelled)
    }

    @Test
    fun `CA-019-15 base legible sin tareas es NoTask`() {
        val source = FakeSource(rows = emptyList())
        assertEquals(TaskRead.NoTask, reader(source).read())
        assertTrue(source.closed)
    }

    @Test
    fun `CA-019-30 un esquema distinto del de la app es ilegible y no se consulta`() {
        for (version in listOf(0, 1, 2, 4, 99, -1)) {
            val source = FakeSource(version = version, rows = listOf(noAttachment("x")))
            assertEquals("v$version", TaskRead.Unreadable, reader(source).read())
            assertEquals("v$version", 0, source.rowReads)
            assertTrue(source.closed)
        }
    }

    @Test
    fun `CA-019-30 cualquier fallo al abrir, preguntar o leer es ilegible, tambien un Error`() {
        val failures = listOf(RuntimeException("texto-secreto"), IllegalStateException(), OutOfMemoryError(), StackOverflowError())
        for (failure in failures) {
            val onVersion = FakeSource(versionFailure = failure)
            assertEquals(TaskRead.Unreadable, reader(onVersion).read())
            assertTrue(onVersion.closed)
            val onRows = FakeSource(rowsFailure = failure)
            assertEquals(TaskRead.Unreadable, reader(onRows).read())
            assertTrue(onRows.closed)
        }
        // Al abrir (antes del primer desbloqueo: SQLITE_CANTOPEN).
        val open = BoundedTaskReader({ throw RuntimeException("cantopen") }, TestGraphemeSplitter, 2000)
        assertEquals(TaskRead.Unreadable, open.read())
    }

    @Test
    fun `CA-019-30 si vence el plazo es ilegible, cancela la consulta y vuelve a tiempo`() {
        val source = FakeSource(rows = listOf(noAttachment("x")), blockForMillis = 3000)
        val started = System.nanoTime()
        assertEquals(TaskRead.Unreadable, reader(source, timeoutMillis = 100).read())
        val elapsedMillis = (System.nanoTime() - started) / 1_000_000
        assertTrue("tardó $elapsedMillis ms", elapsedMillis < 1500)
        assertTrue(source.cancelled)
    }

    @Test
    fun `CA-019-16 el plazo por defecto es de unos 3 segundos`() {
        assertEquals(3000L, BoundedTaskReader.DEFAULT_TIMEOUT_MILLIS)
    }

    @Test
    fun `CA-019-30 cada lectura abre su propia fuente`() {
        var opened = 0
        val reader =
            BoundedTaskReader(
                { opened++; FakeSource(rows = listOf(noAttachment("x"))) },
                TestGraphemeSplitter,
                2000,
            )
        reader.read()
        reader.read()
        assertEquals(2, opened)
    }
}
