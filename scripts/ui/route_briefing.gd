extends Control
## Route briefing: the real stage data and the real vehicle configuration in one
## place, before the player commits. Every number comes from StageDef / VehicleDef,
## and every choice writes to the save profile, so what is shown is what is driven.

var _stage: StageDef
var _stats: Dictionary = {}
var _body: HBoxContainer
var _config_box: VBoxContainer
var _vehicle_id: String = ""

func _ready() -> void:
	UIKit.root(self)
	_stage = GameSession.stage_def()
	if _stage == null:
		Router.goto("res://scenes/menus/stage_select.tscn")
		return
	_stats = _stage.route_stats()
	_vehicle_id = SaveManager.selected_vehicle()
	_build()

func _build() -> void:
	var bg := MenuBackground.new()
	add_child(bg)
	bg.setup(_stage.environment, false)
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
	back.pressed.connect(func() -> void: Router.goto("res://scenes/menus/stage_select.tscn"))
	header.add_child(back)
	var titles := UIKit.vbox(0)
	titles.add_child(UIKit.title(Loc.t("briefing_title"), 32))
	titles.add_child(UIKit.caption(_stage.label(Loc.lang)))
	header.add_child(titles)
	header.add_child(UIKit.spacer(0))
	var diff := UIKit.label("★".repeat(clampi(_stage.difficulty, 1, 6)), 22, UIKit.AMBER, "bold")
	header.add_child(diff)

	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_body)

	var left := UIKit.panel(16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(left)
	var left_col := UIKit.vbox(8)
	left.add_child(left_col)
	left_col.add_child(UIKit.paragraph(_stage.brief(Loc.lang), 17, UIKit.IVORY))
	left_col.add_child(UIKit.divider())
	left_col.add_child(_stat_row(Loc.t("briefing_length"), "%d m" % int(_stats.get("length_m", 0.0))))
	left_col.add_child(_stat_row(Loc.t("briefing_max_grade"), "%.1f°" % float(_stats.get("max_grade_deg", 0.0)), UIKit.AMBER))
	left_col.add_child(_stat_row(Loc.t("briefing_avg_grade"), "%.1f°" % float(_stats.get("avg_grade_deg", 0.0))))
	left_col.add_child(_stat_row(Loc.t("briefing_climbs"), str(int(_stats.get("climbs", 0)))))
	left_col.add_child(_stat_row(Loc.t("briefing_descents"), str(int(_stats.get("descents", 0)))))
	left_col.add_child(_stat_row(Loc.t("briefing_obstacles"), str(int(_stats.get("obstacles", 0)))))
	left_col.add_child(UIKit.divider())
	left_col.add_child(_surface_row(Loc.t("briefing_rock"), float(_stats.get("rock_pct", 0.0)), UIKit.MUTED))
	left_col.add_child(_surface_row(Loc.t("briefing_dirt"), float(_stats.get("dirt_pct", 0.0)), Color(0.62, 0.46, 0.28)))
	left_col.add_child(_surface_row(Loc.t("briefing_mud"), float(_stats.get("mud_pct", 0.0)), UIKit.TEAL))
	left_col.add_child(UIKit.spacer(4))
	left_col.add_child(UIKit.label(Loc.t("briefing_recommend"), 17, UIKit.AMBER, "bold"))
	var rec := UIKit.paragraph(_recommendation(), 16, UIKit.MUTED)
	rec.custom_minimum_size = Vector2(0, 52)
	left_col.add_child(rec)

	var right := UIKit.panel(16)
	right.custom_minimum_size = Vector2(430, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(right)
	var right_col := UIKit.vbox(8)
	right.add_child(right_col)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(scroll)
	_config_box = UIKit.vbox(8)
	_config_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_config_box)
	right_col.add_child(UIKit.caption(Loc.t("briefing_warning")))
	var start := UIKit.button(Loc.t("briefing_start"), true, "play")
	start.custom_minimum_size = Vector2(0, 58)
	start.pressed.connect(_start)
	right_col.add_child(start)
	_refresh_config()

func _stat_row(label_text: String, value_text: String, accent: Color = UIKit.IVORY) -> Control:
	return UIKit.stat_row(label_text, value_text, accent)

func _surface_row(label_text: String, pct: float, color: Color) -> Control:
	var col := UIKit.vbox(2)
	var head := UIKit.hbox(6)
	head.add_child(UIKit.caption(label_text))
	head.add_child(UIKit.spacer(0))
	head.add_child(UIKit.value_label("%d%%" % int(round(pct)), 15, color))
	col.add_child(head)
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = clampf(pct, 0.0, 100.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.10)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	col.add_child(bar)
	return col

func _recommendation() -> String:
	var grade: float = float(_stats.get("max_grade_deg", 0.0))
	var wet: float = float(_stats.get("mud_pct", 0.0))
	var parts: PackedStringArray = []
	if grade >= 20.0:
		parts.append(Loc.t("recommend_low_range"))
	elif grade >= 12.0:
		parts.append(Loc.t("recommend_short_gears"))
	if wet >= 35.0:
		parts.append(Loc.t("recommend_mud_tires"))
	elif float(_stats.get("rock_pct", 0.0)) >= 40.0:
		parts.append(Loc.t("recommend_rock_tires"))
	if float(_stats.get("descents", 0)) >= 2:
		parts.append(Loc.t("recommend_descent"))
	if parts.is_empty():
		parts.append(Loc.t("recommend_standard"))
	return " · ".join(parts)

func _refresh_config() -> void:
	if _config_box == null:
		return
	for c: Node in _config_box.get_children():
		c.queue_free()
	var base: VehicleDef = Content.vehicle_by_id(_vehicle_id)
	if base == null:
		return
	var cfg: Dictionary = SaveManager.vehicle_config(_vehicle_id)

	_config_box.add_child(UIKit.caption(Loc.t("briefing_vehicle")))
	var vehicle_row := UIKit.hbox(6)
	for def: VehicleDef in Content.vehicles:
		if not SaveManager.is_vehicle_owned(def.id):
			continue
		var b := UIKit.button(def.label(Loc.lang), def.id == _vehicle_id)
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func() -> void:
			SaveManager.select_vehicle(def.id)
			_vehicle_id = def.id
			AudioDirector.ui_confirm()
			_refresh_config())
		vehicle_row.add_child(b)
	_config_box.add_child(vehicle_row)

	var profile: TransmissionProfile = base.transmission_by_id(String(cfg.get("transmission", "")))
	if profile == null:
		profile = base.stock_transmission_profile()
	_config_box.add_child(UIKit.divider())
	_config_box.add_child(UIKit.caption(Loc.t("briefing_transmission")))
	var trans_row := UIKit.hbox(6)
	for p: TransmissionProfile in base.transmission_options():
		var b := UIKit.button(p.label(Loc.lang), p.id == String(cfg.get("transmission", "")))
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void:
			SaveManager.set_config_value(_vehicle_id, "transmission", p.id)
			AudioDirector.ui_confirm()
			_refresh_config())
		trans_row.add_child(b)
	_config_box.add_child(trans_row)
	if profile != null:
		var ratios: PackedStringArray = []
		for r: float in profile.ratios:
			ratios.append("%.2f" % r)
		_config_box.add_child(UIKit.value_label("%s · %s" % [profile.name_en, " / ".join(ratios)], 14, UIKit.MUTED))

	if base.has_transfer_case():
		_config_box.add_child(UIKit.caption(Loc.t("briefing_transfer")))
		var trow := UIKit.hbox(6)
		for mode: String in base.transfer_ids:
			var b := UIKit.button(mode, mode == String(cfg.get("transfer", "")))
			b.custom_minimum_size = Vector2(0, 42)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func() -> void:
				SaveManager.set_config_value(_vehicle_id, "transfer", mode)
				AudioDirector.ui_confirm()
				_refresh_config())
			trow.add_child(b)
		_config_box.add_child(trow)

	_config_box.add_child(UIKit.caption(Loc.t("briefing_diff")))
	var drow := UIKit.hbox(6)
	for mode: String in base.diff_modes:
		var b := UIKit.button(mode.to_upper(), mode == String(cfg.get("diff", "")))
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void:
			SaveManager.set_config_value(_vehicle_id, "diff", mode)
			AudioDirector.ui_confirm()
			_refresh_config())
		drow.add_child(b)
	_config_box.add_child(drow)

	_config_box.add_child(UIKit.caption(Loc.t("briefing_tires")))
	var tire_row := UIKit.hbox(6)
	for opt: Dictionary in base.tire_options:
		var oid: String = String(opt.get("id", ""))
		var b := UIKit.button(String(opt.get("name_fa", oid)) if Loc.lang == "fa" else String(opt.get("name_en", oid)), oid == String(cfg.get("tires", "")))
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void:
			SaveManager.set_config_value(_vehicle_id, "tires", oid)
			AudioDirector.ui_confirm()
			_refresh_config())
		tire_row.add_child(b)
	_config_box.add_child(tire_row)

	_config_box.add_child(UIKit.caption(Loc.t("briefing_suspension")))
	var susp_row := UIKit.hbox(6)
	for opt: Dictionary in base.suspension_options:
		var oid: String = String(opt.get("id", ""))
		var b := UIKit.button(String(opt.get("name_fa", oid)) if Loc.lang == "fa" else String(opt.get("name_en", oid)), oid == String(cfg.get("suspension", "")))
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void:
			SaveManager.set_config_value(_vehicle_id, "suspension", oid)
			AudioDirector.ui_confirm()
			_refresh_config())
		susp_row.add_child(b)
	_config_box.add_child(susp_row)

func _start() -> void:
	GameSession.start_stage(_stage.id, GameSession.mode)
	AudioDirector.ui_confirm()
	Router.goto("res://scenes/race/race.tscn", 0.12)
