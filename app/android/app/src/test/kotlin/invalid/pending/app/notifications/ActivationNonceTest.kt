package invalid.pending.app.notifications

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** CA-019-20, P-019-4: el `nonce` de la orden «abrir la tarea actual». */
class ActivationNonceTest {
    @After
    fun tearDown() = ActivationNonce.clear()

    @Test
    fun `CA-019-20 la accion de abrir es fija y propia de la app`() {
        assertEquals("invalid.pending.app.action.OPEN_CURRENT_TASK", ActivationNonce.ACTION)
        assertEquals("nonce", ActivationNonce.EXTRA)
    }

    @Test
    fun `CA-019-20 un nonce de al menos 128 bits y distinto cada vez`() {
        val seen = mutableSetOf<String>()
        repeat(50) {
            val nonce = ActivationNonce.issue()
            // 16 bytes en hexadecimal = 32 caracteres como mínimo.
            assertTrue(nonce.length >= 32)
            assertTrue(nonce.all { it in '0'..'9' || it in 'a'..'f' })
            assertTrue("repetido", seen.add(nonce))
        }
    }

    @Test
    fun `CA-019-20 se acepta una vez y solo una`() {
        val nonce = ActivationNonce.issue()
        assertTrue(ActivationNonce.consume(nonce))
        assertFalse(ActivationNonce.consume(nonce))
    }

    @Test
    fun `CA-019-20 uno nuevo sustituye al anterior`() {
        val old = ActivationNonce.issue()
        val new = ActivationNonce.issue()
        assertNotEquals(old, new)
        assertFalse(ActivationNonce.consume(old))
        assertTrue(ActivationNonce.consume(new))
    }

    @Test
    fun `CA-019-20 sin nonce, vacio, ajeno o nulo se rechaza sin gastar el vigente`() {
        assertFalse(ActivationNonce.consume(null))
        assertFalse(ActivationNonce.consume("")) // nada emitido
        val nonce = ActivationNonce.issue()
        assertFalse(ActivationNonce.consume(null))
        assertFalse(ActivationNonce.consume(""))
        assertFalse(ActivationNonce.consume("00000000000000000000000000000000"))
        assertFalse(ActivationNonce.consume(nonce + "0"))
        assertFalse(ActivationNonce.consume(nonce.dropLast(1)))
        // El vigente sigue valiendo: un intento ajeno no lo gasta.
        assertTrue(ActivationNonce.consume(nonce))
    }

    @Test
    fun `CA-019-19b quitar la notificacion o apagar invalida el nonce`() {
        val nonce = ActivationNonce.issue()
        ActivationNonce.clear()
        assertFalse(ActivationNonce.consume(nonce))
    }
}
