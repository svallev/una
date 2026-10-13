package invalid.pending.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** CA-019-07, 08b: la petición del permiso de Android 13+ y el «se mostró el diálogo» (P-019-14). */
class PermissionRequestsTest {
    private val replies = mutableListOf<PermissionReply>()
    private val requests = PermissionRequests()

    private fun begin() = requests.begin { replies += it }

    @Test
    fun `CA-019-07 solo se pide en Android 13 o posterior y con el permiso sin conceder`() {
        assertFalse(PermissionRequests.needsPrompt(sdk = 26, granted = false))
        assertFalse(PermissionRequests.needsPrompt(sdk = 32, granted = false))
        assertTrue(PermissionRequests.needsPrompt(sdk = 33, granted = false))
        assertTrue(PermissionRequests.needsPrompt(sdk = 37, granted = false))
        assertFalse(PermissionRequests.needsPrompt(sdk = 33, granted = true))
        assertFalse(PermissionRequests.needsPrompt(sdk = 37, granted = true))
    }

    @Test
    fun `CA-019-08b el usuario concede y el dialogo salio, la actividad perdio el foco`() {
        assertTrue(begin())
        requests.onFocusChanged(false)
        requests.onFocusChanged(true)
        requests.onResult(granted = true)
        assertEquals(listOf(PermissionReply(granted = true, dialogShown = true)), replies)
    }

    @Test
    fun `CA-019-08b el usuario rechaza con el dialogo`() {
        begin()
        requests.onFocusChanged(false)
        requests.onFocusChanged(true)
        requests.onResult(granted = false)
        assertEquals(listOf(PermissionReply(granted = false, dialogShown = true)), replies)
    }

    @Test
    fun `CA-019-08b rechazo inmediato sin dialogo, el foco no se movio`() {
        begin()
        requests.onResult(granted = false)
        assertEquals(listOf(PermissionReply(granted = false, dialogShown = false)), replies)
    }

    @Test
    fun `CA-019-08b un cambio de foco anterior a la peticion no cuenta`() {
        requests.onFocusChanged(false)
        requests.onFocusChanged(true)
        begin()
        requests.onResult(granted = false)
        assertEquals(false, replies.single().dialogShown)
    }

    @Test
    fun `CA-019-08b ganar el foco sin haberlo perdido no cuenta como dialogo`() {
        begin()
        requests.onFocusChanged(true)
        requests.onResult(granted = true)
        assertEquals(PermissionReply(granted = true, dialogShown = false), replies.single())
    }

    @Test
    fun `CA-019-07 una sola respuesta por peticion y la siguiente empieza limpia`() {
        begin()
        requests.onFocusChanged(false)
        requests.onResult(granted = true)
        requests.onResult(granted = true) // un resultado repetido o sin peticion se ignora
        assertEquals(1, replies.size)
        assertFalse(requests.pending)
        begin()
        requests.onResult(granted = false)
        assertEquals(PermissionReply(granted = false, dialogShown = false), replies.last())
    }

    @Test
    fun `CA-019-07 un resultado sin peticion se ignora`() {
        requests.onResult(granted = true)
        assertTrue(replies.isEmpty())
    }

    @Test
    fun `CA-019-07 una segunda peticion mientras hay otra no se registra y la primera sigue`() {
        assertTrue(begin())
        val second = mutableListOf<PermissionReply>()
        assertFalse(requests.begin { second += it })
        requests.onResult(granted = true)
        assertEquals(1, replies.size)
        assertTrue(second.isEmpty())
    }

    @Test
    fun `plan 3_5 si la actividad se recrea con la peticion pendiente vale no concedido`() {
        begin()
        requests.onFocusChanged(false)
        requests.abandon()
        assertEquals(1, replies.size)
        assertFalse(replies.single().granted)
        assertFalse(requests.pending)
        requests.onResult(granted = true) // ya no hay a quien contestar
        assertEquals(1, replies.size)
    }

    @Test
    fun `abandonar sin peticion no hace nada`() {
        requests.abandon()
        assertTrue(replies.isEmpty())
    }

    @Test
    fun `la respuesta al canal es un mapa con granted y dialogShown`() {
        assertEquals(
            mapOf("granted" to true, "dialogShown" to false),
            PermissionReply(granted = true, dialogShown = false).toMap(),
        )
    }
}
