// Iconos de la página de inicio (spec 025), copiados de la maqueta: los de la app (`app/lib/ui/una_icons.dart`),
// en una caja de 24, de trazo y con puntas cuadradas. Siempre ocultos al lector (`aria-hidden`): el nombre lo
// da el texto de al lado. Sin `style=` (la CSP lo bloquearía): el trazo y el tamaño, en el CSS (`.ic`).
const PATHS = {
  check: ['M4 12.5l5 5L20 6.5'],
  arrowDown: ['M12 4v15M6 13l6 6 6-6'],
  arrowLeft: ['M20 12H5M11 6l-6 6 6 6'],
  plus: ['M12 4v16M4 12h16'],
  menu: ['M4 7h16M4 12h16M4 17h16'],
  edit: ['M4 20h4L19 9l-4-4L4 16v4z', 'M13 7l4 4'],
  trash: ['M3 7h18M10 11v6M14 11v6M5 7l1 14h12l1-14M9 7V3h6v4'],
  lock: ['M5 11h14v10H5z', 'M8 11V7a4 4 0 0 1 8 0v4'],
  phone: ['M7 2h10v20H7z', 'M11 18h2'],
  magnifierMinus: ['M3 10a7 7 0 1 0 14 0a7 7 0 1 0 -14 0', 'M15 15l6 6', 'M7 10h6'],
  image: ['M3 4h18v16H3z', 'M3 16l5-5 4 4 3-3 6 6', 'M14.4 8.5a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0'],
  document: ['M6 2h9l5 5v15H6z', 'M14 2v6h6M9 13h8M9 17h8'],
  link: ['M10 14l4-4', 'M9 7l2-2a4 4 0 0 1 6 6l-2 2', 'M15 17l-2 2a4 4 0 0 1-6-6l2-2'],
  globe: ['M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M3 12h18', 'M12 3c3 3 3 15 0 18', 'M12 3c-3 3 -3 15 0 18'],
};

export const iconPaths = (name) => PATHS[name];

export function icon(name, cls = '') {
  return `<svg class="ic ${cls}" viewBox="0 0 24 24" aria-hidden="true">${PATHS[name].map((d) => `<path d="${d}"/>`).join('')}</svg>`;
}

// Asa de arrastre de la lista: seis puntos rellenos.
export const HANDLE = '<svg class="ic ic--fill" viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5h3v3H8zM13 5h3v3h-3zM8 10.5h3v3H8zM13 10.5h3v3h-3zM8 16h3v3H8zM13 16h3v3h-3z"/></svg>';

// Barra de estado del sistema (wifi y batería), dibujada en relleno como la del teléfono.
export const STATUS_ICONS = `<svg viewBox="0 0 46 14" aria-hidden="true"><path d="M7.5 13.2 1 6.6a9.3 9.3 0 0 1 13 0Z"/><path d="M3 4.3a12.3 12.3 0 0 1 9 0" fill="none" stroke="currentColor" stroke-width="1.6"/><rect x="21" y="2" width="20" height="10" rx="2.6"/><rect x="42" y="5" width="1.8" height="4" rx=".9"/></svg>`;
