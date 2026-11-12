// ScrollTrigger 3.15.1, al registrarse, hace `body.setAttribute("style", "")` si <body> no tiene atributo
// `style`, y la CSP de la página (sin 'unsafe-inline') lo cuenta como infracción. Una propiedad puesta por
// CSSOM (que la CSP no bloquea) le da ese atributo y evita esa rama (plan §1.6).
//
// Tiene que evaluarse antes que gsap: el núcleo se instala en `window` al importarse y ScrollTrigger se
// registra solo al importarse, antes de que corra el código de `main.js`. Por eso `main.js` lo importa el
// primero.
document.body.style.setProperty("--scroll-trigger-ready", "1");
