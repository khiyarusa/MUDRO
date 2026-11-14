class_name VehicleBody
extends RigidBody2D
## The physical vehicle. A RigidBody2D chassis with two independent axle
## assemblies. Every force is computed in SI units and converted once at the
## boundary (see Units). Nothing here teleports the body or fakes a speed value:
## acceleration comes from engine torque, tyre forces, gravity and resistance.

signal gear_changed(gear: int)
signal shift_rejected(reason: String, gear: int)
signal transfer_changed(mode: String)
signal diff_changed(mode: String)
signal engine_stalled
signal engine_started
signal impact(strength: float, world_point: Vector2, kind: String)
signal landed(axle: int, strength: float)
signal shifted(direction: int)

const TERRAIN_LAYER: int = 2
const OBSTACLE_LAYER: int = 4
const TERRAIN_MASK: int = TERRAIN_LAYER | OBSTACLE_LAYER

var definition: VehicleDef
var engine: EngineState
var gearbox: GearboxState
var clutch: ClutchState
var axles: Array[WheelAxis] = []
var damage: DamageModel = DamageModel.new()

var throttle_input: float = 0.0
var brake_input: float = 0.0
var handbrake_input: float = 0.0
## Clutch pedal release position: 1.0 = foot off (engaged), 0.0 = fully pressed.
## The public input contract uses the opposite (pressed) convention; conversion
## happens only in set_input_state().
var clutch_input: float = 1.0
var controls_locked: bool = false

## The shared input contract. Every driver source writes here; the body only reads.
var input_state: VehicleInputState = VehicleInputState.new()

var auto_clutch: bool = true
var auto_transmission: bool = false
var manual_clutch_enabled: bool = false

## Runtime driveline configuration (garage / route briefing).
var diff_mode: String = "open"
## Weather and surface conditioning, applied without touching the authored data.
var surface_grip_scale: float = 1.0
var surface_rr_scale: float = 1.0

var forward_speed: float = 0.0
var lateral_speed: float = 0.0
var airtime: float = 0.0
var wheels_on_ground: int = 0
var last_impact_at: float = -10.0
var engine_running: bool = true
var _last_gear_seen: int = 0

var _prev_velocity: Vector2 = Vector2.ZERO
## External force in engine units (px·kg/s²), e.g. a winch cable. Cleared by the
## system that owns it every physics step; never a permanent invisible assist.
var external_force: Vector2 = Vector2.ZERO
var _surface_db: Dictionary = {}
var _was_airborne: bool = false
var _air_peak: float = 0.0
var _time: float = 0.0

var telemetry: Dictionary = {}

func _ready() -> void:
	collision_layer = 1
	collision_mask = TERRAIN_MASK
	contact_monitor = true
	max_contacts_reported = 4
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2.ZERO
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	can_sleep = false

## Build the whole vehicle from a data definition.
func setup(def: VehicleDef, surfaces: Dictionary = {}) -> void:
	definition = def
	_surface_db = surfaces
	mass = def.mass_kg
	inertia = def.mass_kg * (pow(def.length_m, 2.0) + pow(def.height_m, 2.0)) / 12.0 * Units.PPM * Units.PPM * def.inertia_scale
	angular_damp = 0.35
	linear_damp = 0.0

	var mat := PhysicsMaterial.new()
	mat.friction = 0.35
	mat.bounce = 0.03
	physics_material_override = mat

	engine = EngineState.new(def.engine)
	var fitted: TransmissionProfile = def.stock_transmission_profile()
	gearbox = GearboxState.new(fitted)
	gearbox.engine_redline = def.engine.redline_rpm
	gearbox.wheel_radius = def.tire_rear.radius_m if def.tire_rear != null else 0.4
	if def.has_transfer_case():
		gearbox.set_transfer_modes(def.transfer_ids, def.transfer_ratios)
		var wanted: String = def.active_transfer if def.active_transfer != "" else def.default_transfer
		if wanted == "":
			wanted = def.transfer_ids[0]
		var idx: int = def.transfer_ids.find(wanted)
		if idx >= 0:
			gearbox.transfer_index = idx
	gearbox.auto_mode = gearbox.profile != null and gearbox.profile.is_automatic()
	auto_transmission = gearbox.auto_mode
	_last_gear_seen = gearbox.gear

	diff_mode = def.active_diff if def.active_diff != "" else def.default_diff
	if def.diff_modes.size() > 0 and not def.diff_modes.has(diff_mode):
		diff_mode = def.diff_modes[0]

	clutch = ClutchState.new()
	clutch.capacity = def.clutch_capacity
	clutch.stiffness = def.clutch_stiffness
	clutch.manual_mode = manual_clutch_enabled
	if gearbox.profile != null and gearbox.profile.requires_clutch and not auto_clutch:
		manual_clutch_enabled = true
		clutch.manual_mode = true

	axles = [WheelAxis.new(0, def.tire_front), WheelAxis.new(1, def.tire_rear)]

	_build_collision()
	var visual := VehicleVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup(self)

## Local chassis outline in px (Godot 2D: +y is down).
func body_polygon_px() -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if definition == null:
		return out
	if definition.body_polygon_m.is_empty():
		out.append(Vector2(-definition.length_m * 0.5, -definition.height_m * 0.5) * Units.PPM)
		out.append(Vector2(definition.length_m * 0.5, -definition.height_m * 0.5) * Units.PPM)
		out.append(Vector2(definition.length_m * 0.5, definition.height_m * 0.5) * Units.PPM)
		out.append(Vector2(-definition.length_m * 0.5, definition.height_m * 0.5) * Units.PPM)
		return out
	for p: Vector2 in definition.body_polygon_m:
		out.append(p * Units.PPM)
	return out

func _build_collision() -> void:
	var pts: PackedVector2Array = body_polygon_px()
	var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
	if hull.size() > 2:
		hull.remove_at(hull.size() - 1)
	var shape := ConvexPolygonShape2D.new()
	shape.points = hull if hull.size() >= 3 else pts
	var col := CollisionShape2D.new()
	col.name = "ChassisShape"
	col.shape = shape
	add_child(col)

func mount_local(axle: int) -> Vector2:
	if definition == null:
		return Vector2.ZERO
	var x: float = definition.wheelbase_m * 0.5 * (1.0 if axle == 0 else -1.0)
	var y: float = definition.com_height_m - definition.suspension.rest_length_m
	return Vector2(x, y) * Units.PPM

func _physics_process(delta: float) -> void:
	if gearbox == null or engine == null:
		return
	if auto_transmission:
		var load_frac: float = clampf(engine.output_torque() / maxf(engine.config.peak_torque(), 1.0), 0.0, 1.0)
		var slip: float = absf(axles[1].slip_ratio) if axles.size() > 1 else 0.0
		gearbox.auto_update(delta, engine.rpm, throttle_input, forward_speed, load_frac, grade_deg(), slip)
	else:
		gearbox.update(delta)
	if gearbox.gear != _last_gear_seen:
		_last_gear_seen = gearbox.gear
		gear_changed.emit(gearbox.gear)
		shifted.emit(gearbox.last_shift_dir)

## Positive when the chassis is climbing in its forward direction, in degrees.
func grade_deg() -> float:
	var forward: Vector2 = global_transform.x.normalized()
	return -rad_to_deg(asin(clampf(forward.y, -1.0, 1.0)))

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if definition == null or engine == null:
		return
	var dt: float = state.step
	if dt <= 0.0:
		return
	_time += dt

	engine.update(dt, 0.0 if controls_locked else throttle_input)
	clutch.manual_mode = manual_clutch_enabled or not auto_clutch
	var xf: Transform2D = state.transform
	var forward: Vector2 = xf.x.normalized()
	var down: Vector2 = xf.y.normalized()

	var vel: Vector2 = state.linear_velocity
	forward_speed = vel.dot(forward) / Units.PPM
	lateral_speed = vel.dot(down) / Units.PPM

	_apply_aero(state, vel)
	_apply_external(state)
	_update_axles(state, dt, xf, forward, down, vel)
	_update_drivetrain(dt)
	_update_damage(state, dt, vel)
	_update_telemetry(state)

	if airtime > 0.25 and wheels_on_ground > 0:
		_was_airborne = false
	_prev_velocity = state.linear_velocity

func _apply_aero(state: PhysicsDirectBodyState2D, vel: Vector2) -> void:
	var v_mps: Vector2 = vel / Units.PPM
	var speed: float = v_mps.length()
	if speed < 0.4:
		return
	var drag_n: float = 0.5 * Units.AIR_DENSITY * definition.drag_cd * definition.frontal_area_m2 * speed * speed
	var force: Vector2 = -v_mps.normalized() * drag_n * Units.PPM
	state.apply_central_force(force)

## Winch cable, recovery sling or any other legitimate external load. Applying it
## through the physics state keeps the vehicle a rigid body: a winch pulls, it does
## not teleport.
func _apply_external(state: PhysicsDirectBodyState2D) -> void:
	if external_force.length_squared() > 0.0001:
		state.apply_central_force(external_force)

func _update_axles(state: PhysicsDirectBodyState2D, dt: float, xf: Transform2D,
		forward: Vector2, down: Vector2, vel: Vector2) -> void:
	wheels_on_ground = 0
	var susp: SuspensionConfig = definition.suspension
	var space: PhysicsDirectSpaceState2D = state.get_space_state()
	var any_contact: bool = false
	var max_compression: float = 0.0

	for i: int in range(axles.size()):
		var axle: WheelAxis = axles[i]
		var tire: TireConfig = definition.tire_for(i)
		axle.config = tire
		var mount_l: Vector2 = mount_local(i)
		var mount_w: Vector2 = xf * mount_l
		var radius: float = tire.radius_m
		var ray_len: float = (susp.rest_length_m + susp.droop_m + radius + 0.02) * Units.PPM
		var query := PhysicsRayQueryParameters2D.create(mount_w, mount_w + down * ray_len, TERRAIN_MASK, [get_rid()])
		query.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(query)

		if hit.is_empty():
			axle.in_contact = false
			axle.normal_load = 0.0
			axle.compression = 0.0
			axle.tire_force = 0.0
			axle.slip_ratio = 0.0
			axle.hub_local = mount_l + Vector2(0.0, (susp.rest_length_m + susp.droop_m * 0.5) * Units.PPM)
			axle.hub_world = xf * axle.hub_local
			continue

		wheels_on_ground += 1
		any_contact = true
		var contact: Vector2 = hit["position"]
		var normal: Vector2 = hit["normal"]
		var dist: float = mount_w.distance_to(contact)
		var hub_dist_m: float = dist / Units.PPM - radius
		var compression: float = clampf(susp.rest_length_m - hub_dist_m, -susp.droop_m, susp.travel_m + 0.15)
		axle.compression = compression
		axle.contact_point = contact
		axle.contact_normal = normal
		axle.in_contact = true
		# Hub position follows the suspension axis, not the contact point.
		var hub_dist_px: float = (susp.rest_length_m - compression) * Units.PPM
		axle.hub_local = mount_l + down * hub_dist_px
		axle.hub_world = xf * axle.hub_local

		# --- suspension force (spring + damper + bump stop) ---
		var mount_vel: Vector2 = _point_velocity(state, mount_w)
		var comp_vel: float = mount_vel.dot(down) / Units.PPM
		axle.compression_velocity = comp_vel
		var spring: float = susp.spring_at(i)
		var damper: float = susp.damper_at(i, comp_vel) * damage.damping_multiplier(i)
		var f_spring: float = 0.0
		if compression > 0.0:
			f_spring = spring * compression + damper * comp_vel
			if compression > susp.travel_m:
				var over: float = compression - susp.travel_m
				f_spring += susp.bump_stop_rate * pow(over, susp.bump_stop_progress)
				axle.bottomed_out = true
			else:
				axle.bottomed_out = false
			f_spring = maxf(f_spring, 0.0)
		else:
			axle.bottomed_out = false
		max_compression = maxf(max_compression, compression)
		axle.normal_load = maxf(f_spring, 0.0)
		if f_spring > 0.0:
			state.apply_force(normal * f_spring * Units.PPM, mount_w - xf.origin)

		# --- tyre longitudinal force ---
		var tangent: Vector2 = Vector2(-normal.y, normal.x)
		if tangent.dot(forward) < 0.0:
			tangent = -tangent
		var contact_vel: Vector2 = _point_velocity(state, contact)
		var ground_speed: float = contact_vel.dot(tangent) / Units.PPM
		axle.update_slip(ground_speed)
		axle.surface = _surface_at(contact)
		var grip_mult: float = damage.grip_multiplier(i) * diff_grip_multiplier(i) * surface_grip_scale
		var peak: float = (axle.surface.grip_peak if axle.surface != null else 0.8) * grip_mult
		var slide_grip: float = (axle.surface.grip_slide if axle.surface != null else 0.62) * grip_mult
		var f_long: float = axle.compute_force(peak, slide_grip)
		if f_long != 0.0:
			state.apply_force(tangent * f_long * Units.PPM, contact - xf.origin)

		# --- rolling resistance (fades as the tyre scrubs: a spinning wheel must not
		# also drag like a rolling one) ---
		var crr: float = tire.rolling_resistance
		if axle.surface != null:
			crr += axle.surface.rolling_resistance
		crr *= surface_rr_scale
		var roll_scale: float = 1.0 - clampf(absf(axle.slip_ratio), 0.0, 1.0)
		var f_rr: float = crr * axle.normal_load * clampf(ground_speed / 0.6, -1.0, 1.0) * roll_scale
		if absf(f_rr) > 0.01:
			state.apply_force(-tangent * f_rr * Units.PPM, contact - xf.origin)

	if any_contact:
		if _was_airborne or airtime > 0.12:
			var axle_idx: int = 0 if axles[0].in_contact else 1
			var strength: float = clampf(_air_peak / 12.0, 0.0, 1.5)
			landed.emit(axle_idx, strength)
			_was_airborne = false
			_air_peak = 0.0
		airtime = 0.0
	else:
		airtime += dt
		_was_airborne = true
		_air_peak = maxf(_air_peak, maxf(0.0, vel_y_local(state)))

func vel_y_local(state: PhysicsDirectBodyState2D) -> float:
	return state.linear_velocity.dot(state.transform.y.normalized()) / Units.PPM

func _point_velocity(state: PhysicsDirectBodyState2D, world_point: Vector2) -> Vector2:
	var r: Vector2 = world_point - state.transform.origin
	return state.linear_velocity + Vector2(-state.angular_velocity * r.y, state.angular_velocity * r.x)

func _surface_at(point: Vector2) -> SurfaceProfile:
	var probe: Object = get_meta("surface_probe", null)
	if probe != null and probe.has_method("surface_at_world"):
		return probe.call("surface_at_world", point)
	if _surface_db.has("default"):
		return _surface_db["default"] as SurfaceProfile
	return null

func attach_surface_probe(probe: Node) -> void:
	set_meta("surface_probe", probe)

func _update_drivetrain(dt: float) -> void:
	var driven_omega: float = 0.0
	var driven_weight: float = 0.0
	for i: int in range(axles.size()):
		if axle_live(i):
			# A wheel in the air must not dictate crank speed: weight by contact.
			var w: float = 1.0 if axles[i].in_contact else 0.12
			driven_omega += axles[i].omega * w
			driven_weight += w
	if driven_weight > 0.0:
		driven_omega /= driven_weight

	# The transfer case multiplies the whole driveline, so the same engine speed
	# means a lower road speed in 4L. That is the point of a low range.
	var ratio: float = gearbox.total_ratio()
	var wheel_rpm: float = Units.rpm_from_omega(driven_omega)
	var driveline_rpm: float = wheel_rpm * ratio

	var pedal_pressed: float = clampf(1.0 - clutch_input, 0.0, 1.0)
	clutch.capacity = definition.clutch_capacity
	clutch.update(dt, pedal_pressed, gearbox.is_shifting(), engine.rpm, driveline_rpm,
			throttle_input, forward_speed)
	if ratio == 0.0:
		clutch.engagement = move_toward(clutch.engagement, 0.0, dt * 8.0)
		clutch.pedal = 1.0 - clutch.engagement

	var shift_interlock: bool = gearbox.is_shifting() or engine.starter_timer > 0.0
	if engine.starter_timer > 0.0:
		# Starter interlock: cranking always happens with the clutch open, even in
		# full-manual mode, otherwise the engine is dragged to a stop by the wheels.
		clutch.engagement = 0.0
	elif gearbox.is_shifting() and not clutch.manual_mode:
		# Assisted shifts open the clutch automatically. In full manual mode the pedal
		# is the player's responsibility, and a shift without it is refused before it
		# ever reaches this function.
		clutch.engagement = 0.0

	# Clutch assist: slip the plates rather than let a beginner stall while pulling
	# away or crawling. It never adds torque, it only disengages a little.
	if auto_clutch and clutch.manual_mode and engine.running and absf(forward_speed) < 1.2:
		if engine.rpm < engine.config.stall_rpm * 1.55 and clutch.engagement > 0.30:
			clutch.engagement = move_toward(clutch.engagement, 0.20, dt * 5.0)

	# Friction clutch with a lock-up state. A stiff spring model oscillates at
	# 120 Hz and lets the engine scream while the wheels crawl; instead the clutch
	# either transmits crank torque (locked) or slips at its torque capacity.
	var slip: float = engine.rpm - driveline_rpm
	var capacity_now: float = clutch.capacity * clutch.engagement
	var can_lock: bool = ratio != 0.0 and clutch.engagement > 0.55 and not shift_interlock and engine.running
	var clutch_torque: float = 0.0

	if can_lock and absf(slip) < 140.0:
		clutch.locked = true
		engine.rpm = clampf(driveline_rpm, 0.0, engine.config.redline_rpm)
		var crank: float = engine.output_torque() * damage.torque_multiplier()
		crank += engine.idle_torque()
		crank -= engine.friction_torque()
		if engine.throttle < 0.12:
			crank -= engine.braking_torque()
		clutch_torque = crank
		clutch.transmitted_torque = clutch_torque
	else:
		clutch.locked = false
		clutch_torque = clampf(slip * clutch.stiffness, -capacity_now, capacity_now)
		clutch.transmitted_torque = clutch_torque
		var net_engine: float = engine.output_torque() * damage.torque_multiplier() - clutch_torque
		net_engine += engine.idle_torque()
		net_engine -= engine.friction_torque()
		engine.integrate(dt, net_engine)

	if engine.running and engine.rpm < engine.config.stall_rpm and clutch.engagement > 0.35:
		if engine.config.stall_enabled and manual_clutch_enabled:
			engine.stall()
			engine_running = false
			engine_stalled.emit()
	engine_running = engine.running

	# Torque converter: multiplies crank torque at low driveline speed and fades to
	# 1:1 as the turbine catches up. It is not extra power, it is a fluid coupling
	# and the clutch capacity still bounds what reaches the wheels.
	var converter: float = 1.0
	if gearbox.profile != null and gearbox.profile.uses_converter() and ratio != 0.0 and auto_transmission:
		var lock_rpm: float = maxf(gearbox.profile.converter_lock_rpm, 200.0)
		converter = lerpf(maxf(gearbox.profile.converter_stall_mult, 1.0), 1.0,
			clampf(absf(driveline_rpm) / lock_rpm, 0.0, 1.0))

	var eff: float = gearbox.profile.efficiency if gearbox.profile != null else 0.9
	var parked: bool = gearbox.profile != null and gearbox.profile.is_automatic() and gearbox.parking_lock()
	var transfer_front: bool = gearbox.transfer_drives_front()
	for i: int in range(axles.size()):
		var axle: WheelAxis = axles[i]
		var share: float = definition.axle_torque_share(i, transfer_front)
		var drive: float = 0.0
		if share > 0.0 and ratio != 0.0:
			drive = clutch_torque * converter * ratio * eff * share
		var brake: float = 0.0
		if brake_input > 0.001:
			brake = (definition.brake_torque_front if i == 0 else definition.brake_torque_rear) * brake_input
		if i == 1 and handbrake_input > 0.001:
			brake += definition.handbrake_torque * handbrake_input
		if parked:
			brake += definition.handbrake_torque * 1.6
		axle.integrate(dt, drive, brake)

	_apply_differential()

## A locked centre differential forces both axles to the same angular speed; a
## limited-slip unit only pulls them together. In this side-view model the two
## physical axles stand in for front and rear, which is exactly the pair a centre
## diff couples.
func _apply_differential() -> void:
	if axles.size() < 2:
		return
	var locked: bool = diff_mode == "locked"
	var limited: bool = diff_mode == "lsd"
	if not (locked or limited):
		return
	if not (axle_live(0) and axle_live(1)):
		return
	var w0: float = 1.0 if axles[0].in_contact else 0.25
	var w1: float = 1.0 if axles[1].in_contact else 0.25
	var avg: float = (axles[0].omega * w0 + axles[1].omega * w1) / (w0 + w1)
	var k: float = 1.0 if locked else 0.35
	axles[0].omega = lerpf(axles[0].omega, avg, k)
	axles[1].omega = lerpf(axles[1].omega, avg, k)

## Extra effective grip from a locked / limited-slip axle in the 2D model. When
## both axles are driven the speed coupling already does the work, so this only
## applies to a single driven axle, where the differential would otherwise lose
## everything to the spinning side.
func diff_grip_multiplier(axle: int) -> float:
	if not axle_live(axle):
		return 1.0
	if axle_live(0) and axle_live(1):
		return 1.0
	if diff_mode == "locked":
		return 1.07
	if diff_mode == "lsd":
		return 1.035
	return 1.0

func axle_live(axle: int) -> bool:
	if definition == null or gearbox == null:
		return false
	return definition.axle_torque_share(axle, gearbox.transfer_drives_front()) > 0.0

func _update_damage(state: PhysicsDirectBodyState2D, dt: float, vel: Vector2) -> void:
	var dv: float = (vel - _prev_velocity).length() / Units.PPM
	if dv > 1.8 and (_time - last_impact_at) > 0.18:
		last_impact_at = _time
		var severity: float = clampf((dv - 1.8) / maxf(definition.impact_tolerance, 1.0), 0.0, 1.3)
		var axle_hint: int = 0 if vel.dot(state.transform.y.normalized()) > 0.0 else 1
		if severity > 0.04:
			damage.apply_impact(severity, axle_hint, definition.durability)
			var kind: String = "hard" if severity > 0.45 else "soft"
			impact.emit(severity, state.transform.origin, kind)
	if engine != null and not engine.running:
		engine_running = false

func _update_telemetry(state: PhysicsDirectBodyState2D) -> void:
	telemetry = {
		"rpm": engine.rpm if engine != null else 0.0,
		"gear": gearbox.gear if gearbox != null else 0,
		"speed_kmh": absf(Units.px2kmh(state.linear_velocity.dot(state.transform.x.normalized()))),
		"forward_speed": forward_speed,
		"throttle": throttle_input,
		"brake": brake_input,
		"clutch": clutch.engagement if clutch != null else 0.0,
		"engine_torque": engine.output_torque() if engine != null else 0.0,
		"engine_running": engine.running if engine != null else false,
		"gear_ratio": gearbox.effective_ratio() if gearbox != null else 0.0,
		"total_ratio": gearbox.total_ratio() if gearbox != null else 0.0,
		"front": {
			"contact": axles[0].in_contact,
			"load": axles[0].normal_load,
			"slip": axles[0].slip_ratio,
			"force": axles[0].tire_force,
			"compression": axles[0].compression,
			"omega": axles[0].omega,
			"surface": axles[0].surface.id if axles[0].surface != null else "",
			"bottomed": axles[0].bottomed_out,
		},
		"rear": {
			"contact": axles[1].in_contact,
			"load": axles[1].normal_load,
			"slip": axles[1].slip_ratio,
			"force": axles[1].tire_force,
			"compression": axles[1].compression,
			"omega": axles[1].omega,
			"surface": axles[1].surface.id if axles[1].surface != null else "",
			"bottomed": axles[1].bottomed_out,
		},
		"airtime": airtime,
		"damage": damage.total_health(),
		"gear_label": gearbox.gear_label() if gearbox != null else "N",
		"clutch_pedal": 1.0 - clutch_input,
		"clutch_engagement": clutch.engagement if clutch != null else 1.0,
		"clutch_locked": clutch.locked if clutch != null else false,
		"shift_reject": gearbox.reject_reason if gearbox != null else "",
		"transfer": gearbox.transfer_id() if gearbox != null else "",
		"transfer_ratio": gearbox.transfer_ratio() if gearbox != null else 1.0,
		"diff": diff_mode,
		"grade_deg": grade_deg(),
		"auto": auto_transmission,
		"range": gearbox.range_id if gearbox != null else "",
		"kickdown": gearbox.is_kickdown() if gearbox != null else false,
		"shifting": gearbox.is_shifting() if gearbox != null else false,
	}

func set_inputs(throttle: float, brake: float, handbrake: float = 0.0, clutch: float = 1.0) -> void:
	throttle_input = clampf(throttle, 0.0, 1.0)
	brake_input = clampf(brake, 0.0, 1.0)
	handbrake_input = clampf(handbrake, 0.0, 1.0)
	clutch_input = clampf(clutch, 0.0, 1.0)

## The only path from a driver source into the car. `clutch` arrives as pedal
## pressure (0 = released, 1 = floor) and is converted once here.
func set_input_state(s: VehicleInputState) -> void:
	if s == null:
		return
	s.sanitize()
	input_state = s
	set_inputs(s.throttle, s.brake, s.handbrake, 1.0 - s.clutch)

## Clutch assist on = the game presses the clutch for you during a shift.
## Assist off = full manual: the pedal must be pressed to the floor first.
func configure_driver(clutch_assist: bool) -> void:
	auto_clutch = clutch_assist
	var requires_clutch: bool = gearbox != null and gearbox.profile != null and gearbox.profile.requires_clutch
	# The pedal is always live; assist only (a) lets a shift through without it and
	# (b) slips the clutch automatically so a beginner cannot stall at the lights.
	manual_clutch_enabled = requires_clutch
	auto_transmission = gearbox != null and gearbox.profile != null and gearbox.profile.is_automatic()
	if clutch != null:
		clutch.manual_mode = manual_clutch_enabled

func clutch_pedal() -> float:
	return 1.0 - clutch_input

## Player-initiated gear change. Returns false with `shift_rejected` emitted when
## the clutch is not fully pressed, the gear would over-rev the engine, or reverse
## is requested while still rolling.
func select_gear(target: int, force: bool = false) -> bool:
	if gearbox == null:
		return false
	var clutch_ok: bool = auto_clutch or clutch.is_fully_pressed()
	if gearbox.profile != null and not gearbox.profile.requires_clutch:
		clutch_ok = true
	if not gearbox.request_gear(target, force, clutch_ok, forward_speed):
		if gearbox.reject_reason != "":
			shift_rejected.emit(gearbox.reject_reason, target)
		return false
	return true

func shift_up() -> void:
	select_gear(gearbox.gear + 1)

func shift_down() -> void:
	select_gear(gearbox.gear - 1)

func set_gear(g: int) -> bool:
	return select_gear(g, true)

func toggle_reverse() -> void:
	set_gear(-1 if gearbox.gear >= 0 else 1)

func set_transfer(mode: String) -> bool:
	if gearbox == null or not gearbox.set_transfer(mode):
		return false
	transfer_changed.emit(gearbox.transfer_id())
	return true

func cycle_transfer() -> String:
	if gearbox == null:
		return ""
	var mode: String = gearbox.cycle_transfer()
	transfer_changed.emit(mode)
	return mode

func set_diff(mode: String) -> bool:
	if definition == null or not definition.diff_modes.has(mode) or mode == diff_mode:
		return false
	diff_mode = mode
	diff_changed.emit(mode)
	return true

func cycle_diff() -> String:
	if definition == null or definition.diff_modes.is_empty():
		return diff_mode
	var idx: int = definition.diff_modes.find(diff_mode)
	diff_mode = definition.diff_modes[(idx + 1) % definition.diff_modes.size()]
	diff_changed.emit(diff_mode)
	return diff_mode

## Weather / surface conditioning without mutating the authored surface profiles.
func apply_surface_conditions(grip_scale: float, rr_scale: float = 1.0) -> void:
	surface_grip_scale = clampf(grip_scale, 0.25, 1.4)
	surface_rr_scale = clampf(rr_scale, 0.5, 2.5)

func restart_engine() -> void:
	if engine != null:
		engine.start()
		engine_running = true
		engine_started.emit()

func speed_kmh() -> float:
	return absf(Units.px2kmh(forward_speed * Units.PPM))

func reset_motion(at: Transform2D) -> void:
	global_transform = at
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	external_force = Vector2.ZERO
	for axle: WheelAxis in axles:
		axle.reset()
	if gearbox != null:
		gearbox.reset(gearbox.gear)
	if engine != null and not engine.running:
		engine.start()

## Snapshot of the driveline for HUD and tests.
func driveline_state() -> Dictionary:
	return {
		"gear": gearbox.gear if gearbox != null else 0,
		"label": gearbox.gear_label() if gearbox != null else "N",
		"ratio": gearbox.total_ratio() if gearbox != null else 0.0,
		"transfer": gearbox.transfer_id() if gearbox != null else "",
		"diff": diff_mode,
		"clutch_pedal": clutch_pedal(),
		"clutch_engagement": clutch.engagement if clutch != null else 1.0,
		"manual_clutch": manual_clutch_enabled,
		"auto": auto_transmission,
		"range": gearbox.range_id if gearbox != null else "",
		"reject": gearbox.reject_reason if gearbox != null else "",
	}
