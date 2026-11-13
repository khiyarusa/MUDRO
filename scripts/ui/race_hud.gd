class_name RaceHUD
extends CanvasLayer
## Race HUD and touch controls. Every touch button drives the same InputMap action
## as the keyboard, so the simulation cannot tell them apart.

signal resume_pressed
signal restart_pressed
signal quit_pressed
signal retry_pressed
signal continue_pressed
signal garage_pressed
signal paused_changed(paused: bool)

var vehicle: VehicleBody
var stage: StageDef
var objective_text: String = ""

var _root: Control
var _timer_label: Label
var _speed_label: Label
var _gear_label: Label
var _objective_label: Label
var _checkpoint_label: Label
var _damage_bar: ProgressBar
var _rpm_bar: ProgressBar
var _rpm_fill: StyleBoxFlat
var _countdown_label: Label
var _pause_panel: Control
var _results_panel: Control
var _touch_buttons: Array[TouchScreenButton] = []
var _start_hint: Label
var _toast_label: Label
var _start_button: TouchScreenButton
var _tex_cache: Dictionary = {}

func setup(v: VehicleBody, def: StageDef, objective: String) -> void:
	vehicle = v
	stage = def
	objective_text = objective
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _build() -> void:
	_root = Control.new()
	_root.theme = UIKit.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- top-left: pause + timer ---
	var pause_btn := UIKit.button("", false, "pause")
	pause_btn.custom_minimum_size = Vector2(56, 56)
	pause_btn.name = "PauseButton"
	pause_btn.pressed.connect(func() -> void: _on_pause())
	_root.add_child(pause_btn)
	pause_btn.set_meta("role", "pause")

	var timer_panel := UIKit.hud_panel(10)
	timer_panel.name = "TimerPanel"
	_root.add_child(timer_panel)
	var timer_box := UIKit.vbox(0)
	timer_panel.get_child(0).add_child(timer_box)
	_timer_label = UIKit.label("00:00.00", 32, UIKit.IVORY, "black")
	_timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	timer_box.add_child(_timer_label)
	_checkpoint_label = UIKit.caption("CHECKPOINT 0/0")
	timer_box.add_child(_checkpoint_label)

	# --- top-right: objective + integrity ---
	var right_panel := UIKit.hud_panel(10)
	right_panel.name = "ObjectivePanel"
	_root.add_child(right_panel)
	var rb := UIKit.vbox(4)
	right_panel.get_child(0).add_child(rb)
	_objective_label = UIKit.caption(objective_text)
	_objective_label.custom_minimum_size = Vector2(260, 0)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_LEFT
	rb.add_child(_objective_label)
	_damage_bar = ProgressBar.new()
	_damage_bar.max_value = 100.0
	_damage_bar.value = 100.0
	_damage_bar.show_percentage = false
	_damage_bar.custom_minimum_size = Vector2(260, 8)
	_damage_bar.add_theme_stylebox_override("background", _bar_style(Color(1, 1, 1, 0.14)))
	_damage_bar.add_theme_stylebox_override("fill", _bar_style(UIKit.TEAL))
	rb.add_child(_damage_bar)

	# --- bottom centre: gear + speed + rpm ---
	var drive_panel := UIKit.hud_panel(12)
	drive_panel.name = "DrivePanel"
	_root.add_child(drive_panel)

	var drive := HBoxContainer.new()
	drive.add_theme_constant_override("separation", 18)
	drive_panel.get_child(0).add_child(drive)

	var gear_box := UIKit.vbox(-6)
	var gear_caption := UIKit.caption(Loc.t("hud_gear"))
	gear_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_box.add_child(gear_caption)
	_gear_label = UIKit.label("N", 46, UIKit.AMBER, "black")
	_gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear_label.custom_minimum_size = Vector2(56, 0)
	gear_box.add_child(_gear_label)
	drive.add_child(gear_box)

	var speed_box := UIKit.vbox(-6)
	speed_box.custom_minimum_size = Vector2(150, 0)
	var speed_caption := UIKit.caption(Loc.t("hud_speed") + " · " + Loc.t("hud_kmh"))
	speed_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_box.add_child(speed_caption)
	_speed_label = UIKit.label("0", 48, UIKit.IVORY, "black")
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_box.add_child(_speed_label)
	drive.add_child(speed_box)

	var rpm_box := UIKit.vbox(4)
	rpm_box.custom_minimum_size = Vector2(230, 0)
	rpm_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rpm_caption := UIKit.caption(Loc.t("hud_rpm"))
	rpm_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rpm_box.add_child(rpm_caption)
	_rpm_bar = ProgressBar.new()
	_rpm_bar.max_value = 100.0
	_rpm_bar.value = 0.0
	_rpm_bar.show_percentage = false
	_rpm_bar.custom_minimum_size = Vector2(230, 22)
	_rpm_bar.add_theme_stylebox_override("background", _bar_style(Color(1, 1, 1, 0.14)))
	_rpm_fill = _bar_style(UIKit.AMBER)
	_rpm_bar.add_theme_stylebox_override("fill", _rpm_fill)
	rpm_box.add_child(_rpm_bar)
	drive.add_child(rpm_box)

	# --- touch controls ---
	_add_touch("throttle", "throttle", 84, Color(0.16, 0.42, 0.30, 0.55))
	_add_touch("brake", "brake", 74, Color(0.46, 0.18, 0.16, 0.55))
	_add_touch("gear_up", "chevron_down", 46, Color(0.18, 0.19, 0.21, 0.6), true)
	_add_touch("gear_down", "chevron_down", 46, Color(0.18, 0.19, 0.21, 0.6))
	_add_touch("handbrake", "handbrake", 44, Color(0.24, 0.20, 0.16, 0.6))
	_add_touch("recover", "reset", 36, Color(0.18, 0.19, 0.21, 0.6))
	_add_touch("start_engine", "play", 40, Color(0.30, 0.26, 0.14, 0.65))
	for b: TouchScreenButton in _touch_buttons:
		if String(b.get_meta("action_key", "")) == "start_engine":
			_start_button = b
			b.visible = false

	# --- countdown & toast ---
	_countdown_label = UIKit.label("", 120, UIKit.IVORY, "black")
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_constant_override("outline_size", 12)
	_countdown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_countdown_label)

	_toast_label = UIKit.label("", 22, UIKit.AMBER, "bold")
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_label)

	_start_hint = UIKit.caption("")
	_start_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_start_hint)

	_build_pause()
	_build_results()
	_disable_wrap(timer_panel)
	_disable_wrap(right_panel)
	_disable_wrap(drive_panel)

func _disable_wrap(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Label:
			(child as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		_disable_wrap(child)

func _bar_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	return sb

func _add_touch(action: String, icon_name: String, radius: int, tint: Color, flip: bool = false) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var btn := TouchScreenButton.new()
	btn.name = "Touch_" + action
	btn.action = action
	btn.texture_normal = _button_texture(icon_name, radius, tint, false, flip)
	btn.texture_pressed = _button_texture(icon_name, radius, tint, true, flip)
	btn.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	btn.passby_press = false
	var circle := CircleShape2D.new()
	circle.radius = float(radius)
	btn.shape = circle
	btn.shape_centered = true
	btn.set_meta("radius", radius)
	btn.set_meta("action_key", action)
	_root.add_child(btn)
	_touch_buttons.append(btn)

func _button_texture(icon_name: String, radius: int, tint: Color, pressed: bool, flip: bool = false) -> ImageTexture:
	var key: String = "%s_%d_%s_%s_%s" % [icon_name, radius, tint.to_html(), str(pressed), str(flip)]
	if _tex_cache.has(key):
		return _tex_cache[key] as ImageTexture
	var size: int = radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base: Color = tint.lightened(0.28) if pressed else tint
	var ring: Color = Color(0.96, 0.93, 0.88, 0.92) if pressed else Color(0.96, 0.93, 0.88, 0.34)
	var r2: float = float(radius * radius)
	var inner: float = float((radius - 4) * (radius - 4))
	for y: int in range(size):
		var dy: float = float(y) - float(radius)
		for x: int in range(size):
			var dx: float = float(x) - float(radius)
			var d2: float = dx * dx + dy * dy
			if d2 <= r2:
				if d2 >= inner:
					img.set_pixel(x, y, ring)
				else:
					var shade: float = 1.0 + 0.12 * (1.0 - clampf(dy / float(radius), -1.0, 1.0))
					img.set_pixel(x, y, Color(base.r * shade, base.g * shade, base.b * shade, base.a))
	var icon_path: String = "res://assets/ui/icons/%s.svg" % icon_name
	if FileAccess.file_exists(icon_path):
		var icon := Image.new()
		var err: int = icon.load_svg_from_string(FileAccess.get_file_as_string(icon_path), 1.0)
		if err == OK and not icon.is_empty():
			var target: int = int(float(size) * 0.46)
			icon.convert(Image.FORMAT_RGBA8)
			icon.resize(target, target, Image.INTERPOLATE_LANCZOS)
			if flip:
				icon.flip_y()
			var pos := Vector2i((size - target) / 2, (size - target) / 2)
			img.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), pos)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

func _layout() -> void:
	if _root == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var w: float = view.x
	var h: float = view.y
	var scale_f: float = SettingsService.control_scale
	var pause_btn: Button = _root.get_node_or_null("PauseButton") as Button
	if pause_btn != null:
		pause_btn.position = Vector2(24, 20)
		pause_btn.custom_minimum_size = Vector2(58, 58)
		pause_btn.reset_size()
	var timer_panel: Control = _root.get_node_or_null("TimerPanel") as Control
	if timer_panel != null:
		timer_panel.position = Vector2(92, 18)
		timer_panel.custom_minimum_size = Vector2(220, 92)
		timer_panel.size = Vector2(220, 92)
	var right_panel: Control = _root.get_node_or_null("ObjectivePanel") as Control
	if right_panel != null:
		right_panel.custom_minimum_size = Vector2(292, 78)
		right_panel.size = Vector2(292, 78)
		right_panel.position = Vector2(w - 316, 18)
	var drive_panel: Control = _root.get_node_or_null("DrivePanel") as Control
	if drive_panel != null:
		drive_panel.custom_minimum_size = Vector2(560, 104)
		drive_panel.size = Vector2(560, 104)
		drive_panel.position = Vector2((w - 560) * 0.5, h - 120)

	_countdown_label.position = Vector2(0, h * 0.32)
	_countdown_label.size = Vector2(w, 160)
	_toast_label.position = Vector2(0, h * 0.22)
	_toast_label.size = Vector2(w, 40)
	_start_hint.position = Vector2(0, h - 172)
	_start_hint.size = Vector2(w, 30)

	var positions: Dictionary = {
		"throttle": Vector2(w - 96, h - 92),
		"brake": Vector2(96, h - 92),
		"gear_up": Vector2(w - 96, h - 250),
		"gear_down": Vector2(w - 228, h - 104),
		"handbrake": Vector2(224, h - 112),
		"recover": Vector2(w - 58, 118),
		"start_engine": Vector2(w * 0.5, h - 210),
	}
	for btn: TouchScreenButton in _touch_buttons:
		var action_key: String = String(btn.get_meta("action_key", ""))
		if not positions.has(action_key):
			continue
		var radius: float = float(btn.get_meta("radius", 44)) * scale_f
		var center: Vector2 = positions[action_key] as Vector2
		btn.position = center - Vector2(radius, radius)
		btn.scale = Vector2.ONE * scale_f

	if _pause_panel != null:
		_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _results_panel != null:
		_results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	if vehicle == null or _timer_label == null:
		return
	var t: Dictionary = vehicle.telemetry
	if t.is_empty():
		return
	var speed: float = float(t.get("speed_kmh", 0.0))
	_speed_label.text = str(int(round(speed)))
	var gear_value: int = int(t.get("gear", 0))
	_gear_label.text = "N" if gear_value == 0 else ("R" if gear_value == -1 else str(gear_value))
	_gear_label.add_theme_color_override("font_color", UIKit.AMBER if gear_value > 0 else UIKit.MUTED)
	var rpm: float = float(t.get("rpm", 0.0))
	var redline: float = 6000.0
	if vehicle.definition != null and vehicle.definition.engine != null:
		redline = vehicle.definition.engine.redline_rpm
	_rpm_bar.value = clampf(rpm / maxf(redline, 1.0) * 100.0, 0.0, 100.0)
	var in_red: bool = rpm >= redline * 0.94
	_rpm_fill.bg_color = UIKit.RED if in_red else UIKit.AMBER
	var health: float = float(t.get("damage", 1.0))
	_damage_bar.value = clampf(health * 100.0, 0.0, 100.0)
	_damage_bar.add_theme_stylebox_override("fill", _bar_style(UIKit.TEAL if health > 0.6 else (UIKit.AMBER if health > 0.3 else UIKit.RED)))
	_start_hint.text = Loc.t("race_stalled_hint") if vehicle.engine != null and not vehicle.engine.running else ""
	if _start_button != null:
		_start_button.visible = vehicle.engine != null and not vehicle.engine.running

func set_time(seconds: float) -> void:
	if _timer_label != null:
		_timer_label.text = UIKit.format_time(seconds)

func set_checkpoint(index: int, total: int) -> void:
	if _checkpoint_label != null:
		_checkpoint_label.text = "%s %d/%d" % [Loc.t("hud_checkpoint"), index, total]

func show_countdown(text: String) -> void:
	if _countdown_label == null:
		return
	_countdown_label.text = text
	_countdown_label.scale = Vector2.ONE
	_countdown_label.pivot_offset = _countdown_label.size * 0.5
	var tw := create_tween()
	tw.tween_property(_countdown_label, "scale", Vector2(1.18, 1.18), 0.16)
	tw.tween_property(_countdown_label, "scale", Vector2.ONE, 0.28)

func hide_countdown() -> void:
	if _countdown_label != null:
		_countdown_label.text = ""

func toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.4)

func _build_pause() -> void:
	_pause_panel = Control.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_pause_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(center)
	var panel := UIKit.panel(22)
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var title := UIKit.title(Loc.t("pause_title"), 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(UIKit.divider())
	var resume := UIKit.button(Loc.t("pause_resume"), true, "play")
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	v.add_child(resume)
	var restart := UIKit.button(Loc.t("pause_restart"), false, "restart")
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	v.add_child(restart)
	var quit := UIKit.button(Loc.t("pause_quit"), false, "home")
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	v.add_child(quit)

func _build_results() -> void:
	_results_panel = Control.new()
	_results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_panel.visible = false
	_results_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_results_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_panel.add_child(center)
	var panel := UIKit.panel(24)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.name = "ResultsCard"
	center.add_child(panel)

func show_pause(visible_state: bool) -> void:
	if _pause_panel != null:
		_pause_panel.visible = visible_state

func show_results(result: Dictionary) -> void:
	if _results_panel == null:
		return
	var card: Control = _results_panel.get_node_or_null("CenterContainer/ResultsCard")
	if card == null:
		card = _results_panel.get_child(1).get_child(0)
	for c: Node in card.get_children():
		c.queue_free()
	var v := UIKit.vbox(8)
	card.add_child(v)

	var head := UIKit.hbox(12)
	var medal: int = int(result.get("medal", 0))
	var medal_tex := UIKit.medal_icon(medal, 64)
	head.add_child(medal_tex)
	var title_box := UIKit.vbox(0)
	title_box.add_child(UIKit.title(Loc.t("results_title"), 32))
	title_box.add_child(UIKit.caption(String(result.get("stage_name", ""))))
	head.add_child(title_box)
	head.add_child(UIKit.spacer(0))
	v.add_child(head)
	v.add_child(UIKit.divider())

	var time_row := UIKit.stat_row(Loc.t("results_time"), UIKit.format_time(float(result.get("time", 0.0))), UIKit.AMBER)
	v.add_child(time_row)
	var best_row := UIKit.stat_row(Loc.t("results_best"), UIKit.format_time(float(result.get("best", 0.0))))
	v.add_child(best_row)
	if bool(result.get("new_best", false)):
		var nb := UIKit.label(Loc.t("results_new_best"), 20, UIKit.GOLD, "bold")
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nb)

	var reward_row := UIKit.hbox(8)
	reward_row.add_child(UIKit.icon("coin", 22, UIKit.GOLD))
	reward_row.add_child(UIKit.label("+%d" % int(result.get("credits", 0)), 20, UIKit.GOLD, "bold"))
	reward_row.add_child(UIKit.spacer(0))
	reward_row.add_child(UIKit.label("%s %d%%" % [Loc.t("results_damage"), int((1.0 - float(result.get("damage", 1.0))) * 100.0)], 17, UIKit.MUTED))
	v.add_child(reward_row)
	v.add_child(UIKit.divider())

	var actions := UIKit.hbox(10)
	var retry := UIKit.button(Loc.t("results_retry"), true, "restart")
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	actions.add_child(retry)
	var cont := UIKit.button(Loc.t("results_continue"), false, "arrow_left" if Loc.is_rtl() else "arrow_right")
	cont.pressed.connect(func() -> void: continue_pressed.emit())
	actions.add_child(cont)
	var garage := UIKit.button(Loc.t("results_garage"), false, "garage")
	garage.pressed.connect(func() -> void: garage_pressed.emit())
	actions.add_child(garage)
	v.add_child(actions)
	_results_panel.visible = true

func hide_results() -> void:
	if _results_panel != null:
		_results_panel.visible = false

func _on_pause() -> void:
	paused_changed.emit(true)
