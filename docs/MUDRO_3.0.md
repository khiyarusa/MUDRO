# MUDRO 3.0 — Release Overview

**What this is:** the 3.0 release document — what the game now is, what shipped, what changed from 2.0, and what is honestly still broken or missing. Written for the people maintaining and shipping it.
**Scope:** the code in this repository as of the date below (`project.godot` 3.0.0). It is not a marketing page and it does not describe features that are not implemented.
**Version:** 1.0 — 2026-11-14.

---

## 1. Summary

MUDRO 3.0 replaces the 2.0 obstacle-stage game with a mountain-road game. Fifteen authored tracks across five regions — Zagros, Alpine, Pine, Black Ridge and Glacier — are defined by continuous elevation profiles instead of props, so every metre of road is a grade and a surface rather than a collider. The roster is now five real, documented 4×4s (Jimny JB74, Hilux AN120, Pajero V80, Patrol Y61, Land Cruiser 79), each with its own engine, gearbox, transfer case and axle layout. The flat upgrade list is replaced by a 41-slot parts catalogue whose numbers feed a causal engine model, a cooling model with derate and damage, and a transmission that can refuse a shift for a reason it can explain. Terrain is one continuous collision body plus two end walls; decoration has no colliders at all. Saves migrate from v2–v4 to v5, keeping credits, unlocks, records and purchases.

The data and physics layers are complete and run headless. The 2.0-era menu screens, the tyre parts table and the automated test suite are **not** yet migrated; §11 states exactly what fails.

---

## 2. Identity

| | |
|---|---|
| Title | MUDRO — OFFROAD PHYSICS |
| Version | 3.0.0 (versionCode 300) |
| Engine | Godot 4.7.2 stable, GL Compatibility renderer |
| Form | 2D side-view physics, landscape, offline, Persian-first with English |
| Package | `com.khiyarusa.mudro`, arm64-v8a |
| Save file | `user://profile.json`, schema v5 |

The game is a physics sandbox disguised as a racing game: the car is a rigid body with two axles, raycast suspension and a slip-based tyre, and the tracks are authored roads rather than obstacle courses. There is no 3D, no network, and nothing is simulated behind the player's back — see `docs/ARCHITECTURE_3.0.md` §5.

**Non-affiliation.** Toyota, Land Cruiser, Hilux, Nissan, Patrol, Suzuki, Jimny, Mitsubishi and Pajero are trademarks of their respective owners. MUDRO 3.0 uses the names descriptively, to identify the vehicles whose published specifications inform the simulation. It is not affiliated with, sponsored by or endorsed by any manufacturer, and no manufacturer logos or badges appear in the art. Full note: `docs/VEHICLE_SPEC_SOURCES.md` §10.

---

## 3. The five regions

| Region | Name | Tracks | Character | Ambient | Art |
|---|---|---|---|---|---|
| `zagros` | Zagros Highlands | 3 | Dry limestone, open dirt roads, gentle rolling climbs. The teaching region. | 28 °C | Borrowed (`canyon`) |
| `alpine` | Alpine Pass | 3 | Cold paved pass, long unbroken gradients, snow at the summits. | 6 °C | Borrowed (`quarry`) |
| `pine` | Pine Valley | 3 | Damp forest, shallow mud, grip that changes under the car. | 14 °C | Native |
| `black_ridge` | Black Ridge | 3 | Abandoned mine roads, broken stone, the hardest grades in the game. | 12 °C | Native |
| `glacier` | Glacier Road | 3 | Exposed ridges, snow and ice, almost no grip. | −6 °C | Borrowed (`quarry`) |

Region determines the ambient temperature the cooling model uses, the terrain tint, the scenery set and the ambience loop. Three of the five borrow another region's art because their own environment layers do not exist yet — `assets/environments/{zagros,alpine,glacier}` are absent and `ArtLib.REGION_ALIAS` falls back to `canyon` and `quarry`. This is a content gap, not a code one: dropping correctly sized SVGs into those folders removes the alias with no code change (`docs/ASSET_PIPELINE.md` §3.4).

---

## 4. The fifteen tracks

Length, gain and grade are computed from the authored slope segments, not typed in. Medals are derived from a reference pace (×1.08 / 1.22 / 1.42).

| Track | Region | Length | Gain | Max grade | Avg grade | Checkpoints | Pace | Gold |
|---|---|---|---|---|---|---|---|---|
| Oak Pass | zagros | 920 m | +46 m | 7.4° | 2.6° | 2 | 55.4 s | 59.8 s |
| Limestone Shelf | zagros | 1080 m | +51 m | 10.8° | 2.2° | 2 | 66.9 s | 72.2 s |
| Zagros Grade | zagros | 1060 m | +85 m | 11.9° | 3.5° | 2 | 105.9 s | 114.3 s |
| Alpine Pass | alpine | 1260 m | +72 m | 9.1° | 2.2° | 2 | 70.6 s | 76.2 s |
| Fog Summit | alpine | 1220 m | +129 m | 12.4° | 5.8° | 3 | 142.4 s | 153.8 s |
| North Face Descent | alpine | 1180 m | +51 m | 11.3° | −0.8° | 3 | 71.7 s | 77.4 s |
| Pine Valley | pine | 1000 m | +48 m | 6.8° | 2.7° | 2 | 64.9 s | 70.1 s |
| Moss Line | pine | 1030 m | +63 m | 9.1° | 3.5° | 2 | 79.6 s | 86.0 s |
| Cold Creek | pine | 1220 m | +60 m | 10.8° | 1.0° | 3 | 99.1 s | 107.0 s |
| Black Gate | black_ridge | 1090 m | +80 m | 11.3° | 4.1° | 2 | 100.3 s | 108.4 s |
| Haul Road | black_ridge | 1220 m | +149 m | 12.4° | 6.8° | 3 | 213.0 s | 230.1 s |
| Ash Summit | black_ridge | 1320 m | +194 m | 13.5° | 8.4° | 3 | 272.0 s | 293.8 s |
| Glacier Road | glacier | 1290 m | +103 m | 10.2° | 4.1° | 3 | 133.9 s | 144.6 s |
| Polar Wind | glacier | 1240 m | +127 m | 11.9° | 5.6° | 3 | 176.8 s | 190.9 s |
| Great Glacier | glacier | 1630 m | +192 m | 11.3° | 6.7° | 3 | 267.7 s | 289.1 s |

The full per-track tables — descent, steepest 20 m, surfaces, all three medals, rewards, and the authored segment list — are in `docs/MOUNTAIN_TRACK_DESIGN.md`.

Two structural differences from 2.0 are worth stating here:

- **There is no obstacle layer.** The road is a single continuous collision body; scenery has zero colliders by design; two end walls stop a runaway car. Nothing on the racing line can be hit.
- **Difficulty is grade and surface, not props.** Ash Summit climbs 194 m at 8.4° average on ash and scree; Great Glacier puts 192 m of gain under ice for 660 m of its length. Neither has a single log to drive over.

---

## 5. The five vehicles

All five are real, documented variants. "Documented" is the published figure for that exact variant; "derived" is what the parts system computes at stock and what the physics drives.

| Vehicle | Engine | Documented | Derived | Mass | Price / unlock |
|---|---|---|---|---|---|
| Suzuki Jimny 1.5 (JB74, 2020) | K15B 1.5 NA petrol, 5MT | 75 kW / 130 N·m | 64.4 kW / 126.1 N·m | 1095 kg | Free, owned |
| Toyota Hilux 2.8 GD-6 (AN120, 2021) | 1GD-FTV 2.8 turbodiesel, 6MT | 150 kW / 420 N·m | 98.1 kW / 407.3 N·m | 2120 kg | 3200 · complete Zagros Grade |
| Nissan Patrol 3.0 Di (Y61, 2010) | ZD30DDTi 3.0 turbodiesel, 5MT | 118 kW / 380 N·m | 108.4 kW / 368.6 N·m | 2478 kg | 6500 · complete Moss Line |
| Mitsubishi Pajero 3.2 DiD (V80, 2012) | 4M41 3.2 turbodiesel, 5MT | 125 kW / 358 N·m | 98.7 kW / 347.5 N·m | 2270 kg | 8200 · complete North Face Descent |
| Toyota Land Cruiser 79 4.2 D (2026) | 1HZ 4.2 NA diesel, 5MT | 96 kW / 285 N·m | 74.1 kW / 245.3 N·m | 2225 kg | 14 000 · complete Haul Road |

Each vehicle carries its own ratios, final drive, transfer case, axle architecture and tyre size — the differences are data, not special cases. Per-vehicle tables, including both gearbox options and the full chassis specification, are in `docs/VEHICLE_DATABASE.md`. The published figures and their sources are in `docs/VEHICLE_SPEC_SOURCES.md`.

**The derived figures are lower than the documented ones, and §10 explains why.** Torque is within 3 % on four of the five; power is not, because the generic torque curve does not hold a diesel's plateau.

---

## 6. Garage and tuning

The 2.0 upgrade list (seven categories × three flat tiers) is gone. A vehicle is now a set of **41 slots** filled with **526 parts** — 40 or 41 per vehicle — and each part carries the numbers its own subsystem consumes.

| Category | Slots |
|---|---|
| Engine | block, pistons, crankshaft, con-rods, camshaft, head, intake, throttle, exhaust, ECU, turbo, intercooler, injectors, fuel pump, radiator, water pump, fan, thermostat |
| Transmission | clutch, gearbox, transfer case, differential |
| Suspension | springs, dampers, bushings, bump stops, arms, lift kit |
| Tyres | tyres, rims |
| Brakes | pads, discs |
| Body | front/rear bumper, fender flares, hood, roof rack, skid plate, sliders, roll cage, winch, snorkel, lights |

The design rule is causal, not additive. A bigger turbo only makes boost if the ECU asks for it and the block tolerates it; the intercooler changes charge density; the radiator only matters when the engine is hot; the fuel system caps power. Fitting `turbo_big` to a stock Hilux changes nothing at all (2.00 bar requested, 1.35 bar delivered, because the stock ECU targets 1.35) — worked example in `docs/TUNING_SYSTEM.md` §7.1.

Condition is tracked as five states (new, used, worn, damaged, broken) with per-race wear and a repair cost. The multipliers are declared but **not yet applied to the physics** (`docs/TUNING_SYSTEM.md` §5).

---

## 7. Transmission and drivetrain

Every vehicle has a stock gearbox profile plus an automatic option; the profile carries ratios, final drive, efficiency, shift time, synchro, clutch type, torque rating, converter behaviour and the automatic shift schedule.

- **Three architectures.** H-pattern manual (all stocks), sequential (the race gearbox part), automatic with a five-position gate.
- **Ranges.** `P / R / N / D / L` for automatics: P locks the rear axle, R is reverse-only, N is neutral, D uses all gears, L holds 1–2.
- **Clutch.** A real friction model with lock-up: assist on opens the clutch during shifts and slips it at crawling speed so a beginner cannot stall; assist off is full manual, where a shift without the pedal pressed is refused.
- **Rejections with reasons.** `clutch`, `shifting`, `reverse`, `overrev`, `range` — each surfaces as a localised message and a haptic tick, never a silent no-op.
- **Transfer case.** 2H / 4H / 4L on four vehicles, 2H / 4H / 4HLc / 4LLc on the Pajero, with a 0.25 s torque interruption on every change.
- **Differential.** Open, limited-slip or locked, modelled as a centre coupling between the two axles.

Details, including the gear-speed table and the automatic schedule: `docs/TRANSMISSION_3.0.md`.

---

## 8. Mobile controls

The control layer is a single full-rect `Control` that receives every screen touch, hit-tests it itself and assigns each finger to exactly one widget. There is no `TouchScreenButton` and no shared mouse pointer, so a finger on the throttle and a finger on the clutch are independent owners — releasing one can never release the other.

- **Three presets:** buttons, slider, pedals. The preset, handedness, per-widget positions and sizes are saved in `user://settings.json`.
- **Gear panel.** A real gate, drawn from the transmission data: H-pattern lever with a neutral rail, sequential up/down with spring-back, or a PRNDL range gate. In H-pattern mode the lever must pass through neutral, so a diagonal 2nd-to-5th is geometrically impossible, and a commit without the clutch is refused at the panel as well as in the gearbox.
- **Drag-to-place editor.** Every widget can be moved and resized in an overlay; positions are stored normalised so they survive a resolution change.
- **Haptics** on refusal, and a clutch-readiness bar on the gear panel.

The layer only produces a `VehicleInputState`. It never touches the vehicle. Contract: `docs/TRANSMISSION_3.0.md` §9.

---

## 9. Save migration

The profile is `user://profile.json`, schema **v5**, written atomically (temp file → `.bak` → live). Starting credits are 600.

| From | What happens |
|---|---|
| v2 / v3 / v4 | Every existing field is preserved; missing fields are filled from defaults |
| Old vehicles | Mapped by role: `rocky_buggy → jimny_jb74`, `ranger_4x4 → hilux_an120`, `dune_pickup → patrol_y61`, `titan_offroad → lc79` |
| Old stages | Mapped onto 3.0 track ids; several 2.0 stages collapse onto one track (e.g. `canyon_04 → zagros_03`), and records merge by best time, highest medal and summed attempts |
| Old upgrades | Each purchased upgrade becomes an owned **and fitted** 3.0 part (`engine_2 → ecu_1`, `gearbox_2 → gbox_close`, `tires_2 → tyre_mt`, …) |
| Old `config` | Transfer and differential selections are carried into the new garage entry |
| `upgrades` / `config` keys | Deleted after conversion; `migrated_from` records the original version |

A migrated profile keeps credits, XP, owned vehicles, records per track and per vehicle, and every purchase. No migration path resets progress. Mapping tables: `scripts/core/save_manager.gd:22-52`; schema: `docs/ARCHITECTURE_3.0.md` §3.7.

---

## 10. What changed from 2.0

| | 2.0 | 3.0 |
|---|---|---|
| Content | 4 regions, 16 stages | 5 regions, 15 tracks |
| Terrain | Heightfield with height-keyframes plus solid obstacles and bridges | Authored C1 slope profile, one continuous collision body, two end walls, zero decor colliders |
| Track definition | Elevation keys + obstacle list + medals typed by hand | Slope segments + surface sections + fractions for checkpoints; every statistic derived |
| Vehicles | 4 fictional (rocky_buggy, ranger_4x4, dune_pickup, titan_offroad) | 5 documented real vehicles, one exact variant each |
| Tuning | 7 categories × 3 flat upgrade tiers | 41 part slots, 526 parts, causal parameters |
| Engine | Per-vehicle authored curve, upgrades as multipliers | `EngineBuild` derived from air flow, boost, charge density, fuel ceiling and rev limits |
| Cooling | None | `ThermalState`: heat balance, thermostat, fan hysteresis, derate 108–124 °C, damage above 121 °C |
| Transmission | Per-vehicle profiles, H-pattern gate | Same model, plus ranges P/R/N/D/L, converter, refusal reasons, panel drawn from data |
| Save | v4 with `upgrades` + `config` | v5 with a per-vehicle `garage` (parts, owned, condition, presets) and full migration |
| Art | 4 vehicle sprite sets, 4 environment sets | 5 new vehicle sprite sets; environment sets unchanged, three regions borrow |
| Physics core | Two axles, raycast suspension, slip tyre | Unchanged model — 3.0 changes what feeds it, not how it integrates |

The version bump is 3.0.0 / code 300; the package id is unchanged.

---

## 11. Known limitations

Everything below is true of the code in this repository today. None of it is a roadmap promise.

1. **The UI layer is still 2.0.** `main_menu.gd`, `stage_select.gd`, `career_screen.gd`, `route_briefing.gd`, `race_hud.gd`, `garage_screen.gd` and `upgrade_screen.gd` call APIs that no longer exist (`Content.stages`, `Content.stages_for()`, `SaveManager.is_stage_unlocked()`, `SaveManager.buy_upgrade()`, `SaveManager.vehicle_upgrades()`, three-argument `GarageModel.build()`). Those screens error at runtime. The data and physics layers are 3.0; the menus on top of them are not.
2. **Tyre and rim parts do not exist at runtime.** `PartsCatalog.tyre_parts()` reads `row[12]` from a 12-element row and raises a script error for every vehicle at boot, so no `TYRES` or `RIMS` parts are created. Every car runs its stock tyre and per-surface compound bonuses never apply.
3. **The automated test suite is the 2.0 suite** and cannot pass against the 3.0 catalogue. The only 3.0 check is `tools/smoke_v3.tscn`, and as recorded it reports failures (see item 4). Details: `docs/ARCHITECTURE_3.0.md` §7.3.
4. **Derived power is below the documented figure on three of five vehicles** — Hilux 98.1 of 150 kW, Pajero 98.7 of 125 kW, LC79 74.1 of 96 kW — because the torque curve is a single generic shape that does not hold a diesel's plateau. The LC79 also loses 11 % of air density to a phantom compressor rise: the `"na_diesel"` aspiration string is not exempted by the `aspiration == "na"` special case. `docs/VEHICLE_DATABASE.md` §2.
5. **A bigger turbo alone changes nothing and says nothing.** The stock ECU's boost target caps it, and the "block-limited" warning only fires when the block is the binding limit. `docs/TUNING_SYSTEM.md` §7.1.
6. **Part condition does not affect performance.** Wear states and repair costs are tracked; `PartDef.condition_mult()` is never called.
7. **No purchase or fitting path in the UI.** `SaveManager.buy_part()` and `install_part()` are implemented and unused, because the workshop screen still drives the 2.0 upgrade API. Presets and the dyno model are likewise implemented without a screen.
8. **Three tracks request `weather: "wind"`**, which `WeatherSystem` does not implement — those tracks run as `clear`.
9. **Surface spans do not always cover the road.** Seven tracks stop short of the finish (the tail reads as `hard_dirt`) and three author sections past it.
10. **`4HLc` on the Pajero does not drive the front axle.** `transfer_drives_front()` lists `4H`, `4L` and `AWD` only.
11. **No dedicated environment art for Zagros, Alpine or Glacier**, and two of them share the same borrowed quarry backdrop.
12. **Engine audio is 2.0's four loops**, mapped by acoustic character; the Hilux and Pajero currently share one loop.
13. **Two classes are named `TerrainBuilder`**, and the 2.0 stage stack (`scripts/stages/`) is dead code still in the tree.
14. **No 3D anything.** Blender is not installed and Python is not available on this machine, so no 3D model was authored or imported; the intended pipeline is documented as a future step in `docs/ASSET_PIPELINE.md` §7 and is explicitly **not executed**.
15. **The physics is a two-axle side view.** There is no left/right differential, no body roll, no chassis flex, and no per-wheel terrain sampling.
16. **Screenshots and the QA report are separate deliverables.** The 3.0 capture folder is `docs/screenshots/v3.0/`; this document makes no claim about their contents.

---

## 12. Where to read next

| Topic | Document |
|---|---|
| Structure, autoloads, data model, physics tick, build and test | `docs/ARCHITECTURE_3.0.md` |
| Regions, tracks, profile maths, medal model | `docs/MOUNTAIN_TRACK_DESIGN.md` |
| Per-vehicle specifications and derived output | `docs/VEHICLE_DATABASE.md` |
| Published figures and their sources | `docs/VEHICLE_SPEC_SOURCES.md` |
| Part slots, compatibility, wear, worked tuning examples | `docs/TUNING_SYSTEM.md` |
| Cooling equations and thresholds | `docs/ENGINE_THERMAL_SYSTEM.md` |
| Gearboxes, clutch, transfer, differential, gear panel | `docs/TRANSMISSION_3.0.md` |
| Sprite and audio authoring, region art state, blocked 3D route | `docs/ASSET_PIPELINE.md` |
| Licensing and originality | `docs/ASSET_LICENSES.md` |
| 2.0 baseline (superseded) | `docs/MUDRO_2.0.md`, `docs/ARCHITECTURE.md` |
