class_name RaceEffects
extends Node2D
## Surface-driven particles: dust, mud spray, snow, exhaust and impact bursts.
## Emission follows the simulated slip and contact state, not a timer.

var vehicle: VehicleBody
var env_id: String = "canyon"
var _wheel_dust: Array[CPUParticles2D] = []
var _exhaust: CPUParticles2D
var _weather: CPUParticles2D
var _soft: Texture2D

func setup(v: VehicleBody, environment: String) -> void:
	vehicle = v
	env_id = environment
	_soft = _soft_circle()
	for i: int in range(2):
		var p := _make_particles(Color(0.72, 0.60, 0.44, 0.5), 16, 1.0, Vector2(0, -1), 55.0, 0.35)
		add_child(p)
		_wheel_dust.append(p)
	_exhaust = _make_particles(Color(0.35, 0.34, 0.33, 0.30), 12, 0.8, Vector2(-1, -0.4), 22.0, 0.22)
	add_child(_exhaust)

	if env_id == "quarry":
		var layer := CanvasLayer.new()
		layer.layer = 4
		add_child(layer)
		_weather = _make_particles(Color(0.95, 0.97, 1.0, 0.55), 70, 3.4, Vector2(0, 1), 30.0, 0.10)
		_weather.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_weather.emission_rect_extents = Vector2(760, 8)
		_weather.gravity = Vector2(28, 90)
		_weather.position = Vector2(640, -30)
		_weather.emitting = true
		layer.add_child(_weather)

func _soft_circle() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex

func _make_particles(color: Color, amount: int, lifetime: float, direction: Vector2,
		speed: float, scale_px: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 0.5
	p.direction = direction
	p.spread = 32.0
	p.gravity = Vector2(0, -18)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_min = scale_px * 0.5
	p.scale_amount_max = scale_px * 1.6
	p.color = color
	p.texture = _soft
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.emitting = false
	p.z_index = 7
	return p

func _process(delta: float) -> void:
	if vehicle == null or vehicle.axles.size() < 2:
		return
	for i: int in range(_wheel_dust.size()):
		var axle: WheelAxis = vehicle.axles[i]
		var p: CPUParticles2D = _wheel_dust[i]
		if axle.in_contact:
			p.global_position = axle.contact_point + axle.contact_normal * 4.0
			var slip: float = absf(axle.slip_ratio)
			var spin: float = maxf(0.0, slip - 0.16)
			var speed_factor: float = clampf(absf(vehicle.forward_speed) / 6.0, 0.0, 1.0)
			var amount: float = clampf(spin * 1.6 + speed_factor * 0.25, 0.0, 1.0)
			p.emitting = amount > 0.08
			p.modulate.a = amount
			var surface: SurfaceProfile = axle.surface
			if surface != null:
				p.color = _surface_color(surface)
		else:
			p.emitting = false

	if _exhaust != null:
		var rear_axle: WheelAxis = vehicle.axles[1]
		_exhaust.global_position = vehicle.global_position + Vector2(-vehicle.definition.length_m * 0.45 * Units.PPM, 0.0)
		_exhaust.emitting = vehicle.throttle_input > 0.2 and vehicle.engine != null and vehicle.engine.running

func _surface_color(surface: SurfaceProfile) -> Color:
	match surface.particle_kind:
		"mud":
			return Color(0.30, 0.22, 0.13, 0.62)
		"snow":
			return Color(0.94, 0.96, 1.0, 0.6)
		"water":
			return Color(0.55, 0.72, 0.78, 0.5)
		"sand":
			return Color(0.86, 0.72, 0.5, 0.55)
		_:
			return Color(0.66, 0.55, 0.4, 0.45)

func burst(world_point: Vector2, kind: String = "dust") -> void:
	var color: Color = Color(0.7, 0.6, 0.45, 0.6)
	var speed: float = 90.0
	match kind:
		"rock":
			color = Color(0.75, 0.70, 0.62, 0.7)
			speed = 140.0
		"wood":
			color = Color(0.52, 0.36, 0.20, 0.7)
			speed = 100.0
		"mud", "water":
			color = Color(0.35, 0.28, 0.18, 0.75)
			speed = 120.0
	var p := _make_particles(color, 20, 0.7, Vector2(0, -1), speed, 0.28)
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = true
	p.global_position = world_point
	p.z_index = 8
	add_child(p)
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(p.queue_free)
