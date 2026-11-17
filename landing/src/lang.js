// El idioma de las páginas de contenido (spec 026, ADR-0028). Un programa clásico y síncrono en el <head>:
// decide el idioma antes del primer pintado y marca <html data-lang>, y site.css oculta la otra mitad. Solo toca
// atributos (data-lang, lang, role y aria-pressed) y document.title; nunca escribe HTML ni estilos, y lo que lee
// de la dirección o del almacenamiento solo se compara con "es" y "en". Si algo falla, <html> queda sin marca
// y se ve la versión sin JavaScript, con los dos idiomas (CL-026-5).
(function () {
  "use strict";

  var html = document.documentElement;
  var ANCHOR = /^#(es|en)(-|$)/;
  var LINKS = ".langs a[hreflang]";

  // El idioma del ancla (#es, #en o la de una sección), o null.
  function fromHash() {
    var match = ANCHOR.exec(location.hash);
    return match ? match[1] : null;
  }

  // Ancla, después lo guardado (si es "es" o "en") y después el navegador: español o catalán → español,
  // otro → inglés, vacío → español (la regla de la landing, CL-026-11). `?lang=` no se mira.
  function pick() {
    var lang = fromHash();
    if (lang) return lang;
    var stored = null;
    try {
      stored = localStorage.getItem("una-lang");
    } catch (e) {
      // Sin almacenamiento (CL-026-4).
    }
    if (stored === "es" || stored === "en") return stored;
    return /^(es|ca)/i.test(navigator.language || "es") ? "es" : "en";
  }

  function links() {
    return document.querySelectorAll(LINKS);
  }

  // Pasa la página a [lang]. Lo último es data-lang: si algo falla antes, no se oculta nada.
  function apply(lang) {
    var title = lang === "es" ? html.dataset.titleEs : html.dataset.titleEn;
    if (!title) throw new Error("sin título");
    document.title = title;
    var all = links();
    for (var i = 0; i < all.length; i++) {
      all[i].setAttribute("aria-pressed", all[i].getAttribute("hreflang") === lang ? "true" : "false");
    }
    html.lang = lang;
    html.dataset.lang = lang;
  }

  // Clic (también Intro) o Espacio en una opción del selector: cambia sin navegar y deja el foco donde está.
  function choose(event, lang) {
    event.preventDefault();
    if (lang === html.dataset.lang) return;
    try {
      apply(lang);
    } catch (e) {
      return;
    }
    try {
      localStorage.setItem("una-lang", lang);
    } catch (e) {
      // Sin almacenamiento: vale para esta página (CL-026-4).
    }
    // Un ancla de idioma es siempre la del que se veía (el ancla manda en pick), o sea, la del otro: una
    // recarga volvería a él (CL-026-2).
    if (fromHash()) {
      history.replaceState(history.state, "", location.pathname + location.search);
    }
  }

  function enhance() {
    var all = links();
    for (var i = 0; i < all.length; i++) {
      var link = all[i];
      var lang = link.getAttribute("hreflang");
      if (lang !== "es" && lang !== "en") continue;
      link.setAttribute("role", "button");
      link.setAttribute("aria-pressed", lang === html.dataset.lang ? "true" : "false");
      link.addEventListener("click", onClick(lang));
      link.addEventListener("keydown", onKey(lang));
    }
  }

  function onClick(lang) {
    return function (event) {
      choose(event, lang);
    };
  }

  function onKey(lang) {
    return function (event) {
      if (event.key === " " || event.key === "Spacebar") choose(event, lang);
    };
  }

  function refresh() {
    try {
      apply(pick());
    } catch (e) {
      // Se queda como estaba.
    }
  }

  try {
    apply(pick());
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", enhance);
    } else {
      enhance();
    }
    // Atrás y adelante dentro de la página, o un ancla escrita a mano (sin guardarla).
    addEventListener("hashchange", function () {
      if (fromHash()) refresh();
    });
    // Página sacada de la memoria del navegador al volver atrás: el idioma guardado ahora (CL-026-8).
    addEventListener("pageshow", function (event) {
      if (event.persisted) refresh();
    });
  } catch (e) {
    // Sin marca en <html>: se ve la versión sin JavaScript (CL-026-5).
  }
})();
