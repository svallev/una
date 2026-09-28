package invalid.pending.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentResolver
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ext.SdkExtensions
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.Closeable
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Canal `una/images` (spec 007): cámara y selector del sistema **sin permisos**,
 * copia acotada y limpieza de la imagen. Desde la spec 008, también el selector
 * de PDF (origen `file`) y `encodeJpeg` (la versión de pantalla de una página). Todo lo que escribe va a
 * `cache/import/` (la misma ruta que `FileAttachmentStore` en Dart); nunca a la
 * galería ni al almacenamiento compartido.
 *
 * Nunca registra URIs, rutas, nombres ni metadatos (CL-007-10).
 */
class ImageImport(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "una/images"
        const val REQUEST_CAMERA = 7001
        const val REQUEST_PICK = 7002
        private const val HEAD_BYTES = 64
        /** Cabecera máxima que se devuelve (el PDF busca `%PDF-` en 1024, spec 008). */
        private const val MAX_HEAD_BYTES = 1024
        /** Nombre visible más largo que se lee del proveedor (Dart lo recorta a 120). */
        private const val MAX_NAME = 1024
        private const val BUFFER = 64 * 1024
        private val ID = Regex("^[A-Za-z0-9_-]{1,64}$")
        private val PICKER_MIME = arrayOf(
            "image/jpeg", "image/png", "image/webp", "image/gif", "image/heic", "image/heif",
        )
    }

    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newFixedThreadPool(2)

    /**
     * Cancelar nunca espera en la cola de [executor]: si una copia está
     * bloqueada en `read()` (proveedor en la nube sin red), cerrar su flujo la
     * desbloquea y el borrado va por su propio hilo.
     */
    private val cleaner = Executors.newSingleThreadExecutor()
    private val cancelled = ConcurrentHashMap<String, AtomicBoolean>()
    private val openStreams = ConcurrentHashMap<String, Closeable>()

    /** Llamada de Dart que espera el resultado de la cámara o del selector. */
    private var pending: MethodChannel.Result? = null
    private var pendingCameraId: String? = null
    private var pendingIsFile = false

    private val importRoot: File get() = File(activity.cacheDir, "import")
    private val authority: String get() = "${activity.packageName}.imports"

    private val debuggable: Boolean
        get() = activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(mapOf("heic" to (Build.VERSION.SDK_INT >= 28)))
            "pick" -> pick(call.argument<String>("origin")!!, id(call), result)
            "copy" -> copy(call.argument<String>("token")!!, id(call), maxBytes(call), headBytes(call), result)
            "sanitize" -> sanitize(call, result)
            "cancel" -> cancel(id(call), result)
            "encodeJpeg" -> encodeJpeg(call, result)
            "regenerate" -> regenerate(call, result)
            "debugCopyFile" -> debugCopyFile(call, result)
            else -> result.notImplemented()
        }
    }

    private fun id(call: MethodCall): String {
        val id = call.argument<String>("id")!!
        require(ID.matches(id)) { "id" }
        return id
    }

    private fun maxBytes(call: MethodCall): Long = call.argument<Number>("maxBytes")!!.toLong()

    private fun headBytes(call: MethodCall): Int =
        (call.argument<Number>("headBytes")?.toInt() ?: HEAD_BYTES).coerceIn(1, MAX_HEAD_BYTES)

    // --- Elegir ---------------------------------------------------------------

    private fun pick(origin: String, id: String, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", null, null)
            return
        }
        try {
            if (origin == "camera") {
                importRoot.mkdirs()
                val file = File(importRoot, "$id.camera")
                val uri = FileProvider.getUriForFile(activity, authority, file)
                val flags =
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION
                val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                    putExtra(MediaStore.EXTRA_OUTPUT, uri)
                    clipData = ClipData.newRawUri("", uri)
                    addFlags(flags)
                }
                pending = result
                pendingCameraId = id
                activity.startActivityForResult(intent, REQUEST_CAMERA)
            } else if (origin == "file") {
                // Selector de documentos del sistema, solo PDF (spec 008): sin
                // permisos de almacenamiento (CA-008-01).
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/pdf"
                }
                pending = result
                pendingIsFile = true
                activity.startActivityForResult(intent, REQUEST_PICK)
            } else {
                val intent = if (photoPickerAvailable()) {
                    Intent(MediaStore.ACTION_PICK_IMAGES).setType("image/*")
                } else {
                    Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "image/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, PICKER_MIME)
                    }
                }
                pending = result
                activity.startActivityForResult(intent, REQUEST_PICK)
            }
        } catch (e: ActivityNotFoundException) {
            pending = null
            pendingCameraId = null
            pendingIsFile = false
            File(importRoot, "$id.camera").delete()
            result.error(if (origin == "camera") "noCamera" else "unreadable", null, null)
        }
    }

    private fun photoPickerAvailable(): Boolean =
        Build.VERSION.SDK_INT >= 33 ||
            (Build.VERSION.SDK_INT >= 30 && SdkExtensions.getExtensionVersion(Build.VERSION_CODES.R) >= 2)

    /** Devuelve true si el resultado era nuestro. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CAMERA && requestCode != REQUEST_PICK) return false
        val result = pending
        val cameraId = pendingCameraId
        val isFile = pendingIsFile
        pending = null
        pendingCameraId = null
        pendingIsFile = false
        // Sin llamada pendiente, Android mató la app con la cámara abierta
        // (CL-007-7): se ignora; el barrido borra la foto del siguiente arranque.
        if (result == null) return true
        if (requestCode == REQUEST_CAMERA) {
            val file = File(importRoot, "$cameraId.camera")
            activity.revokeUriPermission(
                FileProvider.getUriForFile(activity, authority, file),
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            if (resultCode == Activity.RESULT_OK && file.length() > 0) {
                result.success(mapOf("token" to "camera:$cameraId"))
            } else {
                file.delete()
                result.success(null)
            }
        } else {
            val uri = data?.data
            if (resultCode == Activity.RESULT_OK && uri != null) {
                // El nombre visible solo se pide para un PDF (CA-008-07); nunca
                // se registra (CL-008-11) y Dart lo sanea.
                val name = if (isFile && isForeignContent(uri)) displayName(uri) else null
                result.success(mapOf("token" to uri.toString(), "name" to name))
            } else {
                result.success(null)
            }
        }
        return true
    }

    /** `OpenableColumns.DISPLAY_NAME` del documento, o null. */
    private fun displayName(uri: Uri): String? = try {
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst() && !c.isNull(0)) c.getString(0)?.take(MAX_NAME) else null }
    } catch (e: Exception) {
        null
    }

    // --- Copiar ---------------------------------------------------------------

    private fun copy(token: String, id: String, maxBytes: Long, headBytes: Int, result: MethodChannel.Result) {
        val flag = AtomicBoolean(false)
        cancelled[id] = flag
        background(result, id) {
            if (token.startsWith("camera:")) {
                val cameraId = token.removePrefix("camera:")
                require(ID.matches(cameraId)) { "id" }
                val file = File(importRoot, "$cameraId.camera")
                try {
                    FileInputStream(file).use { tracked(id, it) { boundedCopy(it, id, maxBytes, headBytes, flag) } }
                } finally {
                    file.delete() // Ninguna otra copia de lo que escribió la cámara.
                }
            } else {
                val uri = Uri.parse(token)
                // Solo contenido de otras apps; nunca archivos ni un proveedor
                // de la propia app (datos de la app, T-3).
                if (!isForeignContent(uri)) throw ImportException("unreadable")
                val input = activity.contentResolver.openInputStream(uri)
                    ?: throw ImportException("unreadable")
                input.use { tracked(id, it) { boundedCopy(it, id, maxBytes, headBytes, flag) } }
            }
        }
    }

    /**
     * ¿`content://` de otra app? Rechaza la autoridad con usuario
     * (`0@<pkg>.imports`, que `ContentResolver` resolvería a nuestro
     * FileProvider) y cualquier proveedor cuyo paquete sea el nuestro.
     */
    private fun isForeignContent(uri: Uri): Boolean {
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return false
        val auth = uri.authority ?: return false
        if (auth.contains('@') || auth == authority) return false
        @Suppress("DEPRECATION")
        val provider = activity.packageManager.resolveContentProvider(auth, 0)
        return provider?.packageName != activity.packageName
    }

    /** Registra el flujo de [id] mientras dura [block], para que cancelar lo cierre. */
    private fun <T> tracked(id: String, stream: Closeable, block: () -> T): T {
        openStreams[id] = stream
        try {
            return block()
        } finally {
            openStreams.remove(id, stream)
        }
    }

    /** Solo en builds de depuración: los tests de integración importan ficheros de prueba. */
    private fun debugCopyFile(call: MethodCall, result: MethodChannel.Result) {
        if (!debuggable) {
            result.notImplemented()
            return
        }
        val id = id(call)
        val path = call.argument<String>("path")!!
        val flag = AtomicBoolean(false)
        cancelled[id] = flag
        background(result, id) {
            val allowed = path == "/dev/zero" || path == "/dev/urandom" ||
                File(path).canonicalPath.startsWith(
                    File(activity.cacheDir, "fixtures").canonicalPath + File.separator,
                )
            if (!allowed) throw ImportException("unreadable")
            FileInputStream(path).use { tracked(id, it) { boundedCopy(it, id, maxBytes(call), headBytes(call), flag) } }
        }
    }

    /** Copia contando bytes y aborta al pasar de [maxBytes] (CA-007-14). */
    private fun boundedCopy(
        input: InputStream,
        id: String,
        maxBytes: Long,
        headBytes: Int,
        flag: AtomicBoolean,
    ): Map<String, Any> {
        val dir = File(importRoot, id)
        dir.mkdirs()
        val target = File(dir, "source")
        val head = ByteArray(headBytes)
        var headLen = 0
        var total = 0L
        try {
            target.outputStream().use { out ->
                val buf = ByteArray(BUFFER)
                while (true) {
                    if (flag.get()) throw ImportException("cancelled")
                    val n = try {
                        input.read(buf)
                    } catch (e: IOException) {
                        // Cerrado por `cancel` mientras esperaba datos.
                        if (flag.get()) throw ImportException("cancelled")
                        throw e
                    }
                    if (n < 0) break
                    total += n
                    if (total > maxBytes) throw ImportException("tooLarge")
                    if (headLen < headBytes) {
                        val take = minOf(n, headBytes - headLen)
                        System.arraycopy(buf, 0, head, headLen, take)
                        headLen += take
                    }
                    out.write(buf, 0, n)
                }
                out.fd.sync()
            }
        } catch (e: ImportException) {
            dir.deleteRecursively()
            throw e
        } catch (e: IOException) {
            dir.deleteRecursively()
            throw ImportException(if (isNoSpace(e)) "noSpace" else "unreadable")
        }
        if (total == 0L) {
            dir.deleteRecursively()
            throw ImportException("unreadable")
        }
        return mapOf("byteSize" to total, "head" to head.copyOf(headLen))
    }

    // --- Limpiar --------------------------------------------------------------

    private fun sanitize(call: MethodCall, result: MethodChannel.Result) {
        val id = id(call)
        val flag = cancelled.getOrPut(id) { AtomicBoolean(false) }
        background(result, id, last = true) {
            val dir = File(importRoot, id)
            val source = File(dir, "source")
            if (!source.exists()) throw ImportException("unreadable")
            val (w, h) = screenSize()
            val sanitizer = ImageSanitizer(
                maxPixels = call.argument<Number>("maxPixels")!!.toLong(),
                storedMaxPixels = call.argument<Number>("storedMaxPixels")!!.toLong(),
                screenWidth = w,
                screenHeight = h,
                cancelled = flag,
            )
            try {
                val out = sanitizer.sanitize(source, dir, call.argument<String>("type") == "jpeg")
                mapOf("width" to out.width, "height" to out.height, "byteSize" to out.byteSize)
            } catch (e: IOException) {
                throw ImportException(if (isNoSpace(e)) "noSpace" else "unreadable")
            } finally {
                source.delete() // No se conserva ningún byte del original.
            }
        }
    }

    /**
     * Rehace la versión de pantalla y la miniatura de un adjunto **guardado**
     * (`files/attachments/<id>/`) desde sus teselas (CA-007-19). No toca las
     * teselas ni la preparación.
     */
    private fun regenerate(call: MethodCall, result: MethodChannel.Result) {
        val id = id(call)
        val width = call.argument<Number>("width")!!.toInt()
        val height = call.argument<Number>("height")!!.toInt()
        executor.execute {
            val outcome: Result<Any?> = try {
                val dir = File(File(activity.filesDir, "attachments"), id)
                if (!dir.isDirectory) throw ImportException("unreadable")
                val (w, h) = screenSize()
                ImageSanitizer(
                    maxPixels = Long.MAX_VALUE,
                    storedMaxPixels = Long.MAX_VALUE,
                    screenWidth = w,
                    screenHeight = h,
                    cancelled = AtomicBoolean(false),
                ).regenerateDerived(dir, width, height)
                Result.success(null)
            } catch (e: IOException) {
                Result.failure(ImportException(if (isNoSpace(e)) "noSpace" else "unreadable"))
            } catch (e: OutOfMemoryError) {
                Result.failure(ImportException("unreadable"))
            } catch (e: Exception) {
                Result.failure(e as? ImportException ?: ImportException("unreadable"))
            }
            main.post {
                outcome.fold(
                    { result.success(null) },
                    { result.error((it as ImportException).code, null, null) },
                )
            }
        }
    }

    /**
     * Escribe `screen.jpg` desde píxeles RGBA o BGRA (spec 008: la página de un
     * PDF, dibujada en Dart por pdfrx). En la preparación (`cache/import/<id>/`)
     * o en el adjunto guardado (`files/attachments/<id>/`, al cambiar la última
     * posición, CA-008-08). Primero a un temporal y luego rename: nunca a medias.
     * Si el adjunto guardado ya no existe (se completó mientras tanto), nada.
     */
    private fun encodeJpeg(call: MethodCall, result: MethodChannel.Result) {
        val id = id(call)
        val stored = call.argument<String>("target") == "stored"
        val width = call.argument<Number>("width")!!.toInt()
        val height = call.argument<Number>("height")!!.toInt()
        val bgra = call.argument<Boolean>("bgra") == true
        val pixels = call.argument<ByteArray>("pixels")!!
        executor.execute {
            val outcome: Result<Any?> = try {
                require(width in 1..8192 && height in 1..16384) { "size" }
                require(pixels.size.toLong() == width.toLong() * height * 4) { "pixels" }
                val dir = if (stored) File(File(activity.filesDir, "attachments"), id) else File(importRoot, id)
                if (!dir.isDirectory) {
                    Result.success(null)
                } else {
                    if (bgra) {
                        var i = 0
                        while (i < pixels.size) {
                            val b = pixels[i]
                            pixels[i] = pixels[i + 2]
                            pixels[i + 2] = b
                            i += 4
                        }
                    }
                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    try {
                        bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(pixels))
                        val tmp = File(dir, "screen.tmp")
                        FileOutputStream(tmp).use { out ->
                            if (!bitmap.compress(Bitmap.CompressFormat.JPEG, ImageSanitizer.SCREEN_QUALITY, out)) {
                                throw ImportException("unreadable")
                            }
                            out.fd.sync()
                        }
                        if (!tmp.renameTo(File(dir, "screen.jpg"))) {
                            tmp.delete()
                            throw ImportException("unreadable")
                        }
                    } finally {
                        bitmap.recycle()
                    }
                    Result.success(null)
                }
            } catch (e: IOException) {
                Result.failure(ImportException(if (isNoSpace(e)) "noSpace" else "unreadable"))
            } catch (e: OutOfMemoryError) {
                Result.failure(ImportException("unreadable"))
            } catch (e: Exception) {
                Result.failure(e as? ImportException ?: ImportException("unreadable"))
            }
            main.post {
                outcome.fold(
                    { result.success(null) },
                    { result.error((it as ImportException).code, null, null) },
                )
            }
        }
    }

    /** Tamaño físico de la pantalla en vertical (ancho < alto). */
    private fun screenSize(): Pair<Int, Int> {
        val w: Int
        val h: Int
        if (Build.VERSION.SDK_INT >= 30) {
            val b = activity.windowManager.maximumWindowMetrics.bounds
            w = b.width(); h = b.height()
        } else {
            val m = android.util.DisplayMetrics()
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay.getRealMetrics(m)
            w = m.widthPixels; h = m.heightPixels
        }
        return Pair(minOf(w, h), maxOf(w, h))
    }

    private fun cancel(id: String, result: MethodChannel.Result) {
        cancelled[id]?.set(true)
        // Desbloquea una copia parada en `read()`.
        openStreams.remove(id)?.let { runCatching { it.close() } }
        cleaner.execute {
            File(importRoot, id).deleteRecursively()
            File(importRoot, "$id.camera").delete()
            main.post { result.success(null) }
        }
    }

    // --- Utilidades -----------------------------------------------------------

    private fun isNoSpace(e: IOException): Boolean =
        e.message?.contains("ENOSPC") == true || e.message?.contains("No space") == true

    /** Ejecuta [work] fuera del hilo principal (no bloquea la interfaz). */
    private fun background(
        result: MethodChannel.Result,
        id: String,
        last: Boolean = false,
        work: () -> Any?,
    ) {
        executor.execute {
            var outcome: Result<Any?> = try {
                Result.success(work())
            } catch (e: ImportException) {
                Result.failure(e)
            } catch (e: OutOfMemoryError) {
                Result.failure(ImportException("unreadable"))
            } catch (e: Exception) {
                Result.failure(ImportException("unreadable"))
            }
            if (outcome.isSuccess && cancelled[id]?.get() == true) {
                // Cancelada mientras terminaba (quizá tras el borrado de
                // `cancel`, que no la esperaba): se descarta lo escrito.
                outcome = Result.failure(ImportException("cancelled"))
            }
            if (outcome.isFailure) {
                // Error o cancelación: no queda nada de esta importación.
                File(importRoot, id).deleteRecursively()
            }
            if (outcome.isFailure || last) cancelled.remove(id)
            main.post {
                outcome.fold(
                    { result.success(it) },
                    { result.error((it as ImportException).code, null, null) },
                )
            }
        }
    }

    fun dispose() {
        executor.shutdownNow()
        cleaner.shutdown()
    }
}
