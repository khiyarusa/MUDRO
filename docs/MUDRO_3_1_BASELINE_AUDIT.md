# MUDRO 3.1 — Baseline Audit

What was wrong with the project when this pass started, how it was found, what was
changed, and what is still open.

Every claim below has a file and a line, a log, or a probe output behind it. Where a
thing was *not* verified (a real phone, a real Blender pipeline), it says so.

---

## 1. Method

| Step | What was done |
|---|---|
| Repository | `git status`, `git log`, branch and remote inspection. Local `main` at `11206fd`; remote `origin` = `https://github.com/khiyarusa/MUDRO`. An uncommitted 3.1 change set was already present (19 modified files, 1 new screenshot folder, 1 new capture tool). |
| Read | All 72 scripts under `scripts/`, the scene list, `project.godot`, `export_presets.cfg`, the 3.0 docs, the parts catalogue and the test suite. |
| Run | Godot 4.7.2 (`C:\Users\Faraz_pc\Godot\Godot_v4.7.2-stable_win64_console.exe`), headless for the suite, windowed for captures. |
| Baseline suite | `godot --headless --path . res://tests/test_runner.tscn` → **373 / 408** (`local-builds/logs/tests_3_1_baseline.log`). |
| Probes | Three throwaway scenes (`tools/probe_*.gd`) used to reproduce the start-line stall, a launch, and a descent at a given track distance. They were deleted before the final commit. |
| Captures | `tools/capture_v31.gd` — the real scenes, the real physics, `ViewportScreenshot`. |

---

## 2. The baseline defect list

### 2.1 The parts catalogue did not compile (blocker)

`scripts/parts/parts_catalog.gd` called `_auto_ratios(v, stock)` and `_auto_final(v, stock)`
in the automatic-gearbox part; neither function existed. GDScript therefore failed the whole
file, `Content` failed on the dependency, and everything downstream degraded to empty
defaults:

```
SCRIPT ERROR: Parse Error: Function "_auto_ratios()" not found in base self.
  at: GDScript::reload (res://scripts/parts/parts_catalog.gd:308)
FAIL  L0. every script under scripts/ compiles  | 1 broken: parts/parts_catalog.gd
FAIL  D. part catalogue holds more than 200 parts | 0 parts
FAIL  C[hilux_an120] stock torque within 8% of doc | built 199.8 Nm vs doc 420.0 Nm
… 32 failures in total
```

**Fixed:** the two functions are implemented. Where a car documents a factory automatic
(Hilux `hilux_a6`, Land Cruiser `lc79_a6`), the conversion part carries that gearbox's real
ratios, final drive and shift time instead of a synthesised set; otherwise a four-speed set
is grown between a converter-friendly first gear and the donor's unchanged top gear.

### 2.2 An error per axle per physics tick, on every car

```gdscript
var probe: Object = get_meta("surface_probe", null)   # object has no such meta
```

`Object.get_meta` with a `null` default still reports the missing key, and this ran twice per
axle at 120 Hz — 240 errors a second in the log, on Android too.

**Fixed:** `has_meta()` guard. Log is clean.

### 2.3 Every manual car stalled on the start line

The most serious gameplay bug, and the reason the first screenshots showed a dead engine at
`00:00.26`.

In neutral the driveline reference speed is `wheel_rpm × 0` = 0, so `slip = engine_rpm`, and
the clutch law clamped that into **full capacity torque** against a driveline that is not
connected to anything. The plates acted as a brake on the crank and the engine was dragged
below `stall_rpm` in about four ticks.

Probe before the fix (`tools/probe_idle.gd`, now removed):

```
spawn: gear=0 rpm=0 running=false clutch_engagement=0.70 clutch_input=1.00
```

**Fixed:** `connected = ratio != 0.0` in `vehicle_body._update_drivetrain`. No torque path,
no torque. Probe after:

```
spawn: gear=0 rpm=657 running=true …
t=3s  gear=0 rpm=644 running=true engagement=0.00 speed=-0.0
```

### 2.4 Modes that did not exist

| Requirement | Baseline behaviour |
|---|---|
| Automatic needs no clutch pedal | `garage_model._profile_from_part` set `requires_clutch = kind != MANUAL_SEQ`, so **automatics kept the pedal**, the 0.98 interlock and the stall gate. A converted car showed a clutch slider and could stall. |
| Assisted manual is forgiving | `clutch.manual_mode = manual_clutch_enabled or not auto_clutch` forced the manual pedal law in assist mode; the assist block (`move_toward(0.2, dt*5.0)`) could never beat the pedal law (`5.5`) and the stall gate ignored `auto_clutch`. An assisted launch could stall. |
| Automatic does not creep | With `manual_mode` true, the idle-creep guard never ran: at a standstill in D the plates transmitted ~500 Nm at 0 rpm, so the car drove off during the countdown. |
| Reverse obeys the pedal | `can_engage()` returned early for `-1` **before** the `requires_clutch` test, so the keyboard and gamepad could select R with the pedal out. |
| Parking pawl | `set_range("P")` had no speed gate and `parking_lock()` adds `handbrake_torque × 1.6` every frame: P at 80 km/h locked the rear wheels. A refused `R` also silently dropped the range to N. |

**Fixed:** pedal only for `MANUAL_H`; automatic profiles force the automatic clutch and never
the stall gate; the assist mode is a real automatic clutch with a manual override; reverse is
gated by the same pedal test as every other gear; P has a 1 m/s gate and R a 1.4 m/s gate,
both leaving the range untouched and returning `REJECT_PARK` / `REJECT_REVERSE`, which the HUD
now says out loud (`range_park_blocked` in both languages).

### 2.5 A settings toggle that soft-locked the car

`Settings → Show clutch` only stopped building the widget. On Android there is no keyboard
clutch, so a realistic-manual car could never reach `clutch >= 0.98` and could never leave
neutral — for the rest of the run.

**Fixed:** hiding the pedal puts that car on the automatic clutch (documented in
`docs/CONTROLS.md`). Either the player has a pedal or the car does.

### 2.6 Data that was written and never read

`vehicle_config.gd` writes `cfg["transmission"]` when the player picks a gearbox in the route
briefing. `GarageModel.build()` read only `parts`, `condition`, `transfer`, `diff` and
`presets` — so `jimny_a4`, `hilux_a6`, `patrol_a5`, `pajero_a5`, `lc79_a6` were unreachable
data. The UI offered a choice that did nothing.

**Fixed:** `build()` honours the catalogue pick unless a non-stock gearbox part is fitted
(the workshop is the more specific choice and wins).

### 2.7 Half of the "per-vehicle clutch" was a constant

Bite point, engagement window and capacity were per car. Everything else was global:

| Parameter | Baseline | Now |
|---|---|---|
| Pedal → plate clamp rate | 5.5 / 9.0 for every car | `clutch_clamp_rate`, 4.2 s⁻¹ (2.2 t diesel) … 7.4 s⁻¹ (1.1 t petrol) |
| Slip heat capacity | `watts × 0.00003` | `clutch_heat_capacity`, 34 … 46 kW·s per unit fade |
| Fade limit | fixed −30 % | `clutch_fade_limit`, 22 % … 36 % |
| Wear per second of slip | one global 0.006 | scaled by the car's cover (`SaveManager.clutch_heat_rate`) |
| Idle governor | uncapped: asked **315 Nm** of a 130 Nm Jimny at 0 rpm | capped at 25 % of peak torque, tapered |

The three new fields are derived from the car's own authored kerb mass in
`vehicle_catalog._from_row`, not typed per car by hand, so they cannot drift from the
documented data.

### 2.8 UI defects found in the captures

| Defect | Evidence | Fix |
|---|---|---|
| Recover button drawn on top of the HUD timer | `10_drive_layout_idle.png`, first pass | utility row under the clutch |
| Handbrake drawn on top of the speed cluster | same | under the brake at the bottom edge, right side only |
| Drive panel ran 6 px into the brake column | 1280×720 arithmetic | panel capped at 500 px / 42 % of width |
| Starter button floated over the car for the whole stage | `21_launch_pulling_away.png` | shown only while the engine is dead |
| Stall message printed twice in one frame (toast + persistent hint) | `17_engine_stalled.png` | toast removed; the persistent hint stays |
| A live clutch bar on a PRNDL car | `16_automatic_selector.png` | hidden when the car has no pedal |
| Bite band painted from the constant 0.36 | `touch_controls._configure_clutch` | painted from the fitted `engagement_window` (0.38 / 0.28 / 0.22) |
| Closing the layout editor resumed the race | `race_scene._on_layout_closed` | returns to the pause card |
| `Show recover` / `Show winch` did nothing until another rebuild | `_on_settings_changed` | both are part of the rebuild key |
| Lever lost its finger to a second touch; any finger could release it | `gear_panel.press_at` / `release_finger` | one owning finger, checked on press and release |

### 2.9 The capture harness was lying

Three of the 3.1 screenshots were not evidence of anything:

* `_open_race()` skipped the countdown by setting `state = "racing"` but left
  `vehicle.controls_locked = true`, so **no driving shot had throttle or a shift**. That is
  why the first "pulling away" shot showed a car in neutral at 0 km/h.
* The "clutch at bite point" shot passed `-1` and the code only applied `pedal >= 0.0` — the
  shot was the idle state with a different filename.
* The "automatic selector" shot looked for a car whose **factory** transmission is automatic.
  No car in the roster has one (the automatics are options and workshop conversions), so the
  shot was never produced at all.

**Fixed:** controls are unlocked, `-1` means the car's real bite point, the automatic shot
fits `*_gbox_auto` through the save exactly as the workshop does, and the whole run is bounded
(a watchdog, a bounded drawn-frame wait and `RenderingServer.force_draw`) after a run hung for
ten minutes on `frame_post_draw` with an occluded window.

---

## 3. Verification after the fixes

| Check | Result | Where |
|---|---|---|
| Headless suite | **423 / 423 passed** | `local-builds/logs/tests_3_1_b6.log` (re-run after the last edit) |
| New section `L6` | 12 assertions added for 2.3–2.7 and 2.8 | `tests/test_runner.gd` |
| Start-line idle | engine running at 644 rpm after 3 s in N | `tools/probe_idle.gd` (removed) |
| Launch | gear 1, 8 km/h, engine running, clutch released | `docs/screenshots/next-major-update/21_launch_pulling_away.png` |
| Automatic selector | PRNDL panel, no clutch rail, "اتوماتیک" in the cluster | `…/16_automatic_selector.png` |
| Stall | orange "engine off — press start" hint, starter visible, gear 1 | `…/17_engine_stalled.png` |
| Restart | engine running again, hint gone | `…/18_engine_restarted.png` |
| Screenshots | 41 real captures, 1280×720 desktop | `docs/screenshots/next-major-update/` |
| Static checks | no obstacle colliders: `terrain_builder.obstacle_collider_count() == 0` asserted in section B | suite |

The `L6` assertions, for the record: automatic profile builds without a pedal; the conversion
carries the documented ratios; no clutch widget on an automatic; D at rest does not creep; the
parking pawl refuses while rolling; an assisted car does not stall on a dumped clutch; reverse
is refused with the pedal out; a pedal above the bite point moves nothing; every car clamps,
fades and absorbs heat differently; the rail paints the fitted window; a second finger cannot
steal the lever; the owning finger can still release it.

---

## 4. Open — not done in this pass

These are stated plainly because claiming them would be false.

1. **Real-world 3D vehicle reconstruction (Part 6.2) is not done.** The five vehicles are
   hand-authored 2D side-view art (`assets/`, `docs/ASSET_PIPELINE.md`). No licensed 3D model
   was obtained, no Blender orthographic render was produced, and there is no damage/dirt
   layer per car. The data is real and sourced (`docs/VEHICLE_SPEC_SOURCES.md`); the artwork
   is a stylised reconstruction, not a model of the actual vehicle.
2. **No Android device was connected during this pass.** All captures are desktop
   (Godot 4.7.2, GL compatibility, 1280×720) and are labelled as such. Multi-touch ownership is
   verified in the suite by touch indices, not on a Galaxy A23.
3. **Performance on the target phone is unmeasured.** Quality presets exist; no frame-time
   trace from hardware was taken.
4. **The radio has no new content.** The system and its licence gates are unchanged.
5. **Human play-testing of the assist launch curve** has not happened; the mode is correct by
   construction and by test, not by feel.
6. **`docs/TRANSMISSION_3.0.md` and `docs/CONTROLS.md`** were revised for 3.1 but the older 3.0
   documents that describe the previous bite-window behaviour are kept for history and are no
   longer authoritative.

---

## 5. What changed, at a glance

* 5 new/updated systems: automatic clutch governor, parking-pawl gates, per-car cover model,
  transmission picker that is read, H-pattern lever ownership.
* 19 files touched in the 3.1 set, 1 new test section, 1 new capture tool, 41 screenshots.
* Suite grew from 408 to 423 assertions, all passing.
* Two logs of the journey are kept: `tests_3_1_baseline.log` (373/408) and
  `tests_3_1_b6.log` (423/423).
