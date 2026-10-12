package invalid.pending.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/** CA-019-05, 21: lo que llega de Dart por `configure` también es entrada no fiable (plan §3.5). */
class ChannelArgumentsTest {
    private fun args(on: Any? = true, perDay: Any? = 2, lang: Any? = "system") =
        mapOf("on" to on, "perDay" to perDay, "lang" to lang)

    @Test
    fun `CA-019-05 argumentos validos se convierten en la configuracion`() {
        assertEquals(
            NotificationConfig(true, 2, LanguageChoice.SYSTEM),
            ChannelArguments.parseConfigure(args()),
        )
        assertEquals(
            NotificationConfig(false, 1, LanguageChoice.ES),
            ChannelArguments.parseConfigure(args(on = false, perDay = 1, lang = "es")),
        )
        assertEquals(
            NotificationConfig(true, 3, LanguageChoice.EN),
            ChannelArguments.parseConfigure(args(perDay = 3, lang = "en")),
        )
    }

    @Test
    fun `CA-019-05 la cantidad solo vale 1, 2 o 3 como entero`() {
        for (bad in listOf<Any?>(0, 4, -1, 100, Int.MAX_VALUE, "2", 2.0, 1.5, 2L, true, null, listOf(2))) {
            assertNull("perDay=$bad", ChannelArguments.parseConfigure(args(perDay = bad)))
        }
        for (good in 1..3) {
            assertNotNull(ChannelArguments.parseConfigure(args(perDay = good)))
        }
    }

    @Test
    fun `CA-019-05 el interruptor solo vale como booleano`() {
        for (bad in listOf<Any?>("true", 1, 0, null, "on")) {
            assertNull("on=$bad", ChannelArguments.parseConfigure(args(on = bad)))
        }
    }

    @Test
    fun `CA-019-21 el idioma solo vale system, es o en exactos`() {
        for (bad in listOf<Any?>("fr", "ES", "En", " es", "es ", "", "ca", null, 1, true)) {
            assertNull("lang=$bad", ChannelArguments.parseConfigure(args(lang = bad)))
        }
    }

    @Test
    fun `CA-019-05 sin mapa, vacio o con claves que faltan no es valido`() {
        assertNull(ChannelArguments.parseConfigure(null))
        assertNull(ChannelArguments.parseConfigure("on"))
        assertNull(ChannelArguments.parseConfigure(true))
        assertNull(ChannelArguments.parseConfigure(emptyMap<String, Any?>()))
        assertNull(ChannelArguments.parseConfigure(mapOf("on" to true, "perDay" to 1)))
        assertNull(ChannelArguments.parseConfigure(mapOf("on" to true, "lang" to "es")))
        assertNull(ChannelArguments.parseConfigure(mapOf("perDay" to 1, "lang" to "es")))
    }

    @Test
    fun `CA-019-05 las claves de mas se ignoran sin dejar entrar nada`() {
        val parsed = ChannelArguments.parseConfigure(args() + ("texto" to "Llamar a Marta"))
        assertEquals(NotificationConfig(true, 2, LanguageChoice.SYSTEM), parsed)
    }

    @Test
    fun `CA-019-19a setForeground solo admite un booleano`() {
        assertEquals(true, ChannelArguments.parseForeground(true))
        assertEquals(false, ChannelArguments.parseForeground(false))
        for (bad in listOf<Any?>(null, "true", 1, 0, mapOf("on" to true))) {
            assertNull("arg=$bad", ChannelArguments.parseForeground(bad))
        }
    }
}
