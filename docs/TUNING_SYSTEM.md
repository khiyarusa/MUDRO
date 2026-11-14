# MUDRO 3.0 — Tuning System

**What this is:** how the 3.0 parts catalogue works — every installable slot, the numbers each slot carries, the rules that reject or warn, how condition and wear are tracked, and exactly how a fitted part becomes physics. For maintainers and for anyone balancing the game.
**Scope:** `scripts/parts/part_def.gd`, `part_compat.gd`, `parts_catalog.gd`, `engine_build.gd`, and the parts half of `scripts/garage/garage_model.gd`. Cooling physics has its own document (`docs/ENGINE_THERMAL_SYSTEM.md`); driveline behaviour has its own (`docs/TRANSMISSION_3.0.md`).
**Version:** 1.0 — 2026-11-14 · code basis `project.godot` 3.0.0.

---

## 1. What the system is

A part is **data, not a multiplier**. Every part carries a `params` dictionary whose keys are consumed by the subsystem that cares about them: `EngineBuild` for engine internals, `GarageModel` for the chassis and driveline, `ThermalState` for cooling. The design rule is causal: if a turbo cannot get fuel or air, it does not make power — the build reports it, the dyno shows it, and the car drives like the badly-matched machine it is.

Two consequences follow, and they are the whole point:

- **Nothing is a flat "+10 % power".** Fitting a bigger turbo changes a boost number that four other parts can cap; fitting a radiator changes a heat-rejection rating that only matters when the engine is hot.
- **A build can be worse than stock.** A 3-inch exhaust on a stock engine changes almost nothing; a big turbo on a stock ECU changes literally nothing (worked example §7.1).

---

## 2. The catalogue at a glance

| Property | Value | Source |
|---|---|---|
| Slots | 41 | `PartDef.Slot` |
| Categories used by the workshop UI | 7 | `ContentDB.category_slots()` |
| Parts per vehicle | 40 (Jimny, LC79) / 41 (Hilux, Patrol, Pajero) | `local-builds/logs/smoke_v3.log` |
| Total parts | 526 | same run |
| Tiers | 0 = stock, 1 = street, 2 = race | `PartDef.tier` |
| Cost scale | `budget = 240 + price × 0.05`, then × a per-slot factor | `parts_catalog.gd:44-46` |
| Fit rule | per vehicle id, plus engine family for engine slots | `PartDef.fits_vehicle()` |

Stock parts (tier 0) are always owned and always fit; `is_part_owned()` returns `true` for them without looking at the save (`save_manager.gd:456-462`).

Cost budget per vehicle: Jimny 240, Hilux 400, Patrol 565, Pajero 650, LC79 940. A part's cost is that budget multiplied by the per-slot factor in `parts_catalog.gd` (e.g. a race block is ×18, a sport intake ×3, a roof rack ×3).

**Current state — read this before relying on the slot list.** `PartsCatalog.tyre_parts()` indexes `row[12]` on 12-element rows (`parts_catalog.gd:399`, rows defined at 371-386). The result is a script error per vehicle during `Content` boot (visible in `local-builds/logs/smoke_v3.log`), and **no `TYRES` or `RIMS` parts exist in the live catalogue**. Everything in §3.5 and §7.5 describes the intended behaviour of code that is present but not currently reachable; the game falls back to each vehicle's stock tyre because `Content.stock_part()` returns `null` for those slots.

---

## 3. Slots and parameters

Legend: **consumed** = read by code; **stored** = authored and displayed but not read by any subsystem today.

### 3.1 Engine internals

| Slot | Parameters | Consumed | Effect |
|---|---|---|---|
| `BLOCK` | `displacement_mult`, `max_boost_bar` | both | Scales displacement; caps boost |
| `PISTONS` | `compression`, `efficiency_mult`, `max_boost_bar` | `efficiency_mult`, `max_boost_bar` | Multiplies base thermal efficiency (0.29 petrol / 0.35 diesel); caps boost. `compression` is overwritten into a local and never used |
| `CRANKSHAFT` | `stroke_mult`, `max_rpm` | both | Scales displacement; caps the rev limit |
| `CONRODS` | `max_rpm`, `strength` | neither | **Stored only** — `EngineBuild` never reads rods |
| `CAMSHAFT` | `flow_mult`, `rev_add`, `max_rpm` | all three | Flow multiplier; raises the rev limit up to `max_rpm` |
| `HEAD` | `flow_mult`, `max_rpm` | both | Flow; rev ceiling |
| `INTAKE` | `flow_mult` | yes | Flow |
| `THROTTLE` | `flow_mult`, `response` | `flow_mult` | Flow; `response` stored only |
| `EXHAUST` | `flow_mult`, `spool_mult` | `flow_mult` | Flow, then × 0.97 in the min() chain |
| `ECU` | `boost_target_bar`, `rev_limit`, `fuel_map`, `throttle_response` | all four | Boost target, rev ceiling, torque multiplier, throttle gain |
| `TURBO` | `boost_bar`, `spool_rpm`, `efficiency`, `heat_mult` | `boost_bar` | Only the boost target is read; spool is derived from the engine's peak-torque rpm, efficiency and heat load are stored |
| `INTERCOOLER` | `charge_cool`, `pressure_drop` | `charge_cool` | Fraction of compressor heat removed (0–0.92) |
| `INJECTORS` | `flow_cc`, `max_power_kw` | `max_power_kw` | Power ceiling |
| `FUEL_PUMP` | `flow_lph`, `max_power_kw` | `max_power_kw` | Power ceiling |
| `RADIATOR` | `heat_reject_kw`, `capacity_l` | both | Heat rejection and coolant volume |
| `WATER_PUMP` | `flow_mult` | yes | Multiplies coolant airflow term |
| `FAN` | `airflow_mult` | yes | Multiplies the fan's contribution |
| `THERMOSTAT` | `open_c` | yes | Opening temperature |

The flow chain is a `min()`, not a sum:

```
flow_mult = min( min(head, intake), min(throttle, exhaust × 0.97) ) × cam
VE        = clamp(0.90 × flow_mult, 0.55, 1.32)
```

so a ported head with a stock exhaust gains nothing until the exhaust is opened too. The 0.97 on the exhaust is a standing 3 % tax on every stock engine; see `docs/VEHICLE_DATABASE.md` §2.1.

### 3.2 Driveline

| Slot | Parameters | Consumed | Effect |
|---|---|---|---|
| `CLUTCH` | `capacity_nm`, `bite_point`, `type` | all three | Clutch capacity; bite point; `type` becomes the profile's `clutch_type` |
| `GEARBOX` | `ratios`, `final_drive`, `shift_time`, `max_torque_nm`, `kind`, `reverse_ratio`, `efficiency` | all | Replaces the transmission profile entirely |
| `TRANSFER` | `ids`, `ratios` | both | Replaces the transfer modes |
| `DIFFERENTIAL` | `mode`, `grip_mult` | `mode` | Sets `default_diff` if the vehicle allows it; `grip_mult` is stored only (the physics uses its own 1.07 / 1.035 constants) |

A gearbox part replaces the whole profile, which is why the racing gearbox is sequential: `kind = MANUAL_SEQ`, `requires_clutch = false`, 0.14 s shifts. See `docs/TRANSMISSION_3.0.md` §6.

### 3.3 Chassis

| Slot | Parameters | Consumed | Effect |
|---|---|---|---|
| `SPRINGS` | `spring_mult`, `ride_mult` | both | Multiplies both spring rates; scales rest length |
| `DAMPERS` | `compression_mult`, `rebound_mult` | both | Scales all four damper coefficients |
| `BUSHINGS` | `compliance` | no | **Stored only** |
| `BUMP_STOPS` | `rate_mult` | yes | Scales `bump_stop_rate` |
| `ARMS` | `travel_mult`, `strength` | `travel_mult` | Scales suspension travel; `strength` stored only |
| `LIFT_KIT` | `ride_add_m`, `com_add_m`, `travel_mult`, `max_tyre_radius_m` | all four | Raises rest length and centre of mass, scales travel, raises the tyre clearance ceiling |

### 3.4 Body, protection and recovery

| Slot | Parameters | Consumed | Effect |
|---|---|---|---|
| `BUMPER_FRONT` | `mass_kg`, `drag_mult`, `durability_mult`, `protection` | all | Mass, drag, durability, protection score |
| `BUMPER_REAR` | `mass_kg`, `durability_mult`, `protection` | all | Same, no drag term |
| `FENDER_FLARE` | `width_add_m` | no | **Stored only** — body width does not change |
| `HOOD` | `mass_kg`, `vent` | `mass_kg` | `vent` stored only |
| `ROOF_RACK` | `mass_kg`, `com_add_m` | both | Mass, higher centre of mass, +0.08 m² frontal area |
| `SKID_PLATE` | `mass_kg`, `protection` | both | Mass, protection |
| `SLIDERS` | `mass_kg`, `protection` | both | Mass, protection |
| `ROLL_CAGE` | `mass_kg`, `durability_mult` | both | Mass, durability |
| `WINCH` | `mass_kg`, `force_n`, `rope_m` | all | Enables the winch system, sets force and rope length |
| `SNORKEL` | `mass_kg`, `water_ford_m` | both | Wading depth (0.4 m without, 0.9 m with) |
| `LIGHTS` | `range_m`, `mass_kg` | both | Light range (40 m stock, 90 m with a bar) |

### 3.5 Tyres and brakes

| Slot | Parameters | Consumed | Effect |
|---|---|---|---|
| `TYRES` | `radius_m`, `width_m`, `mu_peak`, `mu_slide`, `rr`, `peak_slip`, `surface_bonus{}`, `compound`, `pressure_bar` | all except `mu_slide` | Radius, width, grip scale, rolling resistance, peak slip, per-surface multiplier. `mu_slide` is stored only (the tyre model uses the surface's slide grip) |
| `RIMS` | `mass_add` | yes | Adds to wheel mass, clamped at 8 kg minimum |
| `BRAKE_PADS` | `brake_mult`, `fade_c` | `brake_mult` | Multiplies front and rear brake torque; `fade_c` stored only |
| `BRAKE_DISCS` | `brake_mult`, `mass` | `brake_mult` | Same; mass also enters the part mass total |

Tyre compounds in the catalogue (all currently unreachable, see §2): all-terrain, mud-terrain, rock-terrain, highway-terrain, snow-terrain and oversize mud-terrain, each with its own radius offset, µ, rolling resistance and `surface_bonus` map (for example mud-terrain: +22 % in mud, +18 % in wet mud, −8 % on asphalt).

---

## 4. Compatibility rules

`PartCompatibility.check(base, cfg, part)` returns `{ok, reasons[], warnings[]}`. A **reason** refuses the install; a **warning** installs the part and tells the player what will be wrong. Every message exists in both languages and is written in terms of a number the player can act on.

### 4.1 Refusals

| Condition | Rule | Message |
|---|---|---|
| Fitment | `fits_vehicle(vehicle_id, engine_family)` must be true | "not made for this vehicle or engine family" |
| Tyre clearance | `part.radius_m > allowed + 0.001`, where `allowed` is the lift kit's `max_tyre_radius_m` or the vehicle's | "this tyre needs a lift kit" |
| Gearbox torque | `part.max_torque_nm < current.peak_torque × 1.02` | "gearbox torque rating is below engine torque" |
| Clutch torque | `part.capacity_nm < current.peak_torque × 1.02` | "clutch capacity cannot hold this torque" |
| Turbo boost | `part.boost_bar > min(block.max_boost_bar, pistons.max_boost_bar) + 0.001` | "block and pistons are not rated for X bar" |

Note the asymmetry: a **gearbox** may not be weaker than the engine, but a **turbo** may be stronger than the block — it is refused only if it exceeds the block/piston rating outright. A turbo within the rating but above the ECU target installs silently and does nothing (§7.1).

### 4.2 Warnings

| Condition | Warning |
|---|---|
| Turbo fitted and intercooler is missing or `charge_cool < 0.5` | intake air stays hot, part of the boost is wasted |
| Injectors or fuel pump fitted | check the fuel ceiling on the dyno before committing |
| Radiator `heat_reject_kw < engine.heat_kw_full × 1.02` | marginal for the current power; temperature will climb on long ascents |
| Springs/dampers fitted with a lift kit above 30 mm | short springs and dampers limit the available travel |

### 4.3 Build-level warnings

Separately from install checks, `EngineBuild.derive()` appends its own warnings with severities:

| Severity | Trigger |
|---|---|
| 2 | Boost capped by the block/piston rating |
| 2 | The fuel system is capping power (`fuel_limited`) |
| 3 | Radiator undersized for the build (`heat_kw_full > radiator_kw × 1.05`, `cooling_marginal`) |

`PartCompatibility.audit()` collects those plus two chassis checks (gearbox at its torque limit, clutch at its capacity). The route briefing and the garage are meant to read this list; see §8 for why they currently cannot.

---

## 5. Condition and wear

Condition is a **state**, not a percentage: `NEW`, `USED`, `WORN`, `DAMAGED`, `BROKEN` (0–4). The declared multipliers are:

| Condition | Multiplier |
|---|---|
| NEW | 1.00 |
| USED | 0.96 |
| WORN | 0.90 |
| DAMAGED | 0.74 |
| BROKEN | 0.00 |

**These multipliers are not applied anywhere yet.** `PartDef.condition_mult()` exists and nothing calls it (`scripts/parts/part_def.gd:113-114`), and `VehicleDef.part_conditions` is declared but never read by the physics. A WORN part currently performs exactly like a NEW one. What *does* work is the bookkeeping:

- `SaveManager.apply_race_wear()` runs at the finish (`race_scene.gd:674`) and bumps condition states from a per-race wear accumulator.
- Wear per part class:

```
generic  : seconds × (0.002 + load_avg × 0.010)  (+ (heat_peak − 118) × 0.02 if overheated)
tyres    : seconds × 0.012 + load_avg × 0.020
clutch   : clutch_slip_seconds × 0.006 + generic × 0.5
brakes   : seconds × 0.004
springs / dampers : seconds × 0.003
```

- Fractional wear is kept in a hidden `"<part_id>:wear"` bucket inside the condition dictionary and converted into whole states when it passes 1.0.
- Repair cost is `max(part.cost × factor, 25)` with factor `[0, 0.12, 0.30, 0.55, 0.80]` for USED…BROKEN.

**Worked example.** A 300 s race at 80 % average load with no overheating: generic wear = 300 × (0.002 + 0.008) = 3.0 → three condition steps, NEW → DAMAGED. Tyres: 300 × 0.012 + 0.8 × 0.02 = 3.62 → also three steps. A 600-credit gearbox at WORN would cost 180 credits to repair.

---

## 6. How a part becomes physics

The only place parts become physics is `GarageModel.build(base, config)` (`scripts/garage/garage_model.gd:120-260`). It deep-copies the authored `VehicleDef`, resolves the fitted parts, then rebuilds:

| Output | Rebuilt from |
|---|---|
| `engine_build` | `EngineBuild.derive(vehicle spec, engine-slot parts)` |
| `engine` (curve) | 14 sampled points from `engine_build.torque_at()`, plus turbo gain/width and ECU throttle response |
| `transmissions` | The gearbox part, as a single `TransmissionProfile` |
| `clutch_capacity` | The clutch part, else gearbox rating × 1.05 |
| `transfer_ids` / `transfer_ratios` | The transfer part |
| `default_diff` / `active_diff` | The differential part, sanitised against the vehicle's allowed modes |
| `suspension` | Spring, damper, bump-stop, arm and lift parts applied in that order |
| `tire_front` / `tire_rear` | The tyre part (same object on both axles), then rim mass |
| `brake_torque_front/rear` | Base torque × pad multiplier × disc multiplier |
| `drag_cd`, `frontal_area_m2` | Bumper drag multiplier; roof rack area |
| `mass_kg` | Base mass + Σ part masses (floor: 60 % of base) |
| `com_height_m` | Base + lift `com_add_m` + roof-rack `com_add_m` |
| `durability`, `protection` | Bumper/cage multipliers, summed protection scores |
| `has_winch`, `winch_force_n`, `water_ford_m`, `light_range_m` | Winch, snorkel, lights parts |
| `build_info` | A dictionary of the above for UI and tests |

The authored `Content` resources are never mutated, so two builds of the same vehicle cannot contaminate each other.

**Where the simulation reads it.** `VehicleBody.setup()` takes the built `VehicleDef` and copies: mass and inertia, engine config, the transmission profile, clutch capacity and bite point, tyre configs into `WheelAxis`, suspension into the raycast springs, brake torques into the wheel integration, and `engine_build` into `ThermalState`. Nothing else is consulted at runtime — if a part's parameter is not in the table above, it does not affect the car.

---

## 7. Worked examples

All numbers are from the code's own formulas, and where a headless run exists it is cited.

### 7.1 A big turbo with no support does nothing (Hilux)

Boost is the minimum of four independent limits:

```
boost = min( turbo.boost_bar, ecu.boost_target_bar, block.max_boost_bar, pistons.max_boost_bar )
```

| Build | Turbo | ECU target | Block | Pistons | Resulting boost |
|---|---|---|---|---|---|
| Stock | 1.35 | 1.35 | 1.70 | 1.75 | **1.35** |
| + `turbo_big` | 2.00 | 1.35 | 1.70 | 1.75 | **1.35** |
| + `turbo_big` + Stage 2 ECU | 2.00 | 1.73 | 1.70 | 1.75 | **1.70** (block-limited) |
| + `turbo_big` + Stage 2 + race block/pistons | 2.00 | 1.73 | 2.80 | 2.95 | **1.73** |

The recorded run confirms row 1 and row 2 are identical: `turbo only : 98 kW / 407 Nm`, the same as stock. Worse, because `block_limited` is only set when the *block* is the binding constraint, row 2 raises **no warning at all** — the player pays for a part and sees nothing change.

The fuel-system hypothesis is testable and wrong: the same run fitted race injectors and a race pump on top of the big turbo and still measured 98 kW / 407 Nm with `fuel_limited = false`, because the ECU target was still 1.35 bar. The smoke probe's own assertion ("fuel system did not unlock power") fails for exactly this reason. **The ECU is the first thing to change, not the fuel system.**

### 7.2 Intercooler and charge temperature

Charge temperature is:

```
charge = ambient + (38 + 95 × boost) × (1 − charge_cool)
density_ratio = (1 + boost / 1.013) × 298.15 / (273.15 + charge)
```

For the Hilux at 1.35 bar and 25 °C ambient the compressor rise is 166.25 K:

| Intercooler | `charge_cool` | Charge temp | Density ratio | Torque vs stock |
|---|---|---|---|---|
| None (no part) | 0.00 | 191.3 °C | 1.498 | −19.7 % |
| Stock | 0.55 | 99.8 °C | 1.864 | — |
| Front-mount | 0.76 | 64.9 °C | 2.057 | +10.3 % |
| Race | 0.88 | 45.0 °C | 2.186 | +17.2 % |

Because torque is proportional to density before the curve is applied, the intercooler is worth more than the turbo on a stock ECU: it multiplies air density at **unchanged boost**. `charge_cool` is clamped to 0.92, so the coolest possible charge at 1.35 bar is 38.3 °C.

### 7.3 Radiator and a sustained climb

The cooling model is a first-order balance (`docs/ENGINE_THERMAL_SYSTEM.md` has the equations in full). For the Hilux at 98.1 kW, 6 m/s road speed and 28 °C ambient:

- heat in = 0.75 × 98.1 + 5.5 = **79.1 kW**
- ram airflow at 6 m/s = 0.30 + 6/26 = **0.531**
- stock radiator 142 kW, thermostat 88 °C, fan off below 92 °C

Equilibrium: `T = 28 + 79.1 × 60 / (142 × 0.531) = 28 + 62.9 = 90.9 °C` — which is the value the recorded run prints after 180 s (90.9 °C). With the race radiator (241.4 kW) the same climb settles at **84.9 °C**, because the thermostat is only 65 % open at that temperature: `0.10 + 0.90 × (84.9 − 80)/8 = 0.65`.

Sustained power at which the package reaches the derate and damage thresholds (fan-on airflow 0.751 at 6 m/s, 0.597 at 2 m/s):

| Radiator | 108 °C at 6 m/s | 108 °C at 2 m/s | 121 °C at 6 m/s | 121 °C at 2 m/s |
|---|---|---|---|---|
| Stock 142 kW | 182 kW | 143 kW | 213 kW | 168 kW |
| Race 241 kW | 315 kW | 249 kW | 367 kW | 290 kW |

At stock power the Hilux cannot overheat on a 28 °C climb — correct behaviour, and a warning that any "fit a bigger radiator" upgrade only matters once the engine is boosted well past 140 kW.

### 7.4 Final drive and top speed

The gearing ceiling is:

```
v_max = ω(redline) × r_tyre / (top_gear_ratio × final_drive × transfer)
```

Hilux, 6th gear: `481.7 rad/s × 0.3876 m / (0.643 × 3.583) = 81.0 m/s = 292 km/h`.

The close-ratio gearbox part multiplies every ratio by 1.14 and the final drive by 1.06, so 6th becomes `0.643 × 1.14 = 0.733` and the final `3.798`: total 2.784, ceiling **67.1 m/s = 242 km/h** — a 17 % lower ceiling in exchange for 14 % more wheel torque in every gear and a 0.82 × shift time.

Neither number is a top speed. At 81 m/s this truck's drag alone would be `0.5 × 1.225 × 0.68 × 2.92 × 81² ≈ 8.0 kN`, i.e. about **646 kW** at the wheels. Solving drag + rolling resistance against the derived 98 kW gives a flat-ground top speed just under 40 m/s (≈140 km/h). **The final drive matters for acceleration and for gearing a climb, not for a top-speed figure.**

### 7.5 Tyre radius and gearing

Radius enters four places:

1. **Gearing ceiling** — linear in `r`. A Jimny on the oversize mud-terrain tyre (0.3465 → 0.3765 m, +8.7 %) raises its 5th-gear ceiling from 192 to 208 km/h.
2. **Wheel torque per newton of road force** — `F = T / r`, so the same crank torque produces 8 % less force at the contact patch.
3. **Wheel inertia** — `0.5 × m × r² × 1.9`, so it rises with the square of the radius.
4. **Ride height** — the chassis sits `r − r_stock` higher, which is why clearance is gated.

The clearance rule is the one players hit first. The Jimny's stock ceiling is 0.375 m:

| Tyre | Radius | Fits stock? | Fits 25 mm lift (0.395)? | Fits 50 mm lift (0.420)? |
|---|---|---|---|---|
| All-terrain | 0.3465 | Yes | Yes | Yes |
| Mud-terrain | 0.3565 | Yes | Yes | Yes |
| Rock-terrain | 0.3515 | Yes | Yes | Yes |
| Oversize mud-terrain | 0.3765 | **No** (0.3765 > 0.375) | Yes | Yes |

So the biggest Jimny tyre is exactly one lift kit away, and the refusal message says so. Downshifting is guarded by the same radius: `GearboxState.max_speed_for()` uses `ω(redline) × r / total_ratio`, so a taller tyre raises the speed at which a given gear may be selected.

---

## 8. Known gaps

1. **Tyre and rim parts are missing from the live catalogue** (§2). The lookup falls back to stock tyres; per-surface compound bonuses never apply; the tyre slot is uninstallable.
2. **Condition does not affect performance** (§5). Wear and repair costs are tracked; the multiplier is unused.
3. **Fourteen parameters are authored but never read**: con-rod `max_rpm`/`strength`, turbo `spool_rpm`/`efficiency`/`heat_mult`, intercooler `pressure_drop`, throttle `response`, exhaust `spool_mult`, bushing `compliance`, flare `width_add_m`, hood `vent`, brake `fade_c`, differential `grip_mult`, tyre `mu_slide`. Several appear in the workshop's effect lines as if they mattered.
4. **No purchase path in the UI.** `SaveManager.buy_part()` and `install_part()` exist and are correct; nothing calls them. `scripts/ui/upgrade_screen.gd` still drives the 2.0 `UpgradeDef`/`SaveManager.buy_upgrade` API, and `scripts/ui/garage_screen.gd:144` still calls the 3-argument `GarageModel.build(base, upgrades, config)` — a signature that no longer exists. Both screens error at runtime.
5. **`DynoModel` and `GarageModel.fitted_list()` have no caller.** The dyno maths is implemented and unused.
6. **Presets are stored but not reachable.** `save_preset` / `apply_preset` / `preset_names` work on the save; no screen invokes them.
7. **`GarageModel.sanitize_config()` trusts part ids more than it checks parts.** It validates slot and fitment, but a part whose vehicle list is empty fits everything by design — that is intentional for stock parts, and it means a hand-edited save can fit a tier-2 part it never bought. Ownership is only enforced on the `install_part()` path.
