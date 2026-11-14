class_name TouchButton
extends TouchWidget
## Digital control with a real texture, a pressed state and a captured finger.
## Holding the control keeps the value at 1.0 for as long as the finger is down,
## including when the finger slides outside the circle; only lifting releases it.

var icon_name: String = ""
var _icon: TextureRect

func setup_button(id: String, rect: Rect2, art: String, caption: String = "") -> void:
	configure(id, rect, caption)
	if art.begins_with("icon_"):
		# Icon glyphs are not button skins: put the engraved icon on the machined
		# utility pad so a gear or winch button still looks like a control.
		set_art("pad_handbrake", "pad_pressed")
		_add_icon(art)
	else:
		set_art(art)

func _add_icon(texture_name: String) -> void:
	if _icon != null:
		return
	_icon = TextureRect.new()
	_icon.texture = ArtLib.control(texture_name)
	if _icon.texture == null:
		_icon.texture = ArtLib.icon(texture_name)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.modulate = Color(0.96, 0.92, 0.84, 0.92)
	add_child(_icon)
	_layout_icon()

func _layout_icon() -> void:
	if _icon == null:
		return
	var d: float = minf(size.x, size.y) * 0.48
	_icon.size = Vector2(d, d)
	_icon.position = (size - Vector2(d, d)) * 0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_icon()

func _on_press(_local: Vector2) -> void:
	set_value(1.0)
	_modulate_active(true)
	scale = Vector2(0.955, 0.955)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.09)
	SettingsService.vibrate(9)

func _on_release() -> void:
	set_value(0.0)
	_modulate_active(false)
	scale = Vector2.ONE

func _draw() -> void:
	if not active:
		return
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	draw_arc(c, r * 0.94, 0.0, TAU, 48, Color(0.95, 0.68, 0.28, 0.55), 2.0, true)
	draw_circle(c, r * 0.98, Color(0.95, 0.68, 0.28, 0.06))
