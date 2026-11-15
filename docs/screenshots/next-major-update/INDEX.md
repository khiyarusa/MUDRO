# MUDRO 3.1 — Screenshot Index

Every image in this folder is a real capture of the running game, produced by
`tools/capture_v31.tscn`:

```
godot --path . --resolution 1280x720 res://tools/capture_v31.tscn
```

The harness instantiates the real scenes, drives the real physics, holds the real touch
controls and saves what the renderer produced. Nothing here is a mock-up, a concept render or
a composition.

* **Resolution:** 1280 × 720 (the game's reference landscape layout)
* **Platform:** **Windows desktop**, Godot 4.7.2, OpenGL compatibility renderer.
  No Android device was connected in this pass, so **none of these is a phone screenshot**.
* **Language:** Persian (the default). Every screen also ships in English.
* **Profile:** a disposable capture profile (all vehicles owned, a tuned Hilux, two records).
  The player's own save is snapshotted before the run and restored afterwards.
* **State:** the countdown is skipped so the frame shows driving, never a countdown card.

---

## Menus and navigation

| # | File | What it shows |
|---|---|---|
| 01 | `01_main_menu.png` | Main menu with progress footer |
| 30 | `30_career.png` | Career: the five mountain regions and their completion |
| 31 | `31_track_selection.png` | Zagros Highlands track list with the elevation preview |
| 32 | `32_route_briefing.png` | Route briefing: length, ascent, descent, grade, surfaces, recommended setup |
| 02 | `02_settings_controls.png` | Settings, including the 3.1 control preset row (`drive` first) and the clutch mode |

## Garage and workshop

| # | File | What it shows |
|---|---|---|
| 03 | `03_garage_hilux.png` | The selected Hilux in the garage bay |
| 40 | `40_garage_jimny_jb74.png` | Suzuki Jimny JB74 |
| 41 | `41_garage_hilux_an120.png` | Toyota Hilux AN120 2.8 GD-6 |
| 42 | `42_garage_patrol_y61.png` | Nissan Patrol Y61 3.0 Di |
| 43 | `43_garage_pajero_v80.png` | Mitsubishi Pajero 3.2 DiD |
| 44 | `44_garage_lc79.png` | Toyota Land Cruiser 79 4.2 D |
| 04 | `04_transmission_lab.png` | Transmission lab: gearbox, ratios, final drive, clutch, transfer case |
| 45 | `45_engine_lab.png` | Engine lab: block, pistons, head, cam, turbo, injectors, cooling |
| 46 | `46_suspension_lab.png` | Suspension lab: springs, dampers, bump stops, lift kit |
| 05 | `05_tyre_shop.png` | Tyre shop with the five terrain compounds |
| 47 | `47_ecu_lab.png` | ECU / electronics bay |
| 48 | `48_brakes_lab.png` | Brakes bay |
| 06 | `06_dyno.png` | Dyno: torque and power swept from the fitted engine |
| 07 | `07_repair.png` | Repair shop: condition per part, cost, restore |

## The 3.1 driver layout and the clutch

| # | File | What it shows |
|---|---|---|
| 10 | `10_drive_layout_idle.png` | The default layout: clutch alone on the left, large accelerator and smaller brake on the right, lever, parking brake, recovery row |
| 11 | `11_clutch_fully_pressed.png` | Clutch rail at the floor — the only position from which a manual shift is accepted |
| 12 | `12_clutch_at_bite_point.png` | The pedal at this car's real bite point, with the fitted clutch's engagement window painted on the rail |
| 13 | `13_h_pattern_neutral.png` | The separate H-pattern panel in neutral |
| 14 | `14_h_pattern_first.png` | The lever latched in first |
| 15 | `15_h_pattern_fourth.png` | The lever latched in fourth |
| 16 | `16_automatic_selector.png` | A Hilux converted to the automatic gearbox: PRNDL panel, no clutch control anywhere, "اتوماتیک" in the cluster |
| 17 | `17_engine_stalled.png` | Stalled: engine off, starter visible, the hint under the cluster |
| 18 | `18_engine_restarted.png` | Restarted with the pedal down |
| 50 | `50_controls_buttons.png` | The button preset (clutch still analog) |
| 51 | `51_controls_slider.png` | The slider preset |
| 52 | `52_controls_pedals.png` | The pedal preset |

## Driving

| # | File | What it shows |
|---|---|---|
| 20 | `20_launch_neutral.png` | On the line, neutral, pedal to the floor, the launch hint |
| 21 | `21_launch_pulling_away.png` | A real launch: first gear, 8 km/h, engine pulling, pedal released |
| 22 | `22_uphill_climb.png` | Zagros dirt climb, second gear |
| 23 | `23_descent.png` | Alpine descent |
| 24 | `24_mud_section.png` | Pine Valley mud |
| 25 | `25_snow_road.png` | Glacier Road snow |
| 26 | `26_black_ridge.png` | Black Ridge |
| 27 | `27_glacier_road.png` | Glacier Road, further up |
| 60 | `60_race_results.png` | Results card: time, medal, credits, record flag |
| 61 | `61_pause.png` | Pause card |

---

## Honest gaps in this set

* No phone screenshots: the device was not connected.
* No English-language captures: the English tables are tested, not photographed.
* The `L` range of the automatic, the sequential race gearbox panel and the winch are not
  individually photographed; the panels exist and are covered by the suite.
* Vehicle art is hand-authored 2D (see `docs/MUDRO_3_1_BASELINE_AUDIT.md`, section 4).
