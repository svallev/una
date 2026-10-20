// Ayudas de los tests de la web (spec 023). No es un test: no acaba en `.test.mjs`.
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { build, defaultPaths } from "../build.mjs";

/**
 * Un mundo de prueba: copias en una carpeta temporal de lo que los tests modifican (la identidad, la
 * política, `landing/src/` entera, `build.mjs` y `vercel.json`) y la salida en `dist/` temporal. El
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
    buildFile: join(dir, "build.mjs"),
    vercelJson: join(dir, "vercel.json"),
    out: join(dir, "dist"),
  };
  cpSync(real.identity, paths.identity);
  cpSync(real.policy, paths.policy);
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
