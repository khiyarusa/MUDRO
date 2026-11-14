class_name TransmissionProfile
extends Resource
## Per-vehicle transmission specification. This is the data that makes each car's
## driveline its own machine: architecture, ratios, final drive, clutch type,
## shift time, synchroniser strength, torque capacity, transfer case and the
## automatic shift schedule.
##
## Nothing in the simulation branches on a vehicle id: it branches on this data.

enum Kind { MANUAL_H, MANUAL_SEQ, AUTOMATIC }

## H-pattern gate geometry, normalised to the selector panel (0..1, y down).
const GATE_TOP: float = 0.28
const GATE_BOTTOM: float = 0.72
const GATE_NEUTRAL: float = 0.5
const GATE_X_FIRST: float = 0.16
const GATE_X_LAST: float = 0.84
const GATE_COMMIT_RADIUS: float = 0.105

@export_group("Identity")
@export var id: String = "h5_manual"
@export var name_fa: String = "دستی پنج‌سرعته H"
@export var name_en: String = "5-speed H-pattern manual"
@export var kind: Kind = Kind.MANUAL_H
@export_multiline var notes_fa: String = ""
@export_multiline var notes_en: String = ""

@export_group("Ratios")
@export var ratios: PackedFloat32Array = PackedFloat32Array([3.9, 2.4, 1.7, 1.28, 1.0])
@export var reverse_ratio: float = 3.6
@export var final_drive: float = 4.1
@export var efficiency: float = 0.9
@export var has_reverse: bool = true

@export_group("Shift behaviour")
@export var shift_time: float = 0.22
## 0 = crash box (no synchros, needs matching revs), 1 = fully synchronised.
@export var synchro: float = 1.0
@export var requires_clutch: bool = true
@export var clutch_type: String = "single_plate"
@export var max_torque_nm: float = 480.0
@export var durability: float = 1.0
@export var overrev_margin: float = 0.04

@export_group("Torque converter")
@export var converter_stall_mult: float = 1.0
@export var converter_lock_rpm: float = 1250.0

@export_group("Automatic schedule")
@export var auto_upshift_fraction: float = 0.80
@export var auto_downshift_fraction: float = 0.34
@export var kickdown_throttle: float = 0.86
@export var kickdown_rpm_fraction: float = 0.62
@export var kickdown_hold_s: float = 1.1
@export var slope_downshift_deg: float = 9.0
@export var load_upshift_bias: float = 0.14
@export var launch_gear: int = 1
@export var ranges: PackedStringArray = PackedStringArray(["P", "R", "N", "D"])

func gear_count() -> int:
	return ratios.size()

func is_manual() -> bool:
	return kind == Kind.MANUAL_H or kind == Kind.MANUAL_SEQ

func is_automatic() -> bool:
	return kind == Kind.AUTOMATIC

func is_h_pattern() -> bool:
	return kind == Kind.MANUAL_H

func uses_converter() -> bool:
	return clutch_type == "torque_converter" or converter_stall_mult > 1.0001

func ratio_for(gear: int) -> float:
	if gear > 0 and gear <= ratios.size():
		return ratios[gear - 1]
	if gear == -1 and has_reverse:
		return -reverse_ratio
	return 0.0

func total_ratio(gear: int, transfer_ratio: float = 1.0) -> float:
	return ratio_for(gear) * final_drive * transfer_ratio

func top_speed_mps(wheel_radius_m: float, max_rpm: float, transfer_ratio: float = 1.0) -> float:
	var ratio: float = total_ratio(gear_count(), transfer_ratio)
	if ratio <= 0.0 or wheel_radius_m <= 0.0:
		return 0.0
	return Units.omega_from_rpm(max_rpm) * wheel_radius_m / ratio

func label(lang: String) -> String:
	return name_fa if lang == "fa" else name_en

func note(lang: String) -> String:
	return notes_fa if lang == "fa" else notes_en

# -------------------------------------------------------------- H-pattern ---

## Number of vertical gate columns: one per pair of forward gears, plus a reverse
## column when the car has reverse.
func gate_column_count() -> int:
	var forward: int = int(ceil(float(maxi(gear_count(), 1)) / 2.0))
	return forward + (1 if has_reverse else 0)

func gate_x(column: int) -> float:
	var columns: int = maxi(gate_column_count(), 1)
	if columns <= 1:
		return 0.5
	return lerpf(GATE_X_FIRST, GATE_X_LAST, float(column) / float(columns - 1))

func gate_column_of_gear(gear: int) -> int:
	if gear <= 0:
		return -1
	if gear > gear_count():
		return gate_column_count() - 1
	return int((gear - 1) / 2)

## Normalised node position for a gear. Reverse gets the last column, bottom node.
func gate_node(gear: int) -> Vector2:
	if gear == 0:
		return Vector2(0.5, GATE_NEUTRAL)
	if gear == -1:
		return Vector2(gate_x(gate_column_count() - 1), GATE_BOTTOM)
	var column: int = gate_column_of_gear(gear)
	var row: int = (gear - 1) % 2
	return Vector2(gate_x(column), GATE_TOP if row == 0 else GATE_BOTTOM)

func column_nodes(column: int) -> Array[int]:
	var out: Array[int] = []
	for g: int in range(1, gear_count() + 1):
		if gate_column_of_gear(g) == column:
			out.append(g)
	if has_reverse and column == gate_column_count() - 1:
		out.append(-1)
	return out

## Every legal path segment as [from, to] pairs: the neutral rail plus one vertical
## per occupied half-column. The lever is projected onto these, which is what makes
## an impossible H-pattern move impossible.
func gate_segments() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var columns: int = gate_column_count()
	out.append(PackedVector2Array([Vector2(gate_x(0), GATE_NEUTRAL), Vector2(gate_x(columns - 1), GATE_NEUTRAL)]))
	for c: int in range(columns):
		var nodes: Array[int] = column_nodes(c)
		for g: int in nodes:
			var node: Vector2 = gate_node(g)
			var bottom: bool = node.y > GATE_NEUTRAL
			var end_y: float = GATE_BOTTOM if bottom else GATE_TOP
			out.append(PackedVector2Array([Vector2(gate_x(c), GATE_NEUTRAL), Vector2(gate_x(c), end_y)]))
	return out

## Project an arbitrary knob position onto the legal gate. Returns
## { "point": Vector2, "on_neutral": bool, "column": int, "gear": int }.
## `gear` is 0 while the lever is travelling and only becomes a real gear when the
## knob is close enough to that gear's node.
func gate_project(p: Vector2) -> Dictionary:
	var best_dist: float = INF
	var best_point: Vector2 = Vector2(0.5, GATE_NEUTRAL)
	var best_segment: int = 0
	var segments: Array[PackedVector2Array] = gate_segments()
	for i: int in range(segments.size()):
		var seg: PackedVector2Array = segments[i]
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var ab: Vector2 = b - a
		var t: float = 0.0
		if ab.length_squared() > 0.000001:
			t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q: Vector2 = a + ab * t
		var d: float = p.distance_to(q)
		if d < best_dist:
			best_dist = d
			best_point = q
			best_segment = i
	var on_neutral: bool = best_segment == 0
	var column: int = -1
	var gear: int = 0
	if not on_neutral:
		column = _column_at_x(best_point.x)
		var nearest: int = 0
		var nearest_d: float = INF
		for g: int in column_nodes(column):
			var node: Vector2 = gate_node(g)
			var d: float = best_point.distance_to(node)
			if d < nearest_d:
				nearest_d = d
				nearest = g
		if nearest != 0 and nearest_d <= GATE_COMMIT_RADIUS:
			gear = nearest
	return {
		"point": best_point,
		"on_neutral": on_neutral,
		"column": column,
		"gear": gear,
		"distance": best_dist,
	}

func _column_at_x(x: float) -> int:
	var columns: int = maxi(gate_column_count(), 1)
	var best: int = 0
	var best_d: float = INF
	for c: int in range(columns):
		var d: float = absf(gate_x(c) - x)
		if d < best_d:
			best_d = d
			best = c
	return best

# ---------------------------------------------------------------------------

func describe() -> String:
	var parts: PackedStringArray = []
	for r: float in ratios:
		parts.append("%.2f" % r)
	return "%s · %d-speed [%s] final %.2f" % [name_en, ratios.size(), ", ".join(parts), final_drive]

func duplicate_profile() -> TransmissionProfile:
	return duplicate(true) as TransmissionProfile
