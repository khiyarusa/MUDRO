class_name VehicleVisual
extends Node2D
## Presentation layer for a VehicleBody. The chassis sprite and the two wheel
## sprites are driven by the simulated suspension and wheel rotation, so what you
## see is the physics state, never a disconnected animation.

var vehicle: VehicleBody
var body_sprite: Sprite2D
var wheel_sprites: Array[Sprite2D] = []
var body_fallback: Polygon2D
var brake_glow: Sprite2D
var _shocks: Array[Line2D] = []
var _springs: Array[Line2D] = []
var _dirt: float = 0.0
var _base_modulate: Color = Color.WHITE

func setup(v: VehicleBody) -> void:
	vehicle = v
	z_index = 5

	var shadow := _make_shadow()
	add_child(shadow)

	for i: int in range(2):
		var wheel := Sprite2D.new()
		wheel.name = "Wheel%d" % i
		wheel.z_index = -1
		wheel.centered = true
		var tex: Texture2D = _try_load(vehicle.definition.sprite_wheel)
		if tex != null:
			wheel.texture = tex
			var diameter_px: float = tex.get_width()
			var target_px: float = vehicle.definition.tire_for(i).radius_m * 2.0 * Units.PPM
			wheel.scale = Vector2.ONE * (target_px / maxf(diameter_px, 1.0))
		else:
			var circle := _make_fallback_wheel(vehicle.definition.tire_for(i))
			wheel.add_child(circle)
		add_child(wheel)
		wheel_sprites.append(wheel)

	body_sprite = Sprite2D.new()
	body_sprite.name = "Body"
	body_sprite.centered = true
	body_sprite.z_index = 1
	var body_tex: Texture2D = _try_load(vehicle.definition.sprite_body)
	if body_tex != null:
		body_sprite.texture = body_tex
		var art_scale: float = Units.PPM / maxf(vehicle.definition.art_scale_px_per_m, 1.0)
		body_sprite.scale = Vector2.ONE * art_scale
		# The artwork's axle line (y=400 in a 720 px canvas) must sit exactly on the
		# simulated axle height, so wheels and body arches line up.
		var art_axle_from_center: float = (400.0 - body_tex.get_height() * 0.5) * art_scale
		body_sprite.position = Vector2(0.0, vehicle.definition.com_height_m * Units.PPM - art_axle_from_center)
	else:
		body_fallback = Polygon2D.new()
		body_fallback.polygon = vehicle.body_polygon_px()
		body_fallback.color = vehicle.definition.accent_color
		add_child(body_fallback)
	body_sprite.visible = body_tex != null
	add_child(body_sprite)

	brake_glow = Sprite2D.new()
	brake_glow.name = "BrakeGlow"
	brake_glow.z_index = 2
	brake_glow.texture = _glow_texture(Color(1.0, 0.24, 0.16))
	brake_glow.scale = Vector2(0.5, 0.5)
	brake_glow.visible = false
	var rear_x: float = -vehicle.definition.wheelbase_m * 0.5 * Units.PPM
	brake_glow.position = Vector2(rear_x - vehicle.definition.length_m * 0.18 * Units.PPM, vehicle.definition.com_height_m * Units.PPM - 0.55 * Units.PPM)
	add_child(brake_glow)

	# Visible suspension: the damper body and the coil are driven by the simulated
	# compression every frame, so a bottoming-out axle is something you can see.
	for i: int in range(2):
		var damper := Line2D.new()
		damper.name = "Damper%d" % i
		damper.width = 4.0
		damper.default_color = Color(0.16, 0.17, 0.18, 0.95)
		damper.z_index = 0
		damper.begin_cap_mode = Line2D.LINE_CAP_ROUND
		damper.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(damper)
		_shocks.append(damper)
		var spring := Line2D.new()
		spring.name = "Spring%d" % i
		spring.width = 2.5
		spring.default_color = Color(0.72, 0.52, 0.22, 0.9)
		spring.z_index = 1
		add_child(spring)
		_springs.append(spring)

func _process(delta: float) -> void:
	if vehicle == null or vehicle.axles.size() < 2:
		return
	for i: int in range(wheel_sprites.size()):
		var axle: WheelAxis = vehicle.axles[i]
		var wheel: Sprite2D = wheel_sprites[i]
		wheel.position = wheel.position.lerp(axle.hub_local, clampf(delta * 26.0, 0.0, 1.0))
		wheel.rotation = axle.spin_angle
		_update_suspension_art(i, axle)
	if brake_glow != null:
		var braking: bool = vehicle.brake_input > 0.15 or vehicle.handbrake_input > 0.1
		brake_glow.visible = braking
		if braking:
			brake_glow.modulate.a = 0.55 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
	if body_sprite != null and body_sprite.visible:
		var worn: float = clampf(1.0 - vehicle.damage.chassis, 0.0, 1.0)
		_dirt = lerpf(_dirt, worn, clampf(delta * 1.6, 0.0, 1.0))
		var tint: Color = _base_modulate.lerp(Color(0.42, 0.33, 0.24), _dirt * 0.55)
		body_sprite.modulate = tint

func _update_suspension_art(index: int, axle: WheelAxis) -> void:
	if index >= _shocks.size(): 
		return
	var mount: Vector2 = vehicle.mount_local(index)
	var hub: Vector2 = axle.hub_local
	var travel: float = clampf(axle.compression / maxf(vehicle.definition.suspension.travel_m, 0.01), 0.0, 1.4)
	var damper: Line2D = _shocks[index]
	damper.clear_points()
	damper.add_point(mount)
	damper.add_point(mount.lerp(hub, clampf(0.35 + travel * 0.25, 0.2, 0.75)))
	damper.default_color = Color(0.16, 0.17, 0.18, 0.95).lerp(Color(0.85, 0.62, 0.26, 0.95), clampf(travel - 0.85, 0.0, 0.4))
	var spring: Line2D = _springs[index]
	spring.clear_points()
	var a: Vector2 = mount.lerp(hub, 0.35)
	var b: Vector2 = hub
	var dir: Vector2 = b - a
	if dir.length() < 1.0:
		return
	var perp: Vector2 = Vector2(-dir.y, dir.x).normalized()
	var coils: int = 7
	for k: int in range(coils + 1):
		var t: float = float(k) / float(coils)
		var p: Vector2 = a + dir * t
		if k > 0 and k < coils:
			p += perp * (5.0 if k % 2 == 0 else -5.0)
		spring.add_point(p)
	spring.default_color = Color(0.72, 0.52, 0.22, 0.9).lerp(Color(0.95, 0.40, 0.28, 0.95), clampf(travel - 0.9, 0.0, 0.5))

func _try_load(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res as Texture2D

func _make_fallback_wheel(tire: TireConfig) -> Node2D:
	var rim := Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	var r: float = tire.radius_m * Units.PPM
	for i: int in range(18):
		var a: float = TAU * float(i) / 18.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	rim.polygon = pts
	rim.color = Color(0.09, 0.09, 0.10)
	return rim

func _make_shadow() -> Node2D:
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.z_index = -4
	shadow.texture = _glow_texture(Color(0.0, 0.0, 0.0))
	var w: float = vehicle.definition.length_m * Units.PPM * 1.15
	var h: float = vehicle.definition.height_m * Units.PPM * 0.42
	shadow.scale = Vector2(w / 128.0, h / 128.0)
	shadow.modulate = Color(1, 1, 1, 0.42)
	shadow.position = Vector2(0, vehicle.definition.com_height_m * Units.PPM + 0.1 * Units.PPM)
	return shadow

func _glow_texture(tint: Color) -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(tint.r, tint.g, tint.b, 1.0))
	grad.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 128
	gtex.height = 128
	return gtex
