// Construcción de la página de inicio (spec 025, plan §2). La lanza `landing/build.mjs` (por la API de Vite)
// después de escribir `gen/`; no se usa sola. Sin `plugins` (lo exige un test, plan §6.1).
//
// La raíz es `gen/` porque Vite escribe el HTML en `dist/` con la misma ruta relativa a la raíz: con la raíz
// en `home/`, `gen/index.html` acabaría en `dist/gen/index.html`.
import { fileURLToPath } from "node:url";

const here = (path) => fileURLToPath(new URL(path, import.meta.url));

export default {
  root: here("./gen"),
  publicDir: here("./public"),
  base: "/",
  logLevel: "warn",
  clearScreen: false,
  build: {
    outDir: here("../dist"),
    // `build.mjs` ya vació `dist/` y escribió en ella las otras cuatro páginas.
    emptyOutDir: false,
    sourcemap: false,
    // Sin `data:` en lo publicado: cada recurso, su archivo.
    assetsInlineLimit: 0,
    // El relleno de `modulepreload` hace un `fetch` (CA-025-12).
    modulePreload: { polyfill: false },
    rolldownOptions: {
      // La licencia de GSAP prohíbe quitar sus avisos: se conservan sus comentarios `/*! … @license … */`.
      output: { comments: { legal: true, annotation: false, jsdoc: false } },
    },
  },
};
