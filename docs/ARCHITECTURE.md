# MUDRO — Architecture (2.0)

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
| Version | 2.0.0 (versionCode 200) | `project.godot`, `export_presets.cfg` |

## Autoloads

| Autoload | Script | Responsibility |
|---|---|---|
| `Loc` | `core/loc.gd` | fa/en string tables, RTL direction, Vazirmatn handles |
| `InputRouter` | `core/input_router.gd` | keyboard action set (WASD, Q/E, T, G, L, R, I, Esc, F3) |
| `SettingsService` | `core/settings_service.gd` | audio, language, quality, control preset/layout/sensitivity, assist, haptics; `user://settings.json` v3 |
| `SaveManager` | `core/save_manager.gd` | versioned profile, atomic writes, records, credits, unlocks, upgrades, **driveline config**; `user://profile.json` v4 |
| `Content` | `core/content_db.gd` | builds every `Resource` at boot (surfaces, vehicles + transmissions, upgrades, environments, 16 stages) |
| `AudioDirector` | `audio/audio_director.gd` | buses, cached one-shots, looped engine/ambience, UI sounds |
| `Router` | `core/scene_router.gd` | scene changes with a fade |
| `GameSession` | `core/game_session.gd` | current mode/stage/vehicle, applied config, result calculation |

## Data model

```
VehicleDef                          scripts/vehicle/vehicle_def.gd
├── EngineConfig                    torque curve, inertia, friction, redline, turbo
├── GearboxConfig                   legacy stock view (kept for the derived profile)
├── TransmissionProfile[]           kind, ratios, final drive, shift, synchro,
│                                   clutch type/capacity, converter, auto schedule
├── TireConfig front/rear           radius, mass, mu, peak/slide slip
├── SuspensionConfig                rest, travel, droop, springs/dampers, bump stop
├── transfer_ids / transfer_ratios / default_transfer
├── diff_modes / default_diff
├── tire_options[] / suspension_options[]      garage-configurable
├── winch (force, rope, speed)
└── body polygon, drivetrain, brakes, clutch, sprite paths

StageDef                            scripts/stages/stage_def.gd
├── elevation keyframes, surface spans, obstacle entries, checkpoints, medals
├── weather id
└── route_stats()                   length, max/avg grade, surface split,
                                    obstacles, climbs, descents  (briefing data)

SurfaceProfile                      scripts/terrain/surface_profile.gd
TransmissionProfile                 scripts/vehicle/transmission_profile.gd
UpgradeDef                          scripts/garage/upgrade_def.gd
```

`Content` builds these from typed tables at startup. `GarageModel.build(base,
owned_upgrades, config)` deep-copies a `VehicleDef`, applies upgrades **and the
chosen gearbox / transfer / diff / tyres / suspension**, and returns the object the
simulation uses. The shared `Content` resources are never mutated.

## Input architecture

```
Keyboard ─┐
Touch    ─┼─► VehicleInputState ─► RaceScene._read_input ─► VehicleBody.set_input_state()
Gamepad  ─┘        ▲
                   └── TouchControls (CanvasLayer 25) — one owner per finger
```

* `core/vehicle_input.gd` — the shared contract; clamps, merges, copies.
* `input/touch_controls.gd` — pointer routing, presets, layout, persistence.
* `input/touch_widget.gd`, `touch_button.gd`, `touch_slider.gd`, `touch_pedal.gd`
  — visual + value only, never write to the vehicle.
* `input/gear_panel.gd` — H-pattern / sequential / PRNDL gate, projected onto the
  legal segments generated from the transmission data.

The simulation never reads an input action or a UI node. See `docs/CONTROLS.md`.

## Scene map

| Scene | Script | Notes |
|---|---|---|
| `scenes/boot/boot.tscn` | `ui/boot.gd` | splash → menu |
| `scenes/menus/main_menu.tscn` | `ui/main_menu.gd` | modes, continue, credits, language |
| `scenes/menus/career.tscn` | `ui/career_screen.gd` | four regions in a 2×2 grid, real progress |
| `scenes/menus/stage_select.tscn` | `ui/stage_select.gd` | mode-aware grid, locks, medals |
| `scenes/menus/route_briefing.tscn` | `ui/route_briefing.gd` | **new**: real route stats + driveline choice before the run |
| `scenes/garage/garage.tscn` | `ui/garage_screen.gd` | roster, specification, purchase, selection |
| `scenes/garage/vehicle_config.tscn` | `ui/vehicle_config.gd` | **new**: gearbox/transfer/diff/tyres/suspension |
| `scenes/garage/upgrades.tscn` | `ui/upgrade_screen.gd` | 7 categories × 3 tiers with real effects |
| `scenes/menus/settings.tscn` | `ui/settings_screen.gd` | audio, language, quality, control layout, assist, haptics |
| `scenes/race/race.tscn` | `race/race_scene.gd` | terrain, vehicle, camera, HUD, weather, winch, input layer |
| `ui/control_layout_editor.gd` | overlay | drag-to-place controls; saves normalized centres |

UI is built in code through `ui/ui_kit.gd` (one theme, RTL-aware helpers,
`value_label` so bidi cannot reorder numbers).

## Race composition

```
RaceScene (Node2D)
├── TerrainBuilder        heightfield, collisions, decor, obstacles, bridges
├── WeatherSystem         CanvasLayer particles/fog + grip/rr multipliers
├── CanvasModulate        environment tint × weather tint
├── Backdrop              CanvasLayer −20, parallax (quality-dependent layers)
├── Camera2D
├── VehicleBody           RigidBody2D + VehicleVisual (dampers, coil springs)
├── RaceEffects           CPUParticles2D driven by slip/surface
├── WinchSystem           Line2D cable + bounded external force
├── RaceHUD (CanvasLayer 20)
├── ControlLayer (CanvasLayer 25) ── TouchControls
└── DebugOverlay
```

## Frame flow

```
VehicleInputState ──► RaceScene ──► VehicleBody.set_input_state()
                                        │
                          _integrate_forces(state) @120 Hz
                                        │
             raycast per axle ─► suspension + tyre + rolling resistance
             engine torque ─► clutch (lock-up/slip) ─► gearbox
                          ─► transfer ratio ─► differential ─► wheel torque
                                        │
                              RigidBody2D integrates
                                        │
             telemetry ─► RaceHUD, RaceEffects, AudioDirector (rpm/surface)
```

Gear changes go through `VehicleBody.select_gear()`; the winch adds a bounded
external force through the physics state; weather only scales grip and rolling
resistance. Nothing writes a position or a speed.

## Save format

`user://profile.json`, version 4:

```json
{
  "version": 4,
  "credits": 1000,
  "xp": 120,
  "selected_vehicle": "ranger_4x4",
  "owned_vehicles": ["rocky_buggy", "ranger_4x4"],
  "records": {"canyon_01": {"best_time": 70.0, "medal": 3, "attempts": 2, "completed": true}},
  "upgrades": {"rocky_buggy": ["engine_1"]},
  "config": {
    "ranger_4x4": {"transmission": "ranger_h5", "transfer": "4H", "diff": "open",
                   "tires": "at", "suspension": "stock", "winch": true}
  },
  "play_time_s": 0.0,
  "distance_m": 0.0
}
```

v3 → v4 migration adds `config: {}` and keeps every other field. Settings live in
`user://settings.json` (v3) and include `control_preset`, `control_positions`,
slider sensitivity/return, touch margin and visibility flags.

## Performance and quality tiers

`SettingsService.quality` now changes real work, not a tint:

| | Low | Medium | High |
|---|---|---|---|
| Parallax layers | near only | mid + near | far + mid + near |
| Weather particles | off | half count | full |
| Exhaust / impact particles | off / 12 | 7 / 12 | 12 / 20 |
| Fog overlay | 50 % | full | full |
| Terrain decor density | authored | authored | authored |

Draw calls stay bounded: one terrain polygon, one static body for the heightfield
(plus one per solid obstacle/bridge), two wheel sprites and four suspension lines
per vehicle, `CPUParticles2D` everywhere.

## Adding content

* **Stage** — add a `_mk(...)` entry in `stages/stage_catalog.gd`; set
  `weather`, obstacles (including `steel_bridge` with `deck_y`) and medals.
* **Vehicle** — add a `VehicleDef` block in `Content._build_vehicles()` with its
  engine curve, **transmission profiles**, transfer case and diff options.
* **Transmission** — new `TransmissionProfile` in the vehicle's `transmissions`
  array; it appears in the garage and the briefing automatically.
* **Surface** — add to `Content._build_surfaces()`; grip, rolling resistance and
  colour are picked up by the tyre model and the terrain renderer.
