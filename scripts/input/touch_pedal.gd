class_name TouchPedal
extends TouchWidget
## Analog pedal: a real plate whose travel follows the finger. Pressing near the
## top of the plate is a light touch, pressing to the bottom stop is full throttle.
## The return spring is modelled so the car does not slam shut when the finger lifts.

const DEAD_ZONE: float = 0.10

var release_rate: float = 9.0
var travel_visual: float = 0.0

func setup_pedal(id: String, rect: Rect2, art: String, caption: String = "") -> void:
	configure(id, rect, caption)
	set_art(art, "")
	if _art_pressed != null:
		_art_pressed.texture = null

func hit_test(local: Vector2) -> bool:
	if not enabled or not visible:
		return false
	var pad: float = SettingsService.touch_hit_margin * size.x * 0.25
	return Rect2(Vector2(-pad, -pad), size + Vector2(pad * 2.0, pad * 2.0)).has_point(local)

func _value_from_y(y: float) -> float:
	var t: float = clampf(y / maxf(size.y, 1.0), 0.0, 1.0)
	var usable: float = 1.0 - DEAD_ZONE
	return clampf((t - DEAD_ZONE) / usable, 0.0, 1.0)

func _on_press(local: Vector2) -> void:
	set_value(_value_from_y(local.y))
	_modulate_active(true)

func _on_drag(local: Vector2) -> void:
	set_value(_value_from_y(local.y))

func _on_release() -> void:
	_modulate_active(false)

func _process(delta: float) -> void:
	if active:
		travel_visual = lerpf(travel_visual, value, clampf(delta * 20.0, 0.0, 1.0))
	else:
		if value > 0.0:
			set_value(maxf(0.0, value - release_rate * delta))
		travel_visual = lerpf(travel_visual, 0.0, clampf(delta * 14.0, 0.0, 1.0))
	if _art != null:
		_art.position = Vector2(0.0, travel_visual * size.y * 0.045)
	queue_redraw()

func _draw() -> void:
	var w: float = size.x * 0.34
	var cx: float = size.x * 0.5
	var top: float = size.y * 0.30
	var bottom: float = size.y * 0.94
	var y: float = lerpf(bottom, top, travel_visual)
	draw_rect(Rect2(cx - w * 0.5, y, w, bottom - y), Color(0.93, 0.63, 0.25, 0.35), true)
	draw_line(Vector2(cx - w * 0.5, y), Vector2(cx + w * 0.5, y), Color(1.0, 0.8, 0.45, 0.85), 2.0)
	if active:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.68, 0.28, 0.06), true)
