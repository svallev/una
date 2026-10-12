package invalid.pending.app.notifications

import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Un temporizador falso: guarda una sola acción pendiente. */
class FakeHeartbeatTimer : HeartbeatTimer {
    var delay: Duration? = null
    private var action: (() -> Unit)? = null
    var schedules = 0
    var cancels = 0

    val scheduled: Boolean get() = action != null

    override fun schedule(delay: Duration, action: () -> Unit) {
        schedules++
        this.delay = delay
        this.action = action
    }

    override fun cancel() {
        cancels++
        action = null
    }

    fun fire() {
        val pending = action ?: return
        action = null
        pending()
    }
}

/** CA-019-19a, P-019-5: «a la vista» con latido, `onStop` lo limpia y `onResume` lo restaura. */
class ForegroundTrackerTest {
    private val start = at(day = 12, hour = 10)
    private val clock = FakeClock(start)
    private val timer = FakeHeartbeatTimer()
    private val store = FakeStore(DerivedState(NotificationConfig(true, 1, LanguageChoice.SYSTEM), null, null))
    private val tracker = ForegroundTracker(clock, store, timer)

    private fun turnOff() {
        store.state = store.state.copy(config = NotificationConfig.OFF)
    }

    @Test
    fun `CA-019-19a Dart dice a la vista con el ajuste encendido guarda la hora y arranca el latido`() {
        tracker.setVisible(true)
        assertEquals(start, store.state.foregroundAt)
        assertTrue(timer.scheduled)
        assertEquals(Duration.ofMinutes(5), timer.delay)
    }

    @Test
    fun `P-019-5 el latido renueva la hora cada 5 minutos mientras siga a la vista`() {
        tracker.setVisible(true)
        repeat(36) { // tres horas
            clock.now = clock.now.plus(Duration.ofMinutes(5))
            assertTrue(timer.scheduled)
            timer.fire()
            assertEquals(clock.now, store.state.foregroundAt)
        }
        assertTrue(timer.scheduled)
    }

    @Test
    fun `CA-019-19a con el ajuste apagado no se escribe nada ni hay latido`() {
        turnOff()
        tracker.setVisible(true)
        assertTrue(store.written.isEmpty())
        assertFalse(timer.scheduled)
    }

    @Test
    fun `P-019-5 si se apaga con el latido en marcha, el siguiente latido no escribe y se para`() {
        tracker.setVisible(true)
        store.written.clear()
        turnOff()
        timer.fire()
        assertTrue(store.written.isEmpty())
        assertFalse(timer.scheduled)
    }

    @Test
    fun `CA-019-19a Dart dice oculta limpia la hora y para el latido`() {
        tracker.setVisible(true)
        tracker.setVisible(false)
        assertNull(store.state.foregroundAt)
        assertFalse(timer.scheduled)
    }

    @Test
    fun `CA-019-19a oculta sin hora guardada no escribe`() {
        tracker.setVisible(false)
        assertTrue(store.written.isEmpty())
    }

    @Test
    fun `CA-019-19a onStop limpia la hora y para el latido aunque Dart no lo haya dicho`() {
        tracker.setVisible(true)
        tracker.onStop()
        assertNull(store.state.foregroundAt)
        assertFalse(timer.scheduled)
    }

    @Test
    fun `CA-019-19a onResume restaura la hora solo si Dart la habia marcado visible`() {
        tracker.setVisible(true)
        tracker.onStop()
        clock.now = clock.now.plus(Duration.ofMinutes(30))
        tracker.onResume()
        assertEquals(clock.now, store.state.foregroundAt)
        assertTrue(timer.scheduled)
    }

    @Test
    fun `CA-019-19a onResume sin que Dart la marcara no escribe nada`() {
        tracker.onResume()
        assertTrue(store.written.isEmpty())
        assertFalse(timer.scheduled)
    }

    @Test
    fun `CA-019-19a onResume sin marca de Dart no toca ni una hora que ya hubiera`() {
        store.state = store.state.copy(foregroundAt = start.minusSeconds(60))
        tracker.onResume()
        assertTrue(store.written.isEmpty())
        assertFalse(timer.scheduled)
    }

    @Test
    fun `CA-019-19a onResume tras decir Dart oculta tampoco la restaura`() {
        tracker.setVisible(true)
        tracker.setVisible(false)
        tracker.onStop()
        store.written.clear()
        tracker.onResume()
        assertTrue(store.written.isEmpty())
        assertFalse(timer.scheduled)
    }

    @Test
    fun `CA-019-19a Dart dice visible estando parada la actividad no marca ni arranca el latido`() {
        tracker.onStop()
        tracker.setVisible(true)
        assertNull(store.state.foregroundAt)
        assertFalse(timer.scheduled)
        tracker.onResume()
        assertEquals(start, store.state.foregroundAt)
        assertTrue(timer.scheduled)
    }

    @Test
    fun `CA-019-19a un latido pendiente tras onStop ya no escribe`() {
        tracker.setVisible(true)
        tracker.onStop()
        store.written.clear()
        timer.fire()
        assertTrue(store.written.isEmpty())
    }

    @Test
    fun `plan 3_5 configure encendido con la app a la vista arranca el latido y marca la hora`() {
        turnOff()
        tracker.setVisible(true)
        assertFalse(timer.scheduled)
        store.state = store.state.copy(config = NotificationConfig(true, 2, LanguageChoice.ES))
        tracker.onConfigured()
        assertEquals(start, store.state.foregroundAt)
        assertTrue(timer.scheduled)
    }

    @Test
    fun `plan 3_5 configure apagado para el latido`() {
        tracker.setVisible(true)
        turnOff()
        tracker.onConfigured()
        assertFalse(timer.scheduled)
    }

    @Test
    fun `plan 3_5 configure con la app oculta no marca la app a la vista`() {
        tracker.onConfigured()
        assertNull(store.state.foregroundAt)
        assertFalse(timer.scheduled)
    }

    @Test
    fun `dispose para el latido`() {
        tracker.setVisible(true)
        tracker.dispose()
        assertFalse(timer.scheduled)
        assertNotNull(store.state.foregroundAt) // no borra: lo limpia onStop
    }

    @Test
    fun `CA-019-23 solo escribe la hora de a la vista y nada mas`() {
        tracker.setVisible(true)
        tracker.onStop()
        assertTrue(store.written.all { it.startsWith("foregroundAt:") })
    }
}
