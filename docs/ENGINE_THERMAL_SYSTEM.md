# MUDRO 3.0 — Engine Thermal System

**What this is:** the cooling model behind every long climb in the game — the equations, the derate and damage thresholds, what the HUD shows, and a worked climb with the numbers the code actually produces. For maintainers and for anyone tuning a build that "runs hot".
**Scope:** `scripts/vehicle/thermal_state.gd` (the model), `EngineBuild.coolant_heat_kw()` (the heat source), the thermal block of `scripts/vehicle/vehicle_body.gd` (integration, derate, damage) and `GameSession.ambient_c()` (ambient by region). It does not cover brake fade, engine oil temperature or intercooler heat soak — none of those exist.
**Version:** 1.0 — 2026-11-14 · code basis `project.godot` 3.0.0.

---

## 1. The model in one page

`ThermalState` is a single lumped coolant temperature. It has one state variable (`coolant_temp_c`) and four inputs per physics step: current crank power, road speed, throttle and the build's cooling hardware.

```
heat in   [kW] = 0.75 × crank power + 5.5
heat out  [kW] = radiator_kW × airflow × flow_open × clamp((T − T_amb) / 60, 0, 2.2)
dT/dt     [K/s] = (heat in − heat out) × 1000 / (coolant mass × 4180)
```

with

```
coolant mass [kg] = capacity_l × 1.05
airflow           = (ram + fan_air) × pump_mult
ram               = clamp(0.30 + |v| / 26, 0.30, 1.30)
fan_air           = 0.22 × fan_mult   when the fan is on, else 0
```

Everything is SI: kW for heat, litres for coolant, m/s for road speed, °C for temperature, and 4180 J·kg⁻¹·K⁻¹ for the specific heat of a water/glycol mix. The 60 K in the denominator is the radiator's rated temperature difference: `heat_reject_kw` is the heat the radiator sheds at 60 K above ambient, and the model scales linearly from there up to 2.2× that rating.

Two details are deliberate:

- **The `+ 5.5` kW constant.** An idling engine still makes heat. Without it, a stationary car would cool to ambient and the fan would never cycle.
- **`0.75 × power`.** Roughly three quarters of crank output ends up in the coolant on a sustained pull; the rest leaves in the exhaust and through radiation. This is the same coefficient `EngineBuild.coolant_heat_kw()` uses, so the garage's "is this radiator marginal?" check and the live model cannot disagree.

Initial condition: `coolant_temp_c = ambient + 4 °C` on `setup()` and `reset()`.

---

## 2. Airflow: ram, fan, pump, thermostat

### 2.1 Ram air

`ram = clamp(0.30 + |v| / 26, 0.30, 1.30)`. At rest the radiator still gets 30 % of its rated flow from natural convection; at 26 m/s (94 km/h) it is at 1.30, the cap. Speed matters far less than players expect — from 6 m/s to 20 m/s the ram term only rises from 0.53 to 1.07.

### 2.2 The fan, with hysteresis

```
if T > thermostat + 4 : fan_on = true
elif T < thermostat − 3 : fan_on = false
```

A stock thermostat opens at 88 °C, so the fan switches on above 92 °C and off below 85 °C. When on, it adds `0.22 × fan_mult` to the airflow term — a 41 % increase over the 6 m/s ram value. That hysteresis band is what makes the temperature *hunt* rather than settle: at 92 °C the fan brings the heat out above the heat in, the coolant falls below 85 °C, the fan cuts out, and it climbs again. The fan's `airflow_mult` (1.0 stock, 1.28 twin electric, 1.45 race) scales the whole contribution, so a race fan is worth more at low speed than at high speed.

### 2.3 Water pump

`pump_mult` multiplies the *total* airflow, not just the fan. A high-flow water pump (1.18) therefore behaves like an 18 % bigger radiator everywhere, which is physically generous — the real constraint is the radiator's capacity to reject heat, not the pump's ability to move it.

### 2.4 Thermostat

Below the opening temperature the radiator is bypassed and only a small circuit moves heat:

```
flow_open = clamp(0.10 + 0.90 × (T − (thermostat − 8)) / 8, 0.08, 1.0)     for T < thermostat
flow_open = 1.0                                                             for T ≥ thermostat
```

At 8 K below the opening point the flow is 10 %; it reaches 100 % exactly at the opening temperature. A low-temperature thermostat (82 °C) does not make the engine cooler at equilibrium — it lets the radiator start working earlier, which lowers the *settled* temperature only if the radiator has spare capacity. §6 shows this happening.

---

## 3. Derate and damage thresholds

| Constant | Value | Meaning |
|---|---|---|
| `DERATE_START_C` | 108 °C | Power starts to be pulled |
| `DERATE_FULL_C` | 124 °C | Power multiplier reaches its floor |
| `DAMAGE_START_C` | 121 °C | Coolant temperature begins to damage the engine |
| `RATED_DELTA_K` | 60 K | Temperature difference the radiator is rated at |
| `COOLANT_CP` | 4180 J·kg⁻¹·K⁻¹ | Specific heat |

### 3.1 Derate

```
if T ≤ 108:            derate = 1.0
else:                  derate = lerp(1.0, 0.52, (T − 108) / 16)
```

The multiplier is applied once, to the crank torque that reaches the clutch (`vehicle_body.gd:_update_drivetrain`), so it reduces wheel torque and therefore speed — which in turn reduces ram airflow, which raises the temperature further. That feedback is the intended failure mode: an overheating engine loses pace and gets hotter, and the player has to lift.

| Coolant | Derate | Effective power (of 98.1 kW) |
|---|---|---|
| 108 °C | 1.00 | 98.1 kW |
| 112 °C | 0.88 | 86.3 kW |
| 116 °C | 0.76 | 74.6 kW |
| 121 °C | 0.61 | 59.8 kW |
| 124 °C and above | 0.52 | 51.0 kW |

Note the ordering: damage starts at 121 °C while derate only reaches its floor at 124 °C. Between those two points the engine is being damaged *and* still making 52–61 % of its power.

### 3.2 Damage

Two accumulators run in parallel and they are not the same thing:

- `ThermalState.damage_accum += (T − 121) × 0.004 × dt` — tracked and currently **read by nothing**.
- `VehicleBody.heat_damage += (T − 121) × 0.0025 × dt`, then `engine_health -= heat_damage × 0.002 × dt`.

Because the second accumulator feeds its own rate, heat damage is quadratic in exposure time:

```
health lost ≈ 2.5 × 10⁻⁶ × (T − 121) × t²
```

| Over-temperature | 10 s | 30 s | 60 s |
|---|---|---|---|
| +4 K (125 °C) | 0.1 % | 0.9 % | 3.6 % |
| +9 K (130 °C) | 0.2 % | 2.0 % | 8.1 % |
| +19 K (140 °C) | 0.5 % | 4.3 % | 17.1 % |

`engine_health` also drives `DamageModel.torque_multiplier() = 0.35 + 0.65 × health`, so a heat-damaged engine keeps losing power after it has cooled down. There is no repair path for engine health other than `DamageModel.reset()` (a fresh run).

### 3.3 Warning states

```
warning  = T ≥ 104 °C          (DERATE_START − 4)
critical = T ≥ 121 °C
```

`status_color()` returns green / amber / red from those two flags, and the HUD reads `coolant_c`, `thermal_derate`, `heat_warning` and `overheat` from the vehicle telemetry dictionary.

---

## 4. Where the heat comes from

`EngineBuild.coolant_heat_kw(power) = 0.75 × power + 6.0`, and `GarageModel` stores `heat_kw_full = coolant_heat_kw(peak_power_kw)`. The `+ 6.0` here versus `+ 5.5` in the live model is a 0.5 kW inconsistency: the garage's "marginal radiator" check uses the slightly harsher figure, the simulation the slightly gentler one. At 98 kW the difference is 0.6 %.

Engine power in the model is the *instantaneous crank output*, not the peak. On a climb at part throttle the heat load is proportionally lower, which is why a gentle climb can be survivable on a radiator that a flat-out one is not.

Ambient temperature is set per region in `GameSession.ambient_c()`:

| Region | Ambient |
|---|---|
| `zagros` | 28 °C |
| `pine` | 14 °C |
| `black_ridge` | 12 °C |
| `alpine` | 6 °C |
| `glacier` | −6 °C |

The ambient value is copied into `VehicleBody.ambient_c` before `setup()`, so it also seeds the initial coolant temperature (`ambient + 4`). A Glacier start therefore begins at −2 °C coolant.

---

## 5. Worked example — a long climb with the Hilux

The reference case is the one recorded in `local-builds/logs/smoke_v3.log`: 180 s at full power, 6 m/s road speed, 28 °C ambient, comparing the stock 142 kW radiator with the 241.4 kW race radiator. The probe's climb routine (`tools/smoke_v3.gd:_climb_temp`) steps the model at 0.1 s with `power = peak_power × derate`.

**Inputs.** Derived stock power 98.1 kW → heat in = 0.75 × 98.1 + 5.5 = **79.1 kW**. Ram at 6 m/s = 0.30 + 6/26 = **0.531**. Thermostat 88 °C, fan off below 92 °C.

**Transient.** At 32 °C the thermostat is essentially shut (`flow_open = 0.08`), so heat out is under 0.5 kW and the net +78.6 kW heats 9.66 kg of coolant (9.2 L × 1.05) at 4180 J·kg⁻¹·K⁻¹:

```
dT/dt = 78 600 / (9.66 × 4180) = 1.95 K/s
```

The climb from 32 °C to 80 °C therefore takes about 25 s; from 80 °C the thermostat opens and the rate collapses as heat out rises toward heat in.

**Stock radiator — the equilibrium.** Above 88 °C the thermostat is fully open and the fan is still off, so:

```
79.1 = 142 × 0.531 × (T − 28) / 60
T = 28 + 79.1 × 60 / (142 × 0.531) = 28 + 62.9 = 90.9 °C
```

The recorded run prints **90.9 °C** after 180 s. The equilibrium sits 1.1 K below the fan's switch-on point, so the fan never runs and the state is a true steady state rather than a limit cycle.

**Race radiator — the thermostat is the limit.** With 241.4 kW of rejection the raw equilibrium would be far lower:

```
T_raw = 28 + 79.1 × 60 / (241.4 × 0.531) = 28 + 37.0 = 65 °C
```

But at 65 °C the thermostat is nearly shut (`flow_open = 0.08`), so the radiator cannot reject that much. The actual equilibrium is where the partly-open thermostat passes exactly 79.1 kW:

```
flow_open(T) = 0.10 + 0.90 × (T − 80)/8
79.1 = 241.4 × 0.531 × flow_open(T) × (T − 28)/60
T = 84.9 °C  →  flow_open = 0.65
```

The recorded run prints **84.9 °C**. The lesson is the useful part: 70 % more radiator bought 6 K, not 26 K, because below 88 °C the thermostat — not the radiator — controls the flow. A race radiator only pays off once the engine is hot enough to keep the thermostat wide open.

**What would actually overheat it.** Solving the same balance at 108 °C (derate) and 121 °C (damage) gives the sustained power each package can hold, with the fan on above 92 °C (airflow 0.751 at 6 m/s, 0.597 at 2 m/s):

| Radiator | 108 °C @ 6 m/s | 108 °C @ 2 m/s | 121 °C @ 6 m/s | 121 °C @ 2 m/s |
|---|---|---|---|---|
| Stock 142 kW | 182 kW | 143 kW | 213 kW | 168 kW |
| Race 241 kW | 315 kW | 249 kW | 367 kW | 290 kW |

A stock Hilux at 98 kW is not close to any of them. The thermal system only becomes a gameplay constraint on a heavily boosted build, or on a low-speed climb in a vehicle whose radiator is small relative to its power — which is exactly the case the `cooling_marginal` warning is for.

---

## 6. Second worked example — a cold-start climb on the Glacier

Same Hilux, same 98.1 kW, but 2 m/s (a slow, steep, icy climb) and −6 °C ambient:

- ram = 0.30 + 2/26 = 0.377
- heat in 79.1 kW unchanged
- initial coolant = −2 °C

The engine has to warm 90 K before the thermostat opens. At the early rate (a 4 K delta over ambient with the thermostat at 8 % flow gives about 0.3 kW out):

```
dT/dt = (79.1 − 0.3) × 1000 / 40 379 ≈ 1.95 K/s
```

so it reaches 88 °C in roughly 46 s — most of a short Glacier run spent below operating temperature, with the thermostat shut and the radiator doing nothing. This is correct behaviour for a cold climate and is why the Glacier tracks reward a build that does not depend on the radiator at all.

---

## 7. Reading the model from outside

| Want to know | Read |
|---|---|
| Current coolant temperature | `vehicle.coolant_temp_c()` or telemetry `coolant_c` |
| Current power multiplier | `vehicle.telemetry["thermal_derate"]` |
| Is it hot / damaged | `thermal.warning` (≥104 °C), `thermal.critical` (≥121 °C) |
| Will this build run hot | `build_info.cooling_marginal`, or `heat_kw_full > radiator_kw × 1.05` |
| Heat load at peak power | `engine_build.heat_kw_full` |

`ThermalState.describe(lang)` returns a localised `"96°C HOT"` / `"124°C CRITICAL"` string for the HUD.

---

## 8. Known gaps

1. **Two damage accumulators, one of them dead.** `ThermalState.damage_accum` is computed at 0.004 per K·s and never read; the actual damage path uses `VehicleBody.heat_damage` at 0.0025. Two different coefficients for the same phenomenon.
2. **`+5.5` vs `+6.0` kW idle heat** between the live model and the garage's marginality check (§4).
3. **The fan is a step, not a curve.** Below the switch-on point it contributes nothing; above it, 22 % of rated airflow instantly. Combined with the 7 K hysteresis band this produces the limit cycle described in §2.2 rather than a smooth approach.
4. **`pump_mult` scales total airflow**, which overstates what a water pump can do (§2.3).
5. **No oil temperature, no intercooler heat soak, no ambient humidity.** The intercooler's `charge_cool` is a constant fraction, evaluated once at build time in `EngineBuild`, not a live heat exchanger. A car stuck in slow traffic does not heat-soak its intercooler.
6. **Heat damage cannot be repaired in-run.** `engine_health` only resets with `DamageModel.reset()`. The garage's part-condition repair does not touch it, because the two systems are not connected.
7. **Coolant capacity only affects the transient.** Equilibrium depends on radiator rating, airflow and ambient alone; a bigger capacity delays the climb but never changes where it ends up.
