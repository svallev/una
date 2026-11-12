// Servidor local de la web (spec 023, casillas C-023-2 a 4; spec 025): sirve `landing/dist/` con las mismas
// cabeceras de `vercel.json` (por ruta: «/» lleva la CSP de la página de inicio) y las reglas de
// `cleanUrls` / `404.html`, sin desplegar nada.
//
//   node landing/serve.mjs [--port 4173]      (después de `node landing/build.mjs`)
//
// Solo módulos de Node. Escucha únicamente en 127.0.0.1; rechaza un `Host` que no sea el suyo
// (DNS rebinding), todo método que no sea GET o HEAD y cualquier ruta que salga de `dist/`
// (`..`, `%2e%2e`, byte nulo, barras invertidas, enlaces simbólicos); nunca lista carpetas.
import { createServer } from "node:http";
import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import { extname, join, sep } from "node:path";
import { pathToFileURL } from "node:url";
import { defaultPaths } from "./build.mjs";

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  // Con `nosniff`, un módulo servido con otro tipo no se ejecuta (spec 025).
  ".js": "text/javascript; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".ttf": "font/ttf",
  ".woff2": "font/woff2",
  ".png": "image/png",
  ".svg": "image/svg+xml",
};

/** Qué rutas abarca cada `source` que sé servir (el resto hace fallar el arranque). */
const SOURCES = {
  "/(.*)": () => true,
  "/(.+)": (path) => path !== "/",
  "/": (path) => path === "/",
};

/**
 * Las reglas de cabeceras de `vercel.json` (falla cerrada con un `source` que no conoce). Devuelve una
 * función que da las cabeceras de una ruta: las de todas las reglas que la abarcan, en orden, como Vercel.
 */
function loadHeaders(vercelJson) {
  const json = JSON.parse(readFileSync(vercelJson, "utf8"));
  const rules = json.headers ?? [];
  if (rules.length === 0) throw new Error("vercel.json: no hay ninguna regla de cabeceras");
  for (const r of rules) {
    if (!(r.source in SOURCES)) {
      throw new Error(`vercel.json: no sé servir la regla de cabeceras con source "${r.source}" (solo ${Object.keys(SOURCES).join(", ")})`);
    }
  }
  return (path) => {
    const out = {};
    for (const r of rules) if (SOURCES[r.source](path)) for (const h of r.headers) out[h.key] = h.value;
    return out;
  };
}

/** Crea el servidor (sin ponerlo a escuchar). */
export function createLandingServer({ dist, vercelJson }) {
  if (!existsSync(dist) || !statSync(dist).isDirectory()) throw new Error(`dist/ no existe: ${dist}`);
  const root = realpathSync(dist);
  const headersFor = loadHeaders(vercelJson);

  /** El archivo que sirve [clean] (una ruta ya decodificada y sin `..`), o `null`. */
  function resolveFile(clean) {
    const base = join(root, ...clean.split("/").filter(Boolean));
    const candidates = clean.endsWith("/") || clean === "" ? [join(base, "index.html")] : [base, `${base}.html`, join(base, "index.html")];
    for (const c of candidates) {
      if (!existsSync(c)) continue;
      const real = realpathSync(c);
      if (real !== root && !real.startsWith(root + sep)) return null; // enlace simbólico a fuera
      if (statSync(real).isFile()) return real;
    }
    return null;
  }

  return createServer((req, res) => {
    // Las cabeceras dependen de la ruta pedida (sin la consulta): «/» lleva la CSP de la página de inicio.
    const headers = headersFor((req.url ?? "").split(/[?#]/)[0]);
    const send = (status, body, extra = {}) => {
      const data = Buffer.from(body);
      res.writeHead(status, { ...headers, "Content-Length": data.length, ...extra });
      res.end(data); // Node no escribe el cuerpo de una respuesta a HEAD
    };
    const port = req.socket.localPort;

    if (req.method !== "GET" && req.method !== "HEAD") {
      return send(405, "Método no permitido", { Allow: "GET, HEAD", "Content-Type": "text/plain; charset=utf-8" });
    }
    if (req.headers.host !== `127.0.0.1:${port}` && req.headers.host !== `localhost:${port}`) {
      return send(403, "Host no permitido", { "Content-Type": "text/plain; charset=utf-8" });
    }
    const raw = req.url ?? "";
    const bad = (why) => send(400, why, { "Content-Type": "text/plain; charset=utf-8" });
    if (!raw.startsWith("/")) return bad("Ruta no válida");
    const path = raw.split(/[?#]/)[0];
    let decoded;
    try {
      decoded = decodeURIComponent(path);
    } catch {
      return bad("Ruta no válida");
    }
    if (decoded.includes("\0") || decoded.includes("\\") || path.includes("\\")) return bad("Ruta no válida");
    if (decoded.split("/").some((s) => s === "..")) return bad("Ruta no válida");

    // cleanUrls y trailingSlash: false.
    if (/\/index\.html$/.test(decoded)) return send(308, "", { Location: decoded.replace(/index\.html$/, "").replace(/(.)\/$/, "$1") });
    if (decoded.endsWith(".html") && decoded !== "/404.html") return send(308, "", { Location: decoded.slice(0, -5) });
    if (decoded.length > 1 && decoded.endsWith("/")) return send(308, "", { Location: decoded.replace(/\/+$/, "") });

    const file = resolveFile(decoded === "/" ? "/" : decoded);
    if (file && !file.endsWith(`${sep}404.html`)) {
      return send(200, readFileSync(file), { "Content-Type": TYPES[extname(file)] ?? "application/octet-stream" });
    }
    const notFound = resolveFile("/404.html");
    return send(404, notFound ? readFileSync(notFound) : "No encontrado", {
      "Content-Type": notFound ? TYPES[".html"] : "text/plain; charset=utf-8",
    });
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const at = args.indexOf("--port");
  const port = at >= 0 ? Number(args[at + 1]) : 4173;
  const paths = defaultPaths();
  const server = createLandingServer({ dist: paths.out, vercelJson: paths.vercelJson });
  server.listen(port, "127.0.0.1", () => {
    console.log(`Sirviendo landing/dist en http://127.0.0.1:${server.address().port}/ (Ctrl+C para parar)`);
  });
}
