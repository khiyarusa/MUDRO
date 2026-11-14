# MUDRO 3.0 — Mountain Track Design

**What this is:** the design and data reference for the fifteen MUDRO 3.0 mountain tracks — what each road is, how its elevation profile is authored, and how every number the route briefing shows is derived from that profile. For maintainers and level designers.
**Scope:** the five regions and fifteen tracks defined in `scripts/tracks/track_catalog.gd`, and the profile mathematics in `scripts/tracks/track_profile.gd` / `scripts/tracks/track_def.gd`. It does not cover the race loop, the vehicle or the parts catalogue.
**Version:** 1.0 — 2026-11-14 · code basis `project.godot` 3.0.0, `TrackCatalog` as checked in.

---

## 1. The design thesis

A MUDRO 3.0 track is a **road**, not an obstacle course.

The 2.0 catalogue placed discrete obstacles — logs, barriers, ore carts, steel bridges — on a heightfield, and each one carried a collider. The 3.0 catalogue removes that layer entirely. A track is now defined by four things only:

1. a continuous authored elevation profile (slope per metre of run);
2. a list of surface sections along the road;
3. checkpoints and medal targets;
4. a scenery theme.

Everything the player feels comes from grade, crest, length and grip. There is no obstacle list, no solid prop placement and no random terrain elevation anywhere in `TrackDef` (`scripts/tracks/track_def.gd:1-22`).

**Why the props were removed.** Three reasons, all of them visible in the code that replaced them:

- *The collision contract became absolute.* `TerrainBuilder` builds exactly one continuous `StaticBody2D` for the road plus two end walls. `decor_collider_count()` and `obstacle_collider_count()` both return `0` by design (`scripts/terrain/terrain_builder.gd:319-327`), and the tests assert it. A single body cannot disagree with itself; a scatter of props can.
- *Obstacles fought the physics model.* The car is a two-axle rigid body with raycast suspension. A log under one wheel is a step input that the spring-damper resolves as an impact, not as terrain. Removing props made every metre of the road a fair test of gearing, torque and grip instead of a reflex test.
- *The briefing had to be honest.* `TrackDef.stats()` measures length, gain, descent, max grade, average grade and the steepest 20 m window directly from the profile. With props, "what is this track?" had no numeric answer; now it does, and the numbers cannot drift from the geometry because they are computed from it.

The replacement for obstacle difficulty is **grade and surface**: the Black Ridge tracks reach 24 % slope (13.5°) sustained over a full kilometre, and the Glacier tracks put that grade under ice at 0.15 peak grip.

---

## 2. The five regions

Regions are palette and physics together. `TrackCatalog.REGIONS` (`scripts/tracks/track_catalog.gd:22-56`) carries the id, both names, a short description, an accent colour, a surface hint and an ambience id. `GameSession.ambient_c()` (`scripts/core/game_session.gd:100-114`) turns the region id into the ambient temperature the cooling model uses.

| Region | Name (EN) | Tracks | Dominant surface | Ambient | Character |
|---|---|---|---|---|---|
| `zagros` | Zagros Highlands | 3 | hard dirt, gravel, rock | 28 °C | Dry limestone, open sightlines, rolling climbs. The teaching region. |
| `alpine` | Alpine Pass | 3 | asphalt, rock, snow | 6 °C | Cold paved pass, long unbroken gradients, snow at the summits. |
| `pine` | Pine Valley | 3 | wet mud, mud, water | 14 °C | Damp forest, shallow mud, grip that changes under the car. |
| `black_ridge` | Black Ridge | 3 | ash, scree, rock | 12 °C | Abandoned mine roads, broken stone, the hardest sustained grades. |
| `glacier` | Glacier Road | 3 | snow, ice | −6 °C | Exposed ridges, almost no grip, the longest climb in the game. |

Region art is not yet authored for `zagros`, `alpine` and `glacier`; those three borrow `canyon` and `quarry` layers through `ArtLib.REGION_ALIAS` (`scripts/core/art_lib.gd:9-13`). See `docs/ASSET_PIPELINE.md` §4.

Difficulty is authored per track on a 1–6 scale and is used for reward and unlock pacing, not for physics. `difficulty` values in the current catalogue run 1, 2, 3 (Zagros) through 6 (Black Ridge 3, Glacier 2–3).

---

## 3. The fifteen tracks

All values below are the ones `TrackDef.stats()` produces from the authored segments — the same numbers the route briefing prints. They were read from a headless run of the 3.0 data spine recorded in `local-builds/logs/smoke_v3.log` and cross-checked against the segment tables in `scripts/tracks/track_catalog.gd` (Appendix A).

Grade is reported in **degrees**, computed as `atan(slope)`; the authored data is **slope** (rise ÷ run, so 0.24 = 24 % ≈ 13.5°). Every table in this document follows that convention.

### 3.1 Geometry and grade

| Track | Length | Gain | Descent | Max grade | Avg grade | Steepest 20 m | Checkpoints | Difficulty |
|---|---|---|---|---|---|---|---|---|
| `zagros_01` Oak Pass | 920 m | +46 m | 4 m | 7.4° | 2.6° | 7.1° | 2 | 1 |
| `zagros_02` Limestone Shelf | 1080 m | +51 m | 10 m | 10.8° | 2.2° | 10.6° | 2 | 2 |
| `zagros_03` Zagros Grade | 1060 m | +85 m | 20 m | 11.9° | 3.5° | 11.7° | 2 | 3 |
| `alpine_01` Alpine Pass | 1260 m | +72 m | 23 m | 9.1° | 2.2° | 9.0° | 2 | 3 |
| `alpine_02` Fog Summit | 1220 m | +129 m | 5 m | 12.4° | 5.8° | 12.3° | 3 | 4 |
| `alpine_03` North Face Descent | 1180 m | +51 m | 68 m | 11.3° | −0.8° | 11.1° | 3 | 4 |
| `pine_01` Pine Valley | 1000 m | +48 m | 1 m | 6.8° | 2.7° | 6.7° | 2 | 2 |
| `pine_02` Moss Line | 1030 m | +63 m | 1 m | 9.1° | 3.5° | 8.9° | 2 | 3 |
| `pine_03` Cold Creek | 1220 m | +60 m | 39 m | 10.8° | 1.0° | 10.6° | 3 | 4 |
| `black_ridge_01` Black Gate | 1090 m | +80 m | 2 m | 11.3° | 4.1° | 11.0° | 2 | 4 |
| `black_ridge_02` Haul Road | 1220 m | +149 m | 4 m | 12.4° | 6.8° | 12.3° | 3 | 5 |
| `black_ridge_03` Ash Summit | 1320 m | +194 m | 0 m | 13.5° | 8.4° | 13.4° | 3 | 6 |
| `glacier_01` Glacier Road | 1290 m | +103 m | 10 m | 10.2° | 4.1° | 10.0° | 3 | 5 |
| `glacier_02` Polar Wind | 1240 m | +127 m | 5 m | 11.9° | 5.6° | 11.6° | 3 | 6 |
| `glacier_03` Great Glacier | 1630 m | +192 m | 0 m | 11.3° | 6.7° | 11.2° | 3 | 6 |

Notes on the columns:

- **Gain** and **descent** are sums of every positive and negative knot-to-knot elevation change (`TrackProfile.elevation_gain_m()` / `elevation_descent_m()`), not "highest minus lowest". A rolling track therefore shows more gain than its net rise.
- **Max grade** is the steepest knot slope anywhere on the road, in degrees.
- **Avg grade** is `atan(net_elevation / length)`. `alpine_03` is the only track whose net slope is negative: it summits early and spends 400 m coming down.
- **Steepest 20 m** is the maximum rise over any 20 m window — the number that decides whether a heavy truck holds one gear. The values above are the continuous optimum over the authored profile; the runtime helper `TrackProfile.steepest_window_grade_deg(20.0)` scans the window in 5 m steps, so a HUD/QA readout can land up to a tenth of a degree lower.

### 3.2 Timing, medals and surfaces

Pace is `TrackDef.model_time_s()`: the integral of a simple speed model over the authored grade (see §5). Medal times are derived from pace, never hand-written.

| Track | Pace | Gold | Silver | Bronze | Reward (credits / XP) | Surface spans (metres, in order) |
|---|---|---|---|---|---|---|
| `zagros_01` | 55.4 s | 59.8 | 67.6 | 78.6 | 390 / 67 | hard dirt 180 · gravel 150 · hard dirt 190 · rock 180 · hard dirt 220 |
| `zagros_02` | 66.9 s | 72.2 | 81.6 | 95.0 | 520 / 89 | hard dirt 210 · rock 190 · gravel 160 · hard dirt 200 · gravel 320 |
| `zagros_03` | 105.9 s | 114.3 | 129.1 | 150.3 | 650 / 111 | hard dirt 160 · scree 270 · rock 130 · gravel 200 · hard dirt 260 · scree 130 * |
| `alpine_01` | 70.6 s | 76.2 | 86.1 | 100.2 | 650 / 111 | asphalt 420 · rock 80 · asphalt 200 · hard dirt 200 · asphalt 280 † |
| `alpine_02` | 142.4 s | 153.8 | 173.7 | 202.2 | 780 / 133 | asphalt 180 · rock 240 · snow 200 · rock 200 · snow 180 · asphalt 200 † |
| `alpine_03` | 71.7 s | 77.4 | 87.5 | 101.8 | 780 / 133 | asphalt 160 · rock 220 · snow 140 · asphalt 260 · rock 220 · asphalt 260 * |
| `pine_01` | 64.9 s | 70.1 | 79.1 | 92.1 | 520 / 89 | hard dirt 200 · mud 180 · hard dirt 180 · wet mud 220 · hard dirt 180 † |
| `pine_02` | 79.6 s | 86.0 | 97.1 | 113.1 | 650 / 111 | hard dirt 170 · wet mud 180 · mud 170 · hard dirt 180 · wet mud 200 · hard dirt 180 * |
| `pine_03` | 99.1 s | 107.0 | 120.9 | 140.7 | 780 / 133 | hard dirt 180 · wet mud 220 · mud 160 · water 180 · wet mud 200 · hard dirt 180 · mud 100 |
| `black_ridge_01` | 100.3 s | 108.4 | 122.4 | 142.5 | 780 / 133 | ash 200 · scree 180 · rock 180 · ash 200 · rock 180 · scree 140 † |
| `black_ridge_02` | 213.0 s | 230.1 | 259.9 | 302.5 | 910 / 155 | ash 190 · scree 240 · rock 190 · scree 200 · ash 180 · rock 150 † |
| `black_ridge_03` | 272.0 s | 293.8 | 331.9 | 386.3 | 1040 / 177 | ash 180 · scree 220 · rock 200 · ash 200 · scree 200 · rock 200 · ash 120 |
| `glacier_01` | 133.9 s | 144.6 | 163.3 | 190.1 | 910 / 155 | snow 200 · ice 220 · snow 140 · ice 200 · snow 200 · ice 140 † |
| `glacier_02` | 176.8 s | 190.9 | 215.7 | 251.0 | 910 / 155 | snow 180 · ice 180 · snow 160 · ice 180 · snow 200 · ice 200 · snow 140 |
| `glacier_03` | 267.7 s | 289.1 | 326.6 | 380.2 | 1040 / 177 | snow 220 · ice 240 · snow 180 · ice 240 · snow 200 · ice 180 · snow 180 † |

`*` the authored surface sections run past `finish_x_m()` (length − 3 m).
`†` the authored sections stop before the end of the road; the remaining metres read as `hard_dirt` because `surface_id_at()` falls back to that default when no section matches. The longest such gap is `glacier_01` (190 m) and `glacier_03` (190 m).

Rewards follow `260 + difficulty × 130` credits and `45 + difficulty × 22` XP (`scripts/tracks/track_catalog.gd:334-335`).

### 3.3 What each track is for

**Zagros.** `zagros_01` is the tutorial road: 7.4° maximum, two gentle climbs, one short crest, and a surface mix that lets the player feel dirt → gravel → rock without a grade that punishes a wrong gear. `zagros_02` is the speed track — a fast high plain, then a limestone wall at 10.8°, then dry switchbacks; the lesson is banking speed before the grade. `zagros_03` is the first sustained scree climb (11.9° max, 85 m of gain over 1060 m) and the first track where low-rpm torque decides the run.

**Alpine.** `alpine_01` is the paved reference track: 76 % of its authored span is asphalt, the gradient is one long unbroken climb rather than a series of crests, and it is the only track that rewards a highway tyre compound. `alpine_02` is the cooling track — 129 m of gain with 400 m of rock and snow above 12°, on a 1220 m road; a marginal radiator will be at the derate threshold before the summit (see `docs/ENGINE_THERMAL_SYSTEM.md`). `alpine_03` is the descent track: it summits at 370 m (45 m above the start), then drops 68 m to the finish, with a 120 m segment that reaches −19 % slope. The work is brake and gear discipline rather than throttle.

**Pine.** `pine_01` is the grip-readability track: wet mud with 0.31 peak grip alternating with hard dirt at 0.86, so the same throttle produces very different slip two seconds apart. `pine_02` is short climbs in sequence — twelve segments, eight of them uphill, max 9.1° — where measured throttle beats a heavy foot. `pine_03` adds 180 m of standing water (0.22 grip, 0.26 rolling resistance) after a summit and a steep drop, so the tyre choice and the entry speed are both committed before the water arrives.

**Black Ridge.** `black_ridge_01` is short violent grades on ash and scree — 11.3° maximum but only 80 m of gain, so it is a suspension-durability track more than a power track. `black_ridge_02` is the unbroken mining climb: +149 m, 6.8° average, 12.4° maximum, 213 s of pace. `black_ridge_03` is the hardest road in the game: +194 m over 1320 m, 8.4° average, three knot slopes at or above 22 %, and a pace of 272 s. It is the track that justifies low range.

**Glacier.** `glacier_01` is packed snow on a long grade — 50.9 % of its authored span is ice at 0.15 peak grip, which is less than a fifth of asphalt. `glacier_02` is an exposed ridge whose grade never settles: fourteen segments alternating between 0.01 and 0.21 slope, with ice under most of them. `glacier_03` is the longest road in the game at 1630 m and the longest climb: 192 m of gain, ice for 660 m of it, and a 267.7 s pace that makes cooling and patience the two limiting resources.

---

## 4. Authored versus derived

A deliberate rule: **the catalogue authors slopes and lengths only.** Everything else is computed once, at build time.

| Quantity | Authored? | Where it comes from |
|---|---|---|
| Segment length, entry slope, exit slope | Yes | `TRACKS[].segs` triples in `track_catalog.gd` |
| Surface sections | Yes | `TRACKS[].surfaces` as `[from_m, to_m, surface_id]` |
| Checkpoints | Yes, as fractions | `TRACKS[].cp`, resolved to metres by `round(length × fraction)` |
| Start elevation | Effectively no | `start_elevation_m` defaults to 0 for every track |
| Length, gain, descent, net | No | Integrated from the segments |
| Max / average / steepest-20 m grade | No | From the knot slopes |
| Pace, split targets | No | `model_time_s()` / `model_time_to()` |
| Medal times | No | `pace × 1.08`, `× 1.22`, `× 1.42`, rounded to 0.1 s |
| Rewards | No | `260 + difficulty × 130`, `45 + difficulty × 22` |
| Scenery placement | Seeded random | `decor_seed`, `decor_density` — visual only |

Checkpoints are authored as fractions for one reason: a segment length can be tuned later without ever producing an out-of-order or off-road checkpoint. `TrackDef.is_valid_layout()` enforces the resulting invariants — strictly increasing, at least 10 m apart, at least 5 m inside the drivable road, at least two segments, longer than 60 m.

---

## 5. The medal and pacing model

`TrackDef.model_time_s()` is not a simulation. It is a reference pace used for medal targets and the ghost/HUD delta, and it is intentionally simple:

```
v(x) = ref × clamp(1 − 4.2·s, 0.16, 1.0)        when s > 0   (uphill)
v(x) = ref × clamp(1 − 1.8·s, 1.0, 1.45)        when s ≤ 0   (downhill)
v(x) = max(v, 3.0)
pace = Σ (2 m / v)                              stepped every 2 m
```

where `s` is the slope at the sample and `ref` is the track's `reference_speed_mps` (15–26 m/s depending on the track's intended class). Uphill therefore costs speed roughly four times faster than downhill gains it, and the 3 m/s floor stops a 24 % slope from producing an infinite pace.

The three medal targets are then `pace × 1.08`, `× 1.22`, `× 1.42`, each rounded to 0.1 s (`track_catalog.gd:331-333`). A player who matches the reference pace earns silver by construction; gold requires beating the model by 8 %.

This model deliberately ignores grip, mass and power — those are the car's job. It also means a medal is a statement about the road, not about a particular vehicle, which is why the same targets apply to all five vehicles.

---

## 6. TrackProfile mathematics

### 6.1 Slope integration

A profile is a list of contiguous segments. Each stores the slope at its entry (`s_in`) and exit (`s_out`) as rise ÷ run. Within a segment the slope blends linearly in normalised distance `t = (x − x₀) / L`:

```
s(t) = s_in + (s_out − s_in)·t
y(t) = y₀ + L·( s_in·t + ½·(s_out − s_in)·t² )
```

The second line is the exact integral of the first, which is why `TrackProfile.elevation_at()` needs no numerical integration and no lookup table — every query is closed-form (`scripts/tracks/track_profile.gd:106-135`).

### 6.2 C1 continuity

At every knot the incoming `s_out` and the outgoing `s_in` are the same number (the catalogue is authored that way: each triple's second value repeats the previous triple's third). `build()` therefore stores a single slope per knot and both sides read it, so position *and* first derivative match exactly at every joint. The surface is C1 continuous: no steps, no seams, no tangents that jump.

This is the contract the terrain builder relies on. It samples the profile every 0.35 m and builds one concave collision polyline from those samples; because the underlying curve is C1, the collision surface and the rendered surface cannot disagree by more than the sampling error, and the error is monotone rather than a sawtooth.

Knots beyond the authored range are handled by extrapolating the end slope (`elevation_at()` for `x < 0` and `x > total`), so a car that rolls past the finish line continues on a straight continuation instead of falling off the end of the world.

### 6.3 Why there is no random noise

Random elevation is the cheapest way to make terrain look natural and the most expensive way to make it drivable:

- it destroys C1 continuity at the sample scale, so every bump becomes a collision edge and an impact impulse;
- it makes the briefing numbers meaningless, because gain and grade would change per run unless the seed is frozen — and if the seed is frozen, it is authored data with extra steps;
- it makes a gear choice untestable, because the same road is never the same road.

So the only randomness in the pipeline is scenery placement and scale, driven by `decor_seed` (`terrain_builder.gd:250-252`). The driving surface is fully deterministic: identical inputs produce identical geometry, which is what lets the medal model and the physics tests mean anything.

### 6.4 Derived measurements

| Function | Definition | Used by |
|---|---|---|
| `total_length()` | Σ segment lengths | briefing, gates, camera limits |
| `elevation_gain_m()` / `elevation_descent_m()` | Σ positive / negative knot deltas | briefing |
| `net_elevation_m()` | last knot − first knot | average grade |
| `max_grade_deg()` | max over knots of `|atan(s)|` | briefing, validation |
| `average_grade_deg()` | `atan(net / length)` | briefing |
| `steepest_window_grade_deg(w)` | max of `atan((y(x+w) − y(x))/w)`, scanned every 5 m | briefing, designer check |
| `sample(step)` | uniform polyline | collision, rendering |
| `knots()` | the knot polyline | editor preview |
| `slope_at()` / `grade_deg_at()` | closed-form per segment | physics queries, HUD |

`max_grade_deg()` reports the steepest *instantaneous* slope, while `steepest_window_grade_deg(20)` reports the steepest *sustained* 20 m. The gap between them is a measure of how sharp the crests are: `black_ridge_03` has 13.5° instantaneous and 13.4° sustained (a long ramp into the peak), while `pine_01` has 6.8° and 6.7° (gentle everywhere).

---

## 7. Authoring a new track

1. Add an entry to `TrackCatalog.TRACKS` with `id`, `region`, `diff`, both names, both briefs, `segs`, `surfaces`, `cp`, `weather`, `tod`, `ref`, `seed`.
2. Author `segs` as `[length_m, slope_in, slope_out]` triples. **Make each triple's `slope_in` equal the previous triple's `slope_out`** — this is what preserves C1 continuity.
3. Keep every knot slope at or below 0.24 unless the road is meant to be a wall; `tools/smoke_v3.gd` fails the build at more than 30° of max grade.
4. Author `surfaces` as `[from_m, to_m, surface_id]`. Cover the whole length: sections that stop early fall back to `hard_dirt`, and sections that run past the finish are clipped by the lookup but still counted in `surface_distribution()`.
5. Author `cp` as fractions of length (0 < f < 1). Two or three checkpoints is the current convention; `is_valid_layout()` requires them at least 10 m apart and 5 m inside the road.
6. Set `ref` (flat-ground reference speed in m/s) and let the medals be derived. Do not type medal times.
7. Run `.\tools\local_build\run_game.ps1 -Scene res://tools/smoke_v3.tscn` and read the printed row: length, gain, descent, max grade, average grade, checkpoint count, pace and the three medals.

**Expected result:** the printed `length_m` equals the sum of your segment lengths, `max_grade_deg` is at most 30, the layout check prints no `FAIL invalid layout`, and the medals sit at 1.08 / 1.22 / 1.42 × pace.

---

## 8. Known gaps and data notes

These are real properties of the current catalogue, not aspirations.

- **Surface spans do not always cover the road.** Five tracks stop short of the finish (`alpine_01`, `alpine_02`, `pine_01`, `black_ridge_01`, `black_ridge_02`, `glacier_01`, `glacier_03`), and the tail reads as `hard_dirt`. Three tracks author sections past the finish (`zagros_03`, `alpine_03`, `pine_02`), which changes `surface_distribution()` percentages without changing what the car drives on.
- **`weather: "wind"` is not implemented.** `alpine_03`, `black_ridge_03` and `glacier_02` author `wind`; `WeatherSystem` knows only `clear`, `cloudy`, `rain`, `heavy_rain`, `snow` and `fog`, and an unknown id resolves to `clear` (`scripts/race/weather_system.gd:32`). Those three tracks therefore run with neutral grip and no particles, and the crosswind in their briefs is narrative only.
- **Every track is legal for every mode.** `TrackDef.modes` is empty for all fifteen tracks, and `supports_mode()` returns `true` for an empty list. The mode list in `GameSession.MODES` (rally, hillclimb, downhill, sprint, timeattack, endurance, freedrive, test) is not yet used to filter tracks.
- **No track uses `start_elevation_m`.** All fifteen start at 0 m; only the relative profile is authored. Absolute altitude is therefore not modelled, and the "altitude" mentioned in the Alpine brief is narrative.
- **The checkpoints are timing gates, not gates in the road.** A gate is a 1.2 m wide `Area2D` at the profile height (`terrain_builder.gd:390-394`); it cannot be missed laterally because the car cannot leave the road surface.
- **Terrain decor density is authored at 1.0 everywhere.** `decor_density` is not varied per track, so scenery spacing is effectively `9.0 / 1.0` metres with ±40 % jitter.

---

## Appendix A — Authored slope segments

Every number in §3 comes from these triples (`[length_m, slope_in, slope_out]`, slope = rise ÷ run).

**zagros_01** — 10 segments
`[90, 0.00, 0.03] [130, 0.03, 0.09] [70, 0.09, 0.10] [60, 0.10, 0.02] [110, 0.02, −0.04] [120, −0.04, 0.00] [100, 0.00, 0.11] [80, 0.11, 0.05] [90, 0.05, 0.13] [70, 0.13, 0.06]`

**zagros_02** — 11 segments
`[150, 0.00, −0.02] [120, −0.02, 0.01] [80, 0.01, 0.17] [70, 0.17, 0.19] [60, 0.19, 0.08] [100, 0.08, 0.02] [90, 0.02, −0.07] [130, −0.07, −0.02] [110, −0.02, 0.06] [90, 0.06, 0.14] [80, 0.14, 0.04]`

**zagros_03** — 12 segments
`[70, 0.00, 0.06] [90, 0.06, 0.15] [110, 0.15, 0.21] [90, 0.21, 0.18] [80, 0.18, 0.10] [70, 0.10, 0.03] [60, 0.03, −0.05] [110, −0.05, −0.12] [130, −0.12, −0.04] [90, −0.04, 0.08] [80, 0.08, 0.16] [80, 0.16, 0.07]`

**alpine_01** — 12 segments
`[120, 0.00, 0.04] [140, 0.04, 0.12] [100, 0.12, 0.16] [90, 0.16, 0.14] [110, 0.14, 0.06] [80, 0.06, 0.01] [120, 0.01, −0.08] [140, −0.08, −0.10] [110, −0.10, −0.02] [90, −0.02, 0.05] [100, 0.05, 0.13] [60, 0.13, 0.09]`

**alpine_02** — 13 segments
`[90, 0.00, 0.05] [100, 0.05, 0.13] [120, 0.13, 0.19] [100, 0.19, 0.22] [90, 0.22, 0.20] [80, 0.20, 0.12] [70, 0.12, 0.04] [90, 0.04, 0.10] [110, 0.10, 0.17] [100, 0.17, 0.11] [80, 0.11, 0.02] [90, 0.02, −0.06] [100, −0.06, 0.00]`

**alpine_03** — 13 segments
`[70, 0.00, 0.09] [80, 0.09, 0.16] [90, 0.16, 0.20] [70, 0.20, 0.12] [60, 0.12, 0.03] [80, 0.03, −0.06] [110, −0.06, −0.15] [120, −0.15, −0.19] [110, −0.19, −0.14] [100, −0.14, −0.08] [120, −0.08, −0.02] [90, −0.02, 0.04] [80, 0.04, 0.09]`

**pine_01** — 10 segments
`[100, 0.00, 0.02] [110, 0.02, 0.07] [90, 0.07, 0.04] [120, 0.04, 0.10] [100, 0.10, 0.05] [80, 0.05, −0.03] [120, −0.03, 0.01] [110, 0.01, 0.08] [90, 0.08, 0.12] [80, 0.12, 0.04]`

**pine_02** — 12 segments
`[80, 0.00, 0.04] [90, 0.04, 0.11] [70, 0.11, 0.03] [100, 0.03, 0.09] [80, 0.09, 0.14] [70, 0.14, 0.05] [90, 0.05, −0.04] [110, −0.04, 0.02] [100, 0.02, 0.10] [90, 0.10, 0.16] [80, 0.16, 0.06] [70, 0.06, −0.02]`

**pine_03** — 13 segments
`[80, 0.00, 0.06] [90, 0.06, 0.15] [100, 0.15, 0.19] [80, 0.19, 0.10] [70, 0.10, 0.02] [90, 0.02, −0.09] [100, −0.09, −0.16] [110, −0.16, −0.11] [120, −0.11, −0.03] [110, −0.03, 0.05] [100, 0.05, 0.11] [90, 0.11, 0.03] [80, 0.03, −0.02]`

**black_ridge_01** — 12 segments
`[90, 0.00, 0.05] [100, 0.05, 0.14] [80, 0.14, 0.09] [90, 0.09, 0.18] [70, 0.18, 0.06] [100, 0.06, −0.05] [120, −0.05, 0.02] [100, 0.02, 0.12] [90, 0.12, 0.20] [80, 0.20, 0.08] [90, 0.08, 0.03] [80, 0.03, −0.04]`

**black_ridge_02** — 13 segments
`[70, 0.00, 0.07] [90, 0.07, 0.16] [110, 0.16, 0.21] [100, 0.21, 0.19] [90, 0.19, 0.22] [80, 0.22, 0.15] [90, 0.15, 0.09] [100, 0.09, 0.14] [110, 0.14, 0.20] [100, 0.20, 0.12] [80, 0.12, 0.03] [90, 0.03, −0.05] [110, −0.05, 0.00]`

**black_ridge_03** — 15 segments
`[70, 0.00, 0.08] [80, 0.08, 0.17] [100, 0.17, 0.23] [90, 0.23, 0.21] [80, 0.21, 0.24] [90, 0.24, 0.19] [80, 0.19, 0.12] [100, 0.12, 0.18] [110, 0.18, 0.22] [90, 0.22, 0.14] [100, 0.14, 0.06] [90, 0.06, 0.11] [80, 0.11, 0.16] [90, 0.16, 0.05] [70, 0.05, −0.03]`

**glacier_01** — 13 segments
`[90, 0.00, 0.04] [110, 0.04, 0.11] [120, 0.11, 0.16] [100, 0.16, 0.14] [90, 0.14, 0.09] [100, 0.09, 0.13] [110, 0.13, 0.18] [100, 0.18, 0.10] [90, 0.10, 0.02] [100, 0.02, −0.08] [110, −0.08, −0.04] [90, −0.04, 0.03] [80, 0.03, 0.08]`

**glacier_02** — 14 segments
`[80, 0.00, 0.06] [90, 0.06, 0.15] [100, 0.15, 0.20] [80, 0.20, 0.08] [70, 0.08, 0.13] [90, 0.13, 0.19] [100, 0.19, 0.11] [80, 0.11, 0.04] [90, 0.04, 0.14] [100, 0.14, 0.21] [90, 0.21, 0.10] [80, 0.10, 0.01] [100, 0.01, −0.07] [90, −0.07, 0.02]`

**glacier_03** — 16 segments
`[90, 0.00, 0.05] [100, 0.05, 0.13] [120, 0.13, 0.18] [110, 0.18, 0.16] [100, 0.16, 0.20] [110, 0.20, 0.17] [100, 0.17, 0.11] [110, 0.11, 0.15] [120, 0.15, 0.19] [100, 0.19, 0.12] [90, 0.12, 0.05] [100, 0.05, 0.10] [110, 0.10, 0.14] [100, 0.14, 0.06] [90, 0.06, −0.02] [80, −0.02, 0.03]`
