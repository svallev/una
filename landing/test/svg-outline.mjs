// Geometría mínima de SVG para comprobar el calco de la mesa de luz: lee formas `path`, `ellipse` y `circle`
// con coordenadas absolutas (M, L, C, A, Z), las pasa a cúbicas y responde a «¿este punto está dentro de esta
// forma?» y «¿a qué distancia queda de su borde?». Solo lo que usa el dibujo del gato, no SVG entero.

/** Atributos de una etiqueta (`a="b"`) como objeto. */
export function attrs(text) {
  return Object.fromEntries([...text.matchAll(/([\w-]+)="([^"]*)"/g)].map((m) => [m[1], m[2]]));
}

const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];

/** Una línea recta como cúbica. */
const lineCubic = (p, q) => [p, lerp(p, q, 1 / 3), lerp(p, q, 2 / 3), q];

/** Un arco de SVG (de p a q) como cúbicas, con la conversión de la especificación (apéndice F.6). */
function arcCubics(p, rx, ry, phiDeg, large, sweep, q) {
  const phi = (phiDeg * Math.PI) / 180;
  const [cos, sin] = [Math.cos(phi), Math.sin(phi)];
  const dx = (p[0] - q[0]) / 2;
  const dy = (p[1] - q[1]) / 2;
  const x1 = cos * dx + sin * dy;
  const y1 = -sin * dx + cos * dy;
  const lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry);
  if (lambda > 1) [rx, ry] = [rx * Math.sqrt(lambda), ry * Math.sqrt(lambda)];
  const num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1;
  const den = rx * rx * y1 * y1 + ry * ry * x1 * x1;
  const k = (large === sweep ? -1 : 1) * Math.sqrt(Math.max(0, num / den));
  const cx1 = (k * rx * y1) / ry;
  const cy1 = (-k * ry * x1) / rx;
  const cx = cos * cx1 - sin * cy1 + (p[0] + q[0]) / 2;
  const cy = sin * cx1 + cos * cy1 + (p[1] + q[1]) / 2;
  const ang = (ux, uy, vx, vy) => Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
  const t1 = ang(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry);
  let dt = ang((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry);
  if (!sweep && dt > 0) dt -= 2 * Math.PI;
  if (sweep && dt < 0) dt += 2 * Math.PI;
  const n = Math.ceil(Math.abs(dt) / (Math.PI / 2));
  const step = dt / n;
  const at = (a) => [cx + rx * Math.cos(a) * cos - ry * Math.sin(a) * sin, cy + rx * Math.cos(a) * sin + ry * Math.sin(a) * cos];
  const der = (a) => [-rx * Math.sin(a) * cos - ry * Math.cos(a) * sin, -rx * Math.sin(a) * sin + ry * Math.cos(a) * cos];
  const h = (4 / 3) * Math.tan(step / 4);
  const out = [];
  for (let i = 0; i < n; i++) {
    const a0 = t1 + i * step;
    const a1 = a0 + step;
    const [s, e, d0, d1] = [at(a0), at(a1), der(a0), der(a1)];
    out.push([s, [s[0] + h * d0[0], s[1] + h * d0[1]], [e[0] - h * d1[0], e[1] - h * d1[1]], e]);
  }
  return out;
}

/** Los subtrazos de una forma: listas de cúbicas, cada una con `closed`. */
export function subpaths(tag, a) {
  if (tag === "ellipse" || tag === "circle") {
    const [cx, cy] = [Number(a.cx), Number(a.cy)];
    const [rx, ry] = tag === "circle" ? [Number(a.r), Number(a.r)] : [Number(a.rx), Number(a.ry)];
    const s = [cx + rx, cy];
    const cubics = [
      ...arcCubics(s, rx, ry, 0, 0, 1, [cx - rx, cy]),
      ...arcCubics([cx - rx, cy], rx, ry, 0, 0, 1, s),
    ];
    return [{ cubics, closed: true }];
  }
  const tokens = a.d.match(/[MLCAZ]|-?\d*\.?\d+(?:e-?\d+)?/gi);
  const out = [];
  let cur = null;
  let start = null;
  let pen = null;
  let i = 0;
  const num = () => Number(tokens[i++]);
  const pt = () => [num(), num()];
  let cmd = null;
  while (i < tokens.length) {
    if (/[A-Za-z]/.test(tokens[i])) cmd = tokens[i++];
    if (!/^[MLCAZ]$/.test(cmd)) throw new Error(`orden de trazo no admitida: ${cmd}`);
    if (cmd === "M") {
      pen = start = pt();
      cur = { cubics: [], closed: false };
      out.push(cur);
      cmd = "L";
    } else if (cmd === "L") {
      const q = pt();
      cur.cubics.push(lineCubic(pen, q));
      pen = q;
    } else if (cmd === "C") {
      const c = [pen, pt(), pt(), pt()];
      cur.cubics.push(c);
      pen = c[3];
    } else if (cmd === "A") {
      const [rx, ry, phi, large, sweep] = [num(), num(), num(), num(), num()];
      const q = pt();
      cur.cubics.push(...arcCubics(pen, rx, ry, phi, large, sweep, q));
      pen = q;
    } else if (cmd === "Z") {
      if (Math.hypot(pen[0] - start[0], pen[1] - start[1]) > 1e-6) cur.cubics.push(lineCubic(pen, start));
      cur.closed = true;
      pen = start;
    }
  }
  return out;
}

/** Punto de una cúbica en t. */
export function cubicAt([p0, p1, p2, p3], t) {
  const u = 1 - t;
  const [a, b, c, d] = [u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t];
  return [a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]];
}

/** Los puntos de una forma, uno cada `step` unidades más o menos, por subtrazo. */
export function samplePoints(paths, step = 0.5) {
  const out = [];
  for (const { cubics } of paths) {
    for (const c of cubics) {
      const approx = Math.hypot(c[1][0] - c[0][0], c[1][1] - c[0][1]) + Math.hypot(c[2][0] - c[1][0], c[2][1] - c[1][1]) + Math.hypot(c[3][0] - c[2][0], c[3][1] - c[2][1]);
      const n = Math.max(2, Math.ceil(approx / step));
      for (let k = 0; k <= n; k++) out.push(cubicAt(c, k / n));
    }
  }
  return out;
}

/** Una forma con relleno, lista para preguntar dentro / distancia al borde (polígonos de alta resolución). */
export function solid(paths) {
  const rings = paths.map(({ cubics }) => samplePoints([{ cubics }], 0.25));
  return {
    contains([x, y]) {
      // Regla «nonzero», la de SVG por defecto
      let w = 0;
      for (const r of rings) {
        for (let k = 0; k < r.length; k++) {
          const [a, b] = [r[k], r[(k + 1) % r.length]];
          if (a[1] <= y) {
            if (b[1] > y && (b[0] - a[0]) * (y - a[1]) - (x - a[0]) * (b[1] - a[1]) > 0) w++;
          } else if (b[1] <= y && (b[0] - a[0]) * (y - a[1]) - (x - a[0]) * (b[1] - a[1]) < 0) w--;
        }
      }
      return w !== 0;
    },
    distance: (p) => distanceToRings(rings, p, true),
  };
}

/** Distancia de p a una polilínea (o a varias), cerrada o abierta. */
export function distanceToRings(rings, [x, y], closed = false) {
  let best = Infinity;
  for (const r of rings) {
    const last = closed ? r.length : r.length - 1;
    for (let k = 0; k < last; k++) {
      const [a, b] = [r[k], r[(k + 1) % r.length]];
      const [vx, vy] = [b[0] - a[0], b[1] - a[1]];
      const l2 = vx * vx + vy * vy;
      const t = l2 ? Math.max(0, Math.min(1, ((x - a[0]) * vx + (y - a[1]) * vy) / l2)) : 0;
      best = Math.min(best, Math.hypot(x - a[0] - t * vx, y - a[1] - t * vy));
    }
  }
  return best;
}

/**
 * Las formas de un dibujo de SVG dentro del grupo con `transform` (el gato), en orden de pintado: cada una con
 * `tag`, sus atributos, si tapa lo de detrás (`opaque`: relleno sin transparencia) y si tiene línea (`stroked`).
 */
export function drawing(svg) {
  const start = svg.indexOf("<g transform=");
  if (start < 0) throw new Error("el dibujo no tiene el grupo del gato");
  const out = [];
  const groups = [];
  for (const m of svg.slice(start).matchAll(/<(\/?)(g|path|ellipse|circle)\b([^>]*?)(\/?)>/g)) {
    const [, close, tag, text] = m;
    if (tag === "g") {
      if (close) {
        groups.pop();
        if (!groups.length) break;
      } else groups.push(attrs(text));
      continue;
    }
    const a = { ...Object.assign({}, ...groups.map(({ fill, opacity }) => ({ ...(fill && { fill }), ...(opacity && { opacity }) }))), ...attrs(text) };
    const fill = a.fill ?? "black";
    out.push({
      tag,
      a,
      opaque: fill !== "none" && Number(a.opacity ?? 1) >= 0.95,
      stroked: a.stroke !== undefined && a.stroke !== "none" && Number(a["stroke-width"] ?? 1) > 0,
    });
  }
  return out;
}
