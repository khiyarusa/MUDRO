# MUDRO — Transmission 2.0

In 1.0 the gearbox was a global setting (`SettingsService.transmission`) applied to
every car. In 2.0 the transmission is part of the vehicle, chosen in the garage or
the route briefing, simulated from real ratios, and impossible to shift illegally.

## 1. Data

`TransmissionProfile` (`scripts/vehicle/transmission_profile.gd`) is a `Resource`:

| group | fields |
|---|---|
| identity | `id`, `name_fa/en`, `kind` (`MANUAL_H`, `MANUAL_SEQ`, `AUTOMATIC`), notes |
| ratios | `ratios[]`, `reverse_ratio`, `final_drive`, `efficiency`, `has_reverse` |
| shift | `shift_time`, `synchro` (0 = crash box, 1 = full synchro), `requires_clutch`, `clutch_type`, `max_torque_nm`, `durability`, `overrev_margin` |
| converter | `converter_stall_mult`, `converter_lock_rpm` |
| automatic | `auto_upshift_fraction`, `auto_downshift_fraction`, `kickdown_throttle`, `kickdown_rpm_fraction`, `kickdown_hold_s`, `slope_downshift_deg`, `load_upshift_bias`, `ranges` |

`VehicleDef` carries `transmissions[]`, `stock_transmission`, `transfer_ids/ratios`,
`default_transfer`, `diff_modes`, `default_diff`, `tire_options`,
`suspension_options`, winch data, and the runtime `fitted_*` fields set by
`GarageModel` on the copy used for a run.

| vehicle | stock box | option | transfer | diff |
|---|---|---|---|---|
| Rocky Buggy | 5-speed sequential dog box (clutchless) | 5-speed H | — | open / LSD |
| Ranger 4x4 | 5-speed H manual | 6-speed automatic + converter | 2H / 4H / 4L (2.48) | open / LSD / locked |
| Dune Pickup | 6-speed automatic + converter | 6-speed H manual | 2H / 4H | open / LSD / locked |
| Titan Offroad | heavy 6-speed automatic + converter | heavy 6-speed H | 2H / 4H / 4L (2.72) | open / LSD / locked |

## 2. Ratios and torque

```
total_ratio = gear_ratio · final_drive · transfer_ratio
τ_wheel     = τ_clutch · converter · total_ratio · efficiency · axle_share
```

`effective_ratio()` is 0 while `shift_timer > 0`, so a shift interrupts torque
instead of stacking gears. Reverse is a negative ratio. Efficiency comes from the
profile, not a global constant.

## 3. Clutch interlock (H-pattern)

```
pedal = 1 − clutch_input            (0 = released, 1 = floor)
is_fully_pressed() = pedal ≥ 0.98
can_engage(gear, speed, clutch_ok):
    requires_clutch and not clutch_ok → REJECT_CLUTCH
    speed > max_speed_for(gear)·(1+margin) → REJECT_OVERREV
    speed > 1.4 and gear == −1 → REJECT_REVERSE
    shifting → REJECT_SHIFTING
```

`max_speed_for(gear)` is derived from the redline, the gear ratio, the final drive
and the wheel radius, so a money shift is refused in the data, not in a UI check.
A rejected shift returns `false`, emits `shift_rejected`, plays the grind sound,
vibrates and leaves the current gear engaged.

`ClutchState` is a friction clutch with free play and a bite window
(`engagement_target()`), a lock-up state above 0.55 engagement within 140 rpm, and
a capacity limit `capacity · engagement`. Releasing the pedal quickly is measured
(`release_rate`) and marks the clutch as dumped; the engine can stall. Full manual
mode (`clutch = "manual"`) keeps the interlock and the stall; assist mode bypasses
the interlock and slips the plates automatically at low speed so a beginner cannot
stall, but the pedal still works.

## 4. Transfer case

`GearboxState.set_transfer("4L")` multiplies the whole driveline by 2.48 / 2.72 and
reduces the reachable speed for the same engine rpm. `transfer_drives_front()`
turns 4H/4L into front-axle torque; 2H leaves the front axle unpowered, which is
why a 4x4 in 2H climbs like a RWD car. Changing range interrupts torque for 0.25 s.

## 5. Differential

The side view has two physical axles standing in for front and rear, so that is
exactly the pair a centre differential couples:

* **open** — independent axle speeds, fixed torque split;
* **LSD** — axle speeds pulled together by 35 %;
* **locked** — axle speeds forced equal. A locked diff on a single driven axle
  also gets a small grip multiplier (1.07) because the 2D model has no left/right
  wheel pair to lock.

## 6. Automatic schedule

`auto_update()` is load-, grade- and slip-aware:

* upshift when `rpm > redline·(upshift_fraction + load_bias·load)` **and** the
  projected rpm in the next gear is above the downshift threshold;
* downshift on kickdown (throttle ≥ 0.86 and rpm < 0.62·redline), on grade
  (> `slope_downshift_deg` with low rpm) or on lugging load;
* `kickdown_timer` blocks the immediate upshift that would cancel the kickdown;
* a spinning wheel (|slip| > 1.2) never causes an upshift — automatics wait for
  road speed;
* range **L** caps the box at the first two gears; **P** applies the parking lock.

The torque converter multiplies crank torque up to `converter_stall_mult` at low
driveline speed and fades to 1:1 at `converter_lock_rpm`; it is only active when
the automatic is actually driving, so manual-mode tests remain comparable.

## 7. Persistence

`SaveManager` v4 adds `config: { vehicle_id: { transmission, transfer, diff, tires,
suspension, winch } }`. A v3 profile migrates by adding an empty table; every
vehicle then falls back to its stock specification, so no purchase, medal or credit
is lost. `GarageModel.sanitize_config()` drops options a vehicle does not offer.

## 8. Tests

`transmission: every vehicle has its own box`, `ranger offers manual and automatic`,
`buggy stock is a clutchless dog box`, `pickup automatic uses a converter`,
`titan has a low range`, `torque capacities differ`, the H-pattern gate tests
(column layout, neutral rail, diagonal rejection, commit radius), the clutch
interlock tests (refused / accepted / over-rev / rolling reverse), automatic
(kickdown, grade, spinning wheel, L range), transfer (4L ratio, 2H front axle) and
differential (open / LSD / locked), plus `config: choices survive a reload` and the
v3 → v4 migration.

---

## خلاصهٔ فارسی

گیربکس از یک تنظیم سراسری به مشخصهٔ هر خودرو تبدیل شد. هر ماشین گیربکس، نسبت‌ها،
نوع کلاچ، ظرفیت گشتاور و برنامهٔ تعویض خودش را دارد؛ Ranger و Titan جعبهٔ انتقال
با 4L دارند و دیفرانسیل هر خودرو open/LSD/locked است. در H-pattern اهرم باید از
خلاص عبور کند و بدون فشردن کلاچ تا ۹۸٪ دنده درگیر نمی‌شود؛ دندهٔ نامناسب از نظر
دور موتور یا دندهٔ عقب در حال حرکت رد می‌شود و دلیلش نمایش داده می‌شود.
گیربکس اتوماتیک به بار، شیب، لغزش چرخ و کیک‌داون واکنش می‌دهد و گیربکس ترتیبی
برای باگی تعریف شده است. انتخاب‌ها در پروفایل ذخیره می‌شوند و پروفایل نسخهٔ
قبلی بدون از دست دادن پیشرفت مهاجرت می‌کند.
