extends Control
## Settings: working controls for audio, locale, quality, controls and gameplay.

var _content: VBoxContainer

func _ready() -> void:
	UIKit.root(self)
	_build()

func _build() -> void:
	for c: Node in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.047, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	col.add_child(header)
	var back := UIKit.button(Loc.t("back"), false, "arrow_right" if Loc.is_rtl() else "arrow_left")
	back.custom_minimum_size = Vector2(150, 54)
	back.pressed.connect(func() -> void: Router.goto("res://scenes/menus/main_menu.tscn"))
	header.add_child(back)
	header.add_child(UIKit.title(Loc.t("settings_title"), 40))
	header.add_child(UIKit.spacer(0))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_content = UIKit.vbox(10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

	_section(Loc.t("settings_language"))
	_content.add_child(_option_row("", [
		{"label": Loc.t("settings_language_fa"), "value": "fa"},
		{"label": Loc.t("settings_language_en"), "value": "en"},
	], SettingsService.language, _on_language))

	_section(Loc.t("settings_audio"))
	_content.add_child(_slider_row(Loc.t("settings_master"), "master", SettingsService.master))
	_content.add_child(_slider_row(Loc.t("settings_engine"), "engine", SettingsService.engine))
	_content.add_child(_slider_row(Loc.t("settings_sfx"), "sfx", SettingsService.sfx))
	_content.add_child(_slider_row(Loc.t("settings_music"), "music", SettingsService.music))

	_section(Loc.t("settings_graphics"))
	_content.add_child(_option_row(Loc.t("settings_quality"), [
		{"label": Loc.t("settings_quality_low"), "value": "0"},
		{"label": Loc.t("settings_quality_medium"), "value": "1"},
		{"label": Loc.t("settings_quality_high"), "value": "2"},
	], str(SettingsService.quality), _on_quality))

	_section(Loc.t("settings_controls"))
	_content.add_child(_option_row(Loc.t("settings_preset"), [
		{"label": Loc.t("layout_buttons"), "value": "buttons"},
		{"label": Loc.t("layout_slider"), "value": "slider"},
		{"label": Loc.t("layout_pedals"), "value": "pedals"},
	], SettingsService.control_preset, _on_preset))
	_content.add_child(_option_row(Loc.t("settings_side"), [
		{"label": Loc.t("layout_right"), "value": "right"},
		{"label": Loc.t("layout_left"), "value": "left"},
	], "left" if SettingsService.control_left_handed else "right", _on_side))
	_content.add_child(_slider_row(Loc.t("settings_size"), "control_scale", inverse_lerp(0.8, 1.35, SettingsService.control_scale)))
	_content.add_child(_slider_row(Loc.t("settings_opacity"), "control_opacity", SettingsService.control_opacity))
	_content.add_child(_slider_row(Loc.t("settings_edge_margin"), "control_margin", SettingsService.control_margin / 48.0))
	_content.add_child(_slider_row(Loc.t("settings_slider_sensitivity"), "slider_sensitivity", inverse_lerp(0.55, 1.8, SettingsService.slider_sensitivity)))
	_content.add_child(_slider_row(Loc.t("settings_slider_release"), "slider_release", inverse_lerp(1.0, 12.0, SettingsService.slider_release)))
	_content.add_child(_slider_row(Loc.t("settings_touch_margin"), "touch_hit_margin", SettingsService.touch_hit_margin / 0.45))
	_content.add_child(_toggle_row(Loc.t("settings_show_clutch"), SettingsService.show_clutch, _on_toggle.bind("show_clutch")))
	_content.add_child(_toggle_row(Loc.t("settings_show_handbrake"), SettingsService.show_handbrake, _on_toggle.bind("show_handbrake")))
	_content.add_child(_toggle_row(Loc.t("settings_show_winch"), SettingsService.show_winch, _on_toggle.bind("show_winch")))
	_content.add_child(_toggle_row(Loc.t("settings_show_recover"), SettingsService.show_recover, _on_toggle.bind("show_recover")))
	_content.add_child(_slider_row(Loc.t("settings_shake"), "shake", SettingsService.shake / 1.5))
	_content.add_child(_toggle_row(Loc.t("settings_haptics"), SettingsService.haptics, _on_haptics))
	var edit_row := UIKit.hbox(10)
	var edit := UIKit.button(Loc.t("settings_edit_layout"), true, "settings")
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.pressed.connect(_open_layout_editor)
	edit_row.add_child(edit)
	var reset_layout := UIKit.button(Loc.t("settings_reset_layout"), false, "reset")
	reset_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_layout.pressed.connect(func() -> void:
		SettingsService.reset_control_layout()
		_build()
		UIKit.toast(self, Loc.t("toast_saved")))
	edit_row.add_child(reset_layout)
	_content.add_child(edit_row)

	_section(Loc.t("settings_transmission"))
	_content.add_child(_option_row(Loc.t("settings_clutch"), [
		{"label": Loc.t("settings_auto_clutch"), "value": "assist"},
		{"label": Loc.t("settings_manual_clutch"), "value": "manual"},
	], SettingsService.clutch, _on_clutch))
	_content.add_child(UIKit.paragraph(Loc.t("settings_transmission_note"), 16, UIKit.MUTED))

	_content.add_child(UIKit.spacer(8))
	var reset := UIKit.button(Loc.t("settings_reset"), false, "restart")
	reset.pressed.connect(_on_reset)
	_content.add_child(reset)

func _section(text: String) -> void:
	_content.add_child(UIKit.spacer(4))
	var l := UIKit.label(text, 20, UIKit.AMBER, "bold")
	_content.add_child(l)
	_content.add_child(UIKit.divider())

func _option_row(title_text: String, options: Array, current: String, callback: Callable) -> Control:
	var row := UIKit.hbox(10)
	if not title_text.is_empty():
		var l := UIKit.label(title_text, 18, UIKit.IVORY, "medium")
		l.custom_minimum_size = Vector2(240, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(l)
	for opt: Dictionary in options:
		var value: String = String(opt["value"])
		var b := UIKit.button(String(opt["label"]), value == current)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 50)
		b.pressed.connect(func() -> void:
			callback.call(value)
			SettingsService.vibrate(16))
		row.add_child(b)
	return row

func _slider_row(title_text: String, key: String, normalized: float) -> Control:
	var row := UIKit.hbox(12)
	var l := UIKit.label(title_text, 18, UIKit.IVORY, "medium")
	l.custom_minimum_size = Vector2(240, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = clampf(normalized, 0.0, 1.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 40)
	var value_label := UIKit.label("%d%%" % int(slider.value * 100.0), 17, UIKit.MUTED, "medium")
	value_label.custom_minimum_size = Vector2(64, 0)
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d%%" % int(v * 100.0)
		_apply_live(key, v))
	slider.drag_ended.connect(func(_changed: bool) -> void: SettingsService.save_settings())
	row.add_child(slider)
	row.add_child(value_label)
	return row

func _toggle_row(title_text: String, value: bool, callback: Callable) -> Control:
	var row := UIKit.hbox(12)
	var l := UIKit.label(title_text, 18, UIKit.IVORY, "medium")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	var cb := CheckButton.new()
	cb.button_pressed = value
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(func(v: bool) -> void:
		callback.call(v)
		SettingsService.vibrate(16))
	row.add_child(cb)
	return row

func _apply_live(key: String, v: float) -> void:
	match key:
		"master":
			SettingsService.master = v
		"engine":
			SettingsService.engine = v
		"sfx":
			SettingsService.sfx = v
		"music":
			SettingsService.music = v
		"control_scale":
			SettingsService.control_scale = lerpf(0.8, 1.35, v)
		"control_opacity":
			SettingsService.control_opacity = v
		"control_margin":
			SettingsService.control_margin = v * 48.0
		"slider_sensitivity":
			SettingsService.slider_sensitivity = lerpf(0.55, 1.8, v)
		"slider_release":
			SettingsService.slider_release = lerpf(1.0, 12.0, v)
		"touch_hit_margin":
			SettingsService.touch_hit_margin = v * 0.45
		"shake":
			SettingsService.shake = v * 1.5
	SettingsService.apply_audio()
	SettingsService.changed.emit()

func _on_language(code: String) -> void:
	SettingsService.set_language(code)
	_build()

func _on_quality(value: String) -> void:
	SettingsService.set_value("quality", int(value))
	_build()

func _on_transmission(value: String) -> void:
	SettingsService.set_value("transmission", value)
	_build()

func _on_preset(value: String) -> void:
	SettingsService.set_value("control_preset", value)
	_build()

func _on_side(value: String) -> void:
	SettingsService.set_value("control_left_handed", value == "left")
	_build()

func _on_toggle(value: bool, key: String) -> void:
	SettingsService.set_value(key, value)
	_build()

func _open_layout_editor() -> void:
	var editor := ControlLayoutEditor.new()
	add_child(editor)
	editor.closed.connect(func() -> void:
		editor.queue_free()
		_build())

func _on_clutch(value: String) -> void:
	SettingsService.set_value("clutch", value)
	_build()

func _on_haptics(value: bool) -> void:
	SettingsService.set_value("haptics", value)

func _on_reset() -> void:
	SettingsService.reset_defaults()
	_build()
	UIKit.toast(self, Loc.t("toast_saved"))
