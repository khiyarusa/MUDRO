class_name TouchSlider
extends TouchWidget
## True analog slider: the distance the finger travels along the track *is* the
## commanded value. It is not a button that looks stretched.
##
## Two behaviours, because a throttle and a clutch pedal are not the same control:
##
##  * ABSOLUTE (throttle, brake) — pressing the rail jumps the value to that
##    position and dragging maps linearly from the bottom stop to the top stop.
##    That is what a thumb expects from a throttle: touch high, get a lot.
##  * PEDAL (clutch) — a clutch rail must never jump. Touching the clutch presses
##    it to the floor and the value only falls as the finger is dragged *up*, over
##    a defined travel. Releasing the finger lets the pedal out at a controlled
##    rate. Anything else would either dump the clutch on a stray tap or make the
##    pedal impossible to modulate, and both end with a stalled engine.
##
## In both modes the release is rate-limited, so lifting a finger never snaps a
## pedal to zero in one frame.

enum Mode { ABSOLUTE, PEDAL }

## How far the finger must travel to go from fully pressed to fully released, as a
## fraction of the rail height.
const PEDAL_TRAVEL: float = 0.62
const BITE_WINDOW: float = 0.36

var mode: Mode = Mode.ABSOLUTE
## Throttle/brake fill upward; a clutch pedal travels downward to the floor.
var value_at_bottom: bool = false
var release_rate: float = 4.5
var sensitivity: float = 1.0
var invert: bool = false
## Pedal travel range in this control's own value units where the plates start to
## bite and where they are fully clamped. Drawn on the rail so the mechanic is
## visible instead of being hidden in the physics.
var bite_band: Vector2 = Vector2.ZERO
var _knob: TextureRect
var _rail: TextureRect
var _grab_y: float = 0.0
var _pressed_once: bool = false

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

## A slim clutch rail still needs a thumb-sized target: the hit box is wider than
## the drawn rail, but it stops short of the neighbouring brake.
func hit_test(local: Vector2) -> bool:
	if not enabled or not visible:
		return false
	var half: float = size.x * (0.72 if mode == Mode.PEDAL else 0.45) * (1.0 + SettingsService.touch_hit_margin)
	var cy: float = clampf(local.y, 0.0, size.y)
	return absf(local.x - size.x * 0.5) <= maxf(half, 34.0) \
		and cy >= -size.y * 0.08 and cy <= size.y * 1.08

func _value_from_y(y: float) -> float:
	var top: float = _track_top()
	var bottom: float = _track_bottom()
	var t: float = clampf((bottom - y) / maxf(bottom - top, 1.0), 0.0, 1.0)
	if invert:
		t = 1.0 - t
	if value_at_bottom:
		t = 1.0 - t
	# Response curve: sensitivity < 1 gives finer control at small openings.
	var shaped: float = pow(t, clampf(sensitivity, 0.4, 2.0))
	return shaped

func _pedal_value_from_travel(dy_up: float) -> float:
	var travel: float = maxf(size.y * PEDAL_TRAVEL, 1.0)
	return clampf(1.0 - dy_up / travel, 0.0, 1.0)

func _on_press(local: Vector2) -> void:
	_grab_y = local.y
	_pressed_once = true
	if mode == Mode.PEDAL:
		# A clutch tap always means "pedal to the floor". The player then releases
		# it deliberately; there is no way to accidentally dump it with a tap.
		set_value(1.0)
	else:
		set_value(_value_from_y(local.y))
	_modulate_active(true)
	SettingsService.vibrate(6)

func _on_drag(local: Vector2) -> void:
	if mode == Mode.PEDAL:
		set_value(_pedal_value_from_travel(_grab_y - local.y))
	else:
		set_value(_value_from_y(local.y))

func _on_release() -> void:
	_modulate_active(false)

func _process(delta: float) -> void:
	if not active and value > 0.0:
		var rate: float = release_rate * (0.4 + value * 0.9)
		set_value(maxf(0.0, value - rate * delta))
	_position_knob()

func _pedal_y(value_now: float) -> float:
	var top: float = _track_top()
	var bottom: float = _track_bottom()
	if value_at_bottom:
		return lerpf(top, bottom, value_now)
	return lerpf(bottom, top, value_now)

func _position_knob() -> void:
	if _knob == null:
		return
	var y: float = _pedal_y(value)
	_knob.position = Vector2((size.x - _knob.size.x) * 0.5, y - _knob.size.y * 0.5)
	queue_redraw()

func _draw() -> void:
	var top: float = _track_top()
	var bottom: float = _track_bottom()
	var y: float = _pedal_y(value)
	var cx: float = size.x * 0.5
	var w: float = size.x * (0.30 if mode == Mode.PEDAL else 0.17)
	var half: float = w * 0.5

	# Machined rail: darker well with a fine highlight down each edge.
	draw_rect(Rect2(cx - half - 4.0, top, w + 8.0, bottom - top), Color(0.03, 0.035, 0.04, 0.55), true)
	draw_rect(Rect2(cx - half, top, w, bottom - top), Color(0.10, 0.115, 0.13, 0.65), true)
	draw_line(Vector2(cx - half - 4.0, top), Vector2(cx - half - 4.0, bottom), Color(0.90, 0.91, 0.93, 0.10), 1.0)
	draw_line(Vector2(cx + half + 4.0, top), Vector2(cx + half + 4.0, bottom), Color(0.90, 0.91, 0.93, 0.06), 1.0)

	# Tick marks every 10 %: the player can see how much pedal is in.
	for i: int in range(1, 10):
		var ty: float = lerpf(top, bottom, float(i) / 10.0)
		var tick: float = 6.0 if i % 5 == 0 else 3.0
		draw_line(Vector2(cx + half + 6.0, ty), Vector2(cx + half + 6.0 + tick, ty), Color(0.86, 0.87, 0.88, 0.28), 1.0)

	# Clutch engagement window: the pedal travel where the plates bite. It is drawn
	# from the fitted clutch's own window, so the band shrinks when a twin plate goes
	# in and widens with an organic one.
	if bite_band.x > 0.0 or bite_band.y > 0.0:
		var p_open: float = clampf(bite_band.y, 0.0, 1.0)
		var p_bite: float = clampf(bite_band.x, 0.0, p_open)
		var y_open: float = _pedal_y(p_open)
		var y_bite: float = _pedal_y(p_bite)
		var band_top: float = minf(y_open, y_bite)
		var band_h: float = maxf(absf(y_bite - y_open), 6.0)
		draw_rect(Rect2(cx - half - 7.0, band_top, w + 14.0, band_h), Color(0.95, 0.66, 0.26, 0.30), true)
		draw_rect(Rect2(cx - half - 7.0, band_top, w + 14.0, band_h), Color(0.98, 0.74, 0.36, 0.55), false, 1.0)
		# The bright edge marks the pedal position where the plates start to grip, so
		# the player can learn a car's bite point by looking at the control. The
		# pointer at the rail edge reads the same at any size, with or without a font.
		draw_line(Vector2(cx - half - 7.0, y_open), Vector2(cx + half + 7.0, y_open), Color(0.99, 0.78, 0.40, 0.95), 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx + half + 8.0, y_open),
			Vector2(cx + half + 17.0, y_open - 6.0),
			Vector2(cx + half + 17.0, y_open + 6.0),
		]), Color(0.99, 0.78, 0.40, 0.9))

	# Filled travel.
	var rect_y: float = minf(y, _pedal_y(0.0))
	var rect_h: float = absf(y - _pedal_y(0.0))
	draw_rect(Rect2(cx - half, rect_y, w, rect_h), Color(0.93, 0.63, 0.25, 0.42), true)
	draw_line(Vector2(cx - half, y), Vector2(cx + half, y), Color(1.0, 0.82, 0.48, 0.95), 2.0)
	if active:
		draw_rect(Rect2(cx - half - 2.0, rect_y, w + 4.0, maxf(rect_h, 2.0)), Color(1.0, 0.78, 0.40, 0.12), true)
