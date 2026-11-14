extends Control
## Vehicle configuration: the gearbox, transfer case, differential, tyre set and
## suspension the car will actually race with. Every row writes straight to the
## save profile, and the numbers shown come from the same resources the simulation
## reads.

var _vehicle_id: String = ""
var _config_box: VBoxContainer
var _spec_box: VBoxContainer

func _ready() -> void:
	UIKit.root(self)
	_vehicle_id = GameSession.vehicle_id
	if _vehicle_id.is_empty() or Content.vehicle_by_id(_vehicle_id) == null:
		_vehicle_id = SaveManager.selected_vehicle()
	_build()

func _build() -> void:
	var bg := MenuBackground.new()
	add_child(bg)
	bg.setup("quarry", false)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root_box.add_child(header)
	var back := UIKit.button(Loc.t("back"), false, "arrow_right" if Loc.is_rtl() else "arrow_left")
	back.custom_minimum_size = Vector2(140, 50)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: Router.goto("res://scenes/garage/garage.tscn"))
	header.add_child(back)
	var titles := UIKit.vbox(0)
	var base: VehicleDef = Content.vehicle_by_id(_vehicle_id)
	titles.add_child(UIKit.title(Loc.t("garage_setup"), 34))
	titles.add_child(UIKit.caption(base.label(Loc.lang) + " · " + base.class_label(Loc.lang)))
	header.add_child(titles)
	header.add_child(UIKit.spacer(0))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(body)

	var left := UIKit.panel(16)
	left.custom_minimum_size = Vector2(420, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	_spec_box = UIKit.vbox(6)
	left.add_child(_spec_box)

	var right := UIKit.panel(16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_config_box = UIKit.vbox(8)
	_config_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_config_box)

	_refresh()

func _refresh() -> void:
	for c: Node in _config_box.get_children():
		c.queue_free()
	for c: Node in _spec_box.get_children():
		c.queue_free()
	var base: VehicleDef = Content.vehicle_by_id(_vehicle_id)
	if base == null:
		return
	var cfg: Dictionary = SaveManager.vehicle_config(_vehicle_id)
	_build_specs(base, cfg)

	_config_box.add_child(UIKit.caption(Loc.t("briefing_transmission")))
	var trans_col := UIKit.vbox(4)
	for p: TransmissionProfile in base.transmission_options():
		var row := UIKit.hbox(8)
		var b := UIKit.button(p.label(Loc.lang), p.id == String(cfg.get("transmission", "")))
		b.custom_minimum_size = Vector2(240, 46)
		b.pressed.connect(func() -> void:
			SaveManager.set_config_value(_vehicle_id, "transmission", p.id)
			AudioDirector.ui_confirm()
			_refresh())
		row.add_child(b)
		var ratios: PackedStringArray = []
		for r: float in p.ratios:
			ratios.append("%.2f" % r)
		var info := UIKit.value_label("%d · %s" % [p.gear_count(), " / ".join(ratios)], 14, UIKit.MUTED)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		trans_col.add_child(row)
	_config_box.add_child(trans_col)

	if base.has_transfer_case():
		_config_box.add_child(_row_string("transfer", Loc.t("garage_transfer"), base.transfer_ids, cfg))
	_config_box.add_child(_row_string("diff", Loc.t("garage_diff"), base.diff_modes, cfg))
	_config_box.add_child(_row_dict("tires", Loc.t("garage_tires"), base.tire_options, cfg))
	_config_box.add_child(_row_dict("suspension", Loc.t("garage_suspension"), base.suspension_options, cfg))

	var spacer := UIKit.spacer(4)
	_config_box.add_child(spacer)
	var note := UIKit.paragraph(Loc.t("setup_note"), 15, UIKit.MUTED)
	_config_box.add_child(note)

func _build_specs(base: VehicleDef, cfg: Dictionary) -> void:
	var profile: TransmissionProfile = base.transmission_by_id(String(cfg.get("transmission", "")))
	if profile == null:
		profile = base.stock_transmission_profile()
	_spec_box.add_child(UIKit.label(base.label(Loc.lang), 26, UIKit.AMBER, "bold"))
	_spec_box.add_child(UIKit.caption(base.class_label(Loc.lang)))
	_spec_box.add_child(UIKit.divider())
	_spec_box.add_child(UIKit.stat_row(Loc.t("spec_mass"), "%d kg" % int(base.mass_kg)))
	_spec_box.add_child(UIKit.stat_row(Loc.t("spec_power"), "%d kW" % int(base.peak_power_kw())))
	_spec_box.add_child(UIKit.stat_row(Loc.t("spec_torque"), "%d Nm" % int(base.engine.peak_torque())))
	_spec_box.add_child(UIKit.stat_row(Loc.t("spec_drive"), _drive_label(base)))
	_spec_box.add_child(UIKit.stat_row(Loc.t("spec_wheelbase"), "%.2f m" % base.wheelbase_m))
	if profile != null:
		_spec_box.add_child(UIKit.divider())
		_spec_box.add_child(UIKit.stat_row(Loc.t("garage_transmission"), profile.label(Loc.lang), UIKit.AMBER))
		_spec_box.add_child(UIKit.stat_row(Loc.t("garage_gears"), str(profile.gear_count())))
		_spec_box.add_child(UIKit.stat_row(Loc.t("garage_final"), "%.2f" % profile.final_drive))
		_spec_box.add_child(UIKit.stat_row(Loc.t("garage_capacity"), "%d Nm" % int(profile.max_torque_nm)))
		var top: float = profile.top_speed_mps(base.tire_rear.radius_m, base.engine.max_rpm) * 3.6
		_spec_box.add_child(UIKit.stat_row(Loc.t("spec_top_speed"), "%d km/h" % int(top)))
		_spec_box.add_child(UIKit.paragraph(profile.note(Loc.lang), 14, UIKit.MUTED))
	_spec_box.add_child(UIKit.divider())
	_spec_box.add_child(UIKit.caption(Loc.t("briefing_warning")))

func _drive_label(def: VehicleDef) -> String:
	match def.drivetrain:
		VehicleDef.Drivetrain.FWD:
			return Loc.t("drive_fwd")
		VehicleDef.Drivetrain.RWD:
			return Loc.t("drive_rwd")
		_:
			return Loc.t("drive_awd")

func _row_string(key: String, title_text: String, options: PackedStringArray, cfg: Dictionary) -> Control:
	var current: String = String(cfg.get(key, ""))
	var col := UIKit.vbox(4)
	col.add_child(UIKit.caption(title_text))
	var row := UIKit.hbox(6)
	for opt: String in options:
		var b := UIKit.button(opt.to_upper() if key == "diff" else opt, opt == current)
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			SaveManager.set_config_value(_vehicle_id, key, opt)
			AudioDirector.ui_confirm()
			_refresh())
		row.add_child(b)
	col.add_child(row)
	return col

func _row_dict(key: String, title_text: String, options: Array[Dictionary], cfg: Dictionary) -> Control:
	var current: String = String(cfg.get(key, ""))
	var col := UIKit.vbox(4)
	col.add_child(UIKit.caption(title_text))
	var row := UIKit.hbox(6)
	for opt: Dictionary in options:
		var oid: String = String(opt.get("id", ""))
		var label_text: String = String(opt.get("name_fa", oid)) if Loc.lang == "fa" else String(opt.get("name_en", oid))
		var b := UIKit.button(label_text, oid == current)
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			SaveManager.set_config_value(_vehicle_id, key, oid)
			AudioDirector.ui_confirm()
			_refresh())
		row.add_child(b)
	col.add_child(row)
	return col
