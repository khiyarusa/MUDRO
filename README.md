# MUDRO — OFFROAD PHYSICS

A cinematic side-view off-road driving game for Android, built with **Godot 4.7.2** and **typed GDScript**.
MUDRO is not a sprite with a speed variable: the vehicle is a real `RigidBody2D` with two independent
axle assemblies, a torque-curve engine, a geared drivetrain, a locking clutch, slip-based tyres and
data-driven terrain materials.

![status](docs/screenshots/09_race_driving.png)

## What is in the game

| | |
|---|---|
| **Vehicles** | 4 mechanically distinct machines: Rocky Buggy, Ranger 4x4, Dune Pickup, Titan Offroad |
| **Environments** | 3: Dry Canyon, Pine Highlands, Alpine Quarry — each with its own layered art and physics profiles |
| **Stages** | 12 hand-authored stages (4 per region) with unique elevation, surfaces, obstacles, checkpoints and medal times |
| **Modes** | Career, Hill Climb, Time Trial, Technical Trial |
| **Systems** | Manual gearbox with clutch, engine stall/restart, AWD/RWD/FWD, damage, upgrades, garage, save profile, medals, credits |
| **Presentation** | Hand-authored SVG art, parallax backdrops, surface-driven particles, procedural audio, Persian-first RTL UI with an English option |
| **Platform** | Android, landscape, offline, arm64-v8a, 37 MB debug APK |

## Controls

**Touch** — throttle and brake pedals, up/down shifters, clutch, handbrake, recover; the start button
appears only when the engine has stalled.

**Keyboard (desktop testing)** — `W`/`↑` throttle, `S`/`↓` brake, `E`/`PageUp` upshift,
`Q`/`PageDown` downshift, `Shift` clutch, `Space` handbrake, `R` recover, `I` start engine,
`Esc`/`P` pause, `F3` physics overlay.

Both paths feed the same InputMap actions, so the simulation never knows which one is used.

## Running it

```powershell
# Editor
& 'H:\Game\Engines\Godot\editor\Godot_v4.7.2-stable_win64.exe' --path .

# Headless test suite (68 assertions)
.\tools\local_build\run_tests.ps1

# Android debug APK
.\tools\local_build\build_android_debug.ps1
```

The build scripts resolve the engine, verify its version, and write logs under `local-builds/`.
`tools/local_build/README.md` documents the environment they expect.

## Project layout

```text
project.godot            Godot 4.7.2 project (GL Compatibility, 120 Hz physics, 64 px = 1 m)
scenes/                  boot, menus, garage, race
scripts/
  core/                  units, locale, settings, save profile, content database, router, session
  vehicle/               configs (Resource), engine, gearbox, clutch, wheel/tyre, body, visual, damage
  stages/                stage definitions, stage catalog, terrain builder
  race/                  race scene, backdrop, effects
  ui/                    UI kit and every screen, HUD, debug overlay
assets/                  SVG art (vehicles, environments, icons), fonts, synthesised WAV audio
tests/                   headless test runner with real physics scenarios
tools/                   SVG validator, audio synthesiser, diagnostics, screenshots, build scripts
docs/                    architecture, physics model, asset licenses
```

## Verification

* **68 automated assertions pass** (`tests/test_runner.tscn`), including hill-climb comparisons,
  grip limits, mass and wheel-radius effects, engine braking, landing, stall/restart, save/load,
  unlock chains and upgrade effects.
* The APK was **built locally, installed and run on a Samsung Galaxy A23 (SM-A235F, Android 14)**.
* Screenshots captured from the desktop build and from the device are in `local-builds/screenshots/`
  (not committed; regenerate with `tools/capture.tscn`).

See `docs/PHYSICS.md` for the equations, unit conventions and measured test results,
`docs/ARCHITECTURE.md` for the code map, and `docs/ASSET_LICENSES.md` for licensing.

---

## خلاصهٔ فارسی

**مادرو** یک بازی آفرود دو‌بعدی سینمایی برای اندروید است که با گودو ۴.۷.۲ ساخته شده است.
فیزیک خودرو واقعی است: شاسی `RigidBody2D`، دو محور مستقل با تعلیق فنر-دمپر، موتور با منحنی گشتاور،
گیربکس دستی با کلاچ، تایر با منحنی لغزش و محدودیت اصطکاک، و سطوح زمین با ضریب چسبندگی مستقل.
چهار خودرو، سه محیط، دوازده مرحله، گاراژ و ارتقای واقعی قطعات، سیستم ذخیره، و رابط فارسی راست‌به‌چپ.
۶۸ تست خودکار فیزیک و پیشرفت عبور می‌کنند و APK ساخت محلی روی گلکسی A23 نصب و اجرا شده است.
