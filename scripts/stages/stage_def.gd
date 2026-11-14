class_name StageDef
extends Resource
## Authoring data for one stage. The terrain, collisions, decorations, checkpoints
## and scoring are all generated from this, so twelve stages are genuinely different
## elevation profiles and obstacle layouts rather than recolours.

@export var id: String = "canyon_01"
@export var environment: String = "canyon"
@export var name_fa: String = "گردنهٔ سرخ"
@export var name_en: String = "Red Pass"
@export var brief_fa: String = ""
@export var brief_en: String = ""
@export var difficulty: int = 1
@export var length_m: float = 420.0
@export var mode: String = "career"
@export var medal_gold: float = 95.0
@export var medal_silver: float = 115.0
@export var medal_bronze: float = 145.0
@export var reward_credits: int = 320
@export var reward_xp: int = 60
@export var seed_value: int = 1234
@export var noise_amplitude: float = 1.0

## Elevation keyframes: x in metres, y = height above the stage floor in metres.
@export var points: PackedVector2Array = PackedVector2Array()
## [{ "from": 0.0, "to": 120.0, "surface": "hard_dirt" }, ...]
@export var surface_spans: Array[Dictionary] = []
## [{ "kind": "rock_a", "x": 88.0, "scale": 1.1, "rot": -0.15, "solid": true }, ...]
@export var obstacles: Array[Dictionary] = []
@export var checkpoints: PackedFloat32Array = PackedFloat32Array()
@export var decor_density: float = 1.0
@export var weather: String = "clear"
@export var time_of_day: String = "afternoon"

func label(lang: String) -> String:
	return name_fa if lang == "fa" else name_en

func brief(lang: String) -> String:
	return brief_fa if lang == "fa" else brief_en

func medal_for_time(seconds: float) -> int:
	if seconds <= medal_gold:
		return 3
	if seconds <= medal_silver:
		return 2
	if seconds <= medal_bronze:
		return 1
	return 0

func surface_id_at(x_m: float) -> String:
	for span: Dictionary in surface_spans:
		var from_x: float = float(span.get("from", 0.0))
		var to_x: float = float(span.get("to", length_m))
		if x_m >= from_x and x_m <= to_x:
			return String(span.get("surface", "hard_dirt"))
	return "hard_dirt"

## Approximate elevation at a keyframe x (linear between authored points, extended flat).
func elevation_at(x_m: float) -> float:
	if points.is_empty():
		return 0.0
	if x_m <= points[0].x:
		return points[0].y
	for i: int in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		if x_m >= a.x and x_m <= b.x:
			var t: float = 0.0 if is_equal_approx(b.x, a.x) else (x_m - a.x) / (b.x - a.x)
			return lerpf(a.y, b.y, t)
	return points[points.size() - 1].y

func net_climb_m() -> float:
	if points.is_empty():
		return 0.0
	return points[points.size() - 1].y - points[0].y

## Route briefing data, computed from the authored keyframes and surface spans —
## never from a hand-written number that could drift away from the stage.
func route_stats() -> Dictionary:
	var max_grade: float = 0.0
	var sum_grade: float = 0.0
	var grade_count: int = 0
	var climbs: int = 0
	var descents: int = 0
	for i: int in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var dx: float = b.x - a.x
		if dx <= 0.01:
			continue
		var grade: float = rad_to_deg(atan2(b.y - a.y, dx))
		max_grade = maxf(max_grade, grade)
		sum_grade += absf(grade)
		grade_count += 1
		if grade >= 12.0:
			climbs += 1
		elif grade <= -12.0:
			descents += 1

	var rock: float = 0.0
	var dirt: float = 0.0
	var mud: float = 0.0
	var total: float = 0.0
	for span: Dictionary in surface_spans:
		var from_x: float = float(span.get("from", 0.0))
		var to_x: float = float(span.get("to", length_m))
		var width: float = maxf(to_x - from_x, 0.0)
		var sid: String = String(span.get("surface", "hard_dirt"))
		total += width
		match sid:
			"rock", "gravel", "scree", "asphalt", "steel":
				rock += width
			"mud", "wet_mud", "snow", "ice", "water", "ash":
				mud += width
			_:
				dirt += width
	var denom: float = maxf(total, 1.0)
	var solid_obstacles: int = 0
	for o: Dictionary in obstacles:
		if bool(o.get("solid", true)):
			solid_obstacles += 1
	return {
		"length_m": length_m,
		"max_grade_deg": max_grade,
		"avg_grade_deg": sum_grade / maxf(float(grade_count), 1.0),
		"rock_pct": rock / denom * 100.0,
		"dirt_pct": dirt / denom * 100.0,
		"mud_pct": mud / denom * 100.0,
		"obstacles": solid_obstacles,
		"climbs": climbs,
		"descents": descents,
		"net_climb_m": net_climb_m(),
	}
