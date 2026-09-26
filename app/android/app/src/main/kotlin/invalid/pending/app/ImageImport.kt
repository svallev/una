package invalid.pending.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentResolver
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ext.SdkExtensions
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Canal `una/images` (spec 007): cámara y selector del sistema **sin permisos**,
 * copia acotada y limpieza de la imagen. Todo lo que escribe va a
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
        private const val BUFFER = 64 * 1024
        private val ID = Regex("^[A-Za-z0-9_-]{1,64}$")
        private val PICKER_MIME = arrayOf(
            "image/jpeg", "image/png", "image/webp", "image/gif", "image/heic", "image/heif",
        )
    }

    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newFixedThreadPool(2)
    private val cancelled = ConcurrentHashMap<String, AtomicBoolean>()

    /** Llamada de Dart que espera el resultado de la cámara o del selector. */
    private var pending: MethodChannel.Result? = null
    private var pendingCameraId: String? = null

    private val importRoot: File get() = File(activity.cacheDir, "import")
    private val authority: String get() = "${activity.packageName}.imports"

    private val debuggable: Boolean
        get() = activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(mapOf("heic" to (Build.VERSION.SDK_INT >= 28)))
            "pick" -> pick(call.argument<String>("origin")!!, id(call), result)
            "copy" -> copy(call.argument<String>("token")!!, id(call), maxBytes(call), result)
            "sanitize" -> sanitize(call, result)
            "cancel" -> cancel(id(call), result)
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
        pending = null
        pendingCameraId = null
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
                result.success(mapOf("token" to uri.toString()))
            } else {
                result.success(null)
            }
        }
        return true
    }

    // --- Copiar ---------------------------------------------------------------

    private fun copy(token: String, id: String, maxBytes: Long, result: MethodChannel.Result) {
        val flag = AtomicBoolean(false)
        cancelled[id] = flag
        background(result, id) {
            if (token.startsWith("camera:")) {
                val cameraId = token.removePrefix("camera:")
                require(ID.matches(cameraId)) { "id" }
                val file = File(importRoot, "$cameraId.camera")
                try {
                    FileInputStream(file).use { boundedCopy(it, id, maxBytes, flag) }
                } finally {
                    file.delete() // Ninguna otra copia de lo que escribió la cámara.
                }
            } else {
                val uri = Uri.parse(token)
                // Solo contenido de otras apps; nunca archivos ni nuestro propio
                // FileProvider (datos de la app, T-3).
                if (uri.scheme != ContentResolver.SCHEME_CONTENT || uri.authority == authority) {
                    throw ImportException("unreadable")
                }
                val input = activity.contentResolver.openInputStream(uri)
                    ?: throw ImportException("unreadable")
                input.use { boundedCopy(it, id, maxBytes, flag) }
            }
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
                File(path).canonicalPath.startsWith(File(activity.cacheDir, "fixtures").canonicalPath)
            if (!allowed) throw ImportException("unreadable")
            FileInputStream(path).use { boundedCopy(it, id, maxBytes(call), flag) }
        }
    }

    /** Copia contando bytes y aborta al pasar de [maxBytes] (CA-007-14). */
    private fun boundedCopy(input: InputStream, id: String, maxBytes: Long, flag: AtomicBoolean): Map<String, Any> {
        val dir = File(importRoot, id)
        dir.mkdirs()
        val target = File(dir, "source")
        val head = ByteArray(HEAD_BYTES)
        var headLen = 0
        var total = 0L
        try {
            target.outputStream().use { out ->
                val buf = ByteArray(BUFFER)
                while (true) {
                    if (flag.get()) throw ImportException("cancelled")
                    val n = input.read(buf)
                    if (n < 0) break
                    total += n
                    if (total > maxBytes) throw ImportException("tooLarge")
                    if (headLen < HEAD_BYTES) {
                        val take = minOf(n, HEAD_BYTES - headLen)
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
        executor.execute {
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
            val outcome: Result<Any?> = try {
                Result.success(work())
            } catch (e: ImportException) {
                Result.failure(e)
            } catch (e: OutOfMemoryError) {
                Result.failure(ImportException("unreadable"))
            } catch (e: Exception) {
                Result.failure(ImportException("unreadable"))
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
    }
}
