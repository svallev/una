package invalid.pending.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** CA-019-13 y 25: el receptor solo atiende una lista blanca de acciones; cualquier otra se ignora. */
class WakeActionsTest {
    @Test
    fun `CA-019-13 cada difusion del sistema y la alarma propia tienen su motivo`() {
        assertEquals(WakeReason.LOCKED_BOOT_COMPLETED, WakeActions.reasonFor("android.intent.action.LOCKED_BOOT_COMPLETED"))
        assertEquals(WakeReason.BOOT_COMPLETED, WakeActions.reasonFor("android.intent.action.BOOT_COMPLETED"))
        assertEquals(WakeReason.TIME_SET, WakeActions.reasonFor("android.intent.action.TIME_SET"))
        assertEquals(WakeReason.TIMEZONE_CHANGED, WakeActions.reasonFor("android.intent.action.TIMEZONE_CHANGED"))
        assertEquals(WakeReason.LOCALE_CHANGED, WakeActions.reasonFor("android.intent.action.LOCALE_CHANGED"))
        assertEquals(WakeReason.PACKAGE_REPLACED, WakeActions.reasonFor("android.intent.action.MY_PACKAGE_REPLACED"))
        assertEquals(WakeReason.ALARM, WakeActions.reasonFor(WakeActions.ALARM))
    }

    @Test
    fun `CA-025 cualquier otra accion se ignora sin evaluar nada`() {
        val others =
            listOf(
                null,
                "",
                " ",
                "android.intent.action.MAIN",
                "android.intent.action.QUICKBOOT_POWERON",
                "com.htc.intent.action.QUICKBOOT_POWERON",
                "android.intent.action.BOOT_COMPLETED ",
                "android.intent.action.boot_completed",
                "android.intent.action.PACKAGE_REPLACED",
                "android.intent.action.ACTION_SHUTDOWN",
                "android.intent.action.TIME_TICK",
                "invalid.pending.app.action.NOTIFICATION_ALARM.x",
            )
        for (action in others) assertNull("action=$action", WakeActions.reasonFor(action))
    }

    @Test
    fun `CA-025 las difusiones del manifiesto son seis y la alarma propia no es una de ellas`() {
        assertEquals(6, WakeActions.SYSTEM_BROADCASTS.size)
        assertTrue(WakeActions.ALARM !in WakeActions.SYSTEM_BROADCASTS)
        for (action in WakeActions.SYSTEM_BROADCASTS) assertTrue(action, WakeActions.reasonFor(action) != null)
    }
}
