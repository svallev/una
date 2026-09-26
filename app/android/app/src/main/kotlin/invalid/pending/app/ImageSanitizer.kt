package invalid.pending.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorSpace
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** Error de importación; [code] coincide con `ImageImportError` de Dart. */
class ImportException(val code: String) : Exception(code)

/** Resultado de limpiar una imagen: dimensiones y bytes de la versión completa. */
data class SanitizedImage(val width: Int, val height: Int, val byteSize: Long)

/**
 * Recodifica una imagen **desde los píxeles** (spec 007, CA-007-07, decisión I-4):
 * `Bitmap.compress` escribe un JPEG sin metadatos, así que no sobrevive ningún
 * byte del original (EXIF, GPS, XMP, miniatura interna, vídeo de las fotos con
 * movimiento ni datos tras el final). Escribe en [outDir]:
 *
 * - `full-<fila>-<col>.jpg`: la versión completa en teselas de ≤ 4096 px
 *   (reducida solo si pasa de [storedMaxPixels], sin límite de lado);
 * - `screen.jpg`: recortada para llenar la pantalla en vertical (I-2);
 * - `thumb.jpg`: cuadrada, de [THUMB] px, recortada.
 */
class ImageSanitizer(
    private val maxPixels: Long,
    private val storedMaxPixels: Long,
    private val screenWidth: Int,
    private val screenHeight: Int,
    private val cancelled: AtomicBoolean,
) {
    companion object {
        const val TILE = 4096
        const val THUMB = 176
        private const val FULL_QUALITY = 90
        private const val SCREEN_QUALITY = 85
        private const val THUMB_QUALITY = 80
    }

    fun sanitize(source: File, outDir: File, isJpeg: Boolean): SanitizedImage {
        var bitmap = decode(source, isJpeg)
        try {
            checkCancelled()
            if (Build.VERSION.SDK_INT >= 34 && bitmap.hasGainmap()) {
                // Ultra HDR: compress escribiría la imagen secundaria.
                bitmap.gainmap = null
            }
            if (bitmap.hasAlpha()) bitmap = flattenOnWhite(bitmap) // CL-007-4
            outDir.mkdirs()
            val byteSize = writeTiles(bitmap, outDir)
            checkCancelled()
            writeScreen(bitmap, File(outDir, "screen.jpg"))
            writeThumb(bitmap, File(outDir, "thumb.jpg"))
            return SanitizedImage(bitmap.width, bitmap.height, byteSize)
        } finally {
            bitmap.recycle()
        }
    }

    private fun checkCancelled() {
        if (cancelled.get()) throw ImportException("cancelled")
    }

    private fun tooMany(w: Int, h: Int) = w <= 0 || h <= 0 || w.toLong() * h > maxPixels

    /** Factor de reducción para quedar en ≤ [storedMaxPixels]. */
    private fun scaleFor(w: Int, h: Int): Double {
        val px = w.toLong() * h
        return if (px <= storedMaxPixels) 1.0 else sqrt(storedMaxPixels.toDouble() / px)
    }

    private fun decode(source: File, isJpeg: Boolean): Bitmap =
        if (Build.VERSION.SDK_INT >= 28) decodeModern(source) else decodeLegacy(source, isJpeg)

    /** Android 9+: la cabecera se lee antes de reservar memoria para los píxeles. */
    private fun decodeModern(source: File): Bitmap {
        try {
            return ImageDecoder.decodeBitmap(ImageDecoder.createSource(source)) { decoder, info, _ ->
                val w = info.size.width
                val h = info.size.height
                if (tooMany(w, h)) throw ImportException("tooManyPixels")
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                decoder.setTargetColorSpace(ColorSpace.get(ColorSpace.Named.SRGB))
                // Una imagen incompleta no se acepta a medias.
                decoder.setOnPartialImageListener { false }
                val f = scaleFor(w, h)
                if (f < 1.0) {
                    decoder.setTargetSize(
                        max(1, floor(w * f).toInt()),
                        max(1, floor(h * f).toInt()),
                    )
                }
            }
        } catch (e: ImportException) {
            throw e
        } catch (e: OutOfMemoryError) {
            throw ImportException("unreadable")
        } catch (e: Exception) {
            throw ImportException("unreadable")
        }
    }

    /** Android 8: sin HEIC; la orientación se aplica a mano con el EXIF del sistema. */
    private fun decodeLegacy(source: File, isJpeg: Boolean): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source.path, bounds)
        val w = bounds.outWidth
        val h = bounds.outHeight
        if (w <= 0 || h <= 0) throw ImportException("unreadable")
        if (tooMany(w, h)) throw ImportException("tooManyPixels")
        var sample = 1
        while ((w.toLong() / sample) * (h.toLong() / sample) > storedMaxPixels) sample *= 2
        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredColorSpace = ColorSpace.get(ColorSpace.Named.SRGB)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = try {
            BitmapFactory.decodeFile(source.path, opts)
        } catch (e: OutOfMemoryError) {
            null
        } ?: throw ImportException("unreadable")
        val orientation = if (isJpeg) {
            try {
                FileInputStream(source).use {
                    ExifInterface(it).getAttributeInt(
                        ExifInterface.TAG_ORIENTATION,
                        ExifInterface.ORIENTATION_NORMAL,
                    )
                }
            } catch (e: Exception) {
                ExifInterface.ORIENTATION_NORMAL
            }
        } else {
            ExifInterface.ORIENTATION_NORMAL
        }
        return orient(decoded, orientation)
    }

    /** Las 8 orientaciones EXIF (CA-007-07). */
    private fun orient(bitmap: Bitmap, orientation: Int): Bitmap {
        val m = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> m.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                m.setRotate(90f); m.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> m.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                m.setRotate(-90f); m.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> m.setRotate(-90f)
            else -> return bitmap
        }
        val out = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
        if (out !== bitmap) bitmap.recycle()
        return out
    }

    private fun flattenOnWhite(bitmap: Bitmap): Bitmap {
        val out = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
        Canvas(out).apply {
            drawColor(Color.WHITE)
            drawBitmap(bitmap, 0f, 0f, null)
        }
        bitmap.recycle()
        return out
    }

    private fun writeJpeg(bitmap: Bitmap, file: File, quality: Int) {
        FileOutputStream(file).use { out ->
            if (!bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)) {
                throw ImportException("unreadable")
            }
            out.fd.sync()
        }
    }

    private fun writeTiles(bitmap: Bitmap, outDir: File): Long {
        val rows = (bitmap.height + TILE - 1) / TILE
        val cols = (bitmap.width + TILE - 1) / TILE
        var bytes = 0L
        for (r in 0 until rows) {
            for (c in 0 until cols) {
                checkCancelled()
                val file = File(outDir, "full-$r-$c.jpg")
                if (rows == 1 && cols == 1) {
                    writeJpeg(bitmap, file, FULL_QUALITY)
                } else {
                    val left = c * TILE
                    val top = r * TILE
                    val tile = Bitmap.createBitmap(
                        bitmap, left, top,
                        min(TILE, bitmap.width - left), min(TILE, bitmap.height - top),
                    )
                    try {
                        writeJpeg(tile, file, FULL_QUALITY)
                    } finally {
                        if (tile !== bitmap) tile.recycle()
                    }
                }
                bytes += file.length()
            }
        }
        return bytes
    }

    /** Recorta al centro para llenar [targetW]×[targetH], sin ampliar nunca. */
    private fun cover(bitmap: Bitmap, targetW: Int, targetH: Int): Bitmap {
        val scale = max(targetW.toDouble() / bitmap.width, targetH.toDouble() / bitmap.height)
        val cropW = min(bitmap.width, (targetW / scale).roundToInt().coerceAtLeast(1))
        val cropH = min(bitmap.height, (targetH / scale).roundToInt().coerceAtLeast(1))
        val x = (bitmap.width - cropW) / 2
        val y = (bitmap.height - cropH) / 2
        val m = Matrix()
        val s = min(1.0, scale).toFloat()
        m.setScale(s, s)
        return Bitmap.createBitmap(bitmap, x, y, cropW, cropH, m, true)
    }

    private fun writeScreen(bitmap: Bitmap, file: File) {
        val out = cover(bitmap, screenWidth, screenHeight)
        try {
            writeJpeg(out, file, SCREEN_QUALITY)
        } finally {
            if (out !== bitmap) out.recycle()
        }
    }

    private fun writeThumb(bitmap: Bitmap, file: File) {
        val out = cover(bitmap, THUMB, THUMB)
        try {
            writeJpeg(out, file, THUMB_QUALITY)
        } finally {
            if (out !== bitmap) out.recycle()
        }
    }
}
