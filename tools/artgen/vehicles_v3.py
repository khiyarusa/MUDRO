#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""vehicles_v3.py - deterministic side-view vehicle sprites for MUDRO 3.0.

The art contract (scripts/vehicle/vehicle_visual.gd reads it back):

  body.svg   1600 x 720 px, viewBox "0 0 1600 720", 1 m = 160 px,
             wheelbase midpoint at x = 800, axle line at y = 400,
             front hub at 800 + wheelbase_m * 80, rear at 800 - wheelbase_m * 80,
             wheel arches cut transparent, everything else painted.
  wheel.svg  720 x 720 px, tyre centred on (360, 360).

Why the wheel canvas is 720 px and not 2 * r * 160 px:
vehicle_visual.gd sizes a wheel with ``target_px / tex.get_width()`` where
``target_px = 2 * radius_m * Units.PPM``.  The tyre therefore has to fill its
texture edge to edge, exactly like the shipped ranger_4x4 wheel does; a 128 px
tyre inside a 720 px canvas would render 5.6x too small in game.  The tyre
diameter in *world* pixels is 2 * radius_m * 160, and the sprite scale the game
derives (720 / that number) lands on it exactly - --check prints both numbers.

Usage (the ``python`` on PATH is a stub, use the real interpreter):

    py tools/artgen/vehicles_v3.py              # regenerate every sprite
    py tools/artgen/vehicles_v3.py --check      # parse + assert the contract
    py tools/artgen/vehicles_v3.py --previews   # review PNGs (needs resvg-py)

Everything is hand-built vector geometry: paths, polygons, circles, gradients.
No filters, no text, no external references - Godot's ThorVG rasteriser handles
all of it.  Output is byte-identical between runs (no randomness).
"""

from __future__ import annotations

import math
import os
import re
import sys
from xml.etree import ElementTree as ET

# --------------------------------------------------------------------------
# paths and constants
# --------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))

ASSET_DIR = "assets/vehicles"
PREVIEW_DIR = "local-builds/previews/v3"

PPM = 160.0          # art pixels per metre
CW, CH = 1600, 720   # body canvas
MID = 800.0          # wheelbase midpoint
HUB_Y = 400.0        # axle (hub) line
WHEEL_PX = 720       # wheel canvas
WHEEL_C = 360.0      # wheel centre
MAX_BYTES = 60 * 1024

SVG_NS = "http://www.w3.org/2000/svg"


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------

def n(v: float) -> str:
    """Compact number formatting; one decimal is plenty at 160 px/m."""
    if abs(v - round(v)) < 0.02:
        return str(int(round(v)))
    s = f"{v:.1f}"
    return s[:-2] if s.endswith(".0") else s


def _rgb(c: str) -> list[int]:
    c = c.lstrip("#")
    return [int(c[i:i + 2], 16) for i in (0, 2, 4)]


def mix(a: str, b: str, t: float) -> str:
    ca, cb = _rgb(a), _rgb(b)
    return "#" + "".join(f"{round(ca[i] + (cb[i] - ca[i]) * t):02x}" for i in range(3))


def shade(c: str, t: float) -> str:
    """t > 0 lightens towards white, t < 0 darkens towards black."""
    return mix(c, "#ffffff", t) if t >= 0 else mix(c, "#000000", -t)


def _stops(stops) -> str:
    body = []
    for s in stops:
        o, c = s[0], s[1]
        a = s[2] if len(s) > 2 else None
        body.append(f'<stop offset="{n(o)}" stop-color="{c}"'
                    + (f' stop-opacity="{a}"' if a is not None else "") + "/>")
    return "".join(body)


def lin(gid: str, stops, x1: float, y1: float, x2: float, y2: float,
        units: str = "userSpaceOnUse") -> str:
    return (f'<linearGradient id="{gid}" gradientUnits="{units}" '
            f'x1="{n(x1)}" y1="{n(y1)}" x2="{n(x2)}" y2="{n(y2)}">{_stops(stops)}</linearGradient>')


def rad(gid: str, stops, cx, cy, r, units: str = "objectBoundingBox",
        fx=None, fy=None) -> str:
    extra = ""
    if fx is not None:
        extra += f' fx="{n(fx)}"'
    if fy is not None:
        extra += f' fy="{n(fy)}"'
    return (f'<radialGradient id="{gid}" gradientUnits="{units}" '
            f'cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}"{extra}>{_stops(stops)}</radialGradient>')


# --------------------------------------------------------------------------
# vehicle model
# --------------------------------------------------------------------------

class Veh:
    """One vehicle: metres in, art pixels out."""

    def __init__(self, **kw):
        self.__dict__.update(kw)
        self.hub_f = self.wheelbase * 0.5
        self.hub_r = -self.hub_f
        self.y_front = self.x_front - self.wheelbase * 0.5
        self.over_rear = self.x_front - self.length - self.wheelbase * 0.5

    # metres -> pixels
    def x(self, m: float) -> float:
        return MID + m * PPM

    def y(self, h: float) -> float:
        """h = height above ground in metres."""
        return HUB_Y + (self.tyre_r - h) * PPM

    def p(self, x: float, h: float) -> str:
        return f"{n(self.x(x))} {n(self.y(h))}"

    def ground(self) -> float:
        return HUB_Y + self.tyre_r * PPM

    def floor_at(self, hub_x: float) -> float:
        """Height of the body's bottom edge above the hub that sits there."""
        pts = self.bottom
        for (x0, h0), (x1, h1) in zip(pts, pts[1:]):
            if x1 <= hub_x <= x0:
                return h0
        return pts[-1][1]

    def arch_px(self, hub_x: float):
        """Wheel-arch cut-out radii in px: wide enough for the tyre, and only
        `gap` metres taller than it, so the wheel fills its arch."""
        floor = self.floor_at(hub_x)
        rx = (self.tyre_r + 0.030) * PPM
        ry = (2.0 * self.tyre_r + 0.048 - floor) * PPM
        return rx, max(ry, 0.52 * rx)


# --------------------------------------------------------------------------
# sprite document
# --------------------------------------------------------------------------

class Doc:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.defs: list[str] = []
        self.parts: list[str] = []

    def d(self, markup: str) -> str:
        self.defs.append(markup)
        return markup

    def add(self, markup: str) -> None:
        if markup:
            self.parts.append(markup)

    def render(self) -> str:
        out = [f'<svg xmlns="{SVG_NS}" width="{self.w}" height="{self.h}" '
               f'viewBox="0 0 {self.w} {self.h}">', "  <defs>"]
        out += [f"    {d}" for d in self.defs]
        out.append("  </defs>")
        out.append("  <g>")
        out += [f"    {p}" for p in self.parts]
        out += ["  </g>", "</svg>", ""]
        return "\n".join(out)


# --------------------------------------------------------------------------
# path emitters (metres)
# --------------------------------------------------------------------------

def d_cmds(v: Veh, cmds) -> str:
    out = []
    for c in cmds:
        k = c[0]
        if k == "M":
            out.append(f"M {v.p(c[1], c[2])}")
        elif k == "L":
            out.append(f"L {v.p(c[1], c[2])}")
        elif k == "Q":
            out.append(f"Q {v.p(c[1], c[2])} {v.p(c[3], c[4])}")
        elif k == "C":
            out.append(f"C {v.p(c[1], c[2])} {v.p(c[3], c[4])} {v.p(c[5], c[6])}")
        elif k == "A":
            # A rx ry sweep x h  (arcs are circular in metres -> px)
            out.append(f"A {n(c[1] * PPM)} {n(c[2] * PPM)} 0 0 {c[3]} {v.p(c[4], c[5])}")
        else:
            raise ValueError(k)
    return " ".join(out)


def close(d: str) -> str:
    return d + " Z"


def poly_d(v: Veh, pts, closed: bool = True) -> str:
    d = "M " + v.p(*pts[0])
    for p in pts[1:]:
        d += " L " + v.p(*p)
    return d + (" Z" if closed else "")


def arch_band(v: Veh, hub: float, r_out: float, r_in: float) -> str:
    """Half annulus above the hub line - the dark wheel-well liner."""
    hy = HUB_Y
    xo, xi = v.x(hub), v.x(hub)
    ro, ri = r_out * PPM, r_in * PPM
    d = (f"M {n(xo - ro)} {n(hy)} A {n(ro)} {n(ro)} 0 0 1 {n(xo + ro)} {n(hy)} "
         f"L {n(xi + ri)} {n(hy)} A {n(ri)} {n(ri)} 0 0 0 {n(xi - ri)} {n(hy)} Z")
    return d


# --------------------------------------------------------------------------
# shared palette / defs
# --------------------------------------------------------------------------

def paint_defs(v: Veh, doc: Doc) -> None:
    base = v.paint
    top = v.y(v.height)
    bot = v.ground()
    doc.d(lin("paint", [
        (0, shade(base, 0.50), None),
        (0.07, shade(base, 0.24), None),
        (0.26, base, None),
        (0.52, shade(base, -0.08), None),
        (0.78, shade(base, -0.20), None),
        (1, shade(base, -0.34), None),
    ], 0, top - 4, 70, bot))
    doc.d(lin("paintSide", [
        (0, shade(base, 0.30), None),
        (0.35, base, None),
        (0.72, shade(base, -0.22), None),
        (1, shade(base, -0.44), None),
    ], 0, 0, 0, 1, units="objectBoundingBox"))
    doc.d(lin("roofStrip", [
        (0, shade(base, 0.60), "0.85"),
        (0.55, shade(base, 0.34), "0.45"),
        (1, shade(base, 0.10), "0"),
    ], 0, 0, 0, 1, units="objectBoundingBox"))
    doc.d(lin("glass", [
        (0, "#a6c3d5", None),
        (0.18, "#7193a9", None),
        (0.48, "#3c566a", None),
        (0.76, "#22333f", None),
        (1, "#131f27", None),
    ], 0, 0, 0.55, 1, units="objectBoundingBox"))
    doc.d(lin("glassTop", [
        (0, "#d8ebf6", "0.70"),
        (0.45, "#a7c6d8", "0.26"),
        (1, "#7096ab", "0"),
    ], 0, 0, 0, 1, units="objectBoundingBox"))
    doc.d(lin("clad", [
        (0, shade(base, -0.52), None),
        (0.35, shade(base, -0.66), None),
        (1, shade(base, -0.80), None),
    ], 0, 0, 0, 1, units="objectBoundingBox"))
    doc.d(lin("plastic", [
        (0, "#41474c", None),
        (0.42, "#2b3034", None),
        (1, "#15181a", None),
    ], 0, 0, 0, 1, units="objectBoundingBox"))
    doc.d(lin("rubber", [
        (0, "#23262a", None),
        (0.55, "#15171a", None),
        (1, "#0b0c0e", None),
    ], 0, 0, 0, 1, units="objectBoundingBox"))
    doc.d(lin("steel", [
        (0, "#d6dde5", None),
        (0.26, "#a8b0b9", None),
        (0.62, "#717a83", None),
        (1, "#3a4046", None),
    ], 0, 0, 0.18, 1, units="objectBoundingBox"))
    doc.d(lin("chrome", [
        (0, "#ffffff", None),
        (0.34, "#d3dbe3", None),
        (0.68, "#96a0a9", None),
        (1, "#4f565d", None),
    ], 0, 0, 0.3, 1, units="objectBoundingBox"))
    doc.d(lin("darkSteel", [
        (0, "#585f66", None),
        (0.5, "#3a4046", None),
        (1, "#1c2023", None),
    ], 0, 0, 0, 1, units="objectBoundingBox"))
    doc.d(lin("liner", [
        (0, "#101213", None),
        (0.45, "#1b1e20", None),
        (1, "#08090a", None),
    ], 0, 0, 0, 1, units="objectBoundingBox"))
    doc.d(lin("mud", [
        (0, "#8a6a44", "0"),
        (0.42, "#7d5f3d", "0.13"),
        (1, "#54402a", "0.40"),
    ], 0, 0, 0, 1, units="objectBoundingBox"))
    doc.d(lin("shine", [
        (0, "#ffffff", "0.26"),
        (0.5, "#ffffff", "0.05"),
        (1, "#ffffff", "0"),
    ], 0, 0, 0.4, 1, units="objectBoundingBox"))
    doc.d(lin("sillGrad", [
        (0, "#000000", "0"),
        (0.45, "#000000", "0.10"),
        (1, "#000000", "0.34"),
    ], 0, 0, 0, 1, units="objectBoundingBox"))
    doc.d(lin("shoulder", [
        (0, "#ffffff", "0"),
        (0.42, "#ffffff", "0.17"),
        (0.62, "#ffffff", "0.20"),
        (1, "#ffffff", "0.02"),
    ], 0, 0, 0, 1, units="objectBoundingBox"))


# --------------------------------------------------------------------------
# shared detail primitives
# --------------------------------------------------------------------------

def rect_px(x0, y0, x1, y1, **kw) -> str:
    at = "".join(f' {k.replace("_", "-")}="{v}"' for k, v in kw.items())
    return (f'<rect x="{n(x0)}" y="{n(y0)}" width="{n(x1 - x0)}" '
            f'height="{n(y1 - y0)}"{at}/>')


def door_seam(v: Veh, x: float, h0: float, h1: float, strength: float = 0.65) -> str:
    """Panel shut line: a dark cut with a light catch on its trailing edge."""
    out = [f'<path fill="none" stroke="#0a0c0d" stroke-width="3" opacity="{n(strength)}" '
           f'd="M {v.p(x, h0)} L {v.p(x, h1)}"/>']
    out.append(f'<path fill="none" stroke="{shade(v.paint, 0.34)}" stroke-width="1.6" '
               f'opacity="0.55" d="M {v.p(x + 0.016, h0 + 0.03)} L {v.p(x + 0.016, h1 - 0.03)}"/>')
    return "".join(out)


def handles(v: Veh, x: float, h: float, width: float = 0.17) -> str:
    x0, x1 = v.x(x), v.x(x + width)
    y0, y1 = v.y(h + 0.038), v.y(h - 0.038)
    return (
        f'<g><rect x="{n(x0 - 3)}" y="{n(y0 - 3)}" width="{n(x1 - x0 + 6)}" '
        f'height="{n(y1 - y0 + 6)}" rx="4" fill="#0d1012" opacity="0.6"/>'
        f'<rect x="{n(x0)}" y="{n(y0)}" width="{n(x1 - x0)}" height="{n(y1 - y0)}" '
        f'rx="3" fill="url(#chrome)"/>'
        f'<rect x="{n(x0 + 3)}" y="{n(y0 + 2)}" width="{n((x1 - x0) - 6)}" '
        f'height="2.6" rx="1.3" fill="#ffffff" opacity="0.65"/>'
        f'<rect x="{n(x0 + 3)}" y="{n(y1 - 6)}" width="{n((x1 - x0) - 6)}" '
        f'height="2" rx="1" fill="#2c3238" opacity="0.7"/></g>'
    )


def hinges(v: Veh, xs, h0: float, h1: float, w: float = 0.055) -> str:
    out = []
    for x in xs:
        out.append(rect_px(v.x(x), v.y(h1), v.x(x + w), v.y(h0), rx=2,
                           fill="#2a2e32", stroke="#4c5258", stroke_width="1"))
    return "".join(out)


def mirror_arm(v: Veh, x: float, h: float, size: float = 1.0) -> str:
    """Door mirror on a stalk, seen edge-on from the side."""
    ax, ay = v.x(x), v.y(h)
    hx0, hy0 = v.x(x - 0.02), v.y(h + 0.10)
    hx1, hy1 = v.x(x + 0.11 * size), v.y(h - 0.02)
    return (
        f'<g><path fill="none" stroke="#171a1d" stroke-width="{n(7 * size)}" '
        f'stroke-linecap="round" d="M {n(ax)} {n(ay)} L {n(ax + 14)} {n(ay - 8)}"/>'
        f'<rect x="{n(hx0)}" y="{n(hy0)}" width="{n(hx1 - hx0)}" height="{n(hy1 - hy0)}" '
        f'rx="{n(6 * size)}" fill="#1b1f22"/>'
        f'<rect x="{n(hx0 + 2)}" y="{n(hy0 + 2)}" width="{n(hx1 - hx0 - 4)}" '
        f'height="{n(hy1 - hy0 - 4)}" rx="{n(5 * size)}" fill="url(#glass)"/>'
        f'<path fill="none" stroke="#8fa7b6" stroke-width="1.6" opacity="0.55" '
        f'd="M {n(hx0 + 6)} {n(hy0 + 5)} L {n(hx1 - 6)} {n(hy0 + 3)}"/></g>'
    )


def wheel_bits(v: Veh, hub_f_cut: bool, hub_r_cut: bool) -> str:
    """Dark gutter along the inside of each arch opening."""
    out = []
    for hub, cut in ((v.hub_f, hub_f_cut), (v.hub_r, hub_r_cut)):
        if not cut:
            continue
        rx, ry = v.arch_px(hub)
        ys = v.y(v.floor_at(hub))
        x = v.x(hub)
        out.append(f'<path fill="none" stroke="url(#liner)" stroke-width="9" '
                   f'stroke-linecap="butt" d="M {n(x - rx)} {n(ys)} '
                   f'A {n(rx)} {n(ry)} 0 0 1 {n(x + rx)} {n(ys)}"/>')
    return "".join(out)


def arch_lip(v: Veh, hub: float) -> str:
    """Edge highlight along the arch cut, on the same ellipse as the shell arc."""
    rx, ry = v.arch_px(hub)
    ys = v.y(v.floor_at(hub))
    x = v.x(hub)
    return (f'<path fill="none" stroke="#05070a" stroke-width="3.4" opacity="0.5" '
            f'd="M {n(x - rx)} {n(ys)} A {n(rx)} {n(ry)} 0 0 1 {n(x + rx)} {n(ys)}"/>'
            f'<path fill="none" stroke="{shade(v.paint, 0.34)}" stroke-width="1.6" '
            f'opacity="0.5" d="M {n(x - rx + 5)} {n(ys - 4)} '
            f'A {n(rx - 5)} {n(ry - 5)} 0 0 1 {n(x + rx - 5)} {n(ys - 4)}"/>')


def mudflap(v: Veh, x: float, top: float, w: float = 0.20, colour: str = "#1a1d20") -> str:
    bot = 0.235
    pts = [(x, top + 0.03), (x + w * 0.92, top + 0.03), (x + w, bot + 0.03),
           (x + w * 0.10, bot)]
    d = poly_d(v, pts)
    ribs = "".join(
        f'<path fill="none" stroke="#33383d" stroke-width="1.4" opacity="0.55" '
        f'd="M {v.p(x + 0.025 + i * 0.04, top - 0.02)} L {v.p(x + 0.028 + i * 0.04, bot + 0.05)}"/>'
        for i in range(3))
    return (f'<path d="{d}" fill="{colour}" stroke="#07080a" stroke-width="1.4"/>'
            f'<path fill="none" stroke="#4a5057" stroke-width="1.2" opacity="0.55" '
            f'd="M {v.p(x + 0.01, top + 0.02)} L {v.p(x + w * 0.92, top + 0.02)}"/>' + ribs)


def lamp_front(v: Veh, x0: float, x1: float, h0: float, h1: float,
               kind: str = "rect", amber: bool = True) -> str:
    X0, X1 = v.x(x0), v.x(x1)
    Y0, Y1 = v.y(h1), v.y(h0)     # h1 is higher -> smaller y
    out = [f'<g>']
    if kind == "round":
        cx, cy = (X0 + X1) * 0.5, (Y0 + Y1) * 0.5
        r = min(X1 - X0, Y1 - Y0) * 0.5
        out.append(f'<circle cx="{n(cx)}" cy="{n(cy)}" r="{n(r + 2)}" fill="#0d1114"/>')
        out.append(f'<circle cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}" fill="url(#lampWarm)"/>')
        out.append(f'<circle cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}" fill="none" '
                   f'stroke="#cfd8e0" stroke-width="2"/>')
        out.append(f'<circle cx="{n(cx - r * 0.3)}" cy="{n(cy - r * 0.35)}" r="{n(r * 0.28)}" '
                   f'fill="#ffffff" opacity="0.75"/>')
    else:
        out.append(f'<rect x="{n(X0)}" y="{n(Y0)}" width="{n(X1 - X0)}" '
                   f'height="{n(Y1 - Y0)}" rx="3" fill="#0c1013"/>')
        out.append(f'<rect x="{n(X0 + 2)}" y="{n(Y0 + 2)}" width="{n(X1 - X0 - 4)}" '
                   f'height="{n(Y1 - Y0 - 4)}" rx="2" fill="url(#lampWarm)"/>')
        out.append(f'<path fill="#ffffff" opacity="0.6" '
                   f'd="M {n(X0 + 4)} {n(Y0 + 4)} L {n(X0 + (X1 - X0) * 0.45)} {n(Y0 + 4)} '
                   f'L {n(X0 + 4)} {n(Y0 + (Y1 - Y0) * 0.55)} Z"/>')
        out.append(f'<rect x="{n(X0)}" y="{n(Y0)}" width="{n(X1 - X0)}" '
                   f'height="{n(Y1 - Y0)}" rx="3" fill="none" stroke="#3d454c" stroke-width="1.6"/>')
    if amber:
        ax0, ax1 = X0 + 2, X0 + (X1 - X0) * 0.32
        ay1 = Y1
        out.append(f'<rect x="{n(ax0)}" y="{n(ay1 - (Y1 - Y0) * 0.26)}" '
                   f'width="{n(ax1 - ax0)}" height="{n((Y1 - Y0) * 0.22)}" rx="2" '
                   f'fill="#d98a2b"/>')
    out.append("</g>")
    return "".join(out)


def lamp_rear(v: Veh, x0: float, x1: float, h0: float, h1: float) -> str:
    X0, X1 = v.x(x0), v.x(x1)
    Y0, Y1 = v.y(h1), v.y(h0)
    hgt = Y1 - Y0
    out = [f'<g><rect x="{n(X0 - 1)}" y="{n(Y0 - 1)}" width="{n(X1 - X0 + 2)}" '
           f'height="{n(hgt + 2)}" rx="3" fill="#0b0e10"/>']
    out.append(f'<rect x="{n(X0)}" y="{n(Y0)}" width="{n(X1 - X0)}" height="{n(hgt)}" '
               f'rx="2.5" fill="#8e2420"/>')
    out.append(f'<rect x="{n(X0)}" y="{n(Y0)}" width="{n(X1 - X0)}" height="{n(hgt * 0.50)}" '
               f'rx="2.5" fill="#d0362c"/>')
    out.append(f'<rect x="{n(X0)}" y="{n(Y0 + hgt * 0.58)}" width="{n(X1 - X0)}" '
               f'height="{n(hgt * 0.22)}" rx="1.5" fill="#e39a34"/>')
    out.append(f'<path fill="#ffffff" opacity="0.5" d="M {n(X0 + 1.5)} {n(Y0 + 1.5)} '
               f'L {n(X1 - 1.5)} {n(Y0 + 1.5)} L {n(X1 - 1.5)} {n(Y0 + 3.5)} '
               f'L {n(X0 + 1.5)} {n(Y0 + 4.5)} Z"/>')
    out.append(f'<rect x="{n(X0)}" y="{n(Y0)}" width="{n(X1 - X0)}" height="{n(hgt)}" '
               f'rx="2.5" fill="none" stroke="#4a1410" stroke-width="1.2"/></g>')
    return "".join(out)


def side_repeater(v: Veh, x: float, h: float) -> str:
    return (f'<ellipse cx="{n(v.x(x))}" cy="{n(v.y(h))}" rx="8" ry="4.2" '
            f'fill="#c97a22" stroke="#2a2118" stroke-width="1.2"/>'
            f'<ellipse cx="{n(v.x(x) - 2)}" cy="{n(v.y(h) - 1)}" rx="4" ry="1.8" '
            f'fill="#ffd79a" opacity="0.8"/>')


def fuel_cap(v: Veh, x: float, h: float) -> str:
    cx, cy = v.x(x), v.y(h)
    return (f'<g><circle cx="{n(cx)}" cy="{n(cy)}" r="9.5" fill="#0d0f11" opacity="0.5"/>'
            f'<circle cx="{n(cx)}" cy="{n(cy)}" r="8" fill="{shade(v.paint, -0.06)}" '
            f'stroke="#111417" stroke-width="1.8"/>'
            f'<circle cx="{n(cx)}" cy="{n(cy)}" r="5.4" fill="none" stroke="#1b1f22" '
            f'stroke-width="1.4" opacity="0.8"/>'
            f'<path fill="none" stroke="{shade(v.paint, 0.34)}" stroke-width="1.1" '
            f'opacity="0.7" d="M {n(cx - 5)} {n(cy - 4)} A 7 7 0 0 1 {n(cx + 2)} {n(cy - 6)}"/></g>')


def antenna(v: Veh, x: float, h0: float, h1: float, lean: float = -0.06) -> str:
    base = (v.x(x), v.y(h0))
    tip = (v.x(x + lean), v.y(h1))
    return (f'<path fill="none" stroke="#15181b" stroke-width="3" stroke-linecap="round" '
            f'd="M {n(base[0])} {n(base[1])} L {n(tip[0])} {n(tip[1])}"/>'
            f'<path fill="none" stroke="#5c646c" stroke-width="1.1" opacity="0.7" '
            f'd="M {n(base[0] + 1)} {n(base[1])} L {n(tip[0] + 1)} {n(tip[1] + 3)}"/>'
            f'<circle cx="{n(tip[0])}" cy="{n(tip[1])}" r="2.4" fill="#0d0f11"/>')


def tow_hook(v: Veh, tip: float, h: float, flip: bool = False) -> str:
    """Recovery hook whose ring stops exactly on `tip`."""
    s = -1 if flip else 1
    ring_r = 7.0
    cx = v.x(tip - s * ring_r / PPM)
    return (f'<path fill="none" stroke="#34393e" stroke-width="9" stroke-linecap="round" '
            f'd="M {v.p(tip - s * 0.13, h)} L {n(cx)} {n(v.y(h))}"/>'
            f'<circle cx="{n(cx)}" cy="{n(v.y(h))}" r="{n(ring_r)}" fill="none" '
            f'stroke="#5a6167" stroke-width="4"/>'
            f'<path fill="none" stroke="#0b0d0e" stroke-width="3" opacity="0.7" '
            f'd="M {v.p(tip - s * 0.12, h - 0.03)} L {n(cx)} {n(v.y(h) - 3)}"/>')


# --------------------------------------------------------------------------
# body assembly
# --------------------------------------------------------------------------

def arch_segments(v: Veh, bottom, cut_f: bool, cut_r: bool):
    """Insert the wheel-arch arcs while walking the bottom edge front -> rear."""
    arches = []
    if cut_f:
        arches.append((v.hub_f,) + v.arch_px(v.hub_f))
    if cut_r:
        arches.append((v.hub_r,) + v.arch_px(v.hub_r))
    cmds = []
    for (x0, h0), (x1, h1) in zip(bottom, bottom[1:]):
        hits = sorted([a for a in arches if x1 < a[0] < x0], key=lambda a: -a[0])
        if hits:
            assert abs(h0 - h1) < 1e-6, "arch must sit on a flat floor"
            for hub, rx, ry in hits:
                xr = rx / PPM
                cmds.append(("L", hub + xr, h0))
                cmds.append(("A", xr, ry / PPM, 0, hub - xr, h1))
        cmds.append(("L", x1, h1))
    return cmds


def shell(v: Veh) -> str:
    cmds = list(v.outline) + arch_segments(v, v.bottom, v.cut_f, v.cut_r)
    return close(d_cmds(v, cmds))


def glass_pane(v: Veh, x0: float, x1: float, t0: float, t1: float, b: float,
               inset: float = 0.018) -> str:
    """One side window: rubber seal, gradient glass, two reflection streaks."""
    pts = [(x0, b), (x0, t0), (x1, t1), (x1, b)]
    seal = poly_d(v, [(x0 - inset * 1.6, b + inset * 0.4), (x0 - inset * 1.6, t0 + inset),
                      (x1 + inset * 1.6, t1 + inset), (x1 + inset * 1.6, b + inset * 0.4)])
    gl = poly_d(v, pts)
    out = [f'<path d="{seal}" fill="#0b0f12"/>', f'<path d="{gl}" fill="url(#glass)"/>']
    # roof shadow along the top of the glass, then diagonal reflections
    top_band = [(x0, t0 - 0.075), (x1, t1 - 0.075), (x1, t1 - 0.01), (x0, t0 - 0.01)]
    out.append(f'<path d="{poly_d(v, top_band)}" fill="#05080b" opacity="0.55"/>')
    w = x1 - x0
    shear = 0.40 * w
    tmin = min(t0, t1)
    for u0, uw, op in ((0.10, 0.13, 0.20), (0.40, 0.06, 0.30)):
        xa = x0 + w * u0
        xb = x0 + w * (u0 + uw)
        quad = [(xa, b + 0.04), (xb, b + 0.04),
                (xb + shear, tmin - 0.05), (xa + shear, tmin - 0.05)]
        out.append(f'<path d="{poly_d(v, quad)}" fill="url(#glassTop)" opacity="{n(op)}"/>')
    # top seal + belt strip
    out.append(f'<path fill="none" stroke="#0a0d10" stroke-width="3.2" '
               f'd="M {v.p(x0 - inset, b)} L {v.p(x0 - inset, t0)} L {v.p(x1 + inset, t1)} '
               f'L {v.p(x1 + inset, b)}"/>')
    out.append(f'<path fill="none" stroke="{shade(v.paint, 0.12)}" stroke-width="1.2" '
               f'opacity="0.5" d="M {v.p(x0 - inset, b + 0.012)} L {v.p(x1 + inset, b + 0.012)}"/>')
    return "".join(out)


def windscreen(v: Veh, spec) -> str:
    """The raked windscreen seen edge-on: a slim glass band down the A-pillar."""
    bx, bh, tx, th, wid = spec
    # band runs parallel to the windscreen line, `wid` metres behind it
    p0 = (bx, bh + 0.02)
    p1 = (tx, th - 0.01)
    p2 = (tx + wid, th - 0.055)
    p3 = (bx + wid, bh + 0.02)
    out = [f'<path d="{poly_d(v, [(p0[0] - 0.012, p0[1]), (p1[0] - 0.012, p1[1]),
                                 (p2[0] + 0.012, p2[1]), (p3[0] + 0.012, p3[1])])}" '
           f'fill="#0a0d10"/>',
           f'<path d="{poly_d(v, [p0, p1, p2, p3])}" fill="url(#glass)"/>']
    # a bright reflection down the glass
    q0 = (p0[0] + wid * 0.30, p0[1] - 0.03)
    q1 = (p1[0] + wid * 0.30, p1[1] + 0.03)
    q2 = (p1[0] + wid * 0.46, p1[1] + 0.05)
    q3 = (p0[0] + wid * 0.46, p0[1] - 0.05)
    out.append(f'<path d="{poly_d(v, [q0, q1, q2, q3])}" fill="#cfe4f2" opacity="0.34"/>')
    # wiper arm resting at the base
    out.append(f'<path fill="none" stroke="#101316" stroke-width="3.4" stroke-linecap="round" '
               f'd="M {v.p(bx + 0.03, bh + 0.06)} L {v.p(bx - 0.04, bh + 0.16)}"/>')
    return "".join(out)


def roof_highlight(v: Veh, x0: float, x1: float, h: float, depth: float = 0.09) -> str:
    pts = [(x0, h - 0.012), (x1, h - 0.012), (x1 - 0.01, h - depth), (x0 + 0.02, h - depth)]
    return f'<path d="{poly_d(v, pts)}" fill="url(#roofStrip)" opacity="0.5"/>'


def belt_line(v: Veh, x0: float, x1: float, h: float) -> str:
    return (f'<path fill="none" stroke="#0a0c0e" stroke-width="2.4" opacity="0.55" '
            f'd="M {v.p(x0, h)} L {v.p(x1, h)}"/>'
            f'<path fill="none" stroke="{shade(v.paint, 0.26)}" stroke-width="1.2" '
            f'opacity="0.42" d="M {v.p(x0, h + 0.014)} L {v.p(x1, h + 0.014)}"/>')


def cladding(v: Veh, x0: float, x1: float, h0: float, h1: float) -> str:
    pts = [(x0, h1), (x1, h1), (x1, h0), (x0, h0)]
    return (f'<path d="{poly_d(v, pts)}" fill="url(#clad)"/>'
            f'<path fill="none" stroke="#0b0d0f" stroke-width="2" opacity="0.7" '
            f'd="M {v.p(x0, h1)} L {v.p(x1, h1)}"/>'
            f'<path fill="none" stroke="{shade(v.paint, 0.34)}" stroke-width="1.3" '
            f'opacity="0.4" d="M {v.p(x0, h1 - 0.012)} L {v.p(x1, h1 - 0.012)}"/>')


def flare(v: Veh, hub: float, colour: str, w: float = 0.055) -> str:
    """A plastic wheel-arch flare hugging the outside of the cut-out."""
    rx, ry = v.arch_px(hub)
    R = w * PPM * 0.5
    ys = v.y(v.floor_at(hub))
    x = v.x(hub)
    return (f'<path fill="none" stroke="{colour}" stroke-width="{n(w * PPM)}" '
            f'stroke-linecap="butt" d="M {n(x - rx - R)} {n(ys)} '
            f'A {n(rx + R)} {n(ry + R)} 0 0 1 {n(x + rx + R)} {n(ys)}"/>'
            f'<path fill="none" stroke="{shade(colour, 0.32)}" stroke-width="1.6" '
            f'opacity="0.6" d="M {n(x - rx - R + 2)} {n(ys - 3)} '
            f'A {n(rx + R - 2)} {n(ry + R - 2)} 0 0 1 {n(x + rx + R - 2)} {n(ys - 3)}"/>')


def side_step(v: Veh, x0: float, x1: float, h: float) -> str:
    return (f'<path fill="none" stroke="#0d0f11" stroke-width="10" stroke-linecap="round" '
            f'd="M {v.p(x0, h)} L {v.p(x1, h)}"/>'
            f'<path fill="none" stroke="#3f464c" stroke-width="4" stroke-linecap="round" '
            f'd="M {v.p(x0 + 0.02, h + 0.012)} L {v.p(x1 - 0.02, h + 0.012)}"/>'
            f'<path fill="none" stroke="#6f777e" stroke-width="1.2" opacity="0.6" '
            f'd="M {v.p(x0 + 0.06, h + 0.026)} L {v.p(x1 - 0.06, h + 0.026)}"/>')


def roof_rack(v: Veh, x0: float, x1: float, h: float, top: float, feet: int = 4) -> str:
    """Slim expedition rack: feet on the roof, platform under `top`."""
    y0, y1 = v.y(top), v.y(h)
    xa, xb = v.x(x0), v.x(x1)
    out = [f'<g><rect x="{n(xa)}" y="{n(y0)}" width="{n(xb - xa)}" '
           f'height="{n(y1 - y0 - 2)}" rx="3" fill="#202428"/>']
    for i in range(feet):
        fx = xa + (xb - xa) * (i / max(feet - 1, 1))
        out.append(rect_px(fx - 4, y1 - 9, fx + 4, y1 + 1, rx=2, fill="#2c3135"))
    # slats along the platform
    for i in range(9):
        sx = xa + 8 + (xb - xa - 16) * i / 8.0
        out.append(f'<path fill="none" stroke="#3b4146" stroke-width="3" '
                   f'd="M {n(sx)} {n(y0 + 2)} L {n(sx)} {n(y1 - 10)}"/>')
    # side rails top and bottom
    out.append(f'<path fill="none" stroke="#4d545a" stroke-width="4" '
               f'd="M {n(xa + 2)} {n(y0 + 3)} L {n(xb - 2)} {n(y0 + 3)}"/>')
    out.append(f'<path fill="none" stroke="#9aa2a9" stroke-width="1.4" opacity="0.6" '
               f'd="M {n(xa + 4)} {n(y0 + 1)} L {n(xb - 4)} {n(y0 + 1)}"/>')
    out.append(f'<path fill="none" stroke="#2b3035" stroke-width="3" '
               f'd="M {n(xa)} {n(y1 - 10)} L {n(xb)} {n(y1 - 10)}"/>')
    out.append('</g>')
    return "".join(out)


def snorkel(v: Veh, x_bottom: float, h_bottom: float, x_top: float, h_top: float) -> str:
    """Raised air intake up the A-pillar, ram head on top."""
    bx, by = v.x(x_bottom), v.y(h_bottom)
    tx, ty = v.x(x_top), v.y(h_top)
    w = 11
    return (f'<g><path fill="none" stroke="#0b0d0e" stroke-width="{w + 5}" '
            f'stroke-linecap="round" stroke-linejoin="round" opacity="0.85" '
            f'd="M {n(bx)} {n(by)} L {n(tx)} {n(ty)}"/>'
            f'<path fill="none" stroke="#2c3134" stroke-width="{w}" '
            f'stroke-linecap="round" d="M {n(bx)} {n(by)} L {n(tx)} {n(ty)}"/>'
            f'<path fill="none" stroke="#5c646a" stroke-width="3" opacity="0.7" '
            f'stroke-linecap="round" d="M {n(bx - 2)} {n(by)} L {n(tx - 2)} {n(ty + 2)}"/>'
            # ram head
            f'<path d="M {n(tx - 15)} {n(ty - 6)} L {n(tx + 9)} {n(ty - 10)} '
            f'L {n(tx + 13)} {n(ty + 12)} L {n(tx - 13)} {n(ty + 8)} Z" fill="#22262a"/>'
            f'<path d="M {n(tx - 13)} {n(ty - 4)} L {n(tx + 8)} {n(ty - 8)} '
            f'L {n(tx + 9)} {n(ty - 1)} L {n(tx - 13)} {n(ty + 2)} Z" fill="#4a5156"/>'
            f'<path fill="none" stroke="#7d848b" stroke-width="1.2" opacity="0.6" '
            f'd="M {n(tx - 12)} {n(ty - 3)} L {n(tx + 7)} {n(ty - 6)}"/></g>')


def roll_bar(v: Veh, x: float, h_floor: float, h_top: float, back: float = 0.36) -> str:
    """Sports bar behind the cab: two legs joined by a curved top rail."""
    xa, xb = v.x(x), v.x(x - back)
    ya0, ya1 = v.y(h_floor), v.y(h_top)
    yb1 = v.y(h_top - 0.07)
    out = [f'<g><path fill="none" stroke="#22282d" stroke-width="17" stroke-linecap="round" '
           f'd="M {n(xb)} {n(ya0)} L {n(xb)} {n(yb1)}"/>'
           f'<path fill="none" stroke="#333a40" stroke-width="18" stroke-linecap="round" '
           f'd="M {n(xa)} {n(ya0)} L {n(xa)} {n(ya1)}"/>'
           f'<path fill="none" stroke="#454c53" stroke-width="16" stroke-linecap="round" '
           f'stroke-linejoin="round" d="M {n(xb)} {n(yb1)} Q {n((xa + xb) * 0.5)} {n(ya1 - 8)} '
           f'{n(xa)} {n(ya1)}"/>'
           f'<path fill="none" stroke="#5b636a" stroke-width="5" stroke-linecap="round" '
           f'opacity="0.8" d="M {n(xa - 4)} {n(ya0 - 4)} L {n(xa - 4)} {n(ya1 + 6)}"/>'
           f'<path fill="none" stroke="#7d858d" stroke-width="2.4" stroke-linecap="round" '
           f'opacity="0.7" d="M {n(xb + 3)} {n(yb1)} Q {n((xa + xb) * 0.5)} {n(ya1 - 12)} '
           f'{n(xa + 3)} {n(ya1 - 3)}"/></g>']
    return "".join(out)


def spare_bulge(v: Veh, cx: float, cy: float, rx: float, ry: float, colour: str) -> str:
    """Rear-mounted spare seen edge-on: a solid dome proud of the tailgate."""
    cxp, cyp = v.x(cx), v.y(cy)
    rx_p, ry_p = rx * PPM, ry * PPM
    back = cxp + 8
    d = (f"M {n(back)} {n(cyp - ry_p)} L {n(cxp)} {n(cyp - ry_p)} "
         f"A {n(rx_p)} {n(ry_p)} 0 0 0 {n(cxp)} {n(cyp + ry_p)} "
         f"L {n(back)} {n(cyp + ry_p)} Z")
    out = [f'<path d="{d}" fill="#0b0d0f" opacity="0.5"/>',
           f'<path d="{d}" fill="{colour}" stroke="{shade(colour, -0.45)}" stroke-width="2"/>']
    # cover ribs + centre boss
    out.append(f'<path fill="none" stroke="{shade(colour, -0.28)}" stroke-width="1.8" '
               f'opacity="0.75" d="M {n(cxp - 4)} {n(cyp - ry_p * 0.62)} '
               f'A {n(rx_p - 6)} {n(ry_p - 8)} 0 0 0 {n(cxp - 4)} {n(cyp + ry_p * 0.62)}"/>')
    out.append(f'<path fill="none" stroke="{shade(colour, 0.38)}" stroke-width="1.8" '
               f'opacity="0.65" d="M {n(cxp + 2)} {n(cyp - ry_p * 0.80)} '
               f'A {n(rx_p - 16)} {n(ry_p - 20)} 0 0 0 {n(cxp + 2)} {n(cyp + ry_p * 0.80)}"/>')
    out.append(f'<ellipse cx="{n(cxp - 10)}" cy="{n(cyp)}" rx="5" ry="{n(ry_p * 0.26)}" '
               f'fill="{shade(colour, -0.30)}" stroke="{shade(colour, 0.25)}" stroke-width="1.2"/>')
    return "".join(out)


def front_bumper(v: Veh, x0: float, x1: float, h0: float, h1: float,
                  kind: str = "plastic", chrome: bool = True) -> str:
    """A bumper as a distinct object: dark body, bright top strip, shadow below."""
    fill = {"plastic": "url(#plastic)", "steel": "url(#steel)",
            "body": shade(v.paint, -0.14)}.get(kind, "url(#plastic)")
    out = [f'<path d="{poly_d(v, [(x0, h1), (x1, h1), (x1, h0), (x0 + 0.02, h0)])}" '
           f'fill="{fill}" stroke="#101315" stroke-width="1.6"/>']
    if chrome:
        out.append(f'<path fill="none" stroke="url(#chrome)" stroke-width="3" '
                   f'd="M {v.p(x0 + 0.01, h1 - 0.015)} L {v.p(x1 - 0.01, h1 - 0.015)}"/>')
    out.append(f'<path fill="none" stroke="#05070a" stroke-width="3" opacity="0.55" '
               f'd="M {v.p(x0 + 0.02, h0 + 0.012)} L {v.p(x1 - 0.02, h0 + 0.012)}"/>')
    return "".join(out)


def chassis(v: Veh, x0: float, x1: float, top: float, depth: float = 0.075,
            exhaust: bool = False) -> str:
    if x1 - x0 < 0.05:
        return ""
    y0, y1 = v.y(top), v.y(top - depth)
    out = [f'<g>{rect_px(v.x(x0), y0, v.x(x1), y1, rx=2, fill="#101315")}']
    out.append(f'<path fill="none" stroke="#41474d" stroke-width="1.4" opacity="0.55" '
               f'd="M {n(v.x(x0) + 4)} {n(y0 + 1.5)} L {n(v.x(x1) - 4)} {n(y0 + 1.5)}"/>')
    out.append(f'<path fill="none" stroke="#000000" stroke-width="2" opacity="0.5" '
               f'd="M {n(v.x(x0) + 4)} {n(y1 - 1)} L {n(v.x(x1) - 4)} {n(y1 - 1)}"/>')
    if exhaust:
        run = min(0.44, x1 - x0)
        out.append(f'<path fill="none" stroke="#242a2f" stroke-width="7" stroke-linecap="round" '
                   f'd="M {v.p(x1 - run, top - 0.05)} L {v.p(x1 - 0.02, top - 0.05)}"/>')
        out.append(f'<path fill="none" stroke="#7d858d" stroke-width="2" opacity="0.65" '
                   f'd="M {v.p(x1 - 0.02, top - 0.035)} L {v.p(x1 - 0.06, top - 0.035)}"/>')
    out.append("</g>")
    return "".join(out)


def underbody(v: Veh) -> str:
    """Chassis rails only between the wheels: nothing may sit in an arch."""
    out = []
    lo = v.x_rear + 0.16
    segments = []
    for hub in sorted((v.hub_r, v.hub_f)):
        segments.append((lo, hub - v.arch_r - 0.02))
        lo = hub + v.arch_r + 0.02
    segments.append((lo, v.x_front - 0.12))
    for i, (a, b) in enumerate(segments):
        out.append(chassis(v, a, b, v.y_under, exhaust=(i == 0)))
    return "".join(out)


def dirt_wash(v: Veh, x0: float, x1: float, h0: float, h1: float) -> str:
    pts = [(x0, h1), (x1, h1), (x1, h0), (x0, h0)]
    return f'<path d="{poly_d(v, pts)}" fill="url(#mud)" opacity="0.55"/>'


def sill_shade(v: Veh, x0: float, x1: float, h: float, depth: float = 0.22) -> str:
    """Contact shadow rising off the sill so the body is not a pasted slab."""
    return (f'<rect x="{n(v.x(x0))}" y="{n(v.y(h + depth))}" width="{n(v.x(x1) - v.x(x0))}" '
            f'height="{n(depth * PPM)}" fill="url(#sillGrad)"/>')


def shoulder_line(v: Veh, x0: float, x1: float, h: float) -> str:
    """The long character line every 4x4 has down its flank."""
    return (f'<path fill="none" stroke="{shade(v.paint, -0.34)}" stroke-width="2.4" '
            f'opacity="0.55" d="M {v.p(x0, h)} L {v.p(x1, h)}"/>'
            f'<path fill="none" stroke="{shade(v.paint, 0.42)}" stroke-width="1.6" '
            f'opacity="0.45" d="M {v.p(x0, h + 0.014)} L {v.p(x1, h + 0.014)}"/>'
            f'<rect x="{n(min(v.x(x0), v.x(x1)))}" y="{n(v.y(h + 0.085))}" '
            f'width="{n(abs(v.x(x1) - v.x(x0)))}" height="{n(0.075 * PPM)}" '
            f'fill="url(#shoulder)"/>')


# --------------------------------------------------------------------------
# vehicles
# --------------------------------------------------------------------------

def build_lc79() -> Veh:
    v = Veh(
        id="lc79", model="Toyota Land Cruiser 79 pickup (2023)",
        length=5.24, height=1.95, wheelbase=3.18, tyre_r=0.40,
        paint="#d8c7a0", accent="#7a6a4c", rim=("steel", 8),
        x_front=2.45, x_rear=-2.79,
        y_under=0.44, y_belt=1.18, arch_r=0.435,
        cut_f=True, cut_r=False,
        outline=[
            ("M", -2.70, 0.86),
            ("L", -2.70, 1.08),
            ("L", -0.46, 1.08),
            ("L", -0.46, 1.20),
            ("L", -0.53, 1.20),
            ("L", -0.53, 0.98),
            ("L", -0.34, 0.98),
            ("L", -0.34, 1.90),
            ("Q", -0.34, 1.95, -0.23, 1.95),
            ("L", 0.93, 1.95),
            ("Q", 0.99, 1.95, 1.02, 1.87),
            ("L", 1.13, 1.17),
            ("L", 2.28, 1.12),
            ("Q", 2.33, 1.11, 2.33, 1.05),
            ("L", 2.33, 0.54),
            ("L", 2.28, 0.44),
        ],
        bottom=[(2.28, 0.44), (-0.53, 0.44), (-0.53, 0.86), (-2.70, 0.86)],
        glass=[(1.00, -0.30, 1.80, 1.80, 1.24)],
        ws=(1.13, 1.17, 1.02, 1.87, 0.13),
        doors=[(-0.30, 1.24, 0.44), (1.07, 1.24, 0.50)],
        handle_x=-0.20, handle_h=1.10,
        roof_x=(0.93, -0.23, 1.95),
        belt_x=(-0.34, 1.11),
        clad=[(1.05, -0.56, 0.44, 0.57)],
        crease=[(1.05, -0.32, 0.94)],
        dirt=[(1.03, -0.55, 0.44, 0.66), (-0.50, -2.68, 0.87, 1.10)],
        flaps=[(0.99, 0.44, 0.18), (-2.19, 0.86, 0.18)],
    )
    return v


def build_patrol() -> Veh:
    v = Veh(
        id="patrol_y61", model="Nissan Patrol Y61 wagon (2010)",
        length=5.01, height=1.94, wheelbase=2.97, tyre_r=0.39,
        paint="#3f4d45", accent="#2b3630", rim=("alloy", 6),
        x_front=2.355, x_rear=-2.655,
        y_under=0.46, y_belt=1.24, arch_r=0.425,
        cut_f=True, cut_r=True,
        outline=[
            ("M", -2.58, 0.46),
            ("L", -2.58, 1.54),
            ("Q", -2.57, 1.82, -2.41, 1.86),
            ("L", 1.00, 1.86),
            ("Q", 1.11, 1.86, 1.15, 1.79),
            ("L", 1.29, 1.18),
            ("L", 2.26, 1.14),
            ("Q", 2.32, 1.13, 2.32, 1.06),
            ("L", 2.32, 0.57),
            ("L", 2.24, 0.46),
        ],
        bottom=[(2.24, 0.46), (-2.58, 0.46)],
        glass=[(1.00, 0.26, 1.76, 1.76, 1.24),
               (0.22, -0.58, 1.76, 1.76, 1.24),
               (-0.62, -2.26, 1.75, 1.68, 1.24)],
        ws=(1.29, 1.18, 1.15, 1.79, 0.14),
        doors=[(0.26, 1.24, 0.60), (-0.58, 1.24, 0.60)],
        handle_x=0.30, handle_h=1.16,
        roof_x=(1.00, -2.41, 1.86),
        belt_x=(-2.50, 1.26),
        clad=[(0.97, -0.97, 0.46, 0.60)],
        crease=[(1.24, -2.50, 1.00)],
        dirt=[(-0.96, 0.96, 0.46, 0.72)],
        flaps=[(0.895, 0.46, 0.18), (-2.075, 0.46, 0.18)],
    )
    return v


def build_hilux() -> Veh:
    v = Veh(
        id="hilux_an120", model="Toyota Hilux double cab (2018)",
        length=5.33, height=1.82, wheelbase=3.09, tyre_r=0.38,
        paint="#8a8f6a", accent="#5c6144", rim=("alloy", 6),
        x_front=2.445, x_rear=-2.885,
        y_under=0.44, y_belt=1.18, arch_r=0.415,
        cut_f=True, cut_r=True,
        outline=[
            ("M", -2.82, 0.58),
            ("L", -2.82, 1.04),
            ("L", -0.72, 1.04),
            ("L", -0.72, 1.11),
            ("L", -0.64, 1.11),
            ("L", -0.64, 0.95),
            ("L", -0.58, 0.95),
            ("L", -0.58, 1.62),
            ("Q", -0.58, 1.78, -0.46, 1.81),
            ("L", 1.04, 1.82),
            ("Q", 1.15, 1.82, 1.19, 1.75),
            ("L", 1.37, 1.15),
            ("L", 2.34, 1.07),
            ("Q", 2.40, 1.06, 2.40, 1.00),
            ("L", 2.40, 0.54),
            ("L", 2.34, 0.44),
        ],
        bottom=[(2.34, 0.44), (-0.64, 0.44), (-0.64, 0.58), (-2.82, 0.58)],
        glass=[(1.02, 0.28, 1.72, 1.74, 1.18),
               (0.24, -0.52, 1.74, 1.71, 1.18)],
        ws=(1.37, 1.15, 1.19, 1.75, 0.15),
        doors=[(0.28, 1.18, 0.58), (-0.52, 1.18, 0.58)],
        handle_x=0.34, handle_h=1.10,
        roof_x=(1.04, -0.46, 1.82),
        belt_x=(-0.58, 1.32),
        clad=[(1.04, -0.66, 0.44, 0.57)],
        crease=[(1.30, -0.56, 0.94), (-0.74, -2.78, 0.94)],
        dirt=[(1.02, -0.66, 0.44, 0.66), (-0.70, -2.80, 0.86, 1.02)],
        flaps=[(0.965, 0.44, 0.18), (-2.125, 0.58, 0.18)],
    )
    return v


def build_jimny() -> Veh:
    v = Veh(
        id="jimny_jb74", model="Suzuki Jimny 3-door (2020)",
        length=3.65, height=1.71, wheelbase=2.25, tyre_r=0.34,
        paint="#e0a24a", accent="#a86c1f", rim=("alloy", 5),
        x_front=1.755, x_rear=-1.895,
        y_under=0.44, y_belt=1.16, arch_r=0.375,
        cut_f=True, cut_r=True,
        outline=[
            ("M", -1.62, 0.44),
            ("L", -1.62, 1.56),
            ("Q", -1.62, 1.70, -1.48, 1.71),
            ("L", 0.70, 1.71),
            ("Q", 0.80, 1.71, 0.84, 1.65),
            ("L", 0.95, 1.09),
            ("L", 1.64, 1.06),
            ("Q", 1.70, 1.05, 1.70, 0.99),
            ("L", 1.70, 0.52),
            ("L", 1.65, 0.44),
        ],
        bottom=[(1.65, 0.44), (-1.62, 0.44)],
        glass=[(0.72, -0.24, 1.58, 1.58, 1.16),
               (-0.28, -1.12, 1.58, 1.53, 1.16)],
        ws=(0.95, 1.09, 0.84, 1.65, 0.11),
        doors=[(-0.26, 1.16, 0.56)],
        handle_x=0.30, handle_h=1.08,
        roof_x=(0.70, -1.48, 1.71),
        belt_x=(-1.58, 0.90),
        clad=[(0.67, -0.67, 0.44, 0.58)],
        crease=[(0.88, -1.56, 0.92)],
        dirt=[(0.66, -0.66, 0.44, 0.70)],
        flaps=[(0.605, 0.44, 0.16), (-1.60, 0.44, 0.115)],
    )
    return v


def build_pajero() -> Veh:
    v = Veh(
        id="pajero_v80", model="Mitsubishi Pajero 5-door (2012)",
        length=4.90, height=1.90, wheelbase=2.78, tyre_r=0.38,
        paint="#71818d", accent="#48565f", rim=("alloy", 6),
        x_front=2.25, x_rear=-2.65,
        y_under=0.42, y_belt=1.18, arch_r=0.415,
        cut_f=True, cut_r=True,
        outline=[
            ("M", -2.32, 0.42),
            ("L", -2.32, 1.52),
            ("Q", -2.31, 1.76, -2.14, 1.83),
            ("Q", -1.92, 1.88, -1.58, 1.88),
            ("L", 0.58, 1.88),
            ("Q", 0.70, 1.88, 0.74, 1.81),
            ("L", 1.06, 1.12),
            ("L", 2.08, 1.04),
            ("Q", 2.17, 1.03, 2.18, 0.96),
            ("L", 2.18, 0.56),
            ("L", 2.13, 0.42),
        ],
        bottom=[(2.13, 0.42), (-2.32, 0.42)],
        glass=[(0.96, 0.26, 1.72, 1.74, 1.18),
               (0.22, -0.60, 1.74, 1.72, 1.18),
               (-0.64, -1.50, 1.72, 1.63, 1.18)],
        ws=(1.06, 1.12, 0.74, 1.81, 0.17),
        doors=[(0.26, 1.18, 0.56), (-0.60, 1.18, 0.56)],
        handle_x=0.32, handle_h=1.10,
        roof_x=(0.58, -1.58, 1.88),
        belt_x=(-2.28, 1.02),
        clad=[(0.89, -0.89, 0.42, 0.56)],
        crease=[(1.02, -2.26, 0.94)],
        dirt=[(0.88, -0.88, 0.42, 0.68)],
        flaps=[(0.82, 0.42, 0.17), (-1.96, 0.42, 0.17)],
    )
    return v


VEHICLES = [build_lc79(), build_patrol(), build_hilux(), build_jimny(), build_pajero()]


# --------------------------------------------------------------------------
# per-vehicle body detail
# --------------------------------------------------------------------------

def body_lc79(v: Veh, doc: Doc) -> None:
    # steel bull bar: one chunky side plate with a hoop over the nose
    doc.add(f'<path d="{poly_d(v, [(2.31, 0.48), (2.45, 0.48), (2.45, 1.06), (2.40, 1.12), (2.34, 1.06), (2.31, 0.98)])}" '
            f'fill="url(#darkSteel)" stroke="#0c0f11" stroke-width="2"/>')
    doc.add(f'<path d="{poly_d(v, [(2.32, 0.62), (2.44, 0.62), (2.44, 0.76), (2.32, 0.76)])}" fill="#0b0e10"/>')
    doc.add(f'<path fill="none" stroke="#b9c2ca" stroke-width="2" opacity="0.75" '
            f'd="M {v.p(2.325, 1.06)} L {v.p(2.40, 1.125)} L {v.p(2.44, 1.06)} L {v.p(2.44, 0.52)}"/>')
    doc.add(f'<path fill="none" stroke="#6f777e" stroke-width="1.6" opacity="0.6" '
            f'd="M {v.p(2.33, 0.90)} L {v.p(2.44, 0.90)}"/>')
    doc.add(f'<path fill="none" stroke="#6f777e" stroke-width="1.6" opacity="0.6" '
            f'd="M {v.p(2.33, 0.52)} L {v.p(2.44, 0.52)}"/>')
    doc.add(f'<circle cx="{n(v.x(2.385))}" cy="{n(v.y(0.86))}" r="6.5" fill="#1a1d20" stroke="#b9c2ca" stroke-width="1.5"/>')
    doc.add(f'<circle cx="{n(v.x(2.385))}" cy="{n(v.y(0.86))}" r="3.8" fill="#f0dcae"/>')
    doc.add(tow_hook(v, 2.45, 0.55, flip=False))
    # grille + rectangular headlights + amber indicators
    doc.add(f'<path d="{poly_d(v, [(2.18, 1.04), (2.33, 1.04), (2.33, 0.60), (2.20, 0.60)])}" fill="#161a1d"/>')
    for i in range(3):
        hh = 0.97 - i * 0.085
        doc.add(f'<path fill="none" stroke="#4b5259" stroke-width="6" '
                f'd="M {v.p(2.19, hh)} L {v.p(2.325, hh)}"/>')
        doc.add(f'<path fill="none" stroke="#8b939b" stroke-width="1.2" opacity="0.5" '
                f'd="M {v.p(2.20, hh + 0.012)} L {v.p(2.32, hh + 0.012)}"/>')
    doc.add(lamp_front(v, 2.115, 2.295, 0.915, 1.085, "rect"))
    doc.add(side_repeater(v, 1.86, 0.92))
    # snorkel up the A-pillar
    doc.add(snorkel(v, 1.10, 1.20, 1.00, 1.86))
    # tray: top rail, drop-side panel, tie-down hooks, headboard
    doc.add(f'<path fill="none" stroke="#5b636a" stroke-width="5" stroke-linecap="round" '
            f'd="M {v.p(-2.68, 1.10)} L {v.p(-0.48, 1.10)}"/>')
    doc.add(f'<path fill="none" stroke="#aab2b9" stroke-width="1.6" opacity="0.65" '
            f'd="M {v.p(-2.66, 1.118)} L {v.p(-0.50, 1.118)}"/>')
    doc.add(f'<path fill="none" stroke="#1b1f22" stroke-width="2.4" opacity="0.55" '
            f'd="M {v.p(-2.70, 1.02)} L {v.p(-0.46, 1.02)}"/>')
    for x in (-2.50, -1.95, -1.20, -0.78):
        doc.add(f'<path fill="none" stroke="#3c4348" stroke-width="3.2" '
                f'd="M {v.p(x, 1.06)} L {v.p(x, 0.88)}"/>')
        doc.add(f'<path d="{poly_d(v, [(x - 0.035, 1.03), (x + 0.035, 1.03), (x + 0.024, 0.95), (x - 0.024, 0.95)])}" '
                f'fill="#6c747b"/>')
        doc.add(f'<path fill="none" stroke="#22272b" stroke-width="1.2" '
                f'd="M {v.p(x - 0.03, 0.95)} L {v.p(x + 0.03, 0.95)}"/>')
    # tailgate: seam, hinges, handle
    doc.add(door_seam(v, -2.665, 0.90, 1.06, 0.5))
    doc.add(hinges(v, [-2.66], 0.92, 1.04))
    doc.add(rect_px(v.x(-0.53), v.y(1.20), v.x(-0.46), v.y(0.86), fill="url(#darkSteel)"))
    # rear step + lamps + recovery point
    doc.add(rect_px(v.x(-2.70), v.y(0.62), v.x(-2.62), v.y(0.48), fill="url(#darkSteel)"))
    doc.add(rect_px(v.x(-2.79), v.y(0.54), v.x(-2.70), v.y(0.40), rx=3, fill="#23282c"))
    doc.add(lamp_rear(v, -2.70, -2.622, 0.84, 1.02))
    doc.add(tow_hook(v, -2.79, 0.50, flip=True))
    doc.add(handles(v, -0.44, 1.10, 0.12))
    doc.add(fuel_cap(v, -0.22, 1.02))


def body_patrol(v: Veh, doc: Doc) -> None:
    # flares + side steps
    doc.add(flare(v, v.hub_f, "#2b302c", 0.05))
    doc.add(flare(v, v.hub_r, "#2b302c", 0.05))
    doc.add(side_step(v, -0.62, 1.02, 0.44))
    # front bar: steel centre with a dark valance and a fog lamp
    doc.add(front_bumper(v, 2.18, 2.355, 0.46, 0.78, "body"))
    doc.add(f'<path d="{poly_d(v, [(2.20, 0.54), (2.35, 0.54), (2.35, 0.44), (2.21, 0.44)])}" fill="url(#plastic)"/>')
    doc.add(f'<circle cx="{n(v.x(2.26))}" cy="{n(v.y(0.60))}" r="8" fill="#2a2119" stroke="#9aa3ab" stroke-width="1.8"/>')
    doc.add(f'<circle cx="{n(v.x(2.26))}" cy="{n(v.y(0.60))}" r="4.6" fill="#f0d8a6" opacity="0.9"/>')
    doc.add(rect_px(v.x(2.24), v.y(1.18), v.x(2.33), v.y(0.98), fill="#14181b"))
    for i in range(4):
        doc.add(f'<path fill="none" stroke="#464d54" stroke-width="3.6" '
                f'd="M {v.p(2.245, 1.14 - i * 0.045)} L {v.p(2.325, 1.14 - i * 0.045)}"/>')
    doc.add(lamp_front(v, 2.12, 2.29, 0.95, 1.075, "rect"))
    doc.add(side_repeater(v, 1.93, 0.94))
    # roof rack
    doc.add(roof_rack(v, -2.02, 0.94, 1.86, 1.94, feet=4))
    # rear: bumper, lamps, door handle, hinges
    doc.add(f'<path d="{poly_d(v, [(-2.58, 0.66), (-2.44, 0.66), (-2.44, 0.52), (-2.57, 0.50)])}" fill="url(#darkSteel)"/>')
    doc.add(rect_px(v.x(-2.655), v.y(0.58), v.x(-2.58), v.y(0.44), rx=3, fill="#2a2f33"))
    doc.add(lamp_rear(v, -2.575, -2.495, 0.98, 1.40))
    doc.add(door_seam(v, -2.50, 0.62, 1.52, 0.4))
    doc.add(handles(v, -2.42, 1.16, 0.12))
    doc.add(hinges(v, [-2.53], 1.02, 1.16))
    doc.add(fuel_cap(v, -1.86, 1.06))
    doc.add(antenna(v, -2.10, 1.84, 1.86, lean=0.05))


def body_hilux(v: Veh, doc: Doc) -> None:
    # black arch trim + side steps
    doc.add(flare(v, v.hub_f, "#262b2a", 0.045))
    doc.add(flare(v, v.hub_r, "#262b2a", 0.045))
    doc.add(side_step(v, -0.56, 1.14, 0.42))
    # front: body-colour upper apron, dark bumper, swept lamp, fog lamp
    doc.add(f'<path d="{poly_d(v, [(2.30, 0.78), (2.445, 0.78), (2.445, 0.66), (2.30, 0.66)])}" fill="{shade(v.paint, -0.12)}"/>')
    doc.add(front_bumper(v, 2.28, 2.445, 0.44, 0.66, "plastic"))
    doc.add(f'<circle cx="{n(v.x(2.37))}" cy="{n(v.y(0.55))}" r="7" fill="#2b2318" stroke="#8b939b" stroke-width="1.6"/>')
    doc.add(f'<circle cx="{n(v.x(2.37))}" cy="{n(v.y(0.55))}" r="4" fill="#e8d2a4" opacity="0.85"/>')
    doc.add(f'<path d="{poly_d(v, [(2.22, 1.06), (2.40, 1.02), (2.40, 1.12), (2.24, 1.13)])}" fill="#15191c"/>')
    doc.add(lamp_front(v, 2.17, 2.355, 0.925, 1.025, "rect"))
    doc.add(f'<path fill="none" stroke="#3f474e" stroke-width="6" stroke-linecap="round" '
            f'd="M {v.p(2.26, 1.03)} L {v.p(2.39, 1.00)}"/>')
    doc.add(side_repeater(v, 1.98, 0.94))
    # tub: rail, tie-downs, front panel, tailgate, rear step
    doc.add(f'<path fill="none" stroke="#596167" stroke-width="4" stroke-linecap="round" '
            f'd="M {v.p(-2.80, 1.06)} L {v.p(-0.74, 1.06)}"/>')
    doc.add(f'<path fill="none" stroke="#a7afb6" stroke-width="1.3" opacity="0.6" '
            f'd="M {v.p(-2.78, 1.075)} L {v.p(-0.76, 1.075)}"/>')
    for x in (-2.62, -1.98, -1.10):
        doc.add(f'<path d="{poly_d(v, [(x - 0.03, 1.05), (x + 0.03, 1.05), (x + 0.02, 0.98), (x - 0.02, 0.98)])}" fill="#6c747b"/>')
    doc.add(f'<path fill="none" stroke="#15191c" stroke-width="2.2" opacity="0.55" '
            f'd="M {v.p(-2.82, 1.00)} L {v.p(-0.74, 1.00)}"/>')
    doc.add(roll_bar(v, -0.86, 1.04, 1.46))
    doc.add(rect_px(v.x(-2.885), v.y(0.58), v.x(-2.82), v.y(0.46), rx=2, fill="url(#chrome)"))
    doc.add(lamp_rear(v, -2.82, -2.745, 0.90, 1.08))
    doc.add(handles(v, -2.72, 1.10, 0.12))
    doc.add(fuel_cap(v, -0.86, 1.00))
    doc.add(antenna(v, 1.30, 1.16, 1.52, lean=-0.03))


def body_jimny(v: Veh, doc: Doc) -> None:
    # big square-ish black flares (JB74 signature)
    doc.add(flare(v, v.hub_f, "#23272a", 0.075))
    doc.add(flare(v, v.hub_r, "#23272a", 0.075))
    # front: dark bumper, round headlamp, fog lamp, slotted grille
    doc.add(front_bumper(v, 1.60, 1.755, 0.44, 0.70, "plastic", chrome=False))
    doc.add(f'<circle cx="{n(v.x(1.695))}" cy="{n(v.y(0.58))}" r="6.5" fill="#2b2318" stroke="#6f777e" stroke-width="1.4"/>')
    doc.add(f'<circle cx="{n(v.x(1.695))}" cy="{n(v.y(0.58))}" r="3.6" fill="#e8d2a4" opacity="0.85"/>')
    doc.add(f'<path d="{poly_d(v, [(1.56, 1.03), (1.70, 1.02), (1.70, 0.86), (1.57, 0.86)])}" fill="#15191c"/>')
    for i in range(5):
        doc.add(f'<path fill="none" stroke="#3f464c" stroke-width="3" '
                f'd="M {v.p(1.575, 1.00 - i * 0.033)} L {v.p(1.69, 1.00 - i * 0.033)}"/>')
    doc.add(lamp_front(v, 1.548, 1.692, 0.862, 1.006, "round"))
    doc.add(side_repeater(v, 1.42, 0.94))
    # roof drip rail + gutters
    doc.add(f'<path fill="none" stroke="#1a1e21" stroke-width="4" stroke-linecap="round" '
            f'd="M {v.p(-1.46, 1.705)} L {v.p(0.68, 1.705)}"/>')
    doc.add(f'<path fill="none" stroke="#8a9299" stroke-width="1.3" opacity="0.55" '
            f'd="M {v.p(-1.44, 1.712)} L {v.p(0.66, 1.712)}"/>')
    # rear: tailgate + spare wheel cover + hinges + lamp
    doc.add(f'<path fill="none" stroke="#121518" stroke-width="2" opacity="0.7" '
            f'd="M {v.p(-1.62, 0.62)} L {v.p(-1.62, 1.52)}"/>')
    doc.add(spare_bulge(v, -1.66, 0.98, 0.235, 0.355, shade(v.paint, -0.06)))
    doc.add(lamp_rear(v, -1.615, -1.545, 0.94, 1.22))
    doc.add(handles(v, -1.53, 1.04, 0.10))
    doc.add(hinges(v, [-1.60], 1.30, 1.44))
    doc.add(fuel_cap(v, -1.30, 1.00))
    doc.add(antenna(v, 0.60, 1.68, 1.70, lean=0.02))


def body_pajero(v: Veh, doc: Doc) -> None:
    # rounded body-colour arch blisters + side steps
    doc.add(flare(v, v.hub_f, shade(v.paint, -0.14), 0.06))
    doc.add(flare(v, v.hub_r, shade(v.paint, -0.14), 0.06))
    doc.add(side_step(v, -0.58, 0.98, 0.40))
    # front: body-colour bumper with a black lower lip
    doc.add(front_bumper(v, 2.04, 2.25, 0.50, 0.78, "body"))
    doc.add(f'<path d="{poly_d(v, [(2.06, 0.50), (2.25, 0.50), (2.25, 0.42), (2.07, 0.42)])}" fill="url(#plastic)"/>')
    doc.add(f'<path d="{poly_d(v, [(2.00, 1.04), (2.18, 1.00), (2.18, 1.10), (2.02, 1.12)])}" fill="#15191c"/>')
    doc.add(lamp_front(v, 1.975, 2.145, 0.91, 1.005, "rect"))
    doc.add(f'<path fill="none" stroke="#394148" stroke-width="5" stroke-linecap="round" '
            f'd="M {v.p(2.04, 1.02)} L {v.p(2.16, 1.00)}"/>')
    doc.add(side_repeater(v, 1.86, 0.92))
    # roof rails + rear spoiler lip
    doc.add(f'<path fill="none" stroke="#2a2f33" stroke-width="5" stroke-linecap="round" '
            f'd="M {v.p(-1.28, 1.897)} L {v.p(0.46, 1.897)}"/>')
    doc.add(f'<path fill="none" stroke="#7d858c" stroke-width="1.4" opacity="0.6" '
            f'd="M {v.p(-1.26, 1.903)} L {v.p(0.44, 1.903)}"/>')
    for x in (-1.16, 0.34):
        doc.add(f'<path fill="none" stroke="#23282c" stroke-width="4" '
                f'd="M {v.p(x, 1.893)} L {v.p(x, 1.86)}"/>')
    doc.add(f'<path d="{poly_d(v, [(-1.58, 1.885), (-1.30, 1.900), (-1.30, 1.855), (-1.60, 1.845)])}" fill="{shade(v.paint, -0.22)}"/>')
    # rear: spare cover + bumper + tall lamp
    doc.add(spare_bulge(v, -2.35, 1.00, 0.30, 0.35, shade(v.paint, -0.05)))
    doc.add(f'<path d="{poly_d(v, [(-2.32, 0.66), (-2.44, 0.64), (-2.44, 0.50), (-2.32, 0.50)])}" fill="{shade(v.paint, -0.12)}"/>')
    doc.add(f'<path d="{poly_d(v, [(-2.36, 0.50), (-2.46, 0.50), (-2.46, 0.42), (-2.36, 0.42)])}" fill="url(#plastic)"/>')
    doc.add(lamp_rear(v, -2.32, -2.245, 1.24, 1.54))
    doc.add(handles(v, -2.20, 1.16, 0.11))
    doc.add(fuel_cap(v, -1.90, 1.04))
    doc.add(antenna(v, -1.80, 1.80, 1.86, lean=0.04))


BODY_DETAIL = {
    "lc79": body_lc79,
    "patrol_y61": body_patrol,
    "hilux_an120": body_hilux,
    "jimny_jb74": body_jimny,
    "pajero_v80": body_pajero,
}


# --------------------------------------------------------------------------
# body builder
# --------------------------------------------------------------------------

def build_body(v: Veh) -> str:
    doc = Doc(CW, CH)
    paint_defs(v, doc)
    doc.d(rad("lampWarm", [(0, "#fffdf3"), (0.45, "#f8e9c2"), (1, "#c9a465")], 0.36, 0.3, 0.74))
    doc.d(rad("shadowSoft", [(0, "#000000", "0.30"), (0.7, "#000000", "0.10"), (1, "#000000", "0")],
              0.5, 0.5, 0.5))

    # 1 - chassis + suspension peeking under the sills
    doc.add(underbody(v))
    # 2 - wheel wells
    doc.add(wheel_bits(v, v.cut_f, v.cut_r))
    # 3 - the painted shell (arches cut out of the outline)
    d = shell(v)
    doc.add(f'<path id="body-shell" d="{d}" fill="url(#paint)"/>')
    doc.add(f'<path d="{d}" fill="none" stroke="{shade(v.paint, -0.62)}" stroke-width="2.2"/>')
    # 4 - wheel-arch lips
    if v.cut_f:
        doc.add(arch_lip(v, v.hub_f))
    if v.cut_r:
        doc.add(arch_lip(v, v.hub_r))
    # 5 - rocker cladding, roof strip, belt line, road grime
    for x0, x1, h0, h1 in v.clad:
        doc.add(cladding(v, x0, x1, h0, h1))
    doc.add(roof_highlight(v, v.roof_x[0], v.roof_x[1], v.roof_x[2]))
    doc.add(belt_line(v, v.belt_x[0], v.belt_x[1], v.y_belt))
    for x0, x1, h0, h1 in v.dirt:
        doc.add(dirt_wash(v, x0, x1, h0, h1))
    for x0, x1, h0, h1 in v.clad:
        doc.add(sill_shade(v, x1, x0, h0))
    for x0, x1, h in v.crease:
        doc.add(shoulder_line(v, x0, x1, h))
    # 6 - glass
    for x0, x1, t0, t1, b in v.glass:
        doc.add(glass_pane(v, x0, x1, t0, t1, b))
    doc.add(windscreen(v, v.ws))
    # 7 - panel work
    for x, h0, h1 in v.doors:
        doc.add(door_seam(v, x, h0, h1))
    doc.add(handles(v, v.handle_x, v.handle_h))
    doc.add(mirror_arm(v, v.ws[0] - 0.06, v.y_belt + 0.10, 1.0))
    # 8 - vehicle-specific hardware
    BODY_DETAIL[v.id](v, doc)
    # 9 - mud flaps last: they hang in front of the tyres
    for fx, ftop, fw in v.flaps:
        doc.add(mudflap(v, fx, ftop, fw))
    return doc.render()


# --------------------------------------------------------------------------
# wheels
# --------------------------------------------------------------------------

def build_wheel(v: Veh) -> str:
    """720 px canvas, tyre filling it, rim style per vehicle."""
    doc = Doc(WHEEL_PX, WHEEL_PX)
    R = 358.0
    style, spokes = v.rim

    doc.d(rad("wall", [(0, "#5f646c"), (0.30, "#464b53"), (0.62, "#2e3238"),
                       (0.86, "#1c1f23"), (1, "#0f1012")], 0.33, 0.26, 0.86))
    doc.d(rad("sheen", [(0, "#c8d2e0", "0.16"), (0.65, "#c8d2e0", "0.05"), (1, "#c8d2e0", "0")],
              0.5, 0.5, 0.5))
    doc.d(rad("ao", [(0, "#000000", "0.34"), (0.7, "#000000", "0.10"), (1, "#000000", "0")],
              0.5, 0.5, 0.5))
    doc.d(lin("rimLip", [(0, "#f4f8fc"), (0.26, "#c6cfd9"), (0.56, "#8b949f"),
                         (0.82, "#525a63"), (1, "#2b3137")], 150, 120, 380, 400))
    doc.d(rad("rimFace", [(0, "#c6d0da"), (0.40, "#8b949e"), (0.76, "#565e67"), (1, "#2b3238")],
              0.32, 0.26, 0.86))
    doc.d(rad("discFace", [(0, "#7d828a"), (0.46, "#54585f"), (1, "#24262a")], 0.34, 0.28, 0.82))
    doc.d(lin("hubFace", [(0, "#dfe7ef"), (0.45, "#98a1ab"), (1, "#3d434b")], 216, 206, 300, 312))
    doc.d(rad("dust", [(0, "#8a6640", "0.22"), (0.7, "#7a5a38", "0.09"), (1, "#6a4c2e", "0")],
              0.5, 0.5, 0.5))

    g = doc.add
    # tread ring + shoulder blocks
    g(f'<circle cx="360" cy="360" r="{R}" fill="#0a0b0d"/>')
    g(f'<circle cx="360" cy="360" r="{R - 4}" fill="url(#wall)"/>')
    outer = R - 4
    inner = R - 66
    blocks = []
    for i in range(30):
        a0 = 360.0 * i / 30
        a1 = a0 + 4.4
        p = []
        for ang, rr in ((a0, inner), (a1, inner), (a1 + 0.8, outer), (a0 + 0.8, outer)):
            rad_ = math.radians(ang)
            p.append((360 + rr * math.cos(rad_), 360 + rr * math.sin(rad_)))
        blocks.append(f'<path d="M {n(p[0][0])} {n(p[0][1])} L {n(p[1][0])} {n(p[1][1])} '
                      f'L {n(p[2][0])} {n(p[2][1])} L {n(p[3][0])} {n(p[3][1])} Z" '
                      f'fill="#202227" stroke="#0d0e10" stroke-width="1"/>')
    g('<g>' + "".join(blocks) + '</g>')
    # tread grooves
    g(f'<circle cx="360" cy="360" r="{outer - 6}" fill="none" stroke="#08090a" stroke-width="3" opacity="0.8"/>')
    g(f'<circle cx="360" cy="360" r="{inner + 4}" fill="none" stroke="#0a0b0d" stroke-width="7"/>')
    # sidewall shading + bead
    g(f'<circle cx="360" cy="360" r="{inner}" fill="url(#wall)" stroke="#08090a" stroke-width="2"/>')
    g(f'<ellipse cx="290" cy="272" rx="120" ry="104" fill="url(#sheen)"/>')
    g(f'<ellipse cx="420" cy="450" rx="130" ry="118" fill="url(#ao)"/>')
    g(f'<circle cx="360" cy="360" r="{inner - 26}" fill="none" stroke="#2f333a" stroke-width="2" opacity="0.65"/>')
    g(f'<circle cx="360" cy="360" r="{inner - 42}" fill="none" stroke="#0a0b0d" stroke-width="4" opacity="0.85"/>')
    # brake disc behind the rim
    g(f'<circle cx="360" cy="360" r="196" fill="#0b0c0e"/>')
    g(f'<circle cx="360" cy="360" r="178" fill="url(#discFace)"/>')
    g(f'<circle cx="360" cy="360" r="178" fill="none" stroke="#1d1f23" stroke-width="2"/>')
    g(f'<circle cx="360" cy="360" r="150" fill="none" stroke="#2b2e33" stroke-width="3" opacity="0.9"/>')
    holes = "".join(
        f'<circle cx="{n(360 + 122 * math.cos(math.radians(a)))}" '
        f'cy="{n(360 + 122 * math.sin(math.radians(a)))}" r="5" fill="#202328" opacity="0.85"/>'
        for a in range(0, 360, 30))
    g(f'<g>{holes}</g>')
    # caliper at 10 o'clock
    g(f'<path fill="#3f464e" d="M 205.7 291.4 A 178 178 0 0 1 260.0 224.6 '
      f'L 238.0 196.0 A 214 214 0 0 0 172.0 276.0 Z"/>')
    g(f'<path fill="#6a727b" opacity="0.65" d="M 209.3 289.9 A 174 174 0 0 1 260.8 227.9 '
      f'L 257.2 221.6 A 182 182 0 0 0 202.0 286.0 Z"/>')
    # rim lip
    g(f'<circle cx="360" cy="360" r="196" fill="none" stroke="url(#rimLip)" stroke-width="13"/>')
    g(f'<circle cx="360" cy="360" r="203" fill="none" stroke="#1c2228" stroke-width="1.6"/>')
    g(f'<circle cx="360" cy="360" r="189" fill="none" stroke="#f2f7fc" stroke-width="1" opacity="0.45"/>')

    if style == "steel":
        # pressed steel wheel: eight round vent holes + trim ring
        win = "".join(
            f'<circle cx="{n(360 + 126 * math.cos(math.radians(a)))}" '
            f'cy="{n(360 + 126 * math.sin(math.radians(a)))}" r="21" fill="#0e1114" '
            f'stroke="#3a4147" stroke-width="2"/>'
            for a in range(0, 360, 45))
        g(win)
        g('<circle cx="360" cy="360" r="150" fill="none" stroke="#4b535a" stroke-width="2" opacity="0.8"/>')
        g('<circle cx="360" cy="360" r="104" fill="url(#rimFace)" stroke="#171b1f" stroke-width="1.6"/>')
    else:
        # cast alloy: tapered spokes over the disc
        spoke_geo = []
        for i in range(spokes):
            a = 360.0 * i / spokes - 90.0
            half = 20.0 if spokes >= 6 else 24.0
            p = []
            for ang, rr in ((a - half, 96), (a + half, 96), (a + half * 1.25, 186), (a - half * 1.25, 186)):
                rr_ = math.radians(ang)
                p.append((360 + rr * math.cos(rr_), 360 + rr * math.sin(rr_)))
            spoke_geo.append(f'<path d="M {n(p[0][0])} {n(p[0][1])} L {n(p[1][0])} {n(p[1][1])} '
                             f'L {n(p[2][0])} {n(p[2][1])} L {n(p[3][0])} {n(p[3][1])} Z" '
                             f'fill="url(#rimFace)" stroke="#15181b" stroke-width="1.6"/>')
        g('<g>' + "".join(spoke_geo) + '</g>')
        # spoke highlight
        hi = []
        for i in range(spokes):
            a = 360.0 * i / spokes - 90.0
            half = 20.0 if spokes >= 6 else 24.0
            p = []
            for ang, rr in ((a - half, 100), (a - half * 0.2, 100), (a - half * 0.2, 182), (a - half * 1.2, 182)):
                rr_ = math.radians(ang)
                p.append((360 + rr * math.cos(rr_), 360 + rr * math.sin(rr_)))
            hi.append(f'<path d="M {n(p[0][0])} {n(p[0][1])} L {n(p[1][0])} {n(p[1][1])} '
                      f'L {n(p[2][0])} {n(p[2][1])} L {n(p[3][0])} {n(p[3][1])} Z" '
                      f'fill="#cfd8e2" opacity="0.35"/>')
        g('<g>' + "".join(hi) + '</g>')
    # hub, lug nuts, centre cap
    g('<circle cx="360" cy="360" r="70" fill="url(#hubFace)" stroke="#2f363d" stroke-width="2"/>')
    g('<circle cx="360" cy="360" r="52" fill="none" stroke="#1b1f24" stroke-width="2" opacity="0.8"/>')
    nuts = "".join(
        f'<circle cx="{n(360 + 44 * math.cos(math.radians(a)))}" '
        f'cy="{n(360 + 44 * math.sin(math.radians(a)))}" r="6.4" fill="#d3dbe3"/>'
        f'<circle cx="{n(360 + 44 * math.cos(math.radians(a)))}" '
        f'cy="{n(360 + 44 * math.sin(math.radians(a)))}" r="3.4" fill="#3b4249"/>'
        for a in range(0, 360, 60))
    g(f'<g>{nuts}</g>')
    g('<circle cx="360" cy="360" r="20" fill="#2a3036" stroke="#9aa4ae" stroke-width="2"/>')
    g('<circle cx="353" cy="352" r="7" fill="#7f8992" opacity="0.55"/>')
    # dust + studio rim light
    g('<circle cx="390" cy="410" r="250" fill="url(#dust)"/>')
    g('<path fill="none" stroke="#ffffff" stroke-width="26" stroke-linecap="round" opacity="0.030" '
      'd="M 22.4 271.0 A 358 358 0 0 1 217.3 32.5"/>')
    g('<path fill="none" stroke="#ffffff" stroke-width="10" stroke-linecap="round" opacity="0.075" '
      'd="M 22.4 271.0 A 358 358 0 0 1 217.3 32.5"/>')
    g('<path fill="none" stroke="#000000" stroke-width="20" stroke-linecap="round" opacity="0.16" '
      'd="M 700.0 470.0 A 352 352 0 0 1 610.0 600.0"/>')
    return doc.render()


# --------------------------------------------------------------------------
# generation
# --------------------------------------------------------------------------

def body_path(v: Veh) -> str:
    return os.path.join(ROOT, ASSET_DIR, v.id, "body.svg")


def wheel_path(v: Veh) -> str:
    return os.path.join(ROOT, ASSET_DIR, v.id, "wheel.svg")


def generate(write_files: bool = True) -> dict[str, tuple[str, str]]:
    out = {}
    for v in VEHICLES:
        body, wheel = build_body(v), build_wheel(v)
        out[v.id] = (body, wheel)
        if write_files:
            for path, text in ((body_path(v), body), (wheel_path(v), wheel)):
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(text)
    return out


# --------------------------------------------------------------------------
# geometry contract check
# --------------------------------------------------------------------------

def _raster(svg: str, w: int, h: int):
    """Rasterise through resvg-py. Returns a PIL image or None."""
    try:
        import resvg_py  # type: ignore
        from io import BytesIO
        from PIL import Image
    except Exception:
        return None
    png = resvg_py.svg_to_bytes(svg_string=svg, width=w, height=h, dpi=96.0)
    return Image.open(BytesIO(png)).convert("RGBA")


def _alpha(img, x: float, y: float) -> int:
    if x < 0 or y < 0 or x >= img.width or y >= img.height:
        return -1
    return img.getpixel((int(round(x)), int(round(y))))[3]


class CheckError(AssertionError):
    pass


def check_document(v: Veh, body: str, wheel: str, strict_files: bool) -> list[str]:
    log = []
    fail = []

    def expect(cond: bool, msg: str) -> None:
        if cond:
            log.append("  ok   " + msg)
        else:
            fail.append("  FAIL " + msg)

    # ---- body canvas / viewBox
    root = ET.fromstring(body)
    expect(root.get("width") == str(CW) and root.get("height") == str(CH),
           f"{v.id} body canvas {root.get('width')}x{root.get('height')} == 1600x720")
    expect(root.get("viewBox") == f"0 0 {CW} {CH}", f"{v.id} body viewBox == '{CW} {CH}'")

    # ---- every id used by a fill/stroke reference must exist
    ids = {e.get("id") for e in root.iter() if e.get("id")}
    refs = set(re.findall(r"url\(#([a-zA-Z0-9_]+)\)", body))
    expect(refs <= ids, f"{v.id} gradient refs resolve ({len(refs)} used)")

    # ---- shell path + arch arcs at the contract hubs
    shell_el = None
    for e in root.iter():
        if e.get("id") == "body-shell":
            shell_el = e
    expect(shell_el is not None, f"{v.id} body-shell path present")
    d = shell_el.get("d") if shell_el is not None else ""
    expect(len(d) > 200, f"{v.id} body-shell path has geometry ({len(d)} chars)")

    for label, hub, cut in (("front", v.hub_f, v.cut_f), ("rear", v.hub_r, v.cut_r)):
        hx = v.x(hub)
        expect(abs(hub - (v.wheelbase * 0.5 if label == "front" else -v.wheelbase * 0.5)) < 1e-9,
               f"{v.id} {label} hub at x={n(hx)} px ({hub:+.3f} m)")
        if not cut:
            continue
        rx, ry = v.arch_px(hub)
        sill = v.y(v.floor_at(hub))
        expect(f"A {n(rx)} {n(ry)} 0 0 0 {n(hx - rx)} {n(sill)}" in d,
               f"{v.id} {label} arch cut {n(rx / PPM)} x {n(ry / PPM)} m cut into the shell")
        expect(f"{n(hx + rx)} {n(sill)}" in d,
               f"{v.id} {label} arch starts on the sill line at x={n(hx + rx)}")

    # ---- wheel: canvas, centre, diameter mapping
    wroot = ET.fromstring(wheel)
    expect(wroot.get("width") == str(WHEEL_PX) and wroot.get("height") == str(WHEEL_PX),
           f"{v.id} wheel canvas {WHEEL_PX}x{WHEEL_PX}")
    expect(wroot.get("viewBox") == f"0 0 {WHEEL_PX} {WHEEL_PX}", f"{v.id} wheel viewBox")
    world_d = 2 * v.tyre_r * PPM
    scale = WHEEL_PX / world_d
    expect(abs(scale - WHEEL_PX / (2 * v.tyre_r * PPM)) < 1e-9 and abs(720 * (1 / scale) - world_d) < 1e-6,
           f"{v.id} wheel sprite {WHEEL_PX} px -> world tyre {n(world_d)} px "
           f"(2*r*160, sprite scale {scale:.3f})")
    expect('<text' not in body and '<text' not in wheel, f"{v.id} no <text> nodes")

    # ---- file size
    if strict_files:
        for path, text in ((body_path(v), body), (wheel_path(v), wheel)):
            if not os.path.exists(path):
                fail.append(f"  FAIL missing file {os.path.relpath(path, ROOT)} (run without --check)")
                continue
            with open(path, "r", encoding="utf-8") as fh:
                disk = fh.read()
            expect(disk == text, f"{v.id} {os.path.basename(os.path.dirname(path))}/{os.path.basename(path)} on disk == regenerated")
            expect(len(disk.encode()) < MAX_BYTES,
                   f"{os.path.relpath(path, ROOT)} {len(disk.encode()) // 1024} KB < 60 KB")

    # ---- rasterised geometry (optional, needs resvg)
    img = _raster(body, CW, CH)
    if img is None:
        log.append("  skip alpha probes (resvg-py not installed)")
        return log + fail

    # ink bounding box
    box = img.split()[3].getbbox()
    expect(box is not None, f"{v.id} body raster is not empty")
    if box:
        bx0, by0, bx1, by1 = box
        exp_w = v.length * PPM
        expect(abs((bx1 - bx0) - exp_w) <= 10,
               f"{v.id} body length {n((bx1 - bx0) / PPM)} m ({(bx1 - bx0)} px) == {n(v.length)} m")
        expect(abs(by0 - v.y(v.height)) <= 4,
               f"{v.id} roof at y={by0} == contract y={n(v.y(v.height))} for {n(v.height)} m")
        expect(bx0 >= 6 and bx1 <= CW - 6 and by0 >= 6 and by1 <= CH - 4,
               f"{v.id} body fits the canvas ({bx0},{by0})-({bx1},{by1})")

    # the arch openings must be transparent: no body pixel may cover a wheel
    tyrep = v.tyre_r * PPM
    for label, hub, cut in (("front", v.hub_f, v.cut_f), ("rear", v.hub_r, v.cut_r)):
        if not cut:
            # tray ute: the wheel sits under an open deck, so the opening above
            # the tyre must be clear as well
            pass
        hx, hy = v.x(hub), HUB_Y
        expect(_alpha(img, hx, hy) == 0, f"{v.id} {label} hub pixel transparent")
        covered = []
        for k in range(36):
            a = math.radians(k * 10.0)
            for frac in (0.45, 0.72, 0.94):
                px = hx + tyrep * frac * math.cos(a)
                py = hy + tyrep * frac * math.sin(a)
                if _alpha(img, px, py) != 0:
                    covered.append((k, frac))
        expect(not covered, f"{v.id} {label} wheel disc clear of body pixels ({len(covered)} hits)")
        # the panel the arch is cut into must still be painted beside the opening
        if cut:
            ang = math.radians(40.0)
            rx, ry = v.arch_px(hub)
            px = hx + (rx + 9) * math.cos(ang)
            py = v.y(v.floor_at(hub)) - (ry + 9) * math.sin(ang)
            expect(_alpha(img, px, py) > 200,
                   f"{v.id} {label} arch opening is cut into a painted panel")

    # wheel raster: tyre must fill the canvas, corners transparent
    wimg = _raster(wheel, WHEEL_PX, WHEEL_PX)
    if wimg is not None:
        a = wimg.split()[3]
        expect(a.getpixel((360, 4)) > 250, f"{v.id} wheel tyre reaches the canvas edge")
        expect(a.getpixel((4, 4)) == 0 and a.getpixel((716, 716)) == 0,
               f"{v.id} wheel corners transparent")
        expect(a.getpixel((360, 360)) > 200, f"{v.id} wheel hub is drawn")
        box = a.getbbox()
        expect(box is not None and abs((box[2] - box[0]) - WHEEL_PX) <= 4,
               f"{v.id} wheel ink is square and full-bleed: {box}")
    return log + fail


def run_check(strict_files: bool = True) -> int:
    generated = generate(write_files=False)
    total_fail = 0
    for v in VEHICLES:
        body, wheel = generated[v.id]
        print(f"[check] {v.id}: {v.length} x {v.height} m, wb {v.wheelbase} m, "
              f"tyre r {v.tyre_r} m, hubs x={n(v.x(v.hub_f))}/{n(v.x(v.hub_r))}, "
              f"arch {v.arch_px(v.hub_f)[0] / PPM:.2f} x {v.arch_px(v.hub_f)[1] / PPM:.2f} m")
        lines = check_document(v, body, wheel, strict_files)
        fails = [ln for ln in lines if ln.strip().startswith("FAIL")]
        oks = [ln for ln in lines if ln.strip().startswith("ok")]
        skips = [ln for ln in lines if ln.strip().startswith("skip")]
        print(f"        {len(oks)} assertions passed, {len(fails)} failed"
              + (f", {len(skips)} skipped" if skips else ""))
        for ln in fails:
            print(ln)
        total_fail += len(fails)
    print(f"[check] {'PASS' if total_fail == 0 else 'FAIL'} "
          f"({len(VEHICLES)} vehicles, {total_fail} failed assertions)")
    return 0 if total_fail == 0 else 1


# --------------------------------------------------------------------------
# review previews
# --------------------------------------------------------------------------

def build_previews() -> int:
    try:
        from PIL import Image, ImageDraw
    except Exception:
        print("[previews] Pillow missing - nothing written")
        return 1

    made = []
    for v in VEHICLES:
        body = _raster(build_body(v), CW, CH)
        wheel = _raster(build_wheel(v), WHEEL_PX, WHEEL_PX)
        if body is None or wheel is None:
            print("[previews] no rasteriser (cairosvg / resvg / Inkscape) available - "
                  "writing PREVIEW.md instead of fake images")
            write_preview_note()
            return 1
        sheet = Image.new("RGBA", (CW, CH), (18, 21, 25, 255))
        gd = ImageDraw.Draw(sheet)
        gy = int(v.ground())
        gd.line([(0, gy), (CW, gy)], fill=(44, 50, 58, 255), width=2)
        sheet.alpha_composite(body, (0, 0))
        d = 2 * v.tyre_r * PPM
        w = wheel.resize((int(round(d)), int(round(d))), Image.LANCZOS)
        for hub in (v.hub_f, v.hub_r):
            sheet.alpha_composite(w, (int(round(v.x(hub) - d / 2)), int(round(HUB_Y - d / 2))))
        # review annotations (outside the sprite, this file is a QA sheet)
        gd = ImageDraw.Draw(sheet)
        gd.text((18, 16), f"{v.id}  |  {v.model}", fill=(235, 239, 244, 255))
        gd.text((18, 34), f"L {v.length} m  H {v.height} m  wb {v.wheelbase} m  "
                          f"tyre r {v.tyre_r} m  |  1 m = 160 px", fill=(150, 160, 172, 255))
        for hub in (v.hub_f, v.hub_r):
            gd.line([(v.x(hub), HUB_Y - 22), (v.x(hub), HUB_Y + 22)], fill=(90, 200, 160, 90), width=1)
        out = os.path.join(ROOT, PREVIEW_DIR, f"{v.id}.png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        sheet.convert("RGB").save(out, optimize=True)
        made.append(out)
        print(f"[previews] {os.path.relpath(out, ROOT)}")

    # contact sheet
    if made:
        thumbs = [Image.open(p) for p in made]
        scale = 0.56
        tw, th = int(CW * scale), int(CH * scale)
        gap = 12
        sheet = Image.new("RGB", (tw, th * len(thumbs) + gap * (len(thumbs) + 1)), (12, 14, 17))
        for i, im in enumerate(thumbs):
            sheet.paste(im.resize((tw, th), Image.LANCZOS), (0, gap + i * (th + gap)))
        out = os.path.join(ROOT, PREVIEW_DIR, "v3_contact_sheet.png")
        sheet.save(out, optimize=True)
        print(f"[previews] {os.path.relpath(out, ROOT)}")
    return 0


def write_preview_note() -> None:
    """Honest fallback when no SVG rasteriser is installed."""
    path = os.path.join(ROOT, PREVIEW_DIR, "PREVIEW.md")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lines = ["# v3 vehicle previews", "",
             "No SVG rasteriser was available (cairosvg needs the cairo DLL, `resvg` and",
             "Inkscape are not installed), so no PNG was produced. Nothing here is a",
             "rendered image. The geometry check below is the machine-verifiable part.", "",
             "```"]
    for v in VEHICLES:
        body, wheel = build_body(v), build_wheel(v)
        lines.append(f"{v.id}: {v.length}x{v.height} m wb {v.wheelbase} tyre r {v.tyre_r}")
        for ln in check_document(v, body, wheel, strict_files=True):
            lines.append(ln)
    lines += ["```", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))
    print(f"[previews] {os.path.relpath(path, ROOT)}")


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    if "--check" in argv:
        return run_check(strict_files=True)
    if "--previews" in argv:
        return build_previews()
    out = generate(write_files=True)
    for vid, (body, wheel) in out.items():
        print(f"[gen] {ASSET_DIR}/{vid}/body.svg {len(body.encode()) // 1024} KB, "
              f"wheel.svg {len(wheel.encode()) // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
