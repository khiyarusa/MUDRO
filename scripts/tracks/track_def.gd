class_name TrackDef
extends Resource
## MUDRO 3.0 track definition — the data-driven replacement for the old
## obstacle-based StageDef.
##
## A track is a *road*: a continuous authored elevation profile, a set of surface
## sections, checkpoints, medal targets and a scenery theme. There is no obstacle
## list, no solid prop placement and no random terrain noise anywhere in this
## definition. Everything the terrain builder needs is here, and every number the
## route briefing shows is derived from the profile, never hand-written twice.

enum Mode { RALLY, HILL_CLIMB, DOWNHILL, SPRINT, TIME_ATTACK, ENDURANCE, FREE_DRIVE, TEST }

@export_group("Identity")
@export var id: String = "zagros_01"
@export var region: String = "zagros"
@export var name_fa: String = ""
@export var name_en: String = ""
@export_multiline var brief_fa: String = ""
@export_multiline var brief_en: String = ""
@export var difficulty: int = 1
## Race modes this track is legal for. Empty means every mode.
@export var modes: PackedStringArray = PackedStringArray()

@export_group("Profile")
## [{ "len": 120.0, "s_in": 0.02, "s_out": 0.09 }, ...] — slope is rise / run.
@export var profile_segments: Array[Dictionary] = []
@export var start_elevation_m: float = 0.0
## [{ "from": 0.0, "to": 120.0, "surface": "hard_dirt" }, ...]
@export var surface_sections: Array[Dictionary] = []
@export var checkpoints: PackedFloat32Array = PackedFloat32Array()

@export_group("Timing")
@export var medal_gold: float = 0.0
@export var medal_silver: float = 0.0
@export var medal_bronze: float = 0.0
@export var reward_credits: int = 300
@export var reward_xp: int = 50
## Flat-ground reference speed of the track's intended class, m/s. Used only for
## split targets and the AI ghost pace, never for physics.
@export var reference_speed_mps: float = 20.0

@export_group("Atmosphere")
@export var weather: String = "clear"
@export var time_of_day: String = "afternoon"
@export var decor_density: float = 1.0
@export var decor_seed: int = 1337

var _profile: TrackProfile = null

func profile() -> TrackProfile:
	if _profile == null:
		_profile = TrackProfile.new().setup(profile_segments, start_elevation_m)
		_profile.build()
	return _profile

func length_m() -> float:
	return profile().total_length()

func start_x_m() -> float:
	return 3.0

func finish_x_m() -> float:
	return maxf(length_m() - 3.0, start_x_m() + 20.0)

func elevation_at(x_m: float) -> float:
	return profile().elevation_at(x_m)

func grade_deg_at(x_m: float) -> float:
	return profile().grade_deg_at(x_m)

func supports_mode(mode: String) -> bool:
	if modes.is_empty():
		return true
	return modes.has(mode)

func label(lang: String) -> String:
	return name_fa if lang == "fa" else name_en

func brief(lang: String) -> String:
	return brief_fa if lang == "fa" else brief_en

func medal_for_time(seconds: float) -> int:
	if medal_gold > 0.0 and seconds <= medal_gold:
		return 3
	if medal_silver > 0.0 and seconds <= medal_silver:
		return 2
	if medal_bronze > 0.0 and seconds <= medal_bronze:
		return 1
	return 0

func surface_id_at(x_m: float) -> String:
	for section: Dictionary in surface_sections:
		var from_x: float = float(section.get("from", 0.0))
		var to_x: float = float(section.get("to", length_m()))
		if x_m >= from_x and x_m <= to_x:
			return String(section.get("surface", "hard_dirt"))
	return "hard_dirt"

## Surface sections are authored as absolute metres, but the profile length is the
## sum of its segments and can drift when a segment is retuned. A gap in the surface
## list would leave road with no friction definition and an overrun would make
## `surface_distribution()` report more than 100 %, so the authored ranges are
## clamped to the real road and any gap is closed by the section before it.
## Called once at catalogue build; the result is the single source of truth.
func normalize_surfaces() -> void:
	var length: float = length_m()
	if length <= 0.0:
		surface_sections = [{"from": 0.0, "to": 1.0, "surface": "hard_dirt"}]
		return
	var sorted: Array[Dictionary] = []
	for section: Dictionary in surface_sections:
		sorted.append({
			"from": float(section.get("from", 0.0)),
			"to": float(section.get("to", length)),
			"surface": String(section.get("surface", "hard_dirt")),
		})
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["from"]) < float(b["from"]))
	var out: Array[Dictionary] = []
	# Walk the road from 0 to `length`. A gap is absorbed by the section that ends
	# before it, an overlap is trimmed by the section that starts inside it.
	var cursor: float = 0.0
	for section: Dictionary in sorted:
		var to_x: float = clampf(float(section["to"]), 0.0, length)
		if to_x <= cursor:
			continue
		out.append({"from": cursor, "to": to_x, "surface": String(section["surface"])})
		cursor = to_x
	if out.is_empty():
		out.append({"from": 0.0, "to": length, "surface": "hard_dirt"})
	elif out[out.size() - 1]["to"] < length:
		# The road must be surfaced all the way to the finish: the last authored
		# section carries the remaining tail rather than leaving it undefined.
		out[out.size() - 1]["to"] = length
	surface_sections = out

# ------------------------------------------------------------------ analysis ---

## Surface share in percent, computed from the authored sections.
func surface_distribution() -> Dictionary:
	var totals: Dictionary = {}
	var total: float = 0.0
	for section: Dictionary in surface_sections:
		var from_x: float = float(section.get("from", 0.0))
		var to_x: float = float(section.get("to", length_m()))
		var width: float = maxf(to_x - from_x, 0.0)
		var sid: String = String(section.get("surface", "hard_dirt"))
		totals[sid] = float(totals.get(sid, 0.0)) + width
		total += width
	var out: Dictionary = {}
	if total <= 0.0:
		return out
	for sid: String in totals.keys():
		out[sid] = float(totals[sid]) / total * 100.0
	return out

## Route briefing data. Every field is measured from the profile.
func stats() -> Dictionary:
	var p: TrackProfile = profile()
	var surfaces: Dictionary = surface_distribution()
	var dominant: String = "hard_dirt"
	var best: float = -1.0
	for sid: String in surfaces.keys():
		if float(surfaces[sid]) > best:
			best = float(surfaces[sid])
			dominant = sid
	return {
		"id": id,
		"region": region,
		"length_m": length_m(),
		"elevation_gain_m": p.elevation_gain_m(),
		"elevation_descent_m": p.elevation_descent_m(),
		"net_elevation_m": p.net_elevation_m(),
		"max_grade_deg": p.max_grade_deg(),
		"avg_grade_deg": p.average_grade_deg(),
		"steepest_20m_deg": p.steepest_window_grade_deg(20.0),
		"surface_pct": surfaces,
		"dominant_surface": dominant,
		"checkpoints": checkpoints.size(),
		"difficulty": difficulty,
		"model_time_s": model_time_s(),
	}

## Elevation graph points for the briefing/editor preview.
func elevation_graph(points: int = 96) -> PackedVector2Array:
	var out := PackedVector2Array()
	var total: float = length_m()
	if total <= 0.0:
		return out
	for i: int in range(points + 1):
		var x: float = total * float(i) / float(points)
		out.append(Vector2(x, elevation_at(x)))
	return out

## Expected ground speed at x, from the authored grade. Uphill loses speed hard,
## downhill gains a little; grip is not modelled here (that is the car's job).
func expected_speed_mps(x_m: float) -> float:
	var slope: float = profile().slope_at(x_m)
	var v: float = reference_speed_mps
	if slope > 0.0:
		v *= clampf(1.0 - slope * 4.2, 0.16, 1.0)
	else:
		v *= clampf(1.0 - slope * 1.8, 1.0, 1.45)
	return maxf(v, 3.0)

## Integral of the speed model: the reference pace used for split targets.
func model_time_s() -> float:
	var total: float = length_m()
	if total <= 0.0:
		return 0.0
	var time: float = 0.0
	var step: float = 2.0
	var x: float = 0.0
	while x < total:
		var v: float = expected_speed_mps(x + step * 0.5)
		time += step / maxf(v, 0.1)
		x += step
	return time

func model_time_to(x_m: float) -> float:
	var time: float = 0.0
	var step: float = 2.0
	var x: float = 0.0
	while x < x_m:
		var seg: float = minf(step, x_m - x)
		time += seg / maxf(expected_speed_mps(x + seg * 0.5), 0.1)
		x += seg
	return time

## Split targets for the ghost and the HUD delta.
func split_targets() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for x: float in checkpoints:
		out.append(model_time_to(x))
	if out.is_empty() or finish_x_m() > out[out.size() - 1]:
		out.append(model_time_to(finish_x_m()))
	return out

## Checkpoints must be strictly increasing and inside the drivable road.
func is_valid_layout() -> bool:
	var last: float = -1.0
	for x: float in checkpoints:
		if x <= last + 10.0:
			return false
		if x < start_x_m() + 5.0 or x > finish_x_m() - 5.0:
			return false
		last = x
	return profile_segments.size() >= 2 and length_m() > 60.0

func describe() -> String:
	var s: Dictionary = stats()
	return "%s — %.0f m, +%.0f m, -%.0f m, max %.1f%%, %d CP" % [
		id, float(s["length_m"]), float(s["elevation_gain_m"]),
		float(s["elevation_descent_m"]), float(s["max_grade_deg"]),
		int(s["checkpoints"]),
	]
