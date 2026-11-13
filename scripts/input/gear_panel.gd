class_name GearPanel
extends Control
## The gear lever panel. It is a mechanical gate, not a list of buttons.
##
##  * H-pattern: the lever is projected onto the legal gate segments of the fitted
##    gearbox, so a diagonal jump from 2nd to 5th is physically impossible — the
##    lever must travel through neutral.
##  * Sequential: a lever with up/down detents that springs back to centre.
##  * Automatic: a PRNDL range selector drawn as a real gate.
##
## The panel owns its own finger. The clutch pedal keeps a different finger, which
## is what makes "hold clutch, move lever, release clutch" work on a phone.

signal gear_requested(gear: int)
signal range_requested(range_id: String)
signal close_requested

const PLATE_INSET: float = 0.07

var profile: TransmissionProfile
var current_gear: int = 0
var current_range: String = "D"
var clutch_pedal: float = 0.0
var auto_clutch: bool = true
var speed_kmh: float = 0.0

var _knob: Vector2 = Vector2(0.5, 0.5)
var _finger: int = -1
var _dragging: bool = false
var _warn_timer: float = 0.0
var _warn_text: String = ""
var _grabbed: bool = false
var _seq_armed: bool = false
var _plate: Rect2 = Rect2()
var _knob_tex: Texture2D
var _plate_tex: Texture2D
var _title: Label
var _info: Label

func setup(p: TransmissionProfile) -> void:
	profile = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob_tex = ArtLib.control("gate_knob")
	_plate_tex = ArtLib.control("gate_panel")
	_build_labels()
	_knob = _neutral_point()
	queue_redraw()

func _build_labels() -> void:
	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 19)
	_title.add_theme_color_override("font_color", Color(0.94, 0.91, 0.85))
	var f: Font = Loc.font_bold()
	if f != null:
		_title.add_theme_font_override("font", f)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 6
	_title.offset_bottom = 32
	add_child(_title)

	_info = Label.new()
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 14)
	_info.add_theme_color_override("font_color", Color(0.70, 0.70, 0.68))
	_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_info.offset_top = -34
	_info.offset_bottom = -6
	add_child(_info)

func _neutral_point() -> Vector2:
	if profile == null:
		return Vector2(0.5, 0.5)
	return Vector2(0.5, TransmissionProfile.GATE_NEUTRAL)

func _plate_rect() -> Rect2:
	if _plate.size.x > 0.0:
		return _plate
	var w: float = size.x * (1.0 - PLATE_INSET * 2.0)
	var h: float = size.y * (1.0 - PLATE_INSET * 2.0)
	_plate = Rect2(Vector2(size.x * PLATE_INSET, size.y * PLATE_INSET), Vector2(w, h))
	return _plate

func _gate_space() -> Rect2:
	var p: Rect2 = _plate_rect()
	return Rect2(p.position + Vector2(p.size.x * 0.10, p.size.y * 0.12), p.size * Vector2(0.80, 0.74))

func _to_px(norm: Vector2) -> Vector2:
	var g: Rect2 = _gate_space()
	return g.position + Vector2(norm.x * g.size.x, norm.y * g.size.y)

func _to_norm(px: Vector2) -> Vector2:
	var g: Rect2 = _gate_space()
	return Vector2((px.x - g.position.x) / maxf(g.size.x, 1.0), (px.y - g.position.y) / maxf(g.size.y, 1.0))

func hit_test(local: Vector2) -> bool:
	return visible and _plate_rect().has_point(local)

func is_dragging() -> bool:
	return _dragging

func press_at(local: Vector2, finger: int) -> void:
	_finger = finger
	_dragging = true
	_grabbed = false
	if profile == null:
		return
	match profile.kind:
		TransmissionProfile.Kind.MANUAL_H:
			_move_knob_to_finger(local)
		TransmissionProfile.Kind.MANUAL_SEQ:
			_seq_armed = true
			_grabbed = true
		_:
			_commit_range_at(local)
	queue_redraw()

func drag_at(local: Vector2) -> void:
	if not _dragging or profile == null:
		return
	match profile.kind:
		TransmissionProfile.Kind.MANUAL_H:
			_move_knob_to_finger(local)
		TransmissionProfile.Kind.MANUAL_SEQ:
			_seq_drag(local)
		_:
			pass
	queue_redraw()

func release_finger() -> void:
	if profile != null and profile.kind == TransmissionProfile.Kind.MANUAL_H and _dragging:
		var g: Dictionary = profile.gate_project(_knob)
		var gear: int = int(g.get("gear", 0))
		if gear != 0:
			gear_requested.emit(gear)
		else:
			_knob = _neutral_point()
	_dragging = false
	_finger = -1
	_seq_armed = false
	queue_redraw()

func reset_finger() -> void:
	_dragging = false
	_finger = -1
	_seq_armed = false

func _move_knob_to_finger(local: Vector2) -> void:
	if profile == null:
		return
	var norm: Vector2 = _to_norm(local)
	var projected: Dictionary = profile.gate_project(norm)
	_knob = projected["point"] as Vector2
	_grabbed = true
	var gear: int = int(projected.get("gear", 0))
	# Commit as soon as the lever is fully in a gate, but only with the clutch down.
	if gear != 0:
		if _clutch_ready():
			gear_requested.emit(gear)
			_dragging = false
			_finger = -1
		else:
			_warn(Loc.t("gearbox_clutch_needed"))
			_knob = _neutral_point()

func _seq_drag(local: Vector2) -> void:
	var g: Rect2 = _gate_space()
	var t: float = (_to_norm(local).y - 0.5) / 0.5
	if t < -0.42 and not _seq_armed:
		_seq_armed = true
		gear_requested.emit(mini(current_gear + 1, profile.gear_count()))
	elif t > 0.42 and not _seq_armed:
		_seq_armed = true
		gear_requested.emit(maxi(current_gear - 1, -1 if profile.has_reverse else 0))
	elif absf(t) < 0.2:
		_seq_armed = false
	_knob = Vector2(0.5, clampf(0.5 + clampf(t, -0.45, 0.45) * 0.55, 0.02, 0.98))

func _commit_range_at(local: Vector2) -> void:
	if profile == null:
		return
	var t: float = clampf(_to_norm(local).y, 0.0, 0.999)
	var ranges: PackedStringArray = profile.ranges
	if ranges.is_empty():
		return
	var idx: int = clampi(int(t * ranges.size()), 0, ranges.size() - 1)
	range_requested.emit(ranges[idx])

func _clutch_ready() -> bool:
	if profile == null:
		return true
	if not profile.requires_clutch:
		return true
	return auto_clutch or clutch_pedal >= VehicleInputState.CLUTCH_FULL

func _warn(text: String) -> void:
	_warn_text = text
	_warn_timer = 1.6
	SettingsService.vibrate(35)

func flash_reject(reason: String) -> void:
	match reason:
		GearboxState.REJECT_CLUTCH:
			_warn(Loc.t("gearbox_clutch_needed"))
		GearboxState.REJECT_OVERREV:
			_warn(Loc.t("gearbox_overrev"))
		GearboxState.REJECT_REVERSE:
			_warn(Loc.t("gearbox_reverse_blocked"))
		GearboxState.REJECT_SHIFTING:
			_warn(Loc.t("gearbox_shifting"))
		_:
			_warn(Loc.t("gearbox_refused"))
	queue_redraw()

func confirm_shift(gear: int) -> void:
	current_gear = gear
	if profile != null and profile.kind == TransmissionProfile.Kind.MANUAL_H:
		_knob = profile.gate_node(gear)
	_dragging = false
	_finger = -1
	_warn_timer = 0.0
	queue_redraw()

func set_state(gear: int, range_id: String, clutch: float, speed: float, assist: bool) -> void:
	current_gear = gear
	current_range = range_id
	clutch_pedal = clutch
	speed_kmh = speed
	auto_clutch = assist
	if profile != null and profile.kind == TransmissionProfile.Kind.MANUAL_H and not _dragging:
		_knob = _knob.lerp(profile.gate_node(gear), 0.25)
	if _title != null and profile != null:
		_title.text = _title_text()
		_title.position.y = _plate_rect().position.y + 4.0
	if _info != null:
		if _warn_timer > 0.0:
			_info.text = _warn_text
			_info.add_theme_color_override("font_color", Color(0.92, 0.42, 0.34))
		else:
			_info.text = Loc.t("gearbox_panel_hint")
			_info.add_theme_color_override("font_color", Color(0.66, 0.66, 0.64))
	queue_redraw()

func _title_text() -> String:
	if profile == null:
		return ""
	if profile.kind == TransmissionProfile.Kind.AUTOMATIC:
		return "%s  ·  %s" % [profile.label(Loc.lang), current_range]
	return "%s  ·  %s" % [profile.label(Loc.lang), _gear_text(current_gear)]

func _gear_text(g: int) -> String:
	if g == 0:
		return "N"
	if g == -1:
		return "R"
	return str(g)

func _process(delta: float) -> void:
	if _warn_timer > 0.0:
		_warn_timer = maxf(0.0, _warn_timer - delta)
		queue_redraw()

func _draw() -> void:
	if profile == null:
		return
	var plate: Rect2 = _plate_rect()
	# Brushed plate: the authored texture is a subtle base, the gate itself is drawn
	# from the gearbox data so the slot and the physics can never disagree.
	draw_rect(plate, Color(0.075, 0.082, 0.09, 0.96), true)
	if _plate_tex != null:
		draw_texture_rect(_plate_tex, plate, false, Color(1, 1, 1, 0.10))
	draw_rect(plate, Color(0.95, 0.93, 0.88, 0.14), false, 2.0)
	draw_rect(plate.grow(-4.0), Color(0.95, 0.93, 0.88, 0.05), false, 1.0)

	match profile.kind:
		TransmissionProfile.Kind.MANUAL_H:
			_draw_h_gate()
		TransmissionProfile.Kind.MANUAL_SEQ:
			_draw_seq_gate()
		_:
			_draw_auto_gate()

	if _warn_timer > 0.0:
		var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.014)
		draw_rect(plate, Color(0.86, 0.30, 0.24, 0.16 * pulse), true)

func _draw_h_gate() -> void:
	var g: Rect2 = _gate_space()
	var segments: Array[PackedVector2Array] = profile.gate_segments()
	# Neutral rail first, then the vertical gates.
	for i: int in range(segments.size()):
		var seg: PackedVector2Array = segments[i]
		var a: Vector2 = _to_px(seg[0])
		var b: Vector2 = _to_px(seg[1])
		draw_line(a, b, Color(0.02, 0.02, 0.025, 0.95), 16.0, true)
		draw_line(a, b, Color(0.62, 0.64, 0.66, 0.5), 3.0, true)
		draw_line(a, b, Color(0.95, 0.72, 0.34, 0.28), 1.0, true)

	var font: Font = Loc.font_bold()
	var fs: int = int(clampf(size.y * 0.036, 13.0, 24.0))
	# Neutral label
	var npos: Vector2 = _to_px(Vector2(0.5, TransmissionProfile.GATE_NEUTRAL))
	if font != null:
		draw_string(font, npos + Vector2(-40, -14), "N", HORIZONTAL_ALIGNMENT_CENTER, 80, fs, Color(0.85, 0.83, 0.78, 0.75))
	for gear: int in range(-1, profile.gear_count() + 1):
		if gear == 0:
			continue
		var node: Vector2 = profile.gate_node(gear)
		var p: Vector2 = _to_px(node)
		var active: bool = gear == current_gear
		draw_circle(p, 9.0, Color(0.06, 0.06, 0.07, 0.9))
		draw_arc(p, 9.0, 0.0, TAU, 24, Color(0.95, 0.72, 0.34, 0.85 if active else 0.4), 2.0, true)
		if font != null:
			var dy: float = -26.0 if node.y < 0.5 else 38.0
			var col: Color = Color(1.0, 0.78, 0.38) if active else Color(0.80, 0.79, 0.75, 0.85)
			draw_string(font, p + Vector2(-30, dy), _gear_text(gear), HORIZONTAL_ALIGNMENT_CENTER, 60, fs + (2 if active else 0), col)

	var knob_px: Vector2 = _to_px(_knob)
	draw_circle(knob_px, 26.0, Color(0, 0, 0, 0.35))
	if _knob_tex != null:
		var s: float = 46.0
		draw_texture_rect(_knob_tex, Rect2(knob_px - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	else:
		draw_circle(knob_px, 20.0, Color(0.78, 0.80, 0.82))
		draw_circle(knob_px, 8.0, Color(0.95, 0.72, 0.34))

	# Clutch readiness bar along the bottom of the plate.
	var plate: Rect2 = _plate_rect()
	var bar_w: float = plate.size.x * 0.5
	var bar_pos: Vector2 = Vector2(plate.position.x + (plate.size.x - bar_w) * 0.5, plate.end.y - 18.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, 6.0)), Color(1, 1, 1, 0.10), true)
	var ready: bool = _clutch_ready()
	var fill: Color = Color(0.32, 0.72, 0.60, 0.9) if ready else Color(0.90, 0.62, 0.26, 0.9)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * clampf(clutch_pedal, 0.0, 1.0), 6.0)), fill, true)
	if ready:
		draw_rect(Rect2(bar_pos, Vector2(bar_w, 6.0)), Color(0.45, 0.85, 0.72, 0.55), false, 1.0)

func _draw_seq_gate() -> void:
	var g: Rect2 = _gate_space()
	var cx: float = g.position.x + g.size.x * 0.5
	var top: float = g.position.y
	var bottom: float = g.end.y
	draw_line(Vector2(cx, top), Vector2(cx, bottom), Color(0.02, 0.02, 0.025, 0.95), 16.0, true)
	draw_line(Vector2(cx, top), Vector2(cx, bottom), Color(0.62, 0.64, 0.66, 0.5), 3.0, true)
	var font: Font = Loc.font_bold()
	var fs: int = int(clampf(size.y * 0.036, 13.0, 24.0))
	if font != null:
		draw_string(font, Vector2(cx - 80, top + 18), Loc.t("gearbox_up"), HORIZONTAL_ALIGNMENT_CENTER, 160, fs, Color(0.85, 0.83, 0.78, 0.8))
		draw_string(font, Vector2(cx - 80, bottom - 6), Loc.t("gearbox_down"), HORIZONTAL_ALIGNMENT_CENTER, 160, fs, Color(0.85, 0.83, 0.78, 0.8))
	var knob_px: Vector2 = _to_px(_knob)
	if _knob_tex != null:
		draw_texture_rect(_knob_tex, Rect2(knob_px - Vector2(24, 24), Vector2(48, 48)), false)
	else:
		draw_circle(knob_px, 20.0, Color(0.78, 0.80, 0.82))

func _draw_auto_gate() -> void:
	var g: Rect2 = _gate_space()
	var ranges: PackedStringArray = profile.ranges
	if ranges.is_empty():
		return
	var n: int = ranges.size()
	var font: Font = Loc.font_bold()
	var fs: int = int(clampf(size.y * 0.05, 16.0, 30.0))
	var row_h: float = g.size.y / float(n)
	for i: int in range(n):
		var r: String = ranges[i]
		var rect: Rect2 = Rect2(g.position.x + g.size.x * 0.18, g.position.y + row_h * i + 2.0, g.size.x * 0.64, row_h - 4.0)
		var selected: bool = r == current_range
		draw_rect(rect, Color(0.95, 0.72, 0.34, 0.22) if selected else Color(0.16, 0.17, 0.18, 0.9), true)
		draw_rect(rect, Color(0.95, 0.72, 0.34, 0.85) if selected else Color(0.55, 0.56, 0.57, 0.4), false, 2.0)
		if font != null:
			draw_string(font, rect.position + Vector2(0, rect.size.y * 0.5 + fs * 0.36), r,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, Color(0.96, 0.93, 0.86) if selected else Color(0.72, 0.72, 0.70))
