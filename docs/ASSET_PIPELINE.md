# MUDRO 3.0 — Asset Pipeline

**What this is:** how the art and audio in MUDRO 3.0 are authored, what the runtime expects from each file, which regions are using borrowed art today, and what is blocked (including the 3D route, which has not been executed). For maintainers and asset authors.
**Scope:** `assets/vehicles/**`, `assets/environments/**`, `assets/ui/**`, `assets/audio/**`, the generators in `tools/artgen/` and `tools/asset_processing/`, and the runtime consumers `scripts/core/art_lib.gd`, `scripts/race/backdrop.gd`, `scripts/terrain/terrain_builder.gd`, `scripts/vehicle/vehicle_visual.gd`. Licensing detail is not repeated here — see `docs/ASSET_LICENSES.md`.
**Version:** 1.0 — 2026-11-14 · code basis `project.godot` 3.0.0.

---

## 1. What ships

`assets/` contains exactly four file types: `.svg`, `.ttf`, `.wav`, `.json`. There is no raster image, no 3D file and no sampled audio anywhere in the tree.

| Class | Location | Files | Authored by |
|---|---|---|---|
| Vehicle sprites | `assets/vehicles/<id>/{body,wheel}.svg` | 18 (9 folders) | `tools/artgen/vehicles_v3.py` for the five 3.0 vehicles; four 2.0 folders remain with their own origin |
| Environment layers | `assets/environments/<env>/{sky,far,mid,near,ground}.svg` | 20 (4 environments) | `tools/artgen/black_ridge.py` (2.0-era generator) |
| Shared decor | `assets/environments/common/*.svg` | 16 | same generator family |
| UI icons and control skins | `assets/ui/icons/*.svg`, `assets/ui/controls/*.svg` | 42 + 20, plus `emblem.svg` | `tools/artgen/controls.py` |
| Typeface | `assets/fonts/Vazirmatn-*.ttf` | 4 weights | Third party, SIL OFL 1.1 — the only third-party asset |
| Audio | `assets/audio/*.wav` | 46 | 27 from `gen_audio.gd`, 19 from `tools/artgen/audio_v2.py` |
| Strings | `assets/i18n/{fa,en}.json` | 2 | Project |

Nine vehicle folders exist, but only five are referenced by `VehicleCatalog`: `jimny_jb74`, `hilux_an120`, `patrol_y61`, `pajero_v80`, `lc79`. The four legacy folders (`rocky_buggy`, `ranger_4x4`, `dune_pickup`, `titan_offroad`) are dead art kept on disk; nothing loads them, because `sprite_body` is built from the vehicle id.

---

## 2. Vehicle sprites

### 2.1 The art contract

Both files are SVG with an explicit pixel canvas, because `VehicleVisual` maps them by exact pixel dimensions:

| File | Canvas | Contract |
|---|---|---|
| `body.svg` | **1600 × 720 px**, `viewBox="0 0 1600 720"` | 1 m = **160 art px**. Wheelbase midpoint at x = 800. **Axle line at y = 400.** Front hub at `800 + wheelbase_m × 80`, rear hub at `800 − wheelbase_m × 80`. Wheel arches cut transparent; everything else painted. |
| `wheel.svg` | **720 × 720 px**, tyre centred on (360, 360) | The tyre fills the canvas edge to edge — the canvas is not a frame around a small wheel. |

The 160 px/m scale is data, not a convention: `VehicleDef.art_scale_px_per_m = 160.0` and the sprite paths come from the vehicle id (`vehicle_catalog.gd:367-369`).

### 2.2 How the runtime maps it

`VehicleVisual.setup()` (`scripts/vehicle/vehicle_visual.gd:31-64`):

```
body_sprite.scale   = Units.PPM / art_scale_px_per_m = 64 / 160 = 0.4
body_sprite.position.y = com_height_m × 64 − (400 − 720/2) × 0.4
wheel.scale         = (2 × radius_m × 64) / texture_width
```

Two consequences that break naive art:

- **The axle line must be y = 400.** The body sprite is offset so that the artwork's y = 400 row lands on the simulated axle height. Move the artwork's wheels and the sprite floats or sinks relative to its own suspension.
- **The wheel must fill its 720 px canvas.** The scale factor is `target_px / texture_width`, so a 128 px tyre drawn inside a 720 px frame renders 5.6× too small. This is why the generator's docstring is emphatic about edge-to-edge.

At 160 px/m the body canvas is 10 m × 4.5 m, comfortably larger than the longest vehicle (5.235 m) — the extra width is the space the arches and overhangs need.

### 2.3 Authoring

`tools/artgen/vehicles_v3.py` is a deterministic generator: paths, polygons, circles and gradients only — no filters, no text, no external references, no randomness. It is checked in with three modes documented in its header:

```powershell
py tools/artgen/vehicles_v3.py            # regenerate every sprite
py tools/artgen/vehicles_v3.py --check    # parse + assert the contract
py tools/artgen/vehicles_v3.py --previews # review PNGs (needs resvg-py)
```

**These commands could not be run on this machine** — no Python interpreter is available (see §7). The SVGs on disk are the authoritative output; treat them as frozen source.

Style rules the generator enforces and new art should follow: no `<filter>`, no `<text>`, no external `<image>`, no `href` to anything outside the file, a hard size budget of 60 KB per sprite, and geometry derived from the real dimensions (wheelbase, length, height) rather than drawn by eye.

---

## 3. Environment art

### 3.1 Layers and sizes

Five layers per environment. The sizes are **not** uniform across the four environments, and that is visible in game:

| Environment | sky | far / mid / near | ground |
|---|---|---|---|
| `canyon` | 1920 × 1080 | 2400 × 1080 | 512 × 512 |
| `pine` | 1920 × 1080 | 2400 × 1080 | 512 × 512 |
| `quarry` | 1920 × 1080 | 2400 × 1080 | 512 × 512 |
| `black_ridge` | 1920 × 1080 | **1600 × 720** | 512 × 512 |

The sky is stretched to cover the 1280 × 720 viewport (`STRETCH_KEEP_ASPECT_COVERED`), so 1920 × 1080 is the right authoring size — a 16:9 canvas that cannot run out of pixels on a wider phone.

The parallax layers are **tiled horizontally**, not stretched: `Backdrop` creates a `TextureRect` of `3 × texture width` with `STRETCH_TILE` and texture repeat enabled, and scrolls it at 0.03 / 0.07 / 0.13 of camera motion (vertical 0.05 / 0.10 / 0.18). A 2400 px layer is therefore a 2400 px seamless tile; the left edge must match the right edge or the seam will crawl across the screen. `black_ridge` still uses 1600 × 720 layers from the 2.0 pass, which tile correctly but at a visibly coarser scale than the other three.

Quality gating: Low draws `near` only, Medium `mid + near`, High all three (`backdrop.gd:40-44`).

### 3.2 Ground

`ground.svg` is a **512 × 512 seamless tile**, not a full-scene backdrop. `TerrainBuilder` builds one `Polygon2D` strip 26 m deep under the road and assigns UVs of `(x / 220, y / 220)` in pixels, with texture repeat enabled. That means one tile every 220 px, i.e. every **3.44 m** of road at 64 px/m — the tile is a material, and it must be seamless in both axes.

The strip is built from five vertex rows per sample: offset 0, 0.12, 0.5, 2.4 and 26 m below the road surface, each shaded from the surface's `color_top` toward `color_deep` with a `pow(t, 0.72)` ramp and a small lightening on the top three rows. So the ground is **vertex-tinted**, and a texture that is too dark or too saturated will fight the tint.

### 3.3 Decor

Decor sprites live in `assets/environments/common/` and are drawn by `TerrainBuilder._build_scenery()` as `Sprite2D` nodes with **no collider of any kind** — `decor_collider_count()` returns 0 by design and the tests assert it. Spacing is `9.0 / decor_density` metres with ±40 % jitter, from x = 6 m to `length − 4 m`.

*Back* kinds sit at `z_index = -6` and are modulated to 0.86/0.88/0.90 (pushed toward the sky); *front* kinds sit at `z_index = 3`, modulated to 0.62/0.62/0.64 and offset 10 px down. Both are scaled by `Units.PPM / 160` in `_make_decor()`, so decor is authored at the same 160 px/m as the vehicles.

Per-region kind lists (`terrain_builder.gd:_scenery_kinds()`):

| Region | Back | Front |
|---|---|---|
| zagros | `rock_a`, `rock_b`, `bush` | `grass_tuft`, `rock_b` |
| alpine | `snow_rock`, `rock_a`, `pine_tree` | `snow_rock`, `grass_tuft` |
| pine | `pine_tree`, `stump`, `bush` | `bush`, `grass_tuft` |
| black_ridge | `ash_rock`, `ore_cart`, `pipe_stack` | `ash_rock`, `grass_tuft` |
| glacier | `snow_rock`, `rock_a`, `snow_rock` | `snow_rock` |

### 3.4 The real state of the three new regions

`assets/environments/` contains **four** folders: `black_ridge`, `canyon`, `pine`, `quarry` — plus `common`. There is **no** `zagros/`, `alpine/` or `glacier/` directory.

Those three regions therefore run on borrowed art, resolved at runtime by `ArtLib.REGION_ALIAS` (`scripts/core/art_lib.gd:9-13`):

| Region | Alias | What actually loads |
|---|---|---|
| `zagros` | `canyon` | canyon sky/far/mid/near and canyon ground; decor falls through to `common/` |
| `alpine` | `quarry` | quarry sky/far/mid/near and quarry ground; decor from `common/` |
| `glacier` | `quarry` | the same quarry layers as `alpine` |

The lookup order in `ArtLib.env()` is: exact region path → alias path → `canyon/ground.svg` for the ground layer → `null`. `ArtLib.decor()` is: exact → alias → `common/<kind>`. `TerrainBuilder` additionally falls back to `canyon/ground.svg` if the region lookup fails, and the terrain vertex tint is region-specific (`_road_tint()`), which is why Zagros reads warm and Glacier cool even though both are painting the same canyon texture.

**Consequence:** Zagros, Alpine and Glacier are distinguishable by grade, surface, tint and decor — not by their own sky. This is the largest visual debt in 3.0 and it is a content task, not a code task: dropping five correctly-sized SVGs into `assets/environments/<region>/` makes the alias irrelevant with no code change.

---

## 4. UI art

- 42 icons in `assets/ui/icons/` (medals, drivetrain, settings, transport, gauges).
- 20 control skins in `assets/ui/controls/`: `gate_knob`, `gate_panel` and `frame_plate` for the gear lever; padded button and pedal faces; slider rail and knob; five icon overlays (`icon_drivetrain`, `icon_gear`, `icon_suspension2`, `icon_weather`, `icon_winch`).
- `emblem.svg` and the launcher `icon.svg` at the project root.

`GearPanel` draws its gate from data, not from art: the plate texture is only a 10 % overlay, and the gate lines, nodes, labels and clutch bar are drawn in `_draw()`. That is deliberate — the slot drawn on the phone cannot disagree with the gearbox's legal gears, because both come from the same `TransmissionProfile`.

Art is loaded through `ArtLib.icon()` / `ArtLib.control()`, both cached and both tolerant of a missing file: a missing texture degrades to a drawn placeholder rather than a crash.

---

## 5. Audio

### 5.1 What exists

46 WAV files, all 44.1 kHz, 16-bit, mono, RIFF/WAVE. 27 are produced by `tools/asset_processing/gen_audio.gd`; the other 19 are 2.0-era additions produced by `tools/artgen/audio_v2.py` (see `docs/ASSET_LICENSES.md` §4). Only the GDScript generator can be re-run on this machine.

Groups in the GDScript generator: 7 engine assets (`engine_buggy`, `engine_ranger`, `engine_pickup`, `engine_titan`, `engine_idle`, `engine_start`, `engine_stall`), 2 drivetrain (`shift`, `clutch`), 4 tyre (`tire_roll_gravel`, `tire_roll_dirt`, `skid`, `mud_loop`), 5 one-shots (`water_splash`, `impact_rock`, `impact_wood`, `land_thud`, `suspension_creak`), 3 progress (`checkpoint`, `finish`, `medal`), 3 UI (`ui_click`, `ui_confirm`, `ui_back`) and 3 ambience (`ambience_canyon`, `ambience_pine`, `ambience_quarry`).

The 19 that are **not** in the generator: the four `engine_*_high` layers, `bridge_rumble`, `clutch_engage`, `clutch_release`, `gear_engage`, `gear_grind`, `rain_loop`, `snow_crunch`, `suspension_bottom`, `tire_roll_rock`, `turbo_spool`, `ui_tick`, `weather_thunder`, `winch_loop`, `winch_strain`, `wind_loop`.

### 5.2 How the synthesis works

`gen_audio.gd` is a `SceneTree` script that writes WAVs from mathematics only — no samples, no network, no unseeded randomness.

```powershell
godot --headless --path <project> --script res://tools/asset_processing/gen_audio.gd
   ... -- --list                  # print asset names, groups, loop flags
   ... -- --only=ui_click,medal   # subset by name
   ... -- --group=engines         # subset by group
   ... -- --verbose               # centroid / band diagnostics
```

Primitives: additive sine stacks, a combustion pulse train (cosines summed in phase), one-pole and biquad filters, damped modal resonators, granular noise grains, pitch-swept sines and thuds, and a small Schroeder room for one-shots.

**Loop locking** is the part that matters for game audio:

- every tonal partial is snapped to an integer number of cycles inside the loop length (`_snap_even`), so the fundamental and its octave-down sub both close at the seam;
- "detune" is implemented as a second partial exactly one loop bin away (`1 / loop_duration`), so the beat between the pair returns to zero exactly at the seam;
- every LFO uses a whole number of cycles per loop;
- noise beds are filtered **circularly** — the filter state carries across several passes — which converges to the periodic steady state instead of fading the tail out.

**Mastering and verification.** Each buffer has its DC removed, one-shots get a 1.5 ms / 10 ms edge fade, the peak is normalised to −3.00 dBFS, and the file is written and then **read back** and checked: RIFF/WAVE header, mono, 44100 Hz, 16-bit, non-silent, peak, RMS, DC offset and — for loops — a seam ratio `|first − last| / p99(step)`. A failing asset is reported and the process exits non-zero. `--verbose` adds band energy and a spectral centroid.

### 5.3 Engine audio mapping — naming debt

The engine loops are named after the **2.0 fictional** vehicles, and `RaceScene._build_audio()` maps the 3.0 roster onto them by acoustic character (`race_scene.gd:210-221`):

| 3.0 vehicle | Loop used |
|---|---|
| `jimny_jb74` | `engine_buggy` |
| `patrol_y61` | `engine_pickup` |
| `pajero_v80` | `engine_ranger` (the default) |
| `lc79` | `engine_titan` |
| `hilux_an120` | `engine_ranger` (the fall-through default) |

So the Hilux and the Pajero currently share one engine sound, and none of the five loops was synthesised from the 3.0 engine data (displacement, cylinder count, firing order). The `_engine_params()` table does encode character — a "buggy" twin, an even inline four, an uneven V8, a heavy diesel — but those were 2.0 archetypes. Renaming and re-voicing the set is an open content task; the generator makes it cheap, because a new engine is a parameter block.

Ambience is data-driven per region (`TrackCatalog.REGIONS[].ambience`): Zagros → `ambience_canyon`, Alpine → `ambience_quarry`, Pine → `ambience_pine`, Black Ridge → `ambience_canyon`, Glacier → `ambience_quarry`. `RaceScene` verifies the file exists and falls back to `ambience_quarry`, then `ambience_canyon`.

---

## 6. What is project-original

Everything under `assets/` except the typeface:

- **Vehicle bodies and wheels** — vector geometry generated for this project from the vehicles' real dimensions. No manufacturer drawing, photograph or model was traced. No logos, badges, wordmarks or grille badges appear in the art.
- **Environment layers and decor** — SVG emitted by project generators using only paths, polygons, rects, ellipses, groups, gradients and opacity. No raster, no filters, no external references.
- **UI art** — icons, control skins and the emblem, generated by `tools/artgen/controls.py`.
- **Audio** — 46 WAVs synthesised from mathematics in the two project generators. No sample libraries, no recordings.
- **Typeface** — Vazirmatn 33.003, SIL OFL 1.1, unmodified, four weights. The only third-party asset in the repository, and the only one that carries a redistribution condition.

The generators are self-contained and deterministic, which is what makes the "no third-party input" claim checkable rather than a promise: re-running a generator reproduces byte-identical output.

---

## 7. The blocked 3D route

**Status: not executed. No 3D asset exists in this project.**

The facts, as they stand on this machine:

- **Blender is not installed.** No `.blend` file exists anywhere in the repository, and no Blender executable was available at any point during this work.
- **Python is not available.** The repository's art generators are Python (`tools/artgen/vehicles_v3.py`, `controls.py`, `black_ridge.py`, `audio_v2.py`) and cannot be re-run here. (`vehicles_v3.py` documents a `py` launcher; that instruction could not be followed on this machine.)
- **Nothing 3D is referenced by the code.** A search of every `.gd`, `.tscn`, `project.godot` and `.cfg` in the tree finds no `MeshInstance3D`, `ArrayMesh`, `Skeleton3D`, glTF or FBX reference. `assets/` contains no 3D file type at all.
- **The renderer is 2D.** The project is `gl_compatibility`, a `Node2D` scene tree, and every visual is a `Sprite2D`, `Polygon2D`, `Line2D`, `TextureRect` or `CPUParticles2D`. There is no camera projection other than the orthographic 2D `Camera2D`.

So: **no 3D model was imported, no model was authored, and no 3D pipeline was run.** Any statement that MUDRO 3.0 contains 3D vehicle models would be false.

### 7.1 The intended pipeline, if Blender becomes available

Described here as a future step only. None of it has been executed, and none of it is required for the game to run — the current sprites are complete and load correctly.

1. **Model** each vehicle in Blender at real dimensions: wheelbase, track, overall length/height taken from `docs/VEHICLE_SPEC_SOURCES.md`, wheels as separate objects centred on their own origins.
2. **Match the art contract** rather than inventing a new one: orthographic side camera, 1 m = 160 px, axle line at y = 400 of 720 (55.6 % down the canvas), body canvas 1600 × 720, wheels exported on a 720 × 720 canvas with the tyre filling it edge to edge.
3. **Render** an orthographic side view with a flat, unlit or lightly-lit material set, transparent background, at exactly the canvas size — no post-scaling, because `VehicleVisual` maps by pixel dimensions.
4. **Convert to SVG** (trace the render, or export line work directly) or amend `VehicleDef.sprite_body`/`sprite_wheel` to accept a PNG, which would require a code change: the loader uses `load()` on the path in the definition, so a `.png` would work, but the pixel-size contract still applies.
5. **Validate** against the contract numerically: canvas size, axle-line row, tyre diameter in pixels, and a visual check that the arch openings line up with the wheel sprites at `radius_m × 2 × 64` px.

The reason to keep the contract is that it is the only thing tying art to physics. A 3D-derived sprite that misses y = 400 by 10 px will make every vehicle look like it is riding on its rims, no matter how good the model is.

---

## 8. Known gaps

1. **No dedicated art for Zagros, Alpine or Glacier** (§3.4). Three of five regions borrow canyon/quarry layers.
2. **`black_ridge` parallax layers are 1600 × 720** while the other three environments are 2400 × 1080, so its backdrop reads at a different scale.
3. **Four legacy vehicle art folders remain** and are unreferenced.
4. **Engine audio is named and voiced for 2.0 vehicles**, and the Hilux shares the Pajero's loop (§5.3).
5. **19 of 46 audio assets have no re-runnable generator** on this machine — their source is Python.
6. **The SVG generators cannot be executed here** (no Python), so all vector art is effectively frozen source rather than reproducible output.
7. **No 3D anything** (§7), and no path to one without installing Blender and Python first.
8. **Ground tiling is fixed at 220 px per tile.** A new ground texture with a different feature scale cannot be compensated for without editing `TerrainBuilder`, because the UV divisor is a constant rather than a per-surface property.
