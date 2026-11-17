// Ayudas de los tests de la web (spec 023). No es un test: no acaba en `.test.mjs`.
import { cpSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { build, buildHome, defaultPaths } from "../build.mjs";

/**
 * Un mundo de prueba: copias en una carpeta temporal de lo que los tests modifican (la identidad, la
 * política, `landing/src/` entera, los dos archivos de avisos, `build.mjs` y `vercel.json`) y la salida en `dist/` temporal. El
 * resto (tokens, ARB, fuentes) se lee del repositorio. La página de inicio (spec 025) se construye aparte, con
 * `buildHome` (Vite, asíncrona): el mundo lleva una copia de `landing/home/` sin `gen/`, un enlace a
 * `landing/node_modules/`, para que Vite encuentre las dependencias, y `landing/package.json`.
 */
export function world() {
  const real = defaultPaths();
  const dir = mkdtempSync(join(tmpdir(), "landing-test-"));
  const srcDir = join(dir, "src");
  cpSync(real.srcDir, srcDir, { recursive: true });
  const paths = {
    ...real,
    identity: join(dir, "identity.yaml"),
    policy: join(dir, "privacy-policy.md"),
    srcDir,
    strings: join(srcDir, "strings.json"),
    siteCss: join(srcDir, "site.css"),
    helpEs: join(srcDir, "help.es.md"),
    helpEn: join(srcDir, "help.en.md"),
    notices: join(dir, "third-party-notices.txt"),
    webNotices: join(dir, "web-notices.txt"),
    buildFile: join(dir, "build.mjs"),
    vercelJson: join(dir, "vercel.json"),
    out: join(dir, "dist"),
  };
  cpSync(real.identity, paths.identity);
  cpSync(real.policy, paths.policy);
  cpSync(real.notices, paths.notices);
  cpSync(real.webNotices, paths.webNotices);
  cpSync(real.buildFile, paths.buildFile);
  cpSync(real.vercelJson, paths.vercelJson);
  paths.homeDir = join(dir, "home");
  cpSync(real.homeDir, paths.homeDir, {
    recursive: true,
    filter: (from) => !(from === join(real.homeDir, "gen") || basename(from) === ".DS_Store"),
  });
  symlinkSync(join(real.landingDir, "node_modules"), join(dir, "node_modules"), "dir");
  // `build.mjs` importa los módulos de `home/src/` (`fillHomePage`): `"type": "module"`, como en `landing/`.
  cpSync(join(real.landingDir, "package.json"), join(dir, "package.json"));
  return {
    dir,
    paths,
    dist: paths.out,
    /** Construye (sin `VERCEL_ENV`) y devuelve el resultado de `build`. */
    build: (env = {}) => build(paths, { env }),
    /** Construye la página de inicio con Vite (después de `build`). */
    buildHome: () => buildHome(paths),
    cleanup: () => rmSync(dir, { recursive: true, force: true }),
  };
}

/** Reescribe [file] con lo que devuelve [fn] sobre su texto; falla si no cambia nada. */
export function edit(file, fn) {
  const before = readFileSync(file, "utf8");
  const after = fn(before);
  if (after === before) throw new Error(`la edición no cambió nada en ${file}`);
  writeFileSync(file, after);
}

export const read = (file) => readFileSync(file, "utf8");

/**
 * Una copia de [world] ya construida: el estado "bueno" se construye una vez y cada caso trabaja
 * sobre su propia copia, para no mezclar mutaciones.
 */
export function cloneWorld(base) {
  const dir = mkdtempSync(join(tmpdir(), "landing-test-"));
  cpSync(base.dir, dir, { recursive: true });
  const paths = Object.fromEntries(
    Object.entries(base.paths).map(([key, value]) => [
      key,
      typeof value === "string" && value.startsWith(base.dir) ? value.replace(base.dir, dir) : value,
    ]),
  );
  return {
    dir,
    paths,
    dist: paths.out,
    build: (env = {}) => build(paths, { env }),
    buildHome: () => buildHome(paths),
    cleanup: () => rmSync(dir, { recursive: true, force: true }),
  };
}

/**
 * Los errores de la comprobación sin el general de «lo publicado no coincide con lo que construyen las
 * fuentes»: así cada regla se prueba por sí sola y no la tapa ese aviso.
 */
export function specificErrors(errors) {
  return errors.filter((e) => !e.includes("no coincide con lo que construye la web"));
}

/** Los dos encabezados válidos del archivo de avisos (CA-023-16). */
export const HEADER_VERSION = "Versión: 1.2.3+4";
export const HEADER_BUILD =
  "Compilación de main: 2e835cf9e1d8e1c7e203c90426f28f66e7ba4181 (trabajo de publicación, modo testers, ejecución 38874734623)";

/** Un archivo de avisos de prueba, pequeño, con la cabecera [header] y [body] (el del artefacto). */
export const fakeNotices = (header = HEADER_BUILD, body = "Third-party notices\nVersion: 0.0.0+0\n\nLicencia de prueba.\n") =>
  `${header}\n\n${body}`;

/** La mitad [lang] (`es` o `en`) de una página construida: de su `<section class="half">` a su cierre. */
export function halfOf(html, lang) {
  const from = html.indexOf(`<section class="half" lang="${lang}"`);
  if (from < 0) throw new Error(`no está la mitad «${lang}»`);
  return html.slice(from, html.indexOf("</section>", from));
}

/**
 * El índice de la mitad [lang] (spec 026, CA-026-04): dónde empiezan el `<h2>`, la fecha, el índice y la primera
 * sección; los enlaces del índice (`href` y texto) y las secciones (`<h3>`: `id`, `tabindex` y texto).
 */
export function tocOf(html, lang) {
  const half = halfOf(html, lang);
  const strip = (s) => s.replace(/<[^>]*>/g, "");
  const nav = /<nav class="toc" aria-labelledby="([^"]*)">([\s\S]*?)<\/nav>/.exec(half);
  return {
    half,
    h2At: half.indexOf(`<h2 id="${lang}"`),
    dateAt: half.indexOf('<p class="date">'),
    navAt: nav ? nav.index : -1,
    firstH3At: half.indexOf("<h3"),
    navCount: half.split('<nav class="toc"').length - 1,
    labelledby: nav?.[1],
    name: nav ? /<p id="([^"]*)" class="toc__name">([^<]*)<\/p>/.exec(nav[2]) : null,
    links: nav ? [...nav[2].matchAll(/<a href="([^"]*)">([\s\S]*?)<\/a>/g)].map((m) => ({ href: m[1], text: strip(m[2]) })) : [],
    sections: [...half.matchAll(/<h3([^>]*)>([\s\S]*?)<\/h3>/g)].map((m) => ({
      id: /\bid="([^"]*)"/.exec(m[1])?.[1],
      tabindex: /\btabindex="([^"]*)"/.exec(m[1])?.[1],
      text: strip(m[2]),
    })),
  };
}

/** Todos los `id` de una página construida. */
export const idsOf = (html) => [...html.matchAll(/\sid="([^"]*)"/g)].map((m) => m[1]);
