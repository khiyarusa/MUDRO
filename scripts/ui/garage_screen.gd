extends Control
## MUDRO 3.0 garage: the vehicle roster, the documented factory specification of
## the selected machine, the build the save actually produces, and the workshop
## hub.
##
## Nothing here is decorative. The specification is read from the VehicleDef and
## the EngineBuild the simulation drives, and every workshop tile opens a scene
## that fits real PartDefs through SaveManager.install_part.

const LAB_SCENE: String = "res://scenes/garage/tuning_lab.tscn"
const DYNO_SCENE: String = "res://scenes/garage/dyno.tscn"
const REPAIR_SCENE: String = "res://scenes/garage/repair.tscn"
const SETUP_SCENE: String = "res://scenes/garage/setup.tscn"
const MENU_SCENE: String = "res://scenes/menus/main_menu.tscn"
## Read by tuning_lab.gd. Kept on GameSession so no scene needs a second script.
const CATEGORY_META: String = "garage_lab_category"

const HUB: Array = [
	{"category": "engine", "scene": LAB_SCENE, "icon": "engine",
		"title": "garage_lab_engine", "note": "garage_lab_engine_note"},
	{"category": "transmission", "scene": LAB_SCENE, "icon": "gearbox",
		"title": "garage_lab_transmission", "note": "garage_lab_transmission_note"},
	{"category": "suspension", "scene": LAB_SCENE, "icon": "suspension",
		"title": "garage_lab_suspension", "note": "garage_lab_suspension_note"},
	{"category": "tyres", "scene": LAB_SCENE, "icon": "tire",
		"title": "garage_lab_tyres", "note": "garage_lab_tyres_note"},
	{"category": "body", "scene": LAB_SCENE, "icon": "chassis",
		"title": "garage_lab_body", "note": "garage_lab_body_note"},
	{"category": "brakes", "scene": LAB_SCENE, "icon": "brake",
		"title": "garage_lab_brakes", "note": "garage_lab_brakes_note"},
	{"category": "", "scene": DYNO_SCENE, "icon": "rpm",
		"title": "garage_dyno", "note": "garage_dyno_note"},
	{"category": "", "scene": REPAIR_SCENE, "icon": "wrench",
		"title": "garage_repair", "note": "garage_repair_note"},
]

var _roster: VBoxContainer
var _spec: VBoxContainer
var _hub: VBoxContainer
var _credits_label: Label
var _current: String = ""

func _ready() -> void:
	UIKit.root(self)
	_current = GameSession.vehicle_id
	if Content.vehicle_by_id(_current) == null:
		_current = SaveManager.selected_vehicle()
	GameSession.vehicle_id = _current
	_build()
	_refresh_all()

func _build() -> void:
	var bg := MenuBackground.new()
	add_child(bg)
	bg.setup("quarry", false)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.04, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

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
	back.custom_minimum_size = Vector2(140, 50)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: Router.goto(MENU_SCENE))
	header.add_child(back)
	var titles := UIKit.vbox(0)
	titles.add_child(UIKit.title(Loc.t("garage_title"), 36))
	titles.add_child(UIKit.caption(Loc.t("garage_sub")))
	header.add_child(titles)
	header.add_child(_push())
	header.add_child(_credit_chip())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(body)

	# RTL: first child sits on the right, which is where the roster belongs.
	var roster_panel := UIKit.panel(12)
	roster_panel.custom_minimum_size = Vector2(288, 0)
	roster_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(roster_panel)
	var roster_col := UIKit.vbox(8)
	roster_panel.add_child(roster_col)
	roster_col.add_child(UIKit.caption(Loc.t("garage_roster")))
	roster_col.add_child(UIKit.divider())
	var roster_scroll := ScrollContainer.new()
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_col.add_child(roster_scroll)
	_roster = UIKit.vbox(8)
	_roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.add_child(_roster)

	var spec_panel := UIKit.panel(14)
	spec_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spec_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spec_panel)
	var spec_scroll := ScrollContainer.new()
	spec_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	spec_panel.add_child(spec_scroll)
	_spec = UIKit.vbox(8)
	_spec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spec_scroll.add_child(_spec)

	var hub_panel := UIKit.panel(12)
	hub_panel.custom_minimum_size = Vector2(296, 0)
	hub_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(hub_panel)
	var hub_col := UIKit.vbox(8)
	hub_panel.add_child(hub_col)
	hub_col.add_child(UIKit.caption(Loc.t("garage_workshop")))
	hub_col.add_child(UIKit.divider())
	var hub_scroll := ScrollContainer.new()
	hub_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hub_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hub_col.add_child(hub_scroll)
	_hub = UIKit.vbox(6)
	_hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub_scroll.add_child(_hub)

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
	_refresh_roster()
	_show_vehicle(_current)
	_refresh_hub()

func _refresh_roster() -> void:
	_clear(_roster)
	for def: VehicleDef in Content.vehicles:
		_roster.add_child(_roster_card(def))

func _roster_card(def: VehicleDef) -> Control:
	var owned: bool = SaveManager.is_vehicle_owned(def.id)
	var unlocked: bool = SaveManager.is_vehicle_unlocked(def)
	var viewing: bool = def.id == _current
	var chosen: bool = SaveManager.selected_vehicle() == def.id

	var card := UIKit.panel(10, true)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := UIKit.vbox(3)
	card.add_child(col)

	var name_label := UIKit.label(def.label(Loc.lang), 19, UIKit.AMBER if viewing else UIKit.IVORY, "bold")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_label)
	col.add_child(UIKit.caption(def.class_label(Loc.lang)))

	var doc_kw: float = def.doc_power_kw if def.doc_power_kw > 0.0 else def.peak_power_kw()
	col.add_child(UIKit.value_label("%d kW · %d hp · %d kg" % [
		int(doc_kw), int(doc_kw * 1.341), int(def.mass_kg)], 13, UIKit.MUTED))

	if not owned:
		var price_row := UIKit.hbox(4)
		price_row.add_child(UIKit.icon("coin", 15, UIKit.GOLD))
		price_row.add_child(UIKit.value_label(str(def.price), 14, UIKit.GOLD))
		price_row.add_child(_push())
		col.add_child(price_row)
		if not unlocked:
			var track: TrackDef = Content.track_by_id(def.unlock_track)
			var hint := UIKit.paragraph(Loc.t("garage_unlock_track", {
				"track": track.label(Loc.lang) if track != null else def.unlock_track}), 12, UIKit.RED)
			col.add_child(hint)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	col.add_child(actions)
	if owned:
		var select_btn := UIKit.button(Loc.t("garage_selected") if chosen else Loc.t("garage_select"), not chosen, "check" if chosen else "")
		select_btn.custom_minimum_size = Vector2(0, 38)
		select_btn.add_theme_font_size_override("font_size", 16)
		select_btn.disabled = chosen
		select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_btn.pressed.connect(_select_vehicle.bind(def.id))
		actions.add_child(select_btn)
	else:
		var view_btn := UIKit.button(Loc.t("garage_view"), false)
		view_btn.custom_minimum_size = Vector2(0, 38)
		view_btn.add_theme_font_size_override("font_size", 15)
		view_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view_btn.pressed.connect(_view_vehicle.bind(def.id))
		actions.add_child(view_btn)
		var buy_btn := UIKit.button(Loc.t("garage_buy"), true, "coin")
		buy_btn.custom_minimum_size = Vector2(0, 38)
		buy_btn.add_theme_font_size_override("font_size", 15)
		buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy_btn.disabled = not unlocked or SaveManager.credits() < def.price
		buy_btn.pressed.connect(_buy_vehicle.bind(def.id))
		actions.add_child(buy_btn)
	return card

func _show_vehicle(vehicle_id: String) -> void:
	_clear(_spec)
	var base: VehicleDef = Content.vehicle_by_id(vehicle_id)
	if base == null:
		_spec.add_child(UIKit.paragraph(Loc.t("garage_no_vehicle"), 18, UIKit.MUTED))
		return
	var owned: bool = SaveManager.is_vehicle_owned(vehicle_id)
	var cfg: Dictionary = SaveManager.vehicle_config(vehicle_id)
	var built: VehicleDef = GarageModel.build(base, cfg)
	if built == null:
		return

	var preview := TextureRect.new()
	if ResourceLoader.exists(built.sprite_body):
		preview.texture = load(built.sprite_body) as Texture2D
	preview.custom_minimum_size = Vector2(0, 148)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spec.add_child(preview)

	var name_row := UIKit.hbox(8)
	var name_label := UIKit.label(built.label(Loc.lang), 29, UIKit.IVORY, "black")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_row.add_child(name_label)
	name_row.add_child(_state_chip(owned, base))
	_spec.add_child(name_row)
	_spec.add_child(UIKit.caption(built.class_label(Loc.lang)))
	var desc := UIKit.paragraph(built.description(Loc.lang), 15, UIKit.MUTED)
	desc.custom_minimum_size = Vector2(0, 44)
	_spec.add_child(desc)

	_show_factory_spec(base, built)
	_show_build(built)
	if owned:
		_spec.add_child(UIKit.divider())
		_spec.add_child(UIKit.paragraph(Loc.t("garage_workshop_sub"), 14, UIKit.MUTED))
	else:
		_show_purchase(base)

func _show_factory_spec(base: VehicleDef, built: VehicleDef) -> void:
	_spec.add_child(UIKit.divider())
	_spec.add_child(UIKit.caption(Loc.t("garage_spec_title")))

	var cols := UIKit.hbox(16)
	_spec.add_child(cols)
	var col_a := UIKit.vbox(2)
	var col_b := UIKit.vbox(2)
	col_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(col_a)
	cols.add_child(col_b)

	var profile: TransmissionProfile = built.fitted_transmission_profile()
	var doc_kw: float = base.doc_power_kw if base.doc_power_kw > 0.0 else base.peak_power_kw()
	var doc_nm: float = base.doc_torque_nm if base.doc_torque_nm > 0.0 else base.peak_torque_nm()

	col_a.add_child(UIKit.stat_row(Loc.t("garage_spec_engine"),
		"%s · %s cc" % [base.engine_code, _thousands(base.displacement_cc)]))
	col_a.add_child(_text_row(Loc.t("garage_spec_aspiration"), _aspiration_label(base)))
	col_a.add_child(_text_row(Loc.t("garage_spec_fuel"), _fuel_label(base)))
	col_a.add_child(UIKit.stat_row(Loc.t("garage_spec_doc_power"),
		"%d kW · %d hp" % [int(doc_kw), int(doc_kw * 1.341)]))
	col_a.add_child(UIKit.stat_row(Loc.t("garage_spec_power_rpm"),
		"%s rpm" % _thousands(int(base.doc_power_rpm))))
	col_a.add_child(UIKit.stat_row(Loc.t("garage_spec_doc_torque"), "%d Nm" % int(doc_nm)))
	col_a.add_child(UIKit.stat_row(Loc.t("garage_spec_torque_rpm"),
		"%s rpm" % _thousands(int(base.doc_torque_rpm))))

	col_b.add_child(_text_row(Loc.t("garage_spec_gearbox"), profile.label(Loc.lang) if profile != null else "—"))
	col_b.add_child(UIKit.stat_row(Loc.t("garage_spec_gears"),
		str(profile.gear_count()) if profile != null else "—"))
	col_b.add_child(UIKit.stat_row(Loc.t("garage_spec_transfer"), " / ".join(base.transfer_ids)))
	col_b.add_child(UIKit.stat_row(Loc.t("garage_spec_kerb"), "%s kg" % _thousands(int(base.mass_kg))))
	col_b.add_child(UIKit.stat_row(Loc.t("garage_spec_dimensions"), "%.2f × %.2f × %.2f m" % [
		base.length_m, base.width_m, base.height_m]))
	col_b.add_child(UIKit.stat_row(Loc.t("garage_spec_wheelbase"), "%.2f m" % base.wheelbase_m))
	col_b.add_child(UIKit.stat_row(Loc.t("garage_spec_tyre"),
		base.tyre_size_label if not base.tyre_size_label.is_empty() else "—"))
	var tank_l: float = float(base.spec_value("fuel_tank_l", 0.0))
	if tank_l > 0.0:
		col_b.add_child(UIKit.stat_row(Loc.t("garage_spec_tank"), "%d L" % int(tank_l)))

	_spec.add_child(UIKit.spacer(2))
	_spec.add_child(UIKit.caption(Loc.t("garage_spec_arch")))
	_spec.add_child(_ltr_paragraph(base.suspension_arch, 14, UIKit.IVORY))
	_spec.add_child(UIKit.caption(Loc.t("garage_spec_drivetrain")))
	_spec.add_child(_ltr_paragraph(base.drivetrain_label, 14, UIKit.IVORY))

func _show_build(built: VehicleDef) -> void:
	var info: Dictionary = built.build_info
	var power_kw: float = float(info.get("power_kw", 0.0))
	var power_hp: float = float(info.get("power_hp", power_kw * 1.341))
	var boost: float = float(info.get("boost_bar", 0.0))
	var fuel_limited: bool = bool(info.get("fuel_limited", false))
	var cooling: bool = bool(info.get("cooling_marginal", false))

	_spec.add_child(UIKit.divider())
	_spec.add_child(UIKit.caption(Loc.t("garage_build_title")))
	var cols := UIKit.hbox(16)
	_spec.add_child(cols)
	var col_a := UIKit.vbox(2)
	var col_b := UIKit.vbox(2)
	col_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(col_a)
	cols.add_child(col_b)

	col_a.add_child(UIKit.stat_row(Loc.t("garage_build_power"),
		"%d kW · %d hp" % [int(power_kw), int(power_hp)], UIKit.AMBER))
	col_a.add_child(UIKit.stat_row(Loc.t("garage_build_torque"), "%d Nm" % int(info.get("torque_nm", 0.0))))
	col_a.add_child(UIKit.stat_row(Loc.t("garage_build_redline"),
		"%s rpm" % _thousands(int(info.get("redline_rpm", 0.0)))))
	col_b.add_child(UIKit.stat_row(Loc.t("garage_build_mass"), "%s kg" % _thousands(int(info.get("mass_kg", built.mass_kg)))))
	col_b.add_child(UIKit.stat_row(Loc.t("garage_build_extra"),
		"+%d kg" % int(info.get("extra_mass_kg", 0.0))))
	col_b.add_child(UIKit.stat_row(Loc.t("garage_build_boost"), "%.2f bar" % boost,
		UIKit.AMBER if boost > 0.01 else UIKit.IVORY))
	col_b.add_child(UIKit.stat_row(Loc.t("garage_build_upgrades"), str(_upgrade_count(built))))

	var status := UIKit.hbox(14)
	_spec.add_child(status)
	status.add_child(_status_chip(Loc.t("garage_status_fuel"), fuel_limited))
	status.add_child(_status_chip(Loc.t("garage_status_cooling"), cooling))
	status.add_child(_push())

	var warnings: Array = info.get("warnings", [])
	if warnings.is_empty():
		_spec.add_child(UIKit.caption(Loc.t("garage_no_warnings")))
	else:
		_spec.add_child(UIKit.caption(Loc.t("garage_warnings")))
		for entry: Variant in warnings:
			var severity: int = 0
			if entry is Dictionary:
				var warn_entry: Dictionary = entry
				severity = int(warn_entry.get("severity", 0))
			_spec.add_child(UIKit.paragraph("• " + _localized(entry), 14,
				UIKit.RED if severity >= 3 else UIKit.AMBER))

func _show_purchase(base: VehicleDef) -> void:
	_spec.add_child(UIKit.divider())
	var row := UIKit.hbox(10)
	row.add_child(UIKit.icon("coin", 26, UIKit.GOLD))
	row.add_child(UIKit.value_label(str(base.price), 24, UIKit.GOLD))
	row.add_child(_push())
	var unlocked: bool = SaveManager.is_vehicle_unlocked(base)
	var buy := UIKit.button(Loc.t("garage_buy"), true, "coin")
	buy.custom_minimum_size = Vector2(180, 50)
	buy.disabled = not unlocked or SaveManager.credits() < base.price
	buy.pressed.connect(_buy_vehicle.bind(base.id))
	row.add_child(buy)
	_spec.add_child(row)
	if not unlocked:
		var track: TrackDef = Content.track_by_id(base.unlock_track)
		_spec.add_child(UIKit.paragraph(Loc.t("garage_unlock_track", {
			"track": track.label(Loc.lang) if track != null else base.unlock_track}), 15, UIKit.AMBER))

func _refresh_hub() -> void:
	_clear(_hub)
	var owned: bool = Content.vehicle_by_id(_current) != null and SaveManager.is_vehicle_owned(_current)
	if not owned:
		_hub.add_child(UIKit.paragraph(Loc.t("garage_need_own"), 15, UIKit.MUTED))
		return
	for tile: Dictionary in HUB:
		_hub.add_child(_hub_tile(tile))
	_hub.add_child(UIKit.divider())
	var setup_tile := UIKit.button(Loc.t("garage_setup_presets"), false, "differential")
	setup_tile.custom_minimum_size = Vector2(0, 52)
	setup_tile.add_theme_font_size_override("font_size", 17)
	setup_tile.pressed.connect(_open_setup)
	_hub.add_child(setup_tile)
	_hub.add_child(UIKit.paragraph(Loc.t("garage_setup_note"), 12, UIKit.MUTED))

func _hub_tile(tile: Dictionary) -> Control:
	var col := UIKit.vbox(1)
	var btn := UIKit.button(Loc.t(String(tile["title"])), false, String(tile["icon"]))
	btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(_open_tile.bind(tile))
	col.add_child(btn)
	var note := UIKit.caption(Loc.t(String(tile["note"])))
	note.add_theme_font_size_override("font_size", 12)
	col.add_child(note)
	return col

# -------------------------------------------------------------------- actions ---

func _view_vehicle(vehicle_id: String) -> void:
	_current = vehicle_id
	GameSession.vehicle_id = vehicle_id
	AudioDirector.ui_click()
	_refresh_roster()
	_show_vehicle(_current)
	_refresh_hub()

func _select_vehicle(vehicle_id: String) -> void:
	SaveManager.select_vehicle(vehicle_id)
	GameSession.vehicle_id = vehicle_id
	_current = vehicle_id
	AudioDirector.ui_confirm()
	UIKit.toast(self, Loc.t("garage_toast_selected"))
	_refresh_all()

func _buy_vehicle(vehicle_id: String) -> void:
	var def: VehicleDef = Content.vehicle_by_id(vehicle_id)
	if def == null:
		return
	if not SaveManager.is_vehicle_unlocked(def):
		AudioDirector.play("ui_back", -6.0)
		UIKit.toast(self, Loc.t("garage_locked"))
		return
	if SaveManager.credits() < def.price:
		AudioDirector.play("ui_back", -6.0)
		UIKit.toast(self, Loc.t("toast_not_enough"))
		return
	if SaveManager.buy_vehicle(vehicle_id):
		GameSession.vehicle_id = vehicle_id
		_current = vehicle_id
		AudioDirector.ui_confirm()
		UIKit.toast(self, Loc.t("toast_purchased"))
		_refresh_all()

func _open_tile(tile: Dictionary) -> void:
	GameSession.vehicle_id = _current
	GameSession.set_meta(CATEGORY_META, String(tile.get("category", "")))
	Router.goto(String(tile["scene"]))

func _open_setup() -> void:
	GameSession.vehicle_id = _current
	Router.goto(SETUP_SCENE)

# -------------------------------------------------------------------- helpers ---

func _state_chip(owned: bool, base: VehicleDef) -> Control:
	var text: String
	var color: Color
	if owned:
		text = Loc.t("garage_owned")
		color = UIKit.TEAL
	elif SaveManager.is_vehicle_unlocked(base):
		text = Loc.t("garage_not_owned")
		color = UIKit.AMBER
	else:
		text = Loc.t("garage_locked")
		color = UIKit.RED
	var chip := UIKit.panel(8, true)
	chip.add_child(UIKit.label(text, 14, color, "bold"))
	return chip

func _status_chip(label_text: String, bad: bool) -> Control:
	var chip := UIKit.panel(8, true)
	var row := UIKit.hbox(6)
	row.add_child(UIKit.label(label_text + ":", 14, UIKit.MUTED, "medium"))
	row.add_child(UIKit.label(Loc.t("garage_status_warn") if bad else Loc.t("garage_status_ok"),
		14, UIKit.RED if bad else UIKit.TEAL, "bold"))
	chip.add_child(row)
	return chip

## Row whose value is Persian text, so it must not be forced left-to-right.
func _text_row(label_text: String, value_text: String, color: Color = UIKit.IVORY) -> Control:
	var row := UIKit.hbox(8)
	var l := UIKit.label(label_text, 17, UIKit.MUTED, "medium")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var v := UIKit.label(value_text, 17, color, "bold")
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	row.add_child(v)
	return row

## English technical text: left-to-right and wrapped.
func _ltr_paragraph(text: String, size: int, color: Color) -> Label:
	var l := UIKit.label(text, size, color)
	l.text_direction = Control.TEXT_DIRECTION_LTR
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _aspiration_label(def: VehicleDef) -> String:
	var asp: String = def.aspiration.to_lower()
	if asp.find("turbo") < 0:
		return Loc.t("garage_asp_na")
	if def.fuel_type == "diesel" or def.aspiration == "turbo_diesel":
		return Loc.t("garage_asp_turbo_diesel")
	return Loc.t("garage_asp_turbo_petrol")

func _fuel_label(def: VehicleDef) -> String:
	return Loc.t("garage_fuel_diesel") if def.fuel_type == "diesel" else Loc.t("garage_fuel_petrol")

func _upgrade_count(built: VehicleDef) -> int:
	var count: int = 0
	for slot: int in built.parts.keys():
		var part: PartDef = built.parts[slot] as PartDef
		if part != null and part.tier > 0:
			count += 1
	return count

## Flexible filler for a horizontal row (UIKit.spacer only expands vertically).
func _push() -> Control:
	var c := UIKit.spacer(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

func _localized(entry: Variant) -> String:
	if entry is Dictionary:
		var d: Dictionary = entry
		var text: String = String(d.get(Loc.lang, ""))
		if text.is_empty():
			text = String(d.get("en", ""))
		return text
	return str(entry)

func _thousands(value: int) -> String:
	var raw: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i: int in range(raw.length() - 1, -1, -1):
		out = raw[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out

func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
