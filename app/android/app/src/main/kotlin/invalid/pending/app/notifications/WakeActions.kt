package invalid.pending.app.notifications

/**
 * La lista blanca de acciones que despiertan al receptor (plan §3.2, CA-019-13 y 25): las seis
 * difusiones **protegidas del sistema** del manifiesto y la acción propia de la alarma, que solo
 * llega por un `PendingIntent` explícito (nunca por un `<intent-filter>`). Cualquier otra se
 * ignora sin evaluar nada. Núcleo puro: sin `android.*`, para probarlo en la JVM.
 */
object WakeActions {
    /** Solo la dispara nuestro `PendingIntent`; el manifiesto no la declara en ningún filtro. */
    const val ALARM = "invalid.pending.app.action.NOTIFICATION_ALARM"

    const val LOCKED_BOOT_COMPLETED = "android.intent.action.LOCKED_BOOT_COMPLETED"
    const val BOOT_COMPLETED = "android.intent.action.BOOT_COMPLETED"
    const val TIME_SET = "android.intent.action.TIME_SET"
    const val TIMEZONE_CHANGED = "android.intent.action.TIMEZONE_CHANGED"
    const val LOCALE_CHANGED = "android.intent.action.LOCALE_CHANGED"
    const val MY_PACKAGE_REPLACED = "android.intent.action.MY_PACKAGE_REPLACED"

    /** Las seis que declara el `<intent-filter>` del manifiesto. */
    val SYSTEM_BROADCASTS: List<String> =
        listOf(LOCKED_BOOT_COMPLETED, BOOT_COMPLETED, TIME_SET, TIMEZONE_CHANGED, LOCALE_CHANGED, MY_PACKAGE_REPLACED)

    /** El motivo del despertar, o `null` si la acción no está en la lista blanca (comparación exacta). */
    fun reasonFor(action: String?): WakeReason? =
        when (action) {
            ALARM -> WakeReason.ALARM
            LOCKED_BOOT_COMPLETED -> WakeReason.LOCKED_BOOT_COMPLETED
            BOOT_COMPLETED -> WakeReason.BOOT_COMPLETED
            TIME_SET -> WakeReason.TIME_SET
            TIMEZONE_CHANGED -> WakeReason.TIMEZONE_CHANGED
            LOCALE_CHANGED -> WakeReason.LOCALE_CHANGED
            MY_PACKAGE_REPLACED -> WakeReason.PACKAGE_REPLACED
            else -> null
        }
}
