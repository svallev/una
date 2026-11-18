// Lo que la comprobación de la ficha comparte con la web (spec 023): leer la identidad y la política,
// los huecos de identidad y el nombre escrito a mano. Copiado tal cual de `landing/build.mjs` y
// `landing/check.mjs` cuando la web salió a su propio repositorio (svallev/una-web, ADR-0029).

export class BuildError extends Error {}

const norm = (text) => text.replace(/\r\n?/g, "\n");

const GAP_WORDS = "RESPONSABLE|CONTROLLER|CONTACTO|CONTACT|FECHA|DATE|WEB|WEBSITE";
export const gapPattern = () => new RegExp(`\\[\\s*(?:${GAP_WORDS})\\s*\\]`, "gi");

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

const ES_START = "# Política de privacidad (ES)";
const EN_START = "# Privacy policy (EN)";
const NOTES_START = "## Notas para la revisión";

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

const literal = (name) =>
  new RegExp(`(?<![\\p{L}\\p{N}_])${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?![\\p{L}\\p{N}_])`, "u");

const beforeSentenceStart = /(?:^|[.!?¿¡:…]|\\n)\s*(?:[-*>#]+\s+)?["'«(\-—]*\s*$/u;

const followedByMoreText = /^\s+[\p{L}{]/u;

export function mentionsName(line, name) {
  const bareWord = /\p{L}$/u.test(name);
  const all = new RegExp(literal(name).source, "gu");
  for (const m of line.matchAll(all)) {
    const article = bareWord
      && beforeSentenceStart.test(line.slice(0, m.index))
      && followedByMoreText.test(line.slice(m.index + m[0].length));
    if (!article) return true;
  }
  return false;
}
