// La única función de escape del HTML de la página de inicio: todo texto que entra en el marcado que se
// genera (en la construcción, `landing/build.mjs`, y en el navegador) pasa por aquí, en el texto y en los
// atributos.
const ENTITIES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

export const esc = (value) => String(value).replace(/[&<>"']/g, (c) => ENTITIES[c]);
