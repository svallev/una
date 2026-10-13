package invalid.pending.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** CA-019-21: el idioma de la notificación y cuándo lleva marca para el lector de pantalla. */
class LanguageTest {
    private fun system(vararg tags: String) = Language.resolve(LanguageChoice.SYSTEM, tags.toList())

    @Test
    fun `CA-019-21 como el sistema - es y en`() {
        assertEquals(AppLanguage.ES, system("es-ES"))
        assertEquals(AppLanguage.ES, system("es"))
        assertEquals(AppLanguage.ES, system("es-419"))
        assertEquals(AppLanguage.EN, system("en-GB"))
        assertEquals(AppLanguage.EN, system("en"))
    }

    @Test
    fun `CA-019-21 el catalan abre en español y gallego y euskera en ingles (regla de la 010)`() {
        assertEquals(AppLanguage.ES, system("ca-ES"))
        assertEquals(AppLanguage.ES, system("ca"))
        assertEquals(AppLanguage.EN, system("gl-ES"))
        assertEquals(AppLanguage.EN, system("eu-ES"))
        assertEquals(AppLanguage.EN, system("gl"))
        assertEquals(AppLanguage.EN, system("eu"))
    }

    @Test
    fun `CA-019-21 se usa el primer idioma del sistema que la app admita`() {
        assertEquals(AppLanguage.ES, system("gl-ES", "es-ES"))
        assertEquals(AppLanguage.EN, system("fr-FR", "en-GB", "es"))
        assertEquals(AppLanguage.ES, system("fr", "ca"))
        assertEquals(AppLanguage.ES, system("es-ES", "en-GB"))
        assertEquals(AppLanguage.EN, system("en-GB", "es-ES"))
    }

    @Test
    fun `CA-019-21 sin idioma admitido o sin lista, ingles (tambien de derecha a izquierda)`() {
        assertEquals(AppLanguage.EN, system("fr-FR"))
        assertEquals(AppLanguage.EN, system("ar-SA"))
        assertEquals(AppLanguage.EN, system("he-IL", "fa"))
        assertEquals(AppLanguage.EN, system())
    }

    @Test
    fun `CA-019-21 las etiquetas con guion bajo, mayusculas o espacios se leen igual`() {
        assertEquals(AppLanguage.ES, system("es_ES"))
        assertEquals(AppLanguage.ES, system("ES-es"))
        assertEquals(AppLanguage.ES, system(" es-ES "))
        assertEquals(AppLanguage.ES, system("", "es"))
        assertEquals(AppLanguage.EN, system("esp"))
        assertEquals(AppLanguage.EN, system("e"))
    }

    @Test
    fun `CA-019-21 el idioma elegido en Ajustes manda sobre el del sistema`() {
        assertEquals(AppLanguage.ES, Language.resolve(LanguageChoice.ES, listOf("en-US")))
        assertEquals(AppLanguage.EN, Language.resolve(LanguageChoice.EN, listOf("es-ES")))
        assertEquals(AppLanguage.ES, Language.resolve(LanguageChoice.ES, emptyList()))
        assertEquals(AppLanguage.EN, Language.resolve(LanguageChoice.EN, listOf("ca")))
    }

    @Test
    fun `CA-019-21 el primer idioma del sistema`() {
        assertEquals("es", Language.firstSystemLanguage(listOf("es-ES", "en")))
        assertEquals("ca", Language.firstSystemLanguage(listOf("ca-ES")))
        assertEquals("en", Language.firstSystemLanguage(listOf("EN_gb")))
        assertEquals("gl", Language.firstSystemLanguage(listOf("gl", "es")))
        assertEquals("es", Language.firstSystemLanguage(listOf("  ", "es")))
        assertNull(Language.firstSystemLanguage(emptyList()))
        assertNull(Language.firstSystemLanguage(listOf("", " ")))
    }

    @Test
    fun `CA-019-21 lleva marca cuando el idioma de la app no es el primero del sistema`() {
        assertFalse(Language.needsMark(AppLanguage.ES, listOf("es-ES")))
        assertFalse(Language.needsMark(AppLanguage.EN, listOf("en-GB", "es")))
        assertTrue(Language.needsMark(AppLanguage.ES, listOf("en-US")))
        assertTrue(Language.needsMark(AppLanguage.EN, listOf("es-ES")))
        // El catalan se lee en español, pero la voz del sistema es catalana: se marca.
        assertTrue(Language.needsMark(AppLanguage.ES, listOf("ca-ES")))
        assertTrue(Language.needsMark(AppLanguage.EN, listOf("gl-ES", "en")))
        // Sin idiomas en el sistema no se puede afirmar que coincidan.
        assertTrue(Language.needsMark(AppLanguage.EN, emptyList()))
    }

    @Test
    fun `CA-019-21 la etiqueta BCP-47 del idioma`() {
        assertEquals("es", AppLanguage.ES.tag)
        assertEquals("en", AppLanguage.EN.tag)
    }
}
