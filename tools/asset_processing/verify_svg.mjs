#!/usr/bin/env node
/**
 * MUDRO asset geometry check.
 * Parses every <path> with a real SVG path tokenizer (absolute + relative
 * commands, curves, arcs), resolves it to absolute points and asserts that all
 * geometry sits inside the document canvas. Also checks ellipse/circle/rect.
 *
 * Run: node tools/asset_processing/verify_svg.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const files = [];
for (const region of ['zagros', 'alpine', 'glacier']) {
  const dir = path.join(ROOT, 'assets/environments', region);
  for (const f of fs.readdirSync(dir).filter((n) => n.endsWith('.svg')).sort()) {
    files.push(path.join(dir, f));
  }
}

const numRe = /[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?/g;

/** Returns array of absolute points touched by the path. */
function pathPoints(d) {
  const tokens = d.match(/[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?/g) || [];
  const pts = [];
  let i = 0;
  let cmd = '';
  let cx = 0;
  let cy = 0;
  let sx = 0;
  let sy = 0;
  const push = (x, y) => {
    pts.push([x, y]);
  };
  const take = () => {
    while (i < tokens.length && /^[A-Za-z]$/.test(tokens[i])) {
      cmd = tokens[i];
      i++;
    }
    const v = parseFloat(tokens[i]);
    i++;
    return v;
  };
  const hasNum = () => i < tokens.length && !/^[A-Za-z]$/.test(tokens[i]);

  while (i < tokens.length) {
    if (/^[A-Za-z]$/.test(tokens[i])) {
      cmd = tokens[i];
      i++;
      if (cmd === 'Z' || cmd === 'z') {
        cx = sx;
        cy = sy;
        continue;
      }
    }
    const rel = cmd === cmd.toLowerCase();
    const C = cmd.toUpperCase();
    if (C === 'M') {
      const x = parseFloat(tokens[i++]);
      const y = parseFloat(tokens[i++]);
      cx = rel ? cx + x : x;
      cy = rel ? cy + y : y;
      sx = cx;
      sy = cy;
      push(cx, cy);
      cmd = rel ? 'l' : 'L';
    } else if (C === 'L') {
      const x = parseFloat(tokens[i++]);
      const y = parseFloat(tokens[i++]);
      cx = rel ? cx + x : x;
      cy = rel ? cy + y : y;
      push(cx, cy);
    } else if (C === 'H') {
      const x = parseFloat(tokens[i++]);
      cx = rel ? cx + x : x;
      push(cx, cy);
    } else if (C === 'V') {
      const y = parseFloat(tokens[i++]);
      cy = rel ? cy + y : y;
      push(cx, cy);
    } else if (C === 'C') {
      for (let k = 0; k < 3; k++) {
        const x = parseFloat(tokens[i++]);
        const y = parseFloat(tokens[i++]);
        push(rel ? cx + x : x, rel ? cy + y : y);
        if (k === 2) {
          cx = rel ? cx + x : x;
          cy = rel ? cy + y : y;
        }
      }
    } else if (C === 'S' || C === 'Q') {
      for (let k = 0; k < 2; k++) {
        const x = parseFloat(tokens[i++]);
        const y = parseFloat(tokens[i++]);
        push(rel ? cx + x : x, rel ? cy + y : y);
        if (k === 1) {
          cx = rel ? cx + x : x;
          cy = rel ? cy + y : y;
        }
      }
    } else if (C === 'T') {
      const x = parseFloat(tokens[i++]);
      const y = parseFloat(tokens[i++]);
      cx = rel ? cx + x : x;
      cy = rel ? cy + y : y;
      push(cx, cy);
    } else if (C === 'A') {
      const rx = parseFloat(tokens[i++]);
      const ry = parseFloat(tokens[i++]);
      const rot = parseFloat(tokens[i++]);
      const laf = parseFloat(tokens[i++]);
      const sf = parseFloat(tokens[i++]);
      const x = parseFloat(tokens[i++]);
      const y = parseFloat(tokens[i++]);
      const ex = rel ? cx + x : x;
      const ey = rel ? cy + y : y;
      push(ex, ey);
      cx = ex;
      cy = ey;
      void rx; void ry; void rot; void laf; void sf;
    } else {
      i++; // unknown token: skip defensively
    }
  }
  return pts;
}

let bad = 0;
const rows = [];
for (const file of files) {
  const raw = fs.readFileSync(file, 'utf8');
  const w = parseFloat(raw.match(/width="([\d.]+)"/)[1]);
  const h = parseFloat(raw.match(/height="([\d.]+)"/)[1]);
  let minX = Infinity;
  let maxX = -Infinity;
  let minY = Infinity;
  let maxY = -Infinity;
  let outside = 0;
  const offenders = [];

  const scan = (x, y, tag) => {
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
    if (x < -0.05 || x > w + 0.05 || y < -0.05 || y > h + 0.05) {
      outside++;
      if (offenders.length < 3) offenders.push(`${tag} @ ${x.toFixed(1)},${y.toFixed(1)}`);
    }
  };

  for (const m of raw.matchAll(/<path\b[^>]*\bd="([^"]+)"/g)) {
    for (const [x, y] of pathPoints(m[1])) scan(x, y, 'path');
  }
  for (const m of raw.matchAll(/<ellipse\b([^>]*)>/g)) {
    const a = m[1];
    const get = (k) => parseFloat((a.match(new RegExp(k + '="([^"]+)"')) || [0, '0'])[1]);
    const cx = get('cx');
    const cy = get('cy');
    const rx = get('rx');
    const ry = get('ry');
    scan(cx - rx, cy - ry, 'ellipse');
    scan(cx + rx, cy + ry, 'ellipse');
  }
  for (const m of raw.matchAll(/<circle\b([^>]*)>/g)) {
    const a = m[1];
    const get = (k) => parseFloat((a.match(new RegExp(k + '="([^"]+)"')) || [0, '0'])[1]);
    scan(get('cx') - get('r'), get('cy') - get('r'), 'circle');
    scan(get('cx') + get('r'), get('cy') + get('r'), 'circle');
  }
  for (const m of raw.matchAll(/<rect\b([^>]*)>/g)) {
    const a = m[1];
    const get = (k) => parseFloat((a.match(new RegExp(k + '="([^"]+)"')) || [0, '0'])[1]);
    scan(get('x'), get('y'), 'rect');
    scan(get('x') + get('width'), get('y') + get('height'), 'rect');
  }

  const kb = (Buffer.byteLength(raw, 'utf8') / 1024).toFixed(1);
  const status = outside === 0 ? 'OK' : 'OUT';
  if (outside !== 0) bad++;
  rows.push({
    file: path.relative(ROOT, file).replace(/\\/g, '/'),
    canvas: `${w}x${h}`,
    kb,
    bounds: `${minX.toFixed(1)}..${maxX.toFixed(1)} x ${minY.toFixed(1)}..${maxY.toFixed(1)}`,
    outside,
    note: offenders.join(' | '),
    status,
  });
}

const pad = (s, n) => String(s).padEnd(n);
console.log(pad('file', 46) + pad('canvas', 10) + pad('KB', 7) + pad('bounds', 34) + pad('out', 5) + 'note');
for (const r of rows) {
  console.log(pad(r.file, 46) + pad(r.canvas, 10) + pad(r.kb, 7) + pad(r.bounds, 34) + pad(r.outside, 5) + r.note);
}
console.log(`\n${rows.length} files, ${bad} with geometry outside the canvas`);
process.exit(bad === 0 ? 0 : 1);
