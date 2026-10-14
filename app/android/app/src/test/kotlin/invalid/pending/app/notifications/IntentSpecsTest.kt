package invalid.pending.app.notifications

import android.app.PendingIntent
import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * CA-020-28 (plan §3.3, 12b): las órdenes (`PendingIntent`) que la app deja al sistema son
 * **explícitas** (clase destino de esta app) e **inmutables** (`FLAG_IMMUTABLE`, nunca
 * `FLAG_MUTABLE`), con acción fija y sin datos. Los adaptadores solo traducen estas descripciones.
 */
class IntentSpecsTest {
    private val all =
        listOf(
            "alarma" to IntentSpecs.wakeAlarm(create = true),
            "alarma sin crear" to IntentSpecs.wakeAlarm(create = false),
            "abrir" to IntentSpecs.openCurrentTask(),
        )

    @Test
    fun `CA-020-28 todas llevan FLAG_IMMUTABLE y ninguna FLAG_MUTABLE`() {
        for ((name, spec) in all) {
            assertTrue(name, spec.flags and PendingIntent.FLAG_IMMUTABLE != 0)
            assertEquals(name, 0, spec.flags and PendingIntent.FLAG_MUTABLE)
        }
    }

    @Test
    fun `CA-020-28 todas tienen un destino explicito de la propia app y una accion fija`() {
        for ((name, spec) in all) {
            assertNotNull(name, spec.target)
            assertTrue(name, spec.action.startsWith("invalid.pending.app.action."))
            // Ninguna es una acción genérica del sistema que otra app pudiera resolver.
            assertFalse(name, spec.action.startsWith("android."))
        }
    }

    @Test
    fun `CA-020-28 la alarma va al receptor con la accion de la lista blanca`() {
        val spec = IntentSpecs.wakeAlarm(create = true)
        assertEquals(PendingTarget.WAKE_RECEIVER, spec.target)
        assertEquals(PendingKind.BROADCAST, spec.kind)
        assertEquals(WakeActions.ALARM, spec.action)
        assertEquals(WakeReason.ALARM, WakeActions.reasonFor(spec.action))
        assertEquals(null, spec.nonceExtra)
        assertEquals(0, spec.intentFlags)
    }

    @Test
    fun `CA-020-28 la alarma al crear actualiza la existente y al cancelar no crea nada`() {
        val create = IntentSpecs.wakeAlarm(create = true)
        val cancel = IntentSpecs.wakeAlarm(create = false)
        assertTrue(create.flags and PendingIntent.FLAG_UPDATE_CURRENT != 0)
        assertEquals(0, create.flags and PendingIntent.FLAG_NO_CREATE)
        assertTrue(cancel.flags and PendingIntent.FLAG_NO_CREATE != 0)
        assertEquals(0, cancel.flags and PendingIntent.FLAG_UPDATE_CURRENT)
        // Mismo código: es el mismo PendingIntent (si no, cancelar no encontraría la alarma).
        assertEquals(create.requestCode, cancel.requestCode)
        assertEquals(create.target, cancel.target)
        assertEquals(create.action, cancel.action)
    }

    @Test
    fun `CA-020-28 abrir va a la actividad con la accion de ActivationNonce y su nonce`() {
        val spec = IntentSpecs.openCurrentTask()
        assertEquals(PendingTarget.MAIN_ACTIVITY, spec.target)
        assertEquals(PendingKind.ACTIVITY, spec.kind)
        assertEquals(ActivationNonce.ACTION, spec.action)
        assertEquals(ActivationNonce.EXTRA, spec.nonceExtra)
        assertEquals(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP, spec.intentFlags)
        // UPDATE_CURRENT: sin él el sistema reutilizaría el PendingIntent con el nonce viejo.
        assertTrue(spec.flags and PendingIntent.FLAG_UPDATE_CURRENT != 0)
    }

    @Test
    fun `CA-020-28 la alarma y abrir no se confunden entre si`() {
        val alarm = IntentSpecs.wakeAlarm(create = true)
        val open = IntentSpecs.openCurrentTask()
        assertNotEquals(alarm.requestCode, open.requestCode)
        assertNotEquals(alarm.action, open.action)
        assertNotEquals(alarm.target, open.target)
        // La orden de abrir no es una acción que el receptor atienda.
        assertEquals(null, WakeActions.reasonFor(open.action))
    }
}
