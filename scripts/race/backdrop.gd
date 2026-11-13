class_name Backdrop
extends Node2D
## Screen-space layered backdrop. The environment art tiles horizontally and drifts
## at different rates, giving 2.5D depth without extra draw calls on mobile.

var env_id: String = "canyon"
var camera: Camera2D
var _layer: CanvasLayer
var _sky: TextureRect
var _rects: Array[TextureRect] = []
var _factors: Array[float] = [0.03, 0.07, 0.13]
var _vertical: Array[float] = [0.05, 0.10, 0.18]
var _sizes: Array[float] = []
var _heights: Array[float] = []

func setup(environment: String, cam: Camera2D) -> void:
	env_id = environment
	camera = cam
	_layer = CanvasLayer.new()
	_layer.layer = -20
	add_child(_layer)

	var solid := ColorRect.new()
	solid.color = _fallback_sky()
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(solid)

	_sky = TextureRect.new()
	var sky_tex: Texture2D = _tex("sky")
	if sky_tex != null:
		_sky.texture = sky_tex
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_sky)

	for i: int in range(3):
		var names: Array[String] = ["far", "mid", "near"]
		var tex: Texture2D = _tex(names[i])
		if tex == null:
			continue
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		tr.size = Vector2(tex.get_width() * 3.0, tex.get_height())
		tr.position = Vector2(0, 720 - tex.get_height())
		tr.modulate = Color(1, 1, 1, 0.9 - float(i) * 0.04)
		_layer.add_child(tr)
		_rects.append(tr)
		_sizes.append(float(tex.get_width()))
		_heights.append(float(tex.get_height()))

func _fallback_sky() -> Color:
	match env_id:
		"pine":
			return Color(0.55, 0.60, 0.61)
		"quarry":
			return Color(0.62, 0.72, 0.82)
		_:
			return Color(0.86, 0.72, 0.55)

func _tex(layer: String) -> Texture2D:
	var path: String = "res://assets/environments/%s/%s.svg" % [env_id, layer]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _process(_delta: float) -> void:
	if camera == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	for i: int in range(_rects.size()):
		var tr: TextureRect = _rects[i]
		var factor: float = _factors[i]
		var tile: float = _sizes[i]
		var x: float = -fmod(camera.global_position.x * factor, tile)
		if x > 0.0:
			x -= tile
		tr.position.x = x
		tr.position.y = view.y - _heights[i] + clampf(camera.global_position.y * _vertical[i], -260.0, 260.0)
