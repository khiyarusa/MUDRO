class_name TouchSlider
extends TouchWidget
## True analog slider: the distance the finger travels along the track *is* the
## throttle/brake value. It is not a button that looks stretched.
##
##  * press anywhere on the rail and the value jumps to that position;
##  * dragging maps linearly (with an adjustable response curve) from the bottom
##    stop to the top stop;
##  * releasing returns to zero at a controlled rate instead of snapping, which
##    keeps the car from lurching;
##  * the fill and the knob show the exact commanded value.

var release_rate: float = 4.5
var sensitivity: float = 1.0
var invert: bool = false
var _knob: TextureRect
var _rail: TextureRect

func setup_slider(id: String, rect: Rect2, caption: String = "") -> void:
	configure(id, rect, caption)
	_rail = TextureRect.new()
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rail.texture = ArtLib.control("slider_rail")
	add_child(_rail)
	move_child(_rail, 0)

	_knob = TextureRect.new()
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.texture = ArtLib.control("slider_knob")
	_knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_knob.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_knob.size = Vector2(size.x * 1.25, size.x * 0.9)
	add_child(_knob)
	_position_knob()

func _track_top() -> float:
	return size.y * 0.06

func _track_bottom() -> float:
	return size.y * 0.94

func hit_test(local: Vector2) -> bool:
	if not enabled or not visible:
		return false
	var pad: float = size.x * 0.45 * (1.0 + SettingsService.touch_hit_margin)
	var cy: float = clampf(local.y, 0.0, size.y)
	return absf(local.x - size.x * 0.5) <= pad and cy >= -size.y * 0.08 and cy <= size.y * 1.08

func _value_from_y(y: float) -> float:
	var top: float = _track_top()
	var bottom: float = _track_bottom()
	var t: float = clampf((bottom - y) / maxf(bottom - top, 1.0), 0.0, 1.0)
	if invert:
		t = 1.0 - t
	# Response curve: sensitivity < 1 gives finer control near the top.
	var shaped: float = pow(t, clampf(sensitivity, 0.4, 2.0))
	return shaped

func _on_press(local: Vector2) -> void:
	set_value(_value_from_y(local.y))
	_modulate_active(true)

func _on_drag(local: Vector2) -> void:
	set_value(_value_from_y(local.y))

func _on_release() -> void:
	_modulate_active(false)

func _process(delta: float) -> void:
	if not active and value > 0.0:
		var rate: float = release_rate * (0.4 + value * 0.9)
		set_value(maxf(0.0, value - rate * delta))
	_position_knob()

func _position_knob() -> void:
	if _knob == null:
		return
	var top: float = _track_top()
	var bottom: float = _track_bottom()
	var y: float = lerpf(bottom, top, value)
	_knob.position = Vector2((size.x - _knob.size.x) * 0.5, y - _knob.size.y * 0.5)
	queue_redraw()

func _draw() -> void:
	var top: float = _track_top()
	var bottom: float = _track_bottom()
	var y: float = lerpf(bottom, top, value)
	var cx: float = size.x * 0.5
	var w: float = size.x * 0.17
	draw_rect(Rect2(cx - w * 0.5, y, w, bottom - y), Color(0.93, 0.63, 0.25, 0.55), true)
	draw_line(Vector2(cx - w * 0.5, y), Vector2(cx + w * 0.5, y), Color(1.0, 0.78, 0.4, 0.9), 2.0)
