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

func _process(delta: float) -> void:
	if vehicle == null or vehicle.axles.size() < 2:
		return
	for i: int in range(wheel_sprites.size()):
		var axle: WheelAxis = vehicle.axles[i]
		var wheel: Sprite2D = wheel_sprites[i]
		wheel.position = wheel.position.lerp(axle.hub_local, clampf(delta * 26.0, 0.0, 1.0))
		wheel.rotation = axle.spin_angle
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
