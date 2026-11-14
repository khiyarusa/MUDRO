#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
black_ridge.py - deterministic SVG generator for the Black Ridge region.

Produces the 5 parallax layers of the dark mining region plus 6 industrial
obstacle props.  Everything is hand-built vector geometry: the only SVG
features used are paths, polygons, ellipses, rects, groups, linearGradient,
radialGradient and opacity.  No filters, no raster, no fonts, no external
references - Godot's ThorVG rasterizer handles all of it.

Run with the real interpreter (the `python` on PATH is a stub):

    & "C:\\Users\\Faraz_pc\\AppData\\Local\\Programs\\Python\\Python314\\python.exe" tools/artgen/black_ridge.py

The script is deterministic: every file uses its own seeded RNG, so repeated
runs produce byte-identical output.
"""

from __future__ import annotations

import math
import os
import random
import re
from xml.etree import ElementTree as ET

# --------------------------------------------------------------------------
# paths
# --------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))

BLACK_RIDGE = "assets/environments/black_ridge"
COMMON = "assets/environments/common"

MAX_BYTES = 400 * 1024

# --------------------------------------------------------------------------
# palette
# --------------------------------------------------------------------------
# The seven anchors from the art brief.  Everything else is either an
# interpolation between two anchors (used only inside gradients, which the
# renderer would interpolate anyway) or one of the two horizon tones the brief
# names explicitly (#2a2e33 sky top, #6d6a63 horizon).

CHARCOAL = "#17191b"
GRAPHITE = "#24272a"
GUNMETAL = "#343a40"
ASH = "#6b6560"
WARM = "#8a8075"
OLIVE = "#4a4f42"
SLATE = "#4a5560"
AMBER = "#b07a33"

INK = "#101214"          # charcoal, one step deeper (deepest occlusion)
SKY_TOP = "#2a2e33"      # brief: sky gradient top
HORIZON = "#6d6a63"      # brief: sky gradient horizon


def mix(c1: str, c2: str, t: float) -> str:
    """Linear blend of two hex colours; t=0 -> c1, t=1 -> c2."""
    a = [int(c1[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(c2[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(a[i] + (b[i] - a[i]) * t):02x}" for i in range(3))


# --------------------------------------------------------------------------
# numbers / attributes
# --------------------------------------------------------------------------

def n(v) -> str:
    """Compact number formatting - keeps the SVG files small."""
    if isinstance(v, str):
        return v
    if abs(v) < 0.0005:
        return "0"
    if abs(v - round(v)) < 0.0005:
        return str(int(round(v)))
    return f"{v:.2f}".rstrip("0").rstrip(".")


def _attrs(kw: dict) -> str:
    out = []
    for k, v in kw.items():
        if v is None:
            continue
        out.append(f'{k.replace("_", "-")}="{v if isinstance(v, str) else n(v)}"')
    return " ".join(out)


def el(tag: str, **kw) -> str:
    return f"<{tag} {_attrs(kw)}/>"


def path(d: str, **kw) -> str:
    return el("path", d=d, **kw)


def poly(pts, **kw) -> str:
    return el("polygon", points=" ".join(f"{n(x)},{n(y)}" for x, y in pts), **kw)


def ell(cx, cy, rx, ry, **kw) -> str:
    return el("ellipse", cx=cx, cy=cy, rx=rx, ry=ry, **kw)


def circ(cx, cy, r, **kw) -> str:
    return el("circle", cx=cx, cy=cy, r=r, **kw)


def rect(x, y, w, h, **kw) -> str:
    return el("rect", x=x, y=y, width=w, height=h, **kw)


def group(children, **kw) -> str:
    inner = "".join(children)
    return f"<g {_attrs(kw)}>{inner}</g>" if kw else f"<g>{inner}</g>"


# --------------------------------------------------------------------------
# gradients
# --------------------------------------------------------------------------

def lin(gid: str, stops, x1, y1, x2, y2, units="userSpaceOnUse") -> str:
    body = "".join(
        f'<stop offset="{n(o)}" stop-color="{c}" stop-opacity="{n(a)}"/>'
        for o, c, a in stops
    )
    return (
        f'<linearGradient id="{gid}" gradientUnits="{units}" '
        f'x1="{n(x1)}" y1="{n(y1)}" x2="{n(x2)}" y2="{n(y2)}">{body}</linearGradient>'
    )


def rad(gid: str, stops, cx, cy, r, fx=None, fy=None) -> str:
    body = "".join(
        f'<stop offset="{n(o)}" stop-color="{c}" stop-opacity="{n(a)}"/>'
        for o, c, a in stops
    )
    extra = ""
    if fx is not None:
        extra += f' fx="{n(fx)}"'
    if fy is not None:
        extra += f' fy="{n(fy)}"'
    return (
        f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" '
        f'cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}"{extra}>{body}</radialGradient>'
    )


def rad_obb(gid: str, stops, cx=0.5, cy=0.5, r=0.5) -> str:
    """Object-bounding-box radial - reusable for every lamp glow."""
    body = "".join(
        f'<stop offset="{n(o)}" stop-color="{c}" stop-opacity="{n(a)}"/>'
        for o, c, a in stops
    )
    return (
        f'<radialGradient id="{gid}" cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}">{body}</radialGradient>'
    )


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def d_of(pts, close=True) -> str:
    d = "M" + "L".join(f"{n(x)},{n(y)}" for x, y in pts)
    return d + ("Z" if close else "")


def smooth_closed(pts, tension=1.0) -> str:
    """Catmull-Rom through every point, emitted as cubic beziers."""
    m = len(pts)
    k = tension / 6.0
    d = [f"M{n(pts[0][0])},{n(pts[0][1])}"]
    for i in range(m):
        p0 = pts[(i - 1) % m]
        p1 = pts[i]
        p2 = pts[(i + 1) % m]
        p3 = pts[(i + 2) % m]
        c1 = (p1[0] + (p2[0] - p0[0]) * k, p1[1] + (p2[1] - p0[1]) * k)
        c2 = (p2[0] - (p3[0] - p1[0]) * k, p2[1] - (p3[1] - p1[1]) * k)
        d.append(
            f"C{n(c1[0])},{n(c1[1])} {n(c2[0])},{n(c2[1])} {n(p2[0])},{n(p2[1])}"
        )
    d.append("Z")
    return "".join(d)


def lerp(a, b, t):
    return a + (b - a) * t


def poly_ellipse(cx, cy, rx, ry, steps=28, rot=0.0):
    pts = []
    for i in range(steps):
        a = 2 * math.pi * i / steps
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * math.cos(rot) - y * math.sin(rot),
                    cy + x * math.sin(rot) + y * math.cos(rot)))
    return pts


def clip_poly_rect(pts, x0, y0, x1, y1):
    """Sutherland-Hodgman against an axis aligned rect (used for stripes)."""
    def clip_edge(poly_, inside, intersect):
        out = []
        if not poly_:
            return out
        prev = poly_[-1]
        prev_in = inside(prev)
        for cur in poly_:
            cur_in = inside(cur)
            if cur_in:
                if not prev_in:
                    out.append(intersect(prev, cur))
                out.append(cur)
            elif prev_in:
                out.append(intersect(prev, cur))
            prev, prev_in = cur, cur_in
        return out

    def ix_x(x):
        def f(p, q):
            t = (x - p[0]) / (q[0] - p[0])
            return (x, p[1] + (q[1] - p[1]) * t)
        return f

    def ix_y(y):
        def f(p, q):
            t = (y - p[1]) / (q[1] - p[1])
            return (p[0] + (q[0] - p[0]) * t, y)
        return f

    out = list(pts)
    out = clip_edge(out, lambda p: p[0] >= x0, ix_x(x0))
    out = clip_edge(out, lambda p: p[0] <= x1, ix_x(x1))
    out = clip_edge(out, lambda p: p[1] >= y0, ix_y(y0))
    out = clip_edge(out, lambda p: p[1] <= y1, ix_y(y1))
    return out


def periodic_ridge(w, base, harmonics, samples=180, sharp=1.0, height=None):
    """Ridge that is *exactly* periodic over [0, w] - the seam is continuous.

    `height` normalises the tallest peak to that many pixels above `base`, so a
    ridge can never punch through the top of its plate by accident.
    """
    vals = []
    for i in range(samples + 1):
        x = w * i / samples
        raw = 0.0
        for amp, k, ph in harmonics:
            raw += amp * math.sin(2 * math.pi * k * x / w + ph)
        vals.append((x, raw))
    peak = max(max(0.0, v) for _, v in vals) or 1.0
    target = height if height is not None else peak
    pts = []
    for x, raw in vals:
        h = ((max(0.0, raw) / peak) ** sharp) * target
        pts.append((x, base - h))
    # snap the closing vertex so the seam is bit-identical, not just close
    pts[-1] = (float(w), pts[0][1])
    return pts


def ridge_to_bottom(pts, bottom):
    return d_of(pts + [(pts[-1][0], bottom), (pts[0][0], bottom)])


def tile_shifts(x, half, w):
    """x offsets (including 0) needed to draw a wrapped element near the seam."""
    if half * 2 >= w:
        return [0]
    out = []
    for k in (-1, 0, 1):
        xx = x + k * w
        if xx + half > 0 and xx - half < w:
            out.append(k * w)
    return out


def tile_shifts2(x, y, hw, hh, w, h):
    """(dx, dy) offsets that keep a wrapped element seamless in 2D."""
    xs = [k * w for k in (-1, 0, 1) if x + k * w + hw > 0 and x + k * w - hw < w]
    ys = [k * h for k in (-1, 0, 1) if y + k * h + hh > 0 and y + k * h - hh < h]
    return [(a, b) for a in xs for b in ys]


# --------------------------------------------------------------------------
# document
# --------------------------------------------------------------------------

class Doc:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.defs = []
        self.body = []

    def add(self, *items):
        for it in items:
            if it:
                self.body.append(it)

    def define(self, *items):
        for it in items:
            if it:
                self.defs.append(it)

    def render(self) -> str:
        defs = "<defs>" + "".join(self.defs) + "</defs>" if self.defs else ""
        return (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
            f'viewBox="0 0 {self.w} {self.h}">\n'
            + defs
            + "\n"
            + "".join(self.body)
            + "\n</svg>\n"
        )


# --------------------------------------------------------------------------
# shared drawing atoms
# --------------------------------------------------------------------------

def soft_shadow(doc, cx, cy, rx, ry, color=INK, layers=5, alpha=0.16, squash=0.5):
    """Fake a blurred contact shadow with stacked translucent ellipses."""
    doc.add("".join(
        ell(cx, cy, rx * (1 + i * 0.06), ry * (1 + i * 0.06) * squash,
            fill=color, fill_opacity=n(alpha * (1 - i / (layers + 1.0)) ** 1.5))
        for i in range(layers)
    ))


def speck_cloud(doc, rng, x0, y0, x1, y1, count, rmin, rmax, color, amin, amax,
                wrap=None):
    """Scattered grain dots; wrap=(w,h) makes placement seamless in 2D."""
    out = []
    for _ in range(count):
        x = rng.uniform(x0, x1)
        y = rng.uniform(y0, y1)
        r = rng.uniform(rmin, rmax)
        a = rng.uniform(amin, amax)
        if wrap:
            w, h = wrap
            for dx, dy in tile_shifts2(x, y, r, r, w, h):
                out.append(circ(x + dx, y + dy, r, fill=color, fill_opacity=n(a)))
        else:
            out.append(circ(x, y, r, fill=color, fill_opacity=n(a)))
    doc.add("".join(out))


# --------------------------------------------------------------------------
# 1. sky
# --------------------------------------------------------------------------

def gen_sky() -> str:
    W, H = 1920, 1080
    doc = Doc(W, H)
    rng = random.Random(20261113)

    doc.define(
        lin("skyBase", [
            (0, SKY_TOP, 1), (0.30, mix(SKY_TOP, HORIZON, 0.26), 1),
            (0.52, mix(SKY_TOP, HORIZON, 0.47), 1),
            (0.72, mix(SKY_TOP, HORIZON, 0.66), 1),
            (0.88, mix(SKY_TOP, HORIZON, 0.86), 1),
            (1.0, HORIZON, 1),
        ], 0, 0, 0, H),
        rad("sunHaze", [
            (0, AMBER, 0.20), (0.22, AMBER, 0.13), (0.45, AMBER, 0.075),
            (0.70, AMBER, 0.03), (1, AMBER, 0),
        ], 1218, 812, 760),
        rad("sunCore", [
            (0, AMBER, 0.30), (0.45, AMBER, 0.18), (1, AMBER, 0),
        ], 1218, 812, 132),
        rad("vignette", [
            (0, CHARCOAL, 0), (0.62, CHARCOAL, 0.05), (1, CHARCOAL, 0.42),
        ], 960, 520, 1250),
        lin("horizonWash", [
            (0, HORIZON, 0), (0.42, HORIZON, 0.16), (0.80, HORIZON, 0.42),
            (1, HORIZON, 0.58),
        ], 0, 690, 0, 1080),
        lin("ashVeil", [
            (0, CHARCOAL, 0), (0.55, CHARCOAL, 0.20), (1, CHARCOAL, 0.34),
        ], 0, 0, 0, 300),
        lin("streakWarm", [
            (0, WARM, 0), (0.35, WARM, 0.075), (0.72, WARM, 0.05), (1, WARM, 0),
        ], 0, 0, 1, 0, units="objectBoundingBox"),
        lin("streakCool", [
            (0, SLATE, 0), (0.4, SLATE, 0.075), (0.75, SLATE, 0.045), (1, SLATE, 0),
        ], 0, 0, 1, 0, units="objectBoundingBox"),
    )

    # base sky
    doc.add(rect(0, 0, W, H, fill="url(#skyBase)"))

    # high heavy ceiling
    doc.add(rect(0, 0, W, 300, fill="url(#ashVeil)"))

    # ---- cloud builder --------------------------------------------------
    def cloud_band(y, thickness, amp, fill, op, rim=None, rim_op=0.0,
                   x0=-120, x1=W + 120, step=26):
        ph = [rng.uniform(0, math.tau) for _ in range(5)]
        top, bot = [], []
        x = x0
        while x <= x1:
            t = x / W
            env = 0.72 + 0.28 * math.sin(t * 2.3 + ph[0])
            rise = amp * env * (
                0.58 * math.sin(t * 3.4 + ph[1])
                + 0.30 * math.sin(t * 7.9 + ph[2] + 1.1)
                + 0.16 * math.sin(t * 15.3 + ph[3])
            )
            sag = thickness * (
                0.80 + 0.20 * math.sin(t * 2.1 + ph[4])
            ) + 0.42 * rise
            top.append((x, y - rise))
            bot.append((x, y - rise + sag))
            x += step
        d = "M" + "L".join(f"{n(px)},{n(py)}" for px, py in top)
        d += "L" + "L".join(f"{n(px)},{n(py)}" for px, py in reversed(bot)) + "Z"
        out = [path(d, fill=fill, fill_opacity=n(op))]
        if rim:
            rd = ("M" + "L".join(f"{n(px)},{n(py)}" for px, py in reversed(bot))
                  + "L" + "L".join(f"{n(px)},{n(py + 13)}" for px, py in reversed(bot))
                  + "Z")
            out.append(path(rd, fill=rim, fill_opacity=n(rim_op)))
        return "".join(out)

    # stacked overcast bands, far to near
    doc.add(cloud_band(168, 118, 34, mix(CHARCOAL, GRAPHITE, 0.35), 0.46,
                       rim=WARM, rim_op=0.022))
    doc.add(cloud_band(318, 156, 46, GRAPHITE, 0.55, rim=WARM, rim_op=0.030))
    doc.add(cloud_band(470, 178, 58, mix(GRAPHITE, GUNMETAL, 0.45), 0.50,
                       rim=WARM, rim_op=0.034))
    doc.add(cloud_band(632, 168, 50, GUNMETAL, 0.44, rim=WARM, rim_op=0.036))
    doc.add(cloud_band(760, 132, 34, SLATE, 0.26, rim=WARM, rim_op=0.030))

    # ---- sun haze -------------------------------------------------------
    doc.add(rect(0, 300, W, H - 300, fill="url(#sunHaze)"))
    doc.add(ell(1218, 812, 190, 74, fill=AMBER, fill_opacity=0.055))
    doc.add(ell(1218, 812, 96, 40, fill="url(#sunCore)"))
    doc.add(ell(1218, 812, 46, 21, fill=AMBER, fill_opacity=0.20))

    # weak shafts raking down-left out of the haze
    for i, (dx, wid, op) in enumerate(((-40, 210, 0.030), (-215, 150, 0.022),
                                       (150, 180, 0.018))):
        x = 1218 + dx
        d = (f"M{n(x)},{n(790)}L{n(x + wid)},{n(790)}"
             f"L{n(x + wid * 2.4)},{n(1080)}L{n(x + 40)},{n(1080)}Z")
        doc.add(path(d, fill=AMBER, fill_opacity=n(op)))

    # ---- long ash streaks ----------------------------------------------
    for _ in range(9):
        cy = rng.uniform(300, 880)
        cx = rng.uniform(60, W - 60)
        wdt = rng.uniform(320, 760)
        hgt = rng.uniform(5, 15)
        warm = rng.random() < 0.6
        d = (f"M{n(cx - wdt / 2)},{n(cy)}"
             f"Q{n(cx)},{n(cy - hgt)} {n(cx + wdt / 2)},{n(cy + hgt * 0.25)}"
             f"Q{n(cx)},{n(cy + hgt * 1.1)} {n(cx - wdt / 2)},{n(cy)}Z")
        doc.add(path(d, fill="url(#streakWarm)" if warm else "url(#streakCool)"))

    # ---- horizon --------------------------------------------------------
    doc.add(rect(0, 690, W, H - 690, fill="url(#horizonWash)"))
    doc.add(rect(0, 916, W, 2.5, fill=WARM, fill_opacity=0.16))
    doc.add(rect(0, 909, W, 7, fill=HORIZON, fill_opacity=0.20))
    doc.add(rect(0, 893, W, 22, fill=HORIZON, fill_opacity=0.11))

    # faint distant ridgeline so the horizon is not a hard rule
    ph = [rng.uniform(0, math.tau) for _ in range(4)]
    pts = []
    for i in range(97):
        x = W * i / 96
        h = (14 * math.sin(x / W * math.tau * 3 + ph[0])
             + 8 * math.sin(x / W * math.tau * 7 + ph[1])
             + 5 * math.sin(x / W * math.tau * 13 + ph[2]))
        pts.append((x, 918 - abs(h) - 6))
    doc.add(path(ridge_to_bottom(pts, 1080), fill=HORIZON, fill_opacity=0.16))
    doc.add(path(ridge_to_bottom([(x, y + 16) for x, y in pts], 1080),
                 fill=SLATE, fill_opacity=0.12))

    # ---- grain ----------------------------------------------------------
    speck_cloud(doc, rng, 0, 120, W, 1080, 430, 0.7, 1.9, ASH, 0.05, 0.15)
    speck_cloud(doc, rng, 0, 420, W, 1080, 120, 1.9, 3.4, WARM, 0.035, 0.085)
    speck_cloud(doc, rng, 0, 700, W, 1080, 90, 0.8, 1.6, WARM, 0.06, 0.14)

    # drifting ash motes, slightly elongated
    for _ in range(70):
        x = rng.uniform(0, W)
        y = rng.uniform(300, 1040)
        l = rng.uniform(2, 6)
        doc.add(path(f"M{n(x)},{n(y)}l{n(l)},{n(-l * 0.55)}",
                     stroke=WARM, stroke_width=n(rng.uniform(0.7, 1.2)),
                     stroke_opacity=n(rng.uniform(0.05, 0.12)),
                     stroke_linecap="round"))

    doc.add(rect(0, 0, W, H, fill="url(#vignette)"))
    return doc.render()


# --------------------------------------------------------------------------
# 2. far - three ridge bands, horizontally tileable
# --------------------------------------------------------------------------

def gen_far() -> str:
    W, H = 1600, 720
    doc = Doc(W, H)
    rng = random.Random(770212)

    doc.define(
        lin("farHaze", [
            (0, SLATE, 0), (0.45, SLATE, 0.13), (1, SLATE, 0.22),
        ], 0, 250, 0, 720),
        lin("midHaze", [
            (0, HORIZON, 0), (0.5, HORIZON, 0.10), (1, HORIZON, 0.05),
        ], 0, 380, 0, 620),
        lin("footShade", [
            (0, CHARCOAL, 0), (0.55, CHARCOAL, 0.45), (1, CHARCOAL, 0.9),
        ], 0, 560, 0, 720),
    )

    # ---- band A : farthest ------------------------------------------
    a = periodic_ridge(W, 344, [
        (46, 2, 0.4), (30, 3, 2.1), (18, 5, 4.0), (9, 9, 1.3), (5, 14, 5.2),
    ], samples=200, sharp=1.25, height=150)
    doc.add(path(ridge_to_bottom(a, H), fill=SLATE, fill_opacity=0.40))
    doc.add(path(ridge_to_bottom([(x, y + 26) for x, y in a], H),
                 fill=SLATE, fill_opacity=0.16))

    # facets on band A - very low contrast, atmospheric perspective
    for _ in range(26):
        i = rng.randrange(0, len(a) - 4)
        j = min(i + rng.randint(2, 4), len(a) - 1)
        seg = a[i:j + 1]
        if seg[-1][1] - seg[0][1] > -4:
            continue
        drop = rng.uniform(30, 90)
        pts = seg + [(seg[-1][0], seg[-1][1] + drop), (seg[0][0], seg[0][1] + drop)]
        doc.add(poly(pts, fill=SLATE, fill_opacity=n(rng.uniform(0.05, 0.11))))

    # ---- atmospheric haze between A and B ---------------------------
    doc.add(rect(0, 300, W, 240, fill="url(#farHaze)"))

    # ---- band B : middle --------------------------------------------
    b = periodic_ridge(W, 470, [
        (58, 2, 1.9), (36, 4, 5.1), (22, 6, 0.6), (11, 11, 3.3), (6, 17, 2.2),
    ], samples=210, sharp=1.30, height=190)
    doc.add(path(ridge_to_bottom(b, H), fill=GUNMETAL, fill_opacity=0.82))

    for _ in range(46):
        i = rng.randrange(0, len(b) - 5)
        j = min(i + rng.randint(2, 5), len(b) - 1)
        seg = b[i:j + 1]
        slope = seg[-1][1] - seg[0][1]
        if abs(slope) < 7:
            continue
        drop = rng.uniform(45, 130)
        pts = seg + [(seg[-1][0], seg[-1][1] + drop), (seg[0][0], seg[0][1] + drop)]
        lit = slope > 0
        doc.add(poly(pts, fill=WARM if lit else INK,
                     fill_opacity=n(rng.uniform(0.05, 0.13) if lit else rng.uniform(0.10, 0.20))))

    # gullies: thin dark wedges running down the faces
    for _ in range(20):
        i = rng.randrange(3, len(b) - 6)
        x, y = b[i]
        ln = rng.uniform(40, 120)
        wdt = rng.uniform(2, 7)
        doc.add(poly([(x, y + 4), (x + wdt, y + 6), (x + wdt * 0.6, y + ln),
                      (x - wdt * 0.4, y + ln * 0.9)],
                     fill=INK, fill_opacity=n(rng.uniform(0.10, 0.20))))

    # ash dusting on the lit shoulders
    for _ in range(16):
        i = rng.randrange(2, len(b) - 4)
        x, y = b[i]
        doc.add(ell(x + rng.uniform(-8, 8), y + rng.uniform(2, 9),
                    rng.uniform(16, 40), rng.uniform(4, 10),
                    fill=WARM, fill_opacity=n(rng.uniform(0.05, 0.10))))

    doc.add(rect(0, 380, W, 240, fill="url(#midHaze)"))

    # ---- band C : nearest ridge -------------------------------------
    c = periodic_ridge(W, 604, [
        (66, 2, 4.4), (44, 3, 1.2), (28, 5, 3.7), (15, 8, 5.6), (7, 13, 0.9),
    ], samples=220, sharp=1.32, height=235)
    doc.add(path(ridge_to_bottom(c, H), fill=CHARCOAL, fill_opacity=0.97))
    doc.add(path(ridge_to_bottom([(x, y + 18) for x, y in c], H),
                 fill=INK, fill_opacity=0.35))

    for _ in range(60):
        i = rng.randrange(0, len(c) - 5)
        j = min(i + rng.randint(2, 5), len(c) - 1)
        seg = c[i:j + 1]
        slope = seg[-1][1] - seg[0][1]
        if abs(slope) < 6:
            continue
        drop = rng.uniform(50, 150)
        pts = seg + [(seg[-1][0], seg[-1][1] + drop), (seg[0][0], seg[0][1] + drop)]
        lit = slope > 0
        doc.add(poly(pts, fill=WARM if lit else INK,
                     fill_opacity=n(rng.uniform(0.05, 0.10) if lit else rng.uniform(0.12, 0.24))))

    # crest rim light - a thin top-lit edge, only on peaks
    rim = []
    for i in range(1, len(c) - 1):
        x, y = c[i]
        if y <= c[i - 1][1] and y <= c[i + 1][1]:
            rim.append(f"M{n(x - 26)},{n(y + 3)}Q{n(x)},{n(y - 2)} {n(x + 22)},{n(y + 6)}")
    if rim:
        doc.add(path("".join(rim), fill="none", stroke=WARM, stroke_width="2",
                     stroke_opacity="0.14", stroke_linecap="round"))

    # scree fans at the foot of band C
    for _ in range(18):
        i = rng.randrange(2, len(c) - 3)
        x, y = c[i]
        wdt = rng.uniform(40, 110)
        doc.add(poly([(x - wdt * 0.35, y + 6), (x + wdt * 0.35, y + 4),
                      (x + wdt, 720), (x - wdt, 720)],
                     fill=INK, fill_opacity=n(rng.uniform(0.10, 0.18))))

    doc.add(rect(0, 560, W, 160, fill="url(#footShade)"))

    # ---- wrapped detail on band C -----------------------------------
    # a couple of sparse dead pines / survey poles so the ridge reads at scale
    for _ in range(7):
        x = rng.uniform(60, W - 60)
        i = min(range(len(c)), key=lambda k: abs(c[k][0] - x))
        y = c[i][1] + 2
        hgt = rng.uniform(16, 30)
        for dx in tile_shifts(x, 10, W):
            doc.add(path(f"M{n(x + dx)},{n(y)}l0,{n(-hgt)}", stroke=INK,
                         stroke_width="1.4", stroke_opacity="0.55"))
            for k in range(4):
                yy = y - hgt * (0.35 + k * 0.16)
                ln = (1 - k * 0.2) * 6
                doc.add(path(f"M{n(x + dx)},{n(yy)}l{n(-ln)},{n(-ln * 0.7)}"
                             f"M{n(x + dx)},{n(yy)}l{n(ln)},{n(-ln * 0.7)}",
                             stroke=INK, stroke_width="0.9", stroke_opacity="0.42"))

    # fine grain over the whole plate
    speck_cloud(doc, rng, 0, 200, W, 720, 150, 0.6, 1.5, ASH, 0.03, 0.08,
                wrap=(W, 720))
    return doc.render()


# --------------------------------------------------------------------------
# shared industrial atoms
# --------------------------------------------------------------------------

def lamp_glow(doc, x, y, r=26, core=0.6):
    doc.add(circ(x, y, r, fill="url(#lampGlow)"))
    doc.add(circ(x, y, max(1.6, r * 0.15), fill=AMBER, fill_opacity=n(core)))
    doc.add(circ(x, y, max(0.9, r * 0.07), fill=WARM, fill_opacity=n(0.9 * core)))


def truss_band(x1, y1, x2, y2, depth, panels, color, op, chord=5.0,
               diag=1.5, xbrace=False, rivets=False, rivet_color=None):
    """Two parallel chords with web members - conveyor gantry / bridge side."""
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    h = depth / 2.0

    def at(t, side):
        return (x1 + dx * t + nx * h * side, y1 + dy * t + ny * h * side)

    out = []
    for side in (1, -1):
        a = at(0.0, side)
        b = at(1.0, side)
        out.append(poly([
            (a[0] + nx * chord / 2, a[1] + ny * chord / 2),
            (b[0] + nx * chord / 2, b[1] + ny * chord / 2),
            (b[0] - nx * chord / 2, b[1] - ny * chord / 2),
            (a[0] - nx * chord / 2, a[1] - ny * chord / 2),
        ], fill=color, fill_opacity=n(op)))

    web = []
    for i in range(panels + 1):
        t = i / panels
        a, b = at(t, 1), at(t, -1)
        web.append(f"M{n(a[0])},{n(a[1])}L{n(b[0])},{n(b[1])}")
    for i in range(panels):
        t0, t1 = i / panels, (i + 1) / panels
        if xbrace or i % 2 == 0:
            a, b = at(t0, 1), at(t1, -1)
            web.append(f"M{n(a[0])},{n(a[1])}L{n(b[0])},{n(b[1])}")
        if xbrace or i % 2 == 1:
            a, b = at(t1, 1), at(t0, -1)
            web.append(f"M{n(a[0])},{n(a[1])}L{n(b[0])},{n(b[1])}")
    out.append(path("".join(web), fill="none", stroke=color,
                    stroke_width=n(diag), stroke_opacity=n(min(1.0, op * 0.95)),
                    stroke_linecap="round"))

    if rivets:
        rc = rivet_color or WARM
        dots = []
        for i in range(panels * 3 + 1):
            t = i / (panels * 3)
            for side in (1, -1):
                p = at(t, side)
                dots.append(circ(p[0], p[1], 1.15, fill=rc, fill_opacity=n(0.16)))
        out.append("".join(dots))
    return "".join(out)


def headframe(x, ground, top, spread, color, op, width=7.0):
    """Four-legged winding tower with sheave wheel - mid-distance silhouette."""
    out = []
    legs = []
    for side in (-1, 1):
        a = (x + side * spread, ground)
        b = (x + side * spread * 0.42, top)
        legs.append(poly([(a[0] - width, a[1]), (a[0] + width, a[1]),
                          (b[0] + width * 0.6, b[1]), (b[0] - width * 0.6, b[1])],
                         fill=color, fill_opacity=n(op)))
        out.append(legs[-1])
    # horizontal bracing
    braces = []
    for k in range(1, 5):
        t = k / 5
        xa = x - spread + (spread * 0.58) * t
        xb = x + spread - (spread * 0.58) * t
        yy = ground - (ground - top) * t
        braces.append(f"M{n(xa)},{n(yy)}L{n(xb)},{n(yy)}")
        braces.append(f"M{n(xa)},{n(yy)}L{n(xb)},{n(yy - (ground - top) / 5)}")
    out.append(path("".join(braces), fill="none", stroke=color,
                    stroke_width="2.2", stroke_opacity=n(op * 0.8)))
    # platform + sheave
    out.append(rect(x - spread * 0.6, top - 6, spread * 1.2, 7,
                    fill=color, fill_opacity=n(op)))
    out.append(rect(x - spread * 0.5, top - 20, spread * 1.0, 15,
                    fill=color, fill_opacity=n(op)))
    out.append(circ(x, top - 13, spread * 0.22, fill=color, fill_opacity=n(op)))
    out.append(circ(x, top - 13, spread * 0.22, fill="none", stroke=WARM,
                    stroke_width="1.6", stroke_opacity=n(op * 0.35)))
    spokes = [f"M{n(x - spread * 0.18)},{n(top - 13)}L{n(x + spread * 0.18)},{n(top - 13)}",
              f"M{n(x)},{n(top - 13 - spread * 0.18)}L{n(x)},{n(top - 13 + spread * 0.18)}"]
    out.append(path("".join(spokes), fill="none", stroke=WARM,
                    stroke_width="1", stroke_opacity=n(op * 0.3)))
    return "".join(out)


def spoil_heap(doc, cx, base_y, w, h, fill, op, rng, strata=True):
    n_pts = 24
    pts = []
    for i in range(n_pts + 1):
        t = i / n_pts
        yy = base_y - h * max(0.0, 1 - abs(2 * t - 1) ** 2.2) ** 0.62
        if 0 < i < n_pts:
            yy += rng.uniform(-1.8, 1.8)
        pts.append((cx - w / 2 + w * t, yy))
    doc.add(path(d_of(pts + [(cx + w / 2, base_y + 4), (cx - w / 2, base_y + 4)]),
                 fill=fill, fill_opacity=n(op)))
    # lit crown
    crown = [(p[0], p[1]) for p in pts if abs(p[1] - (base_y - h)) < h * 0.22]
    if len(crown) > 2:
        doc.add(path(d_of(crown + [(crown[-1][0], crown[-1][1] + 9),
                                   (crown[0][0], crown[0][1] + 9)]),
                     fill=WARM, fill_opacity=n(op * 0.10)))
    if strata:
        for k in (0.22, 0.40, 0.60, 0.78):
            half = (w / 2) * max(0.0, 1 - k ** (1 / 0.62)) ** (1 / 2.2)
            if half < 6:
                continue
            yy = base_y - h * k
            x0, x1 = cx - half * 0.88, cx + half * 0.88
            d = (f"M{n(x0)},{n(yy)}Q{n(cx)},{n(yy + 4)} {n(x1)},{n(yy - 1)}")
            doc.add(path(d, fill="none", stroke=INK, stroke_width="1.4",
                         stroke_opacity=n(0.16)))
    # talus at the foot
    doc.add(ell(cx, base_y + 2, w * 0.52, h * 0.12, fill=INK, fill_opacity=n(0.28)))


def dead_tree(doc, x, ground, height, rng, color=INK, op=0.85):
    out = []
    trunk_w = max(2.0, height * 0.045)
    out.append(poly([(x - trunk_w, ground), (x + trunk_w, ground),
                     (x + trunk_w * 0.42, ground - height * 0.62),
                     (x - trunk_w * 0.55, ground - height * 0.60)],
                    fill=color, fill_opacity=n(op)))

    def branch(bx, by, ang, ln, wdt, depth):
        ex = bx + math.cos(ang) * ln
        ey = by + math.sin(ang) * ln
        out.append(path(f"M{n(bx)},{n(by)}L{n(ex)},{n(ey)}", fill="none",
                        stroke=color, stroke_width=n(max(0.7, wdt)),
                        stroke_opacity=n(op * (0.95 if depth > 1 else 0.8)),
                        stroke_linecap="round"))
        if depth <= 0:
            return
        for s in (-1, 1):
            branch(ex, ey, ang + s * rng.uniform(0.30, 0.62),
                   ln * rng.uniform(0.52, 0.72), wdt * 0.62, depth - 1)

    top = ground - height * 0.60
    for s in (-1, 1):
        branch(x + s * trunk_w * 0.2, top, -math.pi / 2 + s * rng.uniform(0.28, 0.55),
               height * 0.42, trunk_w * 0.8, 3)
    return "".join(out)


def stepped_mass(widths, levels, level_h, base_y, bottom, slope=8.0):
    """Mine bench skyline: flat benches separated by short risers. Tile-safe if
    levels[0] == levels[-1] (the seam continues at the same elevation)."""
    ys = [base_y - lv * level_h for lv in levels]
    pts = [(0, ys[0])]
    x = 0
    steps = []
    for i, wd in enumerate(widths):
        nxt = ys[i + 1] if i + 1 < len(ys) else ys[0]
        steps.append((x, x + wd, ys[i], nxt))
        pts.append((x + wd - slope, ys[i]))
        pts.append((x + wd, nxt))
        x += wd
    pts.append((x, bottom))
    pts.append((0, bottom))
    return pts, steps


# --------------------------------------------------------------------------
# 3. mid - terraces, conveyor, headframe, spoil heaps
# --------------------------------------------------------------------------

def gen_mid() -> str:
    W, H = 1600, 720
    doc = Doc(W, H)
    rng = random.Random(5150221)

    doc.define(
        rad_obb("lampGlow", [(0, AMBER, 0.50), (0.30, AMBER, 0.20),
                             (0.62, AMBER, 0.06), (1, AMBER, 0)]),
        lin("midBackFog", [(0, WARM, 0), (0.5, WARM, 0.055), (1, WARM, 0.13)],
            0, 300, 0, 520),
        lin("midLowFog", [(0, WARM, 0), (0.55, WARM, 0.09), (1, WARM, 0.16)],
            0, 540, 0, 720),
        lin("midGround", [(0, CHARCOAL, 0), (0.35, CHARCOAL, 0.55), (1, INK, 0.96)],
            0, 600, 0, 720),
        lin("benchTop", [(0, WARM, 0.55), (1, WARM, 0.12)], 0, 0, 1, 0,
            units="objectBoundingBox"),
    )

    # ---- distant ridge behind the workings --------------------------
    back = periodic_ridge(W, 392, [
        (34, 2, 1.2), (24, 4, 3.4), (14, 7, 5.0), (7, 13, 2.0),
    ], samples=170, sharp=1.2, height=105)
    doc.add(path(ridge_to_bottom(back, H), fill=SLATE, fill_opacity=0.34))
    doc.add(rect(0, 300, W, 240, fill="url(#midBackFog)"))

    # second, nearer dark mass between ridge and benches
    back2 = periodic_ridge(W, 452, [
        (30, 3, 2.2), (20, 5, 0.4), (11, 9, 4.4),
    ], samples=170, sharp=1.15, height=75)
    doc.add(path(ridge_to_bottom(back2, H), fill=GUNMETAL, fill_opacity=0.55))

    # ---- bench terraces ---------------------------------------------
    widths = [200, 180, 220, 180, 240, 200, 200, 180]
    levels = [4, 5, 5, 3, 2, 1, 2, 4]
    lh = 34
    base_y = 470
    pts, steps = stepped_mass(widths, levels, lh, base_y, H)
    doc.add(path(d_of(pts), fill=GRAPHITE, fill_opacity=0.97))

    for (x0, x1, y, yn) in steps:
        # bench floor catching the weak top light
        doc.add(poly([(x0 + 6, y), (x1 - 8, y), (x1 - 10, y + 3.4), (x0 + 8, y + 3.4)],
                     fill=WARM, fill_opacity=n(rng.uniform(0.055, 0.085))))
        # shadowed riser face
        doc.add(poly([(x1 - 8, y), (x1, yn), (x1, yn + 16), (x1 - 8, y + 16)],
                     fill=INK, fill_opacity=0.30))
        # spill of loose rock at the toe of each riser
        for _ in range(2):
            rx = rng.uniform(x1 - 26, x1 - 2)
            doc.add(ell(rx, max(y, yn) + rng.uniform(2, 9),
                        rng.uniform(5, 14), rng.uniform(1.6, 3.6),
                        fill=INK, fill_opacity=n(rng.uniform(0.10, 0.20))))

    # faint haul-road tracks along the widest benches
    for (x0, x1, y, yn) in steps:
        if x1 - x0 < 190:
            continue
        for off in (5, 11):
            doc.add(path(f"M{n(x0 + 18)},{n(y + off)}L{n(x1 - 24)},{n(y + off)}",
                         fill="none", stroke=INK, stroke_width="1.2",
                         stroke_opacity="0.16"))

    # ---- conveyor gantry --------------------------------------------
    cx1, cy1 = 372, 486
    cx2, cy2 = 892, 318
    doc.add(truss_band(cx1, cy1, cx2, cy2, 26, 10, GRAPHITE, 0.98, chord=5.5,
                       diag=1.6))
    # belt shadow line
    doc.add(path(f"M{n(cx1 + 6)},{n(cy1 - 3)}L{n(cx2 - 6)},{n(cy2 - 3)}",
                 fill="none", stroke=INK, stroke_width="3.4", stroke_opacity="0.55"))
    # trestles
    for t in (0.16, 0.36, 0.56, 0.76):
        px = cx1 + (cx2 - cx1) * t
        py = cy1 + (cy2 - cy1) * t
        doc.add(poly([(px - 3.4, py + 8), (px + 3.4, py + 8),
                      (px + 5.2, 552), (px - 5.2, 552)], fill=GRAPHITE,
                     fill_opacity=0.95))
        doc.add(path(f"M{n(px - 16)},{n(py + 22)}L{n(px + 18)},{n(py + 44)}"
                     f"M{n(px + 16)},{n(py + 22)}L{n(px - 18)},{n(py + 44)}",
                     fill="none", stroke=GRAPHITE, stroke_width="1.8",
                     stroke_opacity="0.75"))
        doc.add(ell(px, 553, 13, 3, fill=INK, fill_opacity="0.35"))

    # ---- headframe + winding house ----------------------------------
    doc.add(headframe(946, 548, 286, 46, GRAPHITE, 0.97, width=6))
    doc.add(rect(898, 500, 96, 48, fill=CHARCOAL, fill_opacity="0.9"))
    doc.add(poly([(890, 500), (1002, 500), (992, 486), (900, 486)],
                 fill=GUNMETAL, fill_opacity="0.85"))
    doc.add(rect(898, 500, 96, 5, fill=WARM, fill_opacity="0.09"))
    for i in range(4):
        doc.add(rect(906 + i * 22, 512, 9, 12, fill=AMBER, fill_opacity="0.10"))

    # ---- loading bunker on the right --------------------------------
    doc.add(poly([(1148, 470), (1316, 470), (1300, 516), (1164, 516)],
                 fill=GUNMETAL, fill_opacity="0.92"))
    doc.add(poly([(1152, 470), (1312, 470), (1306, 478), (1158, 478)],
                 fill=WARM, fill_opacity="0.07"))
    for sx in (1176, 1200, 1224):
        doc.add(poly([(sx, 516), (sx + 7, 516), (sx + 5, 560), (sx + 1, 560)],
                     fill=CHARCOAL, fill_opacity="0.95"))
    doc.add(poly([(1230, 516), (1290, 516), (1276, 540), (1244, 540)],
                 fill=INK, fill_opacity="0.55"))
    doc.add(rect(1204, 462, 56, 9, fill=GRAPHITE, fill_opacity="0.9"))

    # ---- spoil heaps -------------------------------------------------
    spoil_heap(doc, 238, 546, 420, 74, CHARCOAL, 0.92, rng)
    spoil_heap(doc, 690, 566, 300, 58, CHARCOAL, 0.94, rng)
    spoil_heap(doc, 1390, 560, 380, 66, CHARCOAL, 0.95, rng)

    # scattered boulders / rubble on the mid ground
    for _ in range(26):
        x = rng.uniform(20, W - 20)
        y = rng.uniform(520, 600)
        rr = rng.uniform(3, 11)
        for dx in tile_shifts(x, rr + 2, W):
            doc.add(path(smooth_closed(poly_ellipse(x + dx, y, rr, rr * 0.62,
                                                    steps=9, rot=rng.uniform(-0.4, 0.4))),
                         fill=INK, fill_opacity=n(rng.uniform(0.2, 0.4))))

    # ---- amber work lights -------------------------------------------
    for (lx, ly, lr) in ((944, 268, 34), (860, 330, 22), (600, 398, 18),
                         (1170, 466, 24), (1306, 470, 20), (300, 542, 16)):
        lamp_glow(doc, lx, ly, lr, core=0.65)

    # two lamp masts so the lights belong to something
    for (mx, my, mh) in ((596, 398, 74), (1170, 466, 66), (300, 542, 64)):
        doc.add(rect(mx - 1.6, my, 3.2, mh, fill=CHARCOAL, fill_opacity="0.95"))
        doc.add(poly([(mx - 9, my), (mx + 9, my), (mx + 6, my - 5), (mx - 6, my - 5)],
                     fill=GUNMETAL, fill_opacity="0.95"))

    # ---- atmosphere ---------------------------------------------------
    doc.add(rect(0, 540, W, 180, fill="url(#midLowFog)"))
    doc.add(rect(0, 600, W, 120, fill="url(#midGround)"))
    speck_cloud(doc, rng, 0, 380, W, 720, 90, 0.6, 1.5, ASH, 0.03, 0.07)
    return doc.render()


# --------------------------------------------------------------------------
# 4. near - broken road, truss bridge, ore carts, dead trees
# --------------------------------------------------------------------------

def gen_near() -> str:
    W, H = 1600, 720
    doc = Doc(W, H)
    rng = random.Random(99001)

    doc.define(
        rad_obb("lampGlow", [(0, AMBER, 0.55), (0.30, AMBER, 0.22),
                             (0.62, AMBER, 0.07), (1, AMBER, 0)]),
        lin("nearGround", [(0, CHARCOAL, 0.55), (0.5, CHARCOAL, 0.95), (1, INK, 1)],
            0, 600, 0, 720),
        lin("roadFace", [(0, GUNMETAL, 0.16), (0.5, CHARCOAL, 0.60), (1, INK, 0.9)],
            0, 566, 0, 640),
        lin("bridgeShade", [(0, GUNMETAL, 0.25), (1, INK, 0.75)], 0, 380, 0, 540),
        lin("nearFog", [(0, WARM, 0), (1, WARM, 0.10)], 0, 520, 0, 640),
    )

    # ---- elevated road, broken edge ---------------------------------
    edge = periodic_ridge(W, 556, [(7, 3, 1.1), (4.5, 9, 3.9), (2.4, 21, 0.4)],
                          samples=320, height=16)
    doc.add(path(d_of([(x, y) for x, y in edge]
                      + [(W, 640), (0, 640)]),
                 fill=mix(CHARCOAL, GUNMETAL, 0.35), fill_opacity="0.95"))
    doc.add(path(d_of([(x, y + 10) for x, y in edge]
                      + [(W, 640), (0, 640)]), fill="url(#roadFace)"))
    doc.add(path("M" + "L".join(f"{n(x)},{n(y)}" for x, y in edge),
                 fill="none", stroke=WARM, stroke_width="1.6",
                 stroke_opacity="0.13"))

    # asphalt patches, cracks and rubble along the break
    for _ in range(26):
        x = rng.uniform(20, W - 20)
        y = rng.uniform(578, 628)
        wdt = rng.uniform(18, 70)
        hgt = rng.uniform(2, 7)
        for dx in tile_shifts(x, wdt, W):
            doc.add(ell(x + dx, y, wdt / 2, hgt, fill=INK if rng.random() < 0.6 else ASH,
                        fill_opacity=n(rng.uniform(0.07, 0.16))))
    for _ in range(12):
        x = rng.uniform(30, W - 60)
        y = rng.uniform(566, 600)
        ln = rng.uniform(26, 90)
        d = (f"M{n(x)},{n(y)}l{n(ln * 0.4)},{n(rng.uniform(-6, 6))}"
             f"l{n(ln * 0.35)},{n(rng.uniform(4, 12))}"
             f"l{n(ln * 0.25)},{n(rng.uniform(-3, 8))}")
        for dx in tile_shifts(x + ln / 2, ln, W):
            doc.add(path(d, fill="none", stroke=INK, stroke_width="1.3",
                         stroke_opacity="0.45", transform=f"translate({n(dx)},0)"))
    # faded centre line, worn into dashes
    for i in range(38):
        x = 12 + i * 42
        if rng.random() < 0.32:
            continue
        doc.add(rect(x, 606, rng.uniform(16, 26), 3, fill=AMBER, fill_opacity="0.11"))

    # rubble spilled off the broken edge
    for _ in range(34):
        x = rng.uniform(0, W)
        y = rng.uniform(628, 660)
        rr = rng.uniform(2.2, 7)
        for dx in tile_shifts(x, rr + 2, W):
            doc.add(path(smooth_closed(poly_ellipse(x + dx, y, rr, rr * 0.6,
                                                    steps=8,
                                                    rot=rng.uniform(-0.5, 0.5))),
                         fill=INK, fill_opacity=n(rng.uniform(0.35, 0.6))))

    # ---- steel truss bridge -----------------------------------------
    bx0, bx1, deck, top = 986, 1452, 516, 388
    # abutments - stop at the road embankment so the bridge sits behind it
    for ax in (bx0 - 30, bx1 - 22):
        doc.add(poly([(ax, deck - 6), (ax + 52, deck - 6), (ax + 58, 566), (ax - 6, 566)],
                     fill=CHARCOAL, fill_opacity="0.98"))
        for k in range(3):
            doc.add(rect(ax + 2, deck + 8 + k * 26, 48, 1.6, fill=INK, fill_opacity="0.5"))
    doc.add(truss_band(bx0, top, bx1, top, 12, 6, GUNMETAL, 0.95, chord=7,
                       diag=2.2, xbrace=True))
    # vertical hangers + deck
    hang = []
    for i in range(7):
        px = bx0 + (bx1 - bx0) * i / 6
        hang.append(f"M{n(px)},{n(top + 6)}L{n(px)},{n(deck)}")
    doc.add(path("".join(hang), fill="none", stroke=GUNMETAL, stroke_width="4",
                 stroke_opacity="0.9"))
    doc.add(rect(bx0 - 8, deck - 6, bx1 - bx0 + 16, 16, fill=CHARCOAL,
                 fill_opacity="0.98"))
    doc.add(rect(bx0 - 8, deck - 8, bx1 - bx0 + 16, 4, fill=WARM,
                 fill_opacity="0.10"))
    doc.add(truss_band(bx0, deck + 26, bx1, deck + 26, 32, 6, GRAPHITE, 0.9,
                       chord=4, diag=1.4, xbrace=True))
    # rivet accents along the top chord
    for i in range(25):
        px = bx0 + 8 + i * (bx1 - bx0 - 16) / 24
        doc.add(circ(px, top, 1.3, fill=WARM, fill_opacity="0.18"))

    # ---- rails + ore carts ------------------------------------------
    ry = 664
    doc.add(rect(180, ry + 8, 420, 7, fill=INK, fill_opacity="0.55"))
    for sx in range(190, 600, 34):
        doc.add(rect(sx, ry + 4, 20, 8, fill=mix(CHARCOAL, ASH, 0.18),
                     fill_opacity="0.85"))
    doc.add(rect(180, ry, 420, 4.5, fill=GUNMETAL, fill_opacity="0.95"))
    doc.add(rect(180, ry, 420, 1.4, fill=WARM, fill_opacity="0.16"))

    def ore_cart(cx, base, scale=1.0, lit=True):
        out = []
        w, h = 62 * scale, 34 * scale
        out.append(poly([(cx - w / 2, base - h), (cx + w / 2, base - h),
                         (cx + w / 2 - 6 * scale, base),
                         (cx - w / 2 + 6 * scale, base)],
                        fill=mix(CHARCOAL, GUNMETAL, 0.3), fill_opacity="0.97"))
        out.append(rect(cx - w / 2 + 2, base - h - 4 * scale, w - 4, 5 * scale,
                        fill=GUNMETAL, fill_opacity="0.95"))
        # ore load
        out.append(path(smooth_closed([
            (cx - w / 2 + 4, base - h - 4), (cx - w * 0.22, base - h - 13 * scale),
            (cx - w * 0.02, base - h - 9 * scale), (cx + w * 0.2, base - h - 14 * scale),
            (cx + w / 2 - 5, base - h - 3), (cx + w * 0.1, base - h + 1),
        ]), fill=INK, fill_opacity="0.9"))
        for sd in (-1, 1):
            wx = cx + sd * w * 0.30
            out.append(circ(wx, base + 3 * scale, 9 * scale, fill=INK,
                            fill_opacity="0.98"))
            out.append(circ(wx, base + 3 * scale, 4.6 * scale, fill=GUNMETAL,
                            fill_opacity="0.9"))
            out.append(circ(wx, base + 3 * scale, 1.6 * scale, fill=WARM,
                            fill_opacity="0.18"))
        if lit:
            out.append(circ(cx - w * 0.45, base - h * 0.55, 2.2 * scale,
                            fill=AMBER, fill_opacity="0.5"))
        return "".join(out)

    for cxv, sc in ((318, 1.0), (452, 0.86)):
        for dx in tile_shifts(cxv, 46, W):
            doc.add(ore_cart(cxv + dx, ry - 1, sc))

    # ---- dead trees ---------------------------------------------------
    for (tx, th) in ((704, 128), (762, 96), (1544, 112)):
        for dx in tile_shifts(tx, 60, W):
            doc.add(dead_tree(doc, tx + dx, 648, th, rng))

    # ---- foreground rock masses ---------------------------------------
    def boulder(cx, cy, rx, ry, seed_off):
        rr = random.Random(seed_off)
        pts = []
        for i in range(13):
            a = 2 * math.pi * i / 13
            rr2 = 1 + rr.uniform(-0.22, 0.2)
            pts.append((cx + math.cos(a) * rx * rr2, cy + math.sin(a) * ry * rr2))
        body = smooth_closed(pts)
        s = path(body, fill=CHARCOAL, fill_opacity="1")
        # top-lit crown
        crown = [p for p in pts if p[1] < cy - ry * 0.15]
        if len(crown) > 2:
            s += path(smooth_closed(crown + [(crown[-1][0], crown[-1][1] + ry * 0.4),
                                             (crown[0][0], crown[0][1] + ry * 0.4)]),
                      fill=WARM, fill_opacity="0.09")
        return s

    doc.add(boulder(96, 700, 150, 96, 11))
    doc.add(boulder(1478, 706, 190, 110, 22))
    doc.add(boulder(842, 712, 96, 62, 33))

    # ---- atmosphere / base -------------------------------------------
    doc.add(rect(0, 600, W, 120, fill="url(#nearGround)"))
    doc.add(poly([(x, y + 44) for x, y in edge] + [(W, H), (0, H)],
                 fill=CHARCOAL, fill_opacity="0.55"))
    doc.add(rect(0, 520, W, 120, fill="url(#nearFog)"))
    speck_cloud(doc, rng, 0, 540, W, 720, 70, 0.6, 1.4, ASH, 0.03, 0.07)
    return doc.render()


# --------------------------------------------------------------------------
# 5. ground - seamless ash / gravel tile
# --------------------------------------------------------------------------

def gen_ground() -> str:
    W = H = 512
    doc = Doc(W, H)
    rng = random.Random(424242)
    base = mix(GRAPHITE, INK, 0.42)

    doc.add(rect(0, 0, W, H, fill=base))

    # broad mottling - the ash / dirt base
    for _ in range(30):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        rx, ry = rng.uniform(42, 120), rng.uniform(34, 100)
        col = rng.choice([GRAPHITE, GUNMETAL, INK, ASH, OLIVE])
        op = rng.uniform(0.05, 0.14) if col != INK else rng.uniform(0.10, 0.20)
        for dx, dy in tile_shifts2(cx, cy, rx, ry, W, H):
            doc.add(ell(cx + dx, cy + dy, rx, ry, fill=col, fill_opacity=n(op)))

    # ash drifts: soft light patches
    for _ in range(9):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        rx, ry = rng.uniform(50, 105), rng.uniform(18, 44)
        for dx, dy in tile_shifts2(cx, cy, rx, ry, W, H):
            doc.add(ell(cx + dx, cy + dy, rx, ry, fill=ASH,
                        fill_opacity=n(rng.uniform(0.035, 0.075))))

    # tire scars - shallow periodic curves so they cross the seam correctly
    for (y0, amp, thick, ph, op) in ((168, 16, 30, 0.7, 0.13),
                                     (352, 13, 26, 2.4, 0.11)):
        top, bot = [], []
        for i in range(65):
            x = W * i / 64
            y = y0 + amp * math.sin(2 * math.pi * 2 * x / W + ph)
            top.append((x, y - thick / 2))
            bot.append((x, y + thick / 2))
        doc.add(path(d_of(top + list(reversed(bot))), fill=INK, fill_opacity=n(op)))
        # tread dashes
        for i in range(26):
            x = W * (i + 0.5) / 26
            y = y0 + amp * math.sin(2 * math.pi * 2 * x / W + ph)
            slope = amp * (2 * math.pi * 2 / W) * math.cos(2 * math.pi * 2 * x / W + ph)
            ang = math.degrees(math.atan(slope))
            doc.add(rect(x - 4, y - thick * 0.22, 9, thick * 0.44, fill=INK,
                         fill_opacity="0.16",
                         transform=f"rotate({n(ang)} {n(x)} {n(y)})"))

    # small stones - body, top lit crown, dark seat
    for _ in range(300):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        rr = rng.uniform(1.3, 5.2)
        rx = rr * rng.uniform(0.8, 1.5)
        ry = rr * rng.uniform(0.55, 0.9)
        tone = rng.choice([ASH, WARM, GUNMETAL, SLATE])
        body_op = rng.uniform(0.16, 0.45)
        for dx, dy in tile_shifts2(cx, cy, rx + 2, ry + 2, W, H):
            doc.add(ell(cx + dx, cy + dy + rr * 0.42, rx * 0.95, ry * 0.7,
                        fill=INK, fill_opacity=n(0.30)))
            doc.add(ell(cx + dx, cy + dy, rx, ry, fill=tone,
                        fill_opacity=n(body_op)))
            doc.add(ell(cx + dx - rx * 0.2, cy + dy - ry * 0.38, rx * 0.55, ry * 0.42,
                        fill=WARM, fill_opacity=n(min(0.55, body_op * 1.4))))

    # fine gravel
    speck_cloud(doc, rng, 0, 0, W, H, 420, 0.5, 1.5, ASH, 0.05, 0.16, wrap=(W, H))
    speck_cloud(doc, rng, 0, 0, W, H, 240, 0.4, 1.1, INK, 0.10, 0.24, wrap=(W, H))
    speck_cloud(doc, rng, 0, 0, W, H, 120, 0.4, 1.0, WARM, 0.06, 0.16, wrap=(W, H))

    # hairline cracks
    for _ in range(4):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        pts = [(cx, cy)]
        ang = rng.uniform(0, math.tau)
        for _k in range(5):
            ang += rng.uniform(-0.7, 0.7)
            pts.append((pts[-1][0] + math.cos(ang) * rng.uniform(12, 30),
                        pts[-1][1] + math.sin(ang) * rng.uniform(12, 30)))
        d = "M" + "L".join(f"{n(x)},{n(y)}" for x, y in pts)
        for dx, dy in tile_shifts2(cx, cy, 70, 70, W, H):
            doc.add(path(d, fill="none", stroke=INK, stroke_width="1.1",
                         stroke_opacity="0.35", transform=f"translate({n(dx)},{n(dy)})"))

    return doc.render()


# --------------------------------------------------------------------------
# prop atoms
# --------------------------------------------------------------------------

def rust_blob(cx, cy, rx, ry, rng, op=0.22, color=AMBER, steps=10):
    pts = []
    for i in range(steps):
        a = 2 * math.pi * i / steps
        rr = 1 + rng.uniform(-0.24, 0.24)
        pts.append((cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr))
    return path(smooth_closed(pts), fill=color, fill_opacity=n(op))


def bolt(x, y, r=4.0):
    return (circ(x, y, r * 1.05, fill=INK, fill_opacity="0.55")
            + circ(x, y, r * 0.82, fill=mix(GUNMETAL, ASH, 0.35))
            + circ(x, y, r * 0.42, fill=WARM, fill_opacity="0.22")
            + circ(x - r * 0.2, y - r * 0.25, r * 0.2, fill=WARM,
                   fill_opacity="0.30"))


def grime_streak(x, y, length, width, op=0.18, color=AMBER):
    d = f"M{n(x)},{n(y)}l{n(width * 0.3)},{n(length)}"
    return path(d, fill="none", stroke=color, stroke_width=n(width),
                stroke_opacity=n(op), stroke_linecap="round")


# --------------------------------------------------------------------------
# 6. industrial barrier
# --------------------------------------------------------------------------

def gen_barrier() -> str:
    W, H = 360, 220
    doc = Doc(W, H)
    rng = random.Random(8081)

    doc.define(
        lin("boardFace", [(0, GUNMETAL, 1), (0.55, mix(GUNMETAL, GRAPHITE, 0.45), 1),
                           (1, CHARCOAL, 1)], 0, 58, 0, 138),
        lin("legSteel", [(0, GUNMETAL, 1), (1, CHARCOAL, 1)], 0, 0, 1, 0,
            units="objectBoundingBox"),
        lin("boltShadow", [(0, INK, 0.5), (1, INK, 0)], 0, 0, 0, 1,
            units="objectBoundingBox"),
    )

    soft_shadow(doc, 180, 204, 130, 13, layers=6, alpha=0.14)

    # ---- folding feet -------------------------------------------------
    for (fx, tilt) in ((52, -1), (308, 1)):
        doc.add(poly([(fx - 40, 196), (fx + 40, 194),
                      (fx + 46, 206), (fx - 46, 208)],
                     fill=CHARCOAL, fill_opacity="0.98"))
        doc.add(poly([(fx - 40, 196), (fx + 40, 194),
                      (fx + 42, 198), (fx - 42, 200)],
                     fill=GUNMETAL, fill_opacity="0.9"))
        doc.add(rect(fx - 30, 199, 60, 1.6, fill=WARM, fill_opacity="0.12"))
        doc.add(bolt(fx - 30, 201, 3.4) + bolt(fx + 30, 200, 3.4))

    # ---- A-frame legs -------------------------------------------------
    for sgn in (-1, 1):
        top_x = 180 + sgn * 96
        bot_x = 180 + sgn * 128
        doc.add(poly([(top_x - 9, 120), (top_x + 9, 120),
                      (bot_x + 13, 199), (bot_x - 13, 199)],
                     fill="url(#legSteel)"))
        # lit left edge of each leg
        doc.add(path(f"M{n(top_x - 7)},{n(124)}L{n(bot_x - 10)},{n(196)}",
                     fill="none", stroke=WARM, stroke_width="2",
                     stroke_opacity="0.13"))
        doc.add(bolt(top_x, 128, 3.6))

    # cross brace between legs
    doc.add(rect(70, 168, 220, 5.5, fill=CHARCOAL, fill_opacity="0.95"))
    doc.add(rect(70, 168, 220, 1.6, fill=WARM, fill_opacity="0.10"))

    # ---- main striped board -------------------------------------------
    bx0, by0, bx1, by1 = 40, 62, 320, 134
    doc.add(rect(bx0, by0, bx1 - bx0, by1 - by0, fill="url(#boardFace)"))

    # hazard stripes, geometrically clipped to the panel
    k = 0.46
    span = by1 - by0 + 40
    s = bx0 - 60
    idx = 0
    while s < bx1 + 40:
        quad = [(s, by0 - 20), (s + 30, by0 - 20),
                (s + 30 + k * span, by1 + 20), (s + k * span, by1 + 20)]
        clipped = clip_poly_rect(quad, bx0, by0, bx1, by1)
        if len(clipped) >= 3:
            doc.add(poly(clipped, fill=AMBER, fill_opacity="0.42"))
            # worn edge to the stripe
            doc.add(poly(clipped, fill=WARM, fill_opacity=n(0.05 if idx % 2 else 0.03)))
        s += 60
        idx += 1

    # panel shading: top lit lip, bottom occluded lip
    doc.add(rect(bx0, by0, bx1 - bx0, 3.5, fill=WARM, fill_opacity="0.16"))
    doc.add(rect(bx0, by1 - 7, bx1 - bx0, 7, fill=INK, fill_opacity="0.42"))
    doc.add(rect(bx0, by0, 4, by1 - by0, fill=INK, fill_opacity="0.30"))
    doc.add(rect(bx1 - 4, by0, 4, by1 - by0, fill=INK, fill_opacity="0.22"))

    # steel frame edges + bolts
    doc.add(rect(bx0, by0, bx1 - bx0, 2.2, fill=GUNMETAL))
    doc.add(rect(bx0, by1 - 2.2, bx1 - bx0, 2.2, fill=GUNMETAL))
    for bx in (bx0 + 12, bx1 - 12):
        for by in (by0 + 10, by1 - 10):
            doc.add(bolt(bx, by, 4.2))

    # dents - a light buckle with a dark fold, stacked translucents
    for (dx, dy, dw, dh) in ((104, 74, 46, 20), (232, 108, 34, 15)):
        doc.add(ell(dx, dy, dw / 2, dh / 2, fill=INK, fill_opacity="0.20"))
        doc.add(ell(dx - 3, dy - 4, dw / 2.6, dh / 3, fill=WARM,
                    fill_opacity="0.10"))
        doc.add(path(f"M{n(dx - dw / 2.6)},{n(dy + dh * 0.15)}q{n(dw / 3)},{n(-dh * 0.5)} "
                     f"{n(dw / 1.9)},{n(dh * 0.1)}", fill="none", stroke=INK,
                     stroke_width="1.4", stroke_opacity="0.35"))

    # rust: patches, drips, pitted spots
    for (rx, ry, rw, rh) in ((66, 122, 26, 12), (296, 118, 22, 14),
                             (150, 66, 30, 10), (268, 72, 18, 9)):
        doc.add(rust_blob(rx, ry, rw, rh, rng, op=rng.uniform(0.16, 0.30)))
    for _ in range(11):
        x = rng.uniform(bx0 + 6, bx1 - 6)
        y = rng.uniform(by0 + 12, by1 - 4)
        doc.add(grime_streak(x, y, rng.uniform(8, 26), rng.uniform(1.4, 3.4),
                             op=rng.uniform(0.07, 0.16)))
    for _ in range(24):
        doc.add(circ(rng.uniform(bx0 + 4, bx1 - 4), rng.uniform(by0 + 4, by1 - 4),
                     rng.uniform(0.5, 1.5), fill=INK,
                     fill_opacity=n(rng.uniform(0.10, 0.25))))

    # scratches
    for _ in range(7):
        x = rng.uniform(bx0 + 10, bx1 - 30)
        y = rng.uniform(by0 + 8, by1 - 8)
        doc.add(path(f"M{n(x)},{n(y)}l{n(rng.uniform(8, 26))},{n(rng.uniform(-2, 2))}",
                     fill="none", stroke=WARM, stroke_width="0.9",
                     stroke_opacity=n(rng.uniform(0.08, 0.2))))

    # folded top edge catching light
    doc.add(poly([(bx0 + 2, by0), (bx1 - 2, by0), (bx1 - 6, by0 - 7), (bx0 + 6, by0 - 7)],
                 fill=GUNMETAL, fill_opacity="0.95"))
    doc.add(poly([(bx0 + 6, by0 - 7), (bx1 - 6, by0 - 7), (bx1 - 8, by0 - 10),
                  (bx0 + 8, by0 - 10)], fill=WARM, fill_opacity="0.13"))

    return doc.render()


# --------------------------------------------------------------------------
# 7. ore cart
# --------------------------------------------------------------------------

def gen_cart() -> str:
    W, H = 300, 260
    doc = Doc(W, H)
    rng = random.Random(191919)

    doc.define(
        lin("bodySteel", [(0, mix(GUNMETAL, ASH, 0.30), 1),
                           (0.45, mix(CHARCOAL, GUNMETAL, 0.55), 1),
                           (1, CHARCOAL, 1)], 0, 96, 0, 200),
        rad_obb("cartGlow", [(0, AMBER, 0.45), (0.5, AMBER, 0.14), (1, AMBER, 0)]),
        lin("railSheen", [(0, WARM, 0.30), (0.5, WARM, 0.08), (1, WARM, 0)],
            0, 0, 0, 1, units="objectBoundingBox"),
    )

    soft_shadow(doc, 150, 248, 104, 12, layers=6, alpha=0.16)

    # ---- track ---------------------------------------------------------
    doc.add(rect(14, 218, 272, 4, fill=mix(CHARCOAL, ASH, 0.22), fill_opacity="0.75"))
    doc.add(rect(14, 218, 272, 1.2, fill=WARM, fill_opacity="0.12"))
    for sx in range(18, 288, 30):
        doc.add(rect(sx, 222, 22, 10, fill=CHARCOAL, fill_opacity="0.9"))
        doc.add(rect(sx, 222, 22, 2, fill=ASH, fill_opacity="0.10"))
    doc.add(rect(10, 234, 280, 6.5, fill=GUNMETAL, fill_opacity="0.95"))
    doc.add(rect(10, 234, 280, 1.8, fill=WARM, fill_opacity="0.22"))
    doc.add(rect(10, 238, 280, 2.5, fill=INK, fill_opacity="0.6"))

    # ---- wheels --------------------------------------------------------
    for wx in (108, 194):
        doc.add(circ(wx, 214, 23, fill=INK, fill_opacity="0.95"))
        doc.add(circ(wx, 214, 19.5, fill=mix(CHARCOAL, GUNMETAL, 0.5),
                     fill_opacity="0.98"))
        doc.add(circ(wx, 214, 19.5, fill="none", stroke=WARM, stroke_width="2.2",
                     stroke_opacity="0.16"))
        for k in range(6):
            a = math.pi * k / 3 + 0.35
            doc.add(path(f"M{n(wx + math.cos(a) * 4)},{n(214 + math.sin(a) * 4)}"
                         f"L{n(wx + math.cos(a) * 17)},{n(214 + math.sin(a) * 17)}",
                         fill="none", stroke=INK, stroke_width="2.4",
                         stroke_opacity="0.75"))
        doc.add(circ(wx, 214, 5.6, fill=GUNMETAL))
        doc.add(circ(wx, 214, 2.2, fill=INK, fill_opacity="0.8"))

    # ---- body ----------------------------------------------------------
    body = [(62, 100), (238, 100), (214, 198), (86, 198)]
    doc.add(poly(body, fill="url(#bodySteel)"))
    # tapering side shading
    doc.add(poly([(62, 100), (86, 198), (96, 198), (76, 100)], fill=INK,
                 fill_opacity="0.32"))
    doc.add(poly([(238, 100), (214, 198), (204, 198), (226, 100)], fill=INK,
                 fill_opacity="0.18"))
    # top rim
    doc.add(poly([(54, 96), (246, 96), (240, 108), (60, 108)], fill=GUNMETAL))
    doc.add(poly([(54, 96), (246, 96), (245, 99), (55, 99)], fill=WARM,
                 fill_opacity="0.20"))
    doc.add(rect(60, 106, 180, 4, fill=INK, fill_opacity="0.45"))
    for i in range(8):
        doc.add(bolt(66 + i * 24, 101, 3.4))

    # panel ribs
    for yy in (128, 152, 176):
        doc.add(rect(74, yy, 152, 3.2, fill=INK, fill_opacity="0.30"))
        doc.add(rect(74, yy - 1.6, 152, 1.6, fill=WARM, fill_opacity="0.07"))
    doc.add(path("M80,112L214,192", fill="none", stroke=INK, stroke_width="2",
                 stroke_opacity="0.30"))
    doc.add(path("M220,112L86,192", fill="none", stroke=INK, stroke_width="2",
                 stroke_opacity="0.22"))

    # faded painted panel marking
    doc.add(rect(104, 132, 92, 22, fill=AMBER, fill_opacity="0.14"))
    doc.add(rect(104, 132, 92, 22, fill="none", stroke=AMBER, stroke_width="1.4",
                 stroke_opacity="0.22"))

    # dents and rust
    doc.add(ell(196, 182, 26, 13, fill=INK, fill_opacity="0.30"))
    doc.add(ell(192, 176, 22, 9, fill=WARM, fill_opacity="0.07"))
    for (rx, ry, rw, rh) in ((92, 190, 22, 10), (222, 168, 16, 12),
                             (150, 110, 26, 8), (200, 120, 14, 9)):
        doc.add(rust_blob(rx, ry, rw, rh, rng, op=rng.uniform(0.16, 0.32)))
    for _ in range(14):
        x = rng.uniform(80, 220)
        doc.add(grime_streak(x, rng.uniform(108, 150), rng.uniform(14, 48),
                             rng.uniform(1.2, 3.2), op=rng.uniform(0.06, 0.15)))
    for _ in range(10):
        doc.add(path(f"M{n(rng.uniform(70, 230))},{n(rng.uniform(112, 194))}"
                     f"l{n(rng.uniform(6, 20))},{n(rng.uniform(-3, 3))}",
                     fill="none", stroke=WARM, stroke_width="0.9",
                     stroke_opacity=n(rng.uniform(0.08, 0.18))))

    # ---- ore load -------------------------------------------------------
    load = [(68, 100), (78, 82), (96, 88), (112, 70), (134, 82), (154, 66),
            (176, 80), (198, 72), (216, 86), (232, 84), (242, 100)]
    doc.add(path(smooth_closed(load + [(240, 104), (70, 104)]), fill=INK,
                 fill_opacity="0.95"))
    for (lx, ly, lr) in ((104, 86, 9), (150, 76, 10), (196, 84, 8), (126, 96, 7)):
        doc.add(path(smooth_closed(poly_ellipse(lx, ly, lr, lr * 0.7, steps=8,
                                                rot=rng.uniform(-0.4, 0.4))),
                     fill=mix(CHARCOAL, SLATE, 0.6), fill_opacity="0.95"))
        doc.add(ell(lx - lr * 0.3, ly - lr * 0.35, lr * 0.4, lr * 0.22,
                    fill=WARM, fill_opacity="0.09"))

    # ---- handle ---------------------------------------------------------
    doc.add(rect(40, 116, 22, 5, fill=GUNMETAL))
    doc.add(path("M40,118l-14,10l0,5l16,-9", fill="none", stroke=GUNMETAL,
                 stroke_width="4", stroke_linecap="round"))
    doc.add(circ(28, 133, 3.4, fill=CHARCOAL))

    # warm glint - a lamp catching the rim
    doc.add(circ(226, 106, 20, fill="url(#cartGlow)"))
    doc.add(circ(226, 106, 2.2, fill=AMBER, fill_opacity="0.6"))
    return doc.render()


# --------------------------------------------------------------------------
# 8. pipe stack
# --------------------------------------------------------------------------

def gen_pipes() -> str:
    W, H = 320, 220
    doc = Doc(W, H)
    rng = random.Random(6161)

    doc.define(
        lin("pipeShell", [(0, WARM, 0.20), (0.22, GUNMETAL, 1),
                           (0.62, mix(GUNMETAL, GRAPHITE, 0.7), 1), (1, INK, 1)],
            0, 0, 0, 1, units="objectBoundingBox"),
        lin("pipeSteel", [(0, WARM, 0.26), (0.2, mix(GUNMETAL, SLATE, 0.35), 1),
                          (0.7, GRAPHITE, 1), (1, INK, 1)],
            0, 0, 0, 1, units="objectBoundingBox"),
        rad_obb("boreDark", [(0, INK, 0.95), (0.7, INK, 0.7), (1, INK, 0.25)]),
    )

    soft_shadow(doc, 162, 208, 112, 12, layers=6, alpha=0.17)

    RX, RY, DX, DY = 40, 34, 19, -13

    def pipe(cx, cy, steel=False):
        out = []
        shell = "pipeSteel" if steel else "pipeShell"
        # barrel between the two caps
        out.append(poly([(cx - RX, cy), (cx + DX - RX, cy + DY),
                         (cx + DX + RX, cy + DY), (cx + RX, cy)], fill=f"url(#{shell})"))
        # far end
        out.append(ell(cx + DX, cy + DY, RX, RY,
                       fill=mix(GRAPHITE, INK, 0.45 if not steel else 0.25)))
        # near end cap
        out.append(ell(cx, cy, RX, RY, fill=mix(GUNMETAL, GRAPHITE, 0.4)))
        out.append(ell(cx, cy, RX, RY, fill="none", stroke=WARM, stroke_width="2.6",
                       stroke_opacity="0.18"))
        out.append(ell(cx - RX * 0.18, cy - RY * 0.30, RX * 0.78, RY * 0.62,
                       fill=WARM, fill_opacity="0.07"))
        # bore
        out.append(ell(cx, cy + RY * 0.06, RX * 0.66, RY * 0.66, fill="url(#boreDark)"))
        out.append(path(f"M{n(cx - RX * 0.62)},{n(cy + RY * 0.1)}"
                        f"A{n(RX * 0.62)},{n(RY * 0.6)} 0 0 1 {n(cx + RX * 0.6)},{n(cy + RY * 0.14)}",
                        fill="none", stroke=INK, stroke_width="3",
                        stroke_opacity="0.55"))
        # aggregate / chipped concrete or steel banding
        if steel:
            for bx in (cx - RX * 0.55, cx + RX * 0.18):
                out.append(ell(bx, cy, RX * 0.14, RY * 0.86, fill=INK,
                               fill_opacity="0.18"))
        else:
            for _ in range(7):
                aa = rng.uniform(0, math.tau)
                rr = rng.uniform(0.45, 0.92)
                out.append(circ(cx + math.cos(aa) * RX * rr,
                                cy + math.sin(aa) * RY * rr,
                                rng.uniform(0.6, 1.8), fill=INK,
                                fill_opacity=n(rng.uniform(0.10, 0.24))))
        out.append(grime_streak(cx - RX * 0.4, cy + RY * 0.35, 12, 3, 0.10))
        return "".join(out)

    # top row first, then middle, then bottom (front)
    for (cx, cy, steel) in ((162, 62, False),):
        doc.add(pipe(cx, cy, steel))
    for (cx, cy, steel) in ((120, 120, True), (204, 120, True)):
        doc.add(pipe(cx, cy, steel))
    for (cx, cy, steel) in ((78, 176, False), (162, 176, False), (246, 176, False)):
        doc.add(pipe(cx, cy, steel))

    # contact occlusion where the rows meet
    for (cx, cy) in ((120, 152), (204, 152), (78, 208), (162, 208), (246, 208)):
        doc.add(ell(cx, cy, 34, 6, fill=INK, fill_opacity="0.22"))

    # loose rubble at the foot
    for _ in range(14):
        x = rng.uniform(30, 290)
        y = rng.uniform(204, 214)
        rr = rng.uniform(1.8, 5)
        doc.add(ell(x, y, rr, rr * 0.6, fill=INK, fill_opacity=n(rng.uniform(0.3, 0.55))))
    return doc.render()


# --------------------------------------------------------------------------
# 9. ash rock
# --------------------------------------------------------------------------

def gen_rock() -> str:
    W, H = 340, 240
    doc = Doc(W, H)
    rng = random.Random(30303)

    doc.define(
        lin("rockBody", [(0, mix(GRAPHITE, GUNMETAL, 0.55), 1),
                          (0.42, mix(CHARCOAL, GRAPHITE, 0.7), 1),
                          (1, INK, 1)], 0, 60, 0, 236),
    )

    soft_shadow(doc, 176, 226, 112, 13, layers=7, alpha=0.20)

    # silhouette - wider than tall, flat seated base
    base_pts = [(30, 210), (44, 168), (72, 138), (108, 112), (140, 86),
                (176, 74), (214, 78), (246, 96), (272, 128), (292, 164),
                (302, 196), (298, 216), (250, 220), (176, 222), (96, 220),
                (44, 218)]
    pts = [(x + rng.uniform(-4, 4), y + rng.uniform(-3, 3)) for x, y in base_pts]
    shape = smooth_closed(pts, tension=1.05)
    doc.add(path(shape, fill="url(#rockBody)"))

    # ---- strata: horizontal bands clipped by sampling the silhouette ----
    def span_at(y):
        xs = []
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            if (a[1] <= y <= b[1]) or (b[1] <= y <= a[1]):
                if abs(b[1] - a[1]) < 1e-6:
                    continue
                t = (y - a[1]) / (b[1] - a[1])
                xs.append(a[0] + (b[0] - a[0]) * t)
        if len(xs) < 2:
            return None
        return min(xs), max(xs)

    for yy, thick, tone, op in ((108, 7, WARM, 0.07), (126, 9, INK, 0.20),
                                (144, 6, WARM, 0.06), (162, 11, INK, 0.22),
                                (182, 7, WARM, 0.055), (198, 9, INK, 0.24)):
        sp = span_at(yy)
        if not sp:
            continue
        x0, x1 = sp[0] + 10, sp[1] - 10
        if x1 - x0 < 20:
            continue
        d = (f"M{n(x0)},{n(yy)}Q{n((x0 + x1) / 2)},{n(yy - 4)} {n(x1)},{n(yy - 1)}"
             f"L{n(x1)},{n(yy + thick)}Q{n((x0 + x1) / 2)},{n(yy + thick + 4)} "
             f"{n(x0)},{n(yy + thick)}Z")
        doc.add(path(d, fill=tone, fill_opacity=n(op)))

    # ---- facet planes --------------------------------------------------
    doc.add(poly([(140, 88), (176, 76), (214, 80), (196, 132), (150, 140)],
                 fill=WARM, fill_opacity="0.075"))
    doc.add(poly([(176, 76), (214, 80), (246, 98), (236, 150), (196, 132)],
                 fill=INK, fill_opacity="0.20"))
    doc.add(poly([(72, 140), (140, 88), (150, 140), (128, 196), (86, 186)],
                 fill=WARM, fill_opacity="0.045"))
    doc.add(poly([(246, 98), (292, 166), (298, 198), (236, 200), (236, 150)],
                 fill=INK, fill_opacity="0.26"))

    # ---- rim light on the upper-left arc -------------------------------
    rim_pts = [(44, 168), (72, 138), (108, 112), (140, 86), (176, 74), (214, 78)]
    d = "M" + "L".join(f"{n(x)},{n(y)}" for x, y in rim_pts)
    doc.add(path(d, fill="none", stroke=WARM, stroke_width="3.4",
                 stroke_opacity="0.16", stroke_linecap="round"))
    doc.add(path(d, fill="none", stroke=WARM, stroke_width="1.3",
                 stroke_opacity="0.22", stroke_linecap="round"))

    # ---- ash dusting on top --------------------------------------------
    for (ax, ay, arx, ary, op) in ((118, 108, 40, 12, 0.16), (168, 88, 34, 10, 0.13),
                                   (206, 92, 26, 8, 0.11), (86, 140, 22, 8, 0.09)):
        doc.add(ell(ax, ay, arx, ary, fill=WARM, fill_opacity=n(op)))
    speck_cloud(doc, rng, 40, 72, 300, 210, 70, 0.5, 1.6, WARM, 0.04, 0.14)
    speck_cloud(doc, rng, 40, 90, 300, 220, 50, 0.5, 1.4, INK, 0.10, 0.22)

    # ---- cracks ---------------------------------------------------------
    for (sx, sy, pts2) in ((152, 84, [(152, 84), (160, 112), (150, 138), (158, 166)]),
                           (216, 92, [(216, 92), (222, 118), (214, 146)]),
                           (96, 150, [(96, 150), (110, 166), (104, 190)])):
        d = "M" + "L".join(f"{n(x)},{n(y)}" for x, y in pts2)
        doc.add(path(d, fill="none", stroke=INK, stroke_width="1.8",
                     stroke_opacity="0.55", stroke_linecap="round"))
        doc.add(path(d, fill="none", stroke=WARM, stroke_width="0.8",
                     stroke_opacity="0.10"))

    # ---- base contact ---------------------------------------------------
    doc.add(path("M44,216Q176,226 298,214L298,224Q176,236 44,224Z",
                 fill=INK, fill_opacity="0.55"))
    for _ in range(12):
        x = rng.uniform(40, 300)
        doc.add(ell(x, rng.uniform(218, 228), rng.uniform(2, 7),
                    rng.uniform(1, 2.6), fill=INK,
                    fill_opacity=n(rng.uniform(0.3, 0.55))))
    return doc.render()


# --------------------------------------------------------------------------
# 10. floodlight mast
# --------------------------------------------------------------------------

def gen_floodlight() -> str:
    W, H = 200, 320
    doc = Doc(W, H)
    rng = random.Random(777001)

    doc.define(
        rad_obb("mastGlow", [(0, AMBER, 0.55), (0.22, AMBER, 0.30),
                              (0.55, AMBER, 0.10), (1, AMBER, 0)]),
        lin("coneGrad", [(0, AMBER, 0.16), (0.55, AMBER, 0.06), (1, AMBER, 0)],
            0, 0, 0, 1, units="objectBoundingBox"),
        lin("poleSteel", [(0, mix(GUNMETAL, ASH, 0.22), 1),
                          (0.35, GUNMETAL, 1), (1, CHARCOAL, 1)], 84, 0, 120, 0),
    )

    soft_shadow(doc, 100, 306, 68, 11, layers=6, alpha=0.20)

    # ---- base plinth ----------------------------------------------------
    doc.add(poly([(64, 290), (136, 290), (142, 304), (58, 304)], fill=CHARCOAL,
                 fill_opacity="0.98"))
    doc.add(poly([(64, 290), (136, 290), (133, 286), (67, 286)],
                 fill=mix(CHARCOAL, ASH, 0.22)))
    doc.add(rect(58, 300, 84, 3, fill=INK, fill_opacity="0.5"))
    for bx in (70, 130):
        doc.add(bolt(bx, 296, 3.6))

    # ---- pole -----------------------------------------------------------
    doc.add(poly([(88, 292), (112, 292), (106, 88), (94, 88)], fill="url(#poleSteel)"))
    doc.add(path("M91,290L96,90", fill="none", stroke=WARM, stroke_width="1.6",
                 stroke_opacity="0.14"))
    doc.add(path("M109,290L104,90", fill="none", stroke=INK, stroke_width="2.6",
                 stroke_opacity="0.45"))
    # flange + gussets
    doc.add(rect(82, 282, 36, 9, fill=GUNMETAL))
    doc.add(rect(82, 282, 36, 2, fill=WARM, fill_opacity="0.16"))
    for sgn in (-1, 1):
        doc.add(poly([(100 + sgn * 10, 282), (100 + sgn * 10, 262),
                      (100 + sgn * 18, 282)], fill=GUNMETAL, fill_opacity="0.9"))

    # ladder rungs on the right of the pole
    for ry in range(120, 276, 18):
        doc.add(rect(108, ry, 13, 2.4, fill=CHARCOAL, fill_opacity="0.9"))
        doc.add(rect(108, ry, 13, 0.8, fill=WARM, fill_opacity="0.10"))
    doc.add(rect(119, 112, 3, 170, fill=CHARCOAL, fill_opacity="0.9"))
    doc.add(rect(118, 112, 1.2, 170, fill=WARM, fill_opacity="0.10"))

    # ---- cross arm + lamp heads ----------------------------------------
    doc.add(rect(56, 84, 88, 7, fill=GUNMETAL))
    doc.add(rect(56, 84, 88, 1.8, fill=WARM, fill_opacity="0.16"))
    doc.add(path("M100,92L70,84M100,92L130,84", fill="none", stroke=CHARCOAL,
                 stroke_width="3.4"))
    doc.add(circ(100, 87, 4.6, fill=CHARCOAL))

    lamps = ((64, 96), (136, 96))
    for (lx, ly) in lamps:
        doc.add(rect(lx - 2.5, ly - 6, 5, 10, fill=CHARCOAL))
        doc.add(poly([(lx - 15, ly + 4), (lx + 15, ly + 4),
                      (lx + 11, ly + 28), (lx - 11, ly + 28)], fill=GUNMETAL))
        doc.add(poly([(lx - 17, ly + 4), (lx + 17, ly + 4),
                      (lx + 13, ly - 5), (lx - 13, ly - 5)], fill=CHARCOAL))
        doc.add(poly([(lx - 17, ly + 4), (lx + 17, ly + 4), (lx + 16, ly + 6),
                      (lx - 16, ly + 6)], fill=WARM, fill_opacity="0.14"))
        doc.add(ell(lx, ly + 27, 10, 3.4, fill=AMBER, fill_opacity="0.85"))
        doc.add(ell(lx, ly + 27, 5.4, 2, fill=WARM, fill_opacity="0.9"))

    # ---- glow + light cones --------------------------------------------
    for (lx, ly) in lamps:
        doc.add(circ(lx, ly + 28, 46, fill="url(#mastGlow)"))
        cone = [(lx - 11, ly + 28), (lx + 11, ly + 28),
                (lx + 52, 300), (lx - 52, 300)]
        doc.add(poly(cone, fill="url(#coneGrad)"))
    doc.add(ell(100, 300, 74, 14, fill=AMBER, fill_opacity="0.05"))

    # ---- cables ---------------------------------------------------------
    doc.add(path("M96,88Q104,140 110,190Q114,230 108,282", fill="none",
                 stroke=INK, stroke_width="1.8", stroke_opacity="0.65"))
    doc.add(path("M104,88Q114,150 118,210Q120,250 116,284", fill="none",
                 stroke=INK, stroke_width="1.2", stroke_opacity="0.45"))

    # ---- weathering ------------------------------------------------------
    for _ in range(12):
        y = rng.uniform(100, 280)
        doc.add(grime_streak(rng.uniform(90, 108), y, rng.uniform(10, 40),
                             rng.uniform(1, 2.6), op=rng.uniform(0.06, 0.16)))
    doc.add(rect(86, 258, 28, 8, fill=AMBER, fill_opacity="0.20"))
    doc.add(rect(86, 258, 28, 2, fill=INK, fill_opacity="0.25"))
    for _ in range(6):
        doc.add(path(f"M{n(rng.uniform(86, 114))},{n(rng.uniform(270, 292))}"
                     f"l{n(rng.uniform(3, 9))},0", fill="none", stroke=WARM,
                     stroke_width="0.9", stroke_opacity=n(rng.uniform(0.08, 0.18))))
    return doc.render()


# --------------------------------------------------------------------------
# 11. steel truss bridge (drivable platform)
# --------------------------------------------------------------------------

def gen_bridge() -> str:
    W, H = 900, 260
    doc = Doc(W, H)
    rng = random.Random(550055)

    doc.define(
        lin("deckPlate", [(0, mix(GUNMETAL, ASH, 0.18), 1), (0.45, GUNMETAL, 1),
                           (1, CHARCOAL, 1)], 0, 248, 0, 260),
        lin("trussShade", [(0, WARM, 0.06), (0.5, GRAPHITE, 0.0), (1, INK, 0.55)],
            0, 54, 0, 248),
        rad_obb("boltSheen", [(0, WARM, 0.55), (1, WARM, 0)]),
    )

    DECK_TOP = 248.0
    DECK_BOT = 260.0
    TOP_CHORD = 54.0
    PANELS = 8
    panel_w = W / PANELS

    # ---- deck plate -----------------------------------------------------
    doc.add(rect(0, DECK_TOP, W, DECK_BOT - DECK_TOP, fill="url(#deckPlate)"))
    doc.add(rect(0, DECK_TOP, W, 2.6, fill=WARM, fill_opacity="0.20"))
    doc.add(rect(0, DECK_TOP + 1.2, W, 1.1, fill=WARM, fill_opacity="0.09"))
    doc.add(rect(0, DECK_BOT - 4, W, 4, fill=INK, fill_opacity="0.55"))
    # deck rivet rows
    for i in range(61):
        x = 6 + i * 14.8
        doc.add(circ(x, DECK_TOP + 6.2, 1.35, fill=WARM, fill_opacity="0.14"))
        doc.add(circ(x, DECK_BOT - 6.4, 1.2, fill=INK, fill_opacity="0.35"))

    # ---- vertical posts --------------------------------------------------
    posts = [i * panel_w for i in range(PANELS + 1)]
    for i, px in enumerate(posts):
        x = min(max(px, 3.5), W - 3.5)
        doc.add(rect(x - 4.5, TOP_CHORD, 9, DECK_TOP - TOP_CHORD, fill=GUNMETAL))
        doc.add(rect(x - 4.5, TOP_CHORD, 2.2, DECK_TOP - TOP_CHORD, fill=WARM,
                     fill_opacity="0.10"))
        doc.add(rect(x + 2.6, TOP_CHORD, 1.9, DECK_TOP - TOP_CHORD, fill=INK,
                     fill_opacity="0.45"))
        # gusset plates
        doc.add(poly([(x - 12, DECK_TOP - 4), (x + 12, DECK_TOP - 4),
                      (x + 9, DECK_TOP - 20), (x - 9, DECK_TOP - 20)],
                     fill=GRAPHITE, fill_opacity="0.98"))
        doc.add(poly([(x - 11, TOP_CHORD + 16), (x + 11, TOP_CHORD + 16),
                      (x + 8, TOP_CHORD + 3), (x - 8, TOP_CHORD + 3)],
                     fill=GRAPHITE, fill_opacity="0.98"))
        for by in (DECK_TOP - 11, TOP_CHORD + 9):
            doc.add(bolt(x - 5.6, by, 2.6))
            doc.add(bolt(x + 5.6, by, 2.6))

    # ---- diagonal web members (X bracing) --------------------------------
    web = []
    web_hi = []
    for i in range(PANELS):
        xa = i * panel_w
        xb = xa + panel_w
        for (p, q) in (((xa, DECK_TOP - 8), (xb, TOP_CHORD + 12)),
                       ((xb, DECK_TOP - 8), (xa, TOP_CHORD + 12))):
            web.append(f"M{n(p[0])},{n(p[1])}L{n(q[0])},{n(q[1])}")
            web_hi.append(f"M{n(p[0] + 1.4)},{n(p[1])}L{n(q[0] + 1.4)},{n(q[1])}")
    doc.add(path("".join(web), fill="none", stroke=GUNMETAL, stroke_width="6.2",
                 stroke_linecap="round"))
    doc.add(path("".join(web_hi), fill="none", stroke=WARM, stroke_width="1.5",
                 stroke_opacity="0.10", stroke_linecap="round"))
    doc.add(path("".join(web), fill="none", stroke=INK, stroke_width="1.1",
                 stroke_opacity="0.25", stroke_linecap="round"))

    # ---- top chord -------------------------------------------------------
    doc.add(rect(0, TOP_CHORD - 9, W, 15, fill=GUNMETAL))
    doc.add(rect(0, TOP_CHORD - 9, W, 3, fill=WARM, fill_opacity="0.17"))
    doc.add(rect(0, TOP_CHORD + 3, W, 3, fill=INK, fill_opacity="0.45"))
    # lattice detail on the chord
    lat = []
    for i in range(90):
        x = i * 10
        lat.append(f"M{n(x)},{n(TOP_CHORD - 7)}L{n(x + 10)},{n(TOP_CHORD + 4)}")
    doc.add(path("".join(lat), fill="none", stroke=INK, stroke_width="1.4",
                 stroke_opacity="0.22"))
    for i in range(41):
        doc.add(circ(6 + i * 22, TOP_CHORD - 2, 1.5, fill=WARM, fill_opacity="0.18"))

    # ---- guard rail along the deck --------------------------------------
    RAIL_TOP = 196.0
    doc.add(rect(0, RAIL_TOP, W, 4.2, fill=GUNMETAL))
    doc.add(rect(0, RAIL_TOP, W, 1.4, fill=WARM, fill_opacity="0.18"))
    doc.add(rect(0, RAIL_TOP + 20, W, 3.4, fill=mix(GUNMETAL, CHARCOAL, 0.5)))
    doc.add(rect(0, RAIL_TOP + 20, W, 1.1, fill=WARM, fill_opacity="0.10"))
    for i in range(PANELS + 1):
        x = min(max(i * panel_w, 3.5), W - 3.5)
        doc.add(rect(x - 3, RAIL_TOP - 6, 6, DECK_TOP - RAIL_TOP + 6, fill=GUNMETAL))
        doc.add(rect(x - 3, RAIL_TOP - 6, 1.4, DECK_TOP - RAIL_TOP + 6, fill=WARM,
                     fill_opacity="0.12"))
        doc.add(bolt(x, RAIL_TOP + 26, 2.4))
    # vertical infill between the rails, every panel
    infill = []
    for i in range(PANELS * 4):
        x = i * panel_w / 4
        if abs((x % panel_w)) < 6:
            continue
        infill.append(f"M{n(x)},{n(RAIL_TOP + 4)}L{n(x)},{n(RAIL_TOP + 20)}")
    doc.add(path("".join(infill), fill="none", stroke=GUNMETAL, stroke_width="1.6",
                 stroke_opacity="0.55"))

    # ---- occlusion bands -------------------------------------------------
    doc.add(rect(0, TOP_CHORD + 6, W, 46, fill="url(#trussShade)"))
    doc.add(rect(0, DECK_TOP - 26, W, 26, fill=INK, fill_opacity="0.18"))

    # ---- weathering -------------------------------------------------------
    for i in range(PANELS + 1):
        x = min(max(i * panel_w, 3.5), W - 3.5)
        doc.add(grime_streak(x - 3, DECK_TOP - 18, rng.uniform(18, 44),
                             rng.uniform(2, 4.5), op=rng.uniform(0.05, 0.12)))
        doc.add(grime_streak(x + 3, TOP_CHORD + 18, rng.uniform(16, 40),
                             rng.uniform(1.5, 3.4), op=rng.uniform(0.05, 0.12)))
    for _ in range(16):
        doc.add(rust_blob(rng.uniform(10, W - 10), rng.uniform(DECK_TOP - 12, DECK_TOP - 2),
                          rng.uniform(8, 26), rng.uniform(2, 5), rng,
                          op=rng.uniform(0.10, 0.22)))
    for _ in range(9):
        doc.add(rust_blob(rng.uniform(10, W - 10), rng.uniform(TOP_CHORD - 8, TOP_CHORD + 4),
                          rng.uniform(6, 20), rng.uniform(2, 4), rng,
                          op=rng.uniform(0.08, 0.16)))
    for _ in range(10):
        doc.add(ell(rng.uniform(20, W - 20), rng.uniform(120, 200),
                    rng.uniform(10, 34), rng.uniform(6, 18), fill=OLIVE,
                    fill_opacity=n(rng.uniform(0.03, 0.07))))
    # scratches along the deck fascia
    for _ in range(14):
        x = rng.uniform(0, W - 20)
        doc.add(path(f"M{n(x)},{n(rng.uniform(251, 258))}l{n(rng.uniform(8, 30))},0",
                     fill="none", stroke=WARM, stroke_width="0.8",
                     stroke_opacity=n(rng.uniform(0.05, 0.13))))

    return doc.render()


# --------------------------------------------------------------------------
# registry
# --------------------------------------------------------------------------

BUILDERS = [
    (f"{BLACK_RIDGE}/sky.svg", 1920, 1080, gen_sky),
    (f"{BLACK_RIDGE}/far.svg", 1600, 720, gen_far),
    (f"{BLACK_RIDGE}/mid.svg", 1600, 720, gen_mid),
    (f"{BLACK_RIDGE}/near.svg", 1600, 720, gen_near),
    (f"{BLACK_RIDGE}/ground.svg", 512, 512, gen_ground),
    (f"{COMMON}/industrial_barrier.svg", 360, 220, gen_barrier),
    (f"{COMMON}/ore_cart.svg", 300, 260, gen_cart),
    (f"{COMMON}/pipe_stack.svg", 320, 220, gen_pipes),
    (f"{COMMON}/ash_rock.svg", 340, 240, gen_rock),
    (f"{COMMON}/floodlight.svg", 200, 320, gen_floodlight),
    (f"{COMMON}/steel_bridge.svg", 900, 260, gen_bridge),
]

FORBIDDEN = ("<filter", "feGaussian", "<image", "xlink:href", "<text",
             "@font-face", "<use", "data:image")

# --------------------------------------------------------------------------
# geometry audit - catches shapes that leak outside a prop's canvas
# --------------------------------------------------------------------------

_TOKEN = re.compile(r"([MmLlHhVvCcSsQqTtAaZz])|(-?\d*\.?\d+)")
_NUM = re.compile(r"-?\d*\.?\d+")
_ATTR = re.compile(r'([\w-]+)="([^"]*)"')


def _path_points(d):
    groups = []
    for m in _TOKEN.finditer(d):
        if m.group(1):
            groups.append([m.group(1), []])
        elif groups:
            groups[-1][1].append(float(m.group(2)))
    pts = []
    cur = [0.0, 0.0]
    start = [0.0, 0.0]
    for cmd, vals in groups:
        c = cmd
        i = 0
        while i < len(vals):
            if c in "Mm":
                if i + 1 >= len(vals):
                    break
                x, y = vals[i], vals[i + 1]
                if c == "m":
                    x += cur[0]
                    y += cur[1]
                cur = [x, y]
                start = list(cur)
                pts.append(tuple(cur))
                i += 2
                c = "L" if c == "M" else "l"
            elif c in "Ll":
                if i + 1 >= len(vals):
                    break
                x, y = vals[i], vals[i + 1]
                if c == "l":
                    x += cur[0]
                    y += cur[1]
                cur = [x, y]
                pts.append(tuple(cur))
                i += 2
            elif c in "HhVv":
                if i >= len(vals):
                    break
                v = vals[i]
                if c == "H":
                    cur[0] = v
                elif c == "h":
                    cur[0] += v
                elif c == "V":
                    cur[1] = v
                else:
                    cur[1] += v
                pts.append(tuple(cur))
                i += 1
            elif c in "Qq":
                if i + 3 >= len(vals):
                    break
                if c == "Q":
                    pts.append((vals[i], vals[i + 1]))
                    x, y = vals[i + 2], vals[i + 3]
                else:
                    pts.append((cur[0] + vals[i], cur[1] + vals[i + 1]))
                    x, y = cur[0] + vals[i + 2], cur[1] + vals[i + 3]
                cur = [x, y]
                pts.append(tuple(cur))
                i += 4
            elif c in "Cc":
                if i + 5 >= len(vals):
                    break
                if c == "C":
                    pts.append((vals[i], vals[i + 1]))
                    pts.append((vals[i + 2], vals[i + 3]))
                    x, y = vals[i + 4], vals[i + 5]
                else:
                    pts.append((cur[0] + vals[i], cur[1] + vals[i + 1]))
                    pts.append((cur[0] + vals[i + 2], cur[1] + vals[i + 3]))
                    x, y = cur[0] + vals[i + 4], cur[1] + vals[i + 5]
                cur = [x, y]
                pts.append(tuple(cur))
                i += 6
            elif c in "Aa":
                if i + 6 >= len(vals):
                    break
                x, y = vals[i + 5], vals[i + 6]
                if c == "a":
                    x += cur[0]
                    y += cur[1]
                cur = [x, y]
                pts.append(tuple(cur))
                i += 7
            else:
                break
    return pts


def collect_bounds(text):
    xs, ys = [], []
    for m in re.finditer(r'points="([^"]+)"', text):
        ns = [float(v) for v in _NUM.findall(m.group(1))]
        xs += ns[0::2]
        ys += ns[1::2]
    for m in re.finditer(r'\bd="([^"]+)"', text):
        for x, y in _path_points(m.group(1)):
            xs.append(x)
            ys.append(y)
    for tag, keys in (("circle", ("cx", "cy", "r")),
                      ("ellipse", ("cx", "cy", "rx", "ry")),
                      ("rect", ("x", "y", "width", "height"))):
        for m in re.finditer(rf"<{tag}\b([^>]*)>", text):
            a = dict(_ATTR.findall(m.group(1)))
            try:
                v = [float(a.get(k, 0)) for k in keys]
            except ValueError:
                continue
            if tag == "circle":
                xs += [v[0] - v[2], v[0] + v[2]]
                ys += [v[1] - v[2], v[1] + v[2]]
            elif tag == "ellipse":
                xs += [v[0] - v[2], v[0] + v[2]]
                ys += [v[1] - v[3], v[1] + v[3]]
            else:
                xs += [v[0], v[0] + v[2]]
                ys += [v[1], v[1] + v[3]]
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def main():
    results = []
    for rel, w, h, fn in BUILDERS:
        svg = fn()
        out = os.path.join(ROOT, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(svg)
        results.append((rel, w, h, len(svg.encode("utf-8"))))

    print(f"{'file':<56}{'px':>12}{'bytes':>9}  status")
    print("-" * 96)
    ok = True
    for rel, w, h, size in results:
        out = os.path.join(ROOT, rel.replace("/", os.sep))
        status = []
        try:
            root = ET.parse(out).getroot()
            if root.get("width") != str(w) or root.get("height") != str(h):
                status.append("DIM-MISMATCH")
                ok = False
            vb = (root.get("viewBox") or "").split()
            if [float(v) for v in vb] != [0, 0, float(w), float(h)]:
                status.append("VIEWBOX-MISMATCH")
                ok = False
        except ET.ParseError as exc:
            status.append(f"XML-ERROR {exc}")
            ok = False
        if size > MAX_BYTES:
            status.append("TOO-BIG")
            ok = False
        txt = open(out, encoding="utf-8").read()
        bad = [t for t in FORBIDDEN if t in txt]
        if bad:
            status.append("FORBIDDEN:" + ",".join(bad))
            ok = False
        b = collect_bounds(txt)
        if b and "/common/" in rel:
            slack = 20 if rel.endswith("steel_bridge.svg") else 2.0
            if b[0] < -slack or b[1] < -slack or b[2] > w + slack or b[3] > h + slack:
                status.append(f"OUT-OF-CANVAS {b[0]:.0f},{b[1]:.0f}..{b[2]:.0f},{b[3]:.0f}")
                ok = False
        print(f"{rel:<56}{w}x{h:<7}{size:>9}  {' '.join(status) or 'ok'}")
    print("-" * 96)
    print("ALL OK" if ok else "PROBLEMS FOUND")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
