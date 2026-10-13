package invalid.pending.app.notifications

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Almacen clave-valor falso: guarda lo escrito y puede fallar o lanzar, como `SharedPreferences`. */
private class FakeBacking(initial: Map<String, Any?> = emptyMap()) : KeyValueBacking {
    val values = initial.toMutableMap()

    /** Todo lo que se intento escribir, en texto, para buscar contenido que no debe estar. */
    val writes = mutableListOf<Map<String, Any>>()
    var failCommit = false
    var failRead: Throwable? = null
    var applies = 0
    var commits = 0

    override fun all(): Map<String, Any?> {
        failRead?.let { throw it }
        return values.toMap()
    }

    override fun commit(values: Map<String, Any>): Boolean {
        commits++
        writes += values
        if (failCommit) return false
        this.values.putAll(values)
        return true
    }

    override fun apply(values: Map<String, Any>) {
        applies++
        writes += values
        this.values.putAll(values)
    }
}

/** CA-019-05 y CA-019-23: la copia derivada son cinco claves, se lee como entrada no fiable y nunca lleva texto. */
class DerivedStoreTest {
    private val five = setOf("on", "perDay", "lang", "lastAttended", "foregroundAt")

    private fun store(vararg entries: Pair<String, Any?>): Pair<PersistedDerivedStore, FakeBacking> {
        val backing = FakeBacking(mapOf(*entries))
        return PersistedDerivedStore(backing) to backing
    }

    @Test
    fun `CA-019-23 las claves son exactamente las cinco de la lista cerrada`() {
        assertEquals(five, DerivedKeys.ALL)
    }

    @Test
    fun `CA-019-05 sin nada guardado equivale a apagado`() {
        val (s, _) = store()
        val state = s.read()
        assertEquals(NotificationConfig.OFF, state.config)
        assertNull(state.lastAttended)
        assertNull(state.foregroundAt)
    }

    @Test
    fun `CA-019-23 lee una copia valida`() {
        val (s, _) =
            store(
                "on" to true,
                "perDay" to 3,
                "lang" to "es",
                "lastAttended" to 1_700_000_000_000L,
                "foregroundAt" to 1_700_000_100_000L,
            )
        val state = s.read()
        assertEquals(NotificationConfig(true, 3, LanguageChoice.ES), state.config)
        assertEquals(Instant.ofEpochMilli(1_700_000_000_000L), state.lastAttended)
        assertEquals(Instant.ofEpochMilli(1_700_000_100_000L), state.foregroundAt)
    }

    @Test
    fun `CA-019-05 un on que no es exactamente el booleano true equivale a apagado`() {
        for (raw in listOf<Any?>("true", "TRUE", 1, 1L, 1.0, "1", listOf(true), null, false)) {
            val (s, _) = store("on" to raw, "perDay" to 2, "lang" to "en")
            assertFalse("on=$raw", s.read().config.on)
        }
    }

    @Test
    fun `CA-019-05 encendido con una cantidad que no es un entero de 1 a 3 equivale a apagado`() {
        for (raw in listOf<Any?>(0, 4, -1, 1.5, 2.0, 2L, "2", "1", listOf(2), null)) {
            val (s, _) = store("on" to true, "perDay" to raw, "lang" to "es")
            assertEquals("perDay=$raw", NotificationConfig.OFF, s.read().config)
        }
    }

    @Test
    fun `CA-019-05 cantidades validas 1 2 y 3`() {
        for (n in 1..3) {
            val (s, _) = store("on" to true, "perDay" to n)
            assertEquals(n, s.read().config.perDay)
            assertTrue(s.read().config.on)
        }
    }

    @Test
    fun `CA-019-05 un idioma fuera de system es en equivale a system`() {
        for (raw in listOf<Any?>("fr", "ES", "es-ES", "", 1, true, null, listOf("es"))) {
            val (s, _) = store("on" to true, "perDay" to 1, "lang" to raw)
            assertEquals("lang=$raw", LanguageChoice.SYSTEM, s.read().config.language)
        }
        for ((raw, expected) in listOf("system" to LanguageChoice.SYSTEM, "es" to LanguageChoice.ES, "en" to LanguageChoice.EN)) {
            val (s, _) = store("on" to true, "perDay" to 1, "lang" to raw)
            assertEquals(expected, s.read().config.language)
        }
    }

    @Test
    fun `CA-019-14 una ultima hora de tipo raro o negativa se ignora`() {
        for (raw in listOf<Any?>(5, "123", 1.5, true, -1L, listOf(1L), null)) {
            val (s, _) = store("on" to true, "perDay" to 1, "lastAttended" to raw)
            assertNull("lastAttended=$raw", s.read().lastAttended)
        }
    }

    @Test
    fun `CA-019-19a un indicador de a la vista de 0 o de tipo raro es no estar a la vista`() {
        for (raw in listOf<Any?>(0L, 7, "9", false, -5L, null)) {
            val (s, _) = store("on" to true, "perDay" to 1, "foregroundAt" to raw)
            assertNull("foregroundAt=$raw", s.read().foregroundAt)
        }
    }

    @Test
    fun `CA-019-05 si no se puede leer la copia equivale a apagado y no lanza`() {
        for (failure in listOf<Throwable>(ClassCastException("x"), RuntimeException("texto-secreto"), IllegalStateException())) {
            val backing = FakeBacking(mapOf("on" to true, "perDay" to 1)).also { it.failRead = failure }
            val state = PersistedDerivedStore(backing).read()
            assertEquals(NotificationConfig.OFF, state.config)
            assertNull(state.lastAttended)
            assertNull(state.foregroundAt)
        }
    }

    @Test
    fun `CA-019-23 una clave extra con texto no aparece en el estado leido ni se reescribe`() {
        val (s, backing) =
            store("on" to true, "perDay" to 1, "task" to "TEXTO-SECRETO", "lang" to "TEXTO-SECRETO")
        val state = s.read()
        assertFalse(state.toString().contains("SECRETO"))
        s.writeConfig(NotificationConfig(true, 2, LanguageChoice.EN))
        s.writeLastAttended(Instant.ofEpochMilli(5))
        s.writeForegroundAt(Instant.ofEpochMilli(6))
        assertFalse(backing.writes.toString().contains("SECRETO"))
    }

    @Test
    fun `CA-019-23 writeConfig escribe solo on perDay y lang, con commit`() {
        val (s, backing) = store()
        assertTrue(s.writeConfig(NotificationConfig(true, 2, LanguageChoice.EN)))
        assertEquals(1, backing.commits)
        assertEquals(0, backing.applies)
        assertEquals(mapOf<String, Any>("on" to true, "perDay" to 2, "lang" to "en"), backing.writes.single())
    }

    @Test
    fun `CA-019-02 writeConfig devuelve false si el commit falla`() {
        val (s, backing) = store()
        backing.failCommit = true
        assertFalse(s.writeConfig(NotificationConfig(true, 1, LanguageChoice.SYSTEM)))
    }

    @Test
    fun `CA-019-05 writeConfig no escribe una cantidad fuera de 1 a 3`() {
        for (n in listOf(0, 4, -1, 99)) {
            val (s, backing) = store()
            assertFalse(s.writeConfig(NotificationConfig(true, n, LanguageChoice.ES)))
            assertTrue("n=$n", backing.writes.isEmpty())
        }
    }

    @Test
    fun `CA-019-02 writeConfig apagando conserva la cantidad`() {
        val (s, backing) = store()
        assertTrue(s.writeConfig(NotificationConfig(false, 3, LanguageChoice.ES)))
        assertEquals(false, backing.writes.single()["on"])
        assertEquals(3, backing.writes.single()["perDay"])
    }

    @Test
    fun `CA-019-02 writeConfig devuelve false si el almacen lanza`() {
        val backing =
            object : KeyValueBacking {
                override fun all(): Map<String, Any?> = emptyMap()

                override fun commit(values: Map<String, Any>): Boolean = throw IllegalStateException("texto-secreto")

                override fun apply(values: Map<String, Any>) = Unit
            }
        assertFalse(PersistedDerivedStore(backing).writeConfig(NotificationConfig(true, 1, LanguageChoice.ES)))
    }

    @Test
    fun `CA-019-14 la ultima hora y el indicador se guardan con apply, como milisegundos`() {
        val (s, backing) = store()
        s.writeLastAttended(Instant.ofEpochMilli(1234))
        s.writeForegroundAt(Instant.ofEpochMilli(5678))
        s.writeForegroundAt(null)
        assertEquals(3, backing.applies)
        assertEquals(0, backing.commits)
        assertEquals(mapOf<String, Any>("lastAttended" to 1234L), backing.writes[0])
        assertEquals(mapOf<String, Any>("foregroundAt" to 5678L), backing.writes[1])
        assertEquals(mapOf<String, Any>("foregroundAt" to 0L), backing.writes[2])
    }

    @Test
    fun `CA-019-23 ninguna escritura usa una clave fuera de las cinco`() {
        val (s, backing) = store()
        s.writeConfig(NotificationConfig(true, 3, LanguageChoice.ES))
        s.writeLastAttended(Instant.ofEpochMilli(1))
        s.writeForegroundAt(Instant.ofEpochMilli(2))
        s.writeForegroundAt(null)
        val keys = backing.writes.flatMap { it.keys }.toSet()
        assertTrue(five.containsAll(keys))
        assertEquals(five, keys)
    }

    @Test
    fun `CA-019-13 lo escrito se lee de vuelta`() {
        val (s, _) = store()
        s.writeConfig(NotificationConfig(true, 2, LanguageChoice.EN))
        s.writeLastAttended(Instant.ofEpochMilli(1_700_000_000_000L))
        s.writeForegroundAt(Instant.ofEpochMilli(1_700_000_001_000L))
        val state = s.read()
        assertEquals(NotificationConfig(true, 2, LanguageChoice.EN), state.config)
        assertEquals(Instant.ofEpochMilli(1_700_000_000_000L), state.lastAttended)
        assertEquals(Instant.ofEpochMilli(1_700_000_001_000L), state.foregroundAt)
        s.writeForegroundAt(null)
        assertNull(s.read().foregroundAt)
    }
}
