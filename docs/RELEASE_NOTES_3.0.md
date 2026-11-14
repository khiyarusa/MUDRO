# MUDRO 3.0 — RELEASE NOTES

**Version:** 3.0.0 (versionCode 300)
**Title:** MOUNTAIN RACING & AUTOMOTIVE WORKSHOP
**Engine:** Godot 4.7.2 · typed GDScript · Android arm64-v8a · offline

---

## The short version

MUDRO stopped being an obstacle course. The 2.0 game asked you to get over things; 3.0 asks
you to get up a mountain quickly. Every obstacle with its own collider is gone, the terrain is
authored rather than generated, the fictional cars are replaced by five real vehicles with
documented data, and the flat upgrade list became a workshop where each part writes a real
parameter into the simulation.

## Headline changes

### Tracks instead of obstacle courses

* **Standalone physical obstacles removed entirely.** No rock, boulder, log, tyre stack,
  concrete barrier, industrial barrier, ore cart, pipe stack, isolated block or broken-bridge
  mechanic exists on a track any more. A track test asserts a road build produces exactly
  three physics bodies: the road and two end walls.
* **Authored elevation profiles.** Each track is a list of segments with an entry and exit
  slope; elevation is the exact integral of the blended slope, so position *and* grade are
  continuous at every joint. Worst slope step across the 15 tracks is 0.00014.
* **Five art regions, fifteen tracks.** Zagros Highlands, Alpine Pass, Pine Valley, Black
  Ridge, Glacier Road — each with its own layered parallax art, surfaces, weather and grades.
* **Route stats are measured, not counted.** Length, ascent, descent, net change, maximum and
  average grade, steepest 20 m, surface distribution, checkpoint count. The obstacle counter
  is gone.
* **Eight race modes** with split targets, checkpoint timing, medals, per-track and
  per-vehicle records, and a ghost of your best run.

### Five real vehicles

| Vehicle | Variant | Engine | Power / torque |
|---|---|---|---|
| Suzuki Jimny JB74 | 1.5, 5-speed manual | K15B, 1,462 cc petrol | 75 kW / 130 Nm |
| Toyota Hilux AN120 | 2.8 GD-6 double cab 4×4, 6-speed manual | 1GD-FTV, 2,755 cc turbodiesel | 150 kW / 420 Nm |
| Nissan Patrol Y61 | 3.0 Di ST wagon, 5-speed manual | ZD30DDTi, 2,953 cc turbodiesel | 118 kW / 380 Nm |
| Mitsubishi Pajero | 3.2 DiD, 5-speed manual | 4M41, 3,200 cc turbodiesel | 125 kW / 358 Nm |
| Toyota Land Cruiser 79 | 4.2 D, 5-speed manual | 1HZ, 4,164 cc diesel | 96 kW / 285 Nm |

Each has its own silhouette, wheelbase, mass, gearbox, transfer case, suspension, tyre size
and engine. The derived engine in the game matches the published torque within 8 % and power
within 12 %; every number is traced to a source in `docs/VEHICLE_SPEC_SOURCES.md`, and
anything estimated is marked as such.

### Automotive workshop

* **566 parts across 30 slots** — engine internals, turbo, intercooler, fuel system, cooling,
  ECU, gearbox, clutch, transfer case, suspension, brakes, tyres, body, drivetrain.
* **A causal engine model.** Boost, charge temperature and volumetric efficiency make torque;
  the fuel system caps power when the injectors or pump run out; the rev limit is the weakest
  fitted part; the radiator either rejects the heat or the engine derates.
* **A real dyno.** Torque and power curves are swept from the same `EngineBuild` the physics
  uses, with wheel torque, boost, temperature and gear.
* **Compatibility with reasons.** An under-rated gearbox, a turbo without fuel or cooling, a
  tyre that needs arch clearance — each is refused with a sentence you can act on.
* **Condition, wear and repair** per part, tied to how the car was actually driven.

### Transmission and controls

* H-pattern with a clutch interlock and a bite point that varies by clutch part; sequential
  dog box; automatic with P/R/N/D/L, kickdown and a torque converter; transfer case with low
  range; open/LSD/locked differential.
* Engine stall, restart, clutch slip and launch are simulated, not scripted.
* Touch controls: three presets, true multi-touch with per-finger ownership, drag-to-place
  layout editor, left/right hand, safe-area aware, input released on pause.

### MUDRO Radio — new

An offline garage radio with a built-in station made entirely inside this project and support
for sideloaded content packs validated against a written rights policy. The APK carries no
third-party audio, and the loader has no network path at all.

## Fixes found on the way to release

These were real defects that made the build unplayable or dishonest; all are fixed and
covered by the suite where a test was possible:

1. The vehicle script did not compile (a typo and a merged line) — no race could start.
2. The terrain builder called a method that no longer existed — no track could be built.
3. Ten of fifteen tracks had surface sections that did not cover the whole road.
4. The stock clutch was sized from a legacy curve and slipped permanently at full throttle.
5. Wheel-spin integration oscillated every frame between gripping and spinning.
6. The main menu, career, briefing and HUD still referenced the deleted obstacle-era class and
   could not compile — the game could not open at all.
7. The route briefing still displayed an obstacle count and called a removed API.
8. The HUD was missing the thermal update the race scene calls every frame.
9. Finishing a race crashed in the save manager on a malformed record shape.
10. The results and pause overlays let the driving HUD and touch controls show through.
11. The first APK shipped 9.4 MB of import cache plus tests, tools and doc translations.

The full list with evidence is in [`QA_REPORT_3.0.md`](QA_REPORT_3.0.md).

## Save compatibility

The profile schema moves from v4 to v5 and migrates in place: credits, XP, owned vehicles,
selected vehicle, completed tracks, best times, medals, records, purchased parts and
per-vehicle tuning are all carried across, and legacy stage ids are mapped to the new track
ids. A migration test runs the old shape through the new loader.

## Upgrading

Nothing to do — install over the 2.0 build. Your profile is migrated on first launch and the
original file is kept as `profile.json.bak` before the write.

## Known limitations

* The APK is built, signed and verified, but this release was **not tested on Android
  hardware**; the 60 FPS target for a Galaxy A23 is a design goal, not a measurement.
* The vehicles are original 2D art matched to real proportions and mechanical data, not
  licensed 3D renders.
* Racing is against the clock and your ghost; there are no AI rivals.
* The radio ships project-made audio only; packs are supplied by the player with documented
  rights.
* Dyno before/after is a two-pull flow rather than one comparison screen.

## Thanks

Godot Engine 4.7.2. Vazirmatn by Saber Rastikerdar (SIL OFL). Everything else — art, audio,
physics, UI, tests and documentation — was authored for this project.
