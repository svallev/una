// Ayudas de los tests de la ficha (spec 023). No es un test: no acaba en `.test.mjs`.
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { deflateSync } from "node:zlib";
import { REPO_ROOT } from "../../../landing/build.mjs";
import { storePaths } from "../check.mjs";

/** Lo que la comprobación lee del repositorio, con la misma disposición de carpetas. */
const FILES = [
  "app/identity.yaml",
  "docs/legal/privacy-policy.md",
  "tools/check-android-permissions.sh",
  "store/google-play/data-safety.md",
  "store/google-play/icon-512.png",
];

/** Un repositorio de mentira en una carpeta temporal con copias de lo que los tests modifican. */
export function world() {
  const dir = mkdtempSync(join(tmpdir(), "store-test-"));
  for (const f of FILES) {
    mkdirSync(dirname(join(dir, f)), { recursive: true });
    cpSync(join(REPO_ROOT, f), join(dir, f));
  }
  cpSync(join(REPO_ROOT, "store/google-play/listing"), join(dir, "store/google-play/listing"), { recursive: true });
  return {
    dir,
    paths: storePaths(dir),
    cleanup: () => rmSync(dir, { recursive: true, force: true }),
  };
}

/** Copia de [base] (para que cada caso trabaje en la suya). */
export function cloneWorld(base) {
  const dir = mkdtempSync(join(tmpdir(), "store-test-"));
  cpSync(base.dir, dir, { recursive: true });
  return { dir, paths: storePaths(dir), cleanup: () => rmSync(dir, { recursive: true, force: true }) };
}

export const read = (file) => readFileSync(file, "utf8");

/** Reescribe [file] con lo que devuelve [fn]; falla si no cambia nada (una edición que no se aplicó). */
export function edit(file, fn) {
  const before = readFileSync(file, "utf8");
  const after = fn(before);
  if (after === before) throw new Error(`la edición no cambió nada en ${file}`);
  writeFileSync(file, after);
}

// ─── Imágenes generadas ──────────────────────────────────────────────────────────────────────────

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const out = Buffer.alloc(12 + data.length);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, "latin1");
  data.copy(out, 8);
  out.writeUInt32BE(crc32(out.subarray(4, 8 + data.length)), 8 + data.length);
  return out;
}

const CHANNELS = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 };

/**
 * Un PNG válido (todo ceros). `colorType` 2 = RGB (24 bits), 6 = RGBA, 3 = paleta, 0 = gris, 4 = gris con
 * alfa; `trns` añade un trozo tRNS (transparencia sin canal alfa); `extra` añade un trozo `tEXt` de ese
 * tamaño en bytes (para pesar más).
 */
export function png({ width, height, colorType = 2, bitDepth = 8, trns = false, extra = 0 }) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = bitDepth;
  ihdr[9] = colorType;
  const rowBytes = Math.ceil((width * CHANNELS[colorType] * bitDepth) / 8) + 1;
  const parts = [Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk("IHDR", ihdr)];
  if (colorType === 3) parts.push(chunk("PLTE", Buffer.from([255, 255, 255])));
  if (trns) parts.push(chunk("tRNS", colorType === 2 ? Buffer.from([0, 0, 0, 0, 0, 0]) : Buffer.from([0])));
  if (extra > 0) parts.push(chunk("tEXt", Buffer.alloc(extra, 0x61)));
  parts.push(chunk("IDAT", deflateSync(Buffer.alloc(rowBytes * height))));
  parts.push(chunk("IEND", Buffer.alloc(0)));
  return Buffer.concat(parts);
}

/** Un JPEG mínimo: solo lo que lee la comprobación (cabecera y tamaño), con `components` componentes. */
export function jpeg({ width, height, components = 3 }) {
  const sof = Buffer.alloc(2 + 6 + 3 * components);
  sof.writeUInt16BE(8 + 3 * components, 0);
  sof[2] = 8;
  sof.writeUInt16BE(height, 3);
  sof.writeUInt16BE(width, 5);
  sof[7] = components;
  for (let i = 0; i < components; i++) sof.set([i + 1, 0x11, 0], 8 + 3 * i);
  const app0 = Buffer.from([0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]);
  return Buffer.concat([
    Buffer.from([0xff, 0xd8, 0xff, 0xe0]),
    app0,
    Buffer.from([0xff, 0xc0]),
    sof,
    Buffer.from([0xff, 0xd9]),
  ]);
}

/** Pone [bytes] en [file] (crea las carpetas). */
export function put(file, bytes) {
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, bytes);
}
