package invalid.pending.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** CA-020-21 (016-c, CA-016-24): el tope de fotos se aplica antes de tocar ningún elemento. */
class PickedItemsTest {
    /** Un «selector» que cuenta cuántos elementos se le piden. */
    private class Counting(private val uris: Int) {
        val touched = mutableListOf<Int>()

        fun at(index: Int): String? {
            touched.add(index)
            return "content://x/$index"
        }

        val count: Int get() = uris
    }

    @Test
    fun `CA-020-21 5000 elementos devueltos por el selector solo tocan los 10 primeros`() {
        val picker = Counting(5000)
        val items = PickedItems.firstItems(picker.count, 10) { picker.at(it) }
        assertEquals(10, picker.touched.size)
        assertEquals((0 until 10).toList(), picker.touched)
        assertEquals((0 until 10).map { "content://x/$it" }, items)
    }

    @Test
    fun `CA-020-21 el tope pedido manda aunque haya muchos mas`() {
        for (max in 1..10) {
            val picker = Counting(5000)
            val items = PickedItems.firstItems(picker.count, max) { picker.at(it) }
            assertEquals("max=$max", max, picker.touched.size)
            assertEquals(max, items.size)
        }
    }

    @Test
    fun `CA-020-21 con menos elementos que el tope solo se piden los que hay`() {
        val picker = Counting(3)
        val items = PickedItems.firstItems(picker.count, 10) { picker.at(it) }
        assertEquals(listOf(0, 1, 2), picker.touched)
        assertEquals(3, items.size)
    }

    @Test
    fun `CA-020-21 sin elementos o con un tope no valido no se toca nada`() {
        for ((count, max) in listOf(0 to 10, -1 to 10, 5000 to 0, 5000 to -3, Int.MAX_VALUE to 0)) {
            val picker = Counting(count)
            val items = PickedItems.firstItems(count, max) { picker.at(it) }
            assertTrue("count=$count max=$max", picker.touched.isEmpty())
            assertTrue(items.isEmpty())
        }
    }

    @Test
    fun `CA-020-21 un entero enorme de elementos no recorre nada de mas`() {
        val picker = Counting(Int.MAX_VALUE)
        PickedItems.firstItems(picker.count, 10) { picker.at(it) }
        assertEquals(10, picker.touched.size)
    }

    @Test
    fun `CA-020-21 los elementos sin direccion se saltan pero siguen contando para el tope`() {
        val touched = mutableListOf<Int>()
        val items =
            PickedItems.firstItems(5000, 10) { i ->
                touched.add(i)
                if (i % 2 == 0) null else "u$i"
            }
        // Se miran 10, no 20 para completar diez validos: el tope es de accesos.
        assertEquals(10, touched.size)
        assertEquals(listOf("u1", "u3", "u5", "u7", "u9"), items)
    }

    @Test
    fun `CA-020-21 el orden es el que devolvio el selector`() {
        val items = PickedItems.firstItems(4, 10) { "u$it" }
        assertEquals(listOf("u0", "u1", "u2", "u3"), items)
    }
}
