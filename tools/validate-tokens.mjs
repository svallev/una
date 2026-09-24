#!/usr/bin/env node
// Valida design/tokens.json: estructura mínima, formato de colores y contraste WCAG AA
// de las combinaciones de texto documentadas en docs/design/tokens.md.
// Uso: node tools/validate-tokens.mjs   (sin dependencias)
import { readFileSync } from "node:fs";

const tokens = JSON.parse(readFileSync(new URL("../design/tokens.json", import.meta.url), "utf8"));
const errors = [];

const required = ["color", "palette", "font", "space", "size", "border", "shadow", "motion"];
for (const g of required) if (!tokens[g]) errors.push(`Falta el grupo "${g}"`);

const hex = (v) => {
  const m = /^#([0-9a-f]{6})$/i.exec(v);
  if (!m) return null;
  return [0, 2, 4].map((i) => parseInt(m[1].slice(i, i + 2), 16));
};
const rgba = (v) => {
  const m = /^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$/.exec(v);
  return m ? { rgb: [+m[1], +m[2], +m[3]], a: +m[4] } : null;
};
const lum = ([r, g, b]) => {
  const f = (c) => ((c /= 255) <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
};
const ratio = (a, b) => {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
};
const blend = ({ rgb, a }, bg) => rgb.map((c, i) => Math.round(c * a + bg[i] * (1 - a)));

// 1. Formato de todos los colores
const walk = (obj, path = []) => {
  for (const [k, v] of Object.entries(obj)) {
    if (k.startsWith("$")) continue;
    if (v && typeof v === "object" && "$value" in v) {
      const val = v.$value;
      if (typeof val === "string" && val.startsWith("#") && !hex(val)) errors.push(`Color no válido en ${[...path, k].join(".")}: ${val}`);
      if (typeof val === "string" && val.startsWith("rgba") && !rgba(val)) errors.push(`rgba no válido en ${[...path, k].join(".")}: ${val}`);
    } else if (v && typeof v === "object") walk(v, [...path, k]);
  }
};
walk(tokens);

// 2. Paletas con 5 colores (colorKey 0..4)
for (const [name, pal] of Object.entries(tokens.palette ?? {})) {
  if (name.startsWith("$")) continue;
  for (let i = 0; i < 5; i++) if (!pal[i] || !hex(pal[i].$value)) errors.push(`palette.${name}.${i} falta o no es hex`);
}

// 3. Contraste AA (4.5:1) de texto
const C = tokens.color;
const ink = hex(C.ink.$value);
const checks = [
  ["ink/paper", ink, hex(C.paper.$value)],
  ["textMuted/paper", hex(C.textMuted.$value), hex(C.paper.$value)],
  ["textMuted/surface", hex(C.textMuted.$value), hex(C.surface.$value)],
  ["error/paper", hex(C.error.$value), hex(C.paper.$value)],
  ["error/surface", hex(C.error.$value), hex(C.surface.$value)],
  ["ink/dangerFill", ink, hex(C.dangerFill.$value)],
  ["onInk/ink", hex(C.onInk.$value), ink],
];
const ph = rgba(C.placeholder.$value);
for (const [name, pal] of Object.entries(tokens.palette)) {
  if (name.startsWith("$")) continue;
  for (let i = 0; i < 5; i++) {
    const bg = hex(pal[i].$value);
    checks.push([`ink/${name}.${i}`, ink, bg]);
    if (name === "classic") checks.push([`placeholder/${name}.${i}`, blend(ph, bg), bg]);
  }
}
checks.push(["placeholder/paper", blend(ph, hex(C.paper.$value)), hex(C.paper.$value)]);

for (const [name, fg, bg] of checks) {
  const r = ratio(fg, bg);
  if (r < 4.5) errors.push(`Contraste insuficiente ${name}: ${r.toFixed(2)} (< 4.5)`);
}

if (errors.length) {
  console.error("❌ tokens.json no es válido:\n - " + errors.join("\n - "));
  process.exit(1);
}
console.log(`✅ tokens.json válido (${checks.length} combinaciones de contraste AA comprobadas)`);
