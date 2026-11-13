# MUDRO — Asset licenses

Every asset shipped with MUDRO is either created for this project or is a font under a
permissive license. Nothing is ripped, traced or downloaded from a commercial game, and no
manufacturer logos or trademarks are used.

## Summary

| Category | Count | Origin | License | Attribution |
|---|---|---|---|---|
| Vehicle art (body + wheel SVGs) | 8 | Original vector art authored for MUDRO | CC0 1.0 (project dedication) | not required |
| Environment art (sky/far/mid/near/ground SVGs) | 15 | Original vector art authored for MUDRO | CC0 1.0 | not required |
| Decoration art (rocks, log, stump, tree, bush, grass, blocks) | 10 | Original vector art authored for MUDRO | CC0 1.0 | not required |
| UI icons + emblem + launcher icon | 44 | Original vector art authored for MUDRO | CC0 1.0 | not required |
| Audio (engine loops, tyres, impacts, UI, ambience) | 27 | Synthesised numerically by `tools/asset_processing/gen_audio.gd` | CC0 1.0 | not required |
| Typeface Vazirmatn (4 weights) | 4 | Saber Rastikerdar | SIL Open Font License 1.1 | required — kept in Credits screen and below |
| Engine | 1 | Godot Engine 4.7.2 | MIT | required — kept in Credits screen |
| **2.0 control skins** | 20 | Original vector art authored for MUDRO (`tools/artgen/controls.py`) | CC0 1.0 | not required |
| **2.0 Black Ridge environment + props** | 11 | Original vector art authored for MUDRO (`tools/artgen/black_ridge.py`) | CC0 1.0 | not required |
| **2.0 audio additions** | 19 | Synthesised numerically by `tools/artgen/audio_v2.py` | CC0 1.0 | not required |

## Typeface — required attribution

**Vazirmatn** by Saber Rastikerdar.
SIL Open Font License, Version 1.1. The font is bundled locally (no runtime download) and is used
unmodified. Full license text: <https://github.com/rastikerdar/vazirmatn/blob/master/OFL.txt>

The in-game Credits screen repeats this attribution in both Persian and English.

## Engine

**Godot Engine 4.7.2 stable** — MIT License — <https://godotengine.org/license>

## Original work statement

All vehicle, environment and interface artwork was drawn as SVG paths specifically for MUDRO:
no third-party model, texture, sprite pack, HDRI or icon set is included. Vehicle names
(Rocky Buggy, Ranger 4x4, Dune Pickup, Titan Offroad) are fictional; no real manufacturer's
trade dress, grille, badge or logo is reproduced.

All sound is generated from oscillators, noise and envelopes inside
`tools/asset_processing/gen_audio.gd`, then written as 16-bit PCM WAV. No sample library, no
downloaded sound effect and no audio extracted from another game is used.

## Commercial use

The project's own art and audio may be used commercially as CC0 1.0. The Vazirmatn font may be
used commercially under the OFL provided the attribution above is preserved. The Godot Engine may
be used commercially under the MIT license.

## Provenance of the art pipeline

The SVGs were produced in this repository, validated with `tools/validate_svg.gd`
(`Image.load_svg_from_string`) and rasterised by Godot's own importer. That validator is also the
reason the files contain only ThorVG-safe features: paths, gradients, opacity and strokes — no
filters, masks, clip paths, patterns, embedded images or text.

A machine-readable register is in `docs/ASSET_LICENSES.csv`.

## MUDRO 2.0 additions

Everything added for 2.0 is original and generated inside this repository:

| Asset group | Files | Generator | License |
|---|---|---|---|
| Industrial control skins (buttons, pedals, slider, H-pattern gate, knob, icons) | 20 SVGs in `assets/ui/controls/` | `tools/artgen/controls.py` | CC0 1.0 |
| Black Ridge sky/far/mid/near/ground + industrial props + steel bridge | 11 SVGs in `assets/environments/` | `tools/artgen/black_ridge.py` | CC0 1.0 |
| Winch, gearbox, clutch, turbo, surface, weather and high-rpm engine layers | 19 WAVs in `assets/audio/` | `tools/artgen/audio_v2.py` | CC0 1.0 |

No downloaded model, texture, HDRI, sprite pack or sound library was added. The 2.0
art was written as explicit SVG paths (ThorVG-safe: paths, gradients, opacity,
strokes) and the audio as numeric oscillators/noise with NumPy, then normalised to
−3 dBFS as 44.1 kHz mono 16-bit PCM.
