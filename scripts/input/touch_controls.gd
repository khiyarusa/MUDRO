class_name TouchControls
extends Control
## The mobile control layer.
##
## One full-rect Control receives every screen touch, performs its own hit testing
## and assigns each finger to exactly one widget. No TouchScreenButton, no InputMap
## action, no shared mouse pointer: a finger on the throttle and a finger on the
## clutch are two independent owners, so releasing one can never release the other.
##
## The layer only produces a VehicleInputState. It never touches VehicleBody.

signal recover_pressed
signal start_pressed
signal winch_pressed
signal gear_requested(gear: int)
signal range_requested(range_id: String)
signal panel_opened
signal panel_closed
signal layout_changed

const PRESETS: Array[String] = ["buttons", "slider", "pedals"]

var profile: TransmissionProfile
var vehicle: VehicleBody = null
var widgets: Dictionary = {}
var panel: GearPanel
var panel_open: bool = false
var edit_mode: bool = false
## Editor preview: show the clutch control even while clutch assist is enabled, so
## the player can still place and size it.
var preview_all: bool = false

var _fingers: Dictionary = {}
var _built_preset: String = ""
var _built_side: bool = false
var _built_scale: float = -1.0
var _built_manual: bool = true
var _use_mouse: bool = true
var _edit_target: TouchWidget = null
var _edit_grab: Vector2 = Vector2.ZERO
var _edit_origin: Vector2 = Vector2.ZERO
var _edit_moved: bool = false
var _panel_tween: Tween
var _close_timer: float = 0.0

func setup(transmission: TransmissionProfile, v: VehicleBody = null) -> void:
	profile = transmission
	vehicle = v
	_use_mouse = not OS.has_feature("mobile")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = false
	position = Vector2.ZERO
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	if not SettingsService.changed.is_connected(_on_settings_changed):
		SettingsService.changed.connect(_on_settings_changed)
	rebuild()

func _on_viewport_resized() -> void:
	layout()

func _on_settings_changed() -> void:
	var preset: String = SettingsService.control_preset
	var manual: bool = _needs_clutch()
	if preset != _built_preset or SettingsService.control_left_handed != _built_side or manual != _built_manual:
		rebuild()
	else:
		layout()

# ------------------------------------------------------------------- build ---

func _needs_clutch() -> bool:
	if profile == null:
		return false
	# The pedal is always present in a car that has one. Clutch assist changes what
	# happens during a shift, it does not hide the pedal.
	return profile.requires_clutch

func _assist() -> bool:
	return SettingsService.clutch != "manual"

func rebuild() -> void:
	release_all()
	for child: Node in get_children():
		child.queue_free()
	widgets.clear()
	panel = null
	panel_open = false
	_built_preset = SettingsService.control_preset
	_built_side = SettingsService.control_left_handed
	_built_scale = SettingsService.control_scale
	_built_manual = _needs_clutch()

	var specs: Array[Dictionary] = _specs()
	for spec: Dictionary in specs:
		_add_widget(spec)
	_build_panel()
	layout()

func _add_widget(spec: Dictionary) -> void:
	var kind: String = String(spec.get("type", "button"))
	var widget: TouchWidget = null
	match kind:
		"slider":
			widget = TouchSlider.new()
		"pedal":
			widget = TouchPedal.new()
		_:
			widget = TouchButton.new()
	widget.name = "W_" + String(spec["id"])
	var rect: Rect2 = spec["rect"]
	if kind == "slider":
		(widget as TouchSlider).setup_slider(String(spec["id"]), rect, String(spec.get("caption", "")))
		(widget as TouchSlider).sensitivity = SettingsService.slider_sensitivity
		(widget as TouchSlider).release_rate = SettingsService.slider_release
	elif kind == "pedal":
		(widget as TouchPedal).setup_pedal(String(spec["id"]), rect, String(spec.get("art", "pedal_throttle")), String(spec.get("caption", "")))
		(widget as TouchPedal).release_rate = 9.0
	else:
		(widget as TouchButton).setup_button(String(spec["id"]), rect, String(spec.get("art", "pad_throttle")), String(spec.get("caption", "")))
	widget.modulate.a = SettingsService.control_opacity
	add_child(widget)
	widgets[widget.control_id] = widget
	widget.value_changed.connect(_on_widget_value.bind(widget))
	_apply_override(widget, spec)

func _build_panel() -> void:
	if profile == null:
		return
	panel = GearPanel.new()
	panel.name = "GearPanel"
	panel.setup(profile)
	panel.visible = false
	panel.modulate.a = 0.0
	add_child(panel)
	panel.gear_requested.connect(func(g: int) -> void: gear_requested.emit(g))
	panel.range_requested.connect(func(r: String) -> void: range_requested.emit(r))
	panel.set_state(0, "D", 0.0, 0.0, _assist())

func _on_widget_value(value: float, widget: TouchWidget) -> void:
	if value < 0.5:
		return
	match widget.control_id:
		"recover":
			recover_pressed.emit()
			SettingsService.vibrate(12)
		"start":
			start_pressed.emit()
			SettingsService.vibrate(12)
		"winch":
			winch_pressed.emit()
			SettingsService.vibrate(12)
		"gear":
			toggle_panel()

# ------------------------------------------------------------------ layout ---

func _u() -> float:
	var view: Vector2 = _view()
	var base: float = minf(view.y / 720.0, view.x / 1280.0)
	return clampf(base * SettingsService.control_scale, 0.55, 2.4)

func _view() -> Vector2:
	if size.length() > 1.0:
		return size
	return get_viewport().get_visible_rect().size

func _mirror(x: float) -> float:
	var w: float = _view().x
	return w - x if SettingsService.control_left_handed else x

func _specs() -> Array[Dictionary]:
	var u: float = _u()
	var m: float = SettingsService.control_margin * u
	var view: Vector2 = _view()
	var w: float = view.x
	var h: float = view.y
	var manual: bool = _needs_clutch()
	var show_clutch: bool = manual and SettingsService.show_clutch
	var specs: Array[Dictionary] = []

	match SettingsService.control_preset:
		"slider":
			specs.append(_spec("throttle", "slider", Vector2(w - 96.0 * u - m, h - 255.0 * u - m), Vector2(120.0, 330.0) * u, "", Loc.t("ctl_throttle")))
			specs.append(_spec("brake", "slider", Vector2(96.0 * u + m, h - 255.0 * u - m), Vector2(120.0, 330.0) * u, "", Loc.t("ctl_brake")))
			if show_clutch:
				specs.append(_spec("clutch", "slider", Vector2(216.0 * u + m, h - 252.0 * u - m), Vector2(96.0, 280.0) * u, "", Loc.t("ctl_clutch")))
			specs.append(_spec("handbrake", "button", Vector2(302.0 * u + m, h - 96.0 * u - m), Vector2(104, 104) * u, "pad_handbrake", Loc.t("ctl_handbrake")))
			specs.append(_spec("gear", "button", Vector2(w - 100.0 * u - m, h - 470.0 * u - m), Vector2(124, 124) * u, "icon_gear", Loc.t("ctl_gear")))
		"pedals":
			specs.append(_spec("throttle", "pedal", Vector2(w - 152.0 * u - m, h - 246.0 * u - m), Vector2(200.0, 404.0) * u, "pedal_throttle", Loc.t("ctl_throttle")))
			specs.append(_spec("brake", "pedal", Vector2(152.0 * u + m, h - 246.0 * u - m), Vector2(200.0, 404.0) * u, "pedal_brake", Loc.t("ctl_brake")))
			if show_clutch:
				specs.append(_spec("clutch", "pedal", Vector2(347.0 * u + m, h - 234.0 * u - m), Vector2(150.0, 360.0) * u, "pedal_clutch", Loc.t("ctl_clutch")))
			specs.append(_spec("handbrake", "button", Vector2(w * 0.5, h - 74.0 * u - m), Vector2(92, 92) * u, "pad_handbrake", ""))
			specs.append(_spec("gear", "button", Vector2(w - 128.0 * u - m, 196.0 * u + m), Vector2(118, 118) * u, "icon_gear", Loc.t("ctl_gear")))
		_:
			specs.append(_spec("throttle", "button", Vector2(w - 122.0 * u - m, h - 122.0 * u - m), Vector2(200, 200) * u, "pad_throttle", Loc.t("ctl_throttle")))
			specs.append(_spec("brake", "button", Vector2(122.0 * u + m, h - 122.0 * u - m), Vector2(178, 178) * u, "pad_brake", Loc.t("ctl_brake")))
			if show_clutch:
				specs.append(_spec("clutch", "button", Vector2(108.0 * u + m, h - 340.0 * u - m), Vector2(148, 148) * u, "pad_clutch", Loc.t("ctl_clutch")))
			specs.append(_spec("handbrake", "button", Vector2(300.0 * u + m, h - 136.0 * u - m), Vector2(104, 104) * u, "pad_handbrake", Loc.t("ctl_handbrake")))
			specs.append(_spec("gear", "button", Vector2(w - 118.0 * u - m, h - 342.0 * u - m), Vector2(132, 132) * u, "icon_gear", Loc.t("ctl_gear")))

	if SettingsService.show_recover:
		specs.append(_spec("recover", "button", Vector2(w - 74.0 * u - m, 168.0 * u + m), Vector2(92, 92) * u, "pad_recover", ""))
	if SettingsService.show_winch and _has_winch():
		specs.append(_spec("winch", "button", Vector2(w - 74.0 * u - m, 276.0 * u + m), Vector2(92, 92) * u, "icon_winch", ""))
	specs.append(_spec("start", "button", Vector2(w * 0.5, h - 218.0 * u - m), Vector2(104, 104) * u, "pad_start", ""))

	# Mirroring is applied once, here, so every preset and every override follow the
	# same rule instead of each control guessing which corner it lives in.
	if SettingsService.control_left_handed:
		for spec: Dictionary in specs:
			var r: Rect2 = spec["rect"]
			r.position.x = w - r.position.x - r.size.x
			spec["rect"] = r
	return specs

## `center` is the centre of the control, not its top-left: the layout numbers are
## authored as "this control sits here on the screen" and converted once.
func _spec(id: String, type: String, center: Vector2, dim: Vector2, art: String, caption: String) -> Dictionary:
	return {
		"id": id, "type": type, "rect": Rect2(center - dim * 0.5, dim), "art": art, "caption": caption,
	}

func _has_winch() -> bool:
	if vehicle != null and vehicle.definition != null:
		return vehicle.definition.has_winch
	return true

func _apply_override(widget: TouchWidget, spec: Dictionary) -> void:
	var key: String = SettingsService.control_preset + ":" + widget.control_id
	var raw: Variant = SettingsService.control_positions.get(key, null)
	if raw is Array and (raw as Array).size() >= 2:
		var view: Vector2 = _view()
		var cx: float = float((raw as Array)[0]) * view.x
		var cy: float = float((raw as Array)[1]) * view.y
		var rect: Rect2 = spec["rect"]
		widget.position = Vector2(cx, cy) - rect.size * 0.5

func layout() -> void:
	var view: Vector2 = _view()
	var specs: Array[Dictionary] = _specs()
	if OS.get_cmdline_args().has("--uidiag"):
		print("[ui] viewport=%s visible=%s own_size=%s widgets=%d" % [str(get_viewport().get_visible_rect().size), str(get_viewport().get_visible_rect()), str(size), widgets.size()])
	for spec: Dictionary in specs:
		var id: String = String(spec["id"])
		if not widgets.has(id):
			continue
		var widget: TouchWidget = widgets[id] as TouchWidget
		var rect: Rect2 = spec["rect"]
		widget.position = rect.position
		widget.size = rect.size
		widget.pivot_offset = rect.size * 0.5
		_apply_override(widget, spec)
		widget.modulate.a = SettingsService.control_opacity
	if panel != null:
		var pw: float = minf(view.x * 0.52, 720.0 * _u())
		var ph: float = minf(view.y * 0.66, 512.0 * _u())
		var px: float = view.x - pw - 20.0 * _u()
		var py: float = maxf(view.y * 0.23, (view.y - ph) * 0.5)
		if SettingsService.control_left_handed:
			px = 20.0 * _u()
		panel.position = Vector2(px, py)
		panel.size = Vector2(pw, ph)
		panel.pivot_offset = Vector2(pw, ph) * 0.5

# ------------------------------------------------------------------- input ---

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or profile == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var p: Vector2 = _to_local(touch.position)
		if touch.pressed:
			if _begin(touch.index, p):
				get_viewport().set_input_as_handled()
		else:
			if _end(touch.index):
				get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _move(drag.index, _to_local(drag.position)):
			get_viewport().set_input_as_handled()
		return
	if _use_mouse:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			var mp: Vector2 = _to_local(mb.position)
			if mb.pressed:
				if _begin(-1, mp):
					get_viewport().set_input_as_handled()
			else:
				if _end(-1):
					get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
			if _move(-1, _to_local((event as InputEventMouseMotion).position)):
				get_viewport().set_input_as_handled()

func _to_local(global_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_pos

func _begin(finger: int, p: Vector2) -> bool:
	if _fingers.has(finger):
		return false
	if edit_mode:
		for widget: TouchWidget in widgets.values():
			if widget.hit_test(p - widget.position):
				_edit_target = widget
				_edit_grab = p
				_edit_origin = widget.position
				_edit_moved = false
				return true
		return false
	if panel_open and panel != null and panel.hit_test(p - panel.position):
		_fingers[finger] = panel
		panel.press_at(p - panel.position, finger)
		return true
	var keys: Array = widgets.keys()
	for i: int in range(keys.size() - 1, -1, -1):
		var widget: TouchWidget = widgets[keys[i]] as TouchWidget
		if widget.hit_test(p - widget.position):
			_fingers[finger] = widget
			widget.press_at(p - widget.position, finger)
			return true
	return false

func _move(finger: int, p: Vector2) -> bool:
	if edit_mode:
		if _edit_target == null:
			return false
		var delta: Vector2 = p - _edit_grab
		if delta.length() > 2.0:
			_edit_moved = true
		_edit_target.position = _clamp_into(_edit_origin + delta, _edit_target.size)
		return true
	if not _fingers.has(finger):
		return false
	var target: Object = _fingers[finger]
	if target is GearPanel:
		(panel as GearPanel).drag_at(p - panel.position)
	else:
		var widget: TouchWidget = target as TouchWidget
		widget.drag_at(p - widget.position)
	return true

func _end(finger: int) -> bool:
	if edit_mode:
		if _edit_target != null:
			if _edit_moved:
				var center: Vector2 = _edit_target.position + _edit_target.size * 0.5
				SettingsService.set_control_position(SettingsService.control_preset + ":" + _edit_target.control_id,
					Vector2(center.x / maxf(size.x, 1.0), center.y / maxf(size.y, 1.0)))
				layout_changed.emit()
			_edit_target = null
			_edit_moved = false
			return true
		return false
	if not _fingers.has(finger):
		return false
	var target: Object = _fingers[finger]
	_fingers.erase(finger)
	if target is GearPanel:
		(panel as GearPanel).release_finger()
	else:
		(target as TouchWidget).release_finger()
	return true

func _clamp_into(pos: Vector2, dim: Vector2) -> Vector2:
	var view: Vector2 = _view()
	return Vector2(
		clampf(pos.x, 4.0, maxf(4.0, view.x - dim.x - 4.0)),
		clampf(pos.y, 4.0, maxf(4.0, view.y - dim.y - 4.0)))

# ------------------------------------------------------------------- state ---

func input_state() -> VehicleInputState:
	var s := VehicleInputState.new()
	s.throttle = maxf(_value_of("throttle"), InputRouter.throttle())
	s.brake = maxf(_value_of("brake"), InputRouter.brake())
	s.handbrake = maxf(_value_of("handbrake"), InputRouter.handbrake())
	var touch_clutch: float = _value_of("clutch")
	var key_clutch: float = 1.0 - InputRouter.clutch()
	s.clutch = maxf(touch_clutch, key_clutch)
	s.source = "touch" if _any_active() else ("keyboard" if s.throttle > 0.0 or s.brake > 0.0 or s.clutch > 0.0 else "none")
	return s

func _value_of(id: String) -> float:
	if not widgets.has(id):
		return 0.0
	return (widgets[id] as TouchWidget).value

func _any_active() -> bool:
	for widget: TouchWidget in widgets.values():
		if widget.active:
			return true
	return panel != null and panel.visible and panel.is_dragging()

func clutch_pedal() -> float:
	return _value_of("clutch")

func release_all() -> void:
	_fingers.clear()
	_edit_target = null
	for widget: TouchWidget in widgets.values():
		widget.reset()
	if panel != null:
		panel.reset_finger()
	_close_timer = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release_all()

# ------------------------------------------------------------------- panel ---

func toggle_panel() -> void:
	if panel == null:
		return
	if panel_open:
		close_panel()
	else:
		open_panel()

func open_panel() -> void:
	if panel == null or edit_mode:
		return
	panel_open = true
	panel.visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	_panel_tween.tween_property(panel, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioDirector.play("ui_confirm", -12.0)
	panel_opened.emit()

func close_panel() -> void:
	if panel == null:
		return
	panel_open = false
	panel.reset_finger()
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(panel, "modulate:a", 0.0, 0.12)
	_panel_tween.tween_property(panel, "scale", Vector2(0.96, 0.96), 0.12)
	_panel_tween.tween_callback(func() -> void: panel.visible = false)
	panel_closed.emit()

## Race scene reports the outcome of a shift request so the lever can snap back or
## latch into the engaged gear.
func on_shift_result(accepted: bool, reason: String = "") -> void:
	if panel == null:
		return
	if accepted:
		var gear: int = 0
		if vehicle != null and vehicle.gearbox != null:
			gear = vehicle.gearbox.gear
		panel.confirm_shift(gear)
		_close_timer = 0.55
		AudioDirector.play("gear_engage", -10.0, randf_range(0.97, 1.05))
	else:
		panel.flash_reject(reason)
		AudioDirector.play("gear_grind", -8.0)

func update_live(gear: int, range_id: String, clutch: float, speed: float, assist: bool) -> void:
	if panel == null:
		return
	panel.set_state(gear, range_id, clutch, speed, assist)
	if _close_timer > 0.0:
		_close_timer -= get_process_delta_time()
		if _close_timer <= 0.0:
			close_panel()

func set_edit_mode(on: bool) -> void:
	edit_mode = on
	release_all()
	if panel != null:
		panel.visible = false
		panel_open = false
	for widget: TouchWidget in widgets.values():
		widget.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if not edit_mode:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.04, 0.55), true)
	for widget: TouchWidget in widgets.values():
		var r := Rect2(widget.position, widget.size)
		draw_rect(r.grow(3.0), Color(0.93, 0.62, 0.24, 0.75), false, 2.0)
		draw_rect(r, Color(0.93, 0.62, 0.24, 0.08), true)
