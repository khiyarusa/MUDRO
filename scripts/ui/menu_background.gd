class_name MenuBackground
extends Control
## Reusable cinematic menu backdrop: layered environment art with slow parallax,
## a controlled vignette and an optional hero vehicle.

var env_id: String = "canyon"
var show_hero: bool = true
var _layers: Array[TextureRect] = []
var _speeds: Array[float] = [0.0, 4.0, 9.0, 16.0]
var _time: float = 0.0
var _hero: TextureRect

func setup(environment: String, hero: bool = true) -> void:
	env_id = environment
	show_hero = hero
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size
	position = Vector2.ZERO
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_on_view_resized)
	_build()

func _on_view_resized() -> void:
	size = get_viewport_rect().size

func _build() -> void:
	var solid := ColorRect.new()
	solid.color = Color(0.10, 0.11, 0.12)
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(solid)

	var sky := TextureRect.new()
	sky.texture = _tex("sky")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	var names: Array[String] = ["far", "mid", "near"]
	for i: int in range(names.size()):
		var tr := TextureRect.new()
		tr.texture = _tex(names[i])
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate = Color(1, 1, 1, 0.95 - float(i) * 0.05)
		add_child(tr)
		_layers.append(tr)

	# Bottom fade only across the lower third, so gameplay art stays readable.
	var fade_holder := Control.new()
	fade_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fade_holder.offset_top = -300.0
	fade_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_holder)
	var fade := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.035, 0.04, 0.0))
	g.set_color(1, Color(0.03, 0.035, 0.04, 0.92))
	fade.gradient = g
	fade.fill_from = Vector2(0.5, 0.0)
	fade.fill_to = Vector2(0.5, 1.0)
	var vig := TextureRect.new()
	vig.texture = fade
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_holder.add_child(vig)

	# Side scrim behind the menu column.
	var side_holder := Control.new()
	if Loc.is_rtl():
		side_holder.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		side_holder.offset_left = -560.0
	else:
		side_holder.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		side_holder.offset_right = 560.0
	side_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side_holder)
	var side := GradientTexture2D.new()
	var gs := Gradient.new()
	gs.set_color(0, Color(0.03, 0.035, 0.04, 0.80))
	gs.set_color(1, Color(0.03, 0.035, 0.04, 0.0))
	side.gradient = gs
	side.fill_from = Vector2(0.0, 0.5) if Loc.is_rtl() else Vector2(1.0, 0.5)
	side.fill_to = Vector2(1.0, 0.5) if Loc.is_rtl() else Vector2(0.0, 0.5)
	var side_rect := TextureRect.new()
	side_rect.texture = side
	side_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	side_rect.stretch_mode = TextureRect.STRETCH_SCALE
	side_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_holder.add_child(side_rect)

	if show_hero:
		var vdef: VehicleDef = Content.vehicle_by_id(SaveManager.selected_vehicle())
		if vdef != null:
			_hero = TextureRect.new()
			var body_path: String = vdef.sprite_body
			if ResourceLoader.exists(body_path):
				_hero.texture = load(body_path) as Texture2D
			_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var hero_scale: float = 520.0 / maxf(vdef.length_m * 160.0, 1.0)
			var hero_size := Vector2(1600.0, 720.0) * hero_scale
			_hero.size = hero_size
			var screen_w: float = get_viewport_rect().size.x
			var hero_x: float = 40.0 if Loc.is_rtl() else screen_w - hero_size.x - 40.0
			_hero.position = Vector2(hero_x, 720.0 - hero_size.y * 0.62)
			add_child(_hero)

func _tex(layer: String) -> Texture2D:
	var path: String = "res://assets/environments/%s/%s.svg" % [env_id, layer]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _process(delta: float) -> void:
	_time += delta
	for i: int in range(_layers.size()):
		var tr: TextureRect = _layers[i]
		var speed: float = _speeds[i + 1]
		var drift: float = fmod(_time * speed, 40.0) - 20.0
		tr.position.x = drift if Loc.is_rtl() else -drift
	if _hero != null:
		_hero.position.y = (720.0 - _hero.size.y * 0.62) + sin(_time * 0.8) * 2.5
