class_name RaceHUD
extends CanvasLayer
## Race HUD: timing, telemetry and the driveline state, plus pause and results.
## Touch controls live in their own layer (TouchControls) so the HUD never competes
## with them for a finger.

signal resume_pressed
signal restart_pressed
signal quit_pressed
signal retry_pressed
signal continue_pressed
signal garage_pressed
signal paused_changed(paused: bool)
signal transfer_pressed
signal diff_pressed
signal winch_pressed
signal layout_pressed

var vehicle: VehicleBody
var stage: StageDef
var objective_text: String = ""

var _root: Control
var _timer_label: Label
var _speed_label: Label
var _gear_label: Label
var _gearbox_label: Label
var _objective_label: Label
var _checkpoint_label: Label
var _damage_bar: ProgressBar
var _rpm_bar: ProgressBar
var _rpm_fill: StyleBoxFlat
var _clutch_bar: ProgressBar
var _clutch_fill: StyleBoxFlat
var _countdown_label: Label
var _pause_panel: Control
var _results_panel: Control
var _start_hint: Label
var _toast_label: Label
var _transfer_btn: Button
var _diff_btn: Button
var _winch_btn: Button
var _weather_label: Label
var _status_row: HBoxContainer
var _timer_panel: Panel
var _right_panel: Panel
var _drive_panel: Panel
var _pause_btn: Button
var _safe: Rect2

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

	_pause_btn = UIKit.button("", false, "pause")
	_pause_btn.name = "PauseButton"
	_pause_btn.custom_minimum_size = Vector2(58, 58)
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.pressed.connect(_on_pause)
	_root.add_child(_pause_btn)

	_timer_panel = UIKit.hud_panel(12)
	_timer_panel.name = "TimerPanel"
	_root.add_child(_timer_panel)
	var timer_box := UIKit.vbox(0)
	_timer_panel.get_child(0).add_child(timer_box)
	_timer_label = UIKit.value_label("00:00.00", 34, UIKit.IVORY)
	timer_box.add_child(_timer_label)
	_checkpoint_label = UIKit.caption("CHECKPOINT 0/0")
	timer_box.add_child(_checkpoint_label)

	_right_panel = UIKit.hud_panel(12)
	_right_panel.name = "ObjectivePanel"
	_root.add_child(_right_panel)
	var rb := UIKit.vbox(5)
	_right_panel.get_child(0).add_child(rb)
	_objective_label = UIKit.caption(objective_text)
	_objective_label.custom_minimum_size = Vector2(268, 0)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_LEFT
	rb.add_child(_objective_label)
	_weather_label = UIKit.caption("")
	_weather_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.76))
	_weather_label.horizontal_alignment = _objective_label.horizontal_alignment
	rb.add_child(_weather_label)
	var health_row := UIKit.hbox(8)
	var health_cap := UIKit.caption(Loc.t("hud_damage"))
	health_row.add_child(health_cap)
	_damage_bar = ProgressBar.new()
	_damage_bar.max_value = 100.0
	_damage_bar.value = 100.0
	_damage_bar.show_percentage = false
	_damage_bar.custom_minimum_size = Vector2(0, 8)
	_damage_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_damage_bar.add_theme_stylebox_override("background", _bar_style(Color(1, 1, 1, 0.13), 3))
	_damage_bar.add_theme_stylebox_override("fill", _bar_style(UIKit.TEAL, 3))
	health_row.add_child(_damage_bar)
	rb.add_child(health_row)

	# --- driveline chips: transfer case, differential, winch, weather ---
	_status_row = UIKit.hbox(6)
	_status_row.name = "StatusRow"
	_root.add_child(_status_row)
	_transfer_btn = _chip("2H", "icon_drivetrain")
	_transfer_btn.pressed.connect(func() -> void: transfer_pressed.emit())
	_status_row.add_child(_transfer_btn)
	_diff_btn = _chip("OPEN", "differential")
	_diff_btn.pressed.connect(func() -> void: diff_pressed.emit())
	_status_row.add_child(_diff_btn)
	_winch_btn = _chip(Loc.t("ctl_winch"), "icon_winch")
	_winch_btn.pressed.connect(func() -> void: winch_pressed.emit())
	_status_row.add_child(_winch_btn)

	# --- bottom centre telemetry ---
	_drive_panel = UIKit.hud_panel(12)
	_drive_panel.name = "DrivePanel"
	_root.add_child(_drive_panel)
	var drive := HBoxContainer.new()
	drive.add_theme_constant_override("separation", 16)
	_drive_panel.get_child(0).add_child(drive)

	var gear_box := UIKit.vbox(-8)
	var gear_caption := UIKit.caption(Loc.t("hud_gear"))
	gear_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_box.add_child(gear_caption)
	_gear_label = UIKit.value_label("N", 46, UIKit.AMBER)
	_gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear_label.custom_minimum_size = Vector2(58, 0)
	gear_box.add_child(_gear_label)
	_gearbox_label = UIKit.caption("")
	_gearbox_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gearbox_label.custom_minimum_size = Vector2(128, 0)
	gear_box.add_child(_gearbox_label)
	drive.add_child(gear_box)

	var speed_box := UIKit.vbox(-8)
	speed_box.custom_minimum_size = Vector2(132, 0)
	var speed_caption := UIKit.caption(Loc.t("hud_kmh"))
	speed_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_box.add_child(speed_caption)
	_speed_label = UIKit.value_label("0", 46, UIKit.IVORY)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_box.add_child(_speed_label)
	drive.add_child(speed_box)

	var rpm_box := UIKit.vbox(4)
	rpm_box.custom_minimum_size = Vector2(212, 0)
	rpm_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rpm_caption := UIKit.caption(Loc.t("hud_rpm"))
	rpm_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rpm_box.add_child(rpm_caption)
	_rpm_bar = ProgressBar.new()
	_rpm_bar.max_value = 100.0
	_rpm_bar.show_percentage = false
	_rpm_bar.custom_minimum_size = Vector2(212, 16)
	_rpm_bar.add_theme_stylebox_override("background", _bar_style(Color(1, 1, 1, 0.13), 4))
	_rpm_fill = _bar_style(UIKit.AMBER, 4)
	_rpm_bar.add_theme_stylebox_override("fill", _rpm_fill)
	rpm_box.add_child(_rpm_bar)
	var clutch_caption := UIKit.caption(Loc.t("hud_clutch"))
	clutch_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rpm_box.add_child(clutch_caption)
	_clutch_bar = ProgressBar.new()
	_clutch_bar.max_value = 100.0
	_clutch_bar.show_percentage = false
	_clutch_bar.custom_minimum_size = Vector2(212, 8)
	_clutch_bar.add_theme_stylebox_override("background", _bar_style(Color(1, 1, 1, 0.10), 3))
	_clutch_fill = _bar_style(UIKit.TEAL, 3)
	_clutch_bar.add_theme_stylebox_override("fill", _clutch_fill)
	rpm_box.add_child(_clutch_bar)
	drive.add_child(rpm_box)

	_countdown_label = UIKit.title("", 112)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_countdown_label)

	_toast_label = UIKit.label("", 21, UIKit.AMBER, "bold")
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_label)

	_start_hint = UIKit.caption("")
	_start_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_start_hint)

	_build_pause()
	_build_results()
	for node: Control in [_timer_panel, _right_panel, _drive_panel]:
		_disable_wrap(node)

func _chip(text: String, icon_name: String) -> Button:
	var b := UIKit.button(text, false, icon_name)
	b.custom_minimum_size = Vector2(94, 42)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("icon_max_width", 22)
	return b

func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb

func _disable_wrap(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Label:
			(child as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		_disable_wrap(child)

func _layout() -> void:
	if _root == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var w: float = view.x
	var h: float = view.y
	var safe: Rect2 = _safe_rect(view)
	var left: float = safe.position.x
	var top: float = safe.position.y
	var right: float = safe.end.x
	var bottom: float = safe.end.y

	if _pause_btn != null:
		_pause_btn.position = Vector2(left + 14.0, top + 12.0)
		_pause_btn.size = Vector2(56, 56)
	if _timer_panel != null:
		_timer_panel.position = Vector2(left + 80.0, top + 10.0)
		_timer_panel.size = Vector2(214, 86)
	if _right_panel != null:
		_right_panel.size = Vector2(300, 104)
		_right_panel.position = Vector2(right - 314.0, top + 10.0)
	if _status_row != null:
		_status_row.position = Vector2(right - 314.0, top + 122.0)
		_status_row.size = Vector2(300, 44)
	if _drive_panel != null:
		var pw: float = minf(520.0, w * 0.46)
		_drive_panel.size = Vector2(pw, 128)
		_drive_panel.position = Vector2((w - pw) * 0.5, bottom - 140.0)
	_countdown_label.position = Vector2(0, h * 0.28)
	_countdown_label.size = Vector2(w, 150)
	_toast_label.position = Vector2(0, h * 0.19)
	_toast_label.size = Vector2(w, 36)
	_start_hint.position = Vector2(0, bottom - 150.0)
	_start_hint.size = Vector2(w, 28)
	if _pause_panel != null:
		_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _results_panel != null:
		_results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

## Android cutouts and rounded corners: keep critical UI inside the reported safe
## area when the platform provides one, otherwise use a small symmetric margin.
func _safe_rect(view: Vector2) -> Rect2:
	var sys_size: Vector2 = Vector2(DisplayServer.screen_get_size())
	if sys_size.x > 0.0 and sys_size.y > 0.0 and OS.has_feature("mobile"):
		var area: Rect2i = DisplayServer.get_display_safe_area()
		if area.size.x > 0 and area.size.y > 0 and (area.size.x < int(sys_size.x) or area.size.y < int(sys_size.y) or area.position.x > 0):
			var sx: float = view.x / sys_size.x
			var sy: float = view.y / sys_size.y
			return Rect2(Vector2(area.position.x * sx, area.position.y * sy), Vector2(area.size.x * sx, area.size.y * sy))
	return Rect2(Vector2(8, 6), view - Vector2(16, 12))

func _process(_delta: float) -> void:
	if vehicle == null or _timer_label == null:
		return
	var t: Dictionary = vehicle.telemetry
	if t.is_empty():
		return
	_speed_label.text = str(int(round(float(t.get("speed_kmh", 0.0)))))
	var gear_value: int = int(t.get("gear", 0))
	var gear_text: String = String(t.get("gear_label", "N"))
	_gear_label.text = gear_text if String(t.get("range", "")) == "" or not bool(t.get("auto", false)) else String(t.get("range", gear_text))
	_gear_label.add_theme_color_override("font_color", UIKit.AMBER if gear_value > 0 else (UIKit.RED if gear_value < 0 else UIKit.MUTED))
	var rpm: float = float(t.get("rpm", 0.0))
	var redline: float = 6000.0
	if vehicle.definition != null and vehicle.definition.engine != null:
		redline = vehicle.definition.engine.redline_rpm
	_rpm_bar.value = clampf(rpm / maxf(redline, 1.0) * 100.0, 0.0, 100.0)
	_rpm_fill.bg_color = UIKit.RED if rpm >= redline * 0.94 else UIKit.AMBER
	var health: float = float(t.get("damage", 1.0))
	_damage_bar.value = clampf(health * 100.0, 0.0, 100.0)
	_damage_bar.add_theme_stylebox_override("fill", _bar_style(UIKit.TEAL if health > 0.6 else (UIKit.AMBER if health > 0.3 else UIKit.RED), 3))

	var pedal: float = float(t.get("clutch_pedal", 0.0))
	_clutch_bar.value = clampf(pedal * 100.0, 0.0, 100.0)
	_clutch_fill.bg_color = UIKit.TEAL if pedal >= VehicleInputState.CLUTCH_FULL else UIKit.AMBER
	_gearbox_label.text = _gearbox_text(t)

	var transfer: String = String(t.get("transfer", ""))
	_transfer_btn.visible = transfer != ""
	if transfer != "":
		_transfer_btn.text = transfer
		_transfer_btn.add_theme_color_override("font_color", UIKit.AMBER if transfer.begins_with("4") else UIKit.MUTED)
	var diff: String = String(t.get("diff", "open"))
	_diff_btn.text = diff.to_upper()
	_diff_btn.add_theme_color_override("font_color", UIKit.AMBER if diff != "open" else UIKit.MUTED)
	_winch_btn.visible = vehicle.definition != null and vehicle.definition.has_winch
	_start_hint.text = Loc.t("race_stalled_hint") if vehicle.engine != null and not vehicle.engine.running else ""

func _gearbox_text(t: Dictionary) -> String:
	var profile: TransmissionProfile = vehicle.gearbox.profile if vehicle.gearbox != null else null
	if profile == null:
		return ""
	if profile.is_automatic():
		if bool(t.get("kickdown", false)):
			return Loc.t("gearbox_kickdown")
		return Loc.t("gearbox_auto")
	if bool(t.get("shifting", false)):
		return Loc.t("gearbox_shifting")
	if profile.is_h_pattern():
		return Loc.t("gearbox_manual_h")
	return Loc.t("gearbox_manual_seq")

func set_weather(text: String) -> void:
	if _weather_label != null:
		_weather_label.text = text

func set_winch_state(attached: bool, tension_kn: float) -> void:
	if _winch_btn == null:
		return
	_winch_btn.text = String(Loc.t("ctl_winch")) + (" · %.1ft" % tension_kn if attached else "")

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
	tw.tween_property(_countdown_label, "scale", Vector2(1.16, 1.16), 0.16)
	tw.tween_property(_countdown_label, "scale", Vector2.ONE, 0.26)

func hide_countdown() -> void:
	if _countdown_label != null:
		_countdown_label.text = ""

func toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.35)

func _build_pause() -> void:
	_pause_panel = Control.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_pause_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.84)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(center)
	var panel := UIKit.panel(22)
	panel.custom_minimum_size = Vector2(440, 0)
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
	var layout := UIKit.button(Loc.t("pause_controls"), false, "settings")
	layout.pressed.connect(func() -> void: layout_pressed.emit())
	v.add_child(layout)
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
	head.add_child(UIKit.medal_icon(medal, 64))
	var title_box := UIKit.vbox(0)
	title_box.add_child(UIKit.title(Loc.t("results_title"), 32))
	title_box.add_child(UIKit.caption(String(result.get("stage_name", ""))))
	head.add_child(title_box)
	head.add_child(UIKit.spacer(0))
	v.add_child(head)
	v.add_child(UIKit.divider())

	v.add_child(UIKit.stat_row(Loc.t("results_time"), UIKit.format_time(float(result.get("time", 0.0))), UIKit.AMBER))
	v.add_child(UIKit.stat_row(Loc.t("results_best"), UIKit.format_time(float(result.get("best", 0.0)))))
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
