// Identidad y enlaces. El nombre, el logotipo y las direcciones de las tiendas salen de `app/identity.yaml`:
// `landing/build.mjs` los escribe en `gen/site.json` antes de construir con Vite.
import site from '../../gen/site.json' with { type: 'json' };

export const APP_NAME = site.appName;
export const WORDMARK = site.wordmark;

// null = la tienda aún no está disponible: el rótulo se ve, pero no enlaza y se avisa de que llega pronto.
// El día del lanzamiento, pon la dirección de cada ficha en `app/identity.yaml` (`appStoreUrl`, `googlePlayUrl`).
export const STORE_URLS = {
  appStore: site.stores.appStoreUrl,
  googlePlay: site.stores.googlePlayUrl,
};

// Las otras páginas de la web (`landing/build.mjs`).
export const LINKS = {
  help: '/help',
  privacy: '/privacy',
  licenses: '/licenses',
};
