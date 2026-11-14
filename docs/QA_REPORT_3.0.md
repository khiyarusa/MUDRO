# MUDRO 3.0 — QA REPORT

**Build under test:** `3.0.0` (versionCode 300), Godot 4.7.2.stable.official.ed1daf0bf
**Test date:** 2026-11-14
**Platform tested:** Windows 10/11 desktop, OpenGL compatibility renderer, AMD RX 580
**Platform built but not tested:** Android arm64-v8a (see §7)

This report separates what was **measured** from what was **only built**. Nothing in §1–§5
is an estimate; §7 is the honest boundary of the pass.

---

## 1. Automated test suite

Command: `.\tools\local_build\run_tests.ps1`
Result: **342 / 342 assertions passed, exit code 0.**
Log: `local-builds/logs/tests.log`

| Section | Assertions | What it proves |
|---|---|---|
| A. Track quality | 15 tracks × 11 | Every profile is C1-continuous (worst slope step 0.00014), no vertical step, length > 300 m, max grade ≤ 30°, checkpoints strictly increasing and inside the road, finish reachable, surfaces cover the whole length, `is_valid_layout()` true, measured ascent > 0, surface distribution sums to 100 % |
| B. No standalone obstacles | 11 | A representative track builds in a real `SceneTree` with **exactly three** `StaticBody2D` (road + two end walls), **zero** obstacle colliders, zero decoration colliders, decoration present to draw, all non-physical shapes are checkpoint/finish triggers |
| C. Vehicle data | 5 × 9 + 2 | Five documented vehicles, engine code, displacement, gearbox ratios, transfer ratios, tyre size, documented power/torque, derived stock torque within 8 % and power within 12 % of the published figures, base mass equals documented kerb mass, no two vehicles share a mass or wheelbase |
| D. Parts and tuning | 22 | 566 parts; a stock part in every slot for every vehicle; hybrid turbo raises peak torque; +30 % injectors let a big turbo make more power; bigger intercooler lowers charge temperature (116 → 74 °C); bigger radiator lowers the 120 s climb temperature (102 → 89 °C); shorter final drive raises 1st-gear wheel torque and lowers top speed; oversize tyre raises radius and top speed; compatibility rejects an under-rated gearbox and a tyre that needs a lift kit, and accepts it once the lift kit is fitted; installing an unowned part fails |
| E. Thermal model | 5 | A big-turbo build makes 183 kW vs 124 kW stock; the same radiator runs 28 °C hotter under the bigger turbo; `power_derate()` is exactly 1.0 below the threshold, 0.97 at 109 °C and still 0.64 at 120 °C |
| F. Dyno | 4 | Pull series are equal length; dyno peak torque and power match the engine build within 2 %; wheel torque equals crank × ratio × efficiency across the curve; the tuned-vs-stock comparison reports +19 kW / +64 Nm |
| G. Transmission | 19 | H-pattern refuses reverse while moving; sequential box shifts up/down; automatic recognises P/R/N/D/L, locks the driveline in P, caps gears in L, upshifts under load; a manual shift without the clutch is refused and accepted with it; clutch pedal pressed = open, released = closed, half pedal = partial engagement; a slipping clutch transmits partial torque |
| H. Save migration | 8 | v4 profile migrates to v5 in memory: credits preserved, schema raised and origin recorded, legacy stage ids mapped to 3.0 track ids with their best times, legacy upgrade block consumed, every migrated purchase kept in the garage entry and fitted |
| I. Data contracts | 15 × 4 | Every track supports at least one mode with ordered medal times; every vehicle has a positive tyre radius and final drives inside 2.5…5.5 |
| J. Radio packs | 10 | Built-in station ships audio under the project's own licence; a complete pack loads; a track without a licence rejects the pack at gate 5; a path escaping the pack is refused at gate 6; `pack_id` must match the folder at gate 3; CC BY content without attribution is refused at gate 7; the loader reads only `user://radio_packs` |
| K. Weather | 5 | Every track names a weather profile the game actually has (this caught `alpine_01` asking for a non-existent `overcast` and silently driving in clear weather); at least four distinct profiles are in use across the tracks; the wind profile carries a physical strength; wind pushes a stationary car; a Land Cruiser 79 catches more wind than a Jimny (165 N vs 102 N) |

## 2. Scene load verification

Command: `.\tools\scene_smoke.ps1`
Result: **15 / 15 scenes load with no script, resource or runtime error.**
Log: `local-builds/logs/` (per-scene output on stdout)

`boot`, `garage`, `vehicle_config`, `tuning_lab`, `dyno`, `repair`, `setup`, `main_menu`,
`career`, `stage_select`, `route_briefing`, `settings`, `credits`, `radio`, `race`.

One non-fatal note: `race.tscn` reports "resources still in use at exit" on shutdown — a
reference cycle released at process exit, not during play. It does not affect the scene
while running; it is recorded here rather than hidden.

## 3. Drivability

Command: `godot --headless --path . res://tools/drive_probe.tscn -- <track> <vehicle> <seconds>`

| Run | Result |
|---|---|
| `zagros_01` / Hilux / 150 s | Reached **922.8 m of a 917 m finish = 100 %**, coolant peaked 111 °C on the climb, engine derated but kept running |
| `zagros_02` / Patrol / 6 s | Pulls away cleanly, reaches 41 m |
| `zagros_01` / Hilux / 6 s (drivetrain trace) | 0 → 35 km/h in 2.5 s in first gear; clutch locks (`lock=true`); wheel force steady at 5–8 kN per axle |

Bugs found and fixed during this work, all verified by the runs above:

1. `vehicle_body.gd` had a **parse error** (`hermal` typo and a function header merged with
   its first statement) — the vehicle script did not compile, so no race could run.
2. `terrain_builder.gd` called a non-existent `elevation_at()`, so the terrain builder did
   not compile and every track test was blocked.
3. Surface sections on 10 of 15 tracks did not cover the whole road (a gap or an overrun).
   Authored ranges are now clamped to the real profile length and gaps are closed.
4. The stock clutch was sized from a legacy engine curve (286 Nm on a 420 Nm engine), so it
   slipped permanently at full throttle. It is now rated from the engine's documented torque.
5. The wheel-spin integration oscillated between gripping and spinning every frame; it now
   sub-steps 6× per tick.
6. `main_menu`, `career`, `route_briefing` and `race_hud` still referenced the deleted
   obstacle-era `StageDef` class and could not compile — the game could not even open.
7. `route_briefing` called the removed `route_stats()` and displayed a **count of obstacles**;
   it now reads `stats()` from the profile and shows length, ascent, descent, grades,
   steepest 20 m, checkpoint count and surface mix.
8. `race_hud` was missing `set_thermal()`, which the race scene calls every frame.
9. `SaveManager.best_time_for()` and `complete_track()` crashed on a scalar where a record
   object was expected — finishing a race threw. Both shapes are now accepted.
10. Connective rods were catalogued but never read by the engine model; a forged set now
    raises the rev limit instead of being decoration.
11. The results and pause overlays left the driving HUD and the touch controls visible
    through the card; they are hidden while an end screen is up.
12. `weather: "wind"` was documented as unimplemented, and `alpine_01` asked for an
    `overcast` profile that never existed (it silently drove in clear weather). Wind is now
    a real profile with a gusting force on the body and dust streaks, and a test checks that
    every track names a profile that exists.

## 4. Screenshots

Command: `godot --path . --resolution 1280x720 res://tools/capture_v3.tscn`
Result: **42 screenshots, `CAPTURE COMPLETE: 42 screenshots`.**
Location: `docs/screenshots/v3.0/`, index at `docs/screenshots/v3.0/INDEX.md`.

Every image is a capture of the running renderer. No mock-ups. Coverage: main menu, career,
five region selection screens, radio, settings, credits, five garage pages, six tuning labs,
dyno, repair, setup presets, route briefing, nine in-race views across surfaces and weather,
telemetry, six control screens, results and pause.

## 5. Android build

Command: `.\tools\local_build\build_android_debug.ps1`
Result: **success**, verified with `aapt2` and `apksigner`.

| Property | Value |
|---|---|
| Output | `local-builds/android/MUDRO-3.0-debug.apk` |
| Size | 36.0 MB |
| SHA-256 | see `local-builds/reports/MUDRO-3.0-BUILD-REPORT.md` (regenerated per build) |
| Package | `com.khiyarusa.mudro` |
| Version | 3.0.0 (versionCode 300) |
| SDK | min 24, target 36 |
| Architecture | arm64-v8a only |
| Signature | verified |

APK content hygiene (checked by listing the archive):

* **0** entries under `docs/`, `tests/`, `tools/`, `.godot/` — the export filter excludes them.
* **0** radio pack files, and no `radio_packs` path — the APK carries only project-made audio.
* No keystore, no token, no log file.

This check found a real problem on the first build: 9.4 MB of import cache plus the tests,
tools and doc translations were inside the APK (16 stray entries, including
`ASSET_LICENSES.*.translation`). The export filter was corrected and the rebuilt APK is
clean.

## 6. What is covered by tests vs. only by eye

| Area | Automated | Human inspection |
|---|---|---|
| Track geometry, continuity, surface coverage | yes | screenshot |
| Obstacle collider removal | yes (exact body/shape counts) | screenshot |
| Vehicle data vs documented specs | yes | screenshot |
| Parts → engine output | yes (torque, power, fuel cap, cooling) | dyno screenshot |
| Thermal behaviour and derate | yes | HUD chip |
| Transmission interlocks and automatic ranges | yes | gear panel screenshot |
| Save migration | yes (in memory) | — |
| Touch controls, layout, safe area | **no automated coverage** | screenshots only |
| Audio mix and levels | **no** | not verified by ear in this pass |
| Runtime performance / FPS | **no** | not measured on device |

## 7. Known gaps in this pass

1. **No Android hardware test.** The APK was built and verified, not installed. The 60 FPS
   target for a Galaxy A23 is a design goal with no measurement behind it. The performance
   section of the previous release notes claimed device screenshots; this pass has none and
   says so.
2. **No AI rivals.** Only the clock and the ghost compete.
3. **Radio content packs are a framework.** The built-in station is project-made; no
   third-party or meme audio is shipped, by policy and by licence.
4. **Compression ratio and throttle-response parameters** are read by the engine model but
   their effect on the final curve is small; they are not claimed as headline tuning levers.
5. **Visual review was done from screenshots**, not on a phone at arm's length. Small-screen
   legibility of the densest screens (engine lab, route briefing) is unverified.
6. **One shutdown-time resource cycle** in the race scene (§2).

## 8. How to reproduce

```powershell
git clone https://github.com/khiyarusa/MUDRO.git
cd MUDRO
.\tools\local_build\run_tests.ps1        # expect "TESTS: 342/342 passed"
.\tools\scene_smoke.ps1                  # expect "ALL SCENES OK: 15"
.\tools\local_build\build_android_debug.ps1
godot --path . --resolution 1280x720 res://tools/capture_v3.tscn
```
