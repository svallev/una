// Lo que el usuario adjunta a sus tareas, dibujado a pantalla completa (390 × 844):
// el mapa de un campo de golf, el cartel de un festival, la portada de un libro y el mapa de una ruta.
// Todo es inventado (nombres de grupos, autora, calles) para no usar material de terceros.
import { t } from '../shared/i18n.js';
import { esc } from '../shared/html.js';

const svg = (inner, extra = '') =>
  `<svg viewBox="0 0 390 844" preserveAspectRatio="xMidYMid slice" aria-hidden="true" ${extra}>${inner}</svg>`;

/** Mapa de un campo de golf: calles, greens, búnkeres, agua y el número de cada hoyo. */
export function golfMap() {
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
    <text x="56" y="652" text-anchor="middle" font-size="11" font-weight="700" fill="#FFFFFF">${esc(t('app.golfHouse'))}</text>
    <g transform="translate(24 152)"><rect width="262" height="32" fill="#1D3B16"/><text x="12" y="21" font-size="13.5" font-weight="800" fill="#FFFFFF" letter-spacing="0.3">${esc(t('app.golfTitle'))}</text></g>
    <g transform="translate(346 176)"><circle r="17" fill="#FFFFFF" stroke="#1D3B16" stroke-width="1.5"/><path d="M0-12L5 4 0 1-5 4Z" fill="#E0342B"/><text y="13" text-anchor="middle" font-size="8" font-weight="800" fill="#1D3B16">N</text></g>`,
  'font-family="Archivo, system-ui, sans-serif"');
}

/** Cartel de un festival de música, con los grupos de cada día (nombres inventados). */
export function lineupPoster() {
  const days = t('app.lineupDays');
  const bands = [
    ['Farolillo Rojo', 'Trece Gatos Pardos', 'La Señal del Faro · Orquesta Mínima'],
    ['Brasa Lenta Club', 'Viento del Sur 77', 'Las Hijas del Trueno · Dos Lunas Cortas'],
    ['Noche de Almendros', 'Cometa Farolera', 'Los Últimos del Andén · Tía Remedios DJ'],
  ];
  const block = (i, y) => `
    <text x="26" y="${y}" font-size="13" font-weight="800" fill="#1A0F12" letter-spacing="1.5"><tspan dx="8" dy="0">${esc(days[i].toUpperCase())}</tspan></text>
    <text x="26" y="${y + 44}" font-size="36" font-weight="900" fill="#FFE55C" style="font-stretch:62%">${esc(bands[i][0].toUpperCase())}</text>
    <text x="26" y="${y + 76}" font-size="27" font-weight="900" fill="#FFF7E6" style="font-stretch:62%">${esc(bands[i][1].toUpperCase())}</text>
    <text x="26" y="${y + 99}" font-size="13.5" font-weight="700" fill="#FFB870" letter-spacing="0.4">${esc(bands[i][2].toUpperCase())}</text>`;
  const tag = (y, w) => `<rect x="26" y="${y - 15}" width="${w}" height="21" fill="#FF8A1F"/>`;
  return svg(`
    <rect width="390" height="844" fill="#1A0F12"/>
    <circle cx="300" cy="96" r="150" fill="#D4145A"/><circle cx="300" cy="96" r="104" fill="#FF8A1F"/><circle cx="300" cy="96" r="60" fill="#FFD21F"/>
    <g fill="#1A0F12"><rect x="0" y="118" width="390" height="7"/><rect x="0" y="136" width="390" height="5"/><rect x="0" y="151" width="390" height="3"/></g>
    <rect x="0" y="154" width="390" height="690" fill="#1A0F12"/>
    <text x="24" y="232" font-size="78" font-weight="900" fill="#FFF7E6" style="font-stretch:62%" letter-spacing="-1">LAGO</text>
    <text x="24" y="296" font-size="78" font-weight="900" fill="#FF8A1F" style="font-stretch:62%" letter-spacing="-1">SONORO</text>
    <text x="196" y="204" font-size="13" font-weight="800" fill="#FFE55C" letter-spacing="1.2">FESTIVAL</text>
    <text x="196" y="222" font-size="12" font-weight="700" fill="#FFF7E6">${esc(t('app.lineupDates'))}</text>
    ${tag(336, 104)}${block(0, 336)}
    ${tag(476, 104)}${block(1, 476)}
    ${tag(616, 114)}${block(2, 616)}
    <rect x="26" y="752" width="338" height="2" fill="#FFF7E6" opacity="0.5"/>
    <text x="26" y="776" font-size="12" font-weight="700" fill="#FFF7E6" letter-spacing="0.6">${esc(t('app.lineupFoot').toUpperCase())}</text>
    <text x="26" y="800" font-size="11" fill="#FFB870" font-family="'Space Mono', monospace">lagosonoro.example</text>`,
  'font-family="Archivo, system-ui, sans-serif"');
}

/** Portada de un libro (título y autora inventados). */
export function bookCover() {
  const lines = t('app.bookTitle');
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
    <text x="42" y="826" font-size="12" font-weight="700" fill="#D9A441" letter-spacing="2.6" font-family="Archivo, system-ui, sans-serif">${esc(t('app.bookKind').toUpperCase())}</text>
    <g transform="translate(336 812)"><circle r="15" fill="none" stroke="#D9A441" stroke-width="2"/><path d="M-6 5V-6l6 5 6-5V5" fill="none" stroke="#D9A441" stroke-width="2"/></g>`);
}

/** Página web con el mapa de una ruta: calles, río, parque, el trazado y su ficha. */
export function routeMap() {
  const [walk, mill, avenue, park] = t('app.routeStreets');
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
    <g font-size="11" font-weight="700" fill="#1F1B16"><rect x="78" y="650" width="${t('app.routeStart').length * 7 + 14}" height="20" rx="4" fill="#FFFFFF"/><text x="85" y="664">${esc(t('app.routeStart'))}</text>
      <rect x="222" y="112" width="${t('app.routeEnd').length * 7 + 14}" height="20" rx="4" fill="#FFFFFF"/><text x="229" y="126">${esc(t('app.routeEnd'))}</text></g>
    <g transform="translate(16 452)">
      <rect width="358" height="150" rx="14" fill="#FFFFFF" stroke="#E2DBCD"/>
      <text x="18" y="34" font-size="20" font-weight="800" fill="#1F1B16">${esc(t('app.routeName'))}</text>
      <text x="18" y="56" font-size="13" font-weight="600" fill="#6B6458">${esc(t('app.routeStats'))}</text>
      <path d="M18 128 L48 112 78 118 108 96 138 104 168 84 198 92 228 74 258 88 288 78 318 100 340 110 V132 H18Z" fill="#FBE3D6"/>
      <path d="M18 128 L48 112 78 118 108 96 138 104 168 84 198 92 228 74 258 88 288 78 318 100 340 110" fill="none" stroke="#E8501A" stroke-width="2.5" stroke-linejoin="round"/>
      <rect x="18" y="132" width="322" height="1.5" fill="#E2DBCD"/>
    </g>
    <g transform="translate(346 312)"><rect x="-18" y="-18" width="36" height="72" rx="8" fill="#FFFFFF" stroke="#E2DBCD"/><path d="M-7 0h14M0-7v14M-7 36h14" stroke="#1F1B16" stroke-width="2.4" stroke-linecap="round"/><rect x="-18" y="17.5" width="36" height="1" fill="#E2DBCD"/></g>
  </svg>`;
}

/**
 * Un gato estilo anime, sentado al atardecer entre pétalos, para la mesa de luz. Es un gato inventado (gris
 * azulado con el pecho claro, sin lazos, collares ni marcas de ningún personaje). Devuelve la imagen a color y
 * el calco que se va dibujando en el papel: como un calco a lápiz, solo las líneas que se ven en la imagen (la
 * parte de cada contorno que no tapa ninguna forma pintada después), en trazos abiertos con pathLength="1".
 * Si cambia una forma, su calco y el de las que tapa se rehacen; `home-page.test.mjs` comprueba que cuadran.
 * Sin texto.
 */
export function cat() {
  // Un miembro: cápsula entre dos puntos, con el ancho dado.
  const limb = (x1, y1, x2, y2, w) => {
    const len = Math.hypot(x2 - x1, y2 - y1);
    const nx = (-(y2 - y1) / len) * (w / 2);
    const ny = ((x2 - x1) / len) * (w / 2);
    const f = (v) => v.toFixed(1);
    return `d="M${f(x1 + nx)} ${f(y1 + ny)} L${f(x2 + nx)} ${f(y2 + ny)} A${w / 2} ${w / 2} 0 0 0 ${f(x2 - nx)} ${f(y2 - ny)} L${f(x1 - nx)} ${f(y1 - ny)} A${w / 2} ${w / 2} 0 0 0 ${f(x1 + nx)} ${f(y1 + ny)}Z"`;
  };
  const LINE = '#3A2440';
  const FUR = '#9DB0DD';
  const FUR_DARK = '#7D90C4';
  const CREAM = '#FFF6EC';
  const EAR = '#FFB3C9';
  const IRIS = '#2F9C8A';
  const IRIS_LIGHT = '#7FE0C2';
  const PUPIL = '#1E2140';
  // Un ojo grande: iris, brillo bajo del iris y pupila (con trazo); los reflejos van aparte, sin trazo y
  // tapan parte de la pupila.
  const eye = (cx, iris, pupil) => [
    ['ellipse', `cx="${cx}" cy="368" rx="24" ry="29"`, IRIS, iris],
    ['ellipse', `cx="${cx}" cy="380" rx="16" ry="13"`, IRIS_LIGHT],
    ['ellipse', `cx="${cx}" cy="370" rx="10" ry="20"`, PUPIL, pupil],
  ];
  // [etiqueta SVG, geometría, relleno, calco], de atrás hacia delante. 'none' es una línea sin relleno. El
  // calco son los trazos visibles del contorno (sin calco, la forma no se calca).
  const shapes = [
    // La cola, curvada hacia arriba por la derecha
    ['path', 'd="M236 600 C296 616 350 586 346 520 C344 484 322 462 300 470 C286 476 288 496 302 496 C318 494 324 512 322 528 C318 566 290 582 240 574Z"', FUR, ['M241.9 601.4 C299.5 614 349.9 583.8 346 520 C344 484 322 462 300 470 C286 476 288 496 302 496 C318 494 324 512 322 528 C318.6 560.6 297.5 577 260.1 576']],
    // Las orejas, detrás de la cabeza
    ['path', 'd="M116 336 L122 236 L188 290Z"', FUR, ['M117.8 306.3 L122 236 L175.2 279.6']],
    ['path', 'd="M274 336 L268 236 L202 290Z"', FUR, ['M272.2 306.3 L268 236 L214.8 279.6']],
    ['path', 'd="M132 314 L136 260 L172 292Z"', EAR, ['M133.5 293.7 L136 260 L161 282.3']],
    ['path', 'd="M258 314 L254 260 L218 292Z"', EAR, ['M256.5 293.7 L254 260 L229 282.3']],
    // El cuerpo, sentado, con el pecho claro
    ['path', 'd="M195 418 C148 420 126 472 124 532 C122 584 142 614 195 614 C248 614 268 584 266 532 C264 472 242 420 195 418Z"', FUR, ['M159.8 431.7 C136.8 451.4 125.4 489.7 124 532 C122.8 564.2 129.9 587.9 148.2 601.4', 'M185 613.6 C188.2 613.9 191.5 614 195 614 C198.5 614 201.8 613.9 205 613.6', 'M241.8 601.4 C260.1 587.9 267.2 564.2 266 532 C264.6 489.7 253.2 451.4 230.2 431.7']],
    ['path', 'd="M195 436 C168 446 160 498 172 540 L195 566 L218 540 C230 498 222 446 195 436Z"', CREAM, ['M223.4 504.7 C224.3 472.9 214.7 443.3 195 436 C175.3 443.3 165.7 472.9 166.6 504.7', 'M184.8 554.5 L195 566 L205.2 554.5']],
    // Las patas de delante
    ['path', limb(170, 520, 168, 600, 32), FUR, ['M184 600.4 L186 520.4 C186.2 511.6 179.2 504.2 170.4 504 C161.6 503.8 154.2 510.8 154 519.6 L152 599.1']],
    ['path', limb(220, 520, 222, 600, 32), FUR, ['M238 599.1 L236 519.6 C235.8 510.8 228.4 503.8 219.6 504 C210.8 504.2 203.8 511.6 204 520.4 L206 600.4']],
    ['ellipse', 'cx="166" cy="608" rx="22" ry="12"', CREAM, ['M188 608 C188 614.6 178.2 620 166 620 C153.8 620 144 614.6 144 608 C144 601.4 153.8 596 166 596 C178.2 596 188 601.4 188 608Z']],
    ['ellipse', 'cx="224" cy="608" rx="22" ry="12"', CREAM, ['M246 608 C246 614.6 236.2 620 224 620 C211.8 620 202 614.6 202 608 C202 601.4 211.8 596 224 596 C236.2 596 246 601.4 246 608Z']],
    // La cabeza, ancha y redonda, con el hocico claro y tres rayas en la frente
    ['path', 'd="M195 278 C262 278 296 318 294 366 C292 410 250 436 195 436 C140 436 98 410 96 366 C94 318 128 278 195 278Z"', FUR, ['M195 278 C262 278 296 318 294 366 C292 410 250 436 195 436 C140 436 98 410 96 366 C94 318 128 278 195 278Z']],
    ['path', 'd="M195 384 C222 384 236 398 234 412 C232 426 214 432 195 432 C176 432 158 426 156 412 C154 398 168 384 195 384Z"', CREAM, ['M169.8 389.4 C176.1 386.1 184.6 384 195 384 C205.4 384 213.9 386.1 220.2 389.4', 'M227.8 395 C232.7 399.9 234.9 405.9 234 412 C232 426 214 432 195 432 C176 432 158 426 156 412 C155.1 405.9 157.3 399.9 162.2 395']],
    ['path', 'd="M195 288 L195 312 M178 292 L182 310 M212 292 L208 310"', 'none', ['M195 288 L195 312', 'M178 292 L182 310', 'M212 292 L208 310']],
    ...eye(154, ['M178 368 C178 384 167.3 397 154 397 C140.7 397 130 384 130 368 C130 352 140.7 339 154 339 C167.3 339 178 352 178 368Z'], ['M151.5 350.6 C152.3 350.2 153.1 350 154 350 C159.5 350 164 359 164 370 C164 374 163.4 377.7 162.4 380.8', 'M159.8 386.3 C158.2 388.6 156.2 390 154 390 C148.5 390 144 381 144 370 C144 367.7 144.2 365.6 144.5 363.6']),
    ...eye(236, ['M260 368 C260 384 249.3 397 236 397 C222.7 397 212 384 212 368 C212 352 222.7 339 236 339 C249.3 339 260 352 260 368Z'], ['M233.5 350.6 C234.3 350.2 235.1 350 236 350 C241.5 350 246 359 246 370 C246 374 245.4 377.7 244.4 380.8', 'M241.8 386.3 C240.2 388.6 238.2 390 236 390 C230.5 390 226 381 226 370 C226 367.7 226.2 365.6 226.5 363.6']),
    // Nariz, boca y bigotes
    ['path', 'd="M187 398 L203 398 L195 407Z"', EAR, ['M187 398 L203 398 L195 407Z']],
    ['path', 'd="M180 412 C184 421 193 421 195 410 C197 421 206 421 210 412"', 'none', ['M180 412 C184 421 193 421 195 410 C197 421 206 421 210 412']],
    ['path', 'd="M112 388 L66 378 M112 400 L64 404 M278 388 L324 378 M278 400 L326 404"', 'none', ['M112 388 L66 378', 'M112 400 L64 404', 'M278 388 L324 378', 'M278 400 L326 404']],
  ];
  const head = 'viewBox="0 0 390 844" preserveAspectRatio="xMidYMid slice" aria-hidden="true"';
  // El gato se dibuja algo más grande, con la misma escala en la imagen y en el calco.
  const zoom = 'transform="translate(195 440) scale(1.18) translate(-195 -440)"';
  // Pétalos de cerezo: [x, y, giro, color]
  const petals = [
    [52, 110, -20, '#FFFFFF'], [318, 96, 30, '#FFC2D6'], [214, 172, 60, '#FFFFFF'], [36, 300, 10, '#FFC2D6'],
    [352, 250, -40, '#FFFFFF'], [70, 470, 45, '#FFFFFF'], [340, 430, -15, '#FFC2D6'], [96, 210, 80, '#FFC2D6'],
    [290, 680, 20, '#FFFFFF'], [60, 720, -50, '#FFC2D6'], [180, 760, 35, '#FFFFFF'], [356, 760, -30, '#FFC2D6'],
  ];
  const art = `<svg ${head}>
    <rect width="390" height="844" fill="#FF8DB5"/>
    <rect y="230" width="390" height="190" fill="#FFA88C"/>
    <rect y="420" width="390" height="200" fill="#FFC77A"/>
    <circle cx="300" cy="560" r="96" fill="#FFE9A8"/>
    <path d="M0 620 C80 596 150 604 200 616 C260 600 330 596 390 610 V844 H0Z" fill="#D4145A"/>
    <path d="M0 668 C90 650 180 660 240 672 C300 662 350 660 390 668 V844 H0Z" fill="#A80F4B"/>
    <ellipse cx="198" cy="658" rx="122" ry="13" fill="#5A0B30" opacity="0.35"/>
    ${petals.map(([x, y, r, c]) => `<path d="M0 -9 C8 -6 8 6 0 9 C-3 4 -3 -4 0 -9Z" transform="translate(${x} ${y}) rotate(${r})" fill="${c}"/>`).join('')}
    <g ${zoom}>
    ${shapes.map(([tag, geo, fill]) => (fill === 'none'
      ? `<${tag} ${geo} fill="none" stroke="${LINE}" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>`
      : `<${tag} ${geo} fill="${fill}" stroke="${LINE}" stroke-width="${fill === IRIS_LIGHT ? 0 : 4}" stroke-linejoin="round"/>`)).join('')}
    <g fill="${FUR_DARK}"><path d="M128 552 C140 548 146 556 144 566 C136 566 130 560 128 552Z"/><path d="M262 552 C250 548 244 556 246 566 C254 566 260 560 262 552Z"/></g>
    <g fill="#FFFFFF"><circle cx="146" cy="356" r="8"/><circle cx="228" cy="356" r="8"/><circle cx="162" cy="384" r="3.5"/><circle cx="244" cy="384" r="3.5"/></g>
    <g fill="#FF8FB1" opacity="0.85"><ellipse cx="130" cy="404" rx="17" ry="8"/><ellipse cx="260" cy="404" rx="17" ry="8"/></g>
    </g>
  </svg>`;
  const lines = shapes.flatMap((sh) => sh[3] ?? []);
  const trace = `<svg ${head}><g ${zoom}>${lines.map((d) => `<path d="${d}" pathLength="1"/>`).join('')}</g></svg>`;
  return { art, trace };
}
