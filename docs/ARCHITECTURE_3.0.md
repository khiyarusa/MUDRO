# MUDRO 3.0 — Architecture

**What this is:** the structural reference for MUDRO 3.0 — global engine settings, autoloads and boot order, the data model, the track build pipeline, the physics tick and its unit boundary, which file owns what, and how to build, run and test. For maintainers.
**Scope:** everything under `scripts/`, `scenes/`, `tests/`, `tools/` and the two project files. Player-facing feature documentation is in `docs/MUDRO_3.0.md`; the subsystems have their own documents (`MOUNTAIN_TRACK_DESIGN.md`, `VEHICLE_DATABASE.md`, `TUNING_SYSTEM.md`, `ENGINE_THERMAL_SYSTEM.md`, `TRANSMISSION_3.0.md`, `ASSET_PIPELINE.md`).
**Version:** 1.0 — 2026-11-14 · code basis `project.godot` 3.0.0, Godot 4.7.2 stable.

---

## 1. Global settings

| Setting | Value | Why it is that value |
|---|---|---|
| Engine | Godot 4.7.2 stable | Pinned in `tools/local_build/common.ps1` (`RequiredVersion`) and verified at every build |
| Renderer | GL Compatibility | Adreno 610 / Mali class mobile GPUs; no Vulkan requirement |
| Physics tick | 120 Hz, max 8 steps/frame | Stiff suspension springs and contact at 64 px/m |
| World scale | 64 px = 1 m (`Units.PPM`) | The single conversion boundary for SI forces |
| Gravity | 627.62 px/s² | 9.80665 × 64 |
| Viewport | 1280 × 720, `canvas_items`, `expand`, sensor landscape | Landscape phone baseline; `expand` keeps the HUD usable on taller screens |
| Scripting | Typed GDScript | Static checking; almost every function has explicit types |
| Version | 3.0.0 / versionCode 300 | `project.godot`, `export_presets.cfg` |
| Package | `com.khiyarusa.mudro`, arm64-v8a only, immersive | `export_presets.cfg` |
| User directory | `user://` → custom dir `MUDRO` | `config/use_custom_user_dir` |

Art is authored at **160 px/m** and drawn at 64 px/m (`Units.PPM / art_scale_px_per_m = 0.4`). Two scales, one conversion — see `docs/ASSET_PIPELINE.md` §2.

---

## 2. Autoloads and boot order

`project.godot` registers eight autoloads. Order matters: each one may use the ones above it, never below.

| # | Autoload | Script | Responsibility |
|---|---|---|---|
| 1 | `Loc` | `core/loc.gd` | fa/en string tables, RTL direction, font handles |
| 2 | `InputRouter` | `core/input_router.gd` | The keyboard/gamepad action set |
| 3 | `SettingsService` | `core/settings_service.gd` | Audio, language, quality, control preset/layout/sensitivity, clutch assist, haptics; `user://settings.json` |
| 4 | `Content` | `core/content_db.gd` | Builds every runtime resource from typed tables: 13 surfaces, 5 vehicles, 526 parts, 5 regions, 15 tracks |
| 5 | `SaveManager` | `core/save_manager.gd` | The v5 profile, migration, records, credits, garage, presets, wear; `user://profile.json` |
| 6 | `AudioDirector` | `audio/audio_director.gd` | Buses, cached one-shots, looped engine/ambience players, UI sounds |
| 7 | `Router` | `core/scene_router.gd` | Scene changes with a 0.24 s fade |
| 8 | `GameSession` | `core/game_session.gd` | Current track/vehicle/mode, the built vehicle for this run, result calculation, ambient temperature |

Boot flow: `scenes/boot/boot.tscn` (splash, 0.9 s bar) → after 1.15 s `Router.goto("res://scenes/menus/main_menu.tscn")`. `SaveManager._ready()` loads and migrates the profile *after* `Content` has filled the catalogue, which is why migration can map legacy ids onto real 3.0 ids.

`Content` order inside `_ready()`: surfaces → vehicles → parts → regions → tracks. Parts are built *from* the vehicles (each vehicle generates its own catalogue section), so vehicles must exist first.

---

## 3. Data model

```
Content (autoload)
├── surfaces: Dictionary[id → SurfaceProfile]          terrain/surface_profile.gd
├── vehicles: Array[VehicleDef]                        vehicle/vehicle_def.gd
├── parts:    Array[PartDef]                           parts/part_def.gd
├── regions:  Array[Dictionary]                        from TrackCatalog.REGIONS
└── tracks:   Array[TrackDef]                          tracks/track_def.gd

TrackDef
├── identity: id, region, name_fa/en, brief_fa/en, difficulty, modes
├── profile_segments: [{len, s_in, s_out}]  ──► TrackProfile (lazy, cached)
├── surface_sections: [{from, to, surface}]
├── checkpoints: PackedFloat32Array (metres, resolved from fractions)
└── timing: medal_gold/silver/bronze, rewards, reference_speed_mps

VehicleDef
├── identity + documented spec{} (with source reference)
├── mass/geometry: mass_kg, wheelbase, L/W/H, com_height, body_polygon, Cd, area
├── drivetrain: AWD/FWD/RWD, torque_split_front, brake torques, clutch capacity
├── engine data: family, code, aspiration, compression, cc, cylinders, boost,
│                injector/pump/radiator limits, torque_scale
├── components: EngineConfig, GearboxConfig (legacy mirror), TireConfig ×2,
│               SuspensionConfig, TransmissionProfile[]
├── configuration: tire_options, suspension_options
└── runtime (never authored): parts{}, part_conditions{}, engine_build,
    build_info{}, fitted_*, active_*, ride_height_add_m, protection, …

PartDef
├── identity: id, slot (41 values), names, description, cost, mass, tier
├── params: Dictionary — the numbers its subsystem consumes
├── fitment: engine_family, fits_vehicles
└── condition: Condition enum + wear_rate

EngineBuild  (derived, never authored)
├── displacement, flow_mult, boost, charge_temp, density_ratio, VE
├── peak torque/power + rpm, redline, idle, inertia, friction
├── fuel_limit_kw, fuel_limited, block_limited, cooling_marginal
└── thermal package: radiator_kw, coolant_l, pump/fan mult, thermostat_c

ThermalState  (runtime)
└── coolant_temp_c, ambient_c, capacity_l, radiator_kw, fan_on,
    heat_in/out_kw, damage_accum, warning, critical
```

### 3.1 TrackDef / TrackProfile

`TrackDef` is the authored resource; `TrackProfile` is the built interpolation. `TrackDef.profile()` builds lazily and caches on first use (`track_def.gd:62-68`), so fifteen tracks cost nothing until their statistics are asked for.

`TrackProfile` holds four parallel arrays — knot x, knot y, knot slope, built flag — and answers `elevation_at`, `slope_at`, `grade_deg_at`, `sample`, `knots` and the seven derived statistics. The full mathematics is in `docs/MOUNTAIN_TRACK_DESIGN.md` §6.

### 3.2 VehicleDef

One `Resource` per vehicle, with authored fields for the documented specification and a separate block of **runtime** fields (`parts`, `engine_build`, `build_info`, `active_transfer`, …) that `GarageModel` fills on a deep copy. The split is the invariant that keeps `Content` immutable: nothing in the simulation writes to an authored resource.

`spec` is a free-form dictionary carrying the published figures *and* the reference they came from, so the in-game spec sheet and `docs/VEHICLE_SPEC_SOURCES.md` can be compared mechanically.

### 3.3 PartDef

41 slots (`PartDef.Slot`), five condition states, one `params` dictionary. The contract is that `params` keys are named after the physics quantity they represent (`boost_bar`, `heat_reject_kw`, `spring_mult`), not after an effect (`power_up`). `docs/TUNING_SYSTEM.md` §3 is the authoritative per-slot key list, including which keys are dead.

### 3.4 EngineBuild

A `RefCounted` produced by `EngineBuild.derive(spec, parts)`. It owns the torque curve:

```
torque(rpm) = peak_torque × shape(rpm) × spool(rpm), capped by fuel_limit_kw
shape(x)    = (0.80 + 0.30·exp(−((x − x_peak)/0.34)²) − 0.55·max(0, x − x_peak − 0.26)²/0.22²) / 1.10
```

with `x = rpm / redline`. It also computes the thermal package, the fuel ceiling and three warning flags. `GarageModel` samples it into 14 points and writes them onto `EngineConfig.curve_rpm` / `curve_torque`, which is what `EngineState` interpolates at runtime — so the dyno, the garage and the car all read the same curve.

### 3.5 ThermalState

A single lumped coolant temperature with a first-order balance, integrated at the physics step. Equations, thresholds and worked examples: `docs/ENGINE_THERMAL_SYSTEM.md`.

### 3.6 GarageModel

`GarageModel.build(base, config)` is the **only** place a part becomes physics. It deep-copies, resolves parts (falling back to stock), derives the engine, and rebuilds transmission, clutch, suspension, tyres, brakes, mass, centre of mass, aero, durability, protection, winch, wading depth and light range. `docs/TUNING_SYSTEM.md` §6 lists every output and its source.

`GarageModel.sanitize_config()` is the repair pass for a corrupt or hand-edited save: unknown ids are dropped, mismatched slots are replaced with stock, conditions are clamped, and the result is guaranteed drivable.

### 3.7 SaveManager v5

`user://profile.json`, `VERSION = 5`, atomic writes (`.tmp` → `.bak` → target), starting credits 600.

```json
{
  "version": 5,
  "credits": 600, "xp": 0,
  "selected_vehicle": "jimny_jb74",
  "owned_vehicles": ["jimny_jb74"],
  "records": {
    "zagros_01": {"best_time": 61.5, "medal": 2, "attempts": 3,
                  "completed": true, "mode": "rally",
                  "by_vehicle": {"jimny_jb74": {"best_time": 61.5, "medal": 2}}}
  },
  "garage": {
    "jimny_jb74": {
      "parts": {"0": "jimny_jb74_block_s", "5": "jimny_jb74_head_s"},
      "owned": ["jimny_jb74_intake_sport"],
      "condition": {"jimny_jb74_intake_sport": 1,
                    "jimny_jb74_intake_sport:wear": 0.42},
      "presets": {"climb": {"0": "jimny_jb74_block_r"}},
      "transfer": "4L", "diff": "locked"
    }
  },
  "play_time_s": 0.0, "distance_m": 0.0,
  "created": "...", "migrated_from": 0
}
```

Notes on the schema:

- **`parts` is keyed by slot number as a string**, not by category or name, so a save cannot hold two parts in one slot.
- **Condition is an int 0–4** plus a hidden `"<part_id>:wear"` float accumulator for fractional wear.
- **`records` are per track and per vehicle** (`by_vehicle`), so a best time is attributable to the car that set it.
- **`migrated_from` records the original schema version** and is never cleared, which makes a migrated profile identifiable forever.

**Migration (v2–v5 → v5).** `_migrate()` fills missing keys from defaults, maps legacy vehicle ids by role, maps legacy stage ids onto 3.0 track ids (several old stages collapse onto one track), rewrites records keeping the best time / highest medal / summed attempts, converts 2.0 upgrade purchases into owned-and-fitted 3.0 parts, and deletes the obsolete `upgrades` and `config` dictionaries. Credits, XP, unlocks and purchases survive; nothing is reset. Full mapping tables: `save_manager.gd:22-52`.

---

## 4. The track build pipeline

`TerrainBuilder.build(track, surfaces)` (`scripts/terrain/terrain_builder.gd`) runs seven passes in a fixed order.

| # | Pass | Output | Cost |
|---|---|---|---|
| 1 | `_sample()` | Polyline of the road, every **0.35 m** from **−8 m** to `length + 12 m` | ≈ 2 915 points for a 1 000 m track |
| 2 | `_build_road()` | **One** `StaticBody2D` (`TrackBody`, layer 2) with one `ConcavePolygonShape2D` of `2 × (N−1)` points, plus **two** end walls | 1 body + 2 bodies |
| 3 | `_build_ground()` | One `Polygon2D` strip, 5 vertex rows per sample (0, 0.12, 0.5, 2.4, 26 m), vertex-coloured, ground texture repeated | 8 triangles per span |
| 4 | `_build_surface_paint()` | One `Line2D` per **authored section**, 5 px wide, +1 px, surface colour lightened 40 % | ≤ 7 lines |
| 5 | `_build_roadside_markers()` | One `Line2D` with a 1 m post every 25 m | 1 node |
| 6 | `_build_scenery()` | `Sprite2D` decor, spacing `9 / density`, seeded by `decor_seed` | ~100–150 nodes |
| 7 | `_build_start_gantry()` + `_build_gates()` | One gantry at `start_x_m()` (3 m), one `Area2D` per checkpoint, one finish gate | 1 + 3–4 nodes |

Five properties of this pipeline are load-bearing:

1. **Exactly one collision body carries the road.** Not one per segment, not one per sample. A single concave shape cannot disagree with itself, and it cannot develop interior seams.
2. **Two end walls, 6 m outside the road**, 1 m × 60 m at y = −20 m, on the same collision layer. They exist so a runaway car cannot leave the world, and they never touch the racing surface.
3. **Zero decor colliders.** `decor_collider_count()` and `obstacle_collider_count()` return `0` literally; the tests assert it. Scenery is `Sprite2D` and `Line2D` only.
4. **Surface identity is a pure function of distance.** `surface_id_at(x)` reads the track's authored sections, and both the painted line and the tyre model call it, so the ground colour and the grip can never disagree.
5. **Gates are `Area2D` with `collision_layer = 0` and `mask = 1`**, 1.2 m wide and 7 m tall, positioned at the profile height. They detect the car and cannot obstruct it.

Sampling bounds matter for the ends: the polyline starts 8 m before the start and ends 12 m after the finish, with elevation clamped to the profile, so the car always has ground under it before the timer starts and after it stops.

---

## 5. Physics tick and units

### 5.1 The unit boundary

Everything inside the simulation is SI. Pixels appear only when a force or a position crosses into Godot:

| Quantity | Inside | At the boundary |
|---|---|---|
| Length | metres | `m × 64` px |
| Force | newtons | `N × 64` px·kg/s² |
| Torque | N·m | `N·m × 64²` (only where a torque is applied to the body) |
| Inertia | kg·m² | `× 64²` |
| Wheel speed | rad/s | — (the wheel loop stays SI; `surface_speed = ω × r` in m/s) |
| Speed readout | m/s | `× 3.6` km/h |

`VehicleBody` converts the body's linear velocity once per step (`vel / Units.PPM`) and works in m/s thereafter, converting back only inside `state.apply_force(...)`.

### 5.2 Order of operations in `_integrate_forces(state)`

```
1  dt = state.step; guard dt <= 0
2  engine.update(dt, throttle)
3  thermal.update(dt, engine.power_kw(), forward_speed, throttle)
      if critical: accumulate heat damage, decay engine_health
4  clutch.manual_mode = manual_clutch_enabled or not auto_clutch
5  read transform → forward, down; velocity → forward_speed, lateral_speed
6  aero drag (0.5·ρ·Cd·A·v², opposing motion, deadband below 0.4 m/s)
7  external force (winch cable), if any
8  per axle: raycast → compression → spring + damper + bump stop
             → tyre slip → longitudinal force (bounded by µ·N)
             → rolling resistance (faded by slip)
             → landing detection
9  drivetrain: driven ω (contact-weighted) → clutch update → lock or slip
             → torque converter → per-axle share → wheel integrate
10 differential coupling (open / lsd / locked)
11 impact damage from |Δv| > 1.8 m/s
12 telemetry dictionary
```

Three invariants of this order: the engine and the cooling model are always integrated before the drivetrain reads their output; the tyre force is applied before the wheel integrates, so the reaction torque is the current one; and damage is evaluated last, from the velocity the solver actually produced.

### 5.3 What is *not* in the tick

- **No position writes.** Nothing teleports the chassis; the winch is a bounded central force, and the only `global_transform` assignment is `reset_motion()` on a restart.
- **No direct speed writes.** Speed emerges from torque, tyre force, gravity and drag.
- **No UI reads.** The simulation never reads an `Input` action or a `Control`; it reads a `VehicleInputState` that a driver source fills.

### 5.4 Per-step cost

Two raycasts, two tyre evaluations, one clutch solve, one differential blend, one thermal integration, one telemetry build. At 120 Hz with `max_physics_steps_per_frame = 8`, a 30 fps phone gets four physics steps per frame, and draw calls stay near the node count: one ground polygon, one road body, two wheel sprites and four suspension lines per vehicle.

---

## 6. File ownership map

Use this to answer "which file has to change".

| Concern | Owned by | Notes |
|---|---|---|
| Track data (regions, tracks, segments, medals) | `scripts/tracks/track_catalog.gd` | Editing this changes every derived number |
| Track maths (interpolation, statistics) | `scripts/tracks/track_profile.gd`, `track_def.gd` | No content here |
| Terrain, collision, decor, gates | `scripts/terrain/terrain_builder.gd` | The 3.0 builder |
| Surfaces (grip, colour, sound ids) | `scripts/core/content_db.gd:_build_surfaces()` | 13 profiles |
| Vehicle data | `scripts/vehicle/vehicle_catalog.gd` | One `DATA` row per vehicle |
| Vehicle schema | `scripts/vehicle/vehicle_def.gd` | Authored vs runtime split |
| Engine model | `scripts/parts/engine_build.gd` | Derived, no content |
| Parts catalogue | `scripts/parts/parts_catalog.gd` | Generated per vehicle |
| Part schema and slot enum | `scripts/parts/part_def.gd` | 41 slots |
| Install rules | `scripts/parts/part_compat.gd` | Refusals vs warnings |
| Parts → physics | `scripts/garage/garage_model.gd` | The only mutation point |
| Dyno maths | `scripts/garage/dyno_model.gd` | No caller yet |
| Cooling | `scripts/vehicle/thermal_state.gd` | Constants at the top |
| Transmission data | `scripts/vehicle/transmission_profile.gd` | Per-vehicle profiles |
| Gear selection, ranges, automatic schedule | `scripts/vehicle/gearbox_state.gd` | Rejections live here |
| Clutch | `scripts/vehicle/clutch_state.gd` | Pedal → engagement |
| Tyre + wheel | `scripts/vehicle/wheel_axis.gd` | Slip curve, force bound |
| Vehicle body / physics tick | `scripts/vehicle/vehicle_body.gd` | The integration order above |
| Sprite ↔ physics mapping | `scripts/vehicle/vehicle_visual.gd` | 160 → 64 px conversion |
| Persistence | `scripts/core/save_manager.gd` | Schema + migration |
| Runtime content access | `scripts/core/content_db.gd` | Every lookup |
| Scene flow | `scripts/core/scene_router.gd`, `scenes/**` | |
| Race composition | `scripts/race/race_scene.gd` | World, audio, HUD wiring |
| Weather | `scripts/race/weather_system.gd` | Six weather ids |
| Winch | `scripts/race/winch_system.gd` | Force, not teleport |
| Touch input | `scripts/input/touch_controls.gd` + widgets | One owner per finger |
| Gear lever UI | `scripts/input/gear_panel.gd` | Draws the gate from data |
| Menu screens | `scripts/ui/*.gd` | **Partially migrated — see §9** |
| Build and run | `tools/local_build/*.ps1` | Godot resolution, logs |
| 3.0 smoke probe | `tools/smoke_v3.gd` + `.tscn` | Prints builds and track stats |
| Test suite | `tests/test_runner.gd` | **2.0-era — see §7.3** |
| Art generators | `tools/artgen/*.py` | Python; not runnable here |
| Audio generator | `tools/asset_processing/gen_audio.gd` | GDScript; runnable |

---

## 7. Build, run and test

### 7.1 Prerequisites

- Godot **4.7.2 stable** exactly. `common.ps1` looks for `$env:GODOT_BIN`, then `H:\Game\Engines\Godot\editor\...`, then Program Files, then the user profile, and refuses a version mismatch.
- PowerShell 5.1 or later.
- Android export templates and build-tools only for the APK step.

### 7.2 Commands

```powershell
.\tools\local_build\import_project.ps1     # regenerate .godot cache, import SVG/WAV/fonts
.\tools\local_build\run_game.ps1           # desktop window, keyboard
.\tools\local_build\run_game.ps1 -Scene res://scenes/race/race.tscn -Autodrive
.\tools\local_build\run_tests.ps1          # headless suite, exit 0/1/2
.\tools\local_build\build_android_debug.ps1
```

`import_project.ps1` prints `Import complete.` on success and fails on `SCRIPT ERROR`, `Parse Error` or `Failed to load`. Import is required on a cold checkout because every `class_name` needs the global class cache; `Ensure-ProjectImported` re-imports automatically when `.godot/global_script_class_cache.cfg` is missing or older than the newest script.

The APK script writes `local-builds/android/MUDRO-2.0-debug.apk` (the filename inside the script is stale) while `export_presets.cfg` names `MUDRO-3.0-debug.apk`. Both produce a 3.0.0/300 package; only the filename differs.

### 7.3 Test state — read before trusting a green tick

- `tests/test_runner.gd` is the **2.0 suite**. It calls `Content.vehicle_by_id("ranger_4x4")`, `SaveManager.buy_upgrade()`, `SaveManager.has_upgrade()`, `SaveManager.vehicle_upgrades()`, `Content.stages_for()`, `SaveManager.is_stage_unlocked()` and the three-argument `GarageModel.build(base, upgrades, config)`. None of those exist in 3.0. Run against the current tree it fails at the first missing vehicle, so **it is not a gate for this release**.
- The last recorded all-pass log (`local-builds/logs/tests.log`, 157 assertions) belongs to the 2.0 tree; its vehicle names (`buggy_seq5`, `ranger_h5`, `pickup_auto6`, `titan_auto6`) prove it.
- The only check that exercises 3.0 data is `tools/smoke_v3.tscn`:

```powershell
.\tools\local_build\run_game.ps1 -Scene res://tools/smoke_v3.tscn
# or
godot --headless --path . res://tools/smoke_v3.tscn
```

It prints the derived build for all five vehicles and the statistics for all fifteen tracks, asserts torques within 10 % and powers within 15 % of the documented figures, asserts every track layout is valid and under 30°, exercises a turbo/fuel comparison, a 180 s cooling comparison and a legacy save migration, then exits non-zero on failure.

**As recorded** (`local-builds/logs/smoke_v3.log`) that probe currently reports failures: Hilux power, Pajero power and LC79 torque/power are outside tolerance, the "fuel system did not unlock power" assertion fails, and a `tyre_parts()` out-of-bounds script error is logged five times at boot. Those are documented in `docs/MUDRO_3.0.md` §12, not hidden here.

---

## 8. Invariants and where they are enforced

| Invariant | Enforced by | Verified by |
|---|---|---|
| One continuous collision body for the road (+2 end walls) | `terrain_builder.gd:_build_road()` | Reading the node tree; the code has no second road body |
| Zero decoration colliders | `decor_collider_count() == 0`, `obstacle_collider_count() == 0` | Intended by the test suite; currently only by the literal return |
| No teleporting, no speed writes | `vehicle_body.gd` has no position/velocity assignment outside `reset_motion()` | Code review |
| Authored resources never mutated | `GarageModel` deep-copies before every change | `duplicate_def()` at the top of `build()` |
| Track geometry is C1 and derived stats cannot drift | Slopes stored per knot; `stats()` computes from the profile | `TrackProfile` structure |
| Every displayed number comes from the same resource the physics reads | `build_info`, `RouteBriefing` (intended), `DynoModel` | Design; see §9 for the UI gap |
| Deterministic scenery | `decor_seed`, seeded `RandomNumberGenerator` | Repeated builds produce identical placement |
| SI inside, pixels only at the boundary | `Units` | Code review |

---

## 9. Known architectural problems

These are present in the tree today. They are listed so that nobody builds on top of a broken assumption.

1. **Duplicate global class name.** `scripts/stages/terrain_builder.gd` and `scripts/terrain/terrain_builder.gd` both declare `class_name TerrainBuilder`. Godot resolves one of them for the global name, which is a coin flip that happens to be correct today (the 3.0 builder is the one whose API the race scene uses) but is not guaranteed. The `scripts/stages/` folder is the entire 2.0 stage stack (`StageDef`, `StageCatalog`, obstacle terrain) and is dead code.
2. **The UI layer is still 2.0.** `main_menu.gd`, `stage_select.gd`, `career_screen.gd`, `route_briefing.gd`, `race_hud.gd`, `garage_screen.gd` and `upgrade_screen.gd` reference `Content.stages`, `Content.stages_for()`, `Content.stage_by_id()`, `SaveManager.is_stage_unlocked()`, `SaveManager.next_stage_after()`, `SaveManager.vehicle_upgrades()`, `SaveManager.buy_upgrade()`, `StageDef.route_stats()` and `UpgradeDef`. None of those exist in 3.0. `race_scene.gd:154` passes a `TrackDef` into `RaceHUD.setup(vehicle, def: StageDef, …)`, which is a type mismatch. The data and physics layers are 3.0; the menus on top of them are not.
3. **`GameSession` carries aliases to paper over the split** — `stage_id`, `stage_def()`, `start_stage()`, `next_stage()` all forward to track equivalents. They are useful for migration, but they also let 2.0-era code compile while doing the wrong thing.
4. **`UpgradeDef` still exists** (`scripts/garage/upgrade_def.gd`) and is used by `upgrade_screen.gd` and (transitively) `career_screen.gd`, even though the 3.0 economy is parts-based. Two upgrade models in one tree.
5. **The test suite is stale** (§7.3).
6. **`GarageModel.build()` replaced the transmission list with a single part-derived profile**, so a vehicle's catalogue alternates (the automatics) are unreachable from the 3.0 path (`docs/TRANSMISSION_3.0.md` §10).
7. **Two terrain builders, two physics stories.** `scripts/stages/terrain_builder.gd` still contains obstacle/bridge placement with colliders; nothing calls it, but a reader can easily believe MUDRO still has solid props.
