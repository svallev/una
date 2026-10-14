package invalid.pending.app

/**
 * El tope de un grupo de fotos (spec 016, CA-016-24; probado en la JVM por CA-020-21). Kotlin puro:
 * sin `android.*`, para comprobar con un contador de accesos que el trabajo no crece con lo que
 * devuelva el selector (T-3 y T-16 del modelo de amenazas).
 */
object PickedItems {
    /**
     * Los primeros [max] elementos de un selector que dice tener [count], en su orden, con [at]
     * (índice → elemento, o `null` si no tiene dirección, que se salta). **Solo se llama a [at]
     * para los índices `0 until min(count, max)`**: los demás elementos ni se abren, ni se
     * consultan, ni se copian, lleguen miles o `Int.MAX_VALUE`. Un [count] o un [max] no positivo
     * no toca nada.
     */
    fun <T : Any> firstItems(count: Int, max: Int, at: (Int) -> T?): List<T> {
        val limit = minOf(count, max)
        if (limit <= 0) return emptyList()
        val items = ArrayList<T>(limit)
        for (i in 0 until limit) at(i)?.let { items.add(it) }
        return items
    }
}
