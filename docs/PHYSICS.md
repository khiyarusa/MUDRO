# MUDRO — Vehicle physics

## 1. Units and the conversion boundary

The simulation is written in SI units. Godot's 2D world is in pixels, so exactly one place
converts (`scripts/core/units.gd`):

| Quantity | Engine value | Conversion |
|---|---|---|
| Length | px | `px = m × 64` |
| Velocity | px/s | `px/s = m/s × 64` |
| Force | px·kg/s² | `F_px = F_N × 64` |
| Torque | px²·kg/s² | `τ_px = τ_Nm × 64²` |
| Inertia | kg·px² | `I_px = I_kgm² × 64²` |
| Gravity | 627.62 px/s² | `9.80665 × 64` |

Mixing these silently is the classic source of "the car feels wrong" bugs. It already bit this
project once: gravity was set to the value for 48 px/m while the world used 64 px/m, which made
every vehicle 25 % too light. The static-load test now pins this down (`load ≈ m·g` within 28 %,
measured 11 582 N vs 11 572 N).

## 2. Chassis

`VehicleBody extends RigidBody2D`:

* mass from `VehicleDef.mass_kg`;
* inertia computed as `m·(L² + H²)/12 · ppm² · inertia_scale` about the origin;
* centre of mass pinned to the origin (`CENTER_OF_MASS_MODE_CUSTOM`) so point-velocity maths
  is exact;
* collision from the convex hull of the authored chassis polygon;
* continuous collision detection (`CAST_SHAPE`) for high speed vs small rocks.

Forces are applied only inside `_integrate_forces()` with `state.apply_force(force_px, offset)`,
never by teleporting position or overwriting velocity. Gravity comes from the physics server.

## 3. Suspension (per axle)

A ray is cast from the mount along the chassis "down" axis:

```
ray_length      = (rest_length + droop + tyre_radius + 0.02) · ppm
hub_distance    = hit_distance/ppm − tyre_radius
compression     = rest_length − hub_distance          (clamped to [−droop, travel + 0.15])
compression_v   = velocity(mount) · down / ppm         (m/s)
F_spring        = k · compression + c(compression_v) · compression_v
if compression > travel:  F_spring += k_bump · (compression − travel)^progress
F_spring        = max(F_spring, 0)
```

* `c` is different for compression and rebound (dampers are asymmetric), and is scaled down by
  suspension damage.
* The force is applied **at the mount**, along the contact normal, so a bump on one wheel pitches
  the chassis — that is what makes the suspension feel connected rather than animated.
* Two axles only. In a side-view 2D plane there is no left/right pair; the model says so instead
  of pretending four wheels exist.

## 4. Tyres

```
slip_ratio   = (ω·r − v_contact) / max(|v_contact|, v_reg)      v_reg = 2.4 m/s
mu(slip)     = lerp(mu_peak, mu_slide, clamp((|slip|−peak_slip)/(slide_slip−peak_slip), 0, 1))
F_long       = mu(slip) · mu_scale · N · shape(slip)
shape(slip)  = clamp(|slip| / peak_slip, 0, 1)
```

Properties that follow from this:

* force is bounded by `mu · N` — there is no infinite traction;
* the force is zero at zero slip and peaks at ~14 % slip, then falls to the sliding plateau;
* the low-speed regularisation prevents division by zero at standstill;
* wheel angular velocity is a real state: `ω += (τ_drive − τ_brake − F_long·r)/I_wheel · dt`,
  so a spinning wheel visually spins faster and the slip value drives the particles;
* surface grip is data: dry rock 0.93, hard dirt 0.86, gravel 0.74, sand 0.62, mud 0.44,
  wet mud 0.31, snow 0.39, ice 0.15;
* rolling resistance fades as `1 − |slip|`, because a spinning tyre is not also rolling.

## 5. Engine

Torque is interpolated from authored samples (never a constant):

```
T(rpm) = lerp(curve[i], curve[i+1], t)
P(kW)  = T · ω / 1000
```

Plus an idle governor (prevents dying at idle), a rev limiter that cuts torque above redline and
adds an overspeed governor, friction that falls with throttle, and engine braking proportional to
rpm when the throttle is closed.

## 6. Clutch and gearbox

The clutch is a **friction clutch with a lock-up state**, not a spring:

```
capacity   = clutch_capacity · engagement
slip       = engine_rpm − driveline_rpm
if |slip| < 140 and engagement > 0.55 and not shifting → LOCKED
    engine_rpm = clamp(driveline_rpm, 0, redline)
    τ_clutch   = engine torque − friction (− engine braking if throttle closed)
else → SLIPPING
    τ_clutch   = clamp(slip · stiffness, ±capacity)
```

The first implementation used only the spring form; at 120 Hz it oscillated between +capacity and
−capacity, which let the engine scream at 4 300 rpm while the wheels crawled. Locking fixed both
the oscillation and the feel.

Gearbox:

```
total_ratio = gear_ratio(gear) · final_drive
τ_wheel     = τ_clutch · total_ratio · efficiency · axle_share
```

`total_ratio` is 0 while shifting (`shift_time`) or in neutral, so a shift interrupts torque.
Reverse is a negative ratio. Automatic mode shifts on rpm with hysteresis and a road-speed guard
(it will not chase a spinning wheel up the box).

Stall: in full-manual clutch mode, if rpm falls below `stall_rpm` with the clutch engaged the engine
dies; the start button then re-cranks with a starter interlock that opens the clutch.

### 6.1 Manual gear selection (2.0)

Gear selection is a request, not an assignment. `GearboxState.can_engage()` answers
with a reason and `VehicleBody.select_gear()` only applies an accepted shift:

```
requires_clutch and pedal < 0.98      → REJECT_CLUTCH
|v| > max_speed_for(gear)·(1+margin)  → REJECT_OVERREV
v > 1.4 m/s and gear == −1            → REJECT_REVERSE
shift_timer > 0                       → REJECT_SHIFTING
```

`max_speed_for()` comes from the redline, the gear ratio, the final drive and the
wheel radius, so over-revving is a mechanical limit rather than a UI check. In
clutch-assist mode the interlock is bypassed and the plates slip automatically at
low speed; the pedal still works in both modes.

### 6.2 Transfer case, differential, converter (2.0)

```
total_ratio = gear_ratio · final_drive · transfer_ratio
τ_wheel     = τ_clutch · converter · total_ratio · efficiency · axle_share
```

* 4L multiplies the driveline (Ranger 2.48, Titan 2.72) and makes the same engine
  rpm a much lower road speed; 2H removes front-axle torque.
* A locked differential forces both axle angular speeds equal, an LSD pulls them
  together by 35 %, an open diff leaves them independent.
* A torque converter multiplies crank torque up to its stall ratio at low driveline
  speed and fades to 1:1 at lock-up. It only applies while the automatic is driving.

## 7. Resistances and grade

Gravity acts through the physics server, so grade resistance is emergent, not scripted:

```
F_grade = m · g · sin(θ)     (θ from the contact normal)
F_roll  = Crr · N · tanh(v/0.6) · (1 − |slip|)
F_drag  = ½ · ρ · Cd · A · v²
```

There is no invisible slope-assist force. If the engine cannot produce enough wheel torque, or the
tyres cannot put it down, the vehicle slows and stalls.

## 8. Measured behaviour (from the automated suite)

Test world: synthetic constant-slope stages built with the real `TerrainBuilder`, zero noise,
full throttle, from rest.

| Scenario | Result |
|---|---|
| Ranger 20° hard dirt, 1st gear, 5 s | **+8.72 m**, 30.4 km/h |
| Ranger 20° hard dirt, 4th gear, 5 s | **−1.33 m** (cannot climb, rolls back) |
| Ranger 28° hard dirt, 1st gear | +4.52 m |
| Ranger 20° rock, 1st gear | +9.79 m |
| Ranger 20° ice, 1st gear | **−0.88 m**, wheels spinning |
| Ranger 18° gravel, 1st gear | +4.37 m |
| Same, +900 kg | +2.37 m |
| Pickup 15° gravel, 1st gear | wheelspin, low speed |
| Titan 25° rock, 2nd gear | climbs |
| Wheel radius 0.28 m vs 0.50 m, flat 3 s | large difference in reached speed |
| Downhill 14°, 1st gear vs neutral, 4 s | 19.7 vs 26.3 km/h (engine braking) |

Static checks: both wheels in contact, `sum(N) = 11 582 N` vs weight `11 572 N`, compression
0.161 m, body upright (−0.004 rad), no sinking through the collider.

## 9. Deliberate simplifications

* Two contact patches, not four: correct for a 2D side view.
* No lateral tyre force, no steering model, no yaw: the camera and controls are side-on.
* Differential is a fixed torque split per axle; the AWD split is data, not a live centre diff.
* Wheel inertia includes a 1.9× driveline factor instead of modelling each shaft separately.
* Terrain is a heightfield with material spans, not deformable soil; "sink" is expressed through
  rolling resistance and grip rather than mesh deformation.
* Damage is scalar per component; deformation is visual.

These keep the simulation stable on a mid-range phone while preserving the relationships that
matter for gameplay: torque vs rpm, gearing, grip limits, mass, grade and wheel radius.

## 10. Weather (2.0)

Weather is data, not a filter. Each state carries a grip multiplier, a rolling-resistance
multiplier and a visual log:

| state | grip | rolling | visuals |
|---|---|---|---|
| clear | 1.00 | 1.00 | — |
| cloudy | 0.99 | 1.00 | dim ambient, light fog |
| rain | 0.94 | 1.05 | rain streaks, fog |
| heavy rain | 0.88 | 1.10 | denser rain, stronger fog |
| snow | 0.86 | 1.14 | snow particles, fog |
| fog | 0.96 | 1.02 | heavy depth fog |

`VehicleBody.apply_surface_conditions()` scales the tyre's peak/slide grip and the
rolling resistance; it never changes the authored surface data or adds an invisible
helper force. The multipliers are deliberately mild so a weather state changes how
a stage drives without making an authored stage impossible.

## 11. Bridges and the winch (2.0)

* A `steel_bridge` obstacle is a real static platform: `deck_y` is authored in
  metres, the collider top is the deck surface, and `surface_at_world()` reports
  `steel` on it. The terrain below stays a gap; falling off is possible.
* The winch is a tension constraint through `VehicleBody.external_force`:

```
stretch = |v − anchor| − rope_length
F       = clamp(k·stretch − c·v_radial, 0, rated_pull)
```

  The cable reels in at `winch_speed_mps`, slack pays out automatically, a ground
  stake only delivers 65 % of the rated pull, and the force never exceeds the
  vehicle's rating. It pulls; it never teleports.
