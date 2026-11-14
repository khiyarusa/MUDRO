class_name WinchSystem
extends Node2D
## Physical winch recovery.
##
## The cable is a tension constraint, not a teleport: while the rope is longer than
## its paid-out length it applies a spring-damper force through the vehicle's
## physics state, bounded by the winch's rated pull. The cable can not pull harder
## than that, and it never moves the car by assignment.
##
## Anchors are real solid obstacles from the stage when one is in range; otherwise a
## ground stake is driven into the terrain ahead and the available force is reduced,
## because a stake is not a tree.

const MIN_LENGTH: float = 3.0
const STIFFNESS_PER_M: float = 2.4
const DAMPING: float = 2600.0
const STAKE_FORCE_FACTOR: float = 0.65

var vehicle: VehicleBody
var terrain: TerrainBuilder
var stage: StageDef

var attached: bool = false
var anchor: Vector2 = Vector2.ZERO
var rope_length: float = 18.0
var max_length: float = 18.0
var min_length: float = MIN_LENGTH
var max_force: float = 16000.0
var reel_speed: float = 1.4
var tension_n: float = 0.0
var anchor_kind: String = ""

var _line: Line2D
var _hook: Sprite2D

func setup(v: VehicleBody, t: TerrainBuilder, s: StageDef) -> void:
	vehicle = v
	terrain = t
	stage = s
	z_index = 8
	if v != null and v.definition != null:
		max_force = v.definition.winch_force_n
		max_length = v.definition.winch_rope_m
		rope_length = max_length
		reel_speed = v.definition.winch_speed_mps
	_line = Line2D.new()
	_line.width = 3.0
	_line.default_color = Color(0.16, 0.17, 0.18, 0.95)
	_line.visible = false
	_line.z_index = 9
	add_child(_line)
	_hook = Sprite2D.new()
	_hook.visible = false
	_hook.z_index = 10
	add_child(_hook)

func available() -> bool:
	return vehicle != null and vehicle.definition != null and vehicle.definition.has_winch

## Returns a message key describing what happened.
func toggle() -> String:
	if not available():
		return "winch_unavailable"
	if attached:
		detach()
		return "winch_detached"
	return attach()

func attach() -> String:
	var found: Dictionary = _find_anchor()
	if found.is_empty():
		return "winch_no_anchor"
	anchor = found["point"] as Vector2
	anchor_kind = String(found.get("kind", "obstacle"))
	var distance: float = vehicle.global_position.distance_to(anchor) / Units.PPM
	rope_length = clampf(distance + 1.5, MIN_LENGTH, max_length)
	attached = true
	_line.visible = true
	_hook.visible = true
	_hook.position = anchor
	AudioDirector.play("winch_strain", -10.0)
	return "winch_attached_" + anchor_kind

func detach() -> void:
	attached = false
	tension_n = 0.0
	if vehicle != null:
		vehicle.external_force = Vector2.ZERO
	if _line != null:
		_line.visible = false
	if _hook != null:
		_hook.visible = false
	AudioDirector.play("ui_back", -12.0)

func tension_kn() -> float:
	return tension_n / 1000.0

func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	if not attached:
		return
	# Reeling in shortens the paid-out cable; slack reels out automatically so the
	# car is never dragged by a rope that has already reached its anchor.
	var distance: float = vehicle.global_position.distance_to(anchor) / Units.PPM
	if distance < rope_length - 0.15:
		rope_length = maxf(min_length, minf(rope_length, distance + 0.6))
	else:
		rope_length = maxf(min_length, rope_length - reel_speed * delta)
	rope_length = clampf(rope_length, min_length, max_length)

	if distance > rope_length:
		var stretch: float = distance - rope_length
		var to_anchor: Vector2 = anchor - vehicle.global_position
		if to_anchor.length() < 1.0:
			return
		var dir: Vector2 = to_anchor.normalized()
		var v_along: float = vehicle.linear_velocity.dot(dir) / Units.PPM
		var force_n: float = max_force * STIFFNESS_PER_M * stretch - DAMPING * v_along
		if anchor_kind == "stake":
			force_n *= STAKE_FORCE_FACTOR
		force_n = clampf(force_n, 0.0, max_force)
		tension_n = force_n
		vehicle.external_force = dir * force_n * Units.PPM
		if force_n > max_force * 0.92:
			AudioDirector.play("suspension_bottom", -20.0, 0.8)
	else:
		tension_n = 0.0
		vehicle.external_force = Vector2.ZERO

	_draw_cable()

func _draw_cable() -> void:
	if _line == null:
		return
	var a: Vector2 = vehicle.global_position + Vector2(vehicle.definition.length_m * 0.4 * Units.PPM, -0.2 * Units.PPM)
	var b: Vector2 = anchor
	var dist: float = a.distance_to(b)
	var sag: float = clampf((rope_length * Units.PPM - dist) * 0.20, 0.0, 120.0)
	_line.clear_points()
	var steps: int = 10
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		p.y += sin(t * PI) * sag
		_line.add_point(p - position)
	_line.default_color = Color(0.15, 0.16, 0.17, 0.95).lerp(Color(0.95, 0.66, 0.28, 0.95), clampf(tension_n / maxf(max_force, 1.0), 0.0, 1.0))
	_line.width = 3.0 + clampf(tension_n / maxf(max_force, 1.0), 0.0, 1.0) * 1.5

func _find_anchor() -> Dictionary:
	if terrain == null or vehicle == null:
		return {}
	var origin: Vector2 = vehicle.global_position
	var best: Dictionary = {}
	var best_score: float = INF
	var forward: Vector2 = vehicle.global_transform.x.normalized()
	if stage != null:
		for entry: Dictionary in stage.obstacles:
			if not bool(entry.get("solid", true)):
				continue
			var x_m: float = float(entry.get("x", 0.0))
			var y_m: float = terrain.elevation_m(x_m) + float(entry.get("y_offset", 0.0))
			var point: Vector2 = Vector2(x_m * Units.PPM, -y_m * Units.PPM)
			var d: float = origin.distance_to(point) / Units.PPM
			if d < 1.2 or d > max_length:
				continue
			# Prefer anchors ahead of the car and uphill: a winch pulls you out, it
			# does not drag you back down the trail.
			var dir: Vector2 = (point - origin).normalized()
			var ahead: float = dir.dot(forward)
			var uphill: float = -dir.y
			var score: float = d * 0.4 - ahead * 6.0 - uphill * 5.0
			if score < best_score:
				best_score = score
				best = {"point": point, "kind": "obstacle"}
	if not best.is_empty():
		return best
	# Ground stake: ahead and up the slope, snapped to the terrain.
	var stake: Vector2 = origin + (forward + Vector2(0, -0.6)).normalized() * minf(max_length * 0.55, 9.0) * Units.PPM
	var x_px: float = clampf(stake.x, 0.0, terrain.world_length)
	var y_px: float = terrain.height_at_world(x_px)
	return {"point": Vector2(x_px, y_px - 4.0), "kind": "stake"}
