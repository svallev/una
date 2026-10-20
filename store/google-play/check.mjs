// Comprobaciones de la ficha de Google Play (spec 023): CA-023-08 (la tabla de permisos, la política y
// la lista blanca del manifiesto dicen lo mismo), CA-023-09 (textos de la ficha en ES y EN) y CA-023-10
// (icono, gráfico de funciones y capturas). Falla cerrada: lo que no entiende es un error.
//
//   node store/google-play/check.mjs
//
// Solo módulos de Node. Cada `check…` devuelve la lista de errores (vacía si todo está bien) para poder
// probar cada regla con un caso que falla (`store/google-play/test/`). Los límites y requisitos salen de
// `play-console.md` §7 (Ayuda de Play, consultada el 2026-10-20) y los permisos, de `data-safety.md` §6.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, extname, join, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { BuildError, extractPolicy, gapPattern, readIdentity } from "../../landing/build.mjs";
import { mentionsName } from "../../landing/check.mjs";

/**
 * ¿Se exigen ya el gráfico de funciones y las capturas? Hasta T-023-10 (que las crea) no: si existen se
 * comprueban igual, pero que falten no es un error. T-023-10 lo pone a `true`.
 */
export const GRAPHICS_REQUIRED = false;

class StoreError extends Error {}

const HERE = fileURLToPath(new URL(".", import.meta.url));
export const REPO_ROOT = resolve(HERE, "../..");

/** Todas las rutas que usa la comprobación; los tests las sustituyen por copias temporales. */
export function storePaths(repoRoot = REPO_ROOT) {
  const storeDir = join(repoRoot, "store/google-play");
  return {
    repoRoot,
    identity: join(repoRoot, "app/identity.yaml"),
    policy: join(repoRoot, "docs/legal/privacy-policy.md"),
    permissionsScript: join(repoRoot, "tools/check-android-permissions.sh"),
    dataSafety: join(storeDir, "data-safety.md"),
    storeDir,
    listingDir: join(storeDir, "listing"),
    icon: join(storeDir, "icon-512.png"),
    featureGraphic: join(storeDir, "feature-graphic.png"),
    screenshotsDir: join(storeDir, "screenshots"),
  };
}

const LANGS = ["es-ES", "en-US"];
/** Idioma de la ficha → parte de la política y columna de la tabla de permisos. */
const SHORT = { "es-ES": "es", "en-US": "en" };

function readText(path, label) {
  try {
    return readFileSync(path, "utf8").replace(/\r\n?/g, "\n");
  } catch (e) {
    throw new StoreError(`${label}: no se puede leer (${e.code ?? e.message})`);
  }
}

const rel = (paths, file) => relative(paths.repoRoot, file) || file;

/** Una comprobación entera: lo que lance (un archivo ilegible, una política rota) es un error, no una excepción. */
function guarded(fn) {
  try {
    return fn();
  } catch (e) {
    if (e instanceof StoreError || e instanceof BuildError) return [e.message];
    throw e;
  }
}

// ─── Permisos (CA-023-08) ────────────────────────────────────────────────────────────────────────

/** El permiso interno que Android añade a toda app para sus receptores no exportados no cuenta. */
const isInternalPermission = (p) => /\.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION$/.test(p);

/** La lista blanca `ALLOWED=(…)` de `tools/check-android-permissions.sh`. */
export function parseAllowed(scriptText) {
  const found = [...scriptText.matchAll(/^ALLOWED=\(([^)]*)\)[ \t]*$/gm)];
  if (found.length === 0) throw new StoreError("tools/check-android-permissions.sh: no encuentro la línea ALLOWED=(…)");
  if (found.length > 1) throw new StoreError("tools/check-android-permissions.sh: ALLOWED=(…) aparece más de una vez");
  const inside = found[0][1];
  const names = [...inside.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
  if (inside.replace(/"[^"]+"/g, "").trim() !== "") {
    throw new StoreError("tools/check-android-permissions.sh: ALLOWED=(…) tiene algo que no es un nombre entre comillas");
  }
  if (names.length === 0) throw new StoreError("tools/check-android-permissions.sh: ALLOWED=(…) está vacía");
  return names;
}

const TABLE_HEADER = ["permiso", "ES", "EN", "lista blanca"];
const STATUS = { "sí": "allowed", "sistema, no declarado": "system" };

const cells = (line) =>
  line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((c) => c.trim().replace(/^`([^`]*)`$/, "$1"));

/**
 * La tabla de permisos de `data-safety.md` §6: `| permiso | ES | EN | lista blanca |`. Cada fila:
 * `{permission, es, en, status, raw}`; `status` es `allowed` (sí), `system` (sistema, no declarado) o
 * `null` si el valor no es ninguno de los dos.
 */
export function parsePermissionTable(md) {
  const lines = md.replace(/\r\n?/g, "\n").split("\n");
  const at = lines.findIndex((l) => {
    const c = cells(l);
    return l.trim().startsWith("|") && c.length === TABLE_HEADER.length && c.every((x, i) => x.toLowerCase() === TABLE_HEADER[i].toLowerCase());
  });
  if (at < 0) {
    throw new StoreError("data-safety.md: no encuentro la tabla de permisos (| permiso | ES | EN | lista blanca |)");
  }
  if (!/^\|?[\s:|-]+\|?$/.test(lines[at + 1] ?? "") || !(lines[at + 1] ?? "").includes("-")) {
    throw new StoreError("data-safety.md: la tabla de permisos no tiene su línea separadora");
  }
  const rows = [];
  for (let i = at + 2; i < lines.length && lines[i].trim().startsWith("|"); i++) {
    const c = cells(lines[i]);
    if (c.length !== 4) throw new StoreError(`data-safety.md: fila de la tabla de permisos mal formada: «${lines[i].trim()}»`);
    rows.push({ permission: c[0], es: c[1], en: c[2], status: STATUS[c[3]] ?? null, raw: c[3] });
  }
  if (rows.length === 0) throw new StoreError("data-safety.md: la tabla de permisos no tiene filas");
  return rows;
}

const PERMISSION_ID = /android\.permission\.[A-Za-z0-9_]+/g;

/** CA-023-08: la tabla de permisos frente a la lista blanca y a la política, en los dos sentidos. */
export function checkPermissions(paths = storePaths()) {
  return guarded(() => {
    const errors = [];
    const allowed = parseAllowed(readText(paths.permissionsScript, "tools/check-android-permissions.sh")).filter(
      (p) => !isInternalPermission(p),
    );
    const rows = parsePermissionTable(readText(paths.dataSafety, "data-safety.md")).filter((r) => !isInternalPermission(r.permission));
    const policy = extractPolicy(readText(paths.policy, "docs/legal/privacy-policy.md"));

    const seen = new Set();
    for (const r of rows) {
      if (seen.has(r.permission)) errors.push(`data-safety.md: el permiso ${r.permission} está repetido en la tabla de permisos`);
      seen.add(r.permission);
      if (!/^[A-Za-z0-9_.]+$/.test(r.permission)) errors.push(`data-safety.md: «${r.permission}» no es un nombre de permiso`);
      if (r.status === null) {
        errors.push(`data-safety.md: ${r.permission}: el valor de «lista blanca» («${r.raw}») no es «sí» ni «sistema, no declarado»`);
      }
    }
    // Lista blanca → tabla.
    for (const p of allowed) {
      const row = rows.find((r) => r.permission === p);
      if (!row) errors.push(`${p}: está en la lista blanca del manifiesto y no en la tabla de permisos de data-safety.md`);
    }
    // Tabla → lista blanca.
    for (const r of rows) {
      const inList = allowed.includes(r.permission);
      if (r.status === "allowed" && !inList) {
        errors.push(`${r.permission}: la tabla de permisos dice «sí» y no está en la lista blanca (tools/check-android-permissions.sh)`);
      }
      if (r.status === "system" && inList) {
        errors.push(`${r.permission}: la tabla lo marca «sistema, no declarado» y sí está en la lista blanca`);
      }
    }
    // Los nombres, tal cual, en la parte de la política de su idioma.
    for (const r of rows) {
      if (r.status === null) continue;
      if (r.es === "" || !policy.es.includes(r.es)) {
        errors.push(`${r.permission}: el nombre en español «${r.es}» no aparece en la parte española de la política`);
      }
      if (r.en === "" || !policy.en.includes(r.en)) {
        errors.push(`${r.permission}: el nombre en inglés «${r.en}» no aparece en la parte inglesa de la política`);
      }
    }
    // La política no nombra permisos que la tabla no tenga.
    const known = new Set(rows.map((r) => r.permission));
    for (const half of [policy.es, policy.en]) {
      for (const id of new Set(half.match(PERMISSION_ID) ?? [])) {
        if (!known.has(id)) errors.push(`${id}: la política lo nombra y no está en la tabla de permisos de data-safety.md`);
      }
    }
    return errors;
  });
}

// ─── Textos de la ficha (CA-023-09) ──────────────────────────────────────────────────────────────

const LIMITS = { title: 30, "short-description": 80, "full-description": 4000 };
const NAMES = Object.keys(LIMITS);

/** Una palabra suelta (sin letras ni cifras pegadas), sin distinguir mayúsculas. */
const word = (source) => new RegExp(`(?<![\\p{L}\\p{N}_])(?:${source})(?![\\p{L}\\p{N}_])`, "iu");

const EMOJI = /\p{Extended_Pictographic}|\p{Emoji_Presentation}|\p{Regional_Indicator}|\u{fe0f}|\u{20e3}/u;

/** Superlativos, palabras promocionales y comparaciones que la política de metadatos de Play prohíbe. */
const PROMO = [
  [word("mejor(?:es)?|best|top|free|gratis|gratuit[oa]s?"), "superlativo o palabra promocional"],
  [word("n[uú]mero\\s?(?:1|uno)|n[º°o]\\.?\\s?1|number\\s?(?:1|one)|no\\.\\s?1"), "superlativo (número 1)"],
  [/#\s?1(?![\p{N}])/u, "superlativo (#1)"],
  [word("mejor que|better than|a diferencia de|unlike|m[aá]s que (?:otras|las dem[aá]s|cualquier)|than (?:other|any)|que (?:otras|las dem[aá]s) apps?"), "comparación con otras apps"],
];

/** Lo que la app no hace y la ficha no puede prometer: sincronización, otras plataformas y más idiomas. */
const CLAIMS = [
  word("sincroniz\\p{L}*|sync\\p{L}*"),
  word("iOS|iPhone|iPad|Apple|App Store"),
  word("catal[aá]n|catalan|gallego|galician|euskera|basque|vasco|franc[eé]s|french|alem[aá]n|german|italiano|italian|portugu[eé]s|portuguese|chino|chinese|japon[eé]s|japanese|[aá]rabe|arabic|ruso|russian"),
  word("multiling[uü]e|multilingual|varios idiomas|several languages|m[aá]s idiomas|more languages"),
  word("subtareas?|subtasks?"),
];

/**
 * Lo que la descripción completa tiene que decir (CA-023-09). Cada punto: expresiones que deben darse
 * **todas en una misma frase** (`es`/`en`) y su descripción para el mensaje.
 */
export const POINTS = [
  { id: "one-task", desc: "una sola tarea a la vez", es: [/una sola tarea a la vez/i], en: [/one task at a time/i] },
  { id: "full-screen", desc: "a pantalla completa", es: [/pantalla completa/i], en: [/full[ -]screen/i] },
  { id: "photo", desc: "una foto", es: [/\bfotos?\b/i], en: [/\bphotos?\b/i] },
  {
    id: "photos",
    desc: "varias fotos",
    es: [/varias fotos|hasta 10 fotos|grupo de fotos/i],
    en: [/several photos|multiple photos|up to 10 photos|group of photos/i],
  },
  { id: "pdf", desc: "PDF", es: [/\bPDF\b/], en: [/\bPDF\b/] },
  { id: "web", desc: "una web", es: [/\bweb\b/i], en: [/\bweb\b|\bwebsite\b/i] },
  { id: "no-accounts", desc: "sin cuentas", es: [/sin cuentas/i], en: [/no accounts|without accounts/i] },
  { id: "no-server", desc: "sin servidor", es: [/sin servidor/i], en: [/no server|without a server/i] },
  { id: "no-analytics", desc: "sin analítica", es: [/sin anal[ií]tica/i], en: [/no analytics|without analytics/i] },
  {
    id: "web-needs-connection",
    desc: "la tarea web necesita conexión (en la misma frase)",
    es: [/\bweb\b/i, /(?:necesita|requiere) conexi[oó]n/i],
    en: [/\bweb\b/i, /(?:needs?|requires?) (?:an? )?(?:internet )?(?:connection|internet)/i],
  },
  {
    id: "notifications-optional",
    desc: "las notificaciones son opcionales (en la misma frase)",
    es: [/notificaciones/i, /opcionales?/i],
    en: [/notifications/i, /optional/i],
  },
  {
    id: "languages",
    desc: "español e inglés (en la misma frase)",
    es: [/espa[ñn]ol/i, /ingl[eé]s/i],
    en: [/\bSpanish\b/, /\bEnglish\b/],
  },
];

/** Las frases de [text]: cortadas por saltos de línea y por `. ! ? : ;` seguidos de espacio. */
const sentences = (text) =>
  text
    .split(/(?<=[.!?:;])\s+|\n+/)
    .map((s) => s.trim())
    .filter(Boolean);

const NEGATOR = {
  es: /(?<![\p{L}])(?:no|sin|ning[uú]n[oa]?|nunca|ni)(?![\p{L}])/iu,
  en: /(?<![\p{L}])(?:no|not|without|never|none|nor)(?![\p{L}])|n['’]t(?![\p{L}])/iu,
};
const PERMISSION_WORD = { es: /permisos?/i, en: /permissions?/i };
/** Permisos delicados que la app no pide: prometerlos es falso. */
const SENSITIVE = {
  es: word("c[aá]mara|fotos|galer[ií]a|almacenamiento|archivos|ubicaci[oó]n|contactos|micr[oó]fono|calendario|tel[eé]fono|llamadas|sms|bluetooth|sensores|portapapeles|huella|biom[eé]tric\\p{L}*|alarmas? exactas?|red local"),
  en: word("camera|photos?|gallery|storage|files?|location|contacts|microphone|calendar|phone|calls|sms|bluetooth|sensors|clipboard|fingerprint|biometric\\p{L}*|exact alarms?|local network"),
};

const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const literalWord = (s) => new RegExp(`(?<![\\p{L}\\p{N}_])${escapeRe(s)}(?![\\p{L}\\p{N}_])`, "iu");

const codePoints = (s) => [...s].length;

/** CA-023-09 (y la parte de CA-023-08 que toca a la ficha): los textos de la ficha en ES y EN. */
export function checkListing(paths = storePaths()) {
  return guarded(() => {
    const errors = [];
    const identity = readIdentity(readText(paths.identity, "app/identity.yaml"), "identity.yaml");
    const name = identity.displayName;

    let permissionRows = null;
    try {
      permissionRows = parsePermissionTable(readText(paths.dataSafety, "data-safety.md")).filter((r) => !isInternalPermission(r.permission));
    } catch (e) {
      if (!(e instanceof StoreError)) throw e;
      errors.push(`ficha: no puedo comprobar los permisos sin la tabla (${e.message})`);
    }

    if (!existsSync(paths.listingDir)) return [...errors, `${rel(paths, paths.listingDir)}: falta la carpeta de la ficha`];
    for (const entry of readdirSync(paths.listingDir).sort()) {
      if (!LANGS.includes(entry)) errors.push(`${rel(paths, join(paths.listingDir, entry))}: carpeta o archivo inesperado (solo ${LANGS.join(" y ")})`);
    }

    for (const lang of LANGS) {
      const dir = join(paths.listingDir, lang);
      if (!existsSync(dir)) {
        errors.push(`${rel(paths, dir)}: falta la carpeta del idioma`);
        continue;
      }
      for (const entry of readdirSync(dir).sort()) {
        if (!NAMES.some((n) => `${n}.txt` === entry)) errors.push(`${rel(paths, join(dir, entry))}: archivo inesperado`);
      }
      for (const file of NAMES) {
        const path = join(dir, `${file}.txt`);
        const where = rel(paths, path);
        if (!existsSync(path)) {
          errors.push(`${where}: falta`);
          continue;
        }
        let raw = readText(path, where);
        if (raw.startsWith("\ufeff")) {
          errors.push(`${where}: empieza con una marca BOM`);
          raw = raw.slice(1);
        }
        const text = raw.replace(/\n+$/, "");
        if (text.trim() === "") {
          errors.push(`${where}: vacío`);
          continue;
        }
        checkText({ errors, where, file, lang, text, name, wordmark: identity.wordmark, permissionRows });
      }
    }
    return errors;
  });
}

function checkText({ errors, where, file, lang, text, name, wordmark, permissionRows }) {
  const fail = (msg) => errors.push(`${where}: ${msg}`);
  const short = SHORT[lang];

  // Huecos, marcas y marcadores.
  for (const g of text.match(gapPattern()) ?? []) fail(`hueco de identidad «${g}»: la ficha no se publica con huecos`);
  for (const m of text.match(/\[[^\]\n]*\]/g) ?? []) {
    if (!gapPattern().test(m)) fail(`marca o texto entre corchetes «${m}»`);
  }
  for (const m of text.match(/\{[^}\n]*\}/g) ?? []) {
    if (m !== "{appName}") fail(`marcador «${m}» (el único admitido es {appName})`);
  }

  // El nombre sale de la identidad (P7).
  text.split("\n").forEach((line, i) => {
    for (const n of [name, wordmark]) {
      if (mentionsName(line, n)) fail(`línea ${i + 1}: el nombre de la app «${n}» está escrito a mano (sale de app/identity.yaml: usa {appName})`);
    }
  });
  if (file === "title" && text !== "{appName}") fail("el título tiene que ser exactamente {appName} (el nombre de la identidad)");

  // Longitud, contada como Play: en caracteres, con el nombre ya sustituido.
  const filled = text.replaceAll("{appName}", name);
  const n = codePoints(filled);
  if (n > LIMITS[file]) fail(`${n} caracteres (máximo ${LIMITS[file]})`);

  if (file !== "full-description") {
    if (/\n/.test(text)) fail("tiene un salto de línea (Play no lo admite aquí)");
    if (EMOJI.test(filled)) fail("lleva un emoji (la política de metadatos de Play lo prohíbe)");
    const rep = /([^\p{L}\p{N}\s])\1{2,}/u.exec(filled);
    if (rep) fail(`caracteres especiales repetidos («${rep[0]}»)`);
  }
  if (file === "short-description") {
    const caps = (filled.match(/\p{L}+/gu) ?? []).filter((w) => w.length >= 3 && w === w.toUpperCase() && w !== w.toLowerCase() && w !== "PDF" && w !== name);
    if (caps.length > 0) fail(`palabras en mayúsculas de énfasis (${caps.join(", ")})`);
    const multiple = /[.!?]\s+\S/.test(filled);
    if (!multiple && /\.$/.test(filled)) fail("una sola frase no acaba en punto (Play: el punto final solo si hay varias frases)");
  }

  // Superlativos, comparaciones y promesas falsas.
  for (const [re, kind] of PROMO) {
    const m = re.exec(filled);
    if (m) fail(`«${m[0]}»: ${kind} (política de metadatos de Play)`);
  }
  for (const re of CLAIMS) {
    const m = re.exec(filled);
    if (m) fail(`«${m[0]}»: promete algo que la app no hace (sincronización, otras plataformas u otros idiomas)`);
  }

  // Permisos: ni prometer los que la app no pide ni negar los que sí.
  if (permissionRows) {
    const known = new Set(permissionRows.map((r) => r.permission));
    for (const id of new Set(filled.match(PERMISSION_ID) ?? [])) {
      if (!known.has(id)) fail(`${id}: no es un permiso de la app (tabla de permisos de data-safety.md)`);
    }
    const real = permissionRows.filter((r) => r.status === "allowed").map((r) => r[short]);
    for (const s of sentences(filled)) {
      const negated = NEGATOR[short].test(s);
      const talksPermission = PERMISSION_WORD[short].test(s);
      let denied = false;
      if (talksPermission && negated) {
        const hit = real.find((r) => literalWord(r).test(s));
        if (hit) {
          fail(`«${s}»: niega un permiso real de la app («${hit}»)`);
          denied = true;
        }
      }
      if (talksPermission && !negated) {
        const m = SENSITIVE[short].exec(s);
        if (m) fail(`«${s}»: promete un permiso que la app no pide («${m[0]}»)`);
      }
      if (!denied && negated && /(?<![\p{L}])internet(?![\p{L}])/iu.test(s)) {
        fail(`«${s}»: niega Internet, que la tarea web sí usa`);
      }
    }
  }

  // Lo que la descripción completa tiene que decir.
  if (file === "full-description") {
    const segments = sentences(filled);
    for (const p of POINTS) {
      const res = short === "es" ? p.es : p.en;
      if (!segments.some((s) => res.every((r) => r.test(s)))) fail(`falta decir «${p.id}»: ${p.desc}`);
    }
  }
}

// ─── Imágenes (CA-023-10) ────────────────────────────────────────────────────────────────────────

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function readPng(buf) {
  let pos = PNG_SIGNATURE.length;
  let ihdr = null;
  let trns = false;
  let idat = false;
  let end = false;
  while (pos < buf.length) {
    if (end) throw new StoreError("PNG con datos después de IEND");
    if (pos + 12 > buf.length) throw new StoreError("PNG truncado (trozo incompleto)");
    const len = buf.readUInt32BE(pos);
    const type = buf.toString("latin1", pos + 4, pos + 8);
    if (pos + 12 + len > buf.length) throw new StoreError(`PNG truncado (el trozo ${type} no cabe)`);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (ihdr === null && type !== "IHDR") throw new StoreError("PNG sin IHDR al principio");
    if (type === "IHDR") {
      if (ihdr !== null || len !== 13) throw new StoreError("PNG con IHDR mal formado");
      ihdr = { width: data.readUInt32BE(0), height: data.readUInt32BE(4), bitDepth: data[8], colorType: data[9] };
    } else if (type === "tRNS") trns = true;
    else if (type === "IDAT") idat = true;
    else if (type === "IEND") end = true;
    pos += 12 + len;
  }
  if (!end) throw new StoreError("PNG truncado (sin IEND)");
  if (!idat) throw new StoreError("PNG sin datos de imagen");
  const alpha = ihdr.colorType === 4 || ihdr.colorType === 6 || trns;
  return { format: "png", ...ihdr, alpha, trns };
}

const isSof = (m) => m >= 0xc0 && m <= 0xcf && m !== 0xc4 && m !== 0xc8 && m !== 0xcc;

function readJpeg(buf) {
  let pos = 2;
  while (pos < buf.length) {
    if (buf[pos] !== 0xff) throw new StoreError("JPEG con un marcador mal formado");
    while (buf[pos] === 0xff) pos++;
    const marker = buf[pos++];
    if (marker === undefined) break;
    if (marker === 0xd9 || marker === 0xda) throw new StoreError("JPEG sin cabecera de tamaño (SOF)");
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd8)) continue;
    if (pos + 2 > buf.length) throw new StoreError("JPEG truncado");
    const len = buf.readUInt16BE(pos);
    if (len < 2 || pos + len > buf.length) throw new StoreError("JPEG truncado");
    if (isSof(marker)) {
      if (len < 8) throw new StoreError("JPEG con SOF mal formado");
      return { format: "jpeg", height: buf.readUInt16BE(pos + 3), width: buf.readUInt16BE(pos + 5), components: buf[pos + 7], alpha: false };
    }
    pos += len;
  }
  throw new StoreError("JPEG sin cabecera de tamaño (SOF)");
}

/** Formato, tamaño y canal alfa de una imagen PNG o JPEG, leyendo la cabecera a mano. */
export function imageInfo(buf) {
  if (buf.length === 0) throw new StoreError("archivo vacío (no es una imagen)");
  if (buf.length >= 8 && buf.subarray(0, 8).equals(PNG_SIGNATURE)) return readPng(buf);
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return readJpeg(buf);
  throw new StoreError("no es una imagen PNG ni JPEG");
}

/**
 * Comprueba un archivo de imagen. `spec`: `{width, height, alpha: 'forbidden'|'required', maxBytes?, formats}`.
 */
function checkImage(paths, file, spec, errors) {
  const where = rel(paths, file);
  const ext = extname(file).toLowerCase();
  const kind = { ".png": "png", ".jpg": "jpeg", ".jpeg": "jpeg" }[ext];
  if (!kind || !spec.formats.includes(kind)) {
    errors.push(`${where}: formato no admitido (${spec.formats.map((f) => f.toUpperCase()).join(" o ")})`);
    return;
  }
  let info;
  try {
    info = imageInfo(readFileSync(file));
  } catch (e) {
    if (!(e instanceof StoreError)) throw e;
    errors.push(`${where}: ${e.message}`);
    return;
  }
  if (info.format !== kind) {
    errors.push(`${where}: la extensión ${ext} no coincide con el contenido (${info.format.toUpperCase()})`);
    return;
  }
  if (info.width !== spec.width || info.height !== spec.height) {
    errors.push(`${where}: mide ${info.width} × ${info.height}, tiene que medir ${spec.width} × ${spec.height}`);
  }
  if (spec.alpha === "required") {
    if (info.format !== "png" || info.colorType !== 6 || info.bitDepth !== 8) {
      errors.push(`${where}: tiene que ser un PNG de 32 bits con canal alfa (Play)`);
    }
  } else if (info.format === "png") {
    if (info.colorType !== 2 || info.bitDepth !== 8 || info.trns) {
      const why = info.alpha ? "tiene canal alfa o transparencia" : `es de ${info.bitDepth} bits, tipo de color ${info.colorType}`;
      errors.push(`${where}: tiene que ser un PNG de 24 bits sin canal alfa (${why}; P5)`);
    }
  } else if (info.components !== 1 && info.components !== 3) {
    errors.push(`${where}: JPEG con ${info.components} componentes (tiene que ser RGB o gris)`);
  }
  if (spec.maxBytes !== undefined) {
    const bytes = statSync(file).size;
    if (bytes > spec.maxBytes) errors.push(`${where}: pesa ${Math.ceil(bytes / 1024)} KB, máximo ${spec.maxBytes / 1024} KB`);
  }
}

const ICON = { width: 512, height: 512, alpha: "required", maxBytes: 1024 * 1024, formats: ["png"] };
const FEATURE = { width: 1024, height: 500, alpha: "forbidden", formats: ["png", "jpeg"] };
const SHOT = { width: 1080, height: 1920, alpha: "forbidden", formats: ["png", "jpeg"] };
const SHOT_COUNT = 4;

/** CA-023-10: icono (siempre), gráfico de funciones y 4 capturas por idioma (si se exigen o si existen). */
export function checkGraphics(paths = storePaths(), { requireGraphics = GRAPHICS_REQUIRED } = {}) {
  return guarded(() => {
    const errors = [];

    // Icono: lo exige la spec desde el principio (es el de la 018, sin cambios).
    if (existsSync(paths.icon)) checkImage(paths, paths.icon, ICON, errors);
    else errors.push(`${rel(paths, paths.icon)}: falta`);

    // Gráfico de funciones.
    const features = existsSync(paths.storeDir)
      ? readdirSync(paths.storeDir).filter((f) => /^feature-graphic\./.test(f)).sort()
      : [];
    if (features.length === 0) {
      if (requireGraphics) errors.push(`${rel(paths, paths.featureGraphic)}: falta el gráfico de funciones`);
    } else if (features.length > 1) {
      errors.push(`${rel(paths, paths.storeDir)}: hay más de un gráfico de funciones (${features.join(", ")}): tiene que ser uno solo`);
    } else {
      checkImage(paths, join(paths.storeDir, features[0]), FEATURE, errors);
    }

    // Capturas.
    const dirExists = existsSync(paths.screenshotsDir);
    if (!dirExists && requireGraphics) errors.push(`${rel(paths, paths.screenshotsDir)}: falta la carpeta de capturas`);
    if (dirExists) {
      for (const entry of readdirSync(paths.screenshotsDir).sort()) {
        if (entry.startsWith(".")) continue;
        if (!LANGS.includes(entry)) errors.push(`${rel(paths, join(paths.screenshotsDir, entry))}: carpeta o archivo inesperado (solo ${LANGS.join(" y ")})`);
      }
      for (const lang of LANGS) checkScreenshots(paths, lang, requireGraphics, errors);
    }
    return errors;
  });
}

function checkScreenshots(paths, lang, requireGraphics, errors) {
  const dir = join(paths.screenshotsDir, lang);
  const where = rel(paths, dir);
  const files = existsSync(dir) ? readdirSync(dir).filter((f) => !f.startsWith(".")).sort() : [];
  if (files.length === 0) {
    if (requireGraphics) errors.push(`${where}: ${existsSync(dir) ? "sin capturas" : "falta la carpeta"} (tiene que tener ${SHOT_COUNT} capturas, 1-… a ${SHOT_COUNT}-…)`);
    return;
  }
  const byNumber = new Map();
  for (const f of files) {
    const full = join(dir, f);
    if (statSync(full).isDirectory()) {
      errors.push(`${rel(paths, full)}: carpeta inesperada`);
      continue;
    }
    const m = /^([1-9]\d*)-[a-z0-9]+(?:-[a-z0-9]+)*\.[A-Za-z0-9]+$/.exec(f);
    const number = m ? Number(m[1]) : 0;
    if (!m || number > SHOT_COUNT) {
      errors.push(`${rel(paths, full)}: nombre no válido (tiene que ser 1-nombre.png a ${SHOT_COUNT}-nombre.png, en minúsculas y con guiones)`);
      continue;
    }
    if (!byNumber.has(number)) byNumber.set(number, []);
    byNumber.get(number).push(f);
    checkImage(paths, full, SHOT, errors);
  }
  for (const [number, list] of byNumber) {
    if (list.length > 1) errors.push(`${where}: el número ${number}- está repetido (${list.join(", ")})`);
  }
  if (files.length !== SHOT_COUNT) errors.push(`${where}: debe tener ${SHOT_COUNT} capturas (1-… a ${SHOT_COUNT}-…) y tiene ${files.length}`);
  for (let i = 1; i <= SHOT_COUNT; i++) {
    if (!byNumber.has(i) && files.length === SHOT_COUNT) errors.push(`${where}: falta la captura ${i}-…`);
  }
}

// ─── Todo junto ──────────────────────────────────────────────────────────────────────────────────

/** Todas las comprobaciones de la ficha. */
export function checkStore(paths = storePaths(), { requireGraphics = GRAPHICS_REQUIRED } = {}) {
  return [...checkPermissions(paths), ...checkListing(paths), ...checkGraphics(paths, { requireGraphics })];
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const paths = storePaths();
  const errors = checkStore(paths);
  if (!GRAPHICS_REQUIRED) {
    const missing = [paths.featureGraphic, paths.screenshotsDir].filter((p) => !existsSync(p));
    for (const m of missing) console.log(`aviso: ${basename(m)} aún no existe (se exige a partir de T-023-10)`);
  }
  if (errors.length > 0) {
    for (const e of errors) console.error(`error: ${e}`);
    console.error(`\n${errors.length} error(es) en la ficha de la tienda.`);
    process.exit(1);
  }
  console.log("Ficha comprobada (permisos, textos y gráficos): sin errores.");
}
