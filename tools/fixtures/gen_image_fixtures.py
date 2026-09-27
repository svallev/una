#!/usr/bin/env python3
"""Genera los ficheros de prueba de la importación de imágenes (spec 007, T-007-03).

    python3 tools/fixtures/gen_image_fixtures.py

Necesita Pillow (con WebP y AVIF) y `sips` de macOS (para el HEIC). Escribe:
  - tools/fixtures/out/<nombre>        los ficheros, para inspeccionarlos (no se versionan);
  - app/integration_test/fixtures/image_fixtures.g.dart   los mismos en base64, para
    que el test de integración los lleve dentro sin empaquetarlos en la app.

Cada fichero lleva **marcadores** (SECRET-…) en todos los sitios donde pueden esconderse
datos: EXIF, GPS, XMP, comentarios, bloques de texto de PNG, miniatura interna y datos
tras el final de la imagen. El test comprueba que ninguno sobrevive (CA-007-07).
"""
import base64
import io
import os
import struct
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageOps, PngImagePlugin

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'tools', 'fixtures', 'out')
DART = os.path.join(ROOT, 'app', 'integration_test', 'fixtures', 'image_fixtures.g.dart')

# Marcadores que no deben aparecer en ninguna versión guardada.
MARKERS = [
    b'SECRET-MAKE', b'SECRET-MODEL', b'SECRET-XMP', b'SECRET-COMMENT', b'SECRET-PNG-TEXT',
    b'SECRET-TRAILER', b'SECRET-WEBP', b'Exif', b'http://ns.adobe.com/xap', b'tEXt', b'ftypmp4',
]


def quadrants(w, h):
    """Imagen con el cuadrante superior izquierdo rojo, para comprobar la orientación."""
    im = Image.new('RGB', (w, h), (0, 0, 255))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w // 2 - 1, h // 2 - 1], fill=(255, 0, 0))
    d.rectangle([w // 2, h // 2, w - 1, h - 1], fill=(0, 255, 0))
    return im


def tiff_exif(orientation, thumbnail_jpeg=None, gps=True):
    """EXIF (TIFF little-endian) con Make, Model, Orientation, GPS y, opcional, miniatura (IFD1)."""
    entries0 = []  # (tag, type, count, value_bytes)
    make = b'SECRET-MAKE\x00'
    model = b'SECRET-MODEL\x00'
    entries0.append((0x010F, 2, len(make), make))
    entries0.append((0x0110, 2, len(model), model))
    entries0.append((0x0112, 3, 1, struct.pack('<HH', orientation, 0)))
    gps_ifd = None
    if gps:
        # Madrid: 40° 25' 0" N, 3° 42' 0" W
        rat = lambda a, b: struct.pack('<II', a, b)
        lat = rat(40, 1) + rat(25, 1) + rat(0, 1)
        lon = rat(3, 1) + rat(42, 1) + rat(0, 1)
        gps_ifd = [
            (0x0001, 2, 2, b'N\x00\x00\x00'),
            (0x0002, 5, 3, lat),
            (0x0003, 2, 2, b'W\x00\x00\x00'),
            (0x0004, 5, 3, lon),
        ]
        entries0.append((0x8825, 4, 1, b'\x00\x00\x00\x00'))  # puntero, se rellena

    out = bytearray(b'II*\x00' + struct.pack('<I', 8))

    def write_ifd(entries, next_ifd_placeholder=True):
        start = len(out)
        n = len(entries)
        data_off = start + 2 + n * 12 + 4
        body = bytearray(struct.pack('<H', n))
        extra = bytearray()
        offsets = {}
        for tag, typ, count, val in entries:
            if len(val) <= 4:
                body += struct.pack('<HHI', tag, typ, count) + val.ljust(4, b'\x00')
            else:
                off = data_off + len(extra)
                offsets[tag] = off
                body += struct.pack('<HHII', tag, typ, count, off)
                extra += val
                if len(extra) % 2:
                    extra += b'\x00'
        body += b'\x00\x00\x00\x00'
        out.extend(body)
        out.extend(extra)
        return start

    ifd0 = write_ifd(entries0)
    n0 = len(entries0)
    next_ptr_pos = ifd0 + 2 + n0 * 12
    if gps_ifd:
        gps_off = len(out)
        write_ifd(gps_ifd)
        idx = [e[0] for e in entries0].index(0x8825)
        struct.pack_into('<I', out, ifd0 + 2 + idx * 12 + 8, gps_off)
    if thumbnail_jpeg:
        ifd1 = len(out)
        struct.pack_into('<I', out, next_ptr_pos, ifd1)
        entries1 = [(0x0201, 4, 1, b'\x00\x00\x00\x00'), (0x0202, 4, 1, struct.pack('<I', len(thumbnail_jpeg)))]
        write_ifd(entries1)
        thumb_off = len(out)
        struct.pack_into('<I', out, ifd1 + 2 + 8, thumb_off)
        out.extend(thumbnail_jpeg)
    return b'Exif\x00\x00' + bytes(out)


def jpeg_with_segments(im, exif, xmp=True, comment=True, trailer=None, quality=90):
    buf = io.BytesIO()
    im.save(buf, 'JPEG', quality=quality)
    raw = buf.getvalue()
    assert raw[:2] == b'\xff\xd8'
    segs = b''
    if exif:
        segs += b'\xff\xe1' + struct.pack('>H', len(exif) + 2) + exif
    if xmp:
        x = (b'http://ns.adobe.com/xap/1.0/\x00<x:xmpmeta><rdf:Description exif:GPSLatitude="40,25N" '
             b'note="SECRET-XMP"/></x:xmpmeta>')
        segs += b'\xff\xe1' + struct.pack('>H', len(x) + 2) + x
    if comment:
        c = b'SECRET-COMMENT'
        segs += b'\xff\xfe' + struct.pack('>H', len(c) + 2) + c
    data = raw[:2] + segs + raw[2:]
    if trailer:
        data += trailer
    return data


def png_bytes(im, text=True, exif=None):
    info = PngImagePlugin.PngInfo()
    if text:
        info.add_text('Comment', 'SECRET-PNG-TEXT')
    buf = io.BytesIO()
    kw = {'pnginfo': info, 'optimize': True}
    if exif:
        kw['exif'] = exif
    im.save(buf, 'PNG', **kw)
    return buf.getvalue()


def solid_png(w, h, color=(240, 240, 240)):
    im = Image.new('RGB', (w, h), color)
    d = ImageDraw.Draw(im)
    for y in range(0, h, max(1, h // 20)):
        d.line([(0, y), (w, y)], fill=(17, 17, 17), width=3)
    buf = io.BytesIO()
    im.save(buf, 'PNG', optimize=True)
    return buf.getvalue()


def png_chunk(typ, data):
    import zlib
    return struct.pack('>I', len(data)) + typ + data + struct.pack('>I', zlib.crc32(typ + data) & 0xffffffff)


def fake_dims_png(w, h):
    """PNG cuya cabecera dice w×h pero cuyos datos son de una sola fila (o nada)."""
    import zlib
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)
    idat = zlib.compress(b'\x00' + b'\x80' * 3 * min(w, 64))
    return b'\x89PNG\r\n\x1a\n' + png_chunk(b'IHDR', ihdr) + png_chunk(b'IDAT', idat) + png_chunk(b'IEND', b'')


def orientation_raw(orientation, w=300, h=200):
    """Píxeles crudos que, con esa orientación EXIF, se ven como `quadrants(w, h)`."""
    shown = quadrants(w, h)
    inverse = {
        1: None, 2: Image.Transpose.FLIP_LEFT_RIGHT, 3: Image.Transpose.ROTATE_180,
        4: Image.Transpose.FLIP_TOP_BOTTOM, 5: Image.Transpose.TRANSPOSE,
        6: Image.Transpose.ROTATE_90, 7: Image.Transpose.TRANSVERSE, 8: Image.Transpose.ROTATE_270,
    }[orientation]
    return shown if inverse is None else shown.transpose(inverse)


def main():
    os.makedirs(OUT, exist_ok=True)
    files = {}

    # Foto de 12 MP con todo tipo de metadatos, miniatura interna y orientación 6.
    thumb = io.BytesIO()
    Image.new('RGB', (160, 120), (255, 0, 255)).save(thumb, 'JPEG', quality=80)
    big = orientation_raw(6, 4000, 3000)
    files['photo_gps.jpg'] = jpeg_with_segments(big, tiff_exif(6, thumb.getvalue()), quality=85)

    # Las 8 orientaciones.
    for o in range(1, 9):
        files[f'orientation_{o}.jpg'] = jpeg_with_segments(orientation_raw(o), tiff_exif(o), xmp=False, comment=False)
        check = ImageOps.exif_transpose(Image.open(io.BytesIO(files[f'orientation_{o}.jpg'])))
        assert check.size == (300, 200) and check.getpixel((10, 10))[0] > 200, o

    # Datos tras el final (como el vídeo de una "foto con movimiento").
    files['trailing.jpg'] = jpeg_with_segments(
        quadrants(400, 300), tiff_exif(1), trailer=b'\x00\x00\x00\x18ftypmp42SECRET-TRAILER' + os.urandom(2048))

    # PNG con transparencia, bloque de texto y EXIF.
    t = Image.new('RGBA', (300, 200), (0, 0, 0, 0))
    ImageDraw.Draw(t).rectangle([0, 0, 149, 99], fill=(255, 0, 0, 255))
    files['transparent.png'] = png_bytes(t, exif=tiff_exif(1)[6:])

    # WebP con EXIF.
    buf = io.BytesIO()
    quadrants(300, 200).save(buf, 'WEBP', exif=tiff_exif(1)[6:].replace(b'SECRET-MAKE', b'SECRET-WEBP'))
    files['exif.webp'] = buf.getvalue()

    # GIF de 5 000 fotogramas.
    frames = [Image.new('RGB', (16, 16), (i % 256, (i // 256) * 12 % 256, 0)) for i in range(5000)]
    buf = io.BytesIO()
    frames[0].save(buf, 'GIF', save_all=True, append_images=frames[1:], duration=10, loop=0)
    files['frames5000.gif'] = buf.getvalue()

    # HEIC (con `sips`) y HEIC corrupto.
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, 'in.jpg')
        dst = os.path.join(tmp, 'out.heic')
        with open(src, 'wb') as f:
            f.write(jpeg_with_segments(orientation_raw(6, 800, 600), tiff_exif(6), xmp=False, comment=False))
        subprocess.run(['sips', '-s', 'format', 'heic', src, '--out', dst], check=True, capture_output=True)
        heic = open(dst, 'rb').read()
    assert heic[4:12] in (b'ftypheic', b'ftypmif1', b'ftypheix'), heic[4:12]
    files['photo.heic'] = heic
    files['corrupt.heic'] = heic[: len(heic) // 3] + os.urandom(512)

    # Resolución: 50 MP (se reduce a 24), 63,8 MP (se acepta), 65 MP y cabecera gigante (se rechazan).
    files['px50.png'] = solid_png(8660, 5774)
    files['px64.png'] = solid_png(8000, 7990)  # "bomba": 64 MP en ~200 KB
    files['px65.png'] = solid_png(8100, 8025)
    files['fake_dims_huge.png'] = fake_dims_png(60000, 60000)
    files['fake_dims_small.png'] = fake_dims_png(4000, 4000)

    # Captura larga (CL-007-2).
    files['tall_1080x20000.png'] = solid_png(1080, 20000, (255, 255, 255))

    # Truncado, SVG disfrazado y AVIF.
    files['truncated.jpg'] = files['orientation_1.jpg'][:600]
    files['svg_as.png'] = b'<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"><rect width="10" height="10"/></svg>'
    buf = io.BytesIO()
    quadrants(64, 64).save(buf, 'AVIF')
    files['image.avif'] = buf.getvalue()
    files['html_as.jpg'] = b'<!doctype html><script>alert(1)</script>'

    total = 0
    for name, data in files.items():
        with open(os.path.join(OUT, name), 'wb') as f:
            f.write(data)
        total += len(data)

    os.makedirs(os.path.dirname(DART), exist_ok=True)
    with open(DART, 'w') as f:
        f.write('// GENERADO por tools/fixtures/gen_image_fixtures.py. No editar a mano.\n')
        f.write('// Ficheros de prueba de la importación de imágenes (spec 007, T-007-03).\n\n')
        f.write('/// Marcadores que no deben sobrevivir en ninguna versión guardada (CA-007-07).\n')
        f.write('const List<String> imageFixtureMarkers = [\n')
        for m in MARKERS:
            f.write(f"  '{m.decode()}',\n")
        f.write('];\n\n')
        f.write('/// Nombre → contenido en base64.\n')
        f.write('const Map<String, String> imageFixtures = {\n')
        for name, data in files.items():
            f.write(f"  '{name}':\n      '{base64.b64encode(data).decode()}',\n")
        f.write('};\n')
    print(f'{len(files)} ficheros, {total / 1e6:.2f} MB → {os.path.relpath(DART, ROOT)}')


if __name__ == '__main__':
    sys.exit(main())
