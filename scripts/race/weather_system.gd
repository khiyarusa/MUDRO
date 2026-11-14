class_name WeatherSystem
extends Node2D
## Data-driven weather. It changes both the picture and the physics:
## rain and snow reduce grip and raise rolling resistance on soft surfaces, fog
## shortens the visible depth band, and clear weather changes nothing at all.
##
## The multipliers are deliberately modest. A weather state must alter how a stage
## drives, not make an authored stage impossible.

const PROFILES: Dictionary = {
	"clear": {"fa": "صاف", "en": "Clear", "grip": 1.0, "rr": 1.0, "fog": 0.0, "rain": 0.0, "snow": 0.0, "light": 1.0},
	"cloudy": {"fa": "ابری", "en": "Cloudy", "grip": 0.99, "rr": 1.0, "fog": 0.05, "rain": 0.0, "snow": 0.0, "light": 0.94},
	"rain": {"fa": "باران", "en": "Rain", "grip": 0.94, "rr": 1.05, "fog": 0.10, "rain": 1.0, "snow": 0.0, "light": 0.84},
	"heavy_rain": {"fa": "باران شدید", "en": "Heavy rain", "grip": 0.88, "rr": 1.10, "fog": 0.18, "rain": 2.0, "snow": 0.0, "light": 0.74},
	"snow": {"fa": "برف", "en": "Snow", "grip": 0.86, "rr": 1.14, "fog": 0.14, "rain": 0.0, "snow": 1.0, "light": 0.88},
	"fog": {"fa": "مه", "en": "Fog", "grip": 0.96, "rr": 1.02, "fog": 0.30, "rain": 0.0, "snow": 0.0, "light": 0.90},
}

var id: String = "clear"
var grip_scale: float = 1.0
var rr_scale: float = 1.0
var quality: int = 2

var _layer: CanvasLayer
var _rain: CPUParticles2D
var _snow: CPUParticles2D
var _fog: TextureRect
var _streak: Texture2D
var _flake: Texture2D

func setup(environment: String, weather_id: String, quality_level: int = 2) -> void:
	id = weather_id if PROFILES.has(weather_id) else "clear"
	quality = clampi(quality_level, 0, 2)
	var p: Dictionary = PROFILES[id] as Dictionary
	grip_scale = float(p.get("grip", 1.0))
	rr_scale = float(p.get("rr", 1.0))
	if id == "clear":
		return
	_streak = _streak_texture()
	_flake = _flake_texture()
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)

	_fog = TextureRect.new()
	_fog.texture = _fog_texture()
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fog.stretch_mode = TextureRect.STRETCH_SCALE
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.modulate = Color(0.86, 0.88, 0.90, clampf(float(p.get("fog", 0.0)) * 1.7, 0.0, 0.55) * (0.5 if quality == 0 else 1.0))
	_layer.add_child(_fog)

	var rain_amount: float = float(p.get("rain", 0.0))
	if rain_amount > 0.0 and quality > 0:
		_rain = _make_precip(_streak, int(150.0 * rain_amount) if quality == 2 else 80, 0.55, Vector2(0.22, 1.0), 780.0, 1.6)
		_rain.color = Color(0.72, 0.80, 0.88, 0.55)
		_layer.add_child(_rain)
	var snow_amount: float = float(p.get("snow", 0.0))
	if snow_amount > 0.0 and quality > 0:
		_snow = _make_precip(_flake, 110 if quality == 2 else 60, 1.5, Vector2(0.15, 1.0), 70.0, 3.4)
		_snow.color = Color(0.96, 0.97, 1.0, 0.8)
		_layer.add_child(_snow)

func apply_to(vehicle: VehicleBody) -> void:
	if vehicle == null:
		return
	vehicle.apply_surface_conditions(grip_scale, rr_scale)

func label() -> String:
	var p: Dictionary = PROFILES.get(id, PROFILES["clear"]) as Dictionary
	return String(p["fa"] if Loc.lang == "fa" else p["en"])

func ambient_tint() -> Color:
	var p: Dictionary = PROFILES.get(id, PROFILES["clear"]) as Dictionary
	var light: float = float(p.get("light", 1.0))
	return Color(light, light, light * 1.01)

func is_wet() -> bool:
	return id == "rain" or id == "heavy_rain" or id == "snow"

func _process(_delta: float) -> void:
	if _layer == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	if _fog != null:
		_fog.position = Vector2.ZERO
		_fog.size = view
	if _rain != null:
		_rain.position = Vector2(view.x * 0.5, -40.0)
		_rain.emission_rect_extents = Vector2(view.x * 0.62, 12.0)
	if _snow != null:
		_snow.position = Vector2(view.x * 0.5, -30.0)
		_snow.emission_rect_extents = Vector2(view.x * 0.62, 12.0)
		_snow.gravity.x = sin(Time.get_ticks_msec() * 0.0004) * 34.0

func _make_precip(tex: Texture2D, amount: int, lifetime: float, direction: Vector2, speed: float, scale_px: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = maxi(amount, 12)
	p.lifetime = lifetime
	p.texture = tex
	p.direction = direction
	p.spread = 6.0
	p.initial_velocity_min = speed * 0.8
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, speed * 0.5)
	p.scale_amount_min = scale_px * 0.7
	p.scale_amount_max = scale_px * 1.3
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700, 12)
	p.emitting = true
	p.z_index = 30
	p.local_coords = false
	return p

func _streak_texture() -> Texture2D:
	var img := Image.create(4, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in range(24):
		var a: float = 0.25 + 0.75 * (float(y) / 24.0)
		img.set_pixel(1, y, Color(1, 1, 1, a))
		img.set_pixel(2, y, Color(1, 1, 1, a * 0.8))
	return ImageTexture.create_from_image(img)

func _flake_texture() -> Texture2D:
	var size: int = 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Vector2 = Vector2(size, size) * 0.5
	for y: int in range(size):
		for x: int in range(size):
			var d: float = Vector2(x, y).distance_to(c) / (size * 0.5)
			if d < 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - d, 1.6)))
	return ImageTexture.create_from_image(img)

func _fog_texture() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.80, 0.84, 0.87, 0.0))
	grad.set_color(1, Color(0.80, 0.84, 0.87, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 128
	return tex
