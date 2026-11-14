class_name GhostReplay
extends Node2D
## A real ghost: the best run on this track is recorded from the simulated chassis
## every 50 ms and replayed as a translucent silhouette of the same vehicle.
##
## Nothing is extrapolated from a target time and nothing is teleported: the ghost
## follows the positions the physics actually produced. A ghost is only saved when
## a run genuinely beats the stored best, and the file lives under user:// so it
## never ships inside the APK.

const SAMPLE_DT: float = 0.05
const DIR: String = "user://ghosts"

var track_id: String = ""
var vehicle_id: String = ""
var samples: Array[Dictionary] = []
var best_time: float = 0.0
var playing: bool = false
var time: float = 0.0
var _cursor: int = 0

var _body: Polygon2D
var _label: Label

func setup(track: String, vehicle: VehicleDef, show_ghost: bool = true) -> void:
	track_id = track
	vehicle_id = vehicle.id if vehicle != null else ""
	z_index = 3
	_body = Polygon2D.new()
	_body.color = Color(0.62, 0.86, 0.92, 0.26)
	if vehicle != null and not vehicle.body_polygon_m.is_empty():
		var pts := PackedVector2Array()
		for p: Vector2 in vehicle.body_polygon_m:
			pts.append(p * Units.PPM)
		_body.polygon = pts
	else:
		_body.polygon = PackedVector2Array([
			Vector2(-40, 0), Vector2(-40, -30), Vector2(40, -30), Vector2(40, 0),
		])
	_body.visible = false
	add_child(_body)
	_label = Label.new()
	_label.text = "BEST"
	_label.add_theme_color_override("font_color", Color(0.72, 0.92, 0.98, 0.75))
	_label.add_theme_font_size_override("font_size", 13)
	_label.position = Vector2(-24, -84)
	_label.visible = false
	add_child(_label)
	if show_ghost:
		load_best()

func ghost_path(track: String = "") -> String:
	var id: String = track if not track.is_empty() else track_id
	return "%s/%s.json" % [DIR, id]

func load_best() -> bool:
	var path: String = ghost_path()
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	var d: Dictionary = parsed as Dictionary
	if not (d.get("samples") is Array):
		return false
	samples.clear()
	for row: Variant in (d["samples"] as Array):
		if row is Array and (row as Array).size() >= 4:
			var a: Array = row as Array
			samples.append({"t": float(a[0]), "x": float(a[1]), "y": float(a[2]), "r": float(a[3])})
	best_time = float(d.get("time", 0.0))
	vehicle_id = String(d.get("vehicle", vehicle_id))
	playing = not samples.is_empty()
	return playing

func has_ghost() -> bool:
	return not samples.is_empty()

## Called by the race scene only when a run beats the stored best.
func save_run(time_s: float, recorded: Array[Dictionary], vehicle: String) -> void:
	if recorded.size() < 4:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var rows: Array = []
	for s: Dictionary in recorded:
		rows.append([
			snappedf(float(s.get("t", 0.0)), 0.01),
			snappedf(float(s.get("x", 0.0)) / Units.PPM, 0.01),
			snappedf(float(s.get("y", 0.0)) / Units.PPM, 0.01),
			snappedf(float(s.get("r", 0.0)), 0.001),
		])
	var payload: Dictionary = {"track": track_id, "vehicle": vehicle, "time": time_s, "samples": rows}
	var f: FileAccess = FileAccess.open(ghost_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload))
	f.close()
	samples.clear()
	for row: Array in rows:
		samples.append({"t": float(row[0]), "x": float(row[1]) * Units.PPM,
			"y": float(row[2]) * Units.PPM, "r": float(row[3])})
	best_time = time_s
	playing = true

func start_replay() -> void:
	time = 0.0
	_cursor = 0
	playing = not samples.is_empty()

func advance(delta: float) -> void:
	if not playing or samples.is_empty():
		if _body != null:
			_body.visible = false
			_label.visible = false
		return
	time += delta
	while _cursor + 1 < samples.size() and float(samples[_cursor + 1]["t"]) <= time:
		_cursor += 1
	if _cursor + 1 >= samples.size():
		_body.visible = false
		_label.visible = false
		return
	var a: Dictionary = samples[_cursor]
	var b: Dictionary = samples[_cursor + 1]
	var span: float = maxf(float(b["t"]) - float(a["t"]), 0.001)
	var t: float = clampf((time - float(a["t"])) / span, 0.0, 1.0)
	var x: float = lerpf(float(a["x"]), float(b["x"]), t)
	var y: float = lerpf(float(a["y"]), float(b["y"]), t)
	var r: float = lerpf(float(a["r"]), float(b["r"]), t)
	global_position = Vector2(x, y)
	rotation = r
	_body.visible = true
	_label.visible = true

## Split time of the ghost at a checkpoint distance, for the HUD delta.
func time_at(x_px: float) -> float:
	for s: Dictionary in samples:
		if float(s["x"]) >= x_px:
			return float(s["t"])
	return best_time
