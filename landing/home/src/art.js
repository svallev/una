// Ilustraciones (spec 025, CA-025-06 y CA-025-14), traídas de la maqueta (`art.js`): lo que el usuario adjunta
// a sus tareas, dibujado a pantalla completa (390 × 844): el mapa de un campo de golf, el cartel de un festival,
// la portada de un libro, el mapa de una ruta y el jugador de la mesa de luz. Todo es inventado (nombres de
// grupos, autora, calles; los dominios, reservados para ejemplos) para no usar material de terceros.
//
// Son imágenes, no interfaz: sus colores y fuentes quedan fuera de los tokens (CA-025-14, DEV-59). Cambios
// respecto a la maqueta: los textos llegan como argumento ([s], `sample` de `strings.*.json`) y pasan por `esc`
// de `html.js`, la única del programa (plan §6.1); sin `style=` (la CSP lo bloquearía): `font-stretch` es un
// atributo de presentación del SVG. Siempre ocultas al lector: la descripción la lleva el móvil (`app-ui.js`).
import { esc } from "./html.js";
const svg = (inner, extra = '') =>
  `<svg viewBox="0 0 390 844" preserveAspectRatio="xMidYMid slice" aria-hidden="true" ${extra}>${inner}</svg>`;

/** Mapa de un campo de golf: calles, greens, búnkeres, agua y el número de cada hoyo. */
export function golfMap(s) {
  // [salida → green, número]
  const holes = [
    ['M60 572 C72 492 48 430 82 366', 1], ['M122 338 C172 300 222 322 272 292', 2], ['M312 304 C334 362 322 420 300 470', 3],
    ['M268 506 C222 524 182 500 152 540', 4], ['M108 250 C98 208 142 188 202 200', 5], ['M250 206 C300 186 342 208 350 252', 6],
    ['M192 600 C232 566 282 584 332 546', 7], ['M40 800 C82 740 162 760 222 720', 8], ['M262 762 C302 782 342 742 350 690', 9],
  ];
  const end = (d) => d.trim().split(' ').slice(-2).map(Number);
  const start = (d) => d.slice(1).split(' ').slice(0, 2).map(Number);
  const trees = [[20, 150], [345, 150], [180, 260], [30, 300], [362, 420], [215, 370], [110, 440], [20, 640], [130, 650], [300, 640], [365, 800], [120, 820], [200, 110], [60, 40], [320, 70], [240, 660]];
  const fairways = holes.map(([d]) => `<path d="${d}" stroke="#6FA854" stroke-width="46"/><path d="${d}" stroke="#93CC6E" stroke-width="32"/>`).join('');
  const greens = holes.map(([d]) => {
    const [x, y] = end(d);
    return `<ellipse cx="${x}" cy="${y}" rx="22" ry="18" fill="#BFE894" stroke="#7DB85C" stroke-width="2"/>
      <ellipse cx="${x - 24}" cy="${y + 14}" rx="10" ry="7" fill="#F1E3B0" stroke="#D9C88C" stroke-width="1.5"/>
      <ellipse cx="${x + 22}" cy="${y - 16}" rx="8" ry="6" fill="#F1E3B0" stroke="#D9C88C" stroke-width="1.5"/>
      <path d="M${x} ${y}v-18" stroke="#2A2A2A" stroke-width="1.6"/><path d="M${x} ${y - 18}l11 4-11 4z" fill="#E0342B"/>`;
  }).join('');
  const tees = holes.map(([d, n]) => {
    const [x, y] = start(d);
    return `<rect x="${x - 9}" y="${y - 5}" width="18" height="10" rx="2" fill="#4F8F3D"/>
      <circle cx="${x}" cy="${y + 20}" r="11" fill="#FFFFFF" stroke="#1D3B16" stroke-width="1.5"/>
      <text x="${x}" y="${y + 24.5}" text-anchor="middle" font-size="13" font-weight="800" fill="#1D3B16">${n}</text>`;
  }).join('');
  return svg(`
    <rect width="390" height="844" fill="#4E8A3E"/>
    <g fill="#3F7433">${trees.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="26"/><circle cx="${x + 24}" cy="${y + 14}" r="19"/><circle cx="${x - 20}" cy="${y + 16}" r="16"/>`).join('')}</g>
    <g fill="#356629">${trees.map(([x, y]) => `<circle cx="${x + 4}" cy="${y + 2}" r="11"/><circle cx="${x + 24}" cy="${y + 14}" r="8"/>`).join('')}</g>
    <path d="M168 404 C190 380 252 384 262 412 C270 440 222 456 190 448 C164 442 152 420 168 404Z" fill="#7CC6EA" stroke="#55A6CF" stroke-width="2.5"/>
    <path d="M286 600 C310 588 350 596 356 618 C360 638 318 646 296 638 C276 630 270 610 286 600Z" fill="#7CC6EA" stroke="#55A6CF" stroke-width="2.5"/>
    <g fill="none" stroke-linecap="round" stroke-linejoin="round">${fairways}</g>
    <path d="M70 610 C120 590 150 470 100 400 C80 360 110 300 190 250 C260 230 330 270 336 330" fill="none" stroke="#EFE6C8" stroke-width="2.5" stroke-dasharray="6 6" opacity="0.85"/>
    ${greens}${tees}
    <g transform="translate(24 596)"><rect width="64" height="36" fill="#F4EFE2" stroke="#3B2F26" stroke-width="2"/><path d="M-6 2L32-18 70 2Z" fill="#B5533A" stroke="#3B2F26" stroke-width="2"/><rect x="26" y="16" width="12" height="20" fill="#3B2F26"/></g>
    <text x="56" y="652" text-anchor="middle" font-size="11" font-weight="700" fill="#FFFFFF">${esc(s.golfHouse)}</text>
    <g transform="translate(24 152)"><rect width="262" height="32" fill="#1D3B16"/><text x="12" y="21" font-size="13.5" font-weight="800" fill="#FFFFFF" letter-spacing="0.3">${esc(s.golfTitle)}</text></g>
    <g transform="translate(346 176)"><circle r="17" fill="#FFFFFF" stroke="#1D3B16" stroke-width="1.5"/><path d="M0-12L5 4 0 1-5 4Z" fill="#E0342B"/><text y="13" text-anchor="middle" font-size="8" font-weight="800" fill="#1D3B16">N</text></g>`,
  'font-family="Archivo, system-ui, sans-serif"');
}

/** Cartel de un festival de música, con los grupos de cada día (nombres inventados). */
export function lineupPoster(s) {
  const days = s.lineupDays;
  const bands = [
    ['Farolillo Rojo', 'Trece Gatos Pardos', 'La Señal del Faro · Orquesta Mínima'],
    ['Brasa Lenta Club', 'Viento del Sur 77', 'Las Hijas del Trueno · Dos Lunas Cortas'],
    ['Noche de Almendros', 'Cometa Farolera', 'Los Últimos del Andén · Tía Remedios DJ'],
  ];
  const block = (i, y) => `
    <text x="26" y="${y}" font-size="13" font-weight="800" fill="#1A0F12" letter-spacing="1.5"><tspan dx="8" dy="0">${esc(days[i].toUpperCase())}</tspan></text>
    <text x="26" y="${y + 44}" font-size="36" font-weight="900" fill="#FFE55C" font-stretch="62%">${esc(bands[i][0].toUpperCase())}</text>
    <text x="26" y="${y + 76}" font-size="27" font-weight="900" fill="#FFF7E6" font-stretch="62%">${esc(bands[i][1].toUpperCase())}</text>
    <text x="26" y="${y + 99}" font-size="13.5" font-weight="700" fill="#FFB870" letter-spacing="0.4">${esc(bands[i][2].toUpperCase())}</text>`;
  const tag = (y, w) => `<rect x="26" y="${y - 15}" width="${w}" height="21" fill="#FF8A1F"/>`;
  return svg(`
    <rect width="390" height="844" fill="#1A0F12"/>
    <circle cx="300" cy="96" r="150" fill="#D4145A"/><circle cx="300" cy="96" r="104" fill="#FF8A1F"/><circle cx="300" cy="96" r="60" fill="#FFD21F"/>
    <g fill="#1A0F12"><rect x="0" y="118" width="390" height="7"/><rect x="0" y="136" width="390" height="5"/><rect x="0" y="151" width="390" height="3"/></g>
    <rect x="0" y="154" width="390" height="690" fill="#1A0F12"/>
    <text x="24" y="232" font-size="78" font-weight="900" fill="#FFF7E6" font-stretch="62%" letter-spacing="-1">LAGO</text>
    <text x="24" y="296" font-size="78" font-weight="900" fill="#FF8A1F" font-stretch="62%" letter-spacing="-1">SONORO</text>
    <text x="196" y="204" font-size="13" font-weight="800" fill="#FFE55C" letter-spacing="1.2">FESTIVAL</text>
    <text x="196" y="222" font-size="12" font-weight="700" fill="#FFF7E6">${esc(s.lineupDates)}</text>
    ${tag(336, 104)}${block(0, 336)}
    ${tag(476, 104)}${block(1, 476)}
    ${tag(616, 114)}${block(2, 616)}
    <rect x="26" y="752" width="338" height="2" fill="#FFF7E6" opacity="0.5"/>
    <text x="26" y="776" font-size="12" font-weight="700" fill="#FFF7E6" letter-spacing="0.6">${esc(s.lineupFoot.toUpperCase())}</text>
    <text x="26" y="800" font-size="11" fill="#FFB870" font-family="'Space Mono', monospace">lagosonoro.example</text>`,
  'font-family="Archivo, system-ui, sans-serif"');
}

/** Portada de un libro (título y autora inventados). */
export function bookCover(s) {
  const lines = s.bookTitle;
  return svg(`
    <rect width="390" height="844" fill="#EFE2C6"/>
    <rect x="0" y="0" width="14" height="844" fill="#D9C7A3"/><rect x="14" y="0" width="2" height="844" fill="#C4B08A"/>
    <g transform="translate(0 150)"><circle cx="250" cy="330" r="112" fill="#E4572E"/>
    <path d="M0 392 C70 340 130 356 196 404 C262 452 318 420 390 372 V620 H0Z" fill="#D9A441"/>
    <path d="M0 470 C80 428 150 452 214 492 C278 532 330 508 390 472 V660 H0Z" fill="#B5533A"/>
    <path d="M0 548 C90 512 170 540 236 572 C296 600 340 588 390 566 V844 H0Z" fill="#3A2420"/>
    <g fill="none" stroke="#EFE2C6" stroke-width="2" opacity="0.5"><path d="M30 600 C110 576 190 600 250 624"/><path d="M60 640 C140 620 220 644 300 652"/></g>
    <g stroke="#3A2420" stroke-width="3" fill="none"><path d="M84 470v-64"/><path d="M84 420c-14-6-20-18-18-30 12 2 20 12 18 30z" fill="#3A2420"/><path d="M84 440c14-6 20-18 18-30-12 2-20 12-18 30z" fill="#3A2420"/></g></g>
    <text x="42" y="182" font-size="15" font-weight="700" fill="#3A2420" letter-spacing="3.2" font-family="Archivo, system-ui, sans-serif">MARINA OLABARRI</text>
    <rect x="42" y="194" width="46" height="3" fill="#3A2420"/>
    <g font-family="Georgia, 'Times New Roman', serif" font-size="47" font-weight="700" fill="#3A2420" letter-spacing="-0.6">
      ${lines.map((ln, i) => `<text x="40" y="${262 + i * 50}">${esc(ln)}</text>`).join('')}
    </g>
    <text x="42" y="826" font-size="12" font-weight="700" fill="#D9A441" letter-spacing="2.6" font-family="Archivo, system-ui, sans-serif">${esc(s.bookKind.toUpperCase())}</text>
    <g transform="translate(336 812)"><circle r="15" fill="none" stroke="#D9A441" stroke-width="2"/><path d="M-6 5V-6l6 5 6-5V5" fill="none" stroke="#D9A441" stroke-width="2"/></g>`);
}

/** Página web con el mapa de una ruta: calles, río, parque, el trazado y su ficha. */
export function routeMap(s) {
  const [walk, mill, avenue, park] = s.routeStreets;
  const route = 'M62 660 C90 600 70 540 118 500 C170 456 150 400 196 360 C250 312 300 330 318 270 C330 226 290 190 300 150';
  return `<svg viewBox="0 0 390 768" preserveAspectRatio="xMidYMid slice" aria-hidden="true" font-family="system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif">
    <rect width="390" height="768" fill="#EFEAE0"/>
    <path d="M196 60 L390 20 V250 L250 290Z" fill="#D3E6B8"/><path d="M0 560 L120 520 190 650 60 768 H0Z" fill="#D3E6B8"/>
    <g fill="#B9D69C"><circle cx="300" cy="120" r="16"/><circle cx="340" cy="170" r="13"/><circle cx="268" cy="200" r="12"/><circle cx="60" cy="640" r="15"/><circle cx="110" cy="600" r="12"/></g>
    <path d="M-10 420 C60 380 110 470 180 440 C250 410 270 300 330 300 C360 300 380 320 400 316" fill="none" stroke="#A7D2EC" stroke-width="40" stroke-linecap="round"/>
    <path d="M-10 420 C60 380 110 470 180 440 C250 410 270 300 330 300 C360 300 380 320 400 316" fill="none" stroke="#C3E2F4" stroke-width="26" stroke-linecap="round"/>
    <g stroke="#FFFFFF" stroke-linecap="round" fill="none">
      <g stroke-width="15"><path d="M-10 250 L400 150"/><path d="M-10 560 L400 470"/><path d="M150 -10 L230 780"/></g>
      <g stroke-width="9"><path d="M-10 120 L400 40"/><path d="M-10 350 L140 310"/><path d="M-10 690 L400 610"/><path d="M40 -10 L96 780"/><path d="M280 -10 L360 780"/><path d="M200 300 L400 250"/><path d="M0 480 L160 450"/></g>
    </g>
    <g fill="#DDD5C6"><path d="M108 172 l34-8 6 46-34 8z"/><path d="M52 186 l40-10 6 46-40 10z"/><path d="M176 506 l40-9 8 58-40 9z"/><path d="M232 494 l44-10 8 58-44 10z"/><path d="M304 478 l40-9 8 58-40 9z"/><path d="M112 270 l28-7 5 34-28 7z"/><path d="M170 620 l44-9 6 44-44 9z"/><path d="M236 606 l44-9 6 44-44 9z"/></g>
    <g font-size="10.5" fill="#857D70" font-weight="600">
      <text transform="translate(206 196) rotate(-13.6)">${esc(avenue)}</text>
      <text transform="translate(240 500) rotate(-12.4)">${esc(mill)}</text>
      <text transform="translate(16 414) rotate(-8)" fill="#4E8FB5" font-style="italic">${esc(walk)}</text>
      <text x="284" y="92" fill="#5E8A3C" font-style="italic">${esc(park)}</text>
    </g>
    <path d="${route}" fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="${route}" fill="none" stroke="#E8501A" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
    <g><circle cx="62" cy="660" r="10" fill="#FFFFFF" stroke="#1F1B16" stroke-width="3"/><circle cx="62" cy="660" r="4" fill="#1F1B16"/></g>
    <g transform="translate(300 150)"><path d="M0 0C-14-16-16-22-16-28a16 16 0 0 1 32 0c0 6-2 12-16 28z" fill="#E8501A" stroke="#FFFFFF" stroke-width="2.5"/><circle cy="-28" r="6" fill="#FFFFFF"/></g>
    <g font-size="11" font-weight="700" fill="#1F1B16"><rect x="78" y="650" width="${s.routeStart.length * 7 + 14}" height="20" rx="4" fill="#FFFFFF"/><text x="85" y="664">${esc(s.routeStart)}</text>
      <rect x="222" y="112" width="${s.routeEnd.length * 7 + 14}" height="20" rx="4" fill="#FFFFFF"/><text x="229" y="126">${esc(s.routeEnd)}</text></g>
    <g transform="translate(16 452)">
      <rect width="358" height="150" rx="14" fill="#FFFFFF" stroke="#E2DBCD"/>
      <text x="18" y="34" font-size="20" font-weight="800" fill="#1F1B16">${esc(s.routeName)}</text>
      <text x="18" y="56" font-size="13" font-weight="600" fill="#6B6458">${esc(s.routeStats)}</text>
      <path d="M18 128 L48 112 78 118 108 96 138 104 168 84 198 92 228 74 258 88 288 78 318 100 340 110 V132 H18Z" fill="#FBE3D6"/>
      <path d="M18 128 L48 112 78 118 108 96 138 104 168 84 198 92 228 74 258 88 288 78 318 100 340 110" fill="none" stroke="#E8501A" stroke-width="2.5" stroke-linejoin="round"/>
      <rect x="18" y="132" width="322" height="1.5" fill="#E2DBCD"/>
    </g>
    <g transform="translate(346 312)"><rect x="-18" y="-18" width="36" height="72" rx="8" fill="#FFFFFF" stroke="#E2DBCD"/><path d="M-7 0h14M0-7v14M-7 36h14" stroke="#1F1B16" stroke-width="2.4" stroke-linecap="round"/><rect x="-18" y="17.5" width="36" height="1" fill="#E2DBCD"/></g>
  </svg>`;
}

/**
 * Un jugador de baloncesto entrando a canasta, para la mesa de luz. Devuelve la imagen a color y,
 * con la misma geometría, el contorno que se va calcando en el papel (cada trazo con pathLength="1").
 */
export function athlete() {
  // Un miembro: cápsula entre dos puntos, con el ancho dado.
  const limb = (x1, y1, x2, y2, w) => {
    const len = Math.hypot(x2 - x1, y2 - y1);
    const nx = (-(y2 - y1) / len) * (w / 2);
    const ny = ((x2 - x1) / len) * (w / 2);
    const f = (v) => v.toFixed(1);
    return `d="M${f(x1 + nx)} ${f(y1 + ny)} L${f(x2 + nx)} ${f(y2 + ny)} A${w / 2} ${w / 2} 0 0 0 ${f(x2 - nx)} ${f(y2 - ny)} L${f(x1 - nx)} ${f(y1 - ny)} A${w / 2} ${w / 2} 0 0 0 ${f(x1 + nx)} ${f(y1 + ny)}Z"`;
  };
  const SKIN = '#8A4B2D';
  const SKIN_BACK = '#74401F';
  // [etiqueta SVG, geometría, relleno, ¿se calca?], de atrás hacia delante
  const shapes = [
    ['rect', 'x="322" y="166" width="62" height="72"', '#FFFFFF', 1],
    ['rect', 'x="336" y="194" width="34" height="30"', '#FFFFFF', 1],
    ['path', limb(166, 318, 130, 342, 22), SKIN_BACK, 1], // brazo de atrás
    ['path', limb(130, 342, 112, 300, 19), SKIN_BACK, 1],
    ['path', limb(156, 446, 128, 506, 30), SKIN_BACK, 1], // pierna de atrás, recogida
    ['path', limb(128, 506, 88, 530, 24), SKIN_BACK, 1],
    ['path', limb(84, 532, 66, 554, 21), '#FFFFFF', 1],
    ['path', limb(186, 310, 170, 410, 62), '#D4145A', 1], // camiseta
    ['path', limb(172, 414, 168, 448, 70), '#FFD21F', 1], // pantalón
    ['path', limb(184, 446, 214, 510, 30), SKIN, 1], // pierna de delante
    ['path', limb(214, 510, 196, 582, 24), SKIN, 1],
    ['path', limb(196, 588, 224, 596, 21), '#FFFFFF', 1],
    ['path', limb(206, 315, 236, 260, 22), SKIN, 1], // brazo que lleva el balón
    ['path', limb(236, 260, 262, 206, 19), SKIN, 1],
    ['circle', 'cx="182" cy="270" r="26"', SKIN, 1],
    ['circle', 'cx="276" cy="184" r="26"', '#F08A24', 1],
    ['ellipse', 'cx="292" cy="238" rx="31" ry="8"', 'none', 1],
    ['path', 'd="M0 668h390"', 'none', 1],
  ];
  const head = 'viewBox="0 0 390 844" preserveAspectRatio="xMidYMid slice" aria-hidden="true"';
  const art = `<svg ${head}>
    <rect width="390" height="844" fill="#FFD9A0"/><circle cx="92" cy="150" r="46" fill="#FFF1C9"/>
    <g fill="#F2B880"><rect x="0" y="470" width="70" height="200"/><rect x="58" y="520" width="56" height="150"/><rect x="232" y="500" width="64" height="170"/><rect x="286" y="440" width="104" height="230"/></g>
    <rect x="0" y="668" width="390" height="176" fill="#D9773F"/>
    <path d="M0 720h390M120 668l-60 176M300 668l40 176" stroke="#FFF1C9" stroke-width="4" fill="none" opacity="0.8"/>
    <ellipse cx="170" cy="716" rx="74" ry="11" fill="#3A2420" opacity="0.28"/>
    <rect x="350" y="238" width="11" height="432" fill="#3A2420"/>
    ${shapes.map(([tag, geo, fill]) => (fill === 'none'
      ? (tag === 'ellipse' ? `<${tag} ${geo} fill="none" stroke="#E0342B" stroke-width="5"/>` : '')
      : `<${tag} ${geo} fill="${fill}"${tag === 'rect' ? ' stroke="#3A2420" stroke-width="4"' : ''}/>`)).join('')}
    <circle cx="262" cy="206" r="11" fill="${SKIN}"/><circle cx="112" cy="300" r="11" fill="${SKIN_BACK}"/>
    <path d="M264 242l6 34M278 245l4 33M292 246v33M306 245l-4 33M320 242l-6 34M266 258h52M270 272h44" stroke="#FFFFFF" stroke-width="2" fill="none"/>
    <path d="M250 184h52M276 158v52M256 166c12 10 12 26 0 36M296 166c-12 10-12 26 0 36" stroke="#3A2420" stroke-width="2" fill="none"/>
    <path d="M158 262c2-18 16-26 30-24 12 2 20 10 20 22-12-6-30-8-50 2z" fill="#2B1D1A"/>
    <text x="178" y="378" text-anchor="middle" font-family="Archivo, system-ui, sans-serif" font-size="40" font-weight="900" fill="#FFFFFF" transform="rotate(9 178 366)">7</text>
  </svg>`;
  const trace = `<svg ${head}>${shapes.filter((sh) => sh[3]).map(([tag, geo]) => `<${tag} ${geo} pathLength="1"/>`).join('')}</svg>`;
  return { art, trace };
}
