# MUDRO 3.0 — Vehicle Database

**What this is:** the specification of the five vehicles MUDRO 3.0 simulates — one documented variant each — together with the engine output the parts system actually derives from that data. For maintainers, vehicle authors and anyone checking a claim about a car against the build.
**Scope:** the five entries in `scripts/vehicle/vehicle_catalog.gd`, the fields on `VehicleDef` they populate, and the stock `EngineBuild` that `GarageModel.build(vehicle, empty_config())` produces. Published-figure provenance (URLs, evidence tiers, conflicts between sources) lives in `docs/VEHICLE_SPEC_SOURCES.md` and is **not** duplicated here.
**Version:** 1.0 — 2026-11-14 · code basis `project.godot` 3.0.0, `VehicleCatalog.DATA` as checked in.

---

## 1. How to read this document

Two kinds of number appear below and they are never mixed:

- **Documented** — the published figure for the exact variant, recorded in the vehicle's `spec` dictionary and in `docs/VEHICLE_SPEC_SOURCES.md`. These are the target values.
- **Derived** — what `EngineBuild.derive()` computes from the fitted parts at stock condition, i.e. what the physics and the dyno will show. These are the values the game actually uses.

Where the two disagree, §2 explains why, and `docs/TUNING_SYSTEM.md` shows how parts move the derived figure.

Unit conventions: power in kW, torque in N·m, mass in kg (kerb), dimensions in metres (converted from the millimetre figures in the source tables), ratios dimensionless, tyre radius in metres to the tread.

**Names are descriptive.** Toyota, Land Cruiser, Hilux, Nissan, Patrol, Suzuki, Jimny, Mitsubishi and Pajero are trademarks of their owners. MUDRO 3.0 uses the names only to identify the real vehicles whose specifications inform the simulation, and is not affiliated with, sponsored by or endorsed by any of them. No manufacturer logos or badges appear in the art. See `docs/VEHICLE_SPEC_SOURCES.md` §10.

---

## 2. Derived stock output — the headline table

Produced by `GarageModel.build(v, GarageModel.empty_config())` and printed by `tools/smoke_v3.gd`; the run is recorded in `local-builds/logs/smoke_v3.log`.

| Vehicle | Documented power | Documented torque | Derived power | Derived torque | Power delta | Torque delta |
|---|---|---|---|---|---|---|
| `jimny_jb74` Suzuki Jimny 1.5 | 75 kW @ 6000 | 130 N·m @ 4000 | 64.4 kW @ 5600 | 126.1 N·m @ 4000 | −14.1 % | −3.0 % |
| `hilux_an120` Toyota Hilux 2.8 GD-6 | 150 kW @ 3000 | 420 N·m @ 1400 | 98.1 kW @ 2725 | 407.3 N·m @ 1400 | −34.6 % | −3.0 % |
| `patrol_y61` Nissan Patrol 3.0 Di | 118 kW @ 3200 | 380 N·m @ 2000 | 108.4 kW @ 3275 | 368.6 N·m @ 2000 | −8.1 % | −3.0 % |
| `pajero_v80` Mitsubishi Pajero 3.2 DiD | 125 kW @ 3800 | 358 N·m @ 2000 | 98.7 kW @ 3150 | 347.5 N·m @ 2000 | −21.0 % | −2.9 % |
| `lc79` Toyota Land Cruiser 79 4.2 D | 96 kW @ 3800 | 285 N·m @ 2200 | 74.1 kW @ 3350 | 245.3 N·m @ 2200 | −22.8 % | −13.9 % |

### 2.1 Why torque is 3 % low on every vehicle

`EngineBuild.derive()` computes the flow multiplier as

```
flow_mult = min(min(flow_head, flow_intake), min(flow_throttle, flow_exhaust × 0.97)) × flow_cam
```

With stock parts every factor is 1.0 except the exhaust's built-in 0.97, so volumetric efficiency is 0.90 × 0.97 = 0.873 rather than 0.90 (`scripts/parts/engine_build.gd:180-186`). Every `torque_scale` in the catalogue was calibrated against a 0.90 VE, so the stock build lands 3 % under the documented torque. This is uniform and deliberate-looking, but it is not described anywhere in the code as intentional.

### 2.2 Why the naturally aspirated 1HZ loses another 11 %

The charge-temperature model always adds a compressor rise of `38 + 95 × boost_bar` kelvin. The code exempts a naturally aspirated engine only when `aspiration == "na"` exactly:

```gdscript
if b.aspiration == "na":
    b.density_ratio = 1.0
    b.charge_temp_c = AMBIENT_C + 8.0
```

The Jimny is `"na"` and is exempt. The Land Cruiser 1HZ is `"na_diesel"`, which does **not** match, so it is charged a phantom 38 K compressor rise at zero boost: charge temperature 63 °C instead of 33 °C, air density ratio 0.887 instead of 1.0. That is the entire 11 % gap between its −3 % and the other vehicles' −3 %: 245.3 N·m instead of the ~282 N·m the same calibration would give. Recorded as a defect, not as a design choice.

### 2.3 Why power falls further than torque

The torque curve is a single generic shape — a Gaussian centred on the documented torque rpm plus a top-end penalty (`engine_build.gd:96-113`). Real turbo diesels hold a broad torque plateau, so their power keeps climbing to a peak near 3000–3800 rpm; this curve has already fallen by then. The Hilux is the clearest case: it makes its documented 420 N·m at 1400 rpm (minus the 3 %), but at 2725 rpm the curve has decayed enough that peak power is 98 kW instead of 150 kW.

The practical consequence is that the *relative* ranking of the five vehicles is right — Patrol strongest, LC79 weakest — while the absolute power of the turbo diesels is optimistic-to-pessimistic in the wrong direction. `docs/TUNING_SYSTEM.md` §7 shows a build that recovers most of it.

---

## 3. Suzuki Jimny 1.5 (JB74)

Light, short, rigid-axled. The starter vehicle: free, always owned, and the only one without a winch.

| Field | Value |
|---|---|
| Model / variant | Suzuki Jimny JB74, 3-door, 1.5 GLX, 5-speed manual |
| Model year / market basis | 2020 (nominal; the source page is undated) |
| Class | Compact 4×4 |
| Price / unlock | 0 credits / owned from the start |
| Drivetrain | Part-time 4WD, 2H / 4H / 4L |
| Fuel | Petrol |

### 3.1 Engine — K15B

| Field | Value |
|---|---|
| Code / family | K15B / `k15b` |
| Displacement, cylinders | 1462 cc, inline-4 |
| Aspiration | Naturally aspirated (`na`) |
| Compression (model input) | 10.5 : 1 |
| Documented power / torque | 75 kW @ 6000 rpm / 130 N·m @ 4000 rpm |
| Redline / idle (model) | 6000 / 750 rpm |
| Engine inertia / friction torque | 0.10 kg·m² / 9.0 N·m |
| Injector flow / power ceiling | 200 cc / 86 kW |
| Fuel pump flow / power ceiling | 85 L/h / 90 kW |
| Radiator / coolant | 44 kW / 5.0 L |
| Torque calibration (`torque_scale`) | 1.074 |
| Boost / spool | 0.00 bar / — |

### 3.2 Transmission

| Box | Kind | Ratios | Reverse | Final | Eff. | Shift |
|---|---|---|---|---|---|---|
| `jimny_m5` (stock) | 5-speed H-pattern manual | 4.425 / 2.304 / 1.674 / 1.190 / 1.000 | 5.151 | 4.090 | 0.90 | 0.28 s |
| `jimny_a4` (option) | 4-speed automatic | 2.875 / 1.568 / 1.000 / 0.697 | 2.300 | 4.300 | 0.88 | 0.42 s |

Transfer: 2H 1.000 · 4H 1.000 · 4L 2.002. Crawl ratio in 1st/low = 4.425 × 4.090 × 2.002 = **36.2**. Gearing ceiling in 5th at 6000 rpm = **192 km/h** (drag-limited in practice; see §8).

### 3.3 Chassis

| Field | Value |
|---|---|
| Kerb mass | 1095 kg |
| Wheelbase / length / width / height | 2.250 / 3.645 / 1.645 / 1.725 m |
| Centre of mass height / inertia scale | 0.44 m / 0.82 |
| Frontal area / drag coefficient | 1.72 m² / 0.62 |
| Tyre | 195/80 R15, radius 0.3465 m, width 0.195 m, µ-scale 0.98 |
| Wheel mass / rolling resistance / peak slip | 18.6 kg / 0.030 / 0.15 |
| Suspension | 3-link rigid axle, coil springs, front and rear |
| Rest / travel / droop | 0.24 / 0.22 / 0.09 m |
| Spring rate F / R | 21 000 / 20 000 N·m⁻¹ |
| Dampers F (comp/reb) / R (comp/reb) | 1500 / 1900 · 1450 / 1800 N·s·m⁻¹ |
| Bump-stop rate | 62 000 N·m⁻¹ |
| Brake torque F / R / handbrake | 1750 / 1250 / 2400 N·m |
| Clutch capacity / stiffness | 210 N·m / 2.2 |
| Durability / impact tolerance | 0.86 / 7.5 |
| Max tyre radius (no lift) | 0.375 m |
| Winch | None |
| Body sprite | `res://assets/vehicles/jimny_jb74/body.svg` |
| Accent colour | `#d6993d` (0.84, 0.60, 0.24) |

### 3.4 Derived stock build

64.4 kW @ 5600 rpm · 126.1 N·m @ 4000 rpm · naturally aspirated (density ratio 1.0) · fuel ceiling 86 kW · radiator 44 kW · 1095 kg · 86 hp · **12.7 kg/hp**.

The engine is not fuel-limited and its radiator is not marginal at stock power. What the numbers do not convey is the shape of the problem: 64 kW in a 1.1 t short-wheelbase car is enough for tight forest lines and not enough for a sustained climb, which is exactly the intent stated in its brief.

---

## 4. Toyota Hilux 2.8 GD-6 (AN120)

The all-round workhorse and the reference vehicle for every tuning example in these documents.

| Field | Value |
|---|---|
| Model / variant | Toyota Hilux AN120, Invincible double cab 4×4, 2.8 GD-6, 6-speed manual |
| Model year / market basis | 2021 (UK sheet) |
| Class | Double-cab pickup |
| Price / unlock | 3200 credits / complete `zagros_03` |
| Drivetrain | Part-time 4WD, 2H / 4H / 4L |
| Fuel | Diesel |

### 4.1 Engine — 1GD-FTV

| Field | Value |
|---|---|
| Code / family | 1GD-FTV / `1gd_ftv` |
| Displacement, cylinders | 2755 cc, inline-4 |
| Aspiration | Turbocharged common-rail diesel (`turbo_diesel`) |
| Compression (model input) | 15.6 : 1 |
| Documented power / torque | 150 kW @ 3000 rpm / 420 N·m @ 1400 rpm |
| Redline / idle (model) | 4600 / 700 rpm |
| Engine inertia / friction torque | 0.28 kg·m² / 22.0 N·m |
| Stock boost / spool | 1.35 bar / 1600 rpm |
| Injector flow / power ceiling | 360 cc / 168 kW |
| Fuel pump flow / power ceiling | 150 L/h / 180 kW |
| Radiator / coolant | 142 kW / 9.2 L |
| Torque calibration (`torque_scale`) | 0.987 |

### 4.2 Transmission

| Box | Kind | Ratios | Reverse | Final | Eff. | Shift |
|---|---|---|---|---|---|---|
| `hilux_m6` (stock) | 6-speed H-pattern manual | 4.784 / 2.423 / 1.443 / 1.000 / 0.826 / 0.643 | 4.066 | 3.583 | 0.90 | 0.30 s |
| `hilux_a6` (option) | 6-speed automatic | 3.600 / 2.090 / 1.488 / 1.000 / 0.687 / 0.580 | 3.732 | 3.909 | 0.88 | 0.40 s |

Transfer: 2H 1.000 · 4H 1.000 · 4L 2.566. Crawl ratio in 1st/low = **44.0**. Gearing ceiling in 6th at 4600 rpm = **292 km/h**.

The 4L figure is Tier B evidence: Toyota's workshop manual gives 1.000/2.566 for the Hilux 4WD transfer family, and the AN120's VF2A unit prints no ratio in the factory sheet. Labelled as inference in `docs/VEHICLE_SPEC_SOURCES.md` §8.

### 4.3 Chassis

| Field | Value |
|---|---|
| Kerb mass | 2120 kg (lightest documented 2.8 6MT double cab; the sheet's range is 2120–2335 kg) |
| Wheelbase / length / width / height | 3.085 / 5.325 / 1.855 / 1.815 m |
| Centre of mass height / inertia scale | 0.62 m / 1.12 |
| Frontal area / drag coefficient | 2.92 m² / 0.68 |
| Tyre | 265/60 R18, radius 0.3876 m, width 0.265 m, µ-scale 0.98 |
| Wheel mass / rolling resistance / peak slip | 36.0 kg / 0.030 / 0.15 |
| Suspension | Double wishbone front, leaf-spring rigid rear axle |
| Rest / travel / droop | 0.26 / 0.24 / 0.10 m |
| Spring rate F / R | 38 000 / 42 000 N·m⁻¹ |
| Dampers F (comp/reb) / R (comp/reb) | 3200 / 3900 · 3000 / 3600 N·s·m⁻¹ |
| Bump-stop rate | 98 000 N·m⁻¹ |
| Brake torque F / R / handbrake | 3000 / 1900 / 3800 N·m |
| Clutch capacity / stiffness | 520 N·m / 2.8 |
| Durability / impact tolerance | 1.05 / 9.5 |
| Max tyre radius (no lift) | 0.405 m |
| Winch | Fitted, 15 900 N (mass × 7.5), 22 m rope |
| Accent colour | `#7a8557` (0.48, 0.52, 0.34) |

### 4.4 Derived stock build

98.1 kW @ 2725 rpm · 407.3 N·m @ 1400 rpm · 1.35 bar · fuel ceiling 168 kW · radiator 142 kW · 2120 kg · 132 hp · **16.1 kg/hp** · **192 N·m per tonne**.

Neither `fuel_limited` nor `cooling_marginal` is raised at stock. That matters for the worked examples: any power gain from here has to come from more air, not from unblocking a restriction.

---

## 5. Nissan Patrol Y61 3.0 Di (ZD30DDTi)

Heavy, coil-sprung on both live axles, and the strongest engine in the roster relative to its documentation.

| Field | Value |
|---|---|
| Model / variant | Nissan Patrol Y61 ST 5-door wagon, 3.0 Di, 5-speed manual |
| Model year / market basis | 2010 (Australian brochure, updated 2015) |
| Class | Full-size expedition 4×4 |
| Price / unlock | 6500 credits / complete `pine_02` |
| Drivetrain | Part-time 4WD, 2H / 4H / 4L |
| Fuel | Diesel |

### 5.1 Engine — ZD30DDTi

| Field | Value |
|---|---|
| Code / family | ZD30DDTi / `zd30` |
| Displacement, cylinders | 2953 cc, inline-4 |
| Aspiration | Turbocharged direct-injection diesel |
| Compression (model input) | 17.9 : 1 |
| Documented power / torque | 118 kW @ 3200 rpm / 380 N·m @ 2000 rpm |
| Redline / idle (model) | 4600 / 700 rpm |
| Engine inertia / friction torque | 0.30 kg·m² / 26.0 N·m |
| Stock boost / spool | 1.00 bar / 1800 rpm |
| Injector flow / power ceiling | 300 cc / 140 kW |
| Fuel pump flow / power ceiling | 130 L/h / 150 kW |
| Radiator / coolant | 122 kW / 9.8 L |
| Torque calibration (`torque_scale`) | 0.939 |

### 5.2 Transmission

| Box | Kind | Ratios | Reverse | Final | Eff. | Shift |
|---|---|---|---|---|---|---|
| `patrol_m5` (stock) | 5-speed H-pattern manual | 4.556 / 2.625 / 1.591 / 1.000 / 0.837 | 4.246 | 4.111 | 0.89 | 0.34 s |
| `patrol_a5` (option) | 5-speed automatic | 3.540 / 2.264 / 1.471 / 1.000 / 0.834 | 2.370 | 3.545 | 0.87 | 0.46 s |

Transfer: 2H 1.000 · 4H 1.000 · 4L 2.020. Crawl ratio in 1st/low = **37.8**. Gearing ceiling in 5th at 4600 rpm = **199 km/h**.

### 5.3 Chassis

| Field | Value |
|---|---|
| Kerb mass | 2478 kg |
| Wheelbase / length / width / height | 2.970 / 5.050 / 1.940 / 1.855 m |
| Centre of mass height / inertia scale | 0.72 m / 1.30 |
| Frontal area / drag coefficient | 3.30 m² / 0.78 |
| Tyre | 275/65 R17, radius 0.3947 m, width 0.275 m, µ-scale 0.98 |
| Wheel mass / rolling resistance / peak slip | 42.0 kg (clamped from 42.1) / 0.030 / 0.15 |
| Suspension | 3-link coil front, 5-link coil rear, live axles |
| Rest / travel / droop | 0.30 / 0.26 / 0.11 m |
| Spring rate F / R | 46 000 / 50 000 N·m⁻¹ |
| Dampers F (comp/reb) / R (comp/reb) | 4200 / 5000 · 3800 / 4600 N·s·m⁻¹ |
| Bump-stop rate | 120 000 N·m⁻¹ |
| Brake torque F / R / handbrake | 3300 / 2400 / 4200 N·m |
| Clutch capacity / stiffness | 480 N·m / 3.0 |
| Durability / impact tolerance | 1.22 / 10.5 |
| Max tyre radius (no lift) | 0.420 m |
| Winch | Fitted, 18 585 N, 22 m rope |
| Accent colour | `#4d6b5c` (0.30, 0.42, 0.36) |

### 5.4 Derived stock build

108.4 kW @ 3275 rpm · 368.6 N·m @ 2000 rpm · 1.00 bar · fuel ceiling 140 kW · radiator 122 kW · 2478 kg · 145 hp · **17.0 kg/hp** · **149 N·m per tonne**.

The highest absolute power in the roster and the highest durability, held back by the lowest power-to-mass ratio of the three big diesel wagons. It is a rock-crawler, not a hill-climb car.

---

## 6. Mitsubishi Pajero 3.2 DiD (V80)

Independent suspension on both axles, the only four-mode transfer case, and the highest clutch capacity in the roster.

| Field | Value |
|---|---|
| Model / variant | Mitsubishi Pajero V80 GLX 5-door, 3.2 DiD, 5-speed manual |
| Model year / market basis | 2012 (MY2010 brochure; 2012 label in the catalogue) |
| Class | Endurance SUV |
| Price / unlock | 8200 credits / complete `alpine_03` |
| Drivetrain | Super Select 4WD, 2H / 4H / 4HLc / 4LLc |
| Fuel | Diesel |

The catalogue labels this vehicle `2012` while the specification source is the MY2010 brochure. The mechanical data is the brochure's; only the label differs.

### 6.1 Engine — 4M41

| Field | Value |
|---|---|
| Code / family | 4M41 / `4m41` |
| Displacement, cylinders | 3200 cc, inline-4 |
| Aspiration | Turbocharged common-rail diesel |
| Compression (model input) | 16.5 : 1 — the factory sheet states 17.0 : 1 |
| Documented power / torque | 125 kW @ 3800 rpm / 358 N·m @ 2000 rpm |
| Redline / idle (model) | 4200 / 700 rpm |
| Engine inertia / friction torque | 0.30 kg·m² / 26.0 N·m |
| Stock boost / spool | 1.20 bar / 1700 rpm |
| Injector flow / power ceiling | 330 cc / 148 kW |
| Fuel pump flow / power ceiling | 140 L/h / 160 kW |
| Radiator / coolant | 125 kW / 10.5 L |
| Torque calibration (`torque_scale`) | 0.761 |

Compression is carried but not used to compute torque or power in `EngineBuild` (pistons override it and nothing reads it afterwards), so the 16.5 vs 17.0 difference has no effect on the simulation — it is a documentation mismatch only. The Jimny carries 10.5 against a documented 10.0 for the same reason.

### 6.2 Transmission

| Box | Kind | Ratios | Reverse | Final | Eff. | Shift |
|---|---|---|---|---|---|---|
| `pajero_m5` (stock) | 5-speed H-pattern manual | 4.234 / 2.238 / 1.398 / 1.000 / 0.760 | 3.553 | 4.100 | 0.89 | 0.34 s |
| `pajero_a5` (option) | 5-speed automatic | 3.520 / 2.042 / 1.400 / 1.000 / 0.716 | 3.400 | 3.917 | 0.88 | 0.44 s |

Transfer: 2H 1.000 · 4H 1.000 · 4HLc 1.000 · 4LLc 1.900. Crawl ratio in 1st/4LLc = **33.0**. Gearing ceiling in 5th at 4200 rpm = **197 km/h**.

`4HLc` is modelled as a locked-centre high range with the same ratio as 4H: `transfer_drives_front()` returns true for `4H`, `4L` and `AWD` but **not** for `4HLc` (`scripts/vehicle/gearbox_state.gd:243-246`), so selecting 4HLc in the current build leaves the front axle undriven. Recorded as a defect.

### 6.3 Chassis

| Field | Value |
|---|---|
| Kerb mass | 2270 kg |
| Wheelbase / length / width / height | 2.780 / 4.900 / 1.875 / 1.900 m |
| Centre of mass height / inertia scale | 0.66 m / 1.24 |
| Frontal area / drag coefficient | 3.05 m² / 0.72 |
| Tyre | 265/65 R17, radius 0.3882 m, width 0.265 m, µ-scale 0.98 |
| Wheel mass / rolling resistance / peak slip | 38.6 kg / 0.030 / 0.15 |
| Suspension | Double wishbone front, multi-link rear, independent |
| Rest / travel / droop | 0.28 / 0.25 / 0.10 m |
| Spring rate F / R | 42 000 / 46 000 N·m⁻¹ |
| Dampers F (comp/reb) / R (comp/reb) | 3600 / 4300 · 3300 / 4000 N·s·m⁻¹ |
| Bump-stop rate | 105 000 N·m⁻¹ |
| Brake torque F / R / handbrake | 3300 / 2400 / 4000 N·m |
| Clutch capacity / stiffness | 620 N·m / 3.2 (highest in the roster) |
| Durability / impact tolerance | 1.12 / 10.0 |
| Max tyre radius (no lift) | 0.415 m |
| Winch | Fitted, 17 025 N, 22 m rope |
| Accent colour | `#61758f` (0.38, 0.46, 0.56) |

### 6.4 Derived stock build

98.7 kW @ 3150 rpm · 347.5 N·m @ 2000 rpm · 1.20 bar · fuel ceiling 148 kW · radiator 125 kW · 2270 kg · 132 hp · **17.1 kg/hp** · **153 N·m per tonne**.

It is the only vehicle with independent suspension at both ends, and its 0.66 m centre of mass sits between the Hilux (0.62 m) and the Patrol (0.72 m). Its 148 kW fuel ceiling means the stock injectors become the binding limit before the block does.

---

## 7. Toyota Land Cruiser 79 4.2 D (1HZ)

The endgame truck: a 4.2 litre straight-six with no turbo, live axles at both ends, and the most durability in the roster.

| Field | Value |
|---|---|
| Model / variant | Toyota Land Cruiser 79 double cab, 4.2 D, 5-speed manual |
| Model year / market basis | 2026 (South African sheet, issued 2026-01-14) |
| Class | Heavy-duty 4×4 pickup |
| Price / unlock | 14 000 credits / complete `black_ridge_02` |
| Drivetrain | Part-time 4WD, 2H / 4H / 4L |
| Fuel | Diesel |

### 7.1 Engine — 1HZ

| Field | Value |
|---|---|
| Code / family | 1HZ / `1hz` |
| Displacement, cylinders | 4164 cc, inline-6 |
| Aspiration | Naturally aspirated diesel (`na_diesel`) |
| Compression (model input) | 22.4 : 1 |
| Documented power / torque | 96 kW @ 3800 rpm / 285 N·m @ 2200 rpm |
| Redline / idle (model) | 4200 / 650 rpm |
| Engine inertia / friction torque | 0.34 kg·m² / 34.0 N·m |
| Stock boost / spool | 0.00 bar / — |
| Injector flow / power ceiling | 420 cc / 108 kW |
| Fuel pump flow / power ceiling | 120 L/h / 116 kW |
| Radiator / coolant | 92 kW / 13.4 L (largest capacity in the roster) |
| Torque calibration (`torque_scale`) | 0.827 |

This is the vehicle affected by the `na_diesel` charge-temperature defect in §2.2: its build loses 11 % of air density to a compressor rise that does not exist, on top of the universal 3 %.

### 7.2 Transmission

| Box | Kind | Ratios | Reverse | Final | Eff. | Shift |
|---|---|---|---|---|---|---|
| `lc79_m5` (stock) | 5-speed H-pattern manual | 4.313 / 2.330 / 1.436 / 1.000 / 0.838 | 4.220 | 4.100 | 0.89 | 0.32 s |
| `lc79_a6` (option) | 6-speed automatic | 3.600 / 2.090 / 1.488 / 1.000 / 0.687 / 0.580 | 3.732 | 3.909 | 0.87 | 0.42 s |

Transfer: 2H 1.000 · 4H 1.000 · 4L **2.488**. Crawl ratio in 1st/low = **44.0** — the same as the Hilux, from a taller first gear and a shorter transfer. Gearing ceiling in 5th at 4200 rpm = **179 km/h**, the lowest of the five.

The 2.488 low-range figure is **provisional**: the Toyota South Africa sheet lists a transfer case but prints no ratio, and no factory or workshop document for the 79 could be opened. `docs/VEHICLE_SPEC_SOURCES.md` §8 records it as an explicit gameplay value, not as factory data. The 6-speed automatic option is the Hilux's `hilux_a6` ratio set (3.909 final); that pairing is a catalogue choice, not a documented 79 Series gearbox.

### 7.3 Chassis

| Field | Value |
|---|---|
| Kerb mass | 2225 kg |
| Wheelbase / length / width / height | 3.180 / 5.235 / 1.870 / 1.945 m |
| Centre of mass height / inertia scale | 0.70 m / 1.28 |
| Frontal area / drag coefficient | 3.20 m² / 0.80 (highest drag in the roster) |
| Tyre | 265/70 R16, radius 0.3887 m, width 0.265 m, µ-scale 0.98 |
| Wheel mass / rolling resistance / peak slip | 37.8 kg / 0.030 / 0.15 |
| Suspension | Rigid axle coil front, rigid axle leaf rear |
| Rest / travel / droop | 0.30 / 0.27 / 0.11 m |
| Spring rate F / R | 50 000 / 56 000 N·m⁻¹ |
| Dampers F (comp/reb) / R (comp/reb) | 4600 / 5400 · 4200 / 5000 N·s·m⁻¹ |
| Bump-stop rate | 135 000 N·m⁻¹ |
| Brake torque F / R / handbrake | 3100 / 2200 / 4400 N·m |
| Clutch capacity / stiffness | 520 N·m / 3.2 |
| Durability / impact tolerance | 1.30 / 11.0 (highest in the roster) |
| Max tyre radius (no lift) | 0.430 m |
| Winch | Fitted, 16 688 N, 22 m rope |
| Accent colour | `#c7b28c` (0.78, 0.70, 0.55) |

### 7.4 Derived stock build

74.1 kW @ 3350 rpm · 245.3 N·m @ 2200 rpm · naturally aspirated · fuel ceiling 108 kW · radiator 92 kW · 2225 kg · 99 hp · **22.4 kg/hp** · **110 N·m per tonne**.

The worst power-to-mass and torque-to-mass figures in the roster, which is exactly why `black_ridge_03` exists: 194 m of gain at 8.4° average is not survivable on brute force, only on low range and gear discipline.

---

## 8. Cross-vehicle comparison

| | Jimny | Hilux | Patrol | Pajero | LC79 |
|---|---|---|---|---|---|
| Derived power (kW) | 64.4 | 98.1 | 108.4 | 98.7 | 74.1 |
| Derived torque (N·m) | 126.1 | 407.3 | 368.6 | 347.5 | 245.3 |
| Kerb mass (kg) | 1095 | 2120 | 2478 | 2270 | 2225 |
| kg per hp | 12.7 | 16.1 | 17.0 | 17.1 | 22.4 |
| N·m per tonne | 115 | 192 | 149 | 153 | 110 |
| Crawl ratio (1st × low) | 36.2 | 44.0 | 37.8 | 33.0 | 44.0 |
| Gearing ceiling (km/h) | 192 | 292 | 199 | 197 | 179 |
| Max tyre radius (stock) | 0.375 | 0.405 | 0.420 | 0.415 | 0.430 |
| Durability | 0.86 | 1.05 | 1.22 | 1.12 | 1.30 |

Two things this table does not show, and they matter more than the numbers:

- **Gearing ceilings are not top speeds.** At its 292 km/h ceiling the Hilux would need about 646 kW to overcome drag (0.5 × 1.225 × 0.68 × 2.92 × 81² N ≈ 8.0 kN at 81 m/s). Drag, not gearing, is the real limit; see `docs/TUNING_SYSTEM.md` §6.
- **All five are modelled as AWD when the transfer case drives the front axle.** `VehicleDef.drivetrain` is `AWD` for every vehicle, with a front torque split of 0.50 (Jimny, Patrol, LC79) or 0.42 (Hilux, Pajero). In 2H the front share is zeroed by the transfer logic, which is what makes part-time four-wheel drive behave correctly. There is no separate left/right differential: the two modelled axles stand in for front and rear.

---

## 9. Gaps and inconsistencies

Recorded here rather than smoothed over.

1. **Stock power is under-documented on three of five vehicles** (§2.3). Torque is within 3 % everywhere except the LC79.
2. **`na_diesel` is not exempt from the compressor temperature rise** (§2.2) — a one-line condition in `EngineBuild.derive()`.
3. **`4HLc` does not drive the front axle** (§6.2).
4. **Compression ratios differ from the factory sheets** on the Pajero (16.5 vs 17.0) and Jimny (10.5 vs 10.0). No physical effect in the current build.
5. **The LC79 low range is provisional** and its automatic option is borrowed from the Hilux.
6. **Front and rear tyres are the same object.** `VehicleCatalog._from_row()` assigns `v.tire_rear = v.tire_front`, so staggered fitments cannot be represented.
7. **No vehicle has a documented top speed in the data.** `top_speed_kmh()` exists but is computed from gearing and redline only, and nothing displays it as a performance claim.
8. **Wheel mass is derived, not documented:** `clamp(mass × 0.017, 16, 42)` kg per corner (`vehicle_catalog.gd:376-378`), which pushes the Patrol to the 42 kg clamp.
