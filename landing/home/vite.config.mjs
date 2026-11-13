// Construcción de la página de inicio (spec 025): la versión A de la maqueta. La lanza `landing/build.mjs` (por
// la API de Vite) después de escribir `gen/site.json`; no se usa sola. Sin `plugins`.
import { fileURLToPath } from "node:url";

const here = (path) => fileURLToPath(new URL(path, import.meta.url));

export default {
  root: here("."),
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
