// El servidor local de la web (spec 023, CA-023-13/14, casillas C-023-2 a 4): imita Vercel con las
// mismas cabeceras y no deja salir de dist/ ni responder a un Host ajeno.
import assert from "node:assert/strict";
import { mkdirSync, symlinkSync, writeFileSync } from "node:fs";
import net from "node:net";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { createLandingServer } from "../serve.mjs";
import { read, world } from "./support.mjs";

let w;
let server;
let port;

before(async () => {
  w = world();
  w.build();
  // Fuera de dist/ hay un secreto que nunca puede salir.
  writeFileSync(join(w.dir, "secret.txt"), "SECRETO-FUERA-DE-DIST");
  mkdirSync(join(w.dir, "outside"));
  writeFileSync(join(w.dir, "outside/inside.txt"), "SECRETO-DE-OTRA-CARPETA");
  symlinkSync(join(w.dir, "secret.txt"), join(w.dist, "enlace.txt"));
  symlinkSync(join(w.dir, "outside"), join(w.dist, "enlace-carpeta"));
  server = createLandingServer({ dist: w.dist, vercelJson: w.paths.vercelJson });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  port = server.address().port;
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
  w.cleanup();
});

/** Una petición HTTP/1.1 a mano (control total de la línea de petición y del Host). */
function raw(requestLine, { host = `127.0.0.1:${port}`, extra = "" } = {}) {
  return new Promise((resolve, reject) => {
    const socket = net.connect(port, "127.0.0.1");
    let data = "";
    socket.setEncoding("utf8");
    socket.on("data", (c) => (data += c));
    socket.on("error", reject);
    socket.on("close", () => {
      const [head, ...rest] = data.split("\r\n\r\n");
      const [statusLine, ...headerLines] = head.split("\r\n");
      const headers = {};
      for (const l of headerLines) {
        const i = l.indexOf(":");
        headers[l.slice(0, i).toLowerCase()] = l.slice(i + 1).trim();
      }
      resolve({ status: Number(statusLine.split(" ")[1]), headers, body: rest.join("\r\n\r\n") });
    });
    const hostLine = host === null ? "" : `Host: ${host}\r\n`;
    socket.write(`${requestLine} HTTP/1.1\r\n${hostLine}${extra}Connection: close\r\n\r\n`);
  });
}
const get = (path, options) => raw(`GET ${path}`, options);

const required = () => JSON.parse(read(w.paths.vercelJson)).headers[0].headers;

describe("sirve lo construido", () => {
  test("escucha solo en 127.0.0.1", () => {
    assert.equal(server.address().address, "127.0.0.1");
  });

  test("la página de inicio, con todas las cabeceras de vercel.json", async () => {
    const r = await get("/");
    assert.equal(r.status, 200);
    assert.match(r.headers["content-type"], /^text\/html/);
    for (const h of required()) {
      assert.equal(r.headers[h.key.toLowerCase()], h.value, `falta o difiere ${h.key}`);
    }
    assert.ok(!("set-cookie" in r.headers));
  });

  test("cleanUrls: /privacy sirve privacy/index.html", async () => {
    const r = await get("/privacy");
    assert.equal(r.status, 200);
    assert.ok(r.body.includes("En pocas palabras"));
  });

  test("trailingSlash false y cleanUrls: /privacy/, /privacy.html y /index.html redirigen", async () => {
    for (const [from, to] of [
      ["/privacy/", "/privacy"],
      ["/privacy.html", "/privacy"],
      ["/privacy/index.html", "/privacy"],
      ["/index.html", "/"],
    ]) {
      const r = await get(from);
      assert.equal(r.status, 308, from);
      assert.equal(r.headers.location, to, from);
    }
  });

  test("la cadena de consulta no cuenta", async () => {
    assert.equal((await get("/privacy?x=1#y")).status, 200);
  });

  test("tipos de contenido de los estilos, las fuentes y las licencias", async () => {
    assert.match((await get("/tokens.css")).headers["content-type"], /^text\/css/);
    assert.match((await get("/site.css")).headers["content-type"], /^text\/css/);
    assert.match((await get("/fonts/archivo/OFL.txt")).headers["content-type"], /^text\/plain/);
    assert.equal((await get("/fonts/archivo/Archivo-Variable.ttf")).headers["content-type"], "font/ttf");
  });

  test("HEAD lleva las cabeceras y ningún cuerpo", async () => {
    const r = await raw("HEAD /");
    assert.equal(r.status, 200);
    assert.equal(r.body, "");
    assert.ok(Number(r.headers["content-length"]) > 100);
  });

  test("una ruta que no existe da la página de error con su 404 y las mismas cabeceras", async () => {
    const r = await get("/no-existe");
    assert.equal(r.status, 404);
    assert.ok(r.body.includes("Esta página no existe."));
    assert.equal(r.headers["content-security-policy"], required().find((h) => h.key === "Content-Security-Policy").value);
  });

  test("una carpeta sin index no se lista", async () => {
    for (const p of ["/fonts", "/fonts/", "/fonts/archivo"]) {
      const r = await get(p);
      assert.ok(r.status === 404 || r.status === 308, `${p} dio ${r.status}`);
      if (r.status === 308) assert.equal((await get(r.headers.location)).status, 404);
      assert.ok(!r.body.includes("Archivo-Variable"), `${p} lista la carpeta`);
    }
  });
});

describe("solo GET y HEAD", () => {
  for (const method of ["POST", "PUT", "DELETE", "PATCH", "OPTIONS", "TRACE"]) {
    test(`${method} da 405`, async () => {
      const r = await raw(`${method} /`, { extra: "Content-Length: 0\r\n" });
      assert.equal(r.status, 405);
      assert.equal(r.headers.allow, "GET, HEAD");
    });
  }
});

describe("no sale de dist/", () => {
  const attempts = [
    "/../secret.txt",
    "/%2e%2e/secret.txt",
    "/%2E%2E/secret.txt",
    "/%2e%2e%2fsecret.txt",
    "/privacy/../../secret.txt",
    "/a/%2e%2e/%2e%2e/secret.txt",
    "/..%2fsecret.txt",
    "/..%5csecret.txt",
    "/..\\secret.txt",
    "/%252e%252e/secret.txt",
    "/fonts/../../secret.txt",
    "//../secret.txt",
  ];
  for (const path of attempts) {
    test(`rechaza ${path}`, async () => {
      const r = await get(path);
      // Con `..` tras decodificar, 400; el doble codificado (%252e) es solo un nombre que no existe (404).
      assert.equal(r.status, path.includes("%252e") ? 404 : 400, `${path} dio ${r.status}`);
      assert.ok(!r.body.includes("SECRETO"), `${path} filtró el secreto`);
    });
  }

  for (const path of ["/%00", "/index.html%00.png", "/privacy%00", "/%00/../secret.txt"]) {
    test(`rechaza el byte nulo ${path}`, async () => {
      const r = await get(path);
      assert.equal(r.status, 400, `${path} dio ${r.status}`);
    });
  }

  for (const path of ["/..%5csecret.txt", "/..\\secret.txt", "/a%5cb"]) {
    test(`rechaza la barra invertida ${path}`, async () => {
      assert.equal((await get(path)).status, 400, path);
    });
  }

  test("la página de error pedida directamente también da 404", async () => {
    for (const p of ["/404", "/404.html"]) {
      const r = await get(p);
      assert.ok(r.status === 404 || r.status === 308, `${p} dio ${r.status}`);
      if (r.status === 308) assert.equal((await get(r.headers.location)).status, 404);
    }
  });

  test("un enlace simbólico a un archivo de fuera no se sigue", async () => {
    const r = await get("/enlace.txt");
    assert.equal(r.status, 404);
    assert.ok(!r.body.includes("SECRETO"));
  });

  test("un enlace simbólico a una carpeta de fuera no se sigue", async () => {
    const r = await get("/enlace-carpeta/inside.txt");
    assert.equal(r.status, 404);
    assert.ok(!r.body.includes("SECRETO"));
  });

  test("una dirección absoluta o rara en la línea de petición se rechaza", async () => {
    assert.equal((await raw("GET http://evil.example/")).status, 400);
    assert.equal((await raw("GET *")).status, 400);
    assert.equal((await raw("GET privacy")).status, 400);
  });
});

describe("Host: sin DNS rebinding", () => {
  test("127.0.0.1:<puerto> y localhost:<puerto> pasan", async () => {
    assert.equal((await get("/", { host: `127.0.0.1:${port}` })).status, 200);
    assert.equal((await get("/", { host: `localhost:${port}` })).status, 200);
  });

  for (const host of [
    "evil.example",
    `evil.example:${port}`,
    `127.0.0.1.evil.example:${port}`,
    `localhost.evil.example:${port}`,
    "127.0.0.1",
    "localhost",
    `127.0.0.1:${1}`,
    `[::1]:${1}`,
    "0.0.0.0:80",
    "",
  ]) {
    test(`rechaza Host «${host}»`, async () => {
      const r = await get("/", { host });
      assert.equal(r.status, 403);
      assert.ok(!r.body.includes("<h1>"));
    });
  }

  test("sin cabecera Host se rechaza", async () => {
    assert.ok([400, 403].includes((await raw("GET /", { host: null })).status));
  });
});

describe("la configuración", () => {
  test("una regla de cabeceras que no sea para todas las rutas hace fallar el arranque", () => {
    writeFileSync(
      join(w.dir, "otra.json"),
      JSON.stringify({ headers: [{ source: "/privacy", headers: [{ key: "X-A", value: "1" }] }] }),
    );
    assert.throws(() => createLandingServer({ dist: w.dist, vercelJson: join(w.dir, "otra.json") }), /source/);
  });

  test("un dist/ que no existe hace fallar el arranque", () => {
    assert.throws(() => createLandingServer({ dist: join(w.dir, "nada"), vercelJson: w.paths.vercelJson }), /dist/);
  });
});
