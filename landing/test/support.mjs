// Ayudas de los tests de la web (spec 023). No es un test: no acaba en `.test.mjs`.
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { build, defaultPaths } from "../build.mjs";

/**
 * Un mundo de prueba: copias en una carpeta temporal de lo que los tests modifican (la identidad, la
 * política, `landing/src/` entera, el archivo de avisos, `build.mjs` y `vercel.json`) y la salida en `dist/` temporal. El
 * resto (tokens, ARB, fuentes) se lee del repositorio.
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
    buildFile: join(dir, "build.mjs"),
    vercelJson: join(dir, "vercel.json"),
    out: join(dir, "dist"),
  };
  cpSync(real.identity, paths.identity);
  cpSync(real.policy, paths.policy);
  cpSync(real.notices, paths.notices);
  cpSync(real.buildFile, paths.buildFile);
  cpSync(real.vercelJson, paths.vercelJson);
  return {
    dir,
    paths,
    dist: paths.out,
    /** Construye (sin `VERCEL_ENV`) y devuelve el resultado de `build`. */
    build: (env = {}) => build(paths, { env }),
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
