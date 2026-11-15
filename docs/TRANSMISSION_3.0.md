# MUDRO 3.0 — Transmission

> **Revised in 3.1.** Three claims in this document are no longer true and the 3.1 code is
the authority: the bite point now moves the engagement window (it is per clutch part, not a
constant 0.36), the assist mode can no longer stall (it is a real automatic clutch, not a
shift bypass), and a sequential box no longer requires a clutch at all. Per-car cover data
(clamp rate, heat capacity, fade limit) is documented in
[`MUDRO_3_1_BASELINE_AUDIT.md`](MUDRO_3_1_BASELINE_AUDIT.md) §2.7.

**What this is:** how the driveline is described as data, how the three gearbox architectures behave, what the clutch and transfer case do, why a shift can be refused, and the contract between the mobile gear selector and the physics. For maintainers and for anyone debugging "the car will not go into gear".
**Scope:** `scripts/vehicle/transmission_profile.gd`, `gearbox_state.gd`, `clutch_state.gd`, the driveline half of `vehicle_body.gd`, and `scripts/input/gear_panel.gd`. Vehicle-specific ratios and transfer cases are tabulated per vehicle in `docs/VEHICLE_DATABASE.md`; this document explains the machinery.
**Version:** 1.0 — 2026-11-14 · code basis `project.godot` 3.0.0.

---

## 1. Nothing branches on a vehicle id

Every behaviour in this document is selected by data on `TransmissionProfile`, never by a `match vehicle_id`:

| Field | Type | Meaning |
|---|---|---|
| `id`, `name_fa`, `name_en` | String | Identity, shown in the garage and briefing |
| `kind` | enum | `MANUAL_H` (0), `MANUAL_SEQ` (1), `AUTOMATIC` (2) |
| `ratios` | PackedFloat32Array | Forward ratios, 1st → top |
| `reverse_ratio` | float | Positive magnitude; `ratio_for(-1)` returns it negated |
| `final_drive` | float | Differential ratio |
| `efficiency` | float | Driveline efficiency, applied to wheel torque |
| `has_reverse` | bool | Whether reverse exists at all |
| `shift_time` | float | Seconds of torque interruption at synchro = 1.0 |
| `synchro` | float | 0 = crash box (1.35 × shift time), 1 = fully synchronised |
| `requires_clutch` | bool | Whether the interlock applies |
| `clutch_type` | String | `single_plate`, `paddle`, `twin`, `torque_converter` |
| `max_torque_nm` | float | Gearbox torque rating (garage compatibility) |
| `durability` | float | Declared, not currently consumed |
| `overrev_margin` | float | Fraction above the gear's speed ceiling allowed on a downshift (0.04) |
| `converter_stall_mult` | float | Torque multiplication at stall (automatics only) |
| `converter_lock_rpm` | float | Driveline rpm at which multiplication reaches 1.0 |
| `auto_upshift_fraction` | float | Upshift point as a fraction of redline (0.68) |
| `auto_downshift_fraction` | float | Downshift point (0.30) |
| `kickdown_throttle` | float | Throttle fraction that arms kickdown (0.86) |
| `kickdown_rpm_fraction` | float | rpm below which kickdown triggers (0.55) |
| `kickdown_hold_s` | float | Seconds the upshift is blocked after a kickdown (1.1) |
| `slope_downshift_deg` | float | Grade above which a loaded automatic downshifts (9°) |
| `load_upshift_bias` | float | How much load raises the upshift point (0.14) |
| `launch_gear` | int | Declared first gear (1); the scheduler always pulls away in 1 |
| `ranges` | PackedStringArray | Legal range ids (`P R N D L` for automatics, empty for manuals) |

Gear indexing is uniform: `0` = neutral, `1..N` = forward, `-1` = reverse. `ratio_for()` returns the negative reverse ratio, and `total_ratio()` multiplies by final drive and the selected transfer ratio.

---

## 2. The three architectures

### 2.1 H-pattern manual (`MANUAL_H`)

The default for all five stock vehicles. The gearbox itself has no gate geometry — the gate is a property of the *profile*, because the UI has to draw a slot for exactly the gears that exist:

```
columns      = ceil(gear_count / 2) + (1 if has_reverse else 0)
gate_x(col)  = lerp(0.16, 0.84, col / (columns − 1))
gate_node(g) = column (g−1)/2, row (g−1) % 2 → y 0.28 (top) or 0.72 (bottom)
reverse      = last column, bottom node
```

So a six-speed box has four columns: `1 3 5` on the top row, `2 4 6` on the bottom, `R` alone in the fourth column. `gate_segments()` returns the neutral rail plus one vertical per occupied half-column, and `gate_project(point)` projects any knob position onto those segments. A diagonal from 2nd to 5th is not "discouraged" — it is geometrically impossible, because the projection only ever lands on a legal path.

Commit rule: the projected point must be within `GATE_COMMIT_RADIUS = 0.105` of a gear node, and the clutch must be ready (§5). Anything else returns `gear = 0` (neutral).

### 2.2 Sequential (`MANUAL_SEQ`)

One column, up = next gear, down = previous, springs back to centre. It is what the race gearbox part produces: `kind = MANUAL_SEQ`, `requires_clutch = false`, 0.14 s shifts. No stock vehicle uses it; the 2.0 roster had a clutchless dog box, the 3.0 roster does not.

### 2.3 Automatic (`AUTOMATIC`)

A torque-converter box with a five-position range gate. It exists as an *option* on every vehicle (`jimny_a4`, `hilux_a6`, `patrol_a5`, `pajero_a5`, `lc79_a6`); none is the stock choice.

The scheduler (`auto_update`) is load-, grade- and slip-aware rather than a single rpm threshold:

```
up_rpm   = redline × (0.68 + 0.14 × load_fraction)
down_rpm = redline × 0.30
kick     = throttle ≥ 0.86 and rpm < redline × 0.55
lug      = load_fraction > 0.55 and rpm < redline × 0.42
grade    = slope > 9° and rpm < redline × 0.60
spinning = |rear slip| > 1.2
```

Order of precedence: downshift first (kickdown, lugging or grade), then an upshift only if rpm is above `up_rpm`, road speed above 1.2 m/s, the wheels are not spinning, and the *projected* rpm in the next gear would not immediately lug (`> down_rpm × 1.25`). A minimum of 0.30 s in gear prevents hunting.

---

## 3. Ranges P / R / N / D / L

| Range | Top gear allowed | On selection | Notes |
|---|---|---|---|
| `P` | 0 | Forced to neutral | Parking lock: adds `handbrake_torque × 1.6` of brake to the rear axle |
| `R` | −1 | Forced to reverse | Upshifts to 1 automatically once rolling forward and throttle is applied |
| `N` | 0 | Forced to neutral | No drive, no engine braking through the box |
| `D` | `gear_count()` | Clamps the current gear into 1..N | Normal schedule |
| `L` | `min(2, gear_count())` | Clamps into 1..2 | Holds low gears; the scheduler will not upshift past 2 |

`set_range()` refuses a range the profile does not list (`profile.ranges`) and refuses a no-op change. `range_top_gear()` is also enforced inside `request_gear()`, so a manual `shift_up()` in `L` cannot exceed 2nd.

`gear_label()` returns the range id for an automatic and the gear number otherwise, which is what the HUD and the gear panel display.

---

## 4. Torque path

```
crank torque
  × damage.torque_multiplier()          (0.35 + 0.65 × engine health)
  × thermal derate                      (1.0 … 0.52)
  + idle torque − friction − engine braking
  → clutch (locked: crank torque; slipping: clamp(slip × stiffness, ±capacity × engagement))
  → × ratio (0 while shifting)
  → × transfer ratio
  → × final drive
  → × efficiency
  → × axle share (front/rear, and zero in 2H)
  → wheel torque
```

Then, per axle, `WheelAxis.integrate()` applies drive torque minus the tyre reaction torque (`F_long × r`), integrates wheel speed, and applies the brake torque separately with a hard stop at zero.

Two consequences worth stating plainly:

- **Neutral transmits nothing**, because `effective_ratio()` returns 0 while shifting or in neutral, and the clutch engagement is forced toward 0 whenever the ratio is 0.
- **Reverse is a negative ratio**, so reverse torque is real engine torque with the sign flipped; there is no separate reverse gear model.

### 4.1 Torque converter

For an automatic with `uses_converter()`:

```
converter = lerp(stall_mult, 1.0, clamp(|driveline_rpm| / lock_rpm, 0, 1))
```

with `stall_mult = 1.9` and `lock_rpm = 1400` for every automatic in the catalogue. It multiplies crank torque at low driveline speed and fades to 1:1 as the turbine catches up. It is **not** extra power: the clutch capacity still bounds what reaches the wheels, and the converter only applies when `auto_transmission` is true.

---

## 5. The clutch

`ClutchState` is a friction clutch with an explicit lock-up state. The public input convention is "pedal pressure": `VehicleInputState.clutch` is 1.0 when the pedal is on the floor. `VehicleBody.set_input_state()` converts once to `clutch_input = 1 − pressure`, where 1.0 means "foot off".

### 5.1 Engagement window

```
engagement_target(pedal) = clamp(((1 − pedal) − 0.14) / 0.56, 0, 1)
```

| Pedal | Engagement | Meaning |
|---|---|---|
| 0.00 – 0.30 | 1.00 | Fully engaged; 14 % of travel is free play |
| 0.55 | 0.55 | Mid-window |
| 0.86 – 1.00 | 0.00 | Fully open |

Engagement moves toward the target at 9.0 s⁻¹ when pressing and 5.5 s⁻¹ when releasing, so a dumped pedal is a real event: `release_rate > 3.2` with engagement between 0.25 and 0.85 sets `dumped`, which is what the stall path watches.

The clutch part carries a `bite_point` (0.62 stock, 0.56 heavy-duty, 0.48 twin-plate). **It is stored and displayed but does not move the engagement window** — `engagement_target()` uses the fixed 0.14/0.56 numbers above. Gap, recorded in §10.

### 5.2 Lock-up and slip

In `_update_drivetrain()` the clutch either locks or slips:

- **Lock** requires ratio ≠ 0, engagement > 0.55, no shift in progress, engine running, and |engine rpm − driveline rpm| < 140. When locked, engine rpm is *set* to driveline rpm and the transmitted torque is whatever the engine makes.
- **Slip** transmits `clamp(slip × stiffness, ±capacity × engagement)` and the engine integrates its own net torque, which is what lets the engine rev while the car creeps.

Clutch capacity comes from the clutch part (`capacity_nm`), else the gearbox rating × 1.05. Stiffness comes from the vehicle (`2.2` Jimny … `3.2` Pajero/LC79). A stiff spring model would oscillate at 120 Hz, which is why the lock state exists at all.

### 5.3 Automatic clutch (assist)

`configure_driver(clutch_assist)` decides the mode:

- **Assist on** (`auto_clutch = true`): shifts open the clutch automatically, and below 1.2 m/s the clutch slips itself so a beginner cannot stall at the lights. The pedal is still live; assist only *adds* disengagement.
- **Assist off**: `manual_clutch_enabled = true` for any box with `requires_clutch`, and the pedal must be pressed to 0.98 before a shift is accepted (§6). A stall is then the player's.

Starter interlock: while `engine.starter_timer > 0`, engagement is forced to 0 so cranking is never fought by the wheels.

### 5.4 Stall

`engine.rpm < stall_rpm` with engagement > 0.35 stalls the engine — but only when `stall_enabled` **and** `manual_clutch_enabled`. With assist on, the engine cannot stall; with assist off, it can.

---

## 6. Why a shift is refused

`GearboxState.can_engage(target, speed, clutch_ok)` returns one of six reasons, checked in this order:

| Reason constant | Condition | Player-facing meaning |
|---|---|---|
| `REJECT_RANGE` | `target > gear_count()` or `target < −1`, or reverse on a box without it | That gear does not exist |
| `REJECT_SHIFTING` | A shift is already in progress | Wait for the current shift |
| `REJECT_REVERSE` | Reverse requested above 1.4 m/s | Stop before selecting reverse |
| `REJECT_CLUTCH` | `requires_clutch` and the pedal is below 0.98 | Press the clutch |
| `REJECT_OVERREV` | `speed > max_speed_for(target) × 1.04` | That gear would over-rev the engine |
| `REJECT_STALLED` | Declared; not raised by `can_engage()` in the current build | — |

`max_speed_for(gear) = ω(engine_redline) × r_tyre / (|ratio| × final × transfer)` — the road speed at which that gear would hit the redline. With the 4 % margin, a downshift is allowed slightly above the exact limit, which is what makes a "just barely" downshift possible.

**Worked example — Hilux, 4H, 4500 rpm limit, 0.3876 m tyre:**

| Gear | Total ratio | Speed at redline |
|---|---|---|
| 1 | 17.14 | 38 km/h |
| 2 | 8.68 | 76 km/h |
| 3 | 5.17 | 127 km/h |
| 4 | 3.58 | 184 km/h |
| 5 | 2.96 | 222 km/h |
| 6 | 2.30 | 285 km/h |

At 200 km/h the car may be shifted into 5th (222 × 1.04 = 231) but not into 4th (184 × 1.04 = 191). In 4L every one of those speeds is divided by 2.566, so 4th tops out at 72 km/h — which is the whole reason low range exists on a climb.

A refused shift emits `shift_rejected(reason, gear)` and leaves the current gear engaged. It never silently does nothing.

### 6.1 Shift duration

```
shift_timer = max(0.05, shift_time × (1.35 − 0.35 × synchro))
```

Every catalogue profile has `synchro = 1.0`, so the timer equals `shift_time`: 0.28 s (Jimny), 0.30 s (Hilux), 0.32 s (LC79), 0.34 s (Patrol, Pajero), 0.40–0.46 s (the automatics), 0.14 s (race gearbox). A crash box would take 1.35× as long; none exists in the catalogue, so `synchro` is currently inert.

Changing the transfer range also interrupts torque for at least 0.25 s (`set_transfer` and `cycle_transfer` raise `shift_timer` to 0.25), which is why shifting range mid-climb costs momentum.

---

## 7. Transfer case

| Property | Behaviour |
|---|---|
| Modes | Authored per vehicle: `2H / 4H / 4L` (Jimny, Hilux, Patrol, LC79), `2H / 4H / 4HLc / 4LLc` (Pajero) |
| Ratios | One per mode, e.g. Hilux `1.000 / 1.000 / 2.566` |
| Default | Index 1 (4H) when more than one mode exists |
| Front drive | `transfer_drives_front()` is true only for `4H`, `4L` and `AWD` |
| Torque path | `total_ratio = gear × final_drive × transfer_ratio` |
| Interruption | 0.25 s on every change |

`2H` zeroes the front axle's torque share, which turns any part-time vehicle into rear-wheel drive without touching `VehicleDef.drivetrain` (still `AWD`). `4L` multiplies the whole driveline, so the same engine rpm means a lower road speed and proportionally more wheel torque.

**Defect:** `4HLc` — the Pajero's locked-centre high range — is not in the `transfer_drives_front()` list, so selecting it leaves the front axle undriven. It should behave like `4H` with a locked centre differential; today it behaves like `2H` with an extra label.

---

## 8. Differential

Three modes, authored on `VehicleDef.diff_modes` (`open`, `lsd`, `locked`):

| Mode | Speed coupling | Extra grip (single driven axle only) |
|---|---|---|
| `open` | None | 1.000 |
| `lsd` | Axles pulled together with k = 0.35 | 1.035 |
| `locked` | Axles forced equal with k = 1.00 | 1.070 |

`_apply_differential()` blends the two axle speeds with contact weighting (a wheel in the air counts 0.25), so a locked differential keeps a spinning axle and a gripping axle at the same speed. In this side-view model the two axles stand in for front and rear, which is exactly the pair a **centre** differential couples: there is no left/right differential, and therefore no modelling of a cross-axle open diff.

The extra grip multiplier applies only when a *single* axle is driven — with both driven, the speed coupling already does the work and adding grip on top would double-count. The differential part's own `grip_mult` parameter is **not** used by the physics (see `docs/TUNING_SYSTEM.md` §3.2).

---

## 9. The mobile gear selector contract

`GearPanel` (`scripts/input/gear_panel.gd`) is a `Control` that draws a real gate and owns exactly one finger.

### 9.1 Signals

| Signal | Emitted when | Consumer |
|---|---|---|
| `gear_requested(gear)` | An H-pattern or sequential move has committed | `RaceScene` → `VehicleBody.select_gear()` |
| `range_requested(range_id)` | A row of the automatic gate is tapped | `RaceScene` → `GearboxState.set_range()` |
| `close_requested` | The panel's close affordance is used | `TouchControls` |

The panel **never** writes to the vehicle. It asks; the gearbox decides; the result comes back through `set_state()` and, on refusal, `flash_reject()`.

### 9.2 Per-architecture behaviour

| Architecture | Press | Drag | Release | Commit condition |
|---|---|---|---|---|
| H-pattern | Knob jumps to the finger's projection | Knob follows the projection of the finger on the legal gate | If no gear node was reached, knob returns to neutral | Reaching a node within 0.105 of it |
| Sequential | Arms the lever | Vertical travel > 0.42 emits ±1 and disarms | Disarms | Travel past the detent, re-armed only by returning to the middle 20 % |
| Automatic | Tapping a row emits that range | — | — | Row index = `int(t × ranges.size())` |

### 9.3 Clutch interlock at the panel

In H-pattern mode a commit is only sent when `_clutch_ready()` is true — either the box does not require a clutch, or clutch assist is on, or the pedal is at `VehicleInputState.CLUTCH_FULL` (0.98). Otherwise the panel warns locally ("clutch needed"), vibrates, springs the knob to neutral and sends nothing. This is a *panel* guard on top of the gearbox guard; both exist because the panel must not leave a knob visually engaged in a gear the gearbox refused.

### 9.4 State feedback

`set_state(gear, range, clutch, speed, assist)` is called every frame with live telemetry. It moves the knob toward `gate_node(gear)` with a 0.25 lerp (unless the player is dragging), updates the title (`"6-speed manual · 3"` or `"6-speed automatic · D"`), and draws the clutch bar: green when the pedal is at 0.98 or assist is on, amber otherwise. `flash_reject(reason)` maps `clutch`, `overrev`, `reverse`, `shifting` and everything else to a localised 1.6 s message.

---

## 10. Known gaps

1. **`4HLc` does not drive the front axle** (§7).
2. **The clutch bite point is decorative.** `bite_point` is stored per clutch part and never used by `engagement_target()` (§5.1).
3. **`synchro` is inert** — every profile is 1.0, so the crash-box branch never runs.
4. **No left/right differential**, therefore no cross-axle behaviour: the differential is a centre coupling only.
5. **`TransmissionProfile.durability` and `launch_gear` are declared but unused.**
6. **The gearbox is always rebuilt from the gearbox part.** `GarageModel.build()` replaces `v.transmissions` with a single profile derived from the fitted part, so a vehicle's *other* catalogue boxes (for example the Jimny's 4-speed automatic) are unreachable through `VehicleBody` unless they are fitted as parts — and no gearbox part reproduces them.
7. **`GearboxState.config` is a legacy `GearboxConfig` mirror.** It is kept in sync at setup and never used by the physics; leaving it in place invites two sources of truth.
