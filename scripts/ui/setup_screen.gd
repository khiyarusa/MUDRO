extends Control
## Vehicle setup: named presets of the fitted parts, plus the transfer-case mode
## and differential that are written straight into the save configuration.
##
## Transfer and differential are read from the *built* vehicle, so a fitted heavy
## duty transfer case offers its own ids and ratios. Both settings are consumed by
## VehicleBody when the track loads.

const GARAGE_SCENE: String = "res://scenes/garage/garage.tscn"

var _vehicle_id: String = ""
var _base: VehicleDef = null
var _credits_label: Label
var _name_edit: LineEdit
var _preset_box: VBoxContainer
var _config_box: VBoxContainer

func _ready() -> void:
	UIKit.root(self)
	_resolve_vehicle()
	_build()
	_refresh_all()

func _resolve_vehicle() -> void:
	_vehicle_id = GameSession.vehicle_id
	_base = Content.vehicle_by_id(_vehicle_id)
	if _base == null or not SaveManager.is_vehicle_owned(_vehicle_id):
		_vehicle_id = SaveManager.selected_vehicle()
		_base = Content.vehicle_by_id(_vehicle_id)
	if _base == null and not Content.vehicles.is_empty():
		_base = Content.vehicles[0]
		_vehicle_id = _base.id
	if _base != null:
		GameSession.vehicle_id = _vehicle_id

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var glow := MenuBackground.new()
	add_child(glow)
	glow.setup("quarry", false)
	glow.modulate = Color(1, 1, 1, 0.22)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root_box.add_child(header)
	var back := UIKit.button(Loc.t("back"), false, "arrow_right" if Loc.is_rtl() else "arrow_left")
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: Router.goto(GARAGE_SCENE))
	header.add_child(back)
	var titles := UIKit.vbox(0)
	titles.add_child(UIKit.title(Loc.t("garage_setup_title"), 32))
	titles.add_child(UIKit.caption((_base.label(Loc.lang) + " · " + Loc.t("garage_setup_sub")) if _base != null else ""))
	header.add_child(titles)
	header.add_child(_push())
	header.add_child(_credit_chip())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(body)

	# Presets (right in RTL).
	var preset_panel := UIKit.panel(12)
	preset_panel.custom_minimum_size = Vector2(376, 0)
	preset_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(preset_panel)
	var preset_col := UIKit.vbox(8)
	preset_panel.add_child(preset_col)
	preset_col.add_child(UIKit.caption(Loc.t("garage_setup_presets")))
	preset_col.add_child(UIKit.divider())

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = Loc.t("garage_setup_preset_ph")
	_name_edit.custom_minimum_size = Vector2(0, 46)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_direction = Loc.direction()
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT if Loc.is_rtl() else HORIZONTAL_ALIGNMENT_LEFT
	_name_edit.add_theme_font_override("font", Loc.font_regular())
	_name_edit.add_theme_font_size_override("font_size", 18)
	_name_edit.add_theme_color_override("font_color", UIKit.IVORY)
	_name_edit.add_theme_color_override("font_placeholder_color", UIKit.MUTED)
	_name_edit.add_theme_color_override("caret_color", UIKit.AMBER)
	_name_edit.add_theme_stylebox_override("normal", _field_style(UIKit.PANEL_SOFT, Color(1, 1, 1, 0.08)))
	_name_edit.add_theme_stylebox_override("focus", _field_style(UIKit.PANEL_SOFT.lightened(0.05), UIKit.AMBER))
	_name_edit.text_submitted.connect(func(_text: String) -> void: _save_preset())
	var save_row := UIKit.hbox(8)
	save_row.add_child(_name_edit)
	var save_btn := UIKit.button(Loc.t("garage_setup_save"), true, "plus")
	save_btn.custom_minimum_size = Vector2(126, 46)
	save_btn.add_theme_font_size_override("font_size", 16)
	save_btn.pressed.connect(_save_preset)
	save_row.add_child(save_btn)
	preset_col.add_child(save_row)

	var preset_scroll := ScrollContainer.new()
	preset_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	preset_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preset_col.add_child(preset_scroll)
	_preset_box = UIKit.vbox(6)
	_preset_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_scroll.add_child(_preset_box)

	var note := UIKit.paragraph(Loc.t("garage_setup_preset_note"), 13, UIKit.MUTED)
	preset_col.add_child(note)

	# Transfer case and differential (centre).
	var config_panel := UIKit.panel(12)
	config_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(config_panel)
	var config_scroll := ScrollContainer.new()
	config_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	config_panel.add_child(config_scroll)
	_config_box = UIKit.vbox(6)
	_config_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_scroll.add_child(_config_box)

func _field_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _credit_chip() -> Control:
	var chip := UIKit.panel(10, true)
	var row := UIKit.hbox(8)
	row.add_child(UIKit.icon("coin", 24, UIKit.GOLD))
	_credits_label = UIKit.value_label(str(SaveManager.credits()), 19, UIKit.GOLD)
	row.add_child(_credits_label)
	chip.add_child(row)
	return chip

# ------------------------------------------------------------------- refresh ---

func _refresh_all() -> void:
	if _credits_label != null:
		_credits_label.text = str(SaveManager.credits())
	_refresh_presets()
	_refresh_config()

func _refresh_presets() -> void:
	_clear(_preset_box)
	var names: Array = SaveManager.preset_names(_vehicle_id)
	if names.is_empty():
		_preset_box.add_child(UIKit.paragraph(Loc.t("garage_setup_no_presets"), 15, UIKit.MUTED))
		return
	for raw: Variant in names:
		var preset_name: String = String(raw)
		_preset_box.add_child(_preset_row(preset_name))

func _preset_row(preset_name: String) -> Control:
	var card := UIKit.panel(8, true)
	var row := UIKit.hbox(8)
	card.add_child(row)
	var label := UIKit.label(preset_name, 17, UIKit.IVORY, "bold")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var apply_btn := UIKit.button(Loc.t("garage_setup_apply"), false, "check")
	apply_btn.custom_minimum_size = Vector2(96, 38)
	apply_btn.add_theme_font_size_override("font_size", 15)
	apply_btn.pressed.connect(_apply_preset.bind(preset_name))
	row.add_child(apply_btn)

	var delete_btn := UIKit.button(Loc.t("garage_setup_delete"), false, "close")
	delete_btn.custom_minimum_size = Vector2(96, 38)
	delete_btn.add_theme_font_size_override("font_size", 15)
	delete_btn.pressed.connect(_delete_preset.bind(preset_name))
	row.add_child(delete_btn)
	return card

func _refresh_config() -> void:
	_clear(_config_box)
	if _base == null:
		_config_box.add_child(UIKit.paragraph(Loc.t("garage_no_vehicle"), 16, UIKit.MUTED))
		return
	var cfg: Dictionary = SaveManager.vehicle_config(_vehicle_id)
	var built: VehicleDef = GarageModel.build(_base, cfg)
	if built == null:
		return
	var profile: TransmissionProfile = built.fitted_transmission_profile()
	var tyre: PartDef = built.parts.get(PartDef.Slot.TYRES, null) as PartDef
	var transfer: String = built.default_transfer
	var diff: String = built.active_diff if not built.active_diff.is_empty() else built.default_diff

	_config_box.add_child(UIKit.caption(Loc.t("garage_setup_current")))
	_config_box.add_child(_text_row(Loc.t("garage_setup_gearbox"),
		profile.label(Loc.lang) if profile != null else "—"))
	_config_box.add_child(_text_row(Loc.t("garage_setup_tyres"),
		tyre.label(Loc.lang) if tyre != null else "—"))
	if built.has_transfer_case():
		_config_box.add_child(_text_row(Loc.t("garage_setup_transfer"), transfer))
	_config_box.add_child(_text_row(Loc.t("garage_setup_diff"), _diff_label(diff)))
	_config_box.add_child(UIKit.divider())

	if built.has_transfer_case():
		_config_box.add_child(UIKit.caption(Loc.t("garage_setup_transfer")))
		for i: int in range(built.transfer_ids.size()):
			var mode: String = built.transfer_ids[i]
			var ratio: float = built.transfer_ratios[i] if i < built.transfer_ratios.size() else 1.0
			_config_box.add_child(_mode_row(mode, mode == transfer, "×%.2f" % ratio,
				_transfer_note(mode), _set_transfer.bind(mode)))

	_config_box.add_child(UIKit.divider())
	_config_box.add_child(UIKit.caption(Loc.t("garage_setup_diff")))
	for mode: String in built.diff_modes:
		_config_box.add_child(_mode_row(_diff_label(mode), mode == diff, "",
			_diff_note(mode), _set_diff.bind(mode)))

	_config_box.add_child(UIKit.divider())
	_config_box.add_child(UIKit.paragraph(Loc.t("garage_setup_apply_note"), 13, UIKit.MUTED))

func _mode_row(label_text: String, selected: bool, ratio_text: String, note_text: String,
		on_press: Callable) -> Control:
	var row := UIKit.hbox(8)
	var btn := UIKit.button(label_text, selected)
	btn.custom_minimum_size = Vector2(150, 42)
	btn.add_theme_font_size_override("font_size", 15)
	btn.disabled = selected
	btn.pressed.connect(on_press)
	row.add_child(btn)
	if not ratio_text.is_empty():
		var ratio := UIKit.value_label(ratio_text, 14, UIKit.AMBER)
		ratio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ratio)
	var note := UIKit.caption(note_text)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(note)
	return row

# -------------------------------------------------------------------- actions ---

func _save_preset() -> void:
	var preset_name: String = _name_edit.text.strip_edges()
	if preset_name.is_empty():
		AudioDirector.play("ui_back", -6.0)
		UIKit.toast(self, Loc.t("garage_setup_name_empty"))
		return
	SaveManager.save_preset(_vehicle_id, preset_name)
	_name_edit.text = ""
	AudioDirector.ui_confirm()
	UIKit.toast(self, Loc.t("garage_setup_saved"))
	_refresh_presets()

func _apply_preset(preset_name: String) -> void:
	if SaveManager.apply_preset(_vehicle_id, preset_name):
		AudioDirector.ui_confirm()
		UIKit.toast(self, Loc.t("garage_setup_applied"))
	else:
		AudioDirector.play("ui_back", -6.0)
		UIKit.toast(self, Loc.t("garage_setup_missing"))
	_refresh_all()

func _delete_preset(preset_name: String) -> void:
	SaveManager.delete_preset(_vehicle_id, preset_name)
	AudioDirector.ui_click()
	UIKit.toast(self, Loc.t("garage_setup_deleted"))
	_refresh_presets()

func _set_transfer(mode: String) -> void:
	SaveManager.set_config_value(_vehicle_id, "transfer", mode)
	AudioDirector.ui_confirm()
	_refresh_all()

func _set_diff(mode: String) -> void:
	SaveManager.set_config_value(_vehicle_id, "diff", mode)
	AudioDirector.ui_confirm()
	_refresh_all()

# -------------------------------------------------------------------- helpers ---

func _transfer_note(mode: String) -> String:
	match mode.to_upper():
		"2H":
			return Loc.t("garage_setup_transfer_2h")
		"4H":
			return Loc.t("garage_setup_transfer_4h")
		"4L":
			return Loc.t("garage_setup_transfer_4l")
		_:
			return Loc.t("garage_setup_transfer_unknown")

func _diff_label(mode: String) -> String:
	match mode:
		"lsd":
			return Loc.t("garage_setup_diff_lsd")
		"locked":
			return Loc.t("garage_setup_diff_locked")
		_:
			return Loc.t("garage_setup_diff_open")

func _diff_note(mode: String) -> String:
	match mode:
		"lsd":
			return Loc.t("garage_setup_diff_lsd_note")
		"locked":
			return Loc.t("garage_setup_diff_locked_note")
		_:
			return Loc.t("garage_setup_diff_open_note")

## Row whose value is Persian text, so it must not be forced left-to-right.
func _text_row(label_text: String, value_text: String, color: Color = UIKit.IVORY) -> Control:
	var row := UIKit.hbox(8)
	var l := UIKit.label(label_text, 16, UIKit.MUTED, "medium")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.label(value_text, 16, color, "bold")
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(l)
	row.add_child(v)
	return row

func _push() -> Control:
	var c := UIKit.spacer(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
