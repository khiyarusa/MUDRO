#!/usr/bin/env node
/**
 * MUDRO 3.0 — procedural environment art generator (SVG, hand-built paths).
 *
 * Draws the three missing region sets:
 *   assets/environments/zagros/  {sky,far,mid,near}.svg 1920x1080 + ground.svg 512
 *   assets/environments/alpine/  (same)
 *   assets/environments/glacier/ (same)
 * and ten region decor props (512x512, bottom-centred, ~1 m = 160 px).
 *
 * Everything is generated from seeded maths — no samples, no downloads, no
 * raster tracing. Layers the game tiles horizontally (far/mid/near) are built
 * from functions that are exactly periodic over the tile width, so the left and
 * right edge match to the pixel. Every emitted coordinate is clipped to the
 * canvas, including the wrapped copies used by the 512 px ground tiles.
 *
 * Run:  node tools/asset_processing/gen_environments_v3.mjs
 */

import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] && !process.argv[2].startsWith('-') ? process.argv[2] : process.cwd());
const W = 1920;
const H = 1080;
const G = 512; // ground tile / prop canvas
const TAU = Math.PI * 2;

/* ------------------------------------------------------------------ maths -- */

function rng(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), 1 | t);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (e0, e1, x) => {
  const t = clamp((x - e0) / (e1 - e0), 0, 1);
  return t * t * (3 - 2 * t);
};
const rr = (r, a, b) => lerp(a, b, r());
const pick = (r, arr) => arr[Math.min(arr.length - 1, Math.floor(r() * arr.length))];

/** One decimal, no trailing ".0" noise. Keeps the SVG small. */
const f1 = (v) => {
  const x = Math.round(v * 10) / 10;
  return Number.isInteger(x) ? String(x) : x.toFixed(1);
};
const f0 = (v) => String(Math.round(v));

/* ---------------------------------------------------------------- colours -- */

function rgbOf(hex) {
  const v = parseInt(hex.slice(1), 16);
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
}
function hexOf(c) {
  return '#' + c.map((v) => clamp(Math.round(v), 0, 255).toString(16).padStart(2, '0')).join('');
}
function mix(a, b, t) {
  const A = rgbOf(a);
  const B = rgbOf(b);
  return hexOf([lerp(A[0], B[0], t), lerp(A[1], B[1], t), lerp(A[2], B[2], t)]);
}
const dark = (c, t) => mix(c, '#000000', t);
const lite = (c, t) => mix(c, '#ffffff', t);

/* ------------------------------------------------------------------ paths -- */

function polyPath(pts, close = true) {
  return 'M' + pts.map((p) => f1(p[0]) + ',' + f1(p[1])).join(' L') + (close ? ' Z' : '');
}

function ellipsePts(cx, cy, rx, ry, n = 18, ph = 0) {
  const out = [];
  for (let i = 0; i < n; i++) {
    const a = (i / n) * TAU + ph;
    out.push([cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]);
  }
  return out;
}

/** Sutherland–Hodgman clip to a rectangle: keeps every coordinate in-frame. */
function clipRect(pts, xmin, ymin, xmax, ymax) {
  const edge = (poly, inside, isect) => {
    const out = [];
    for (let i = 0; i < poly.length; i++) {
      const a = poly[i];
      const b = poly[(i + 1) % poly.length];
      const ai = inside(a);
      const bi = inside(b);
      if (ai) out.push(a);
      if (ai !== bi) out.push(isect(a, b));
    }
    return out;
  };
  let p = pts;
  p = edge(p, (q) => q[0] >= xmin, (a, b) => [xmin, a[1] + ((b[1] - a[1]) * (xmin - a[0])) / (b[0] - a[0])]);
  if (!p.length) return p;
  p = edge(p, (q) => q[0] <= xmax, (a, b) => [xmax, a[1] + ((b[1] - a[1]) * (xmax - a[0])) / (b[0] - a[0])]);
  if (!p.length) return p;
  p = edge(p, (q) => q[1] >= ymin, (a, b) => [a[0] + ((b[0] - a[0]) * (ymin - a[1])) / (b[1] - a[1]), ymin]);
  if (!p.length) return p;
  p = edge(p, (q) => q[1] <= ymax, (a, b) => [a[0] + ((b[0] - a[0]) * (ymax - a[1])) / (b[1] - a[1]), ymax]);
  return p;
}

/** Irregular closed blob (rock, scrub mass, serac). */
function blobPts(cx, cy, rx, ry, r, n = 12, rough = 0.16) {
  const p1 = r() * TAU;
  const p2 = r() * TAU;
  const p3 = r() * TAU;
  const out = [];
  for (let i = 0; i < n; i++) {
    const a = (i / n) * TAU;
    const k = 1 + rough * Math.sin(a * 2 + p1) + rough * 0.6 * Math.sin(a * 3 + p2) + rough * 0.35 * Math.sin(a * 5 + p3);
    out.push([cx + Math.cos(a) * rx * k, cy + Math.sin(a) * ry * k]);
  }
  return out;
}

/* ------------------------------------------------------------------- svg ---- */

function newDoc(w, h) {
  const defs = [];
  const body = [];
  return {
    w,
    h,
    def(id, s) {
      defs.push(s.replace('{id}', id));
      return `url(#${id})`;
    },
    add(s) {
      body.push(s);
      return this;
    },
    svg() {
      return (
        '<?xml version="1.0" encoding="UTF-8"?>\n' +
        `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">\n` +
        '<defs>\n' +
        defs.join('\n') +
        '\n</defs>\n' +
        body.join('\n') +
        '\n</svg>\n'
      );
    },
  };
}

function lg(id, stops, x1, y1, x2, y2) {
  return (
    `<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${f1(x1)}" y1="${f1(y1)}" x2="${f1(x2)}" y2="${f1(y2)}">` +
    stops.map((s) => `<stop offset="${s[0]}" stop-color="${s[1]}" stop-opacity="${s[2] === undefined ? 1 : s[2]}"/>`).join('') +
    '</linearGradient>'
  );
}
function rg(id, stops, cx, cy, rad) {
  return (
    `<radialGradient id="${id}" gradientUnits="userSpaceOnUse" cx="${f1(cx)}" cy="${f1(cy)}" r="${f1(rad)}">` +
    stops.map((s) => `<stop offset="${s[0]}" stop-color="${s[1]}" stop-opacity="${s[2] === undefined ? 1 : s[2]}"/>`).join('') +
    '</radialGradient>'
  );
}
function lgBox(id, stops) {
  return (
    `<linearGradient id="${id}" gradientUnits="objectBoundingBox" x1="0" y1="0" x2="0" y2="1">` +
    stops.map((s) => `<stop offset="${s[0]}" stop-color="${s[1]}" stop-opacity="${s[2] === undefined ? 1 : s[2]}"/>`).join('') +
    '</linearGradient>'
  );
}

/* -------------------------------------------------------------- landforms --- */

/** Sum of sines whose periods divide the tile width exactly -> seamless. */
function makeWave(r, terms = 3, cycles = 2, growth = 2.7, decay = 0.52) {
  const list = [];
  for (let i = 0; i < terms; i++) {
    const k = Math.max(1, Math.round(cycles * Math.pow(growth, i)));
    list.push([k, Math.pow(decay, i) * (0.7 + 0.6 * r()), r() * TAU]);
  }
  const norm = list.reduce((s, l) => s + l[1], 0) || 1;
  return (x) => {
    let s = 0;
    for (const [k, a, p] of list) s += a * Math.sin((TAU * k * x) / W + p);
    return s / norm;
  };
}

/** Evenly spread summits with jitter; flat=true makes mesas, else sharp peaks. */
function makePeaks(r, o) {
  const n = o.n;
  const out = [];
  for (let i = 0; i < n; i++) {
    const t = (i + 0.5 + (r() - 0.5) * 0.55) / n;
    out.push({
      x: lerp(o.x0 === undefined ? 0 : o.x0, o.x1 === undefined ? W : o.x1, t),
      h: rr(r, o.hMin, o.hMax),
      w: rr(r, o.wMin, o.wMax),
      flat: !!o.flat,
      pow: o.pow === undefined ? 1 : o.pow,
    });
  }
  return out;
}

function profileFn(peaks, baseY, opts) {
  const rough = typeof opts === 'function' ? opts : opts && opts.rough ? opts.rough : null;
  const notches = (typeof opts === 'object' && opts && opts.notches) || [];
  const roughAmp = typeof opts === 'object' && opts && opts.roughAmp !== undefined ? opts.roughAmp : 3.2;
  return function (x) {
    let best = 0;
    for (const p of peaks) {
      for (let k = -1; k <= 1; k++) {
        const t = Math.abs(x - (p.x + k * W)) / p.w;
        if (t >= 1) continue;
        const shape = p.flat ? 1 - smooth(0.62, 1, t) : Math.pow(1 - t, p.pow);
        const v = p.h * shape;
        if (v > best) best = v;
      }
    }
    let y = baseY - best;
    if (rough) y += rough(x) * roughAmp * Math.min(1, best / 46);
    for (const n of notches) {
      for (let k = -1; k <= 1; k++) {
        const d = Math.abs(x - (n.x + k * W)) / n.w;
        if (d < 1) y += n.depth * Math.pow(1 - d, 1.5) * Math.min(1, best / 40);
      }
    }
    return y;
  };
}

/** Explicit landform list: [x, height, halfWidth, flat, power]. */
const forms = (list) => list.map(([x, h, w, flat, pow]) => ({ x, h, w, flat: !!flat, pow: pow || 1 }));

/** V-shaped notches cut into a rim: the eroded gullies that break a flat top. */
function makeNotches(r, n, dMin, dMax, wMin, wMax, x0 = 0, x1 = W) {
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push({
      x: lerp(x0, x1, (i + 0.5 + (r() - 0.5) * 0.8) / n),
      depth: rr(r, dMin, dMax),
      w: rr(r, wMin, wMax),
    });
  }
  return out;
}

/** Fill from a skyline down to a base line (or the canvas bottom). */
function massPath(top, baseY, step = 6) {
  let d = '';
  for (let x = 0; x <= W; x += step) {
    d += (x === 0 ? 'M' : 'L') + f1(x) + ',' + f1(top(x)) + ' ';
  }
  d += `L${W},${f1(baseY)} L0,${f1(baseY)} Z`;
  return d;
}

/** Horizontal runs (in x) where a horizontal band actually sits on the mass. */
function bandRuns(top, y, step = 8, inset = 4) {
  const runs = [];
  let cur = null;
  for (let x = 0; x <= W; x += step) {
    const inside = y > top(x) + inset;
    if (inside) {
      if (!cur) cur = [x, x];
      else cur[1] = x;
    } else if (cur) {
      runs.push(cur);
      cur = null;
    }
  }
  if (cur) runs.push(cur);
  return runs;
}

/** Rock face: fill + rim light + strata + erosion gullies. */
function rockFace(doc, o) {
  const { top, baseY, gid, rim, rimOp = 0.4, step = 6 } = o;
  const fillTo = o.fillTo || baseY;
  doc.add(`<path d="${massPath(top, fillTo, step)}" fill="url(#${gid})"/>`);
  // rim light along the skyline, broken into chunks of varying strength
  if (rim) {
    const chunk = 30 * step;
    for (let x0 = 1; x0 < W - 1; x0 += chunk) {
      const x1 = Math.min(W - 1, x0 + chunk);
      let d = '';
      let first = true;
      for (let x = x0; x <= x1; x += step) {
        const xx = Math.min(x, x1);
        d += (first ? 'M' : 'L') + f1(xx) + ',' + f1(top(xx)) + ' ';
        first = false;
      }
      const op = rimOp * (0.45 + 0.75 * ((Math.sin((x0 / W) * TAU * 3.1) + 1) / 2));
      doc.add(
        `<path d="${d}" fill="none" stroke="${rim}" stroke-width="${f1(o.rimW || 2.2)}" stroke-opacity="${f1(op * 100) / 100}" stroke-linecap="round" stroke-linejoin="round"/>`
      );
    }
  }
  // strata: sedimentary ledges, broken where the skyline cuts them
  for (const st of o.strata || []) {
    const runs = bandRuns(top, st.y, 8, st.inset === undefined ? 5 : st.inset);
    for (const [a, b] of runs) {
      if (b - a < 16) continue;
      let d = '';
      let first = true;
      for (let x = a; x <= b; x += 8) {
        const y =
          st.y +
          Math.sin((TAU * st.k * x) / W + st.p) * st.amp +
          Math.sin((TAU * (st.k * 2 + 1) * x) / W + st.p * 1.7) * st.amp * 0.42;
        d += (first ? 'M' : 'L') + f1(x) + ',' + f1(y) + ' ';
        first = false;
      }
      doc.add(
        `<path d="${d}" fill="none" stroke="${st.color}" stroke-width="${f1(st.w)}" stroke-opacity="${st.op}" stroke-linecap="round" stroke-linejoin="round"/>`
      );
    }
  }
  // gullies: vertical erosion channels, lit on the sun side, fading into talus
  for (const g of o.gullies || []) {
    const y0 = top(g.x) + (g.inset === undefined ? 8 : g.inset);
    if (y0 > baseY - 90) continue;
    const y1 = baseY - (g.tail === undefined ? 46 : g.tail);
    const xc = g.x;
    const d =
      `M${f1(xc - g.wTop / 2)},${f1(y0)} ` +
      `C${f1(xc - g.wTop / 2 - 4)},${f1(y0 + (y1 - y0) * 0.4)} ${f1(xc + g.drift - g.wBot / 2)},${f1(y1 - (y1 - y0) * 0.3)} ${f1(xc + g.drift - g.wBot / 2)},${f1(y1)} ` +
      `L${f1(xc + g.drift + g.wBot / 2)},${f1(y1)} ` +
      `C${f1(xc + g.drift + g.wBot / 2)},${f1(y1 - (y1 - y0) * 0.35)} ${f1(xc + g.wTop / 2 + 4)},${f1(y0 + (y1 - y0) * 0.35)} ${f1(xc + g.wTop / 2)},${f1(y0)} Z`;
    doc.add(`<path d="${d}" fill="${g.shadow}" fill-opacity="${g.op}"/>`);
    // lit spur on the sun side of the channel: this is what reads as a cliff
    if (g.light) {
      const sw = g.spur === undefined ? 16 : g.spur;
      const dl =
        `M${f1(xc - g.wTop / 2 - sw)},${f1(y0 + 6)} ` +
        `C${f1(xc - g.wTop / 2 - sw * 0.7)},${f1(y0 + (y1 - y0) * 0.45)} ${f1(xc + g.drift - g.wBot / 2 - sw * 0.5)},${f1(y1 - (y1 - y0) * 0.35)} ${f1(xc + g.drift - g.wBot / 2 - 2)},${f1(y1)} ` +
        `L${f1(xc + g.drift - g.wBot / 2 + 2)},${f1(y1)} ` +
        `C${f1(xc + g.drift - g.wBot / 2 + 1)},${f1(y1 - (y1 - y0) * 0.4)} ${f1(xc - g.wTop / 2 + 2)},${f1(y0 + (y1 - y0) * 0.4)} ${f1(xc - g.wTop / 2 + 5)},${f1(y0 + 3)} Z`;
      doc.add(`<path d="${dl}" fill="${g.light}" fill-opacity="${f1(g.lop * 100) / 100}"/>`);
    }
  }
}

/** Snow that sits on a skyline above a snow line, with a ragged lower edge. */
function snowCaps(doc, o) {
  const { top, snowLine, depth, color, wave, op = 1 } = o;
  const runs = [];
  let cur = null;
  for (let x = 0; x <= W; x += 6) {
    const inside = top(x) < snowLine;
    if (inside) {
      if (!cur) cur = [x, x];
      else cur[1] = x;
    } else if (cur) {
      runs.push(cur);
      cur = null;
    }
  }
  if (cur) runs.push(cur);
  for (const [a, b] of runs) {
    if (b - a < 26) continue;
    const pts = [];
    for (let x = a; x <= b; x += 6) pts.push([x, top(x)]);
    for (let x = b; x >= a; x -= 6) {
      const dd = depth * (0.55 + 0.45 * (wave ? wave(x) : 0));
      pts.push([x, top(x) + Math.max(6, dd)]);
    }
    doc.add(`<path d="${polyPath(pts)}" fill="${color}" fill-opacity="${op}"/>`);
  }
}

/* ------------------------------------------------------------------ skies --- */

function cloudShape(cx, cy, w, h, r, N = 15) {
  const p1 = r() * TAU;
  const p2 = r() * TAU;
  const top = [];
  const bot = [];
  for (let i = 0; i <= N; i++) {
    const t = i / N;
    const env = Math.sin(Math.PI * t);
    const x = cx - w / 2 + w * t;
    top.push([x, cy - h * env * (0.5 + 0.5 * Math.sin(t * 5.6 + p1)) - h * 0.1]);
    bot.push([x, cy + h * env * (0.4 + 0.24 * Math.sin(t * 3.7 + p2))]);
  }
  // clipped: clouds are the one element that can run past the frame edge
  return polyPath(clipRect(top.concat(bot.reverse()), 0, 0, W, H));
}

function vignette(doc) {
  doc.def('vgRad', rg('{id}', [[0, '#000000', 0], [0.52, '#000000', 0], [0.78, '#000000', 0.04], [0.92, '#000000', 0.14], [1, '#000000', 0.3]], 960, 500, 1100));
  doc.def('vgTop', lg('{id}', [[0, '#000000', 0.26], [0.42, '#000000', 0], [1, '#000000', 0]], 0, 0, 0, H));
  doc.def('vgBot', lg('{id}', [[0, '#000000', 0], [0.62, '#000000', 0], [1, '#000000', 0.3]], 0, 0, 0, H));
  doc.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#vgRad)"/>`);
  doc.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#vgTop)"/>`);
  doc.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#vgBot)"/>`);
}

/* ================================================================ ZAGROS === */
// Dry limestone highlands: warm dust, pale mesas, eroded gullies, dry scrub.

const Z = {
  skyTop: '#d9c3a0',
  skyHorizon: '#f0dcbd',
  sand: '#b99a6b',
  lime: '#cbbfa6',
  ochre: '#6d5334',
  haze: '#f3e1c2',
};

function zagrosSky() {
  const d = newDoc(W, H);
  const r = rng(7101);
  d.def('sky', lg('{id}', [[0, Z.skyTop], [0.24, '#e1cdac'], [0.5, '#ebd9ba'], [0.72, '#f0dcbd'], [0.88, '#f2e1c5'], [1, '#f4e5cb']], 0, 0, 0, H));
  d.def('sunWide', rg('{id}', [[0, '#fff6de', 0.5], [0.2, '#fff0d2', 0.3], [0.56, '#ffe6ba', 0.11], [1, '#ffe6ba', 0]], 1402, 584, 820));
  d.def('sunMid', rg('{id}', [[0, '#fffaf0', 0.6], [0.34, '#fff2d8', 0.3], [0.72, '#ffe4b6', 0.07], [1, '#ffe4b6', 0]], 1402, 584, 250));
  d.def('sunCore', rg('{id}', [[0, '#fffdf6', 1], [0.72, '#fff8e8', 0.92], [1, '#ffefcf', 0.35]], 1402, 584, 30));
  d.def('clBody', lgBox('{id}', [[0, '#ffffff', 0.08], [0.34, '#fdf6ea', 0.8], [0.72, '#f3e4c9', 0.45], [1, '#ecd9b8', 0]]));
  d.def('dustHaze', lg('{id}', [[0, '#f7e7c9', 0], [0.42, '#f6e3c1', 0.3], [0.72, '#f2dcb6', 0.42], [1, '#eed4a9', 0.46]], 0, 548, 0, H));
  d.def('horizonGlow', rg('{id}', [[0, '#ffeccb', 0.26], [0.5, '#ffe4bb', 0.09], [1, '#ffe4bb', 0]], 960, 782, 1080));

  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sky)"/>`);
  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sunWide)"/>`);
  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sunMid)"/>`);
  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sunCore)"/>`);

  // high thin cirrus, drawn as long feathered ribbons
  const bands = [
    [300, 108, 620, 26], [980, 152, 760, 30], [1540, 96, 520, 22],
    [210, 236, 700, 24], [820, 268, 560, 18], [1420, 316, 660, 26],
    [520, 372, 900, 22], [1290, 420, 700, 20], [120, 470, 640, 18],
    [980, 512, 820, 16],
  ];
  for (const [cx, cy, w, h] of bands) {
    d.add(`<path d="${cloudShape(cx, cy, w, h, r)}" fill="url(#clBody)" fill-opacity="0.55"/>`);
  }
  // dust sheet hugging the horizon
  const veils = [[420, 640, 1180, 54], [1300, 676, 1240, 46], [900, 712, 1500, 60]];
  for (const [cx, cy, w, h] of veils) {
    d.add(`<path d="${cloudShape(cx, cy, w, h, r)}" fill="url(#clBody)" fill-opacity="0.7"/>`);
  }
  // fine dust streaks
  for (let i = 0; i < 14; i++) {
    const y = 430 + r() * 270;
    const len = 90 + r() * 260;
    const x = 12 + r() * (W - 24 - len);
    const op = 0.06 + r() * 0.08;
    d.add(`<path d="M${f1(x)},${f1(y)} Q${f1(x + len * 0.5)},${f1(y - 5 - r() * 6)} ${f1(x + len)},${f1(y + 2)}" fill="none" stroke="#fff4de" stroke-width="${f1(1 + r() * 2.4)}" stroke-opacity="${f1(op * 100) / 100}" stroke-linecap="round"/>`);
  }
  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#horizonGlow)"/>`);
  d.add(`<rect x="0" y="548" width="${W}" height="${H - 548}" fill="url(#dustHaze)"/>`);
  vignette(d);
  return d.svg();
}

function zagrosFar() {
  const d = newDoc(W, H);
  const r = rng(7102);
  const rough = makeWave(r, 3, 9, 2.4, 0.5);

  const t1 = profileFn(forms([[280, 44, 230, 1], [700, 30, 300, 1], [1120, 52, 250, 1], [1520, 34, 270, 1], [1830, 42, 210, 1]]), 636, { rough, roughAmp: 2.2 });
  const t2 = profileFn(forms([[190, 132, 240, 1], [610, 172, 280, 1], [1010, 96, 220, 1], [1380, 180, 290, 1], [1740, 118, 220, 1]]), 724, { rough, roughAmp: 3.0, notches: makeNotches(r, 9, 28, 60, 24, 56) });
  const t3 = profileFn(forms([[330, 254, 310, 1], [900, 196, 240, 1], [1310, 270, 290, 1], [1700, 214, 230, 1]]), 830, { rough, roughAmp: 3.6, notches: makeNotches(r, 16, 26, 78, 16, 46) });

  d.def('p1', lg('{id}', [[0, mix(Z.lime, Z.haze, 0.6)], [1, mix(Z.lime, Z.haze, 0.78)]], 0, 560, 0, 660));
  d.def('p2', lg('{id}', [[0, mix(Z.lime, Z.haze, 0.32)], [0.55, mix(Z.sand, Z.haze, 0.44)], [1, mix(Z.sand, Z.haze, 0.58)]], 0, 520, 0, 740));
  d.def('p3', lg('{id}', [[0, mix(Z.lime, Z.haze, 0.08)], [0.3, mix(Z.lime, Z.haze, 0.24)], [0.7, mix(Z.sand, Z.haze, 0.34)], [1, mix(Z.sand, Z.haze, 0.52)]], 0, 560, 0, 860));
  d.def('plain', lg('{id}', [[0, mix(Z.sand, Z.haze, 0.52)], [0.45, mix(Z.sand, Z.haze, 0.34)], [1, mix(Z.sand, Z.haze, 0.14)]], 0, 770, 0, H));
  d.def('farHaze', lg('{id}', [[0, Z.haze, 0], [0.34, Z.haze, 0.2], [0.7, Z.haze, 0.26], [1, Z.haze, 0.1]], 0, 690, 0, H));

  d.add(`<path d="${massPath(t1, 1014, 8)}" fill="url(#p1)"/>`);
  d.add(`<path d="${massPath(t2, 1014, 8)}" fill="url(#p2)"/>`);

  // main plateau with sedimentary strata and erosion gullies
  rockFace(d, {
    top: t3,
    baseY: 848,
    fillTo: 1014,
    gid: 'p3',
    rim: '#fff6e2',
    rimOp: 0.5,
    strata: [
      { y: 604, amp: 3.4, k: 3, p: 1.1, color: mix(Z.ochre, Z.haze, 0.5), op: 0.26, w: 1.8 },
      { y: 640, amp: 4.2, k: 2, p: 2.4, color: mix(Z.ochre, Z.haze, 0.45), op: 0.32, w: 2.4 },
      { y: 678, amp: 5.0, k: 3, p: 0.4, color: lite(Z.lime, 0.35), op: 0.4, w: 2.2 },
      { y: 712, amp: 4.4, k: 2, p: 3.1, color: mix(Z.ochre, Z.haze, 0.4), op: 0.3, w: 2.6 },
      { y: 748, amp: 3.6, k: 4, p: 1.8, color: mix(Z.ochre, Z.sand, 0.35), op: 0.3, w: 2.0 },
      { y: 782, amp: 2.8, k: 3, p: 4.4, color: mix(Z.ochre, Z.haze, 0.3), op: 0.24, w: 3.0 },
    ],
    gullies: (() => {
      const out = [];
      for (let i = 0; i < 11; i++) {
        const x = 60 + (W - 120) * ((i + 0.5 + (r() - 0.5) * 0.7) / 11);
        out.push({ x, inset: 5, drift: (r() - 0.5) * 20, wTop: 10 + r() * 8, wBot: 26 + r() * 24, shadow: mix(Z.ochre, Z.sand, 0.12), op: 0.22 + r() * 0.1, light: lite(Z.lime, 0.5), lop: 0.3, spur: 20 + r() * 22, tail: 60 });
      }
      return out;
    })(),
  });

  // alluvial plain, faint distributary fans
  const plainTop = (x) => 838 + 4 * Math.sin((TAU * 2 * x) / W + 0.6) + 2 * Math.sin((TAU * 5 * x) / W + 2.2);
  let dp = '';
  for (let x = 0; x <= W; x += 8) dp += (x === 0 ? 'M' : 'L') + f1(x) + ',' + f1(plainTop(x)) + ' ';
  dp += `L${W},${H} L0,${H} Z`;
  d.add(`<path d="${dp}" fill="url(#plain)"/>`);
  for (let i = 0; i < 9; i++) {
    const x = 120 + (W - 440) * ((i + 0.5 + (r() - 0.5) * 0.6) / 9);
    const w = 40 + r() * 110;
    const spread = 60 + r() * 90;
    d.add(`<path d="M${f1(x - 6)},${f1(plainTop(x) + 2)} L${f1(x + 6)},${f1(plainTop(x) + 2)} L${f1(x + spread)},${f1(900 + r() * 44)} L${f1(x + spread - w)},${f1(900 + r() * 44)} Z" fill="${lite(Z.sand, 0.28)}" fill-opacity="${f1((0.12 + r() * 0.1) * 100) / 100}"/>`);
  }
  // dry wash channels on the plain
  for (let i = 0; i < 7; i++) {
    const x = 90 + r() * (W - 180);
    const len = 200 + r() * 380;
    d.add(`<path d="M${f1(x)},${f1(858 + r() * 40)} C${f1(x + 40)},${f1(910)} ${f1(x - 30)},${f1(980)} ${f1(Math.min(W - 8, x + len * 0.35))},${f1(1050)}" fill="none" stroke="${mix(Z.ochre, Z.sand, 0.4)}" stroke-width="${f1(1.6 + r() * 2)}" stroke-opacity="0.26" stroke-linecap="round"/>`);
  }
  d.add(`<rect x="0" y="690" width="${W}" height="${H - 690}" fill="url(#farHaze)"/>`);
  return d.svg();
}

function zagrosMid() {
  const d = newDoc(W, H);
  const r = rng(7103);
  const rough = makeWave(r, 4, 7, 2.5, 0.55);

  const tA = profileFn(forms([[240, 214, 260, 1], [720, 262, 300, 1], [1200, 192, 250, 1], [1640, 242, 280, 1]]), 826, { rough, roughAmp: 3.4, notches: makeNotches(r, 15, 24, 62, 16, 40) });
  const tB = profileFn(forms([[420, 152, 330, 1], [980, 202, 380, 1], [1540, 172, 340, 1]]), 962, { rough, roughAmp: 3.8, notches: makeNotches(r, 11, 22, 54, 20, 48) });

  d.def('mA', lg('{id}', [[0, mix(Z.lime, Z.sand, 0.3)], [0.3, mix(Z.lime, Z.sand, 0.08)], [0.7, mix(Z.sand, Z.ochre, 0.2)], [1, mix(Z.sand, Z.ochre, 0.42)]], 0, 560, 0, 870));
  d.def('mB', lg('{id}', [[0, mix(Z.lime, Z.sand, 0.14)], [0.26, Z.sand], [0.7, mix(Z.sand, Z.ochre, 0.38)], [1, mix(Z.sand, Z.ochre, 0.56)]], 0, 760, 0, 980));
  d.def('apron', lg('{id}', [[0, mix(Z.sand, Z.ochre, 0.3)], [0.45, mix(Z.sand, Z.ochre, 0.46)], [1, mix(Z.ochre, Z.sand, 0.22)]], 0, 930, 0, H));
  d.def('midHaze', lg('{id}', [[0, Z.haze, 0], [0.45, Z.haze, 0.2], [1, Z.haze, 0]], 0, 730, 0, 900));

  rockFace(d, {
    top: tA,
    baseY: 858,
    fillTo: 1014,
    gid: 'mA',
    rim: '#fff0d2',
    rimOp: 0.55,
    strata: [
      { y: 596, amp: 4.0, k: 3, p: 0.7, color: mix(Z.ochre, Z.sand, 0.3), op: 0.3, w: 2.2 },
      { y: 634, amp: 4.6, k: 2, p: 2.0, color: lite(Z.lime, 0.28), op: 0.42, w: 2.0 },
      { y: 672, amp: 5.2, k: 3, p: 3.6, color: mix(Z.ochre, Z.sand, 0.24), op: 0.34, w: 2.8 },
      { y: 710, amp: 4.0, k: 4, p: 1.4, color: mix(Z.ochre, Z.sand, 0.5), op: 0.3, w: 2.2 },
      { y: 748, amp: 3.0, k: 2, p: 4.8, color: mix(Z.ochre, Z.sand, 0.35), op: 0.34, w: 3.4 },
      { y: 790, amp: 2.6, k: 3, p: 2.2, color: dark(Z.ochre, 0.1), op: 0.26, w: 4.0 },
      { y: 826, amp: 2.2, k: 2, p: 5.5, color: dark(Z.ochre, 0.2), op: 0.24, w: 3.0 },
    ],
    gullies: (() => {
      const out = [];
      for (let i = 0; i < 13; i++) {
        const x = 50 + (W - 100) * ((i + 0.5 + (r() - 0.5) * 0.6) / 13);
        out.push({ x, inset: 4, drift: (r() - 0.5) * 24, wTop: 11 + r() * 9, wBot: 30 + r() * 30, shadow: mix(Z.ochre, Z.sand, 0.02), op: 0.24 + r() * 0.12, light: lite(Z.lime, 0.55), lop: 0.34, spur: 22 + r() * 26, tail: 50 });
      }
      return out;
    })(),
  });

  // scree fans spilling from the gullies onto the next bench
  for (let i = 0; i < 11; i++) {
    const x = 90 + (W - 180) * ((i + 0.5 + (r() - 0.5) * 0.6) / 11);
    const top = tA(x) + 16;
    if (top > 830) continue;
    const spread = 50 + r() * 70;
    d.add(`<path d="M${f1(x - 7)},${f1(top)} L${f1(x + 7)},${f1(top)} L${f1(x + spread)},${f1(890 + r() * 26)} L${f1(x - spread * 0.8)},${f1(890 + r() * 26)} Z" fill="${mix(Z.sand, Z.lime, 0.42)}" fill-opacity="${f1((0.18 + r() * 0.12) * 100) / 100}"/>`);
  }
  d.add(`<rect x="0" y="730" width="${W}" height="170" fill="url(#midHaze)"/>`);

  rockFace(d, {
    top: tB,
    baseY: 972,
    fillTo: 1014,
    gid: 'mB',
    rim: '#ffe7bf',
    rimOp: 0.6,
    strata: [
      { y: 828, amp: 4.4, k: 2, p: 1.9, color: mix(Z.ochre, Z.sand, 0.2), op: 0.32, w: 2.6 },
      { y: 862, amp: 5.0, k: 3, p: 0.3, color: mix(Z.lime, Z.sand, 0.5), op: 0.3, w: 2.2 },
      { y: 894, amp: 4.2, k: 2, p: 3.2, color: mix(Z.ochre, Z.sand, 0.12), op: 0.34, w: 3.0 },
      { y: 924, amp: 3.4, k: 4, p: 2.6, color: mix(Z.ochre, Z.sand, 0.36), op: 0.34, w: 2.4 },
      { y: 952, amp: 2.6, k: 3, p: 5.1, color: dark(Z.ochre, 0.25), op: 0.26, w: 3.6 },
    ],
    gullies: (() => {
      const out = [];
      for (let i = 0; i < 12; i++) {
        const x = 60 + (W - 120) * ((i + 0.5 + (r() - 0.5) * 0.55) / 12);
        out.push({ x, inset: 4, drift: (r() - 0.5) * 28, wTop: 12 + r() * 10, wBot: 32 + r() * 34, shadow: mix(Z.ochre, Z.sand, 0.02), op: 0.3 + r() * 0.14, light: lite(Z.lime, 0.55), lop: 0.32, spur: 24 + r() * 28, tail: 40 });
      }
      return out;
    })(),
  });

  // dry scrub dots along the benches
  for (let i = 0; i < 70; i++) {
    const x = 40 + r() * (W - 80);
    const yBase = 900 + r() * 66;
    if (yBase < tA(x) + 20) continue;
    const h = 5 + r() * 9;
    d.add(`<path d="M${f1(x)},${f1(yBase)} L${f1(x)},${f1(yBase - h)}" stroke="${mix(Z.ochre, Z.sand, 0.15)}" stroke-width="1.2" stroke-opacity="0.5"/>`);
    d.add(`<ellipse cx="${f1(x)}" cy="${f1(yBase - h)}" rx="${f1(2 + r() * 3)}" ry="${f1(1.4 + r() * 1.6)}" fill="${mix(Z.ochre, '#7d7a4e', 0.55)}" fill-opacity="0.55"/>`);
  }

  let dap = '';
  for (let x = 0; x <= W; x += 8) dap += (x === 0 ? 'M' : 'L') + f1(x) + ',' + f1(946 + 5 * Math.sin((TAU * 3 * x) / W + 1.2) + 2 * Math.sin((TAU * 7 * x) / W + 0.3)) + ' ';
  dap += `L${W},${H} L0,${H} Z`;
  d.add(`<path d="${dap}" fill="url(#apron)"/>`);
  for (let i = 0; i < 40; i++) {
    const x = 30 + r() * (W - 60);
    const y = 968 + r() * 100;
    d.add(`<ellipse cx="${f1(x)}" cy="${f1(y)}" rx="${f1(4 + r() * 12)}" ry="${f1(2 + r() * 4)}" fill="${dark(Z.ochre, 0.1)}" fill-opacity="${f1((0.1 + r() * 0.12) * 100) / 100}"/>`);
    d.add(`<ellipse cx="${f1(x)}" cy="${f1(y - 1.6)}" rx="${f1(3 + r() * 9)}" ry="${f1(1.4 + r() * 3)}" fill="${lite(Z.lime, 0.2)}" fill-opacity="${f1((0.12 + r() * 0.1) * 100) / 100}"/>`);
  }
  return d.svg();
}

function zagrosNear() {
  const d = newDoc(W, H);
  const r = rng(7104);
  const rough = makeWave(r, 4, 6, 2.6, 0.6);
  const pBase = makePeaks(r, { n: 8, hMin: 20, hMax: 54, wMin: 140, wMax: 300, flat: true });
  const tBase = profileFn(pBase, 1018, rough);

  d.def('nBase', lg('{id}', [[0, '#5d4526'], [0.45, '#4d3922'], [1, '#3a2a18']], 0, 960, 0, H));
  d.def('rockA', lg('{id}', [[0, '#7a5c37'], [0.42, '#5b4426'], [1, '#3a2a18']], 0, 760, 0, H));
  d.def('rockB', lg('{id}', [[0, '#6d5334'], [0.5, '#4e3a22'], [1, '#332413']], 0, 820, 0, H));

  d.add(`<path d="${massPath(tBase, H, 8)}" fill="url(#nBase)"/>`);

  // two big outcrops framing the road
  const outcrops = [
    { cx: 300, cy: 902, rx: 230, ry: 150, gid: 'rockA' },
    { cx: 1560, cy: 936, rx: 250, ry: 132, gid: 'rockB' },
    { cx: 980, cy: 1000, rx: 210, ry: 78, gid: 'rockA' },
  ];
  for (const o of outcrops) {
    const pts = blobPts(o.cx, o.cy, o.rx, o.ry, r, 14, 0.14);
    d.add(`<path d="${polyPath(clipRect(pts, 0, 0, W, H))}" fill="url(#${o.gid})"/>`);
    // faceted lit tops
    for (let i = 0; i < 6; i++) {
      const a = Math.PI + (i / 5) * Math.PI;
      const x1 = o.cx + Math.cos(a) * o.rx * 0.92;
      const y1 = o.cy + Math.sin(a) * o.ry * 0.92;
      const a2 = Math.PI + ((i + 1) / 5) * Math.PI;
      const x2 = o.cx + Math.cos(a2) * o.rx * 0.92;
      const y2 = o.cy + Math.sin(a2) * o.ry * 0.92;
      const cx = o.cx + (r() - 0.5) * 60;
      const cy = o.cy + o.ry * 0.25;
      d.add(`<path d="M${f1(x1)},${f1(y1)} L${f1(x2)},${f1(y2)} L${f1(cx)},${f1(cy)} Z" fill="${i % 2 ? '#7f6440' : '#6a4f2d'}" fill-opacity="${f1((0.35 + r() * 0.25) * 100) / 100}"/>`);
    }
    // rim light
    let rim = '';
    for (let i = 0; i <= 8; i++) {
      const a = Math.PI + (i / 8) * Math.PI;
      const k = 1 + 0.14 * Math.sin(a * 2 + 1.1) + 0.06 * Math.sin(a * 5 + 2.2);
      const x = clamp(o.cx + Math.cos(a) * o.rx * k, 0, W);
      const y = clamp(o.cy + Math.sin(a) * o.ry * k, 0, H);
      rim += (i === 0 ? 'M' : 'L') + f1(x) + ',' + f1(y) + ' ';
    }
    d.add(`<path d="${rim}" fill="none" stroke="#c99a5e" stroke-width="2.4" stroke-opacity="0.3" stroke-linecap="round"/>`);
    // cracks
    for (let i = 0; i < 3; i++) {
      const x = o.cx + (r() - 0.5) * o.rx * 1.1;
      const y = o.cy - o.ry * 0.3 + r() * o.ry * 0.7;
      d.add(`<path d="M${f1(x)},${f1(y)} q${f1(8 + r() * 14)},${f1(14 + r() * 20)} ${f1(4 + r() * 10)},${f1(40 + r() * 34)}" fill="none" stroke="#2a1d10" stroke-width="2" stroke-opacity="0.45" stroke-linecap="round"/>`);
    }
  }

  // dry scrub silhouettes along the base band
  for (let i = 0; i < 46; i++) {
    const x = 24 + r() * (W - 48);
    const y = 1024 + r() * 52;
    const h = 16 + r() * 34;
    const lean = (r() - 0.5) * 10;
    d.add(`<path d="M${f1(x)},${f1(y)} Q${f1(x + lean * 0.5)},${f1(y - h * 0.6)} ${f1(x + lean)},${f1(y - h)}" fill="none" stroke="#2c1f12" stroke-width="${f1(1.4 + r() * 1.6)}" stroke-opacity="0.9" stroke-linecap="round"/>`);
    for (let j = 0; j < 5; j++) {
      const ty = y - h * (0.55 + r() * 0.45);
      const tx = x + lean * (1 - (y - ty) / h) + (r() - 0.5) * 16;
      d.add(`<path d="M${f1(x + lean * 0.5)},${f1(y - h * 0.62)} Q${f1(tx)},${f1(ty - 2)} ${f1(tx + (r() - 0.5) * 12)},${f1(ty - 8 - r() * 10)}" fill="none" stroke="#2c1f12" stroke-width="1.2" stroke-opacity="0.75" stroke-linecap="round"/>`);
    }
  }
  return d.svg();
}

function zagrosGround() {
  const d = newDoc(G, G);
  const r = rng(7105);
  d.def('base', lg('{id}', [[0, '#bd9f70'], [0.35, '#b99a6b'], [0.7, '#b3935f'], [1, '#bd9f70']], 0, 0, 0, G));
  d.add(`<rect x="0" y="0" width="${G}" height="${G}" fill="url(#base)"/>`);

  const wrap = (pts, fill, op) => {
    for (const dx of [-G, 0, G]) {
      for (const dy of [-G, 0, G]) {
        const moved = pts.map((p) => [p[0] + dx, p[1] + dy]);
        const c = clipRect(moved, 0, 0, G, G);
        if (c.length > 2) d.add(`<path d="${polyPath(c)}" fill="${fill}" fill-opacity="${op}"/>`);
      }
    }
  };

  // broad ochre wash patches (kept periodic by wrapping)
  for (let i = 0; i < 26; i++) {
    const cx = r() * G;
    const cy = r() * G;
    const rx = 26 + r() * 62;
    const ry = 16 + r() * 38;
    const tone = pick(r, ['#c8ab7c', '#ab8b5c', '#c2a473', '#a68553']);
    wrap(blobPts(cx, cy, rx, ry, r, 12, 0.2), tone, f1((0.1 + r() * 0.12) * 100) / 100);
  }
  // gravel pebbles: lit cap + contact shadow
  for (let i = 0; i < 210; i++) {
    const cx = r() * G;
    const cy = r() * G;
    const rx = 2.2 + r() * 8;
    const ry = rx * (0.5 + r() * 0.5);
    wrap(blobPts(cx, cy + ry * 0.35, rx, ry, r, 8, 0.22), '#6d5334', f1((0.22 + r() * 0.18) * 100) / 100);
    wrap(blobPts(cx, cy, rx, ry, r, 8, 0.22), pick(r, ['#cbbfa6', '#c3b498', '#d2c7b0', '#b6a687']), f1((0.55 + r() * 0.35) * 100) / 100);
    wrap(ellipsePts(cx - rx * 0.15, cy - ry * 0.3, rx * 0.5, ry * 0.42, 8), '#efe3cc', f1((0.3 + r() * 0.3) * 100) / 100);
  }
  // fine grit
  for (let i = 0; i < 260; i++) {
    const cx = 2 + r() * (G - 4);
    const cy = 2 + r() * (G - 4);
    const rad = 0.8 + r() * 2.2;
    d.add(`<ellipse cx="${f1(cx)}" cy="${f1(cy)}" rx="${f1(rad)}" ry="${f1(rad * 0.8)}" fill="${pick(r, ['#8a6f47', '#d8cbb0', '#7a5f3c'])}" fill-opacity="${f1((0.2 + r() * 0.3) * 100) / 100}"/>`);
  }
  // hairline desiccation cracks
  for (let i = 0; i < 7; i++) {
    const x = 40 + r() * (G - 80);
    const y = 40 + r() * (G - 80);
    let dd = `M${f1(x)},${f1(y)}`;
    let px = x;
    let py = y;
    for (let j = 0; j < 5; j++) {
      px += (r() - 0.5) * 30;
      py += 8 + r() * 22;
      dd += ` L${f1(clamp(px, 10, G - 10))},${f1(clamp(py, 10, G - 10))}`;
    }
    d.add(`<path d="${dd}" fill="none" stroke="#7f653f" stroke-width="${f1(0.9 + r() * 1.1)}" stroke-opacity="0.3" stroke-linecap="round"/>`);
  }
  return d.svg();
}

/* ================================================================ ALPINE === */
// High alpine pass: cold slate rock, snow, low cloud, paved switchbacks.

const A = {
  slate: '#6f7d8c',
  snow: '#e8eef2',
  deep: '#2f3a45',
  skyTop: '#9fb6c8',
  skyHorizon: '#dfe8ef',
};

function alpineSky() {
  const d = newDoc(W, H);
  const r = rng(7201);
  d.def('sky', lg('{id}', [[0, A.skyTop], [0.22, '#b2c5d4'], [0.46, '#ccdae5'], [0.68, '#dfe8ef'], [0.86, '#e7eef3'], [1, '#eef3f7']], 0, 0, 0, H));
  d.def('sunWide', rg('{id}', [[0, '#ffffff', 0.4], [0.22, '#f4f9fc', 0.22], [0.6, '#e6eef4', 0.08], [1, '#e6eef4', 0]], 1320, 322, 700));
  d.def('sunCore', rg('{id}', [[0, '#ffffff', 0.95], [0.6, '#fbfdff', 0.75], [1, '#eaf2f8', 0.2]], 1320, 322, 54));
  d.def('clBody', lgBox('{id}', [[0, '#ffffff', 0.16], [0.34, '#f7fbfd', 0.86], [0.72, '#e2ebf2', 0.42], [1, '#d5e2eb', 0]]));
  d.def('lowCloud', lgBox('{id}', [[0, '#ffffff', 0.06], [0.36, '#fbfdff', 0.72], [0.8, '#e8f0f5', 0.3], [1, '#e0eaf1', 0]]));
  d.def('haze', lg('{id}', [[0, '#eaf1f6', 0], [0.45, '#e8f0f5', 0.34], [1, '#dfe9f0', 0.44]], 0, 520, 0, H));

  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sky)"/>`);
  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sunWide)"/>`);
  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sunCore)"/>`);

  // high cirrus
  for (const [cx, cy, w, h] of [[420, 128, 760, 22], [1180, 176, 820, 26], [1660, 108, 520, 18], [760, 238, 900, 20], [240, 300, 560, 16], [1480, 356, 720, 18]]) {
    d.add(`<path d="${cloudShape(cx, cy, w, h, r)}" fill="url(#clBody)" fill-opacity="0.6"/>`);
  }
  // low cloud bands caught on the range
  for (const [cx, cy, w, h] of [[360, 604, 1100, 46], [1220, 642, 1250, 54], [820, 690, 1500, 60], [300, 736, 900, 44], [1500, 726, 880, 40]]) {
    d.add(`<path d="${cloudShape(cx, cy, w, h, r)}" fill="url(#lowCloud)" fill-opacity="0.85"/>`);
  }
  for (let i = 0; i < 10; i++) {
    const y = 560 + r() * 210;
    const len = 120 + r() * 300;
    const x = 12 + r() * (W - 24 - len);
    d.add(`<path d="M${f1(x)},${f1(y)} Q${f1(x + len * 0.5)},${f1(y - 6)} ${f1(x + len)},${f1(y + 3)}" fill="none" stroke="#ffffff" stroke-width="${f1(1.6 + r() * 3)}" stroke-opacity="${f1((0.08 + r() * 0.1) * 100) / 100}" stroke-linecap="round"/>`);
  }
  d.add(`<rect x="0" y="520" width="${W}" height="${H - 520}" fill="url(#haze)"/>`);
  vignette(d);
  return d.svg();
}

function alpineFar() {
  const d = newDoc(W, H);
  const r = rng(7202);
  const rough = makeWave(r, 3, 11, 2.3, 0.55);

  const t1 = profileFn(forms([[260, 150, 190, 0, 0.8], [700, 214, 220, 0, 0.75], [1150, 122, 180, 0, 0.85], [1560, 192, 210, 0, 0.8], [1860, 142, 160, 0, 0.85]]), 588, { rough, roughAmp: 2.6, notches: makeNotches(r, 10, 14, 34, 12, 30) });
  const t2 = profileFn(forms([[150, 196, 210, 0, 0.8], [600, 262, 240, 0, 0.78], [1030, 158, 190, 0, 0.85], [1440, 244, 230, 0, 0.8], [1810, 180, 180, 0, 0.85]]), 668, { rough, roughAmp: 3.0, notches: makeNotches(r, 12, 16, 42, 12, 30) });
  const t3 = profileFn(forms([[320, 214, 230, 0, 0.85], [780, 258, 250, 0, 0.8], [1200, 176, 200, 0, 0.9], [1620, 232, 230, 0, 0.82], [1880, 168, 170, 0, 0.9]]), 746, { rough, roughAmp: 3.2, notches: makeNotches(r, 14, 18, 48, 14, 34) });

  d.def('r1', lg('{id}', [[0, mix('#c5d4e0', A.skyHorizon, 0.2)], [0.6, mix('#aebfcc', A.skyHorizon, 0.42)], [1, mix('#9fb0bf', A.skyHorizon, 0.6)]], 0, 360, 0, 600));
  d.def('r2', lg('{id}', [[0, mix(A.snow, A.skyHorizon, 0.28)], [0.5, mix('#9dafbe', A.skyHorizon, 0.34)], [1, mix(A.slate, A.skyHorizon, 0.5)]], 0, 430, 0, 690));
  d.def('r3', lg('{id}', [[0, mix(A.snow, A.skyHorizon, 0.16)], [0.42, mix('#8ea0af', A.skyHorizon, 0.22)], [1, mix(A.slate, A.skyHorizon, 0.3)]], 0, 520, 0, 780));
  d.def('field', lg('{id}', [[0, mix(A.snow, A.skyHorizon, 0.3)], [0.45, mix(A.snow, '#c6d5e1', 0.35)], [1, '#cbd9e3']], 0, 700, 0, H));
  d.def('haze', lg('{id}', [[0, '#e8f0f6', 0], [0.34, '#e4eef5', 0.28], [0.7, '#e2ecf4', 0.4], [1, '#dde9f1', 0.3]], 0, 560, 0, H));

  d.add(`<path d="${massPath(t1, 1000, 6)}" fill="url(#r1)"/>`);
  snowCaps(d, { top: t1, snowLine: 470, depth: 74, color: lite('#dbe7ef', 0.5), wave: makeWave(r, 3, 8, 2.2, 0.55), op: 0.75 });
  d.add(`<path d="${massPath(t2, 1000, 6)}" fill="url(#r2)"/>`);
  snowCaps(d, { top: t2, snowLine: 556, depth: 92, color: mix(A.snow, '#ffffff', 0.35), wave: makeWave(r, 3, 7, 2.4, 0.5), op: 0.9 });
  d.add(`<path d="${massPath(t3, 1000, 6)}" fill="url(#r3)"/>`);
  snowCaps(d, { top: t3, snowLine: 640, depth: 104, color: A.snow, wave: makeWave(r, 4, 6, 2.5, 0.55), op: 0.95 });

  // rock ribs showing through the snow on the nearest range
  for (let i = 0; i < 16; i++) {
    const x = 60 + (W - 120) * ((i + 0.5 + (r() - 0.5) * 0.7) / 16);
    const y0 = t3(x) + 20;
    if (y0 > 740) continue;
    const y1 = y0 + 40 + r() * 70;
    const w = 8 + r() * 16;
    d.add(`<path d="M${f1(x - w * 0.3)},${f1(y0)} L${f1(x + w * 0.3)},${f1(y0)} L${f1(x + w)},${f1(y1)} L${f1(x - w * 0.7)},${f1(y1)} Z" fill="${mix(A.slate, A.deep, 0.25)}" fill-opacity="${f1((0.2 + r() * 0.16) * 100) / 100}"/>`);
  }

  let df = '';
  for (let x = 0; x <= W; x += 8) df += (x === 0 ? 'M' : 'L') + f1(x) + ',' + f1(776 + 6 * Math.sin((TAU * 2 * x) / W + 0.4) + 3 * Math.sin((TAU * 6 * x) / W + 2.1)) + ' ';
  df += `L${W},${H} L0,${H} Z`;
  d.add(`<path d="${df}" fill="url(#field)"/>`);
  // wind-scoured streaks on the snowfield
  for (let i = 0; i < 22; i++) {
    const y = 800 + r() * 260;
    const len = 90 + r() * 240;
    const x = 12 + r() * (W - 24 - len);
    d.add(`<path d="M${f1(x)},${f1(y)} Q${f1(x + len * 0.5)},${f1(y - 4)} ${f1(x + len)},${f1(y + 2)}" fill="none" stroke="${mix(A.slate, A.snow, 0.55)}" stroke-width="${f1(1 + r() * 2)}" stroke-opacity="${f1((0.1 + r() * 0.14) * 100) / 100}" stroke-linecap="round"/>`);
  }
  d.add(`<rect x="0" y="560" width="${W}" height="${H - 560}" fill="url(#haze)"/>`);
  return d.svg();
}

function alpineMid() {
  const d = newDoc(W, H);
  const r = rng(7203);
  const rough = makeWave(r, 4, 8, 2.4, 0.55);

  const tW = profileFn(forms([[260, 236, 240, 0, 0.9], [760, 292, 290, 0, 0.85], [1260, 204, 230, 0, 0.9], [1700, 262, 260, 0, 0.88]]), 902, { rough, roughAmp: 3.4, notches: makeNotches(r, 16, 18, 52, 14, 34) });

  d.def('wall', lg('{id}', [[0, mix(A.snow, A.slate, 0.18)], [0.3, mix(A.slate, A.snow, 0.3)], [0.66, mix(A.slate, A.deep, 0.18)], [1, mix(A.deep, A.slate, 0.24)]], 0, 700, 0, 900));
  d.def('base', lg('{id}', [[0, mix(A.slate, A.deep, 0.5)], [0.4, mix(A.deep, '#1f2831', 0.2)], [1, '#1b232b']], 0, 930, 0, H));
  d.def('midHaze', lg('{id}', [[0, '#e9f1f6', 0], [0.45, '#e7eff5', 0.26], [1, '#e3edf3', 0]], 0, 700, 0, 880));

  rockFace(d, {
    top: tW,
    baseY: 940,
    fillTo: 1016,
    gid: 'wall',
    rim: '#ffffff',
    rimOp: 0.5,
    strata: [
      { y: 716, amp: 5.0, k: 2, p: 1.2, color: A.deep, op: 0.16, w: 2.6 },
      { y: 754, amp: 5.6, k: 3, p: 2.8, color: lite(A.snow, 0.2), op: 0.18, w: 2.4 },
      { y: 792, amp: 4.8, k: 2, p: 0.2, color: A.deep, op: 0.2, w: 3.2 },
      { y: 828, amp: 4.0, k: 3, p: 3.9, color: A.deep, op: 0.18, w: 2.6 },
      { y: 862, amp: 3.2, k: 2, p: 5.2, color: A.deep, op: 0.24, w: 3.6 },
    ],
    gullies: (() => {
      const out = [];
      for (let i = 0; i < 18; i++) {
        const x = 60 + (W - 120) * ((i + 0.5 + (r() - 0.5) * 0.6) / 18);
        out.push({ x, inset: 4, drift: (r() - 0.5) * 30, wTop: 6 + r() * 7, wBot: 20 + r() * 26, shadow: mix(A.deep, A.slate, 0.1), op: 0.28 + r() * 0.12, light: lite(A.snow, 0.4), lop: 0.3 });
      }
      return out;
    })(),
  });

  // snow fields clinging to the upper wall
  const snowWave = makeWave(r, 3, 5, 2.3, 0.5);
  for (let i = 0; i < 7; i++) {
    const cx = 120 + (W - 240) * ((i + 0.5 + (r() - 0.5) * 0.6) / 7);
    const w = 150 + r() * 200;
    const y = 748 + r() * 54;
    if (y < tW(cx) + 30) continue;
    const pts = [];
    for (let x = cx - w / 2; x <= cx + w / 2; x += 8) {
      const k = 1 - Math.pow(Math.abs(x - cx) / (w / 2), 2);
      if (k <= 0) continue;
      pts.push([x, y - k * (16 + r() * 10) + snowWave(x) * 4]);
    }
    for (let x = cx + w / 2; x >= cx - w / 2; x -= 8) {
      const k = 1 - Math.pow(Math.abs(x - cx) / (w / 2), 2);
      if (k <= 0) continue;
      pts.push([x, y + k * (10 + 8 * (0.5 + 0.5 * snowWave(x)))]);
    }
    if (pts.length > 4) d.add(`<path d="${polyPath(pts)}" fill="${A.snow}" fill-opacity="${f1((0.6 + r() * 0.28) * 100) / 100}"/>`);
  }

  // --- paved switchbacks -------------------------------------------------
  const road = [
    [120, 936], [300, 930], [520, 924], [700, 916],
    [772, 910], [806, 896], [800, 880], [764, 872],
    [640, 868], [470, 864], [330, 860],
    [268, 858], [236, 846], [244, 832], [286, 826],
    [430, 820], [620, 814], [800, 808], [940, 802],
    [1002, 797], [1024, 784], [1008, 770], [968, 764],
    [840, 760], [700, 756], [566, 752],
  ];
  let dRoad = 'M' + road.map((p) => f1(p[0]) + ',' + f1(p[1])).join(' L');
  // retaining wall shadow under the outer edge
  d.add(`<path d="${dRoad}" fill="none" stroke="#141b21" stroke-width="17" stroke-opacity="0.28" stroke-linecap="round" stroke-linejoin="round" transform="translate(0,7)"/>`);
  d.add(`<path d="${dRoad}" fill="none" stroke="#313d47" stroke-width="15" stroke-opacity="0.9" stroke-linecap="round" stroke-linejoin="round"/>`);
  d.add(`<path d="${dRoad}" fill="none" stroke="${mix(A.slate, '#3c4854', 0.35)}" stroke-width="11" stroke-opacity="1" stroke-linecap="round" stroke-linejoin="round"/>`);
  d.add(`<path d="${dRoad}" fill="none" stroke="${mix(A.snow, A.slate, 0.35)}" stroke-width="1.6" stroke-opacity="0.55" stroke-linecap="round" stroke-linejoin="round" transform="translate(0,-5)"/>`);
  // guard stones on the downhill lip
  for (let i = 2; i < road.length - 1; i++) {
    const [x, y] = road[i];
    d.add(`<rect x="${f1(x - 1.6)}" y="${f1(y + 6)}" width="3.2" height="${f1(5 + r() * 3)}" fill="${mix(A.snow, A.slate, 0.28)}" fill-opacity="0.9"/>`);
  }

  // snow banks along the inner edge of the road
  for (let i = 1; i < road.length - 2; i += 2) {
    const [x, y] = road[i];
    d.add(`<ellipse cx="${f1(x + 4)}" cy="${f1(y - 8)}" rx="${f1(16 + r() * 16)}" ry="${f1(4 + r() * 3)}" fill="${A.snow}" fill-opacity="${f1((0.5 + r() * 0.3) * 100) / 100}"/>`);
  }

  // tunnel portal where the top leg leaves the frame
  d.add(`<path d="M512,744 L560,742 L560,786 L512,788 Z" fill="${mix(A.deep, '#10161b', 0.4)}"/>`);
  d.add(`<path d="M508,742 L564,740 L564,748 L508,750 Z" fill="${mix(A.snow, A.slate, 0.2)}" fill-opacity="0.85"/>`);

  d.add(`<rect x="0" y="700" width="${W}" height="180" fill="url(#midHaze)"/>`);

  // conifers at the treeline, below the road
  for (let i = 0; i < 60; i++) {
    const x = 20 + r() * (W - 40);
    const y = 948 + r() * 74;
    const h = 24 + r() * 46;
    const w = h * (0.3 + r() * 0.1);
    const col = mix('#2b3a34', A.deep, r() * 0.5);
    d.add(`<path d="M${f1(x)},${f1(y - h)} L${f1(x + w * 0.5)},${f1(y - h * 0.42)} L${f1(x + w * 0.3)},${f1(y - h * 0.4)} L${f1(x + w * 0.62)},${f1(y)} L${f1(x - w * 0.62)},${f1(y)} L${f1(x - w * 0.3)},${f1(y - h * 0.4)} L${f1(x - w * 0.5)},${f1(y - h * 0.42)} Z" fill="${col}" fill-opacity="${f1((0.75 + r() * 0.25) * 100) / 100}"/>`);
    d.add(`<path d="M${f1(x + w * 0.2)},${f1(y - h * 0.62)} L${f1(x + w * 0.42)},${f1(y - h * 0.2)} L${f1(x + w * 0.1)},${f1(y - h * 0.24)} Z" fill="${A.snow}" fill-opacity="0.35"/>`);
  }

  let db = '';
  for (let x = 0; x <= W; x += 8) db += (x === 0 ? 'M' : 'L') + f1(x) + ',' + f1(1004 + 7 * Math.sin((TAU * 3 * x) / W + 0.9) + 4 * Math.sin((TAU * 8 * x) / W + 2.4)) + ' ';
  db += `L${W},${H} L0,${H} Z`;
  d.add(`<path d="${db}" fill="url(#base)"/>`);
  return d.svg();
}

function alpineNear() {
  const d = newDoc(W, H);
  const r = rng(7204);
  const rough = makeWave(r, 4, 7, 2.5, 0.6);
  const pBase = makePeaks(r, { n: 7, hMin: 26, hMax: 66, wMin: 160, wMax: 320, flat: true });
  const tBase = profileFn(pBase, 1006, rough);

  d.def('nBase', lg('{id}', [[0, '#3b4750'], [0.5, '#2f3a45'], [1, '#232c34']], 0, 950, 0, H));
  d.def('boulder', lg('{id}', [[0, '#5c6b78'], [0.42, '#414e5a'], [1, '#242d36']], 0, 780, 0, H));
  d.def('boulder2', lg('{id}', [[0, '#4f5e6b'], [0.5, '#38434e'], [1, '#1f272e']], 0, 820, 0, H));

  // snow drift band that the foreground rocks sit in
  d.add(`<path d="${massPath(tBase, H, 8)}" fill="url(#nBase)"/>`);
  let drift = '';
  for (let x = 0; x <= W; x += 8) drift += (x === 0 ? 'M' : 'L') + f1(x) + ',' + f1(tBase(x) + 6 + 5 * Math.sin((TAU * 4 * x) / W + 1.3)) + ' ';
  drift += `L${W},${H} L0,${H} Z`;
  d.def('drift', lg('{id}', [[0, '#dfe9f0'], [0.4, '#d3e0e9'], [1, '#c3d3de']], 0, 1000, 0, H));
  d.add(`<path d="${drift}" fill="url(#drift)" fill-opacity="0.9"/>`);

  const rocks = [
    { cx: 260, cy: 934, rx: 216, ry: 148, gid: 'boulder' },
    { cx: 1500, cy: 956, rx: 250, ry: 140, gid: 'boulder2' },
    { cx: 900, cy: 1030, rx: 230, ry: 84, gid: 'boulder' },
  ];
  for (const o of rocks) {
    const pts = blobPts(o.cx, o.cy, o.rx, o.ry, r, 13, 0.15);
    d.add(`<path d="${polyPath(clipRect(pts, 0, 0, W, H))}" fill="url(#${o.gid})"/>`);
    // snow cap along the top of the boulder
    const cap = [];
    for (let i = 0; i <= 10; i++) {
      const a = Math.PI + (i / 10) * Math.PI;
      const k = 1 + 0.15 * Math.sin(a * 2 + 1.4) + 0.07 * Math.sin(a * 5 + 0.8);
      cap.push([o.cx + Math.cos(a) * o.rx * k, o.cy + Math.sin(a) * o.ry * k]);
    }
    for (let i = 10; i >= 0; i--) {
      const a = Math.PI + (i / 10) * Math.PI;
      const k = 1 + 0.15 * Math.sin(a * 2 + 1.4) + 0.07 * Math.sin(a * 5 + 0.8);
      cap.push([o.cx + Math.cos(a) * o.rx * k * 0.94, o.cy + Math.sin(a) * o.ry * k * 0.94 + 10 + 6 * Math.sin(i)]);
    }
    d.add(`<path d="${polyPath(clipRect(cap, 0, 0, W, H))}" fill="${A.snow}" fill-opacity="0.9"/>`);
    // fractures
    for (let i = 0; i < 3; i++) {
      const x0 = clamp(o.cx + (r() - 0.5) * o.rx, 4, W - 4);
      const y0 = clamp(o.cy - o.ry * 0.2 + r() * o.ry * 0.6, 4, H - 4);
      const x1 = x0 + (r() - 0.5) * 26;
      const y1 = y0 + 18 + r() * 30;
      const x2 = x1 + (r() - 0.5) * 18;
      const y2 = y1 + 16 + r() * 26;
      d.add(`<path d="M${f1(x0)},${f1(y0)} L${f1(clamp(x1, 2, W - 2))},${f1(clamp(y1, 2, H - 2))} L${f1(clamp(x2, 2, W - 2))},${f1(clamp(y2, 2, H - 2))}" fill="none" stroke="#161d24" stroke-width="2.2" stroke-opacity="0.5" stroke-linecap="round"/>`);
    }
  }
  // wind-blown snow streaks across the foreground
  for (let i = 0; i < 26; i++) {
    const len = 80 + r() * 240;
    const x = 12 + r() * (W - 24 - len);
    const y = 960 + r() * 100;
    d.add(`<path d="M${f1(x)},${f1(y)} Q${f1(x + len * 0.5)},${f1(y - 3)} ${f1(x + len)},${f1(y + 1)}" fill="none" stroke="#eaf2f8" stroke-width="${f1(1 + r() * 2.4)}" stroke-opacity="${f1((0.12 + r() * 0.16) * 100) / 100}" stroke-linecap="round"/>`);
  }
  return d.svg();
}

function alpineGround() {
  const d = newDoc(G, G);
  const r = rng(7205);
  d.def('base', lg('{id}', [[0, '#8f8a7d'], [0.3, '#8a8578'], [0.68, '#837e72'], [1, '#8f8a7d']], 0, 0, 0, G));
  d.add(`<rect x="0" y="0" width="${G}" height="${G}" fill="url(#base)"/>`);

  const wrap = (pts, fill, op) => {
    for (const dx of [-G, 0, G]) {
      for (const dy of [-G, 0, G]) {
        const moved = pts.map((p) => [p[0] + dx, p[1] + dy]);
        const c = clipRect(moved, 0, 0, G, G);
        if (c.length > 2) d.add(`<path d="${polyPath(c)}" fill="${fill}" fill-opacity="${op}"/>`);
      }
    }
  };

  // packed snow patches
  for (let i = 0; i < 16; i++) {
    wrap(blobPts(r() * G, r() * G, 24 + r() * 60, 18 + r() * 40, r, 12, 0.22), pick(r, ['#e8eef2', '#dfe8ee', '#eef3f6']), f1((0.55 + r() * 0.35) * 100) / 100);
  }
  // wet slate chips
  for (let i = 0; i < 190; i++) {
    const cx = r() * G;
    const cy = r() * G;
    const rx = 2 + r() * 7;
    const ry = rx * (0.45 + r() * 0.5);
    wrap(blobPts(cx, cy + ry * 0.4, rx, ry, r, 8, 0.25), '#3b4650', f1((0.22 + r() * 0.2) * 100) / 100);
    wrap(blobPts(cx, cy, rx, ry, r, 8, 0.25), pick(r, ['#9aa8b4', '#8b98a4', '#a9b6c1', '#77848f']), f1((0.5 + r() * 0.35) * 100) / 100);
    wrap(ellipsePts(cx - rx * 0.2, cy - ry * 0.32, rx * 0.45, ry * 0.4, 8), '#dbe6ee', f1((0.25 + r() * 0.25) * 100) / 100);
  }
  // grit + ice specks
  for (let i = 0; i < 260; i++) {
    const cx = 2 + r() * (G - 4);
    const cy = 2 + r() * (G - 4);
    d.add(`<ellipse cx="${f1(cx)}" cy="${f1(cy)}" rx="${f1(0.7 + r() * 2)}" ry="${f1(0.6 + r() * 1.6)}" fill="${pick(r, ['#55626d', '#e8eef2', '#3d4852'])}" fill-opacity="${f1((0.2 + r() * 0.3) * 100) / 100}"/>`);
  }
  // tyre-scuffed streaks
  for (let i = 0; i < 5; i++) {
    const y = 40 + r() * (G - 80);
    d.add(`<path d="M12,${f1(y)} Q${f1(G * 0.5)},${f1(y - 10 + r() * 20)} ${G - 12},${f1(y + 6)}" fill="none" stroke="#6f7d8c" stroke-width="${f1(3 + r() * 7)}" stroke-opacity="${f1((0.08 + r() * 0.1) * 100) / 100}" stroke-linecap="round"/>`);
  }
  return d.svg();
}

/* =============================================================== GLACIER === */
// Glacier road: blue-white ice, crevasses, blowing snow, low white sun.

const C = {
  ice: '#cfe3ee',
  deepIce: '#7fa6bd',
  snow: '#f2f7fa',
  shadow: '#5b7d92',
};

function glacierSky() {
  const d = newDoc(W, H);
  const r = rng(7301);
  d.def('sky', lg('{id}', [[0, '#a8c3d6'], [0.18, '#c2d8e6'], [0.4, '#d8e8f1'], [0.6, '#e7f1f6'], [0.78, '#f0f6fa'], [1, '#f4f9fc']], 0, 0, 0, H));
  d.def('sunWide', rg('{id}', [[0, '#ffffff', 0.55], [0.18, '#fefeff', 0.34], [0.52, '#f4fafd', 0.12], [1, '#eef6fb', 0]], 1436, 706, 900));
  d.def('sunMid', rg('{id}', [[0, '#ffffff', 0.6], [0.4, '#ffffff', 0.28], [1, '#ffffff', 0]], 1436, 706, 240));
  d.def('sunCore', rg('{id}', [[0, '#ffffff', 1], [0.7, '#fdffff', 0.9], [1, '#f2f9fc', 0.3]], 1436, 706, 44));
  d.def('clBody', lgBox('{id}', [[0, '#ffffff', 0.1], [0.4, '#ffffff', 0.66], [0.78, '#e6f0f6', 0.28], [1, '#dbe9f1', 0]]));
  d.def('lowHaze', lg('{id}', [[0, '#ffffff', 0], [0.4, '#fbfdff', 0.3], [0.74, '#f3f9fc', 0.5], [1, '#eef6fa', 0.6]], 0, 540, 0, H));

  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sky)"/>`);
  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sunWide)"/>`);
  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sunMid)"/>`);
  d.add(`<rect x="0" y="0" width="${W}" height="${H}" fill="url(#sunCore)"/>`);

  // thin high cloud, very cold
  for (const [cx, cy, w, h] of [[420, 150, 820, 20], [1240, 200, 900, 24], [1740, 136, 520, 16], [700, 286, 940, 18], [180, 352, 620, 14]]) {
    d.add(`<path d="${cloudShape(cx, cy, w, h, r)}" fill="url(#clBody)" fill-opacity="0.55"/>`);
  }
  // drifting snow haze near the horizon
  for (const [cx, cy, w, h] of [[300, 632, 1000, 40], [1180, 668, 1300, 46], [760, 712, 1600, 52]]) {
    d.add(`<path d="${cloudShape(cx, cy, w, h, r)}" fill="url(#clBody)" fill-opacity="0.8"/>`);
  }
  // blowing snow: long low-contrast streaks
  for (let i = 0; i < 46; i++) {
    const y = 420 + r() * 560;
    const len = 90 + r() * 320;
    const x = 12 + r() * (W - 24 - len);
    const dy = -6 - r() * 10;
    d.add(`<path d="M${f1(x)},${f1(y)} Q${f1(x + len * 0.55)},${f1(y + dy * 0.6)} ${f1(x + len)},${f1(y + dy)}" fill="none" stroke="#ffffff" stroke-width="${f1(1 + r() * 3.4)}" stroke-opacity="${f1((0.1 + r() * 0.22) * 100) / 100}" stroke-linecap="round"/>`);
  }
  d.add(`<rect x="0" y="540" width="${W}" height="${H - 540}" fill="url(#lowHaze)"/>`);
  vignette(d);
  return d.svg();
}

function glacierFar() {
  const d = newDoc(W, H);
  const r = rng(7302);
  const rough = makeWave(r, 3, 10, 2.3, 0.5);

  const t1 = profileFn(forms([[280, 116, 210, 0, 0.85], [760, 148, 240, 0, 0.8], [1220, 96, 190, 0, 0.9], [1620, 132, 220, 0, 0.85], [1880, 106, 170, 0, 0.9]]), 620, { rough, roughAmp: 2.4 });
  const t2 = profileFn(forms([[200, 152, 210, 0, 0.82], [660, 196, 240, 0, 0.78], [1100, 130, 190, 0, 0.88], [1520, 182, 230, 0, 0.8], [1840, 142, 180, 0, 0.88]]), 690, { rough, roughAmp: 2.8, notches: makeNotches(r, 11, 16, 44, 12, 30) });
  const t3 = profileFn(forms([[320, 168, 230, 0, 0.85], [800, 210, 250, 0, 0.8], [1240, 140, 200, 0, 0.9], [1660, 190, 230, 0, 0.84], [1900, 152, 170, 0, 0.9]]), 760, { rough, roughAmp: 3.0, notches: makeNotches(r, 13, 18, 50, 14, 34) });

  d.def('i1', lg('{id}', [[0, mix(C.snow, '#b7cddc', 0.3)], [0.55, mix(C.ice, '#a9c4d6', 0.4)], [1, mix('#9db9cb', '#c5d9e5', 0.4)]], 0, 470, 0, 640));
  d.def('i2', lg('{id}', [[0, '#eaf2f7'], [0.4, mix(C.ice, '#b2cbdc', 0.4)], [1, mix(C.deepIce, C.snow, 0.42)]], 0, 520, 0, 710));
  d.def('i3', lg('{id}', [[0, C.snow], [0.34, C.ice], [0.72, mix(C.deepIce, C.ice, 0.4)], [1, mix(C.deepIce, C.shadow, 0.35)]], 0, 570, 0, 790));
  d.def('plain', lg('{id}', [[0, mix(C.snow, '#ffffff', 0.3)], [0.35, C.snow], [1, '#dfeaf1']], 0, 750, 0, H));
  d.def('haze', lg('{id}', [[0, '#ffffff', 0], [0.35, '#f7fbfd', 0.3], [0.7, '#f2f9fc', 0.4], [1, '#eef6fa', 0.28]], 0, 600, 0, H));

  d.add(`<path d="${massPath(t1, 1006, 6)}" fill="url(#i1)"/>`);
  d.add(`<path d="${massPath(t2, 1006, 6)}" fill="url(#i2)"/>`);
  d.add(`<path d="${massPath(t3, 1006, 6)}" fill="url(#i3)"/>`);

  // ice-fall seracs on the nearest ridge: bright crests + blue shadow
  for (let i = 0; i < 26; i++) {
    const x = 40 + (W - 80) * ((i + 0.5 + (r() - 0.5) * 0.7) / 26);
    const y0 = t3(x) + 16;
    if (y0 > 760) continue;
    const h = 26 + r() * 58;
    const w = 16 + r() * 34;
    d.add(`<path d="M${f1(x)},${f1(y0)} L${f1(x + w)},${f1(y0 + h * 0.55)} L${f1(x + w * 0.25)},${f1(y0 + h)} L${f1(x - w * 0.55)},${f1(y0 + h * 0.6)} Z" fill="${C.snow}" fill-opacity="${f1((0.4 + r() * 0.4) * 100) / 100}"/>`);
    d.add(`<path d="M${f1(x + w * 0.25)},${f1(y0 + h)} L${f1(x + w)},${f1(y0 + h * 0.55)} L${f1(x + w * 0.5)},${f1(y0 + h * 0.2)} Z" fill="${mix(C.deepIce, C.shadow, 0.3)}" fill-opacity="${f1((0.18 + r() * 0.2) * 100) / 100}"/>`);
  }

  // glacier tongue with longitudinal flow lines
  let dp = '';
  for (let x = 0; x <= W; x += 8) dp += (x === 0 ? 'M' : 'L') + f1(x) + ',' + f1(770 + 8 * Math.sin((TAU * 2 * x) / W + 1.1) + 4 * Math.sin((TAU * 7 * x) / W + 0.4)) + ' ';
  dp += `L${W},${H} L0,${H} Z`;
  d.add(`<path d="${dp}" fill="url(#plain)"/>`);
  for (let i = 0; i < 26; i++) {
    const y = 790 + r() * 260;
    const len = 120 + r() * 320;
    const x = 12 + r() * (W - 24 - len);
    d.add(`<path d="M${f1(x)},${f1(y)} C${f1(x + len * 0.35)},${f1(y - 5)} ${f1(x + len * 0.7)},${f1(y + 5)} ${f1(x + len)},${f1(y + 1)}" fill="none" stroke="${mix(C.deepIce, C.ice, 0.45)}" stroke-width="${f1(1 + r() * 2.6)}" stroke-opacity="${f1((0.1 + r() * 0.16) * 100) / 100}" stroke-linecap="round"/>`);
  }
  // medial moraine: dark debris streaks
  for (let i = 0; i < 5; i++) {
    const x = 160 + r() * (W - 320);
    const len = 260 + r() * 420;
    d.add(`<path d="M${f1(x)},${f1(786 + r() * 30)} C${f1(x + 40)},${f1(850)} ${f1(x - 20)},${f1(940)} ${f1(x + len * 0.3)},${f1(1030)}" fill="none" stroke="${mix(C.shadow, '#4a5a63', 0.5)}" stroke-width="${f1(2 + r() * 5)}" stroke-opacity="${f1((0.1 + r() * 0.12) * 100) / 100}" stroke-linecap="round"/>`);
  }
  d.add(`<rect x="0" y="600" width="${W}" height="${H - 600}" fill="url(#haze)"/>`);
  return d.svg();
}

function glacierMid() {
  const d = newDoc(W, H);
  const r = rng(7303);
  const rough = makeWave(r, 4, 8, 2.4, 0.5);

  const tIce = profileFn(forms([[300, 196, 280, 1], [900, 246, 340, 1], [1500, 172, 260, 1], [1860, 206, 220, 1]]), 900, { rough, roughAmp: 3.2, notches: makeNotches(r, 12, 20, 58, 18, 44) });

  d.def('iceSlope', lg('{id}', [[0, mix(C.snow, '#e6f1f7', 0.4)], [0.28, C.ice], [0.62, mix(C.ice, C.deepIce, 0.28)], [0.86, mix(C.deepIce, C.ice, 0.22)], [1, mix(C.deepIce, C.shadow, 0.2)]], 0, 690, 0, 940));
  d.def('apron', lg('{id}', [[0, mix(C.ice, C.snow, 0.5)], [0.4, C.snow], [1, '#e4eff5']], 0, 920, 0, H));
  d.def('haze', lg('{id}', [[0, '#ffffff', 0], [0.5, '#fbffff', 0.22], [1, '#f5fbfd', 0]], 0, 730, 0, 900));

  rockFace(d, {
    top: tIce,
    baseY: 944,
    fillTo: 1010,
    gid: 'iceSlope',
    rim: '#ffffff',
    rimOp: 0.55,
    strata: [],
    gullies: [],
  });

  // pressure ridges: bright crest with a blue shadow beneath
  for (let i = 0; i < 9; i++) {
    const x = 150 + (W - 300) * ((i + 0.5 + (r() - 0.5) * 0.5) / 9);
    const y = 760 + r() * 130;
    if (y < tIce(x) + 30) continue;
    const w = 90 + r() * 150;
    const h = 14 + r() * 20;
    d.add(`<path d="M${f1(x - w / 2)},${f1(y)} Q${f1(x)},${f1(y - h * 1.4)} ${f1(x + w / 2)},${f1(y + 4)} Q${f1(x)},${f1(y + h * 0.5)} ${f1(x - w / 2)},${f1(y)} Z" fill="${C.snow}" fill-opacity="0.95"/>`);
    d.add(`<path d="M${f1(x - w / 2)},${f1(y + 2)} Q${f1(x)},${f1(y + h * 0.6)} ${f1(x + w / 2)},${f1(y + 6)} Q${f1(x)},${f1(y + h * 0.9)} ${f1(x - w / 2)},${f1(y + 2)} Z" fill="${mix(C.deepIce, C.shadow, 0.35)}" fill-opacity="0.35"/>`);
  }

  // crevasse field: lens shaped fissures, white lip on top, blue body
  for (let i = 0; i < 54; i++) {
    const y = 700 + (i / 54) * 250 + (r() - 0.5) * 26;
    const x = 40 + r() * (W - 80);
    if (y < tIce(x) + 26) continue;
    const len = 40 + r() * 160;
    const th = 4 + r() * 10;
    const tilt = (r() - 0.5) * 16;
    if (x - len < 6 || x + len > W - 6) continue;
    const body = `M${f1(x - len)},${f1(y)} Q${f1(x)},${f1(y - th * 1.3)} ${f1(x + len)},${f1(y + tilt)} Q${f1(x)},${f1(y + th * 0.7)} ${f1(x - len)},${f1(y)} Z`;
    const lip = `M${f1(x - len)},${f1(y - 1)} Q${f1(x)},${f1(y - th * 1.3 - 2.5)} ${f1(x + len)},${f1(y + tilt - 1)} Q${f1(x)},${f1(y - th * 1.3 + 2.4)} ${f1(x - len)},${f1(y - 1)} Z`;
    d.add(`<path d="${lip}" fill="${C.snow}" fill-opacity="0.9"/>`);
    d.add(`<path d="${body}" fill="${pick(r, [C.deepIce, mix(C.deepIce, C.shadow, 0.45), mix(C.shadow, C.deepIce, 0.3)])}" fill-opacity="${f1((0.55 + r() * 0.35) * 100) / 100}"/>`);
    // inner shadow at the deep end
    d.add(`<path d="M${f1(x - len * 0.2)},${f1(y + th * 0.1)} Q${f1(x + len * 0.4)},${f1(y - th * 0.2 + tilt * 0.4)} ${f1(x + len * 0.8)},${f1(y + tilt * 0.8)} Q${f1(x + len * 0.3)},${f1(y + th * 0.5)} ${f1(x - len * 0.2)},${f1(y + th * 0.1)} Z" fill="${C.shadow}" fill-opacity="0.3"/>`);
  }

  // a meltwater channel meandering down the ice
  const chX = 1180;
  let ch = `M${chX},716`;
  let cx0 = chX;
  for (let i = 0; i < 7; i++) {
    cx0 += (r() - 0.5) * 90;
    const c1 = clamp(cx0 + 40, 20, W - 20);
    const c2 = clamp(cx0 + (r() - 0.5) * 70, 100, W - 100);
    ch += ` Q${f1(c1)},${f1(760 + i * 34)} ${f1(c2)},${f1(786 + i * 34)}`;
  }
  d.add(`<path d="${ch}" fill="none" stroke="${mix(C.shadow, '#3f6076', 0.4)}" stroke-width="7" stroke-opacity="0.35" stroke-linecap="round"/>`);
  d.add(`<path d="${ch}" fill="none" stroke="${mix(C.deepIce, C.shadow, 0.5)}" stroke-width="3" stroke-opacity="0.5" stroke-linecap="round"/>`);
  d.add(`<path d="${ch}" fill="none" stroke="#ffffff" stroke-width="1.2" stroke-opacity="0.4" stroke-linecap="round" transform="translate(0,-3)"/>`);

  d.add(`<rect x="0" y="730" width="${W}" height="170" fill="url(#haze)"/>`);

  let da = '';
  for (let x = 0; x <= W; x += 8) da += (x === 0 ? 'M' : 'L') + f1(x) + ',' + f1(926 + 9 * Math.sin((TAU * 2 * x) / W + 0.5) + 4 * Math.sin((TAU * 6 * x) / W + 2.0)) + ' ';
  da += `L${W},${H} L0,${H} Z`;
  d.add(`<path d="${da}" fill="url(#apron)"/>`);
  for (let i = 0; i < 30; i++) {
    const x = 30 + r() * (W - 220);
    const y = 950 + r() * 110;
    d.add(`<path d="M${f1(x)},${f1(y)} q${f1(20 + r() * 50)},${f1(-3 - r() * 4)} ${f1(50 + r() * 80)},${f1(1)}" fill="none" stroke="#ffffff" stroke-width="${f1(1 + r() * 2.4)}" stroke-opacity="${f1((0.16 + r() * 0.18) * 100) / 100}" stroke-linecap="round"/>`);
  }
  return d.svg();
}

function glacierNear() {
  const d = newDoc(W, H);
  const r = rng(7304);
  const rough = makeWave(r, 4, 7, 2.5, 0.55);
  const pBase = makePeaks(r, { n: 7, hMin: 18, hMax: 52, wMin: 170, wMax: 330, flat: true });
  const tBase = profileFn(pBase, 1004, rough);

  d.def('nBase', lg('{id}', [[0, '#7fa6bd'], [0.45, '#5b7d92'], [1, '#3f5f74']], 0, 960, 0, H));
  d.def('serac', lg('{id}', [[0, '#eef7fb'], [0.36, '#cfe3ee'], [0.74, '#8fb3c8'], [1, '#6b8ea5']], 0, 800, 0, H));
  d.def('serac2', lg('{id}', [[0, '#dceef7'], [0.4, '#a9c9da'], [1, '#5b7d92']], 0, 830, 0, H));
  d.def('drift', lg('{id}', [[0, '#f4f9fc'], [0.5, '#e7f1f7'], [1, '#d3e4ee']], 0, 990, 0, H));

  d.add(`<path d="${massPath(tBase, H, 8)}" fill="url(#nBase)"/>`);

  const blocks = [
    { cx: 250, cy: 946, rx: 224, ry: 132, gid: 'serac' },
    { cx: 1470, cy: 962, rx: 240, ry: 140, gid: 'serac2' },
    { cx: 880, cy: 1032, rx: 230, ry: 80, gid: 'serac' },
  ];
  for (const o of blocks) {
    const pts = blobPts(o.cx, o.cy, o.rx, o.ry, r, 9, 0.2);
    d.add(`<path d="${polyPath(clipRect(pts, 0, 0, W, H))}" fill="url(#${o.gid})"/>`);
    // faceted ice: fans of flat planes
    for (let i = 0; i < 7; i++) {
      const a = Math.PI + (i / 6) * Math.PI;
      const b = Math.PI + ((i + 1) / 6) * Math.PI;
      const x1 = o.cx + Math.cos(a) * o.rx * 0.94;
      const y1 = o.cy + Math.sin(a) * o.ry * 0.94;
      const x2 = o.cx + Math.cos(b) * o.rx * 0.94;
      const y2 = o.cy + Math.sin(b) * o.ry * 0.94;
      const cxx = o.cx + (r() - 0.5) * 46;
      const cyy = o.cy + o.ry * 0.3;
      const shade = i % 3 === 0 ? '#8fb3c8' : i % 3 === 1 ? '#b8d5e4' : '#6f95ac';
      d.add(`<path d="M${f1(x1)},${f1(y1)} L${f1(x2)},${f1(y2)} L${f1(cxx)},${f1(cyy)} Z" fill="${shade}" fill-opacity="${f1((0.3 + r() * 0.28) * 100) / 100}"/>`);
    }
    // snow cap
    const cap = [];
    for (let i = 0; i <= 8; i++) {
      const a = Math.PI + (i / 8) * Math.PI;
      const k = 1 + 0.2 * Math.sin(a * 2 + 2.1) + 0.08 * Math.sin(a * 4 + 0.6);
      cap.push([o.cx + Math.cos(a) * o.rx * k, o.cy + Math.sin(a) * o.ry * k]);
    }
    for (let i = 8; i >= 0; i--) {
      const a = Math.PI + (i / 8) * Math.PI;
      const k = 1 + 0.2 * Math.sin(a * 2 + 2.1) + 0.08 * Math.sin(a * 4 + 0.6);
      cap.push([o.cx + Math.cos(a) * o.rx * k * 0.95, o.cy + Math.sin(a) * o.ry * k * 0.95 + 8 + 5 * Math.sin(i * 1.7)]);
    }
    d.add(`<path d="${polyPath(clipRect(cap, 0, 0, W, H))}" fill="${C.snow}" fill-opacity="0.92"/>`);
    // fracture lines
    for (let i = 0; i < 4; i++) {
      const x0 = clamp(o.cx + (r() - 0.5) * o.rx * 1.2, 4, W - 4);
      const y0 = clamp(o.cy - o.ry * 0.4 + r() * o.ry * 0.7, 4, H - 4);
      const x1 = x0 + (r() - 0.5) * 20;
      const y1 = y0 + 20 + r() * 30;
      const x2 = x1 + (r() - 0.5) * 24;
      const y2 = y1 + 14 + r() * 26;
      d.add(`<path d="M${f1(x0)},${f1(y0)} L${f1(clamp(x1, 2, W - 2))},${f1(clamp(y1, 2, H - 2))} L${f1(clamp(x2, 2, W - 2))},${f1(clamp(y2, 2, H - 2))}" fill="none" stroke="#4d6f85" stroke-width="${f1(1.4 + r() * 1.6)}" stroke-opacity="0.45" stroke-linecap="round"/>`);
    }
  }

  // snow drift at the very bottom of the frame
  let drift = '';
  for (let x = 0; x <= W; x += 8) drift += (x === 0 ? 'M' : 'L') + f1(x) + ',' + f1(1032 + 7 * Math.sin((TAU * 3 * x) / W + 1.7) + 3 * Math.sin((TAU * 9 * x) / W + 0.5)) + ' ';
  drift += `L${W},${H} L0,${H} Z`;
  d.add(`<path d="${drift}" fill="url(#drift)" fill-opacity="0.92"/>`);

  // blowing snow
  for (let i = 0; i < 30; i++) {
    const len = 90 + r() * 220;
    const x = 12 + r() * (W - 24 - len);
    const y = 930 + r() * 120;
    d.add(`<path d="M${f1(x)},${f1(y)} Q${f1(x + len * 0.5)},${f1(y - 4)} ${f1(x + len)},${f1(y + dy0(r))}" fill="none" stroke="#ffffff" stroke-width="${f1(1 + r() * 2.6)}" stroke-opacity="${f1((0.16 + r() * 0.18) * 100) / 100}" stroke-linecap="round"/>`);
  }
  return d.svg();
}

function dy0(r) {
  return -2 - r() * 6;
}

function glacierGround() {
  const d = newDoc(G, G);
  const r = rng(7305);
  d.def('base', lg('{id}', [[0, '#e4eef5'], [0.32, '#e9f2f7'], [0.68, '#dfeaf2'], [1, '#e4eef5']], 0, 0, 0, G));
  d.add(`<rect x="0" y="0" width="${G}" height="${G}" fill="url(#base)"/>`);

  const wrap = (pts, fill, op) => {
    for (const dx of [-G, 0, G]) {
      for (const dy of [-G, 0, G]) {
        const moved = pts.map((p) => [p[0] + dx, p[1] + dy]);
        const c = clipRect(moved, 0, 0, G, G);
        if (c.length > 2) d.add(`<path d="${polyPath(c)}" fill="${fill}" fill-opacity="${op}"/>`);
      }
    }
  };

  // wind-packed ripples
  for (let i = 0; i < 14; i++) {
    const y = r() * G;
    d.add(`<path d="M0,${f1(y)} Q${f1(G * 0.5)},${f1(y - 6 + r() * 12)} ${G},${f1(y + 4)}" fill="none" stroke="${pick(r, ['#cfe3ee', '#f2f7fa', '#c2dae8'])}" stroke-width="${f1(2 + r() * 9)}" stroke-opacity="${f1((0.16 + r() * 0.2) * 100) / 100}" stroke-linecap="round"/>`);
  }
  // blue shadow hollows
  for (let i = 0; i < 22; i++) {
    wrap(blobPts(r() * G, r() * G, 20 + r() * 55, 12 + r() * 30, r, 12, 0.24), pick(r, ['#a9c9da', '#9dbfd2', '#b6d3e3']), f1((0.16 + r() * 0.16) * 100) / 100);
  }
  // ice chips with lit edges
  for (let i = 0; i < 150; i++) {
    const cx = r() * G;
    const cy = r() * G;
    const rx = 2 + r() * 9;
    const ry = rx * (0.4 + r() * 0.5);
    wrap(blobPts(cx, cy + ry * 0.5, rx, ry, r, 7, 0.3), '#7fa6bd', f1((0.22 + r() * 0.2) * 100) / 100);
    wrap(blobPts(cx, cy, rx, ry, r, 7, 0.3), pick(r, ['#f2f7fa', '#ffffff', '#dcecf5']), f1((0.6 + r() * 0.35) * 100) / 100);
    wrap(ellipsePts(cx - rx * 0.15, cy - ry * 0.28, rx * 0.55, ry * 0.45, 7), mix(C.deepIce, C.snow, 0.7), f1((0.25 + r() * 0.3) * 100) / 100);
  }
  // crevice hairlines
  for (let i = 0; i < 6; i++) {
    const x = 30 + r() * (G - 60);
    const y = 30 + r() * (G - 60);
    let dd = `M${f1(x)},${f1(y)}`;
    let px = x;
    let py = y;
    for (let j = 0; j < 4; j++) {
      px += (r() - 0.3) * 26;
      py += 10 + r() * 26;
      dd += ` L${f1(clamp(px, 8, G - 8))},${f1(clamp(py, 8, G - 8))}`;
    }
    d.add(`<path d="${dd}" fill="none" stroke="${mix(C.shadow, C.deepIce, 0.3)}" stroke-width="${f1(1 + r())}" stroke-opacity="0.35" stroke-linecap="round"/>`);
  }
  // grit specks
  for (let i = 0; i < 150; i++) {
    const cx = 2 + r() * (G - 4);
    const cy = 2 + r() * (G - 4);
    d.add(`<ellipse cx="${f1(cx)}" cy="${f1(cy)}" rx="${f1(0.7 + r() * 2)}" ry="${f1(0.6 + r() * 1.5)}" fill="${pick(r, ['#7fa6bd', '#ffffff', '#5b7d92'])}" fill-opacity="${f1((0.16 + r() * 0.26) * 100) / 100}"/>`);
  }
  return d.svg();
}

/* ================================================================= PROPS === */

const P = 512;

function propDoc(fn) {
  const d = newDoc(P, P);
  d.def('sh', rg('{id}', [[0, '#000000', 0.34], [0.55, '#000000', 0.18], [1, '#000000', 0]], 256, 506, 210));
  fn(d);
  return d.svg();
}

function groundShadow(d, rx, op = 1) {
  d.add(`<ellipse cx="256" cy="503" rx="${f1(rx)}" ry="8" fill="#1a1512" fill-opacity="${f1(op * 0.3 * 100) / 100}"/>`);
  d.add(`<ellipse cx="256" cy="505" rx="${f1(rx * 0.68)}" ry="6" fill="#120e0b" fill-opacity="${f1(op * 0.32 * 100) / 100}"/>`);
}

function zagrosProps() {
  const dryOak = propDoc((d) => {
    const r = rng(8101);
    groundShadow(d, 150);
    // gnarled trunk
    d.add('<path d="M232,506 L240,430 L234,372 L242,326 L252,300 L272,304 L266,344 L270,382 L276,434 L282,506 Z" fill="#4a3a28"/>');
    d.add('<path d="M262,504 L264,432 L266,382 L272,346 L280,332 L276,392 L272,436 L276,504 Z" fill="#6b5540" fill-opacity="0.55"/>');
    // limbs
    d.add('<path d="M250,344 Q222,312 188,296 L180,306 Q214,326 240,368 Z" fill="#4a3a28"/>');
    d.add('<path d="M258,336 Q290,300 330,288 L336,298 Q300,314 270,360 Z" fill="#4a3a28"/>');
    d.add('<path d="M244,410 Q212,388 178,392 L176,402 Q212,404 240,428 Z" fill="#46351f"/>');
    d.add('<path d="M266,404 Q300,384 340,392 L342,402 Q304,398 272,420 Z" fill="#46351f"/>');
    // dry, open canopy: clusters of small leaf masses
    const clusters = [[170, 300, 46, 30], [250, 262, 54, 34], [330, 292, 44, 28], [206, 246, 36, 24], [300, 244, 38, 24], [148, 342, 34, 22], [352, 336, 30, 20], [250, 220, 30, 18]];
    for (const [cx, cy, rx, ry] of clusters) {
      for (let i = 0; i < 9; i++) {
        const x = cx + (r() - 0.5) * rx * 1.5;
        const y = cy + (r() - 0.5) * ry * 1.5;
        const rr2 = 6 + r() * 12;
        d.add(`<ellipse cx="${f1(x)}" cy="${f1(y)}" rx="${f1(rr2)}" ry="${f1(rr2 * 0.66)}" fill="${pick(r, ['#5d6238', '#6b6b3f', '#4a4f2c', '#77794a'])}" fill-opacity="${f1((0.72 + r() * 0.24) * 100) / 100}"/>`);
      }
    }
    // sun-lit top of the canopy
    for (let i = 0; i < 16; i++) {
      const x = 150 + r() * 220;
      const y = 216 + r() * 40;
      d.add(`<ellipse cx="${f1(x)}" cy="${f1(y)}" rx="${f1(5 + r() * 9)}" ry="${f1(3 + r() * 4)}" fill="#8b8a52" fill-opacity="${f1((0.35 + r() * 0.3) * 100) / 100}"/>`);
    }
    // dead twigs poking out
    for (let i = 0; i < 7; i++) {
      const x = 150 + r() * 220;
      const y = 250 + r() * 80;
      d.add(`<path d="M${f1(x)},${f1(y)} l${f1((r() - 0.5) * 40)},${f1(-18 - r() * 26)}" fill="none" stroke="#4a3a28" stroke-width="1.6" stroke-opacity="0.8" stroke-linecap="round"/>`);
    }
  });

  const slab = propDoc((d) => {
    const r = rng(8102);
    groundShadow(d, 190);
    d.add('<path d="M62,430 L196,318 L378,300 L448,372 L392,466 L140,482 Z" fill="#b6a88c"/>');
    d.add('<path d="M196,318 L378,300 L448,372 L300,392 Z" fill="#d8ccb2"/>');
    d.add('<path d="M62,430 L196,318 L300,392 L140,482 Z" fill="#8a7a5f"/>');
    d.add('<path d="M140,482 L300,392 L448,372 L392,466 Z" fill="#a3947a"/>');
    // strata
    for (let i = 0; i < 4; i++) {
      const y = 404 + i * 16;
      d.add(`<path d="M${f1(96 + i * 6)},${f1(y + 12)} L${f1(300)},${f1(y - 22)} L${f1(430 - i * 8)},${f1(y - 6)}" fill="none" stroke="#7b6a4e" stroke-width="${f1(2 + i * 0.6)}" stroke-opacity="0.35" stroke-linecap="round"/>`);
    }
    // crack + chip
    d.add('<path d="M250,330 L268,376 L246,404 L262,446" fill="none" stroke="#6d5334" stroke-width="2.4" stroke-opacity="0.5" stroke-linecap="round"/>');
    d.add('<path d="M196,318 L214,300 L240,306 L228,322 Z" fill="#e2d7c0" fill-opacity="0.7"/>');
    for (let i = 0; i < 6; i++) {
      const x = 110 + r() * 300;
      const y = 466 + r() * 32;
      d.add(`<ellipse cx="${f1(x)}" cy="${f1(y)}" rx="${f1(4 + r() * 9)}" ry="${f1(3 + r() * 4)}" fill="${pick(r, ['#cbbfa6', '#a3947a', '#8a7a5f'])}" fill-opacity="0.9"/>`);
    }
  });

  const scrub = propDoc((d) => {
    const r = rng(8103);
    groundShadow(d, 128, 0.8);
    for (let i = 0; i < 34; i++) {
      const x0 = 256 + (r() - 0.5) * 90;
      const x1 = 256 + (r() - 0.5) * 260;
      const y1 = 250 + r() * 130;
      d.add(`<path d="M${f1(x0)},506 Q${f1((x0 + x1) / 2 + (r() - 0.5) * 30)},${f1((506 + y1) / 2)} ${f1(x1)},${f1(y1)}" fill="none" stroke="${pick(r, ['#7a7448', '#8f8557', '#6a6439'])}" stroke-width="${f1(1.4 + r() * 2)}" stroke-opacity="0.95" stroke-linecap="round"/>`);
      for (let j = 0; j < 2; j++) {
        const lx = lerp(x0, x1, 0.55 + r() * 0.4);
        const ly = lerp(506, y1, 0.55 + r() * 0.4);
        d.add(`<ellipse cx="${f1(lx)}" cy="${f1(ly)}" rx="${f1(3 + r() * 6)}" ry="${f1(2 + r() * 3)}" fill="${pick(r, ['#8a8551', '#9a9159', '#767244'])}" fill-opacity="${f1((0.6 + r() * 0.3) * 100) / 100}"/>`);
      }
    }
    for (let i = 0; i < 9; i++) {
      const x = 150 + r() * 210;
      const y = 240 + r() * 90;
      d.add(`<ellipse cx="${f1(x)}" cy="${f1(y)}" rx="${f1(3 + r() * 4)}" ry="${f1(6 + r() * 4)}" fill="#a89464" fill-opacity="0.8"/>`);
    }
  });

  const wall = propDoc((d) => {
    const r = rng(8104);
    groundShadow(d, 210);
    // four courses of dry stone
    const courses = [[400, 436], [436, 468], [468, 494], [494, 508]];
    for (let c = 0; c < courses.length; c++) {
      const [y0, y1] = courses[c];
      let x = 44 + r() * 10;
      while (x < 470) {
        const w = Math.min(40 + r() * 54, 498 - x);
        const gap = x > 240 && x < 300 && c === 2 ? 18 : 3 + r() * 4;
        d.add(`<path d="M${f1(x)},${f1(y0 + r() * 3)} L${f1(x + w * 0.55)},${f1(y0 - 2 - r() * 4)} L${f1(x + w)},${f1(y0 + 2 + r() * 3)} L${f1(x + w - 2)},${f1(y1 + r() * 3)} L${f1(x + 3)},${f1(y1 - r() * 3)} Z" fill="${pick(r, ['#b0a389', '#a1957c', '#bcb098', '#948870'])}"/>`);
        d.add(`<path d="M${f1(x)},${f1(y0)} L${f1(x + w)},${f1(y0 + 2)}" fill="none" stroke="#efe4cd" stroke-width="1.6" stroke-opacity="0.45" stroke-linecap="round"/>`);
        x += w + gap;
      }
    }
    // capstones
    for (let i = 0; i < 5; i++) {
      const x = 46 + i * 88;
      d.add(`<path d="M${f1(x)},${f1(392 - r() * 6)} L${f1(x + 42)},${f1(386 - r() * 6)} L${f1(x + 86)},${f1(394 - r() * 4)} L${f1(x + 84)},${f1(410)} L${f1(x + 2)},${f1(410)} Z" fill="${pick(r, ['#c2b69c', '#b5a98f'])}"/>`);
      d.add(`<path d="M${f1(x)},${f1(398)} L${f1(x + 86)},${f1(394)}" fill="none" stroke="#7a6c53" stroke-width="2" stroke-opacity="0.4" stroke-linecap="round"/>`);
    }
    // fallen stones + grass at the base
    for (let i = 0; i < 5; i++) {
      const x = 90 + r() * 320;
      d.add(`<ellipse cx="${f1(x)}" cy="${f1(500 - r() * 12)}" rx="${f1(7 + r() * 10)}" ry="${f1(5 + r() * 5)}" fill="${pick(r, ['#a1957c', '#8d8168'])}"/>`);
    }
    for (let i = 0; i < 12; i++) {
      const x = 60 + r() * 390;
      d.add(`<path d="M${f1(x)},506 q${f1((r() - 0.5) * 8)},${f1(-10 - r() * 14)} ${f1((r() - 0.5) * 16)},${f1(-16 - r() * 18)}" fill="none" stroke="#7a7448" stroke-width="1.4" stroke-opacity="0.8" stroke-linecap="round"/>`);
    }
  });

  return { 'dry_oak.svg': dryOak, 'limestone_slab.svg': slab, 'scrub.svg': scrub, 'drystone_wall.svg': wall };
}

function alpineProps() {
  const guardrail = propDoc((d) => {
    const r = rng(8201);
    groundShadow(d, 200);
    // posts
    for (const x of [92, 408]) {
      d.add(`<path d="M${x - 9},508 L${x - 6},292 L${x + 8},292 L${x + 10},508 Z" fill="#55606b"/>`);
      d.add(`<path d="M${x - 6},300 L${x - 2},300 L${x},506 L${x - 6},506 Z" fill="#78848f" fill-opacity="0.7"/>`);
      d.add(`<circle cx="${x}" cy="330" r="3.4" fill="#2c353d"/><circle cx="${x}" cy="404" r="3.4" fill="#2c353d"/>`);
    }
    // W-beam
    d.add('<path d="M24,300 L488,296 L488,340 L24,344 Z" fill="#9aa7b2"/>');
    d.add('<path d="M24,300 L488,296 L488,308 L24,312 Z" fill="#d5e0e7"/>');
    d.add('<path d="M24,318 L488,314 L488,322 L24,326 Z" fill="#6c7883" fill-opacity="0.9"/>');
    d.add('<path d="M24,336 L488,332 L488,344 L24,348 Z" fill="#49545f"/>');
    d.add('<path d="M24,300 L488,296" fill="none" stroke="#eff5f9" stroke-width="2" stroke-opacity="0.6" stroke-linecap="round"/>');
    // snow piled against the posts
    for (const x of [92, 408, 240]) {
      d.add(`<ellipse cx="${x}" cy="498" rx="${f1(46 + r() * 26)}" ry="${f1(9 + r() * 4)}" fill="#e8eef2" fill-opacity="0.95"/>`);
    }
    d.add('<path d="M24,344 Q80,352 120,346 L120,352 Q70,358 24,350 Z" fill="#e8eef2" fill-opacity="0.6"/>');
  });

  const pole = propDoc((d) => {
    groundShadow(d, 96, 0.75);
    d.add('<path d="M248,508 L252,240 L262,240 L258,508 Z" fill="#2f3a45"/>');
    for (let i = 0; i < 5; i++) {
      const y = 250 + i * 52;
      d.add(`<path d="M${f1(252 - i * 0.1)},${y} L${f1(261 + i * 0.1)},${y - 0.6} L${f1(260 + i * 0.1)},${y + 26} L${f1(251 - i * 0.1)},${y + 26} Z" fill="${i % 2 ? '#2f3a45' : '#d9713a'}"/>`);
    }
    d.add('<path d="M251,300 L261,299.4 L260,312 L250,312.6 Z" fill="#f4f9fc" fill-opacity="0.95"/>');
    d.add('<path d="M253,508 L259,508 L258,468 L254,468 Z" fill="#e8eef2" fill-opacity="0.9"/>');
    d.add('<ellipse cx="256" cy="497" rx="54" ry="11" fill="#e8eef2" fill-opacity="0.95"/>');
    d.add('<ellipse cx="256" cy="494" rx="38" ry="8" fill="#ffffff" fill-opacity="0.7"/>');
    d.add('<path d="M246,240 L264,240 L262,232 L248,232 Z" fill="#3b4650"/>');
  });

  const cairn = propDoc((d) => {
    const r = rng(8203);
    groundShadow(d, 130, 0.85);
    const stones = [[504, 470, 78, 25], [466, 424, 66, 24], [422, 386, 54, 20], [386, 352, 44, 17], [352, 322, 34, 14], [322, 300, 24, 11]];
    for (let i = 0; i < stones.length; i++) {
      const [y, y2, rx, ry] = stones[i];
      const pts = [];
      for (let j = 0; j < 9; j++) {
        const a = Math.PI + (j / 8) * Math.PI;
        const k = 1 + 0.12 * Math.sin(a * 3 + i) + 0.07 * Math.sin(a * 5 + i * 2);
        pts.push([256 + Math.cos(a) * rx * k, (y + y2) / 2 + Math.sin(a) * ry * k]);
      }
      for (let j = 8; j >= 0; j--) {
        const a = Math.PI + (j / 8) * Math.PI;
        pts.push([256 + Math.cos(a) * rx * 0.94, (y + y2) / 2 + ry * 0.98]);
      }
      d.add(`<path d="${polyPath(pts)}" fill="${pick(r, ['#6f7d8c', '#7b8896', '#64717f'])}"/>`);
      d.add(`<path d="M${f1(256 - rx * 0.9)},${f1((y + y2) / 2 + 2)} Q256,${f1((y + y2) / 2 - ry * 0.5)} ${f1(256 + rx * 0.9)},${f1((y + y2) / 2)}" fill="none" stroke="#9fadb9" stroke-width="2.2" stroke-opacity="0.7" stroke-linecap="round"/>`);
      if (i % 2 === 0) {
        d.add(`<path d="M${f1(256 - rx * 0.75)},${f1((y + y2) / 2 - ry * 0.2)} Q256,${f1((y + y2) / 2 - ry * 0.85)} ${f1(256 + rx * 0.62)},${f1((y + y2) / 2 - ry * 0.1)} Q256,${f1((y + y2) / 2 + ry * 0.1)} ${f1(256 - rx * 0.75)},${f1((y + y2) / 2 - ry * 0.2)} Z" fill="#e8eef2" fill-opacity="0.9"/>`);
      }
    }
    d.add('<ellipse cx="256" cy="499" rx="96" ry="10" fill="#e8eef2" fill-opacity="0.9"/>');
  });

  const larch = propDoc((d) => {
    const r = rng(8204);
    groundShadow(d, 120, 0.8);
    d.add('<path d="M250,506 L254,120 L262,120 L262,506 Z" fill="#4a3a2a"/>');
    d.add('<path d="M258,502 L260,126 L262,126 L262,502 Z" fill="#6b5540" fill-opacity="0.5"/>');
    const tiers = [[120, 44], [172, 62], [226, 78], [282, 94], [340, 108], [400, 118], [456, 126]];
    for (const [y, w] of tiers) {
      for (let s = -1; s <= 1; s += 2) {
        d.add(`<path d="M258,${y + 8} Q${f1(258 + s * w * 0.5)},${f1(y - 4)} ${f1(258 + s * w)},${f1(y + 10)}" fill="none" stroke="#3f4f40" stroke-width="2.4" stroke-linecap="round"/>`);
        for (let i = 0; i < 7; i++) {
          const t = 0.3 + (i / 7) * 0.7;
          const x = 258 + s * w * t;
          const yy = y + 8 - t * 10 + (r() - 0.5) * 6;
          d.add(`<ellipse cx="${f1(x)}" cy="${f1(yy)}" rx="${f1(6 + r() * 7)}" ry="${f1(3 + r() * 3)}" fill="${pick(r, ['#4c5f4e', '#5b6e58', '#425444'])}" fill-opacity="0.95"/>`);
          if (r() > 0.45) d.add(`<ellipse cx="${f1(x)}" cy="${f1(yy - 2.4)}" rx="${f1(4 + r() * 5)}" ry="${f1(1.8 + r() * 1.6)}" fill="#e8eef2" fill-opacity="${f1((0.4 + r() * 0.4) * 100) / 100}"/>`);
        }
      }
    }
    d.add('<path d="M256,120 L252,96 L258,84 L264,98 L262,120 Z" fill="#4c5f4e"/>');
    d.add('<ellipse cx="256" cy="501" rx="82" ry="9" fill="#e8eef2" fill-opacity="0.9"/>');
  });

  return { 'guardrail.svg': guardrail, 'snow_pole.svg': pole, 'cairn.svg': cairn, 'larch.svg': larch };
}

function glacierProps() {
  const block = propDoc((d) => {
    const r = rng(8301);
    groundShadow(d, 170, 0.8);
    d.add('<path d="M74,442 L150,318 L318,286 L438,344 L406,462 L214,492 Z" fill="#a9c9da"/>');
    d.add('<path d="M150,318 L318,286 L438,344 L300,368 Z" fill="#eaf5fa"/>');
    d.add('<path d="M74,442 L150,318 L300,368 L214,492 Z" fill="#cfe3ee"/>');
    d.add('<path d="M214,492 L300,368 L438,344 L406,462 Z" fill="#8fb3c8"/>');
    d.add('<path d="M406,462 L438,344 L452,392 L420,470 Z" fill="#5b7d92" fill-opacity="0.75"/>');
    // fractures and internal bubbles
    d.add('<path d="M186,352 L214,404 L196,452" fill="none" stroke="#ffffff" stroke-width="2.2" stroke-opacity="0.6" stroke-linecap="round"/>');
    d.add('<path d="M330,320 L352,376 L338,430" fill="none" stroke="#5b7d92" stroke-width="2" stroke-opacity="0.45" stroke-linecap="round"/>');
    for (let i = 0; i < 8; i++) {
      const x = 140 + r() * 240;
      const y = 340 + r() * 120;
      d.add(`<circle cx="${f1(x)}" cy="${f1(y)}" r="${f1(1.6 + r() * 3.4)}" fill="#ffffff" fill-opacity="${f1((0.25 + r() * 0.35) * 100) / 100}"/>`);
    }
    // snow cap and drift at the base
    d.add('<path d="M150,318 L318,286 L438,344 L404,356 L316,306 L176,330 Z" fill="#ffffff" fill-opacity="0.92"/>');
    d.add('<ellipse cx="256" cy="492" rx="176" ry="16" fill="#f2f7fa" fill-opacity="0.95"/>');
    d.add('<ellipse cx="230" cy="484" rx="120" ry="9" fill="#ffffff" fill-opacity="0.7"/>');
    for (let i = 0; i < 5; i++) {
      const x = 110 + r() * 300;
      d.add(`<path d="M${f1(x)},${f1(494 + r() * 6)} l10,-6 l8,7 l-12,5 Z" fill="${pick(r, ['#cfe3ee', '#ffffff', '#a9c9da'])}"/>`);
    }
  });

  const fence = propDoc((d) => {
    const r = rng(8302);
    groundShadow(d, 200);
    for (const [x, lean] of [[84, -6], [256, 2], [428, 5]]) {
      d.add(`<path d="M${x - 8},508 L${x - 8 + lean},296 L${x + 8 + lean},296 L${x + 8},508 Z" fill="#6b5a46"/>`);
      d.add(`<path d="M${x + 2 + lean},300 L${x + 7 + lean},300 L${x + 7},506 L${x + 2},506 Z" fill="#8a7458" fill-opacity="0.6"/>`);
      d.add(`<ellipse cx="${x + lean}" cy="296" rx="10" ry="4" fill="#e8eef2" fill-opacity="0.85"/>`);
    }
    for (const y of [330, 386, 442]) {
      d.add(`<path d="M30,${y + 6} L470,${y - 2} L470,${y + 22} L30,${y + 30} Z" fill="#8a7458"/>`);
      d.add(`<path d="M30,${y + 6} L470,${y - 2} L470,${y + 8} L30,${y + 16} Z" fill="#e8eef2" fill-opacity="0.8"/>`);
      d.add(`<path d="M30,${y + 26} L470,${y + 18} L470,${y + 22} L30,${y + 30} Z" fill="#5a4a38" fill-opacity="0.6"/>`);
      for (let i = 0; i < 4; i++) {
        const x = 60 + i * 120 + r() * 20;
        d.add(`<path d="M${f1(x)},${f1(y + 10)} l3,14" stroke="#4c3f30" stroke-width="1.6" stroke-opacity="0.5"/>`);
      }
    }
    d.add('<path d="M20,470 Q120,452 220,468 Q330,484 480,464 L492,512 L12,512 Z" fill="#f2f7fa" fill-opacity="0.95"/>');
    d.add('<path d="M30,478 Q140,462 250,476 Q360,490 470,472" fill="none" stroke="#ffffff" stroke-width="3" stroke-opacity="0.6" stroke-linecap="round"/>');
  });

  const flag = propDoc((d) => {
    const r = rng(8303);
    groundShadow(d, 110, 0.8);
    d.add('<path d="M248,508 L252,128 L262,128 L258,508 Z" fill="#a8935f"/>');
    d.add('<path d="M257,504 L259,134 L262,134 L262,504 Z" fill="#c7b27a" fill-opacity="0.65"/>');
    // flag
    d.add('<path d="M262,140 L396,166 Q404,182 396,198 L262,196 Z" fill="#c9502f"/>');
    d.add('<path d="M262,168 L392,182 Q396,190 392,198 L262,196 Z" fill="#e8eef2" fill-opacity="0.9"/>');
    d.add('<path d="M262,140 L396,166" fill="none" stroke="#f2b39a" stroke-width="2.2" stroke-opacity="0.7" stroke-linecap="round"/>');
    d.add('<path d="M262,196 L396,198" fill="none" stroke="#8e3a22" stroke-width="2" stroke-opacity="0.6"/>');
    // reflective band + snow base
    d.add('<path d="M250,304 L260,303.6 L259.6,320 L249.6,320.4 Z" fill="#f4f9fc"/>');
    d.add('<ellipse cx="256" cy="497" rx="66" ry="11" fill="#f2f7fa" fill-opacity="0.95"/>');
    d.add('<ellipse cx="250" cy="493" rx="40" ry="7" fill="#ffffff" fill-opacity="0.7"/>');
    d.add('<path d="M246,128 L264,128 L262,118 L248,118 Z" fill="#8a7458"/>');
  });

  return { 'ice_block.svg': block, 'snow_fence.svg': fence, 'marker_flag.svg': flag };
}

/* ================================================================== main === */

const log = [];
function write(rel, text) {
  const abs = path.join(ROOT, rel);
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, text, 'utf8');
  log.push([rel, Buffer.byteLength(text, 'utf8')]);
}

const sets = {
  zagros: { sky: zagrosSky, far: zagrosFar, mid: zagrosMid, near: zagrosNear, ground: zagrosGround, props: zagrosProps() },
  alpine: { sky: alpineSky, far: alpineFar, mid: alpineMid, near: alpineNear, ground: alpineGround, props: alpineProps() },
  glacier: { sky: glacierSky, far: glacierFar, mid: glacierMid, near: glacierNear, ground: glacierGround, props: glacierProps() },
};

for (const [region, s] of Object.entries(sets)) {
  for (const layer of ['sky', 'far', 'mid', 'near', 'ground']) {
    write(`assets/environments/${region}/${layer}.svg`, s[layer]());
  }
  for (const [name, text] of Object.entries(s.props)) {
    write(`assets/environments/${region}/${name}`, text);
  }
}

let total = 0;
for (const [rel, size] of log) {
  total += size;
  console.log(`${String(size).padStart(7)} B  ${rel}`);
}
console.log(`\n${log.length} files, ${(total / 1024).toFixed(1)} KB total`);
