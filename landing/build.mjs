// Construye la web de la app (spec 023, CA-023-03, 04, 13 a 15): la página de inicio, la política de
// privacidad y la página de error, en español e inglés en la misma dirección, sin JavaScript.
//
//   node landing/build.mjs      escribe landing/dist/
//
// Solo módulos de Node, sin `package.json` ni dependencias (P11). Lee `app/identity.yaml` (el nombre,
// P7), `design/tokens.json` (colores, fuentes y medidas, P12), los títulos de las ARB, el texto de la
// política (`docs/legal/privacy-policy.md`, la única copia, CA-023-04) y `landing/src/`. Falla cerrada:
// lo que no entiende (Markdown fuera del subconjunto, un enlace raro, un `{…}` sin sustituir, una
// clave que falta) detiene la construcción en lugar de publicar algo distinto de lo escrito.
import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export class BuildError extends Error {}
export class MarkdownError extends BuildError {}

const HERE = dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = resolve(HERE, "..");

/** Todas las rutas que usa la construcción; los tests las sustituyen por copias temporales. */
export function defaultPaths(repoRoot = REPO_ROOT) {
  const landingDir = join(repoRoot, "landing");
  return {
    repoRoot,
    landingDir,
    identity: join(repoRoot, "app/identity.yaml"),
    tokens: join(repoRoot, "design/tokens.json"),
    arbEs: join(repoRoot, "app/lib/l10n/app_es.arb"),
    arbEn: join(repoRoot, "app/lib/l10n/app_en.arb"),
    policy: join(repoRoot, "docs/legal/privacy-policy.md"),
    srcDir: join(landingDir, "src"),
    strings: join(landingDir, "src/strings.json"),
    siteCss: join(landingDir, "src/site.css"),
    buildFile: join(landingDir, "build.mjs"),
    vercelJson: join(landingDir, "vercel.json"),
    fontsDir: join(repoRoot, "app/assets/fonts"),
    out: join(landingDir, "dist"),
  };
}

// ─── Utilidades ──────────────────────────────────────────────────────────────────────────────────

/** Escapa el texto para HTML (también en atributos). */
export const esc = (s) =>
  String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

/** `textMuted` → `text-muted`. */
export const kebab = (s) => s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();

const norm = (text) => text.replace(/\r\n?/g, "\n");

function readText(path, label) {
  try {
    return readFileSync(path, "utf8");
  } catch (e) {
    throw new BuildError(`${label}: no se puede leer (${e.code ?? e.message})`);
  }
}

/** Los huecos de identidad (CA-023-01): la misma lista cerrada que la puerta de publicación. */
const GAP_WORDS = "RESPONSABLE|CONTROLLER|CONTACTO|CONTACT|FECHA|DATE|WEB|WEBSITE";
export const gapPattern = () => new RegExp(`\\[\\s*(?:${GAP_WORDS})\\s*\\]`, "gi");
const GAP_ONLY = new RegExp(`^\\[\\s*(?:${GAP_WORDS})\\s*\\]$`, "i");

// ─── Identidad ───────────────────────────────────────────────────────────────────────────────────

/** Lee `identity.yaml` con un lector mínimo: solo `clave: "texto"` y comentarios; lo demás falla. */
export function readIdentity(text, label = "identity.yaml") {
  const out = {};
  norm(text)
    .split("\n")
    .forEach((line, i) => {
      if (/^\s*(#.*)?$/.test(line)) return;
      const m = /^([A-Za-z][A-Za-z0-9]*):\s*"([^"\\]*)"\s*(#.*)?$/.exec(line);
      if (!m) {
        throw new BuildError(
          `${label}, línea ${i + 1}: no sé leer «${line.trim()}» (solo «clave: "texto"» entre comillas y comentarios)`,
        );
      }
      if (m[1] in out) throw new BuildError(`${label}, línea ${i + 1}: «${m[1]}» está repetida`);
      out[m[1]] = m[2];
    });
  for (const key of ["displayName", "wordmark"]) {
    if (!out[key]) throw new BuildError(`${label}: falta «${key}»`);
  }
  return out;
}

// ─── Markdown (subconjunto con falla cerrada) ────────────────────────────────────────────────────

const mdFail = (msg) => {
  throw new MarkdownError(msg);
};

/** Un enlace admitido: `https:`, `mailto:`, relativo o `#…`. */
function checkUrl(url) {
  if (!url) mdFail("enlace vacío");
  if (/[\s"'<>`\\\u0000-\u001f]/.test(url)) mdFail(`enlace no admitido (caracteres no válidos): «${url}»`);
  if (url.startsWith("#")) {
    if (!/^#[A-Za-z0-9_-]+$/.test(url)) mdFail(`enlace no admitido: «${url}»`);
    return { external: false };
  }
  if (url.startsWith("//")) mdFail(`enlace no admitido (sin protocolo, a otro sitio): «${url}»`);
  const scheme = /^([A-Za-z][A-Za-z0-9+.-]*):/.exec(url);
  if (!scheme) return { external: false }; // relativo
  const name = scheme[1].toLowerCase();
  if (name === "https") {
    const authority = /^https:\/\/([^/?#]*)/i.exec(url)?.[1];
    if (!authority || authority.includes("@")) mdFail(`enlace https no admitido: «${url}»`);
    return { external: true };
  }
  if (name === "mailto") {
    if (url.length <= "mailto:".length) mdFail(`enlace mailto vacío: «${url}»`);
    return { external: false };
  }
  return mdFail(`enlace no admitido (solo https, mailto, relativos y #): «${url}»`);
}

function inline(src, gaps) {
  let out = "";
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === "`") {
      if (src[i + 1] === "`") mdFail("no se admiten los acentos graves dobles");
      const end = src.indexOf("`", i + 1);
      if (end < 0) mdFail(`código sin cerrar: «${src.slice(i, i + 30)}»`);
      out += `<code>${esc(src.slice(i + 1, end))}</code>`;
      i = end + 1;
    } else if (c === "\\") {
      mdFail("no se admite la barra invertida");
    } else if (c === "!" && src[i + 1] === "[") {
      mdFail("no se admiten imágenes");
    } else if (c === "*" && src[i + 1] === "*") {
      const end = src.indexOf("**", i + 2);
      if (end < 0 || end === i + 2) mdFail(`negrita sin cerrar: «${src.slice(i, i + 30)}»`);
      out += `<strong>${inline(src.slice(i + 2, end), gaps)}</strong>`;
      i = end + 2;
    } else if (c === "*") {
      let end = i + 1;
      while (end < src.length && !(src[end] === "*" && src[end - 1] !== "*" && src[end + 1] !== "*")) end++;
      if (end >= src.length || end === i + 1) mdFail(`cursiva sin cerrar: «${src.slice(i, i + 30)}»`);
      out += `<em>${inline(src.slice(i + 1, end), gaps)}</em>`;
      i = end + 1;
    } else if (c === "[") {
      const close = src.indexOf("]", i + 1);
      if (close < 0) mdFail(`corchete sin cerrar: «${src.slice(i, i + 30)}»`);
      const text = src.slice(i + 1, close);
      if (src[close + 1] === "(") {
        const endUrl = src.indexOf(")", close + 2);
        if (endUrl < 0) mdFail(`enlace sin cerrar: «${src.slice(i, i + 40)}»`);
        const url = src.slice(close + 2, endUrl);
        if (!text.trim()) mdFail(`enlace sin texto: «${url}»`);
        if (text.includes("[")) mdFail(`enlace con corchetes dentro: «${text}»`);
        const { external } = checkUrl(url);
        const rel = external ? ' rel="noopener noreferrer"' : "";
        out += `<a href="${esc(url)}"${rel}>${inline(text, gaps)}</a>`;
        i = endUrl + 1;
      } else {
        const group = src.slice(i, close + 1);
        if (!GAP_ONLY.test(group)) {
          mdFail(`texto entre corchetes que no es un hueco de identidad ni un enlace: «${group}»`);
        }
        gaps.push(group);
        out += esc(group);
        i = close + 1;
      }
    } else {
      out += esc(c);
      i++;
    }
  }
  return out;
}

/** Falla con lo que el subconjunto no admite al empezar (o continuar) un bloque. */
function rejectUnsupported(line) {
  if (/^ {4,}\S/.test(line)) mdFail("no se admite el código con sangría");
  if (/^\s*(```|~~~)/.test(line)) mdFail("no se admiten los bloques de código");
  if (/^\|/.test(line) || (line.includes("-") && /^[ |:-]*\|[ |:-]*$/.test(line))) {
    mdFail("no se admiten las tablas");
  }
  if (/^\s*(-{3,}|\*{3,}|_{3,}|=+)\s*$/.test(line)) {
    mdFail("no se admiten las líneas horizontales ni los encabezados subrayados");
  }
  if (/^\s*\d+[.)]\s/.test(line)) mdFail("no se admiten las listas numeradas");
  if (/^\s*[*+]\s/.test(line)) mdFail("las listas van con «- » (no con «*» ni «+»)");
  if (/^#{4,}(\s|$)/.test(line)) mdFail("solo se admiten los encabezados de «#» a «###»");
}

/**
 * Convierte [md] (el subconjunto: encabezados `#`–`###`, párrafos, listas con «- » y anidadas,
 * citas, **negrita**, *cursiva*, `código` y enlaces) a HTML. [shift] desplaza el nivel de los
 * encabezados; [firstHeadingAttrs] son los atributos del primero. Devuelve el HTML, los encabezados
 * que leyó y los huecos de identidad que dejó tal cual.
 */
export function convertMarkdown(md, { shift = 0, firstHeadingAttrs = "" } = {}) {
  const text = norm(md);
  if (text.includes("\t")) mdFail("no se admiten los tabuladores");
  const placeholder = /\{[^{}\n]*\}/.exec(text);
  if (placeholder) mdFail(`marcador sin sustituir: ${placeholder[0]}`);

  const lines = text.split("\n");
  const blocks = [];
  const headings = [];
  const gaps = [];
  let firstHeading = true;
  let i = 0;

  const startsBlock = (line) => /^#/.test(line) || /^>/.test(line) || /^- /.test(line);

  while (i < lines.length) {
    const line = lines[i];
    if (line.trim() === "") {
      i++;
      continue;
    }
    rejectUnsupported(line);

    const heading = /^(#{1,3}) +(\S.*)$/.exec(line);
    if (heading) {
      const level = heading[1].length + shift;
      const attrs = firstHeading && firstHeadingAttrs ? ` ${firstHeadingAttrs}` : "";
      firstHeading = false;
      headings.push({ level, text: heading[2].trim() });
      blocks.push(`<h${level}${attrs}>${inline(heading[2].trim(), gaps)}</h${level}>`);
      i++;
      continue;
    }
    if (/^#/.test(line)) mdFail(`encabezado no válido: «${line.slice(0, 30)}»`);

    if (/^>/.test(line)) {
      const parts = [];
      while (i < lines.length && /^>/.test(lines[i])) {
        const content = lines[i].replace(/^> ?/, "");
        if (content.trim() === "") mdFail("no se admiten las citas con varios párrafos");
        parts.push(content.trim());
        i++;
      }
      blocks.push(`<blockquote>\n<p>${inline(parts.join(" "), gaps)}</p>\n</blockquote>`);
      continue;
    }

    if (/^ *- /.test(line)) {
      const items = [];
      while (i < lines.length && lines[i].trim() !== "") {
        const l = lines[i];
        const item = /^( *)- (.*)$/.exec(l);
        if (item) {
          const indent = item[1].length;
          const prev = items.length ? items[items.length - 1].indent : -2;
          if (indent % 2 !== 0 || indent > prev + 2 || (items.length === 0 && indent !== 0)) {
            mdFail(`sangría no admitida en la lista (de dos en dos espacios): «${l.trim().slice(0, 30)}»`);
          }
          if (!item[2].trim()) mdFail("punto de lista vacío");
          rejectUnsupported(item[2]);
          items.push({ indent, text: item[2].trim() });
        } else if (/^ +\S/.test(l)) {
          const last = items[items.length - 1];
          if (l.length - l.trimStart().length !== last.indent + 2) {
            mdFail(`sangría no admitida en la continuación de un punto: «${l.trim().slice(0, 30)}»`);
          }
          rejectUnsupported(l.trim());
          last.text += ` ${l.trim()}`;
        } else if (startsBlock(l)) {
          break;
        } else {
          mdFail(`línea sin sangría tras una lista: «${l.slice(0, 30)}»`);
        }
        i++;
      }
      blocks.push(renderItems(items, 0, 0, gaps)[0]);
      continue;
    }

    const parts = [];
    while (i < lines.length && lines[i].trim() !== "" && !startsBlock(lines[i])) {
      rejectUnsupported(lines[i]);
      if (/^\s/.test(lines[i])) mdFail(`sangría inesperada: «${lines[i].trim().slice(0, 30)}»`);
      parts.push(lines[i].trim());
      i++;
    }
    blocks.push(`<p>${inline(parts.join(" "), gaps)}</p>`);
  }
  return { html: blocks.join("\n"), headings, gaps };
}

function renderItems(items, idx, indent, gaps) {
  const li = [];
  while (idx < items.length && items[idx].indent === indent) {
    let inner = inline(items[idx].text, gaps);
    idx++;
    if (idx < items.length && items[idx].indent > indent) {
      const [nested, next] = renderItems(items, idx, items[idx].indent, gaps);
      inner += `\n${nested}`;
      idx = next;
    }
    li.push(`<li>${inner}</li>`);
  }
  return [`<ul>\n${li.join("\n")}\n</ul>`, idx];
}

// ─── La política ─────────────────────────────────────────────────────────────────────────────────

const ES_START = "# Política de privacidad (ES)";
const EN_START = "# Privacy policy (EN)";
const NOTES_START = "## Notas para la revisión";

/**
 * Las dos partes publicadas de `privacy-policy.md`, en Markdown: de «# Política de privacidad (ES)»
 * a «# Privacy policy (EN)» y de ahí a las notas. La cabecera y las notas de revisión no se publican.
 */
export function extractPolicy(md) {
  const lines = norm(md).split("\n");
  const find = (needle, exact) => {
    const at = [];
    lines.forEach((l, i) => {
      if (exact ? l === needle : l.startsWith(needle)) at.push(i);
    });
    if (at.length === 0) throw new BuildError(`la política: no está la línea «${needle}»`);
    if (at.length > 1) throw new BuildError(`la política: «${needle}» aparece más de una vez`);
    return at[0];
  };
  const es = find(ES_START, true);
  const en = find(EN_START, true);
  const notes = find(NOTES_START, false);
  if (!(es < en && en < notes)) {
    throw new BuildError("la política: el orden tiene que ser español, inglés y notas de revisión");
  }
  const half = (from, to) =>
    lines
      .slice(from, to)
      .join("\n")
      .replace(/\n+---\s*$/, "")
      .trim();
  return { es: half(es, en), en: half(en, notes) };
}

/** Secciones `##` de una parte con lo que hay que mantener igual en las dos lenguas. */
function sectionSignatures(half) {
  const sections = [];
  let cur = null;
  const flush = () => {
    if (cur) sections.push(cur);
  };
  let block = [];
  const closeBlock = () => {
    if (!cur || block.length === 0) return;
    if (!block.every((l) => /^\s*- /.test(l))) cur.paragraphs++;
    block = [];
  };
  for (const line of half.split("\n")) {
    if (line.startsWith("## ")) {
      closeBlock();
      flush();
      cur = { title: line.slice(3).trim(), bullets: 0, paragraphs: 0, gaps: [], links: 0 };
      continue;
    }
    if (!cur) continue;
    if (line.trim() === "") {
      closeBlock();
      continue;
    }
    if (/^\s*- /.test(line)) cur.bullets++;
    block.push(line);
    for (const g of line.match(gapPattern()) ?? []) cur.gaps.push(gapKind(g));
    cur.links += (line.match(/\]\(https:/g) ?? []).length;
  }
  closeBlock();
  flush();
  return sections;
}

/** `[CONTACTO]` y `[CONTACT]` son el mismo hueco en las dos lenguas. */
function gapKind(g) {
  const word = g.replace(/[\[\]\s]/g, "").toUpperCase();
  return (
    { RESPONSABLE: "RESPONSABLE", CONTROLLER: "RESPONSABLE", CONTACTO: "CONTACTO", CONTACT: "CONTACTO", FECHA: "FECHA", DATE: "FECHA", WEB: "WEB", WEBSITE: "WEB" }[word] ?? word
  );
}

/**
 * CA-023-03: la parte española y la inglesa tienen las mismas secciones, en el mismo orden, y en cada
 * una los mismos puntos (viñetas, párrafos, enlaces y huecos). Devuelve la lista de diferencias.
 */
export function comparePolicyStructure(md) {
  const { es, en } = extractPolicy(md);
  const a = sectionSignatures(es);
  const b = sectionSignatures(en);
  const errors = [];
  if (a.length !== b.length) {
    errors.push(`la parte española tiene ${a.length} secciones y la inglesa ${b.length}`);
    return errors;
  }
  a.forEach((s, i) => {
    const t = b[i];
    const where = `sección ${i + 1} («${s.title}» / «${t.title}»)`;
    if (s.bullets !== t.bullets) {
      errors.push(`${where}: ${s.bullets} viñetas en español y ${t.bullets} en inglés`);
    }
    if (s.paragraphs !== t.paragraphs) {
      errors.push(`${where}: ${s.paragraphs} párrafos en español y ${t.paragraphs} en inglés`);
    }
    if (s.links !== t.links) {
      errors.push(`${where}: ${s.links} enlaces en español y ${t.links} en inglés`);
    }
    if (s.gaps.join(",") !== t.gaps.join(",")) {
      errors.push(`${where}: huecos de identidad distintos (${s.gaps.join(" ")} / ${t.gaps.join(" ")})`);
    }
  });
  return errors;
}

const DATE_LINE = {
  es: /^\*\*Última actualización:\*\*[ \t]*(.+)$/m,
  en: /^\*\*Last updated:\*\*[ \t]*(.+)$/m,
};

/**
 * El HTML de las dos partes de la política con el nombre de la app, la fecha de «última
 * actualización» de cada una (para el pie) y los huecos que dejan.
 */
export function policyFragments(md, appName) {
  const { es, en } = extractPolicy(md);
  const result = {};
  for (const [lang, half] of [["es", es], ["en", en]]) {
    const text = half.replaceAll("{appName}", appName);
    const converted = convertMarkdown(text, { shift: 1, firstHeadingAttrs: `id="${lang}" tabindex="-1"` });
    const date = DATE_LINE[lang].exec(text);
    if (!date) {
      throw new BuildError(
        `la política (${lang}): falta la línea «${lang === "es" ? "**Última actualización:**" : "**Last updated:**"}»`,
      );
    }
    result[lang] = { html: converted.html, gaps: converted.gaps, date: date[1].trim() };
  }
  return result;
}

// ─── Textos (strings.json) ───────────────────────────────────────────────────────────────────────

/** Las claves de `strings.json` y los marcadores que admite cada una (por idioma). */
const STRING_KEYS = {
  webHomeTitle: { es: ["appName"], en: ["appName"] },
  webHomeIntro: { es: [], en: [] },
  webPageTitle: { es: ["página", "appName"], en: ["page", "appName"] },
  webNotFoundTitle: { es: [], en: [] },
  webNotFoundBody: { es: [], en: [] },
  webContact: { es: [], en: [] },
  webLastUpdated: { es: ["fecha"], en: ["date"] },
  webBackHome: { es: [], en: [] },
  webLicensesVersion: { es: ["versión"], en: ["version"] },
  webLicensesLatestBuild: { es: [], en: [] },
  webLicensesInApp: { es: [], en: [] },
  webLanguageName: { es: [], en: [] },
};
const LANG_ONLY = { webSwitchToSpanish: { es: [] }, webSwitchToEnglish: { en: [] } };

export function loadStrings(text, label = "strings.json") {
  let json;
  try {
    json = JSON.parse(text);
  } catch (e) {
    throw new BuildError(`${label}: no es JSON válido (${e.message})`);
  }
  const top = Object.keys(json ?? {}).sort();
  if (top.join() !== "en,es") throw new BuildError(`${label}: tiene que tener solo «es» y «en» (tiene ${top.join(", ")})`);
  for (const lang of ["es", "en"]) {
    const spec = {};
    for (const [k, v] of Object.entries(STRING_KEYS)) spec[k] = v[lang];
    for (const [k, v] of Object.entries(LANG_ONLY)) if (v[lang]) spec[k] = v[lang];
    const obj = json[lang];
    for (const k of Object.keys(spec)) {
      if (typeof obj[k] !== "string") throw new BuildError(`${label}: falta «${lang}.${k}» (texto)`);
    }
    for (const [k, v] of Object.entries(obj)) {
      if (!(k in spec)) throw new BuildError(`${label}: «${lang}.${k}» no es una clave conocida`);
      for (const m of v.matchAll(/\{([^{}]*)\}/g)) {
        if (!spec[k].includes(m[1])) throw new BuildError(`${label}: «${lang}.${k}» lleva el marcador {${m[1]}}, que no admite`);
      }
    }
  }
  return json;
}

export function fill(template, values) {
  return template.replace(/\{([^{}]+)\}/g, (m, name) => {
    if (!(name in values)) throw new BuildError(`marcador sin valor: ${m}`);
    return values[name];
  });
}

// ─── CSS de los tokens ───────────────────────────────────────────────────────────────────────────

const REM = 16;
const num = (n) => String(Number(n.toFixed(4)));
const dim = (v, toRem) => {
  if (v.unit === "px") return toRem ? `${num(v.value / REM)}rem` : `${num(v.value)}px`;
  return `${num(v.value)}${v.unit}`;
};
const familyValue = (list) => list.map((f, i) => (i === 0 ? `"${f}"` : f)).join(", ");

/** Las fuentes que se publican: archivo, carpeta de `app/assets/fonts/` y peso (según los tokens). */
export const FONT_FILES = [
  { family: "display", dir: "archivo", file: "Archivo-Variable.ttf", weight: "range" },
  { family: "mono", dir: "space_mono", file: "SpaceMono-Regular.ttf", weight: "regular" },
  { family: "mono", dir: "space_mono", file: "SpaceMono-Bold.ttf", weight: "bold" },
];
export const FONT_DIRS = [...new Set(FONT_FILES.map((f) => f.dir))];

/** `tokens.css`: las variables de `design/tokens.json` (rem para texto y espacios) y las fuentes. */
export function tokensCss(tokens) {
  const vars = [];
  const emit = (name, value) => vars.push(`  --${name}: ${value};`);
  for (const [k, v] of Object.entries(tokens.color)) if (!k.startsWith("$")) emit(`color-${kebab(k)}`, v.$value);
  for (const [k, v] of Object.entries(tokens.font.family)) if (!k.startsWith("$")) emit(`font-family-${kebab(k)}`, familyValue(v.$value));
  for (const [k, v] of Object.entries(tokens.font.weight)) if (!k.startsWith("$")) emit(`font-weight-${kebab(k)}`, v.$value);
  for (const [k, v] of Object.entries(tokens.font.size)) if (!k.startsWith("$")) emit(`font-size-${kebab(k)}`, dim(v.$value, true));
  for (const [k, v] of Object.entries(tokens.font.letterSpacing)) if (!k.startsWith("$")) emit(`font-letter-spacing-${kebab(k)}`, dim(v.$value, false));
  for (const [k, v] of Object.entries(tokens.space)) if (!k.startsWith("$")) emit(`space-${kebab(k)}`, dim(v.$value, true));
  for (const [k, v] of Object.entries(tokens.size)) if (!k.startsWith("$")) emit(`size-${kebab(k)}`, dim(v.$value, true));
  for (const [k, v] of Object.entries(tokens.border.width)) if (!k.startsWith("$")) emit(`border-width-${kebab(k)}`, dim(v.$value, false));
  for (const [k, v] of Object.entries(tokens.border.radius)) if (!k.startsWith("$")) emit(`border-radius-${kebab(k)}`, dim(v.$value, false));

  const weights = Object.entries(tokens.font.weight).filter(([k]) => !k.startsWith("$")).map(([, v]) => v.$value);
  const faces = FONT_FILES.map((f) => {
    const family = tokens.font.family[f.family].$value[0];
    const weight =
      f.weight === "range" ? `${Math.min(...weights)} ${Math.max(...weights)}` : tokens.font.weight[f.weight].$value;
    return [
      "@font-face {",
      `  font-family: "${family}";`,
      `  src: url("/fonts/${f.dir}/${f.file}") format("truetype");`,
      `  font-weight: ${weight};`,
      "  font-display: swap;",
      "}",
    ].join("\n");
  });
  return [
    "/* Generado por landing/build.mjs desde design/tokens.json. No editar a mano. */",
    ...faces,
    ":root {",
    ...vars,
    "}",
    "",
  ].join("\n");
}

// ─── Páginas ─────────────────────────────────────────────────────────────────────────────────────

function shell({ title, h1, main, footer }) {
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>${esc(title)}</title>
<link rel="stylesheet" href="/tokens.css">
<link rel="stylesheet" href="/site.css">
</head>
<body>
<header>
<h1>${h1}</h1>
</header>
<main>
${main}
</main>
<footer>
${footer}
</footer>
</body>
</html>
`;
}

function loadSite(paths) {
  const identity = readIdentity(readText(paths.identity, "identity.yaml"), basename(paths.identity));
  const strings = loadStrings(readText(paths.strings, "strings.json"), basename(paths.strings));
  const tokens = JSON.parse(readText(paths.tokens, "tokens.json"));
  const arb = {};
  for (const [lang, path] of [["es", paths.arbEs], ["en", paths.arbEn]]) {
    const json = JSON.parse(readText(path, `app_${lang}.arb`));
    arb[lang] = {};
    for (const [key, name] of [["privacy", "settingsPrivacy"], ["licenses", "settingsThirdPartyLicenses"], ["help", "settingsHelp"]]) {
      if (typeof json[name] !== "string") throw new BuildError(`app_${lang}.arb: falta «${name}»`);
      arb[lang][key] = json[name];
    }
  }
  return { identity, strings, tokens, arb };
}

function bilingualH1(es, en) {
  return `<span lang="es">${esc(es)}</span> · <span lang="en">${esc(en)}</span>`;
}

function section(lang, s, body) {
  const link =
    lang === "es"
      ? `<p><a class="block-link" href="#en" lang="en">${esc(s.en.webSwitchToEnglish)}</a></p>`
      : `<p><a class="block-link" href="#es" lang="es">${esc(s.es.webSwitchToSpanish)}</a></p>`;
  return `<section lang="${lang}" aria-labelledby="${lang}">\n${link}\n${body}\n</section>`;
}

const langHeading = (lang, s) => `<h2 id="${lang}" tabindex="-1">${esc(s[lang].webLanguageName)}</h2>`;

function footer(s, { date = null, backHome = false } = {}) {
  return ["es", "en"]
    .map((lang) => {
      const rows = [`<p>${esc(s[lang].webContact)}</p>`];
      if (date) rows.push(`<p>${esc(fill(s[lang].webLastUpdated, { [lang === "es" ? "fecha" : "date"]: date[lang] }))}</p>`);
      if (backHome) rows.push(`<p><a class="block-link" href="/">${esc(s[lang].webBackHome)}</a></p>`);
      return `<div lang="${lang}">\n${rows.join("\n")}\n</div>`;
    })
    .join("\n");
}

function pageTitle(s, name, es, en) {
  return `${fill(s.es.webPageTitle, { página: es, appName: name })} / ${fill(s.en.webPageTitle, { page: en, appName: name })}`;
}

/**
 * Todas las páginas en memoria: `files` (ruta de salida → contenido) y `meta` (de cada página, el
 * `<title>` y el `<h1>` que le tocan según las ARB, la identidad y `strings.json`).
 */
export function renderSite(paths) {
  const { identity, strings: s, tokens, arb } = loadSite(paths);
  const name = identity.displayName;
  const files = new Map();
  const meta = new Map();
  const page = (file, spec) => {
    meta.set(file, { title: spec.title, h1: spec.h1 });
    files.set(file, shell(spec));
  };

  // Inicio.
  const homeTitle = fill(s.es.webHomeTitle, { appName: name });
  const links = (lang) =>
    ["privacy", "licenses", "help"]
      .map((k) => `<li><a class="block-link" href="/${k}">${esc(arb[lang][k])}</a></li>`)
      .join("\n");
  const homeBody = (lang) =>
    `${langHeading(lang, s)}\n<p>${esc(s[lang].webHomeIntro)}</p>\n<ul class="links">\n${links(lang)}\n</ul>`;
  page("index.html", {
    title: homeTitle,
    h1: esc(homeTitle),
    main: `${section("es", s, homeBody("es"))}\n${section("en", s, homeBody("en"))}`,
    footer: footer(s),
  });

  // Política: el texto es el de docs/legal/privacy-policy.md (CA-023-04).
  const policy = policyFragments(readText(paths.policy, "privacy-policy.md"), name);
  page("privacy/index.html", {
    title: pageTitle(s, name, arb.es.privacy, arb.en.privacy),
    h1: bilingualH1(arb.es.privacy, arb.en.privacy),
    main: `${section("es", s, policy.es.html)}\n${section("en", s, policy.en.html)}`,
    footer: footer(s, { date: { es: policy.es.date, en: policy.en.date }, backHome: true }),
  });

  // Error (CL-023-6).
  const notFound = (lang) =>
    `${langHeading(lang, s)}\n<p>${esc(s[lang].webNotFoundBody)}</p>\n<p><a class="block-link" href="/">${esc(s[lang].webBackHome)}</a></p>`;
  page("404.html", {
    title: pageTitle(s, name, s.es.webNotFoundTitle, s.en.webNotFoundTitle),
    h1: bilingualH1(s.es.webNotFoundTitle, s.en.webNotFoundTitle),
    main: `${section("es", s, notFound("es"))}\n${section("en", s, notFound("en"))}`,
    footer: footer(s),
  });

  files.set("tokens.css", tokensCss(tokens));
  files.set("site.css", readText(paths.siteCss, "site.css"));
  return { files, meta };
}

/** Los huecos de identidad que quedan en lo que se publica, por archivo. */
function findGaps(files) {
  const found = [];
  for (const [file, content] of files) {
    if (!file.endsWith(".html")) continue;
    const text = content.replace(/<[^>]*>/g, " ");
    const kinds = new Set(text.match(gapPattern()) ?? []);
    for (const g of kinds) found.push({ file, gap: g });
  }
  return found;
}

/**
 * Construye la web en `paths.out`. Con `VERCEL_ENV=production` un hueco de identidad hace fallar la
 * construcción (así la integración Git de Vercel no puede publicar una web a medias); en cualquier
 * otro entorno es un aviso. Devuelve los avisos.
 */
export function build(paths = defaultPaths(), { env = process.env } = {}) {
  if (basename(paths.out) !== "dist") {
    throw new BuildError(`la carpeta de salida tiene que llamarse «dist» (es «${paths.out}»): no se borra otra`);
  }
  const { files } = renderSite(paths);
  const gaps = findGaps(files);
  const warnings = gaps.map((g) => `aviso: hueco de identidad ${g.gap} en ${g.file} (se rellena en F6)`);
  if (env.VERCEL_ENV === "production" && gaps.length > 0) {
    throw new BuildError(
      `no se publica con huecos de identidad (VERCEL_ENV=production): ${gaps.map((g) => `${g.gap} en ${g.file}`).join("; ")}`,
    );
  }

  // Las fuentes, con su licencia, dentro de la web (CA-023-14).
  const copies = [];
  for (const dir of FONT_DIRS) {
    const names = [...FONT_FILES.filter((f) => f.dir === dir).map((f) => f.file), "OFL.txt"];
    for (const file of names) {
      const from = join(paths.fontsDir, dir, file);
      if (!existsSync(from)) throw new BuildError(`falta la fuente ${from}`);
      copies.push([from, join(paths.out, "fonts", dir, file)]);
    }
  }

  rmSync(paths.out, { recursive: true, force: true });
  for (const [file, content] of files) {
    const target = join(paths.out, file);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, content);
  }
  for (const [from, to] of copies) {
    mkdirSync(dirname(to), { recursive: true });
    cpSync(from, to);
  }
  return { warnings, files: [...files.keys(), ...copies.map(([, to]) => to.slice(paths.out.length + 1))] };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const { warnings, files } = build();
    for (const w of warnings) console.warn(w);
    console.log(`Web construida en landing/dist (${files.length} archivos).`);
  } catch (e) {
    if (!(e instanceof BuildError)) throw e;
    console.error(`error: ${e.message}`);
    process.exit(1);
  }
}
