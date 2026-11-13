# MUDRO — Architecture

## Engine and global settings

| Setting | Value | Why |
|---|---|---|
| Engine | Godot 4.7.2 stable | locked by the project brief |
| Renderer | GL Compatibility | Adreno 610 / Mali class mobile GPUs; no Vulkan requirement |
| Physics tick | 120 Hz | stable stiff springs and contact at 64 px/m |
| World scale | 64 px = 1 m (`Units.PPM`) | single conversion boundary for SI forces |
| Gravity | 627.62 px/s² | = 9.80665 × 64 |
| Viewport | 1280 × 720, `canvas_items`, expand | landscape phone baseline |
| Scripting | typed GDScript throughout | static checking, readable contracts |

## Autoloads

| Autoload | Script | Responsibility |
|---|---|---|
| `Loc` | `scripts/core/loc.gd` | fa/en string tables, RTL direction, Vazirmatn font handles |
| `InputRouter` | `scripts/core/input_router.gd` | registers the shared action set (keyboard + touch) |
| `SettingsService` | `scripts/core/settings_service.gd` | volumes, language, quality, control sizing, haptics; persists `user://settings.json` |
| `SaveManager` | `scripts/core/save_manager.gd` | versioned profile, atomic writes, credits, records, unlocks, upgrades |
| `Content` | `scripts/core/content_db.gd` | builds every `Resource` (surfaces, vehicles, upgrades, stages) at boot |
| `AudioDirector` | `scripts/audio/audio_director.gd` | audio buses, cached one-shots, looped engine/ambience, UI sounds |
| `Router` | `scripts/core/scene_router.gd` | scene changes with a fade |
| `GameSession` | `scripts/core/game_session.gd` | current mode/stage/vehicle, result calculation |

## Data model

All gameplay data is `Resource` based:

```
VehicleDef            scripts/vehicle/vehicle_def.gd
├── EngineConfig      torque curve samples, inertia, friction, redline, turbo
├── GearboxConfig     ratios, reverse, final drive, efficiency, shift time
├── TireConfig        radius, wheel mass, mu scale, peak/slide slip
├── SuspensionConfig  rest length, travel, droop, spring/damper front+rear, bump stop
└── body polygon, drivetrain, brakes, clutch capacity, sprite paths

StageDef              scripts/stages/stage_def.gd
├── elevation keyframes (PackedVector2Array, metres)
├── surface spans (id ranges)
├── obstacle entries (kind, x, scale, rotation, solid)
└── checkpoints, medal times, rewards, seed

SurfaceProfile        scripts/terrain/surface_profile.gd
└── grip peak/slide, rolling resistance, bumpiness, colours, particles, sound

UpgradeDef            scripts/garage/upgrade_def.gd
└── category, tier, cost and real modifiers (torque, ratios, springs, grip, mass…)
```

`Content` builds these from typed tables at startup so there is one source of truth;
`GarageModel.build()` deep-copies a `VehicleDef` and applies owned upgrades, so the
garage changes the simulation, not a label.

## Scene map

| Scene | Script | Notes |
|---|---|---|
| `scenes/boot/boot.tscn` | `ui/boot.gd` | splash, then routes to the menu |
| `scenes/menus/main_menu.tscn` | `ui/main_menu.gd` | modes, continue, credits, language toggle |
| `scenes/menus/career.tscn` | `ui/career_screen.gd` | three region cards with real progress |
| `scenes/menus/stage_select.tscn` | `ui/stage_select.gd` | mode-aware stage grid, locks, medals |
| `scenes/garage/garage.tscn` | `ui/garage_screen.gd` | roster, live specification, purchase, selection |
| `scenes/garage/upgrades.tscn` | `ui/upgrade_screen.gd` | 7 categories × 3 tiers with real effects |
| `scenes/menus/settings.tscn` | `ui/settings_screen.gd` | audio, language, quality, controls, transmission |
| `scenes/menus/credits.tscn` | `ui/credits_screen.gd` | licensing and attribution |
| `scenes/race/race.tscn` | `race/race_scene.gd` | builds terrain, vehicle, camera, HUD, audio, timing |

UI is constructed in code through `scripts/ui/ui_kit.gd` (one theme, RTL-aware helpers,
`label` / `paragraph` / `value_label` so bidi cannot reorder numbers).
`RaceHUD` builds `TouchScreenButton`s that press the same InputMap actions as the keyboard.

## Frame flow

```
InputMap actions ──► RaceScene._read_input() ──► VehicleBody.set_inputs()
                                                   │
                                    _integrate_forces(state) @120 Hz
                                                   │
             raycast per axle ─► suspension force + tyre force + rolling resistance
             engine torque ──► clutch (locked/slipping) ──► gearbox ──► wheel torque
                                                   │
                                    RigidBody2D integrates
                                                   │
             telemetry dict ──► RaceHUD (speed, rpm, gear, damage)
                            ──► RaceEffects (slip-driven particles)
                            ──► AudioDirector loops (pitch from rpm)
```

`RaceScene` also owns checkpoints (x-crossing, more robust than area signals at speed),
recovery to the last checkpoint, fall detection, finish and result calculation.

## Save format

`user://profile.json`, version 3, written to `.tmp` then renamed with a `.bak` copy:

```json
{
  "version": 3,
  "credits": 1000,
  "xp": 120,
  "selected_vehicle": "ranger_4x4",
  "owned_vehicles": ["rocky_buggy", "ranger_4x4"],
  "records": {"canyon_01": {"best_time": 70.0, "medal": 3, "attempts": 2, "completed": true}},
  "upgrades": {"rocky_buggy": ["engine_1", "engine_2"]},
  "play_time_s": 0.0,
  "distance_m": 0.0
}
```

Settings live separately in `user://settings.json` (version 2).

## Performance notes

* One static body for the whole terrain (concave segment shape), one body per vehicle,
  one small body per solid obstacle — no per-pixel or per-vertex physics.
* Terrain is sampled once at build time (0.30 m) and rendered as a single polygon with
  vertex colours and a ground texture; surface bands are `Line2D`s.
* Particles are `CPUParticles2D` with small counts (16–70) and scale driven by context.
* SVG art is rasterised at import; textures stay ≤ 2400×1080.
* `SettingsService.quality` switches render scaling; 2D MSAA is disabled because GLES3
  does not support it (verified on the target GPU).
* The debug overlay is off by default and toggled with `F3`.

## Adding content

* **Stage** — add a `_mk(...)` entry in `scripts/stages/stage_catalog.gd` (elevation keyframes,
  surface spans, obstacles, checkpoints, medal times). It appears automatically in career order.
* **Vehicle** — add a `VehicleDef` block in `Content._build_vehicles()` with its own engine curve,
  ratios, tyres and suspension. Physics differences come from those numbers.
* **Surface** — add an entry in `Content._build_surfaces()`; grip, rolling resistance and
  colour are picked up by the tyre model and the terrain renderer.
