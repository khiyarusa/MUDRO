extends Control
## One workshop bay, parameterised by parts category.
##
## The same script drives Engine Lab, Transmission Lab, Suspension Lab, Tire Shop,
## Body & Armour and Brakes. The garage passes the category on GameSession before
## navigating; opening the scene directly falls back to the exported value.
##
## Every part card is real: its price, mass, condition and effect lines come from
## the PartDef, the INSTALL button calls SaveManager.install_part and a rejection
## is shown with the exact reasons PartCompatibility returned.

@export var category: String = "engine"

const META_KEY: String = "garage_lab_category"
const GARAGE_SCENE: String = "res://scenes/garage/garage.tscn"

var _vehicle_id: String = ""
var _base: VehicleDef = null
var _slot: int = -1
var _reasons: Array = []
var _warnings: Array = []
var _credits_label: Label
var _parts_title: Label
var _slots_box: VBoxContainer
var _parts_box: VBoxContainer
var _summary_box: VBoxContainer
var _message_box: VBoxContainer

func _ready() -> void:
	UIKit.root(self)
	_resolve_category()
	_resolve_vehicle()
	_build()
	_refresh_all()

func _resolve_category() -> void:
	if GameSession.has_meta(META_KEY):
		var meta: String = String(GameSession.get_meta(META_KEY, ""))
		GameSession.remove_meta(META_KEY)
		if not meta.is_empty():
			category = meta
	if not Content.category_slots().has(category):
		category = "engine"

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
	glow.modulate = Color(1, 1, 1, 0.25)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
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
	titles.add_child(UIKit.title(Loc.t("garage_lab_" + category), 32))
	titles.add_child(UIKit.caption(_base.label(Loc.lang) if _base != null else ""))
	header.add_child(titles)
	header.add_child(_push())
	header.add_child(_credit_chip())

	root_box.add_child(UIKit.caption(Loc.t("garage_lab_hint_" + category)))
	if category == "brakes":
		root_box.add_child(UIKit.caption(Loc.t("garage_lab_hint_brakes_extra")))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(body)

	# Slots (right in RTL).
	var slots_panel := UIKit.panel(12)
	slots_panel.custom_minimum_size = Vector2(248, 0)
	slots_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(slots_panel)
	var slots_col := UIKit.vbox(6)
	slots_panel.add_child(slots_col)
	slots_col.add_child(UIKit.caption(Loc.t("garage_lab_slots")))
	slots_col.add_child(UIKit.divider())
	var slots_scroll := ScrollContainer.new()
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slots_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_col.add_child(slots_scroll)
	_slots_box = UIKit.vbox(6)
	_slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_scroll.add_child(_slots_box)

	# Parts of the selected slot (centre).
	var parts_panel := UIKit.panel(12)
	parts_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(parts_panel)
	var parts_col := UIKit.vbox(6)
	parts_panel.add_child(parts_col)
	_parts_title = UIKit.caption(Loc.t("garage_lab_parts"))
	parts_col.add_child(_parts_title)
	_message_box = UIKit.vbox(6)
	parts_col.add_child(_message_box)
	parts_col.add_child(UIKit.divider())
	var parts_scroll := ScrollContainer.new()
	parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parts_col.add_child(parts_scroll)
	_parts_box = UIKit.vbox(8)
	_parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_scroll.add_child(_parts_box)

	# Live build summary (left).
	var summary_panel := UIKit.panel(12)
	summary_panel.custom_minimum_size = Vector2(296, 0)
	summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(summary_panel)
	var summary_scroll := ScrollContainer.new()
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_panel.add_child(summary_scroll)
	_summary_box = UIKit.vbox(4)
	_summary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_scroll.add_child(_summary_box)

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
	_refresh_slots()
	_refresh_parts()
	_refresh_summary()
	_refresh_messages()

func _refresh_slots() -> void:
	_clear(_slots_box)
	if _base == null:
		_slots_box.add_child(UIKit.paragraph(Loc.t("garage_no_vehicle"), 15, UIKit.MUTED))
		return
	var cfg: Dictionary = SaveManager.vehicle_config(_vehicle_id)
	var slots: Array = Content.category_slots().get(category, [])
	if slots.is_empty():
		_slots_box.add_child(UIKit.paragraph(Loc.t("garage_lab_empty_slot"), 15, UIKit.MUTED))
		return
	if _slot < 0 or not slots.has(_slot):
		_slot = -1
		for raw: Variant in slots:
			var candidate: int = int(raw)
			if Content.stock_part(_vehicle_id, candidate) != null:
				_slot = candidate
				break
	for raw: Variant in slots:
		var slot: int = int(raw)
		var fitted: PartDef = GarageModel.part_at(_base, cfg, slot)
		if fitted == null:
			continue
		var col := UIKit.vbox(1)
		var btn := UIKit.button(fitted.slot_label(Loc.lang), slot == _slot)
		btn.custom_minimum_size = Vector2(0, 38)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_select_slot.bind(slot))
		col.add_child(btn)
		var sub := UIKit.label(fitted.label(Loc.lang), 12, UIKit.MUTED)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(sub)
		_slots_box.add_child(col)

func _refresh_parts() -> void:
	_clear(_parts_box)
	if _base == null or _slot < 0:
		_parts_title.text = Loc.t("garage_lab_parts")
		_parts_box.add_child(UIKit.paragraph(Loc.t("garage_lab_pick_slot"), 15, UIKit.MUTED))
		return
	var cfg: Dictionary = SaveManager.vehicle_config(_vehicle_id)
	var fitted: PartDef = GarageModel.part_at(_base, cfg, _slot)
	if fitted == null:
		_parts_title.text = Loc.t("garage_lab_parts")
		_parts_box.add_child(UIKit.paragraph(Loc.t("garage_lab_pick_slot"), 15, UIKit.MUTED))
		return
	_parts_title.text = "%s · %s" % [Loc.t("garage_lab_parts"), fitted.slot_label(Loc.lang)]
	var list: Array[PartDef] = Content.parts_for_slot(_vehicle_id, _slot)
	if list.is_empty():
		_parts_box.add_child(UIKit.paragraph(Loc.t("garage_lab_empty_slot"), 15, UIKit.MUTED))
		return
	for part: PartDef in list:
		_parts_box.add_child(_part_card(part, fitted))

func _part_card(part: PartDef, fitted: PartDef) -> Control:
	var installed: bool = fitted != null and fitted.id == part.id
	var owned: bool = SaveManager.is_part_owned(_vehicle_id, part.id)

	var card := UIKit.panel(12, not installed)
	var col := UIKit.vbox(4)
	card.add_child(col)

	var head := UIKit.hbox(8)
	var name_label := UIKit.label(part.label(Loc.lang), 19, UIKit.AMBER if installed else UIKit.IVORY, "bold")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name_label)
	head.add_child(_tier_chip(part.tier))
	col.add_child(head)

	var desc := UIKit.paragraph(part.description(Loc.lang), 14, UIKit.MUTED)
	col.add_child(desc)

	for line: String in part.effect_lines(Loc.lang):
		col.add_child(_effect_row(line))

	var foot := UIKit.hbox(8)
	col.add_child(foot)
	var price_row := UIKit.hbox(4)
	price_row.add_child(UIKit.icon("coin", 16, UIKit.GOLD))
	price_row.add_child(UIKit.value_label(str(part.cost), 15, UIKit.GOLD))
	foot.add_child(price_row)
	if not is_zero_approx(part.mass_kg):
		foot.add_child(UIKit.value_label("%+.1f kg" % part.mass_kg, 14, UIKit.MUTED))
	var cond: int = SaveManager.part_condition(_vehicle_id, part.id)
	if cond != PartDef.Condition.NEW:
		foot.add_child(UIKit.label(part.condition_label(Loc.lang), 14, _condition_color(cond), "bold"))
	foot.add_child(_push())

	var action: Button
	if installed:
		action = UIKit.button(Loc.t("garage_lab_installed"), false, "check")
		action.disabled = true
	elif owned:
		action = UIKit.button(Loc.t("garage_lab_install"), true, "wrench")
		action.pressed.connect(_install_part.bind(part.id))
	else:
		action = UIKit.button(Loc.t("garage_lab_buy"), false, "coin")
		action.disabled = SaveManager.credits() < part.cost
		action.pressed.connect(_buy_part.bind(part.id))
	action.custom_minimum_size = Vector2(148, 42)
	action.add_theme_font_size_override("font_size", 16)
	foot.add_child(action)
	return card

func _effect_row(line: String) -> Control:
	var row := UIKit.hbox(6)
	var name_text: String = line
	var value_text: String = ""
	var split: int = line.find(":")
	if split > 0:
		name_text = line.substr(0, split).strip_edges() + ":"
		value_text = line.substr(split + 1).strip_edges()
	var l := UIKit.label(name_text, 14, UIKit.MUTED, "medium")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	if not value_text.is_empty():
		row.add_child(UIKit.value_label(value_text, 14, UIKit.TEAL))
	return row

func _refresh_summary() -> void:
	_clear(_summary_box)
	_summary_box.add_child(UIKit.caption(Loc.t("garage_lab_summary")))
	_summary_box.add_child(UIKit.divider())
	if _base == null:
		return
	var built: VehicleDef = GarageModel.build(_base, SaveManager.vehicle_config(_vehicle_id))
	if built == null:
		return
	var info: Dictionary = built.build_info
	var power_kw: float = float(info.get("power_kw", 0.0))
	var power_hp: float = float(info.get("power_hp", power_kw * 1.341))
	var boost: float = float(info.get("boost_bar", 0.0))
	_summary_box.add_child(UIKit.stat_row(Loc.t("garage_build_power"),
		"%d kW · %d hp" % [int(power_kw), int(power_hp)], UIKit.AMBER))
	_summary_box.add_child(UIKit.stat_row(Loc.t("garage_build_torque"),
		"%d Nm" % int(info.get("torque_nm", 0.0))))
	_summary_box.add_child(UIKit.stat_row(Loc.t("garage_build_mass"),
		"%s kg" % _thousands(int(info.get("mass_kg", built.mass_kg)))))
	_summary_box.add_child(UIKit.stat_row(Loc.t("garage_build_extra"),
		"+%d kg" % int(info.get("extra_mass_kg", 0.0))))
	_summary_box.add_child(UIKit.stat_row(Loc.t("garage_build_boost"), "%.2f bar" % boost,
		UIKit.AMBER if boost > 0.01 else UIKit.IVORY))
	_summary_box.add_child(UIKit.stat_row(Loc.t("garage_build_redline"),
		"%s rpm" % _thousands(int(info.get("redline_rpm", 0.0)))))

	var fuel_limited: bool = bool(info.get("fuel_limited", false))
	var cooling: bool = bool(info.get("cooling_marginal", false))
	_summary_box.add_child(_text_row(Loc.t("garage_status_fuel"),
		Loc.t("garage_status_warn") if fuel_limited else Loc.t("garage_status_ok"),
		UIKit.RED if fuel_limited else UIKit.TEAL))
	_summary_box.add_child(_text_row(Loc.t("garage_status_cooling"),
		Loc.t("garage_status_warn") if cooling else Loc.t("garage_status_ok"),
		UIKit.RED if cooling else UIKit.TEAL))

	var warnings: Array = info.get("warnings", [])
	_summary_box.add_child(UIKit.divider())
	if warnings.is_empty():
		_summary_box.add_child(UIKit.caption(Loc.t("garage_no_warnings")))
	else:
		_summary_box.add_child(UIKit.caption(Loc.t("garage_warnings")))
		for entry: Variant in warnings:
			var severity: int = 0
			if entry is Dictionary:
				var warn_entry: Dictionary = entry
				severity = int(warn_entry.get("severity", 0))
			_summary_box.add_child(UIKit.paragraph("• " + _localized(entry), 13,
				UIKit.RED if severity >= 3 else UIKit.AMBER))

func _refresh_messages() -> void:
	_clear(_message_box)
	var visible_now: bool = not (_reasons.is_empty() and _warnings.is_empty())
	_message_box.visible = visible_now
	if not visible_now:
		return
	var card := UIKit.panel(10, true)
	var col := UIKit.vbox(3)
	card.add_child(col)
	if not _reasons.is_empty():
		col.add_child(UIKit.label(Loc.t("garage_lab_refused"), 16, UIKit.RED, "bold"))
		for entry: Variant in _reasons:
			col.add_child(UIKit.paragraph("• " + _localized(entry), 14, UIKit.RED))
	if not _warnings.is_empty():
		col.add_child(UIKit.label(Loc.t("garage_warnings"), 15, UIKit.AMBER, "bold"))
		for entry: Variant in _warnings:
			col.add_child(UIKit.paragraph("• " + _localized(entry), 14, UIKit.AMBER))
	_message_box.add_child(card)

# -------------------------------------------------------------------- actions ---

func _select_slot(slot: int) -> void:
	_slot = slot
	_reasons = []
	_warnings = []
	AudioDirector.ui_click()
	_refresh_slots()
	_refresh_parts()
	_refresh_messages()

func _buy_part(part_id: String) -> void:
	if SaveManager.buy_part(_vehicle_id, part_id):
		AudioDirector.ui_confirm()
		UIKit.toast(self, Loc.t("garage_lab_bought"))
		_reasons = []
		_warnings = []
		_refresh_all()
	else:
		AudioDirector.play("ui_back", -6.0)
		UIKit.toast(self, Loc.t("toast_not_enough"))

func _install_part(part_id: String) -> void:
	var result: Dictionary = SaveManager.install_part(_vehicle_id, part_id)
	_reasons = result.get("reasons", [])
	_warnings = result.get("warnings", [])
	if bool(result.get("ok", false)):
		AudioDirector.ui_confirm()
		UIKit.toast(self, Loc.t("garage_lab_installed_ok"))
	else:
		AudioDirector.play("ui_back", -6.0)
	_refresh_all()

# -------------------------------------------------------------------- helpers ---

func _tier_chip(tier: int) -> Control:
	var chip := UIKit.panel(6, true)
	var l: Label
	if tier <= 0:
		l = UIKit.label(Loc.t("garage_lab_stock_part"), 12, UIKit.MUTED, "bold")
	else:
		l = UIKit.value_label("T%d" % tier, 12, UIKit.AMBER)
	chip.add_child(l)
	return chip

func _condition_color(condition: int) -> Color:
	match condition:
		PartDef.Condition.NEW:
			return UIKit.TEAL
		PartDef.Condition.USED:
			return UIKit.MUTED
		PartDef.Condition.WORN:
			return UIKit.AMBER
		_:
			return UIKit.RED

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

func _localized(entry: Variant) -> String:
	if entry is Dictionary:
		var d: Dictionary = entry
		var text: String = String(d.get(Loc.lang, ""))
		if text.is_empty():
			text = String(d.get("en", ""))
		return text
	return str(entry)

func _push() -> Control:
	var c := UIKit.spacer(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

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
