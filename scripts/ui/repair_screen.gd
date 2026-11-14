extends Control
## Repair bay: every fitted part with its real condition, the price SaveManager
## charges to return it to NEW, and a total bill.
##
## Condition is a state the race wear model writes (SaveManager.apply_race_wear),
## so this screen is the only place the player can pay to reset it.

const GARAGE_SCENE: String = "res://scenes/garage/garage.tscn"

var _vehicle_id: String = ""
var _base: VehicleDef = null
var _credits_label: Label
var _list_box: VBoxContainer
var _side_box: VBoxContainer

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
	titles.add_child(UIKit.title(Loc.t("garage_repair_title"), 32))
	titles.add_child(UIKit.caption((_base.label(Loc.lang) + " · " + Loc.t("garage_repair_sub")) if _base != null else ""))
	header.add_child(titles)
	header.add_child(_push())
	header.add_child(_credit_chip())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(body)

	var list_panel := UIKit.panel(12)
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
	_list_box = UIKit.vbox(7)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)

	var side_panel := UIKit.panel(12)
	side_panel.custom_minimum_size = Vector2(320, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(side_panel)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(side_scroll)
	_side_box = UIKit.vbox(8)
	_side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(_side_box)

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
	_clear(_list_box)
	_clear(_side_box)
	if _base == null:
		_list_box.add_child(UIKit.paragraph(Loc.t("garage_no_vehicle"), 16, UIKit.MUTED))
		return
	var cfg: Dictionary = SaveManager.vehicle_config(_vehicle_id)
	var entries: Array[Dictionary] = GarageModel.fitted_list(_base, cfg)
	entries.sort_custom(_sort_by_wear)
	var total: int = 0
	for entry: Dictionary in entries:
		var part: PartDef = entry["part"] as PartDef
		total += SaveManager.repair_cost(_vehicle_id, part.id)
	for entry: Dictionary in entries:
		_list_box.add_child(_part_row(entry))
	_refresh_side(total)

func _sort_by_wear(a: Dictionary, b: Dictionary) -> bool:
	var ca: int = int(a.get("condition", 0))
	var cb: int = int(b.get("condition", 0))
	if ca == cb:
		return int(a.get("slot", 0)) < int(b.get("slot", 0))
	return ca > cb

func _part_row(entry: Dictionary) -> Control:
	var part: PartDef = entry["part"] as PartDef
	var cond: int = int(entry.get("condition", 0))
	var cost: int = SaveManager.repair_cost(_vehicle_id, part.id)

	var card := UIKit.panel(10, true)
	var row := UIKit.hbox(10)
	card.add_child(row)

	var text_col := UIKit.vbox(1)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	text_col.add_child(UIKit.caption(part.slot_label(Loc.lang)))
	var name_label := UIKit.label(part.label(Loc.lang), 17, UIKit.IVORY, "bold")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(name_label)
	var state_row := UIKit.hbox(6)
	state_row.add_child(UIKit.label(part.condition_label(Loc.lang), 14, _condition_color(cond), "bold"))
	state_row.add_child(UIKit.value_label("×%.2f" % float(PartDef.CONDITION_MULT.get(cond, 1.0)), 13, UIKit.MUTED))
	state_row.add_child(_push())
	text_col.add_child(state_row)

	var cost_col := UIKit.vbox(3)
	cost_col.custom_minimum_size = Vector2(160, 0)
	row.add_child(cost_col)
	var price_row := UIKit.hbox(5)
	price_row.add_child(UIKit.icon("coin", 17, UIKit.GOLD if cost > 0 else UIKit.MUTED))
	price_row.add_child(UIKit.value_label(str(cost), 16, UIKit.GOLD if cost > 0 else UIKit.MUTED))
	price_row.add_child(_push())
	cost_col.add_child(price_row)
	if cost <= 0:
		var ok_label := UIKit.caption(Loc.t("garage_repair_free"))
		ok_label.add_theme_font_size_override("font_size", 13)
		cost_col.add_child(ok_label)
	else:
		var btn := UIKit.button(Loc.t("garage_repair_action"), true, "wrench")
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 15)
		btn.disabled = SaveManager.credits() < cost
		btn.pressed.connect(_repair_part.bind(part.id))
		cost_col.add_child(btn)
	return card

func _refresh_side(total: int) -> void:
	_side_box.add_child(UIKit.caption(Loc.t("garage_repair_total")))
	var total_row := UIKit.hbox(8)
	total_row.add_child(UIKit.icon("coin", 30, UIKit.GOLD))
	total_row.add_child(UIKit.value_label(str(total), 30, UIKit.GOLD if total > 0 else UIKit.TEAL))
	total_row.add_child(_push())
	_side_box.add_child(total_row)

	var all_btn := UIKit.button(Loc.t("garage_repair_all"), true, "wrench")
	all_btn.custom_minimum_size = Vector2(0, 48)
	all_btn.disabled = total <= 0 or SaveManager.credits() <= 0
	all_btn.pressed.connect(_repair_all)
	_side_box.add_child(all_btn)
	_side_box.add_child(UIKit.divider())
	_side_box.add_child(UIKit.paragraph(Loc.t("garage_repair_explain"), 14, UIKit.MUTED))
	_side_box.add_child(UIKit.paragraph(Loc.t("garage_repair_mult_note"), 13, UIKit.MUTED))
	if total <= 0:
		_side_box.add_child(UIKit.paragraph(Loc.t("garage_repair_healthy"), 15, UIKit.TEAL))

# -------------------------------------------------------------------- actions ---

func _repair_part(part_id: String) -> void:
	if SaveManager.repair_part(_vehicle_id, part_id):
		AudioDirector.ui_confirm()
		UIKit.toast(self, Loc.t("garage_repair_ok"))
	else:
		AudioDirector.play("ui_back", -6.0)
		UIKit.toast(self, Loc.t("toast_not_enough"))
	_refresh_all()

func _repair_all() -> void:
	var cfg: Dictionary = SaveManager.vehicle_config(_vehicle_id)
	var entries: Array[Dictionary] = GarageModel.fitted_list(_base, cfg)
	var repaired: int = 0
	for entry: Dictionary in entries:
		var part: PartDef = entry["part"] as PartDef
		if SaveManager.repair_cost(_vehicle_id, part.id) <= 0:
			continue
		if SaveManager.repair_part(_vehicle_id, part.id):
			repaired += 1
	if repaired > 0:
		AudioDirector.ui_confirm()
		UIKit.toast(self, Loc.t("garage_repair_all_ok"))
	else:
		AudioDirector.play("ui_back", -6.0)
		UIKit.toast(self, Loc.t("toast_not_enough"))
	_refresh_all()

# -------------------------------------------------------------------- helpers ---

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

func _push() -> Control:
	var c := UIKit.spacer(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
