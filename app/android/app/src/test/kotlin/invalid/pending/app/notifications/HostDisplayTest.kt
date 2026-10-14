package invalid.pending.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * CA-019-16, CL-019-13 a 15: el dominio de la etiqueta es el de la barra de la tarea web (CA-009-14).
 * Los casos son los mismos que lee `test/domain/notification_parity_test.dart` contra Dart.
 */
class HostDisplayTest {
    @Test
    fun `CA-019-16 hosts txt - cada caso da lo mismo que Dart`() {
        val cases = Fixtures.cases("hosts.txt", 3)
        assertTrue("faltan casos", cases.size > 30)
        assertEquals(setOf("host", "hostWww", "url"), cases.map { it.columns[0] }.toSet())
        for (case in cases) {
            val (kind, rawInput, rawExpected) = case.columns
            val input = Fixtures.nullable(rawInput)
            val expected = Fixtures.nullable(rawExpected)
            val actual =
                when (kind) {
                    "host" -> HostDisplay.displayHost(input!!)
                    "hostWww" -> HostDisplay.displayHost(input!!, dropWww = true)
                    "url" -> HostDisplay.webAddressHost(input)
                    else -> error("tipo desconocido $kind")
                }
            assertEquals("$case $kind $rawInput", expected, actual)
        }
    }

    @Test
    fun `CA-019-16 punycode - vectores conocidos y ida y vuelta`() {
        val bucher = "bücher"
        val cyrillicPple = "\u0430pple"
        val primer = "пример"
        val nihongo = "日本語"
        assertEquals(bucher, HostDisplay.fromPunycodeLabel("xn--bcher-kva"))
        assertEquals(cyrillicPple, HostDisplay.fromPunycodeLabel("xn--pple-43d"))
        assertEquals(primer, HostDisplay.fromPunycodeLabel("xn--e1afmkfd"))
        assertEquals(nihongo, HostDisplay.fromPunycodeLabel("xn--wgv71a119e"))
        for (label in listOf(bucher, cyrillicPple, primer, "españa", nihongo, "ñ", "a-ü-b")) {
            val encoded = HostDisplay.toPunycodeLabel(label)
            assertTrue(encoded, encoded.startsWith("xn--"))
            assertEquals(label, HostDisplay.fromPunycodeLabel(encoded))
        }
        assertEquals("example", HostDisplay.toPunycodeLabel("example"))
    }

    @Test
    fun `CA-019-16 punycode - lo que no es punycode valido da null`() {
        assertNull(HostDisplay.fromPunycodeLabel("example"))
        assertNull(HostDisplay.fromPunycodeLabel("xn--"))
        assertNull(HostDisplay.fromPunycodeLabel("xn--a!"))
        assertNull(HostDisplay.fromPunycodeLabel("xn--abc-"))
        assertNull(HostDisplay.fromPunycodeLabel("xn--" + "9".repeat(60)))
        // Decodifica a una mitad de par sustituto (U+D800), que no es Unicode válido.
        assertNull(HostDisplay.fromPunycodeLabel("xn--ab-zd9k"))
    }

    @Test
    fun `CA-019-16 un punycode que esconde caracteres peligrosos se queda como llego`() {
        val hidden = HostDisplay.toPunycodeLabel("exa\u202Emple")
        assertTrue(hidden.startsWith("xn--"))
        assertEquals("$hidden.com", HostDisplay.displayHost("$hidden.com"))
    }

    @Test
    fun `CL-019-15 un escape porcentual con UTF-8 mal formado se deja como llego`() {
        // El Kotlin que corre con la app cerrada nunca debe lanzar: devuelve el texto tal cual (en
        // minusculas). Dart hace lo mismo desde CA-020-27.
        assertEquals("%c3.com", HostDisplay.displayHost("%C3.com"))
        assertEquals("%e2%80.com", HostDisplay.displayHost("%E2%80.com"))
    }

    @Test
    fun `CA-020-27 escapes mal formados en el dominio - el texto tal cual y en minusculas`() {
        assertEquals("%c3.es", HostDisplay.displayHost("%C3.es"))
        assertEquals("%.es", HostDisplay.displayHost("%.es"))
        assertEquals("%zz.es", HostDisplay.displayHost("%ZZ.es"))
        assertEquals("%e2%82.es", HostDisplay.displayHost("%E2%82.es"))
        // Un escape valido junto a uno roto: nada se decodifica a medias.
        assertEquals("%c3%b1%c3.es", HostDisplay.displayHost("%C3%B1%C3.es"))
        assertEquals("%c3.es", HostDisplay.webAddressHost("https://%C3.es/"))
        assertEquals("%e2%82.es", HostDisplay.webAddressHost("https://%E2%82.es/"))
        assertEquals("%", HostDisplay.webAddressHost("https://%/"))
        assertEquals("%zz.es", HostDisplay.webAddressHost("https://%ZZ.es/"))
    }

    @Test
    fun `CA-020-27 escapes mal formados en la ruta - el dominio no cambia`() {
        for (path in listOf("%C3", "%", "%ZZ", "%E2%82", "%E2%82?q=%C3#%")) {
            assertEquals(path, "dominio.es", HostDisplay.webAddressHost("https://dominio.es/$path"))
        }
    }

    @Test
    fun `CL-019-15 un host enorme o raro no lanza`() {
        assertNotNull(HostDisplay.displayHost("a".repeat(5000) + ".com"))
        assertEquals("", HostDisplay.displayHost("\u202E\u202D"))
        assertNull(HostDisplay.webAddressHost("https://\u202E/"))
        assertNull(HostDisplay.webAddressHost("https://[::1/"))
        assertNull(HostDisplay.webAddressHost("https://example.com:abc/"))
    }
}
