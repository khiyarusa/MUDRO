# MUDRO 3.0 — Screenshot Index

Every image in this folder is a real capture of the running game. They were produced by
`tools/capture_v3.tscn` (`godot --path . --resolution 1280x720 res://tools/capture_v3.tscn`),
which instantiates the real scenes, drives the real physics and saves what the renderer
produced. Nothing here is a mock-up, a promotional render or a hand-made composition.

* **Resolution:** 1280×720 (the game's reference landscape layout)
* **Platform:** Windows desktop build, Godot 4.7.2, OpenGL compatibility renderer
* **Language:** Persian (the default). English is supported by the same screens.
* **Profile:** a disposable capture profile (all vehicles owned, several records, a tuned
  Hilux). The player's own save is snapshotted before the run and restored after it.
* **Device shots:** none. No Android device was connected for this pass, so no image here
  is device photography and none is presented as such.

---

## Main & navigation

| # | File | What it shows |
|---|---|---|
| 01 | `01_main_menu.png` | Main menu: continue shortcut, career, hill climb, time trial, sprint, garage, radio, settings, credits, progress footer |
| 02 | `02_career.png` | Career: the five mountain regions with per-region completion and medal counts |
| 03 | `03_map_zagros.png` | Zagros Highlands track selection with elevation preview |
| 04 | `04_map_alpine.png` | Alpine Pass track selection |
| 05 | `05_map_pine.png` | Pine Valley track selection |
| 06 | `06_map_black_ridge.png` | Black Ridge track selection |
| 07 | `07_map_glacier.png` | Glacier Road track selection |
| 08 | `08_radio.png` | MUDRO Radio: now playing, built-in station, content-pack section |
| 09 | `09_settings.png` | Settings: language, audio, quality, controls, transmission, clutch |
| 62 | `62_credits.png` | Credits and asset attribution |

## Vehicles & garage

| # | File | What it shows |
|---|---|---|
| 10 | `10_garage_jimny_jb74.png` | Suzuki Jimny JB74 in the garage |
| 11 | `11_garage_hilux_an120.png` | Toyota Hilux AN120 2.8 GD-6 |
| 12 | `12_garage_patrol_y61.png` | Nissan Patrol Y61 3.0 Di |
| 13 | `13_garage_pajero_v80.png` | Mitsubishi Pajero 3.2 DiD |
| 14 | `14_garage_lc79.png` | Toyota Land Cruiser 79 4.2 D |

## Tuning, dyno and repair

| # | File | What it shows |
|---|---|---|
| 20 | `20_engine_lab.png` | Engine lab: block, pistons, head, cam, intake, exhaust, turbo, injectors, cooling |
| 21 | `21_transmission_lab.png` | Transmission lab: gearbox, ratios, final drive, clutch, transfer case |
| 22 | `22_suspension_lab.png` | Suspension lab: springs, dampers, bump stops, lift kit, travel |
| 23 | `23_tire_shop.png` | Tyre shop: all-terrain, mud, rock, highway, snow with grip figures |
| 24 | `24_brakes_lab.png` | Brakes and drivetrain: pads, discs, bias, differential, transfer |
| 25 | `25_body_lab.png` | Body lab: bumpers, flares, snorkel, skid plate, winch, roof rack, rims |
| 26 | `26_dyno.png` | Dyno pull: torque and power curves, peak values, gearing |
| 27 | `27_repair.png` | Repair shop: per-part condition and repair cost |
| 28 | `28_setup_presets.png` | Setup presets built from the fitted parts |

## Racing

| # | File | What it shows |
|---|---|---|
| 30 | `30_route_briefing.png` | Route briefing: length, ascent, descent, grades, surface mix, recommended setup, vehicle/gearbox/transfer/diff/tyre |
| 40 | `40_race_start.png` | Race start on Zagros |
| 41 | `41_uphill_dirt.png` | Climbing a dirt grade in first gear |
| 42 | `42_downhill_asphalt.png` | Alpine descent on asphalt |
| 43 | `43_gravel.png` | Gravel section |
| 44 | `44_mud.png` | Wet mud in Pine Valley |
| 45 | `45_snow.png` | Glacier snow |
| 46 | `46_weather_fog.png` | Fog weather on Black Ridge |
| 47 | `47_dashboard.png` | Dashboard, gear and transfer state while driving |
| 48 | `48_telemetry.png` | Debug telemetry overlay |

## Controls

| # | File | What it shows |
|---|---|---|
| 50 | `50_controls_buttons.png` | Button control scheme |
| 51 | `51_controls_slider.png` | Analog slider scheme |
| 52 | `52_controls_pedals.png` | Analog pedals scheme, left-handed layout |
| 53 | `53_manual_clutch.png` | Manual clutch pedal in use |
| 54 | `54_gear_selector.png` | Gear selector gate open |
| 55 | `55_layout_editor.png` | Control layout editor |

## End screens

| # | File | What it shows |
|---|---|---|
| 60 | `60_race_results.png` | Results: time, best, new-record flag, credits, damage, retry/resume/garage |
| 61 | `61_pause.png` | Pause overlay |

---

## Known gaps in this pass

Honest list, because a screenshot index that hides them is worse than useless:

* **No Android device capture.** Every image is a desktop render at 1280×720. The APK was
  built and verified (`local-builds/reports/MUDRO-3.0-BUILD-REPORT.md`) but not installed on
  hardware in this session.
* **No separate "turbo" or "cooling" sub-page.** Those parts live inside the engine lab
  rather than on their own screens, so shot `20_engine_lab.png` covers them.
* **No before/after dyno comparison shot.** The comparison needs a second pull triggered in
  the same session; the capture harness takes the single-pull view (`26_dyno.png`) only.
* **English UI is not captured.** The same scenes render in English by switching the language
  in settings; only the Persian default is documented here.

## Regenerating

```powershell
. (Join-Path $PSScriptRoot 'tools\local_build\common.ps1')
# from the project root, with a display available (not --headless):
& 'H:\Game\Engines\Godot\editor\Godot_v4.7.2-stable_win64_console.exe' `
    --path . --resolution 1280x720 res://tools/capture_v3.tscn
```

The harness writes into `docs/screenshots/v3.0/`, snapshots and restores `user://profile.json`,
and prints `CAPTURE COMPLETE: <n> screenshots` when it is done.
