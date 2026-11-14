#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Deterministic generator for MUDRO's industrial control skins.

Run with the project interpreter (plain ``python`` is a stub on this machine)::

    C:\\Users\\Faraz_pc\\AppData\\Local\\Programs\\Python\\Python314\\python.exe \
        tools/artgen/controls.py

All artwork is emitted from this file: no external references, no fonts, no
raster images and no SVG filters (Godot's ThorVG rasteriser ignores filters, so
every soft shadow is a stack of translucent offset shapes).  Output is pure
function of the constants below - no timestamps, no RNG without a fixed seed.

Visual language
---------------
charcoal #17191b / graphite #24272a / gunmetal #3a4046, ivory #f4ede0 engraving,
restrained amber #b07a33 / #d99a45 as the only accent, muted red #8c3b32 for
brake, cold teal #2f6b63 reserved for clutch hints.
"""

from __future__ import annotations

import math
import os
import random
import sys
import xml.etree.ElementTree as ET

# --------------------------------------------------------------------------- palette
CHARCOAL = "#17191b"
GRAPHITE = "#24272a"
GUNMETAL = "#3a4046"
IVORY = "#f4ede0"
AMBER = "#b07a33"
AMBER_HI = "#d99a45"
BRAKE = "#8c3b32"
TEAL = "#2f6b63"
STEEL = "#5c656d"
STEEL_HI = "#9aa4ac"
INK = "#050606"

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "ui", "controls")

# Gate-panel geometry, single source of truth for the game side.
GATE_W, GATE_H = 760, 560
GATE_X = (GATE_W * 0.20, GATE_W * 0.50, GATE_W * 0.80)
GATE_YT = GATE_H * 0.28
GATE_YM = GATE_H * 0.50
GATE_YB = GATE_H * 0.72


# --------------------------------------------------------------------------- helpers
def num(v, p: int = 2) -> str:
    """Fixed-point number without trailing zeros (keeps files small/stable)."""
    if isinstance(v, str):
        return v
    s = f"{v:.{p}f}"
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    if s in ("-0", "", "-"):
        return "0"
    return s


def attrs(**kw) -> str:
    out = []
    for k, v in kw.items():
        if v is None:
            continue
        out.append(f'{k.replace("_", "-")}="{num(v)}"')
    return " ".join(out)


def el(tag: str, **kw) -> str:
    return f"<{tag} {attrs(**kw)}/>"


def circle(cx, cy, r, **kw) -> str:
    return el("circle", cx=cx, cy=cy, r=r, **kw)


def rect(x, y, w, h, **kw) -> str:
    return el("rect", x=x, y=y, width=w, height=h, **kw)


def path(d, **kw) -> str:
    return el("path", d=d, **kw)


def poly(points) -> str:
    d = "M" + " L".join(f"{num(x)} {num(y)}" for x, y in points)
    return d + " Z"


def rounded_poly(points, radius: float) -> str:
    """Closed polygon with quadratic-rounded corners (machined plate look)."""
    n = len(points)
    d = []
    for i in range(n):
        px, py = points[i]
        ax, ay = points[i - 1]
        bx, by = points[(i + 1) % n]
        l1 = math.hypot(ax - px, ay - py) or 1.0
        l2 = math.hypot(bx - px, by - py) or 1.0
        u1 = ((ax - px) / l1, (ay - py) / l1)
        u2 = ((bx - px) / l2, (by - py) / l2)
        rr = min(radius, 0.45 * l1, 0.45 * l2)
        s1 = (px + u1[0] * rr, py + u1[1] * rr)
        s2 = (px + u2[0] * rr, py + u2[1] * rr)
        d.append(("M" if i == 0 else "L") + f"{num(s1[0])} {num(s1[1])}")
        d.append(f"Q{num(px)} {num(py)} {num(s2[0])} {num(s2[1])}")
    return " ".join(d) + " Z"


def arc(cx, cy, r, a0, a1) -> str:
    """Elliptical arc path, angles in degrees (0 = +x, 90 = +y / down)."""
    p0 = (cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0)))
    p1 = (cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1)))
    large = 1 if abs(a1 - a0) > 180 else 0
    sweep = 1 if a1 > a0 else 0
    return (
        f"M{num(p0[0])} {num(p0[1])} "
        f"A{num(r)} {num(r)} 0 {large} {sweep} {num(p1[0])} {num(p1[1])}"
    )


def stop_xml(stops) -> str:
    out = []
    for off, col, op in stops:
        a = f' offset="{num(off, 3)}" stop-color="{col}"'
        if op < 0.999:
            a += f' stop-opacity="{num(op, 3)}"'
        out.append(f"<stop{a}/>")
    return "".join(out)


class Svg:
    """Tiny ordered SVG document builder."""

    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.defs: list[str] = []
        self.body: list[str] = []
        self._seq = 0

    def _id(self, prefix: str) -> str:
        self._seq += 1
        return f"{prefix}{self._seq}"

    def lin(self, x1, y1, x2, y2, stops) -> str:
        gid = self._id("lg")
        self.defs.append(
            f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" '
            f'x1="{num(x1)}" y1="{num(y1)}" x2="{num(x2)}" y2="{num(y2)}">'
            + stop_xml(stops)
            + "</linearGradient>"
        )
        return f"url(#{gid})"

    def rad(self, cx, cy, r, stops, fx=None, fy=None) -> str:
        gid = self._id("rg")
        focal = ""
        if fx is not None and fy is not None:
            focal = f' fx="{num(fx)}" fy="{num(fy)}"'
        self.defs.append(
            f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" '
            f'cx="{num(cx)}" cy="{num(cy)}" r="{num(r)}"{focal}>'
            + stop_xml(stops)
            + "</radialGradient>"
        )
        return f"url(#{gid})"

    def add(self, *items: str) -> None:
        for it in items:
            if it:
                self.body.append(it)

    def render(self) -> str:
        head = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
            f'viewBox="0 0 {self.w} {self.h}">\n'
        )
        defs = "<defs>" + "".join(self.defs) + "</defs>\n" if self.defs else ""
        return head + defs + "\n".join(self.body) + "\n</svg>\n"


def soft_shadow_circle(cx, cy, r, layers=7, spread=16.0, dy=7.0, op=0.05, color=INK) -> str:
    out = []
    for i in range(layers, 0, -1):
        t = i / layers
        rr = r + spread * t
        o = op * (0.45 + 0.55 * t)
        out.append(
            circle(cx, cy + dy * (1.0 - 0.25 * t), rr,
                   fill=color, fill_opacity=round(o, 4))
        )
    return "".join(out)


def soft_shadow_rect(x, y, w, h, rx, layers=6, spread=14.0, dy=8.0, op=0.05) -> str:
    out = []
    for i in range(layers, 0, -1):
        t = i / layers
        e = spread * t
        out.append(
            rect(x - e, y - e + dy * (1.0 - 0.25 * t), w + 2 * e, h + 2 * e,
                 rx=rx + e * 0.7, fill=INK, fill_opacity=round(op * (0.45 + 0.55 * t), 4))
        )
    return "".join(out)


def brushed(x, y, w, h, count=90, horizontal=True, seed=7, op=0.05, inset=6.0) -> str:
    """Directional brushed-metal hairlines, grouped by opacity to stay compact."""
    rnd = random.Random(seed)
    buckets = {"L1": [], "L2": [], "D1": [], "D2": []}
    for i in range(count):
        t = (i + 0.5) / count
        if horizontal:
            yy = y + t * h + rnd.uniform(-0.35, 0.35)
            a = x + inset + rnd.uniform(0, 4)
            b = x + w - inset - rnd.uniform(0, 4)
            d = f"M{num(a)} {num(yy)} H{num(b)}"
        else:
            xx = x + t * w + rnd.uniform(-0.35, 0.35)
            a = y + inset + rnd.uniform(0, 4)
            b = y + h - inset - rnd.uniform(0, 4)
            d = f"M{num(xx)} {num(a)} V{num(b)}"
        key = ("L" if i % 2 == 0 else "D") + ("2" if rnd.random() > 0.58 else "1")
        buckets[key].append(f'<path d="{d}"/>')
    styles = {
        "L1": (STEEL_HI, op * 0.55, 0.55),
        "L2": (STEEL_HI, op * 1.30, 0.8),
        "D1": (INK, op * 0.95, 0.6),
        "D2": (INK, op * 2.00, 0.95),
    }
    out = []
    for k in ("L1", "L2", "D1", "D2"):
        if not buckets[k]:
            continue
        col, o, sw = styles[k]
        out.append(
            f'<g fill="none" stroke="{col}" stroke-opacity="{num(o, 3)}" '
            f'stroke-width="{num(sw)}" stroke-linecap="butt">'
            + "".join(buckets[k]) + "</g>"
        )
    return "".join(out)


def engraved(items, cx, cy, scale=1.0, width=6.0, op=0.92, off=1.0, color=IVORY) -> str:
    """Recessed engraving: dark groove, cast shadow, ivory line, top sheen."""

    def grp(dx, dy, sw, col, o):
        return (
            f'<g transform="translate({num(cx + dx)} {num(cy + dy)}) scale({num(scale, 4)})" '
            f'stroke="{col}" stroke-opacity="{num(o, 3)}" stroke-width="{num(sw)}" '
            f'stroke-linecap="round" stroke-linejoin="round" fill="none">'
            + "".join(items) + "</g>"
        )

    return "".join((
        grp(0.4 * off, 1.0 * off, width * 2.55, STEEL_HI, 0.17),
        grp(0, 0, width * 2.05, "#040506", 0.52),
        grp(0.9 * off, 1.45 * off, width * 1.02, "#000000", 0.58),
        grp(0, 0, width, color, op),
        grp(0, -0.55 * off, width * 0.30, "#ffffff", 0.10),
    ))


def bolt(s: Svg, cx, cy, r, hex_socket=True, slot_angle=32) -> None:
    g = s.rad(cx - r * 0.38, cy - r * 0.42, r * 1.6,
              [(0, "#a7b1b8", 1), (0.45, "#646e76", 1), (0.82, "#33393f", 1), (1, "#1a1e21", 1)])
    s.add(circle(cx + 0.7, cy + 1.4, r + 1.3, fill=INK, fill_opacity=0.55))
    s.add(circle(cx, cy, r + 1.0, fill="#0c0e10", fill_opacity=0.9))
    s.add(circle(cx, cy, r, fill=g))
    s.add(circle(cx, cy, r, fill="none", stroke="#040505", stroke_width=0.7, stroke_opacity=0.7))
    if hex_socket:
        pts = [
            (cx + r * 0.46 * math.cos(math.radians(60 * i)),
             cy + r * 0.46 * math.sin(math.radians(60 * i)))
            for i in range(6)
        ]
        s.add(path(poly(pts), fill="#07090a", fill_opacity=0.85,
                   stroke=STEEL_HI, stroke_opacity=0.16, stroke_width=max(0.5, r * 0.1)))
    else:
        a = math.radians(slot_angle)
        dx, dy = math.cos(a) * r * 0.62, math.sin(a) * r * 0.62
        s.add(path(f"M{num(cx - dx)} {num(cy - dy)} L{num(cx + dx)} {num(cy + dy)}",
                   stroke="#060708", stroke_width=max(0.9, r * 0.26),
                   stroke_linecap="round", stroke_opacity=0.9))
        s.add(path(f"M{num(cx - dx)} {num(cy - dy + 0.8)} L{num(cx + dx)} {num(cy + dy + 0.8)}",
                   stroke=IVORY, stroke_width=max(0.4, r * 0.09),
                   stroke_linecap="round", stroke_opacity=0.18))
    s.add(circle(cx - r * 0.30, cy - r * 0.34, r * 0.36, fill="#ffffff", fill_opacity=0.10))


def rivet(s: Svg, cx, cy, r=8.0) -> None:
    g = s.rad(cx - r * 0.35, cy - r * 0.4, r * 1.5,
              [(0, "#8d98a0", 1), (0.42, "#626b72", 1), (0.78, "#353b41", 1), (1, "#1c2125", 1)])
    s.add(circle(cx + 0.8, cy + 1.6, r + 2.4, fill=INK, fill_opacity=0.42))
    s.add(circle(cx, cy, r + 1.6, fill="#101316", fill_opacity=0.85))
    s.add(circle(cx, cy, r + 0.9, fill="#2c3238"))
    s.add(circle(cx, cy, r, fill=g))
    s.add(circle(cx, cy, r + 0.2, fill="none", stroke="#050607", stroke_opacity=0.5, stroke_width=0.9))
    s.add(circle(cx - r * 0.26, cy - r * 0.30, r * 0.30, fill="#ffffff", fill_opacity=0.06))


def inner_shadow_rect(s: Svg, x, y, w, h, rx, top=0.85, bottom=0.30) -> None:
    g = s.lin(0, y, 0, y + h,
              [(0.0, "#000000", top), (0.45, "#000000", top * 0.35), (1.0, "#000000", bottom)])
    for ww, oo in ((18.0, 0.16), (11.0, 0.30), (5.5, 0.46)):
        rx_i = max(1.0, rx - ww * 0.5)
        s.add(rect(x + ww * 0.5, y + ww * 0.5, w - ww, h - ww, rx=rx_i,
                   fill="none", stroke=g, stroke_width=ww, stroke_opacity=oo))


# --------------------------------------------------------------------------- pad icons
def ico_throttle():
    return [
        '<g transform="translate(0 6)">',
        '<path d="M-38 -40 H-18"/>',
        '<path d="M-28 -40 V-32"/>',
        '<circle cx="-28" cy="-27" r="4.5"/>',
        '<path d="M-28 -22 L-8 10" stroke-width="8"/>',
        '<path d="M-26 4 L10 0 L14 16 L-22 20 Z"/>',
        '<path d="M-20 8 L4 5"/>',
        '<path d="M-21 13 L3 10"/>',
        '<path d="M20 -6 L34 10 L20 26"/>',
        '<path d="M33 -6 L47 10 L33 26"/>',
        '</g>',
    ]


def ico_brake():
    items = ['<circle cx="0" cy="0" r="33"/>', '<circle cx="0" cy="0" r="10"/>']
    for i in range(5):
        a = math.radians(i * 72 + 36)
        p0 = (19 * math.cos(a), 19 * math.sin(a))
        p1 = (26 * math.cos(a), 26 * math.sin(a))
        items.append(f'<path d="M{num(p0[0])} {num(p0[1])} L{num(p1[0])} {num(p1[1])}" '
                     f'stroke-width="3.4" stroke-linecap="round"/>')
    # floating caliper, clear of the disc
    items.append(path(arc(0, 0, 43, -48, 48), stroke_width="9", stroke_linecap="round"))
    return items


def ico_clutch():
    return [
        '<g transform="translate(0 4)">',
        '<path d="M-38 -38 H-18"/>',
        '<path d="M-28 -38 V-30"/>',
        '<circle cx="-28" cy="-25" r="4.5"/>',
        '<path d="M-28 -20 L-10 10" stroke-width="8"/>',
        '<path d="M-28 4 L2 0 L6 16 L-24 20 Z"/>',
        '<path d="M-22 8 L-2 5"/>',
        '<path d="M-23 13 L-3 10"/>',
        '<path d="M6 8 C12 8 14 12 18 12"/>',
        '<circle cx="32" cy="12" r="17"/>',
        '<circle cx="32" cy="12" r="11"/>',
        '<circle cx="32" cy="12" r="4.5"/>',
        '<path d="M39 5 L42 2"/>',
        '<path d="M25 6 L22 3"/>',
        '<path d="M37 19 L40 22"/>',
        '<path d="M27 19 L24 22"/>',
        '</g>',
    ]


def ico_handbrake():
    return [
        '<g transform="translate(-16 1)">',
        '<path d="M6 45 H52"/>',
        '<path d="M16 45 V40"/>',
        '<path d="M44 45 V40"/>',
        '<path d="M36 45 V28" stroke-width="9"/>',
        '<path d="M36 30 L6 -24" stroke-width="11"/>',
        '<circle cx="4" cy="-30" r="9"/>',
        '<circle cx="4" cy="-30" r="3.2"/>',
        '<path d="M28 18 l-3.4 -5"/>',
        '<path d="M23 11 l-3.4 -5"/>',
        '<circle cx="36" cy="34" r="5.5"/>',
        '</g>',
    ]


def ico_winch():
    return [
        '<g transform="translate(-12 10)">',
        '<circle cx="0" cy="-36" r="7"/>',
        '<circle cx="0" cy="-36" r="2.8"/>',
        '<path d="M0 -29 V-4"/>',
        '<path d="M-7 -22 L7 -26"/>',
        '<path d="M-7 -13 L7 -17"/>',
        '<path d="M0 -4 C0 14 9 24 21 20 C31 17 31 3 20 3"/>',
        '<path d="M20 3 L13 8"/>',
        '</g>',
    ]


def ico_start():
    return [
        path(arc(0, 0, 28, 302, 598)),
        '<path d="M0 -38 V-4"/>',
        circle(0, 0, 43, stroke_width="2.4", stroke_opacity="0.5"),
    ]


# --------------------------------------------------------------------------- button pads
def build_pad(name, size, accent, icon_items, icon_scale=0.92, teal=False,
              accent_op=0.95, start_ring=False, seed=23, accent_glow=0.07):
    s = Svg(size, size)
    u = size / 256.0
    c = size / 2.0
    r_out = 121.5 * u
    r_face = 94.5 * u
    r_acc = 83.5 * u
    r_step = 101.0 * u

    s.add(soft_shadow_circle(c, c + 3 * u, r_out, layers=7, spread=15 * u, dy=6 * u, op=0.052))
    s.add(circle(c, c, r_out + 1.4 * u, fill="#0b0d0e", fill_opacity=0.92))

    bez = s.rad(c - 30 * u, c - 38 * u, 205 * u, [
        (0.00, "#8d98a1", 1), (0.22, "#5a636b", 1), (0.48, "#3b4148", 1),
        (0.72, "#252a2f", 1), (0.89, "#15181b", 1), (1.00, "#0b0d0f", 1)])
    s.add(circle(c, c, r_out, fill=bez))
    s.add(circle(c, c, r_out, fill="none", stroke="#070809",
                 stroke_width=1.8 * u, stroke_opacity=0.85))

    # rim catch-light top-left, shade bottom-right
    s.add(path(arc(c, c, r_out - 2.2 * u, 188, 322), fill="none", stroke=IVORY,
               stroke_opacity=0.22, stroke_width=1.6 * u, stroke_linecap="round"))
    s.add(path(arc(c, c, r_out - 2.6 * u, 8, 152), fill="none", stroke="#000000",
               stroke_opacity=0.48, stroke_width=3.2 * u))

    # lathe-turned hairlines on the brushed ring
    for rr, col, op, sw in (
            (118.2, STEEL_HI, 0.060, 0.7), (115.2, INK, 0.24, 0.9),
            (112.2, STEEL_HI, 0.050, 0.7), (109.2, INK, 0.22, 0.9),
            (106.2, STEEL_HI, 0.045, 0.7), (103.4, INK, 0.30, 1.0)):
        s.add(circle(c, c, rr * u, fill="none", stroke=col,
                     stroke_width=sw * u, stroke_opacity=op))

    # radial brushing
    rnd = random.Random(seed)
    fine_l, fine_d = [], []
    for i in range(120):
        a = rnd.uniform(0, math.tau)
        r0 = rnd.uniform(104.6, 112.0) * u
        r1 = rnd.uniform(113.4, 119.4) * u
        d = (f"M{num(c + r0 * math.cos(a))} {num(c + r0 * math.sin(a))} "
             f"L{num(c + r1 * math.cos(a))} {num(c + r1 * math.sin(a))}")
        (fine_l if i % 3 else fine_d).append(f'<path d="{d}"/>')
    s.add(f'<g fill="none" stroke="{STEEL_HI}" stroke-opacity="0.055" '
          f'stroke-width="{num(0.65 * u)}" stroke-linecap="round">' + "".join(fine_l) + "</g>")
    s.add(f'<g fill="none" stroke="#050708" stroke-opacity="0.10" '
          f'stroke-width="{num(0.60 * u)}" stroke-linecap="round">' + "".join(fine_d) + "</g>")

    # knurled outer edge
    kn_l, kn_d = [], []
    for i in range(96):
        a = i * math.tau / 96
        d = (f"M{num(c + 119.6 * u * math.cos(a))} {num(c + 119.6 * u * math.sin(a))} "
             f"L{num(c + 122.0 * u * math.cos(a))} {num(c + 122.0 * u * math.sin(a))}")
        (kn_l if i % 2 == 0 else kn_d).append(f'<path d="{d}"/>')
    s.add(f'<g fill="none" stroke="{STEEL_HI}" stroke-opacity="0.16" '
          f'stroke-width="{num(0.9 * u)}">' + "".join(kn_l) + "</g>")
    s.add(f'<g fill="none" stroke="#000000" stroke-opacity="0.42" '
          f'stroke-width="{num(1.0 * u)}">' + "".join(kn_d) + "</g>")

    # step down into the face
    s.add(circle(c, c, r_step + 1.8 * u, fill="#070809"))
    s.add(circle(c, c, r_step, fill="#15181a"))
    s.add(circle(c, c, r_step, fill="none", stroke=IVORY,
                 stroke_width=0.8 * u, stroke_opacity=0.10))
    s.add(circle(c, c, r_step - 2.4 * u, fill="none", stroke="#000000",
                 stroke_width=2.0 * u, stroke_opacity=0.55))

    # smoked glass face
    face = s.rad(c - 16 * u, c - 26 * u, 148 * u, [
        (0.00, "#30363b", 1), (0.28, "#23282c", 1), (0.60, "#171b1e", 1),
        (0.85, "#0f1214", 1), (1.00, "#0a0c0d", 1)])
    s.add(circle(c, c, r_face, fill=face))
    inner = s.rad(c, c, r_face, [
        (0.00, "#000000", 0.0), (0.50, "#000000", 0.02), (0.79, "#000000", 0.20),
        (0.93, "#000000", 0.50), (1.00, "#000000", 0.70)])
    s.add(circle(c, c, r_face, fill=inner))
    shade = s.lin(0, c - r_face, 0, c + r_face, [
        (0.00, "#000000", 0.42), (0.36, "#000000", 0.12),
        (0.60, "#000000", 0.0), (1.00, IVORY, 0.05)])
    s.add(circle(c, c, r_face, fill=shade))

    glx, gly = c - 22 * u, c - 34 * u
    gl = s.lin(glx - 58 * u, gly - 32 * u, glx + 40 * u, gly + 40 * u,
               [(0.0, IVORY, 0.14), (0.55, IVORY, 0.045), (1.0, IVORY, 0.0)])
    s.add(f'<ellipse cx="{num(glx)}" cy="{num(gly)}" rx="{num(56 * u)}" ry="{num(33 * u)}" '
          f'transform="rotate(-22 {num(glx)} {num(gly)})" fill="{gl}"/>')
    s.add(path(arc(c, c, r_face - 1.4 * u, 200, 300), fill="none", stroke=IVORY,
               stroke_opacity=0.24, stroke_width=1.0 * u, stroke_linecap="round"))

    # accent ring (machined groove + inlay + bloom)
    s.add(circle(c, c, r_acc, fill="none", stroke="#040505",
                 stroke_width=6.6 * u, stroke_opacity=0.78))
    s.add(circle(c, c, r_acc, fill="none", stroke=accent,
                 stroke_width=11.0 * u, stroke_opacity=accent_glow))
    s.add(circle(c, c, r_acc, fill="none", stroke=accent,
                 stroke_width=2.3 * u, stroke_opacity=accent_op))
    if start_ring:
        s.add(circle(c, c, r_acc + 6.4 * u, fill="none", stroke=accent,
                     stroke_width=1.1 * u, stroke_opacity=0.40))
        s.add(circle(c, c, r_acc - 5.0 * u, fill="none", stroke=accent,
                     stroke_width=0.8 * u, stroke_opacity=0.30))
    s.add(path(arc(c, c, r_acc + 0.9 * u, 198, 284), fill="none", stroke=IVORY,
               stroke_opacity=0.30, stroke_width=0.9 * u, stroke_linecap="round"))
    if teal:
        s.add(circle(c, c, r_acc - 6.6 * u, fill="none", stroke=TEAL,
                     stroke_width=5.0 * u, stroke_opacity=0.05))
        s.add(circle(c, c, r_acc - 6.6 * u, fill="none", stroke=TEAL,
                     stroke_width=1.2 * u, stroke_opacity=0.50))

    s.add(engraved(icon_items, c, c, scale=icon_scale, width=5.7 * u, op=0.92, off=u))
    return s


def build_square_pad(name, size, accent, icon_items, icon_scale=0.86, seed=31):
    s = Svg(size, size)
    u = size / 200.0
    m = 8 * u
    x, y, w, h = m, m, size - 2 * m, size - 2 * m
    rx = 30 * u
    c = size / 2.0

    s.add(soft_shadow_rect(x, y + 2 * u, w, h, rx, layers=6, spread=11 * u, dy=6 * u, op=0.06))
    s.add(rect(x - 1.4 * u, y - 1.4 * u, w + 2.8 * u, h + 2.8 * u, rx=rx + 1.4 * u,
               fill="#0a0c0d"))

    bez = s.lin(x, y, x + w, y + h, [
        (0.00, "#7d8891", 1), (0.18, "#525b63", 1), (0.45, "#3a4046", 1),
        (0.72, "#252a2e", 1), (1.00, "#14171a", 1)])
    s.add(rect(x, y, w, h, rx=rx, fill=bez))
    s.add(rect(x, y, w, h, rx=rx, fill="none", stroke="#060708",
               stroke_width=1.8 * u, stroke_opacity=0.9))
    s.add(rect(x + 2.0 * u, y + 2.0 * u, w - 4 * u, h - 4 * u, rx=rx - 2 * u,
               fill="none", stroke=IVORY, stroke_width=1.1 * u, stroke_opacity=0.14))
    s.add(brushed(x + 4 * u, y + 4 * u, w - 8 * u, h - 8 * u, count=64,
                  horizontal=True, seed=seed, op=0.05, inset=10 * u))

    # machined inner band + glass face
    ix, iy = x + 22 * u, y + 22 * u
    iw, ih = w - 44 * u, h - 44 * u
    irx = rx - 12 * u
    s.add(rect(ix, iy, iw, ih, rx=irx, fill="#101315"))
    s.add(rect(ix, iy, iw, ih, rx=irx, fill="none", stroke="#000000",
               stroke_width=2.0 * u, stroke_opacity=0.7))
    s.add(rect(ix + 1.0 * u, iy + 1.0 * u, iw - 2 * u, ih - 2 * u, rx=irx - 1 * u,
               fill="none", stroke=STEEL_HI, stroke_width=0.9 * u, stroke_opacity=0.14))

    fx, fy = ix + 9 * u, iy + 9 * u
    fw, fh = iw - 18 * u, ih - 18 * u
    frx = max(6.0, irx - 7 * u)
    face = s.rad(c - 14 * u, fy + 22 * u, fw * 0.78, [
        (0.00, "#2e3439", 1), (0.35, "#20252a", 1), (0.72, "#14181b", 1), (1.00, "#0b0d0f", 1)])
    s.add(rect(fx, fy, fw, fh, rx=frx, fill=face))
    inner_shadow_rect(s, fx, fy, fw, fh, frx, top=0.9, bottom=0.35)
    gcx, gcy = fx + fw * 0.40, fy + fh * 0.30
    grx, gry = fw * 0.44, fh * 0.31
    gl = s.lin(gcx - grx, gcy - gry, gcx + grx * 0.6, gcy + gry * 1.4,
               [(0.0, IVORY, 0.13), (0.55, IVORY, 0.04), (1.0, IVORY, 0.0)])
    s.add(f'<ellipse cx="{num(gcx)}" cy="{num(gcy)}" rx="{num(grx)}" ry="{num(gry)}" '
          f'transform="rotate(-14 {num(gcx)} {num(gcy)})" fill="{gl}"/>')

    # accent inlay on the machined step around the glass (never on the glass)
    ax, ay = fx - 5 * u, fy - 5 * u
    aw, ah = fw + 10 * u, fh + 10 * u
    arx = frx + 5 * u
    s.add(rect(ax, ay, aw, ah, rx=arx, fill="none", stroke="#040506",
               stroke_width=5.0 * u, stroke_opacity=0.65))
    s.add(rect(ax, ay, aw, ah, rx=arx, fill="none", stroke=accent,
               stroke_width=10.0 * u, stroke_opacity=0.06))
    s.add(rect(ax, ay, aw, ah, rx=arx, fill="none", stroke=accent,
               stroke_width=1.8 * u, stroke_opacity=0.62))

    for sx, sy in ((x + 15 * u, y + 15 * u), (x + w - 15 * u, y + 15 * u),
                   (x + 15 * u, y + h - 15 * u), (x + w - 15 * u, y + h - 15 * u)):
        bolt(s, sx, sy, 4.6 * u, hex_socket=False, slot_angle=38)

    s.add(engraved(icon_items, c, c, scale=icon_scale, width=5.4 * u, op=0.93, off=u))
    return s


def build_pressed():
    s = Svg(256, 256)
    c = 128.0
    r_face = 94.5
    s.add(circle(c, c, r_face, fill=s.rad(c, c - 8, 132, [
        (0.00, "#040505", 0.58), (0.55, "#040505", 0.44), (1.00, "#040505", 0.30)])))
    s.add(circle(c, c, r_face, fill=s.rad(c, c, r_face, [
        (0.00, AMBER_HI, 0.0), (0.50, AMBER_HI, 0.0), (0.76, AMBER_HI, 0.09),
        (0.90, AMBER_HI, 0.30), (0.97, AMBER_HI, 0.42), (1.00, AMBER_HI, 0.0)])))
    s.add(circle(c, c, r_face, fill=s.lin(0, c - r_face, 0, c + 24, [
        (0.00, "#000000", 0.55), (0.40, "#000000", 0.22), (0.70, "#000000", 0.02),
        (1.00, "#000000", 0.0)])))
    s.add(circle(c, c, 93.2, fill="none", stroke=AMBER_HI, stroke_width=1.2, stroke_opacity=0.55))
    s.add(circle(c, c, 86.0, fill="none", stroke=AMBER, stroke_width=3.2, stroke_opacity=0.20))
    s.add(circle(c, c, 62.0, fill=s.rad(c, c, 62, [
        (0.00, AMBER_HI, 0.10), (0.55, AMBER, 0.05), (1.00, AMBER, 0.0)])))
    return s


# --------------------------------------------------------------------------- pedals
def build_pedal(name, w, h, accent, cfg, teal=False, seed=41):
    s = Svg(w, h)
    cx = w / 2.0
    y0, y1 = cfg["y0"], cfg["y1"]
    hw0, hw1 = cfg["hw0"], cfg["hw1"]

    def hw(y):
        t = (y - y0) / (y1 - y0)
        return hw0 + (hw1 - hw0) * t

    plate = rounded_poly([(cx - hw0, y0), (cx + hw0, y0), (cx + hw1, y1), (cx - hw1, y1)], 9)

    # soft cast shadow
    for i in range(7, 0, -1):
        t = i / 7.0
        s.add(f'<path d="{plate}" transform="translate({num(2.5 + 9 * t)} {num(7 + 13 * t)})" '
              f'fill="#000000" fill-opacity="{num(0.028 + 0.024 * t, 3)}"/>')

    # steel arm
    arm_top = y1 - 30
    arm = rounded_poly([(cx - 16, arm_top), (cx + 16, arm_top), (cx + 21, h - 36),
                        (cx + 31, h - 10), (cx - 31, h - 10), (cx - 21, h - 36)], 8)
    arm_g = s.lin(cx - 34, 0, cx + 34, 0, [
        (0.00, "#101315", 1), (0.22, "#343a41", 1), (0.44, "#5b646c", 1),
        (0.62, "#454c53", 1), (0.82, "#24282d", 1), (1.00, "#0d1012", 1)])
    s.add(f'<path d="{arm}" fill="{arm_g}" stroke="#060708" stroke-width="1.4" stroke-opacity="0.9"/>')
    s.add(f'<path d="M{num(cx - 7)} {num(arm_top + 10)} L{num(cx - 3)} {num(h - 18)}" '
          f'stroke="{IVORY}" stroke-opacity="0.14" stroke-width="2.2"/>')
    s.add(f'<path d="M{num(cx + 11)} {num(arm_top + 10)} L{num(cx + 15)} {num(h - 20)}" '
          f'stroke="#000000" stroke-opacity="0.38" stroke-width="2.6"/>')
    # rubber boot at the plate junction + stamped recess in the arm
    s.add(rect(cx - 25, arm_top - 4, 50, 16, rx=7, fill="#0a0c0e"))
    s.add(rect(cx - 25, arm_top - 4, 50, 16, rx=7, fill="none", stroke="#000000",
               stroke_width=1.2, stroke_opacity=0.7))
    s.add(rect(cx - 22, arm_top - 2.6, 44, 2.4, rx=1.2, fill=IVORY, fill_opacity=0.10))
    s.add(rect(cx - 8, arm_top + 18, 16, 46, rx=8, fill="#0a0c0e", fill_opacity=0.85))
    s.add(rect(cx - 8, arm_top + 18, 16, 46, rx=8, fill="none", stroke="#000000",
               stroke_width=1.0, stroke_opacity=0.6))
    s.add(rect(cx - 7, arm_top + 61, 14, 1.4, rx=0.7, fill=IVORY, fill_opacity=0.12))
    s.add(rect(cx - 36, h - 26, 72, 18, rx=7, fill="#202529"))
    s.add(rect(cx - 36, h - 26, 72, 18, rx=7, fill="none", stroke="#000000",
               stroke_width=1.2, stroke_opacity=0.7))
    s.add(rect(cx - 30, h - 24, 60, 3, rx=1.5, fill=IVORY, fill_opacity=0.08))
    bolt(s, cx, h - 17, 6.4)
    s.add(rect(cx - 26, h - 60, 12, 2.4, rx=1.2, fill=AMBER, fill_opacity=0.55))

    # plate body
    plate_g = s.lin(cx - hw1, y0, cx + hw1, y1, [
        (0.00, "#4c545b", 1), (0.26, "#3b4147", 1), (0.60, "#272c31", 1),
        (0.86, "#1a1e21", 1), (1.00, "#14171a", 1)])
    s.add(f'<path d="{plate}" fill="{plate_g}" stroke="#070809" stroke-width="1.6" stroke-opacity="0.9"/>')

    bevel_g = s.lin(cx - hw0, y0, cx + hw1, y1, [
        (0.00, IVORY, 0.34), (0.30, IVORY, 0.06), (0.52, "#000000", 0.06),
        (0.80, "#000000", 0.35), (1.00, "#000000", 0.55)])
    inset = rounded_poly([(cx - hw0 + 3, y0 + 3), (cx + hw0 - 3, y0 + 3),
                          (cx + hw1 - 3, y1 - 3), (cx - hw1 + 3, y1 - 3)], 7)
    s.add(f'<path d="{inset}" fill="none" stroke="{bevel_g}" stroke-width="2.4"/>')

    face = rounded_poly([(cx - hw0 + 6, y0 + 6), (cx + hw0 - 6, y0 + 6),
                         (cx + hw1 - 6, y1 - 6), (cx - hw1 + 6, y1 - 6)], 6)
    face_g = s.lin(0, y0, 0, y1, [
        (0.00, "#2f353a", 1), (0.30, "#252a2f", 1), (0.70, "#1a1e22", 1), (1.00, "#121518", 1)])
    s.add(f'<path d="{face}" fill="{face_g}"/>')

    # glassy top sheen on the plate
    sheen = s.lin(0, y0, 0, y0 + (y1 - y0) * 0.45, [(0.0, IVORY, 0.10), (1.0, IVORY, 0.0)])
    s.add(f'<path d="{face}" fill="{sheen}"/>')

    # inlay stripe (recessed band)
    iy0, iy1 = cfg["inlay"]
    il = hw(iy0) - 14
    ir = hw(iy1) - 14
    band = rounded_poly([(cx - il, iy0), (cx + il, iy0), (cx + ir, iy1), (cx - ir, iy1)], 5)
    s.add(f'<path d="{band}" transform="translate(0 2)" fill="#040506" fill-opacity="0.75"/>')
    if accent == "amber":
        inlay = s.lin(cx - il, 0, cx + il, 0, [
            (0.00, "#5d3d17", 1), (0.22, "#a06a2a", 1), (0.50, AMBER_HI, 1),
            (0.78, "#9a6526", 1), (1.00, "#54360f", 1)])
    elif accent == "red":
        inlay = s.lin(cx - il, 0, cx + il, 0, [
            (0.00, "#43180f", 1), (0.22, "#73302a", 1), (0.50, "#a34b3f", 1),
            (0.78, "#6d2c26", 1), (1.00, "#3d1611", 1)])
    else:
        inlay = s.lin(cx - il, 0, cx + il, 0, [
            (0.00, "#24282c", 1), (0.30, "#4d555d", 1), (0.55, "#6b757e", 1),
            (0.80, "#3d444a", 1), (1.00, "#202428", 1)])
    s.add(f'<path d="{band}" fill="{inlay}"/>')
    s.add(f'<path d="{band}" fill="none" stroke="{IVORY}" stroke-opacity="0.22" stroke-width="1.0"/>')
    s.add(f'<path d="{band}" fill="none" stroke="#000000" stroke-opacity="0.45" stroke-width="2.4"/>')
    if teal:
        s.add(f'<path d="{band}" transform="translate(0 {num(6)})" fill="none" stroke="{TEAL}" '
              f'stroke-width="1.1" stroke-opacity="0.55"/>')

    # rubber tread ribs
    n = cfg["ribs"]
    rh = cfg["rib_h"]
    ry0, ry1 = cfg["rib_y0"], cfg["rib_y1"]
    step = (ry1 - ry0 - rh) / (n - 1)
    for i in range(n):
        yy = ry0 + i * step
        wl = hw(yy) - 11
        wr = hw(yy + rh) - 11
        rib = rounded_poly([(cx - wl, yy), (cx + wl, yy), (cx + wr, yy + rh), (cx - wr, yy + rh)], 4)
        s.add(f'<path d="{rib}" transform="translate(0 2.4)" fill="#040506" fill-opacity="0.55"/>')
        rib_g = s.lin(0, yy, 0, yy + rh, [
            (0.00, "#4f575f", 1), (0.30, "#3b4248", 1), (0.72, "#23282c", 1), (1.00, "#15191c", 1)])
        s.add(f'<path d="{rib}" fill="{rib_g}"/>')
        s.add(f'<path d="M{num(cx - wl + 4)} {num(yy + 1.5)} H{num(cx + wl - 4)}" '
              f'stroke="{IVORY}" stroke-opacity="0.13" stroke-width="1.2"/>')
        s.add(f'<path d="M{num(cx - wr + 4)} {num(yy + rh - 0.6)} H{num(cx + wr - 4)}" '
              f'stroke="#000000" stroke-opacity="0.35" stroke-width="1.1"/>')

    # corner bolts
    for bx, by in ((cx - hw0 + 19, y0 + 19), (cx + hw0 - 19, y0 + 19),
                   (cx - hw1 + 21, y1 - 19), (cx + hw1 - 21, y1 - 19)):
        bolt(s, bx, by, 5.6, hex_socket=True)

    # bottom machined rule
    rw = hw(y1 - 16) - 26
    s.add(f'<path d="M{num(cx - rw)} {num(y1 - 15)} H{num(cx + rw)}" stroke="{IVORY}" '
          f'stroke-opacity="0.09" stroke-width="1.2"/>')
    s.add(rect(cx - 20, y1 - 11, 40, 2.2, rx=1.1, fill=accent if accent != "gunmetal" else STEEL_HI,
               fill_opacity=0.55))

    # deterministic wear scratches
    rnd = random.Random(seed)
    for i in range(16):
        xx = cx + rnd.uniform(-hw1 * 0.85, hw1 * 0.85)
        yy = y0 + rnd.uniform(12, (y1 - y0) * 0.92)
        ln = rnd.uniform(4, 16)
        s.add(f'<path d="M{num(xx)} {num(yy)} l{num(ln)} {num(rnd.uniform(-1.2, 1.2))}" '
              f'stroke="{IVORY}" stroke-opacity="{num(rnd.uniform(0.03, 0.07), 3)}" '
              f'stroke-width="{num(rnd.uniform(0.5, 0.9))}"/>')
    return s


# --------------------------------------------------------------------------- slider
def build_slider_rail():
    s = Svg(120, 460)
    s.add(soft_shadow_rect(4, 4, 112, 452, 16, layers=5, spread=7, dy=6, op=0.06))

    base = s.lin(4, 4, 116, 456, [
        (0.00, "#3c434a", 1), (0.18, "#2e3439", 1), (0.55, "#23282c", 1),
        (0.85, "#1a1e21", 1), (1.00, "#14171a", 1)])
    s.add(rect(4, 4, 112, 452, rx=16, fill=base))
    s.add(rect(4, 4, 112, 452, rx=16, fill="none", stroke="#070809",
               stroke_width=1.6, stroke_opacity=0.9))
    s.add(rect(6, 6, 108, 448, rx=14, fill="none", stroke=IVORY,
               stroke_width=1.0, stroke_opacity=0.13))
    s.add(brushed(8, 8, 104, 444, count=120, horizontal=False, seed=77, op=0.055, inset=8))

    # dark channel
    ch_x, ch_y, ch_w, ch_h = 36, 22, 48, 416
    s.add(rect(ch_x - 3, ch_y - 3, ch_w + 6, ch_h + 6, rx=27, fill="#08090a"))
    s.add(rect(ch_x, ch_y, ch_w, ch_h, rx=24, fill=s.lin(ch_x, 0, ch_x + ch_w, 0, [
        (0.00, "#050708", 1), (0.30, "#0e1114", 1), (0.62, "#161a1d", 1),
        (0.88, "#0b0e10", 1), (1.00, "#060809", 1)])))
    s.add(rect(ch_x, ch_y, ch_w, ch_h, rx=24, fill="none", stroke="#000000",
               stroke_width=2.0, stroke_opacity=0.8))
    # inner shading of the channel
    s.add(rect(ch_x + 1.5, ch_y + 2, 8, ch_h - 4, rx=4, fill="#000000", fill_opacity=0.35))
    s.add(rect(ch_x + ch_w - 8, ch_y + 2, 6, ch_h - 4, rx=3, fill=IVORY, fill_opacity=0.05))
    s.add(rect(ch_x + 4, ch_y + 2, ch_w - 8, 3, rx=1.5, fill="#000000", fill_opacity=0.45))
    s.add(rect(ch_x + 4, ch_y + ch_h - 4, ch_w - 8, 2, rx=1, fill=IVORY, fill_opacity=0.06))

    # detent notches + amber scale
    ys = [58 + i * (402 - 58) / 6 for i in range(7)]
    for i, yy in enumerate(ys):
        s.add(rect(ch_x + 2, yy - 4.5, ch_w - 4, 9, rx=4.5, fill="#030405", fill_opacity=0.9))
        s.add(rect(ch_x + 2, yy - 4.5, ch_w - 4, 2.0, rx=1, fill="#000000", fill_opacity=0.6))
        s.add(rect(ch_x + 3, yy + 3.4, ch_w - 6, 1.5, rx=0.75, fill=IVORY, fill_opacity=0.17))
        long_tick = i in (0, 3, 6)
        tw = 24 if long_tick else 15
        top = 2.6 if long_tick else 1.9
        # right gutter
        s.add(rect(90, yy - top / 2, tw, top, rx=top / 2, fill=AMBER,
                   fill_opacity=0.82 if long_tick else 0.55))
        s.add(rect(90, yy - top / 2, tw, top * 0.42, rx=top * 0.21, fill=AMBER_HI,
                   fill_opacity=0.38))
        s.add(rect(90, yy + top / 2 + 0.7, tw, 0.9, rx=0.45, fill="#000000", fill_opacity=0.5))
        # left gutter (mirrored)
        s.add(rect(30 - tw, yy - top / 2, tw, top, rx=top / 2, fill=AMBER,
                   fill_opacity=0.55 if long_tick else 0.38))

    # centre detent marker
    mid = ys[3]
    s.add(circle(ch_x + ch_w - 5, mid, 2.6, fill=AMBER, fill_opacity=0.75))
    s.add(circle(ch_x + ch_w - 5, mid, 4.6, fill=AMBER_HI, fill_opacity=0.10))

    # machined end caps
    for ey in (6, 426):
        s.add(rect(26, ey, 68, 28, rx=8, fill=s.lin(0, ey, 0, ey + 28, [
            (0.00, "#464e55", 1), (0.42, "#2d3338", 1), (1.00, "#15181b", 1)])))
        s.add(rect(26, ey, 68, 28, rx=8, fill="none", stroke="#050708",
                   stroke_width=1.2, stroke_opacity=0.85))
        s.add(rect(28, ey + 1.4, 64, 1.4, rx=0.7, fill=IVORY, fill_opacity=0.16))
        s.add(rect(28, ey + 25.2, 64, 1.4, rx=0.7, fill="#000000", fill_opacity=0.5))
        bolt(s, 60, ey + 14, 6.4, hex_socket=True)
        s.add(rect(34, ey + 13, 14, 1.8, rx=0.9, fill=IVORY, fill_opacity=0.09))
        s.add(rect(72, ey + 13, 14, 1.8, rx=0.9, fill=IVORY, fill_opacity=0.09))

    return s


def build_slider_knob():
    s = Svg(168, 120)
    s.add(soft_shadow_rect(6, 16, 156, 88, 26, layers=6, spread=10, dy=9, op=0.06))

    body = s.lin(6, 16, 162, 104, [
        (0.00, "#79838c", 1), (0.14, "#4b535a", 1), (0.42, "#343a40", 1),
        (0.70, "#24292e", 1), (0.90, "#1a1e21", 1), (1.00, "#121518", 1)])
    s.add(rect(6, 16, 156, 88, rx=26, fill=body))
    s.add(rect(6, 16, 156, 88, rx=26, fill="none", stroke="#060708",
               stroke_width=1.8, stroke_opacity=0.9))
    s.add(rect(8, 18, 152, 84, rx=24, fill="none", stroke=IVORY,
               stroke_width=1.0, stroke_opacity=0.16))
    s.add(brushed(10, 20, 148, 80, count=54, horizontal=True, seed=91, op=0.05, inset=8))

    # smoked glass grip face
    fx, fy, fw, fh = 20, 28, 128, 64
    s.add(rect(fx, fy, fw, fh, rx=16, fill=s.rad(60, 44, 120, [
        (0.00, "#333a40", 1), (0.32, "#242a2f", 1), (0.68, "#171b1e", 1), (1.00, "#0d1012", 1)])))
    inner_shadow_rect(s, fx, fy, fw, fh, 16, top=0.85, bottom=0.32)
    gl = s.lin(fx, fy, fx + fw * 0.8, fy + fh,
               [(0.0, IVORY, 0.13), (0.45, IVORY, 0.04), (1.0, IVORY, 0.0)])
    s.add(rect(fx + 4, fy + 4, fw - 8, fh * 0.48, rx=13, fill=gl))

    # recessed grip pad with engraved grip lines
    s.add(rect(26, 36, 66, 48, rx=12, fill="#0f1316", fill_opacity=0.60))
    s.add(rect(26, 36, 66, 48, rx=12, fill="none", stroke="#000000",
               stroke_width=1.4, stroke_opacity=0.55))
    s.add(rect(27, 37, 64, 1.4, rx=0.7, fill=IVORY, fill_opacity=0.10))
    for gx in (34, 42, 50, 58, 66, 74):
        s.add(rect(gx - 1.8, 42, 3.6, 36, rx=1.8, fill="#030405", fill_opacity=0.90))
        s.add(rect(gx - 1.1, 42, 1.3, 36, rx=0.65, fill=IVORY, fill_opacity=0.15))
        s.add(rect(gx + 1.1, 42, 0.9, 36, rx=0.45, fill="#000000", fill_opacity=0.60))

    # small amber indicator in a chrome bezel
    s.add(circle(116, 60, 30, fill=AMBER_HI, fill_opacity=0.05))
    s.add(circle(116, 60, 19, fill=AMBER_HI, fill_opacity=0.07))
    s.add(circle(116, 60, 16.5, fill="#0a0c0d"))
    s.add(circle(116, 60, 16, fill=s.rad(112, 54, 20, [
        (0.00, "#c3cdd3", 1), (0.45, "#778189", 1), (0.80, "#3a4147", 1), (1.00, "#1b1f22", 1)])))
    s.add(circle(116, 60, 11.5, fill="#07090a"))
    s.add(circle(116, 60, 9.5, fill=s.rad(113, 56, 12, [
        (0.00, "#f8d49a", 1), (0.35, AMBER_HI, 1), (0.75, "#a06a2a", 1), (1.00, "#54360f", 1)])))
    s.add(circle(116, 60, 9.5, fill="none", stroke="#000000", stroke_opacity=0.5, stroke_width=1.0))
    s.add(circle(113.5, 56.5, 2.6, fill=IVORY, fill_opacity=0.45))
    s.add(rect(100, 34, 32, 2.2, rx=1.1, fill=AMBER, fill_opacity=0.50))

    for bx in (14, 154):
        bolt(s, bx, 60, 4.4, hex_socket=False, slot_angle=90)
    return s


# --------------------------------------------------------------------------- gate
def build_gate_panel():
    W, H = GATE_W, GATE_H
    s = Svg(W, H)
    x0, x1, x2 = GATE_X
    yt, ym, yb = GATE_YT, GATE_YM, GATE_YB

    s.add(f"<!-- gate slot nodes (normalized): 0.20/0.28 0.50/0.28 0.80/0.28 "
          f"0.20/0.50 0.50/0.50 0.80/0.50 0.20/0.72 0.50/0.72 0.80/0.72 -->")

    s.add(rect(6, 6, W - 12, H - 12, rx=22, fill=s.lin(6, 6, W - 6, H - 6, [
        (0.00, "#33393f", 1), (0.14, "#2a2f34", 1), (0.46, "#212529", 1),
        (0.78, "#1b1e21", 1), (1.00, "#15181b", 1)])))
    s.add(rect(6, 6, W - 12, H - 12, rx=22, fill="none", stroke="#070808",
               stroke_width=2.0, stroke_opacity=0.9))
    s.add(rect(9, 9, W - 18, H - 18, rx=20, fill="none", stroke=IVORY,
               stroke_width=1.0, stroke_opacity=0.10))

    s.add(brushed(10, 10, W - 20, H - 20, count=190, horizontal=True, seed=303, op=0.05, inset=14))

    # broad workshop sheen + corner vignette
    s.add(rect(6, 6, W - 12, H - 12, rx=22, fill=s.rad(W * 0.32, H * 0.18, W * 0.72, [
        (0.00, IVORY, 0.055), (0.45, IVORY, 0.018), (1.00, IVORY, 0.0)])))
    s.add(rect(6, 6, W - 12, H - 12, rx=22, fill=s.rad(W * 0.5, H * 0.5, W * 0.62, [
        (0.00, "#000000", 0.0), (0.62, "#000000", 0.02), (0.88, "#000000", 0.14),
        (1.00, "#000000", 0.26)])))

    # inner machined frame
    s.add(rect(30, 30, W - 60, H - 60, rx=12, fill="none", stroke="#050607",
               stroke_width=2.4, stroke_opacity=0.55))
    s.add(rect(31.4, 31.4, W - 62.8, H - 62.8, rx=11, fill="none", stroke=IVORY,
               stroke_width=0.9, stroke_opacity=0.12))

    # recessed mechanism field: gives the gate a real machined surround
    mfx, mfy = 86.0, 92.0
    mfw, mfh = W - 172.0, H - 200.0
    s.add(rect(mfx, mfy, mfw, mfh, rx=16, fill=s.lin(0, mfy, 0, mfy + mfh, [
        (0.00, "#15181b", 0.55), (0.40, "#1b1f22", 0.40),
        (0.78, "#14171a", 0.45), (1.00, "#0f1214", 0.55)])))
    s.add(rect(mfx, mfy, mfw, mfh, rx=16, fill="none", stroke="#000000",
               stroke_width=2.2, stroke_opacity=0.55))
    s.add(rect(mfx + 1.2, mfy + 1.2, mfw - 2.4, mfh - 2.4, rx=15, fill="none",
               stroke=IVORY, stroke_width=0.9, stroke_opacity=0.10))
    s.add(rect(mfx + 2, mfy + 2, mfw - 4, 9, rx=4, fill=s.lin(0, mfy, 0, mfy + 11, [
        (0.0, "#000000", 0.45), (1.0, "#000000", 0.0)])))
    for sx, sy in ((mfx + 15, mfy + 15), (mfx + mfw - 15, mfy + 15),
                   (mfx + 15, mfy + mfh - 15), (mfx + mfw - 15, mfy + mfh - 15)):
        bolt(s, sx, sy, 4.6, hex_socket=True)

    # brushed neutral strip: lighter than the plate so the H slot reads
    by0, by1 = ym - 30, ym + 30
    s.add(rect(104, by0, W - 208, 60, rx=8, fill=s.lin(0, by0, 0, by1, [
        (0.00, "#414951", 0.60), (0.16, "#353c43", 0.62),
        (0.70, "#262b30", 0.62), (1.00, "#1c2024", 0.68)])))
    s.add(rect(104, by0, W - 208, 60, rx=8, fill="none", stroke="#000000",
               stroke_width=1.6, stroke_opacity=0.45))
    s.add(rect(105, by0 + 1.2, W - 210, 1.6, rx=0.8, fill=IVORY, fill_opacity=0.22))
    s.add(rect(105, by1 - 2.4, W - 210, 2.0, rx=1.0, fill="#000000", fill_opacity=0.55))
    s.add(brushed(112, by0 + 4, W - 224, 52, count=22, horizontal=True, seed=404, op=0.05, inset=10))
    for tx in (118, W - 142):
        s.add(rect(tx, ym - 3, 24, 6, rx=3, fill=AMBER, fill_opacity=0.75))
        s.add(rect(tx, ym - 3, 24, 1.8, rx=0.9, fill=AMBER_HI, fill_opacity=0.50))
        s.add(rect(tx, ym + 3.4, 24, 1.2, rx=0.6, fill="#000000", fill_opacity=0.45))

    # ---- H-pattern gate slot ------------------------------------------------
    half = 14.0
    shapes = [
        (x0, ym - half, x2 - x0, half * 2, 0.0),          # neutral channel
        (x0 - half, yt, half * 2, yb - yt, half),          # left column
        (x1 - half, yt, half * 2, yb - yt, half),          # centre column
        (x2 - half, yt, half * 2, yb - yt, half),          # right column
    ]
    # soft contact shadow of the recess
    for sx, sy, sw, sh, srx in shapes:
        s.add(rect(sx - 9.0, sy - 9.0, sw + 18, sh + 18, rx=srx + 9,
                   fill="#000000", fill_opacity=0.16))
    # machined chamfer: light rim, darker inner bevel
    for sx, sy, sw, sh, srx in shapes:
        s.add(rect(sx - 2.8, sy - 2.8, sw + 5.6, sh + 5.6, rx=srx + 2.8,
                   fill="#a2adb5", fill_opacity=0.46))
    for sx, sy, sw, sh, srx in shapes:
        s.add(rect(sx - 1.2, sy - 1.2, sw + 2.4, sh + 2.4, rx=srx + 1.2,
                   fill="#5d666d", fill_opacity=0.55))
    groove_g = s.lin(0, yt, 0, yb, [
        (0.00, "#020304", 1), (0.24, "#060809", 1), (0.50, "#0c1012", 1),
        (0.74, "#080a0c", 1), (1.00, "#030405", 1)])
    for sx, sy, sw, sh, srx in shapes:
        s.add(rect(sx, sy, sw, sh, rx=srx, fill=groove_g))

    # inner walls
    for cx_ in (x0, x1, x2):
        s.add(rect(cx_ - half, yt, half * 2, 3.4, fill="#000000", fill_opacity=0.62))
        s.add(rect(cx_ - half + 1, yt + 3.4, half * 2 - 2, 1.2,
                   fill="#7d8891", fill_opacity=0.22))
        s.add(rect(cx_ - half, yb - 3.4, half * 2, 2.4, fill=IVORY, fill_opacity=0.10))
        s.add(rect(cx_ - half, yt + 3.4, 2.6, yb - yt - 7, fill="#000000", fill_opacity=0.45))
        s.add(rect(cx_ + half - 2.4, yt + 3.4, 1.8, yb - yt - 7, fill=IVORY, fill_opacity=0.07))
    s.add(rect(x0, ym - half, x2 - x0, 3.4, fill="#000000", fill_opacity=0.55))
    s.add(rect(x0 + 1, ym - half + 3.4, x2 - x0 - 2, 1.2, fill="#7d8891", fill_opacity=0.20))
    s.add(rect(x0, ym + half - 3.4, x2 - x0, 2.4, fill=IVORY, fill_opacity=0.09))

    # riveted corners
    for rx_, ry_ in ((38, 38), (W - 38, 38), (38, H - 38), (W - 38, H - 38)):
        rivet(s, rx_, ry_, 8.2)

    # machining wear on the plate
    rnd = random.Random(717)
    for i in range(26):
        wx = rnd.uniform(60, W - 60)
        wy = rnd.uniform(60, H - 60)
        wl = rnd.uniform(6, 26)
        s.add(f'<path d="M{num(wx)} {num(wy)} l{num(wl)} {num(rnd.uniform(-1.4, 0.6))}" '
              f'stroke="{IVORY}" stroke-opacity="{num(rnd.uniform(0.02, 0.05), 3)}" '
              f'stroke-width="{num(rnd.uniform(0.5, 0.9))}"/>')
    return s


def build_gate_knob():
    s = Svg(140, 140)
    cx, cy, r = 70.0, 70.0, 54.0
    s.add(soft_shadow_circle(cx, cy + 42, 44, layers=7, spread=12, dy=8, op=0.06))

    # shaft collar / boot (grounds the ball)
    s.add(f'<ellipse cx="{num(cx)}" cy="125" rx="31" ry="9" fill="#07080a"/>')
    s.add(f'<ellipse cx="{num(cx)}" cy="123" rx="27" ry="7" fill="{s.lin(0, 116, 0, 130, [(0, "#3a4046", 1), (1, "#0c0e10", 1)])}"/>')
    s.add(f'<ellipse cx="{num(cx)}" cy="122.6" rx="27" ry="7" fill="none" stroke="{IVORY}" stroke-opacity="0.10" stroke-width="1"/>')

    # leather body
    s.add(circle(cx, cy, r + 1.4, fill="#07080a"))
    s.add(circle(cx, cy, r, fill=s.rad(cx - 18, cy + 4, 62, [
        (0.00, "#5f666c", 1), (0.28, "#42484e", 1), (0.55, "#2e3236", 1),
        (0.80, "#1d2124", 1), (1.00, "#101214", 1)])))

    # leather grain: two clean stitched panels, no noisy stipple
    s.add(f'<path d="{arc(cx, cy, r - 4, 34, 146)}" fill="none" stroke="#000000" '
          f'stroke-opacity="0.28" stroke-width="1.0"/>')

    # leather sheen + lower rim light
    s.add(f'<ellipse cx="{num(cx - 15)}" cy="{num(cy + 30)}" rx="15" ry="8" '
          f'transform="rotate(-28 {num(cx - 15)} {num(cy + 30)})" fill="{IVORY}" fill-opacity="0.075"/>')
    s.add(f'<ellipse cx="{num(cx + 10)}" cy="100" rx="30" ry="15" '
          f'transform="rotate(-12 {num(cx + 10)} 100)" fill="{IVORY}" fill-opacity="0.045"/>')
    s.add(f'<path d="{arc(cx, cy, r - 1.6, 32, 148)}" fill="none" stroke="{IVORY}" '
          f'stroke-opacity="0.22" stroke-width="1.8" stroke-linecap="round"/>')
    s.add(f'<path d="{arc(cx, cy, r - 1.4, 302, 24)}" fill="none" stroke="#000000" '
          f'stroke-opacity="0.50" stroke-width="3.4"/>')

    # chrome cap above the leather seam (convex lower edge = machined collar)
    seam_y = cy - 20
    dx = math.sqrt(max(0.0, r * r - (seam_y - cy) ** 2))
    cap = (f"M{num(cx - dx)} {num(seam_y)} A{num(r)} {num(r)} 0 0 1 "
           f"{num(cx + dx)} {num(seam_y)} A240 240 0 0 1 {num(cx - dx)} {num(seam_y)} Z")
    cap_g = s.lin(cx - dx, seam_y - 50, cx + dx, seam_y, [
        (0.00, "#e2ebf0", 1), (0.16, "#c6d0d6", 1), (0.36, "#9aa5ad", 1),
        (0.58, "#6d777f", 1), (0.78, "#4a5158", 1), (1.00, "#2b3035", 1)])
    s.add(f'<path d="{cap}" fill="{cap_g}"/>')
    # turned rings on the cap
    s.add(f'<path d="{arc(cx, cy, 40, 212, 328)}" fill="none" stroke="{IVORY}" '
          f'stroke-opacity="0.24" stroke-width="1.2"/>')
    s.add(f'<path d="{arc(cx, cy, 33, 208, 332)}" fill="none" stroke="#000000" '
          f'stroke-opacity="0.20" stroke-width="1.0"/>')
    # cap rim + specular
    s.add(f'<path d="{arc(cx, cy, r - 1.2, 198, 302)}" fill="none" stroke="#ffffff" '
          f'stroke-opacity="0.34" stroke-width="1.4" stroke-linecap="round"/>')
    s.add(f'<ellipse cx="{num(cx - 20)}" cy="{num(cy - 34)}" rx="14" ry="7" '
          f'transform="rotate(-32 {num(cx - 20)} {num(cy - 34)})" fill="#ffffff" fill-opacity="0.30"/>')

    # seam: machined chrome collar, dark groove below, bright edge on top
    seam = (f"M{num(cx - dx)} {num(seam_y)} A240 240 0 0 0 "
            f"{num(cx + dx)} {num(seam_y)}")
    s.add(f'<path d="{seam}" fill="none" stroke="#050607" stroke-opacity="0.85" stroke-width="5.0"/>')
    s.add(f'<path d="{seam}" fill="none" stroke="#7b858d" stroke-opacity="0.85" stroke-width="2.4"/>')
    s.add(f'<path d="{seam}" fill="none" stroke="{IVORY}" stroke-opacity="0.35" stroke-width="0.9"/>')

    # stitching
    s.add(f'<path d="{arc(cx, cy, r - 9, 28, 152)}" fill="none" stroke="{IVORY}" '
          f'stroke-opacity="0.22" stroke-width="1.4" stroke-dasharray="2.4 5.2" stroke-linecap="round"/>')

    # amber top marker set into the chrome
    s.add(circle(cx, 22, 12, fill=AMBER_HI, fill_opacity=0.06))
    s.add(circle(cx, 22, 9.4, fill="#121517"))
    s.add(circle(cx, 22, 8.0, fill="none", stroke=STEEL_HI, stroke_opacity=0.42, stroke_width=1.1))
    s.add(circle(cx, 22, 6.0, fill=s.rad(cx - 1.6, 20.2, 10, [
        (0.00, "#f8d49a", 1), (0.34, AMBER_HI, 1), (0.74, "#a06a2a", 1), (1.00, "#54360f", 1)])))
    s.add(circle(cx, 22, 6.0, fill="none", stroke="#000000", stroke_opacity="0.55", stroke_width="0.9"))
    s.add(circle(cx - 1.6, 20.2, 1.7, fill=IVORY, fill_opacity="0.60"))
    return s


# --------------------------------------------------------------------------- plate
def build_frame_plate():
    s = Svg(320, 320)
    s.add(rect(6, 6, 308, 308, rx=24, fill=s.lin(6, 6, 250, 314, [
        (0.00, "#434b52", 1), (0.16, "#353c42", 1), (0.48, "#282d31", 1),
        (0.78, "#1e2225", 1), (1.00, "#161a1d", 1)])))
    s.add(rect(6, 6, 308, 308, rx=24, fill="none", stroke="#070808",
               stroke_width=2.0, stroke_opacity=0.9))
    s.add(rect(8.6, 8.6, 302.8, 302.8, rx=22, fill="none", stroke=IVORY,
               stroke_width=1.1, stroke_opacity=0.16))
    s.add(brushed(12, 12, 296, 296, count=150, horizontal=True, seed=909, op=0.055, inset=14))
    s.add(rect(6, 6, 308, 308, rx=24, fill=s.rad(110, 80, 250, [
        (0.00, IVORY, 0.05), (0.4, IVORY, 0.015), (1.00, IVORY, 0.0)])))

    # raised outer border with a recessed field (9-slice safe: all edges uniform)
    s.add(rect(20, 20, 280, 280, rx=18, fill="none", stroke="#0a0c0d",
               stroke_width=3.2, stroke_opacity=0.55))
    s.add(rect(21.6, 21.6, 276.8, 276.8, rx=17, fill="none", stroke=IVORY,
               stroke_width=1.2, stroke_opacity=0.15))
    s.add(rect(8, 8, 304, 304, rx=23, fill="none", stroke=s.lin(8, 8, 312, 312, [
        (0.00, IVORY, 0.26), (0.32, IVORY, 0.04), (0.55, "#000000", 0.08),
        (1.00, "#000000", 0.48)]), stroke_width=2.4))
    s.add(rect(26, 26, 268, 268, rx=14, fill=s.lin(0, 26, 0, 294, [
        (0.00, "#20252a", 1), (0.40, "#2a2f34", 1), (1.00, "#1a1e21", 1)])))
    inner_shadow_rect(s, 26, 26, 268, 268, 14, top=0.72, bottom=0.22)
    s.add(rect(27, 291.2, 266, 1.8, rx=0.9, fill=IVORY, fill_opacity=0.12))
    s.add(brushed(28, 28, 264, 264, count=110, horizontal=True, seed=911, op=0.07, inset=10))

    # diagonal workshop sheen over the field
    s.add(rect(26, 26, 268, 268, rx=14, fill=s.lin(26, 26, 294, 294, [
        (0.00, IVORY, 0.045), (0.34, IVORY, 0.012), (0.62, IVORY, 0.0), (1.00, IVORY, 0.0)])))
    s.add(rect(6, 6, 308, 308, rx=24, fill=s.rad(160, 160, 210, [
        (0.00, "#000000", 0.0), (0.62, "#000000", 0.03), (1.00, "#000000", 0.24)])))

    for rx_, ry_ in ((36, 36), (284, 36), (36, 284), (284, 284)):
        rivet(s, rx_, ry_, 8.4)
    return s


# --------------------------------------------------------------------------- 128px icons
def build_icon(name, items):
    s = Svg(128, 128)
    s.add(engraved(items, 0, 0, scale=1.0, width=6.2, op=0.94, off=1.0))
    return s


def ico_winch_128():
    return [
        '<g transform="translate(-8 6)">',
        '<circle cx="60" cy="18" r="9"/>',
        '<circle cx="60" cy="18" r="3.6"/>',
        '<path d="M60 27 V50"/>',
        '<path d="M52 34 L68 30"/>',
        '<path d="M52 43 L68 39"/>',
        '<path d="M60 50 C60 72 71 82 84 78 C95 74 95 58 83 58"/>',
        '<path d="M83 58 L75 63"/>',
        '</g>',
    ]


def gear_path(cx, cy, r_out, r_root, teeth):
    pts = []
    step = math.tau / teeth
    for i in range(teeth):
        a = i * step - math.pi / 2
        for rr, da in ((r_root, -0.31 * step), (r_out, -0.17 * step),
                       (r_out, 0.17 * step), (r_root, 0.31 * step)):
            ang = a + da
            pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    return poly(pts)


def ico_gear_128():
    items = [path(gear_path(64, 64, 47, 36, 9))]
    items.append('<circle cx="64" cy="64" r="13"/>')
    items.append('<circle cx="64" cy="64" r="4.5"/>')
    for i in range(6):
        a = math.radians(i * 60 + 30)
        items.append(f'<circle cx="{num(64 + 24 * math.cos(a))}" cy="{num(64 + 24 * math.sin(a))}" r="3.4"/>')
    return items


def ico_weather_128():
    items = [
        '<circle cx="94" cy="33" r="12"/>',
        '<path d="M94 14 V9"/>',
        '<path d="M94 52 V57"/>',
        '<path d="M75 33 H70"/>',
        '<path d="M118 33 H113"/>',
        '<path d="M80.5 19.5 L77 16"/>',
        '<path d="M107.5 46.5 L111 50"/>',
        '<path d="M107.5 19.5 L111 16"/>',
        '<path d="M80.5 46.5 L77 50"/>',
        '<path d="M14 84 C4 84 2 68 14 66 C14 52 32 46 40 56 C48 42 70 44 72 60 C84 60 86 78 74 84 Z"/>',
        '<path d="M30 94 L26 106"/>',
        '<path d="M48 92 L44 104"/>',
        '<path d="M64 96 L60 108"/>',
    ]
    return items


def ico_drivetrain_128():
    items = [
        '<path d="M35 36 H55"/>',
        '<path d="M73 36 H93"/>',
        '<path d="M35 94 H55"/>',
        '<path d="M73 94 H93"/>',
        '<circle cx="64" cy="36" r="9"/>',
        '<circle cx="64" cy="94" r="9"/>',
        '<circle cx="26" cy="36" r="9"/>',
        '<circle cx="26" cy="36" r="3.6"/>',
        '<circle cx="102" cy="36" r="9"/>',
        '<circle cx="102" cy="36" r="3.6"/>',
        '<circle cx="26" cy="94" r="9"/>',
        '<circle cx="26" cy="94" r="3.6"/>',
        '<circle cx="102" cy="94" r="9"/>',
        '<circle cx="102" cy="94" r="3.6"/>',
        '<path d="M64 45 V55"/>',
        '<path d="M64 75 V85"/>',
        '<rect x="54" y="55" width="20" height="20" rx="4"/>',
        '<path d="M64 60 V70"/>',
    ]
    return items


def ico_suspension_128():
    return [
        '<circle cx="64" cy="20" r="7"/>',
        '<path d="M64 27 V44"/>',
        '<rect x="55" y="44" width="18" height="50" rx="6"/>',
        '<path d="M44 48 A20 7 0 0 0 84 48"/>',
        '<path d="M44 56 A20 7 0 0 0 84 56"/>',
        '<path d="M44 64 A20 7 0 0 0 84 64"/>',
        '<path d="M44 72 A20 7 0 0 0 84 72"/>',
        '<path d="M44 80 A20 7 0 0 0 84 80"/>',
        '<circle cx="64" cy="100" r="7"/>',
        '<path d="M30 112 L64 100 L98 112"/>',
        '<path d="M24 112 H104"/>',
    ]


# --------------------------------------------------------------------------- registry
def build_all():
    assets = {}

    assets["pad_throttle.svg"] = build_pad(
        "pad_throttle", 256, AMBER, ico_throttle(), icon_scale=1.00, seed=23, accent_glow=0.075)
    assets["pad_brake.svg"] = build_pad(
        "pad_brake", 256, BRAKE, ico_brake(), icon_scale=1.00, seed=29, accent_op=0.90, accent_glow=0.06)
    assets["pad_clutch.svg"] = build_pad(
        "pad_clutch", 256, GUNMETAL, ico_clutch(), icon_scale=0.95, teal=True, seed=37,
        accent_op=0.95, accent_glow=0.05)
    assets["pad_handbrake.svg"] = build_square_pad(
        "pad_handbrake", 200, BRAKE, ico_handbrake(), icon_scale=0.95, seed=31)
    assets["pad_recover.svg"] = build_pad(
        "pad_recover", 160, AMBER, ico_winch(), icon_scale=0.95, seed=43,
        accent_op=0.55, accent_glow=0.045)
    assets["pad_start.svg"] = build_pad(
        "pad_start", 160, AMBER, ico_start(), icon_scale=0.60, seed=47,
        accent_op=0.98, accent_glow=0.10, start_ring=True)
    assets["pad_pressed.svg"] = build_pressed()

    assets["pedal_throttle.svg"] = build_pedal(
        "pedal_throttle", 240, 460, "amber",
        dict(y0=48, y1=306, hw0=72, hw1=92, inlay=(84, 100), ribs=9, rib_h=13,
             rib_y0=112, rib_y1=294), seed=41)
    assets["pedal_brake.svg"] = build_pedal(
        "pedal_brake", 240, 460, "red",
        dict(y0=44, y1=318, hw0=86, hw1=104, inlay=(80, 98), ribs=7, rib_h=16,
             rib_y0=112, rib_y1=308), seed=43)
    assets["pedal_clutch.svg"] = build_pedal(
        "pedal_clutch", 200, 400, "gunmetal",
        dict(y0=44, y1=274, hw0=58, hw1=72, inlay=(78, 92), ribs=8, rib_h=12,
             rib_y0=104, rib_y1=268), teal=True, seed=47)

    assets["slider_rail.svg"] = build_slider_rail()
    assets["slider_knob.svg"] = build_slider_knob()
    assets["gate_panel.svg"] = build_gate_panel()
    assets["gate_knob.svg"] = build_gate_knob()
    assets["frame_plate.svg"] = build_frame_plate()

    assets["icon_winch.svg"] = build_icon("icon_winch", ico_winch_128())
    assets["icon_gear.svg"] = build_icon("icon_gear", ico_gear_128())
    assets["icon_weather.svg"] = build_icon("icon_weather", ico_weather_128())
    assets["icon_drivetrain.svg"] = build_icon("icon_drivetrain", ico_drivetrain_128())
    assets["icon_suspension2.svg"] = build_icon("icon_suspension2", ico_suspension_128())
    return assets


# --------------------------------------------------------------------------- checks
FORBIDDEN = ("<filter", "<fe", "<image", "<text", "<tspan", "font-family",
             "@font-face", "xlink:href", "mix-blend-mode", "<pattern", "<mask")


def validate(path: str, w: int, h: int) -> tuple[bool, str]:
    size = os.path.getsize(path)
    if size > 300_000:
        return False, f"too large ({size} bytes)"
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        return False, f"xml error: {exc}"
    if root.get("width") != str(w) or root.get("height") != str(h):
        return False, f"bad size attrs {root.get('width')}x{root.get('height')}"
    if root.get("viewBox") != f"0 0 {w} {h}":
        return False, f"bad viewBox {root.get('viewBox')}"
    for token in FORBIDDEN:
        if token in text:
            return False, f"forbidden token {token!r}"
    if text.count("http") != 1:
        return False, "external reference detected"
    if "<rect" not in text and "<path" not in text and "<circle" not in text:
        return False, "empty artwork"
    return True, ""


def main(argv) -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    assets = build_all()

    expected = {
        "pad_throttle.svg": (256, 256), "pad_brake.svg": (256, 256),
        "pad_clutch.svg": (256, 256), "pad_handbrake.svg": (200, 200),
        "pad_recover.svg": (160, 160), "pad_start.svg": (160, 160),
        "pad_pressed.svg": (256, 256), "pedal_throttle.svg": (240, 460),
        "pedal_brake.svg": (240, 460), "pedal_clutch.svg": (200, 400),
        "slider_rail.svg": (120, 460), "slider_knob.svg": (168, 120),
        "gate_panel.svg": (760, 560), "gate_knob.svg": (140, 140),
        "frame_plate.svg": (320, 320), "icon_winch.svg": (128, 128),
        "icon_gear.svg": (128, 128), "icon_weather.svg": (128, 128),
        "icon_drivetrain.svg": (128, 128), "icon_suspension2.svg": (128, 128),
    }

    missing = [k for k in expected if k not in assets]
    extra = [k for k in assets if k not in expected]
    if missing or extra:
        print("registry mismatch", missing, extra)
        return 2

    failures = 0
    rows = []
    for name, (w, h) in expected.items():
        path = os.path.join(OUT_DIR, name)
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(assets[name].render())
        ok, why = validate(path, w, h)
        if not ok:
            failures += 1
            rows.append((name, f"{w}x{h}", os.path.getsize(path), "FAIL " + why))
        else:
            rows.append((name, f"{w}x{h}", os.path.getsize(path), "ok"))

    print(f"MUDRO control skins -> {os.path.relpath(OUT_DIR, ROOT)}")
    print(f"{'file':<26}{'size':>10}{'bytes':>10}  status")
    for name, dims, size, status in rows:
        print(f"{name:<26}{dims:>10}{size:>10}  {status}")

    print()
    print("H-pattern slot nodes (normalized / pixels):")
    for ny, label in ((0.28, "top"), (0.50, "neutral"), (0.72, "bottom")):
        cells = []
        for nx in (0.20, 0.50, 0.80):
            cells.append(f"({nx:.2f},{ny:.2f})={nx * GATE_W:.1f},{ny * GATE_H:.1f}")
        print(f"  {label:<8} " + "  ".join(cells))

    # optional previews: only when cairosvg is already present, never installed
    previews = 0
    if "--previews" in argv:
        try:
            import cairosvg  # noqa: F401
        except Exception:
            print("\npreviews skipped: cairosvg not installed (nothing installed, as required)")
        else:
            pdir = os.path.join(ROOT, "local-builds", "previews", "controls")
            os.makedirs(pdir, exist_ok=True)
            for name in expected:
                import cairosvg as _c
                _c.svg2png(url=os.path.join(OUT_DIR, name),
                           write_to=os.path.join(pdir, name.replace(".svg", ".png")),
                           output_width=expected[name][0] * 2,
                           output_height=expected[name][1] * 2)
                previews += 1
            print(f"\npreviews written: {previews} -> {os.path.relpath(pdir, ROOT)}")

    print(f"\n{len(expected) - failures}/{len(expected)} files valid")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
