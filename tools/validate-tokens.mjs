#!/usr/bin/env node
// Valida design/tokens.json: estructura mínima, formato de colores, contraste WCAG AA
// de las combinaciones de texto (4,5:1) y de los elementos no textuales (3:1, WCAG 1.4.11)
// documentadas en docs/design/tokens.md.
// Uso: node tools/validate-tokens.mjs [--tokens <archivo>]   (sin dependencias)
//   --tokens: valida otro archivo (para probar con una copia modificada que el validador falla).
import { readFileSync } from "node:fs";

const argTokens = process.argv.indexOf("--tokens");
const tokensUrl = argTokens > 0 ? process.argv[argTokens + 1] : new URL("../design/tokens.json", import.meta.url);
const tokens = JSON.parse(readFileSync(tokensUrl, "utf8"));
const errors = [];

const required = ["color", "palette", "landing", "font", "space", "size", "border", "shadow", "motion"];
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
  // Etiqueta de la tarea en la card de deshacer (spec 014, CA-014-03).
  ["onInkMuted/ink", hex(C.onInkMuted.$value), ink],
  // Ajustes (spec 015, CA-015-19): subtítulo del interruptor y línea inferior de "Como el
  // sistema" (textMuted/paper, ya arriba) y texto de los avisos de error (error/paper, ya arriba).
];
// 4. Contraste no textual (3:1, WCAG 1.4.11): la barra de tiempo de la card de deshacer
//    es del color de la nota eliminada y se vacía sobre su pista (spec 014, CA-014-03).
//    Se comprueban todas las paletas (la activa, classic, y las de futuro theming).
const nonTextChecks = [];
const undoTrack = hex(C.undoTrack.$value);
const ph = rgba(C.placeholder.$value);
for (const [name, pal] of Object.entries(tokens.palette)) {
  if (name.startsWith("$")) continue;
  for (let i = 0; i < 5; i++) {
    const bg = hex(pal[i].$value);
    checks.push([`ink/${name}.${i}`, ink, bg]);
    if (name === "classic") checks.push([`placeholder/${name}.${i}`, blend(ph, bg), bg]);
    nonTextChecks.push([`${name}.${i}/undoTrack`, bg, undoTrack]);
  }
}
checks.push(["placeholder/paper", blend(ph, hex(C.paper.$value)), hex(C.paper.$value)]);

// 4b. Interruptor de Ajustes (spec 015, CA-015-03 y CA-015-19; WCAG 1.4.11, ≥ 3:1). El estado
//     lo da la posición del pomo; el amarillo `switchOn` contra el papel (~1,2:1) no distingue
//     nada ni se le exige contraste. Lo que contrasta es el borde de tinta, en los dos estados:
//     (a) borde de la pista (ink) frente al papel de la pantalla;
//     (b) borde del pomo (ink) frente al relleno de la pista: papel (apagado) y switchOn (encendido).
const paper = hex(C.paper.$value);
const switchOn = hex(C.switchOn.$value);
nonTextChecks.push(["switch/borde de la pista (ink) / papel", ink, paper]);
nonTextChecks.push(["switch/borde del pomo (ink) / pista apagada (papel)", ink, paper]);
nonTextChecks.push(["switch/borde del pomo (ink) / pista encendida (switchOn)", ink, switchOn]);
// Marca de selección de la página de Idioma (CA-015-07): ink sobre el papel.
nonTextChecks.push(["marca de selección (ink) / papel", ink, paper]);

// 4c. Varias imágenes (spec 016, CA-016-06 y CA-016-22; WCAG 1.4.1, 1.4.3 y 1.4.11).
//     (a) Etiqueta "{n} fotos" de la pila: blanco sobre tinta, texto, ≥ 4,5:1 sea cual sea la foto.
//     (b) Puntos del carrusel (borde de tinta, relleno de tinta o blanco, halo blanco por fuera):
//         el borde contra el papel y la superficie (≥ 3:1) y contra el halo (se distinguen entre
//         sí), y el halo debe existir. Sobre una foto cualquiera, la tinta o el halo llegan a
//         ≥ 3:1 contra **cualquier gris** (el peor caso, ≈ 4,3:1, es un gris medio de luminancia
//         ≈ 0,19): se recorren los 256 grises.
const dotInk = hex(C.photoDotInk.$value);
const dotLight = hex(C.photoDotLight.$value);
const dotHalo = hex(C.photoDotHalo.$value);
checks.push(["etiqueta de la pila (photoCountText/photoCountFill)", hex(C.photoCountText.$value), hex(C.photoCountFill.$value)]);
nonTextChecks.push(["punto/borde de tinta / papel", dotInk, paper]);
nonTextChecks.push(["punto/borde de tinta / superficie", dotInk, hex(C.surface.$value)]);
nonTextChecks.push(["punto/borde de tinta / halo", dotInk, dotHalo]);
nonTextChecks.push(["punto/relleno de tinta / relleno claro", dotInk, dotLight]);
if (!((tokens.border?.width?.photoDotHalo?.$value?.value ?? 0) > 0)) {
  errors.push("Falta el halo de los puntos (border.width.photoDotHalo > 0): sin él, el punto no se ve sobre una foto negra");
}
let worstGray = Infinity;
for (let g = 0; g <= 255; g++) {
  worstGray = Math.min(worstGray, Math.max(ratio(dotInk, [g, g, g]), ratio(dotHalo, [g, g, g])));
}
if (worstGray < 3) errors.push(`Contraste no textual insuficiente de los puntos sobre un gris: ${worstGray.toFixed(2)} (< 3)`);

// 4d. Notificaciones en Ajustes (spec 019, CA-019-26 y CA-019-03). Sin token nuevo: se declaran
//     aquí los pares que ya existían para que un cambio de color los rompa con su nombre.
//     Texto (≥ 4,5:1): la línea de privacidad, la ayuda con las horas y el aviso de bloqueo van
//     en textMuted sobre el papel (como CA-017-15); el botón de enlace («Abrir los ajustes de
//     notificaciones») y el número de la opción marcada son tinta (este sobre el amarillo del
//     relleno, `switchOn`, que no cuenta para distinguir el estado: ≈ 1,2:1 contra el papel).
//     No textual (≥ 3:1, WCAG 1.4.1 y 1.4.11): la marca de selección (la misma de Idioma, tinta)
//     contra los dos fondos posibles, el relleno amarillo de la marcada y el papel de las demás.
const textMuted = hex(C.textMuted.$value);
checks.push(["notificaciones/línea de privacidad (textMuted/paper)", textMuted, paper]);
checks.push(["notificaciones/ayuda con las horas (textMuted/paper)", textMuted, paper]);
checks.push(["notificaciones/aviso de bloqueo (textMuted/paper)", textMuted, paper]);
checks.push(["notificaciones/botón de enlace (ink/paper)", ink, paper]);
checks.push(["notificaciones/número de la opción marcada (ink/switchOn)", ink, switchOn]);
nonTextChecks.push(["opciones al día/marca de selección (ink) / relleno de la opción marcada (switchOn)", ink, switchOn]);
nonTextChecks.push(["opciones al día/marca de selección (ink) / papel de las demás opciones", ink, paper]);

// 4e. Página de inicio de la web (spec 025, CA-025-14 y CA-025-15; plan §6.2). Los cuatro fondos de
//     `landing` con lo que va encima en cada escena:
//     - texto (≥ 4,5:1): paper sobre los magentas (entradillas, «Muy pronto», notas, pie) e ink sobre
//       orange y yellow;
//     - titular (texto grande, ≥ 3:1): la palabra destacada, palette.classic.0 sobre los magentas y
//       landing.magenta sobre yellow;
//     - no textual (≥ 3:1, WCAG 1.4.11): el anillo de foco (paper sobre los magentas, ink sobre orange
//       y yellow) y los bordes de tinta (rótulos de las tiendas, móviles) sobre los cuatro fondos.
//     **Una sola salvedad, con nombre** (propietario, 2026-11-13, sin excepción de P6): la palabra
//     destacada paperFiber sobre orange (escenas 2 y 5), 2,31:1. No hace fallar; si algún día llega a
//     3:1, sí falla, para que se quite de aquí. Cualquier otro par por debajo, falla.
const largeTextChecks = [];
const knownShortfalls = [];
const landing = tokens.landing ?? {};
const landingColor = (key) => {
  const value = hex(landing[key]?.$value ?? "");
  if (!value) errors.push(`Falta el color landing.${key} (o no es hex)`);
  return value;
};
const magenta = landingColor("magenta");
const magentaDeep = landingColor("magentaDeep");
const orange = landingColor("orange");
const yellow = landingColor("yellow");
const note = hex(tokens.palette?.classic?.[0]?.$value ?? "");
const fiber = hex(C.paperFiber.$value);
if (magenta && magentaDeep && orange && yellow && note) {
  for (const [bgName, bg] of [["magenta", magenta], ["magentaDeep", magentaDeep]]) {
    checks.push([`landing/texto (paper) / ${bgName}`, paper, bg]);
    largeTextChecks.push([`landing/palabra destacada (palette.classic.0) / ${bgName}`, note, bg]);
    nonTextChecks.push([`landing/anillo de foco (paper) / ${bgName}`, paper, bg]);
  }
  for (const [bgName, bg] of [["orange", orange], ["yellow", yellow]]) {
    checks.push([`landing/texto (ink) / ${bgName}`, ink, bg]);
    nonTextChecks.push([`landing/anillo de foco (ink) / ${bgName}`, ink, bg]);
  }
  for (const [bgName, bg] of [["magenta", magenta], ["magentaDeep", magentaDeep], ["orange", orange], ["yellow", yellow]]) {
    nonTextChecks.push([`landing/borde de tinta (ink) / ${bgName}`, ink, bg]);
  }
  largeTextChecks.push(["landing/palabra destacada (landing.magenta) / yellow", magenta, yellow]);
  knownShortfalls.push(["landing/palabra destacada (paperFiber) / orange", fiber, orange, 3]);
}

for (const [name, fg, bg] of checks) {
  const r = ratio(fg, bg);
  if (r < 4.5) errors.push(`Contraste insuficiente ${name}: ${r.toFixed(2)} (< 4.5)`);
}
for (const [name, fg, bg] of largeTextChecks) {
  const r = ratio(fg, bg);
  if (r < 3) errors.push(`Contraste insuficiente (texto grande) ${name}: ${r.toFixed(2)} (< 3)`);
}
const shortfallNotes = [];
for (const [name, fg, bg, min] of knownShortfalls) {
  const r = ratio(fg, bg);
  if (r >= min) {
    errors.push(`La salvedad ${name} ya no hace falta (${r.toFixed(2)} ≥ ${min}): quítala de validate-tokens y de docs/design/tokens.md`);
  } else {
    shortfallNotes.push(`${name}: ${r.toFixed(2)} (< ${min}), salvedad aceptada (spec 025, CA-025-15)`);
  }
}
for (const [name, fg, bg] of nonTextChecks) {
  const r = ratio(fg, bg);
  if (r < 3) errors.push(`Contraste no textual insuficiente ${name}: ${r.toFixed(2)} (< 3)`);
}

if (errors.length) {
  console.error("❌ tokens.json no es válido:\n - " + errors.join("\n - "));
  process.exit(1);
}
console.log(
  `✅ tokens.json válido (${checks.length} combinaciones de contraste AA de texto, ` +
    `${largeTextChecks.length} de texto grande y ${nonTextChecks.length} no textuales comprobadas)`,
);
for (const n of shortfallNotes) console.log(`   salvedad: ${n}`);
