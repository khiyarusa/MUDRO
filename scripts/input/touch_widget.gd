class_name TouchWidget
extends Control
## A touch control that is *not* a GUI button. The TouchControls layer owns pointer
## routing, so every widget receives exactly one finger index and keeps it until
## that finger is lifted — this is what makes simultaneous throttle + clutch work.
##
## Widgets are pure presentation plus a value. They never write to the vehicle:
## the layer assembles a VehicleInputState and the race scene hands it over.

signal value_changed(value: float)

## Finger index currently owning the control, or -1.
var finger_id: int = -1
var active: bool = false
var enabled: bool = true
var value: float = 0.0
var control_id: String = ""

var _label: Label
var _art: TextureRect
var _art_pressed: TextureRect

func configure(id: String, rect: Rect2, caption: String = "") -> void:
	control_id = id
	position = rect.position
	size = rect.size
	pivot_offset = rect.size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build(caption)

func _build(caption: String) -> void:
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_art)
	_art_pressed = TextureRect.new()
	_art_pressed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_pressed.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_pressed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_pressed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_pressed.modulate = Color(1, 1, 1, 0)
	add_child(_art_pressed)
	if not caption.is_empty():
		_label = Label.new()
		_label.text = caption
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 13)
		_label.add_theme_color_override("font_color", Color(0.86, 0.83, 0.76, 0.85))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_label.add_theme_constant_override("outline_size", 4)
		var lf: Font = Loc.font_medium()
		if lf != null:
			_label.add_theme_font_override("font", lf)
		_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_label.offset_top = -22
		_label.offset_bottom = -2
		add_child(_label)

func set_art(normal: String, pressed_art: String = "pad_pressed") -> void:
	if _art == null:
		return
	_art.texture = ArtLib.control(normal)
	if _art_pressed != null and not pressed_art.is_empty():
		_art_pressed.texture = ArtLib.control(pressed_art)

## Circle hit test by default: the visible control is round even though the node is
## a square, so a square hit area would steal touches from neighbouring controls.
func hit_test(local: Vector2) -> bool:
	if not enabled or not visible:
		return false
	var r: float = minf(size.x, size.y) * 0.5
	var margin: float = SettingsService.touch_hit_margin
	return local.distance_to(size * 0.5) <= r * (1.0 + margin)

func press_at(local: Vector2, finger: int) -> void:
	if not enabled:
		return
	finger_id = finger
	active = true
	_on_press(local)

func drag_at(local: Vector2) -> void:
	if not active:
		return
	_on_drag(local)

func release_finger() -> void:
	if not active and finger_id < 0:
		return
	active = false
	finger_id = -1
	_on_release()

func reset() -> void:
	active = false
	finger_id = -1
	set_value(0.0)
	_modulate_active(false)

func set_value(v: float) -> void:
	var clamped: float = clampf(v, 0.0, 1.0)
	if is_equal_approx(clamped, value):
		value = clamped
		return
	value = clamped
	value_changed.emit(value)
	queue_redraw()

func _modulate_active(on: bool) -> void:
	if _art != null:
		_art.modulate = Color(1.12, 1.12, 1.12, 1.0) if on else Color(1, 1, 1, 1)
	if _art_pressed != null:
		_art_pressed.modulate.a = 0.95 if on else 0.0
	queue_redraw()

func _on_press(_local: Vector2) -> void:
	pass

func _on_drag(_local: Vector2) -> void:
	pass

func _on_release() -> void:
	pass

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
