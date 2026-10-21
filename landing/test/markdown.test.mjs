// Conversor de Markdown de la web (spec 023, CA-023-04 y CA-023-13): un subconjunto con falla cerrada.
// La salida esperada está escrita a mano: no se compara con el propio conversor.
import assert from "node:assert/strict";
import { test } from "node:test";
import { convertMarkdown, MarkdownError } from "../build.mjs";

const html = (md, options) => convertMarkdown(md, options).html;
const fails = (md, pattern, options) =>
  assert.throws(() => convertMarkdown(md, options), (e) => {
    assert.ok(e instanceof MarkdownError, `se esperaba MarkdownError y salió ${e}`);
    assert.match(e.message, pattern);
    return true;
  });

test("CA-023-04: la salida esperada, escrita a mano, de un texto con HTML y comillas", () => {
  assert.equal(
    html("Hola <script>alert(1)</script> & \"comillas\" y 'simples'"),
    "<p>Hola &lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;comillas&quot; y &#39;simples&#39;</p>",
  );
});

test("CA-023-04: encabezados desplazados un nivel, párrafos y varias líneas de un párrafo", () => {
  assert.equal(
    html("# Título\n\n## Sección\n\nUna línea\ny otra.\n\n### Punto\n\nFin", { shift: 1 }),
    [
      "<h2>Título</h2>",
      "<h3>Sección</h3>",
      "<p>Una línea y otra.</p>",
      "<h4>Punto</h4>",
      "<p>Fin</p>",
    ].join("\n"),
  );
});

test("CA-023-04: el primer encabezado puede llevar atributos (el destino del salto de idioma)", () => {
  assert.equal(
    html("# Hola\n\n## Dos", { shift: 1, firstHeadingAttrs: 'id="es" tabindex="-1"' }),
    '<h2 id="es" tabindex="-1">Hola</h2>\n<h3>Dos</h3>',
  );
});

test("CA-023-04: negrita, cursiva y código; lo de dentro del código no se interpreta", () => {
  assert.equal(
    html("Esto es **fuerte**, *suave* y `a **b** <c>`."),
    "<p>Esto es <strong>fuerte</strong>, <em>suave</em> y <code>a **b** &lt;c&gt;</code>.</p>",
  );
});

test("CA-023-04: listas de un nivel y anidadas", () => {
  assert.equal(
    html("- uno\n- dos\n  - dos A\n  - dos B\n- tres"),
    [
      "<ul>",
      "<li>uno</li>",
      "<li>dos",
      "<ul>",
      "<li>dos A</li>",
      "<li>dos B</li>",
      "</ul></li>",
      "<li>tres</li>",
      "</ul>",
    ].join("\n"),
  );
});

test("CA-023-04: una cita", () => {
  assert.equal(html("> dice\n> algo"), "<blockquote>\n<p>dice algo</p>\n</blockquote>");
});

test("CA-023-04: los enlaces https llevan rel; mailto, relativos y # no", () => {
  assert.equal(
    html("[a](https://example.org/x?y=1&z=2) [b](mailto:a@b.co) [c](/privacy) [d](#en)"),
    '<p><a href="https://example.org/x?y=1&amp;z=2" rel="noopener noreferrer">a</a> ' +
      '<a href="mailto:a@b.co">b</a> <a href="/privacy">c</a> <a href="#en">d</a></p>',
  );
});

test("CA-023-13: javascript:, data:, http: y // en un enlace hacen fallar la construcción", () => {
  for (const url of [
    "javascript:alert(1)",
    "JavaScript:alert(1)",
    "data:text/html;base64,AAAA",
    "http://example.org",
    "//evil.example/x",
    "vbscript:x",
    "https://a b.example",
    "https://x.example/\"onmouseover=\"x",
  ]) {
    fails(`[x](${url})`, /enlace/i);
  }
});

test("CA-023-13: cualquier {…} sin sustituir hace fallar", () => {
  fails("Hola {otro}", /\{otro\}/);
  fails("Hola {appName}", /\{appName\}/); // el nombre se sustituye antes de convertir
  fails("- punto {x}", /\{x\}/);
});

test("CA-023-13: los huecos de identidad salen tal cual y se anotan; lo demás entre corchetes falla", () => {
  const r = convertMarkdown("Contacto: [CONTACTO] y [FECHA] y [DATE]");
  assert.equal(r.html, "<p>Contacto: [CONTACTO] y [FECHA] y [DATE]</p>");
  assert.deepEqual(r.gaps, ["[CONTACTO]", "[FECHA]", "[DATE]"]);
  fails("Esto es [Suposición] seguro", /corchetes/i);
  fails("Esto es [Pending]", /corchetes/i);
  fails("Esto es [otra cosa]", /corchetes/i);
  fails("Esto es [NOMBRE DE LA APP]", /corchetes/i);
});

test("CA-023-13: lo que el subconjunto no admite hace fallar, cada cosa con su motivo", () => {
  const casos = [
    ["una tabla", "| a | b |\n|---|---|\n| 1 | 2 |", /tablas/],
    ["una tabla sin barra al principio", "texto\na | b\n--|--", /tablas/],
    ["una imagen", "![texto](/x.png)", /im[aá]genes/],
    ["un bloque de código", "```\ncodigo\n```", /bloques de código/],
    ["un bloque de código con tildes", "~~~\ncodigo\n~~~", /bloques de código/],
    ["una lista numerada", "1. uno\n2. dos", /numeradas/],
    ["una lista numerada con paréntesis", "1) uno", /numeradas/],
    ["una línea horizontal", "texto\n\n---\n\nmás", /horizontales/],
    ["una línea horizontal de asteriscos", "***", /horizontales/],
    ["un encabezado subrayado", "Título\n======", /subrayados/],
    ["un cuarto nivel", "#### Cuatro", /«#» a «###»/],
    ["una lista con asterisco", "* uno\n* dos", /listas van con/],
    ["una lista con +", "+ uno", /listas van con/],
    ["código con sangría", "    codigo", /código con sangría/],
    ["una almohadilla suelta", "#sin espacio", /encabezado no válido/],
    ["una almohadilla sola", "#", /encabezado no válido/],
    ["un encabezado sin texto", "# ", /encabezado no válido/],
    ["una barra invertida", "a \\* b", /barra invertida/],
    ["un código sin cerrar", "a `b", /sin cerrar/],
    ["una negrita sin cerrar", "a **b", /negrita sin cerrar/],
    ["una negrita vacía", "a **** b", /negrita sin cerrar/],
    ["una cursiva sin cerrar", "a *b", /cursiva sin cerrar/],
    ["un acento grave doble", "a ``b`` c", /acentos graves dobles/],
    ["un enlace con texto vacío", "[](https://example.org)", /sin texto/],
    ["un enlace sin dirección", "[a]()", /enlace vacío/],
    ["un enlace sin cerrar", "[a](https://example.org", /enlace sin cerrar/],
    ["un corchete sin cerrar", "texto [abc", /corchete sin cerrar/],
    ["un enlace con corchetes dentro", "[a [b](https://example.org)", /corchetes dentro/],
    ["un fragmento vacío", "[a](#)", /enlace no admitido/],
    ["un fragmento con espacios", "[a](#uno dos)", /caracteres no válidos/],
    ["un https sin dominio", "[a](https:///ruta)", /https no admitido/],
    ["un https con usuario", "[a](https://usuario@example.org/)", /https no admitido/],
    ["un mailto vacío", "[a](mailto:)", /mailto vac/],
    ["una línea sin sangría tras una lista", "- uno\ncontinuación", /sin sangría tras una lista/],
    ["un punto de lista vacío", "- uno\n- ", /punto de lista vac/],
    ["una continuación de lista mal sangrada", "- uno\n    mal", /continuación/],
    ["una línea de párrafo sangrada", "uno\n  dos", /sangría inesperada/],
    ["un párrafo sangrado", " uno", /sangría inesperada/],
    ["una cita con varios párrafos", "> uno\n>\n> dos", /varios párrafos/],
    ["un tabulador", "uno\n\tdos", /tabuladores/],
  ];
  for (const [nombre, md, motivo] of casos) {
    assert.throws(() => convertMarkdown(md), (e) => e instanceof MarkdownError && motivo.test(e.message), `${nombre}: ${JSON.stringify(md)}`);
  }
});

test("CA-023-13: la continuación de un punto de lista y un enlace con negrita dentro se leen bien", () => {
  assert.equal(html("- uno\n  sigue\n- dos"), "<ul>\n<li>uno sigue</li>\n<li>dos</li>\n</ul>");
  assert.equal(html("[**x**](https://example.org)"), '<p><a href="https://example.org" rel="noopener noreferrer"><strong>x</strong></a></p>');
});

test("CA-023-13: una sangría rara dentro de una lista falla (no se adivina)", () => {
  fails("- uno\n   - raro", /sangr/i);
  fails("- uno\n      - muy dentro", /sangr/i);
});

test("CA-023-04: los encabezados que se leyeron salen en el resultado", () => {
  const r = convertMarkdown("# Uno\n\n## Dos\n\n## Tres", { shift: 1 });
  assert.deepEqual(r.headings, [
    { level: 2, text: "Uno" },
    { level: 3, text: "Dos" },
    { level: 3, text: "Tres" },
  ]);
});
