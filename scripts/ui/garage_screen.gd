extends Control
## Garage: vehicle roster, real specification read from the simulation data,
## selection, purchase and the entry point to component upgrades.

var _detail: VBoxContainer
var _list: VBoxContainer
var _current: String = ""

func _ready() -> void:
	UIKit.root(self)
	_current = SaveManager.selected_vehicle()
	_build()

func _build() -> void:
	var bg := MenuBackground.new()
	add_child(bg)
	bg.setup("quarry", false)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.04, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root_box.add_child(header)
	var back := UIKit.button(Loc.t("back"), false, "arrow_right" if Loc.is_rtl() else "arrow_left")
	back.custom_minimum_size = Vector2(150, 54)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: Router.goto("res://scenes/menus/main_menu.tscn"))
	header.add_child(back)
	var titles := UIKit.vbox(0)
	titles.add_child(UIKit.title(Loc.t("garage_title"), 40))
	titles.add_child(UIKit.caption(Loc.t("garage_sub")))
	header.add_child(titles)
	header.add_child(UIKit.spacer(0))
	var chip := UIKit.panel(12, true)
	var chip_row := UIKit.hbox(8)
	chip_row.add_child(UIKit.icon("coin", 26, UIKit.GOLD))
	var credits_label := UIKit.label(str(SaveManager.credits()), 20, UIKit.GOLD, "bold")
	credits_label.name = "CreditsValue"
	chip_row.add_child(credits_label)
	chip.add_child(chip_row)
	header.add_child(chip)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(body)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(360, 0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list_scroll)
	_list = UIKit.vbox(10)
	_list.custom_minimum_size = Vector2(330, 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list)

	var detail_panel := UIKit.panel(16)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(detail_scroll)
	_detail = UIKit.vbox(10)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail)

	_refresh_list()
	_show(_current)

func _refresh_list() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	for def: VehicleDef in Content.vehicles:
		_list.add_child(_vehicle_card(def))

func _vehicle_card(def: VehicleDef) -> Control:
	var owned: bool = SaveManager.is_vehicle_owned(def.id)
	var unlocked: bool = SaveManager.is_stage_unlocked_vehicle(def)
	var selected: bool = def.id == _current

	var card := UIKit.panel(12, true)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(4)
	card.add_child(v)

	var row := UIKit.hbox(8)
	v.add_child(row)
	var name_label := UIKit.label(def.label(Loc.lang), 21, UIKit.AMBER if selected else UIKit.IVORY, "bold")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_label)
	if not owned and not unlocked:
		row.add_child(UIKit.icon("lock", 22, UIKit.MUTED))

	var sub := UIKit.caption(def.class_label(Loc.lang))
	v.add_child(sub)

	var bottom := UIKit.hbox(6)
	if owned:
		bottom.add_child(UIKit.icon("check", 18, UIKit.TEAL))
		if selected:
			bottom.add_child(UIKit.caption(Loc.t("garage_selected")))
	else:
		bottom.add_child(UIKit.icon("coin", 18, UIKit.GOLD))
		bottom.add_child(UIKit.label(str(def.price), 17, UIKit.GOLD, "medium"))
	bottom.add_child(UIKit.spacer(0))
	v.add_child(bottom)

	var btn := UIKit.button(Loc.t("garage_upgrade") if owned else Loc.t("garage_buy"), false, "wrench" if owned else "coin")
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(_select.bind(def.id))
	v.add_child(btn)
	return card

func _select(vehicle_id: String) -> void:
	_current = vehicle_id
	AudioDirector.ui_click()
	_refresh_list()
	_show(vehicle_id)

func _show(vehicle_id: String) -> void:
	for c: Node in _detail.get_children():
		c.queue_free()
	var base: VehicleDef = Content.vehicle_by_id(vehicle_id)
	if base == null:
		return
	var owned: bool = SaveManager.is_vehicle_owned(vehicle_id)
	var def: VehicleDef = GarageModel.build(base, SaveManager.vehicle_upgrades(vehicle_id))

	var preview := TextureRect.new()
	var body_path: String = def.sprite_body
	if ResourceLoader.exists(body_path):
		preview.texture = load(body_path) as Texture2D
	preview.custom_minimum_size = Vector2(0, 210)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail.add_child(preview)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	_detail.add_child(title_row)
	var name_label := UIKit.label(def.label(Loc.lang), 32, UIKit.IVORY, "black")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	if not owned:
		var state := UIKit.label(Loc.t("garage_locked") if not SaveManager.is_stage_unlocked_vehicle(base) else Loc.t("garage_buy"), 18, UIKit.AMBER, "bold")
		title_row.add_child(state)
	var cls := UIKit.caption(def.class_label(Loc.lang))
	_detail.add_child(cls)
	var desc := UIKit.paragraph(def.description(Loc.lang), 17, UIKit.MUTED)
	desc.custom_minimum_size = Vector2(0, 52)
	_detail.add_child(desc)
	_detail.add_child(UIKit.divider())

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 26)
	_detail.add_child(stats)
	var col_a := UIKit.vbox(3)
	var col_b := UIKit.vbox(3)
	col_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(col_a)
	stats.add_child(col_b)

	var power_hp: float = def.peak_power_kw() * 1.341
	col_a.add_child(UIKit.stat_row(Loc.t("spec_mass"), "%d kg" % int(def.mass_kg)))
	col_a.add_child(UIKit.stat_row(Loc.t("spec_power"), "%d kW · %d hp" % [int(def.peak_power_kw()), int(power_hp)]))
	col_a.add_child(UIKit.stat_row(Loc.t("spec_torque"), "%d Nm" % int(def.engine.peak_torque())))
	col_a.add_child(UIKit.stat_row(Loc.t("spec_top_speed"), "%d km/h" % int(_top_speed(def)), UIKit.AMBER))
	col_a.add_child(UIKit.stat_row(Loc.t("spec_weight_power"), "%.1f kg/hp" % def.mass_per_hp()))
	col_b.add_child(UIKit.stat_row(Loc.t("spec_drive"), _drive_label(def)))
	col_b.add_child(UIKit.stat_row(Loc.t("spec_gearbox"), def.gearbox.describe()))
	col_b.add_child(UIKit.stat_row(Loc.t("spec_wheelbase"), "%.2f m" % def.wheelbase_m))
	col_b.add_child(UIKit.stat_row(Loc.t("spec_travel"), "%d mm" % int(def.suspension.travel_m * 1000.0)))
	col_b.add_child(UIKit.stat_row(Loc.t("spec_grip"), "%.2f µ" % def.tire_rear.mu_scale))

	_detail.add_child(UIKit.spacer(4))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_detail.add_child(actions)

	if owned:
		var select_btn := UIKit.button(Loc.t("garage_selected") if SaveManager.selected_vehicle() == vehicle_id else Loc.t("garage_select"), true, "check")
		select_btn.disabled = SaveManager.selected_vehicle() == vehicle_id
		select_btn.pressed.connect(_choose.bind(vehicle_id))
		actions.add_child(select_btn)
		var upg := UIKit.button(Loc.t("garage_upgrade"), false, "wrench")
		upg.pressed.connect(_open_upgrades.bind(vehicle_id))
		actions.add_child(upg)
	else:
		var unlocked: bool = SaveManager.is_stage_unlocked_vehicle(base)
		var buy := UIKit.button(Loc.t("garage_buy") + " · " + str(base.price), true, "coin")
		buy.disabled = not unlocked or SaveManager.credits() < base.price
		buy.pressed.connect(_buy.bind(vehicle_id))
		actions.add_child(buy)
		if not unlocked:
			var unlock_stage: StageDef = Content.stage_by_id(base.unlock_stage)
			var hint := UIKit.caption(Loc.t("garage_unlock_hint", {"stage": unlock_stage.label(Loc.lang) if unlock_stage != null else "—"}))
			_detail.add_child(hint)

func _drive_label(def: VehicleDef) -> String:
	match def.drivetrain:
		VehicleDef.Drivetrain.FWD:
			return Loc.t("drive_fwd")
		VehicleDef.Drivetrain.RWD:
			return Loc.t("drive_rwd")
		_:
			return Loc.t("drive_awd")

func _top_speed(def: VehicleDef) -> float:
	var geared: float = def.gearbox.top_speed_mps(def.tire_rear.radius_m, def.engine.max_rpm)
	var torque_at_redline: float = def.engine.torque_at(def.engine.redline_rpm)
	var top_gear_ratio: float = def.gearbox.total_ratio(def.gearbox.gear_count())
	var force: float = torque_at_redline * top_gear_ratio * def.gearbox.efficiency / maxf(def.tire_rear.radius_m, 0.1)
	var drag_term: float = 0.5 * Units.AIR_DENSITY * def.drag_cd * def.frontal_area_m2
	var drag_limited: float = sqrt(2.0 * maxf(force, 1.0) / maxf(drag_term, 0.05))
	return minf(geared, drag_limited) * 3.6

func _choose(vehicle_id: String) -> void:
	SaveManager.select_vehicle(vehicle_id)
	AudioDirector.ui_confirm()
	_show(vehicle_id)

func _buy(vehicle_id: String) -> void:
	if SaveManager.buy_vehicle(vehicle_id):
		AudioDirector.ui_confirm()
		_current = vehicle_id
		_refresh_list()
		_show(vehicle_id)
		UIKit.toast(self, Loc.t("toast_purchased"))
	else:
		AudioDirector.play("ui_back", -6.0)
		UIKit.toast(self, Loc.t("toast_not_enough"))

func _open_upgrades(vehicle_id: String) -> void:
	GameSession.vehicle_id = vehicle_id
	Router.goto("res://scenes/garage/upgrades.tscn")
