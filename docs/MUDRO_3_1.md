# MUDRO 3.1 — Release Notes

**Driver experience rebuild: clutch, transmission, mountain roads.**
Version 3.1.0, November 2026.

The point of this release is not new menus. It is the moment where the driver's foot, the
lever, the engine, the plates, the tyres and the road all have to agree — and where they now
do.

---

## The three things

### 1. The clutch is a real, per-car pedal

* The default layout is **clutch alone on the left**, a large accelerator and a smaller brake
  on the right. It is the shipped default, not a hidden alternative, and every control is
  still adjustable (size, opacity, sensitivity, position, handedness, spacing).
* The clutch rail travels **downward to the floor** like a pedal, never jumps to a touched
  position, and releases at a rate a foot could produce. It paints the fitted clutch's
  **engagement window** on the rail.
* Each car has its own cover: bite point, engagement window (0.38 organic / 0.28 heavy-duty /
  0.22 twin plate), clamp rate, slip heat capacity, fade limit and wear rate, derived from
  the car's authored kerb mass.
* A slip can cook the cover: heat fades capacity (down to the car's own fade floor), a long
  hill start can cost the very grip it needs, and wear from slipping is stored per part.

### 2. Manual shifting has to be earned

* A gear change — including reverse — is refused unless `clutch >= 0.98`, in every mode and
  from every input path. The refusal is visible and, on the lever, audible.
* The H-pattern gate is drawn from the gearbox definition (a 5MT is `1 3 5 / 2 4 R`), reverse
  is at the bottom of the last column, and the panel is its own tool that can be dismissed
  with one tap.
* The lever belongs to one finger. A palm landing on the plate cannot steal it, the clutch
  rail does not lose its finger when a second thumb opens the panel, and the accelerator does
  not reset when the panel opens.
* Launching wrong stalls the engine: dumping the pedal at idle, pulling away in fourth, a
  heavy car on a steep climb. The stall is immediate, the audio stops, the starter appears —
  and restarting needs the pedal down or neutral. Recovery does not resurrect the engine.

### 3. The automatic is an automatic

* Converted cars get a converter, kickdown, uphill gear hold, downhill gear selection, P/R/N/D/L
  and **no clutch control anywhere**.
* The parking pawl cannot engage above walking pace, and both P and R refusals say why
  instead of silently dropping to N.
* An automatic sits still in D at idle instead of creeping off the line during the countdown.
* The route briefing's transmission picker is finally read: catalogue automatics
  (`hilux_a6`, `lc79_a6`, …) are selectable, and the workshop's automatic conversion carries
  the factory ratios where they are documented.

---

## Fixes in the same pass

* Manual cars no longer stall in neutral on the start line (the plates transmitted full
  capacity against a disconnected driveline).
* Hiding the clutch control no longer soft-locks a manual car: that car gets the automatic
  clutch.
* `Show recover` / `Show winch` take effect immediately.
* The bite band on the rail comes from the fitted clutch, not from a constant.
* The idle governor is capped at a quarter of the engine's own peak torque.
* HUD/control collisions fixed: recover was on the timer, the handbrake on the speed cluster,
  the drive panel 6 px into the brake column, and the starter floated over the car for a whole
  stage (it now appears only when the engine is dead).
* The stall message is no longer printed twice in one frame; the clutch bar is hidden on
  automatics; closing the layout editor returns to the pause card.
* The screenshot harness no longer takes a shot of a car whose controls are locked, and can no
  longer hang the machine on a drawn-frame wait.

The full defect list, with file/line evidence and what proved each fix:
[`docs/MUDRO_3_1_BASELINE_AUDIT.md`](MUDRO_3_1_BASELINE_AUDIT.md).

---

## Numbers

| | 3.0 | 3.1 |
|---|---|---|
| Automated assertions | 342 → 408 | **423** |
| Parts | 566 across 30 slots | 573 (adds the automatic conversion) |
| Vehicles / tracks | 5 real vehicles, 15 authored tracks | unchanged |
| Screenshots | 42 (v3.0 folder) | 41 (`next-major-update` folder) |
| APK | 36.0 MB debug | see `local-builds/reports/ANDROID_BUILD_REPORT.md` |

## Screenshots

[`docs/screenshots/next-major-update/INDEX.md`](screenshots/next-major-update/INDEX.md) —
all desktop captures, honestly labelled.

## Save compatibility

Schema v5 is unchanged. Per-vehicle garage configs, conditions, records, credits and control
settings migrate; the 3.1 defaults (driver layout, realistic clutch) apply once, and only to
profiles that never customised their layout.

## Upgrade notes for players

* Your first launch will feel different — the clutch now has to be let out like a clutch.
  The route briefing and the launch hint say what to do; the assist mode is one setting away.
* The 3.0 layout presets are still there in Settings → Controls.
* Worn clutches behave like worn clutches. Repair them in the workshop.
