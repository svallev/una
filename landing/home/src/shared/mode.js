// Recorrido o versión apilada (CA-025-10, CA-025-16 y CL-025-13). Sin `window` ni `document`: se prueba en Node.

// Alto mínimo de la ventana, en píxeles CSS, para el recorrido: por debajo, las escenas no caben enteras y se
// recibe la versión apilada, la misma que con «reducir movimiento». Es un umbral medido, no una medición de
// cada escena: con la página apilada el alto de las escenas no dice si caben en el recorrido (las piezas del
// móvil van en posición absoluta y la portada sube el texto con un margen negativo), y en el recorrido las
// escenas están en 3D. En Chrome (CDP): con 540 de alto o más todo cabe (960, 1024 y 1280 de ancho, y 568 a
// 320); con 500, 480, 412 y 390 algo queda fuera. El zoom del navegador baja el alto en píxeles CSS y cuenta igual.
export const MIN_JOURNEY_HEIGHT = 540;

/** La consulta de medios que dice si la ventana es lo bastante alta para el recorrido. */
export const TALL_ENOUGH = `(min-height: ${MIN_JOURNEY_HEIGHT}px)`;

/** «journey» (recorrido) o «stacked» (apilada), según reducir movimiento y si la ventana es bastante alta. */
export function pickMode({ reduceMotion, tallEnough }) {
  return !reduceMotion && tallEnough === true ? 'journey' : 'stacked';
}
