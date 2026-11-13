extends Control
## Component upgrades: seven categories, three real tiers each. Buying changes the
## simulation data immediately (GarageModel rebuilds the vehicle from the save).

var _category: int = 0
var _list: VBoxContainer
var _tabs: HBoxContainer
var _credits_label: Label
var _vehicle_id: String = ""

func _ready() -> void:
	UIKit.root(self)
	_vehicle_id = GameSession.vehicle_id
	if _vehicle_id.is_empty():
		_vehicle_id = SaveManager.selected_vehicle()
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.047, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var glow := MenuBackground.new()
	add_child(glow)
	glow.setup("quarry", false)
	glow.modulate = Color(1, 1, 1, 0.28)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)

	var base: VehicleDef = Content.vehicle_by_id(_vehicle_id)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root_box.add_child(header)
	var back := UIKit.button(Loc.t("back"), false, "arrow_right" if Loc.is_rtl() else "arrow_left")
	back.custom_minimum_size = Vector2(150, 54)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: Router.goto("res://scenes/garage/garage.tscn"))
	header.add_child(back)
	var titles := UIKit.vbox(0)
	titles.add_child(UIKit.title(Loc.t("upgrade_title"), 38))
	titles.add_child(UIKit.caption(base.label(Loc.lang) if base != null else ""))
	header.add_child(titles)
	header.add_child(UIKit.spacer(0))
	var chip := UIKit.panel(12, true)
	var chip_row := UIKit.hbox(8)
	chip_row.add_child(UIKit.icon("coin", 26, UIKit.GOLD))
	_credits_label = UIKit.value_label(str(SaveManager.credits()), 20, UIKit.GOLD)
	chip_row.add_child(_credits_label)
	chip.add_child(chip_row)
	header.add_child(chip)

	_tabs = UIKit.hbox(8)
	root_box.add_child(_tabs)
	_build_tabs()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)
	_list = UIKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_refresh()

func _build_tabs() -> void:
	for c: Node in _tabs.get_children():
		c.queue_free()
	for cat: int in range(7):
		var b := UIKit.button(UpgradeDef.category_name(cat, Loc.lang), cat == _category, UpgradeDef.category_icon(cat))
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_select_category.bind(cat))
		_tabs.add_child(b)

func _select_category(cat: int) -> void:
	_category = cat
	_build_tabs()
	_refresh()

func _refresh() -> void:
	if _credits_label != null:
		_credits_label.text = str(SaveManager.credits())
	for c: Node in _list.get_children():
		c.queue_free()
	var owned: Array = SaveManager.vehicle_upgrades(_vehicle_id)
	for up: UpgradeDef in Content.upgrades_for(_category):
		_list.add_child(_upgrade_row(up, owned))

func _upgrade_row(up: UpgradeDef, owned: Array) -> Control:
	var is_owned: bool = owned.has(up.id)
	var prev_owned: bool = up.tier == 1 or owned.has("%s_%d" % [up.id.rsplit("_", true, 1)[0], up.tier - 1])
	var affordable: bool = SaveManager.credits() >= up.cost

	var row := UIKit.panel(14, not is_owned)
	var h := UIKit.hbox(14)
	row.add_child(h)

	var icon_wrap := UIKit.panel(10, true)
	icon_wrap.custom_minimum_size = Vector2(64, 64)
	icon_wrap.add_child(UIKit.icon(up.icon_name(), 40, UIKit.AMBER if is_owned else UIKit.IVORY))
	h.add_child(icon_wrap)

	var text_col := UIKit.vbox(2)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text_col)
	var name_row := UIKit.hbox(8)
	text_col.add_child(name_row)
	name_row.add_child(UIKit.label(up.label(Loc.lang), 22, UIKit.IVORY, "bold"))
	name_row.add_child(UIKit.caption("T%d" % up.tier, UIKit.AMBER if up.tier == 3 else UIKit.MUTED))
	var desc := UIKit.paragraph(up.description(Loc.lang), 16, UIKit.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(desc)
	var effects := UIKit.label(up.effects_summary(Loc.lang), 15, UIKit.TEAL)
	text_col.add_child(effects)

	var action_col := UIKit.vbox(6)
	action_col.custom_minimum_size = Vector2(180, 0)
	h.add_child(action_col)

	var cost_row := UIKit.hbox(6)
	cost_row.add_child(UIKit.icon("coin", 20, UIKit.GOLD))
	cost_row.add_child(UIKit.label(str(up.cost), 18, UIKit.GOLD, "bold"))
	cost_row.add_child(UIKit.spacer(0))
	action_col.add_child(cost_row)

	var btn: Button
	if is_owned:
		btn = UIKit.button(Loc.t("upgrade_owned"), false, "check")
		btn.disabled = true
	elif not prev_owned:
		btn = UIKit.button(Loc.t("upgrade_need_prev"), false, "lock")
		btn.disabled = true
	else:
		btn = UIKit.button(Loc.t("upgrade_buy"), true, "plus")
		btn.disabled = not affordable
		btn.pressed.connect(_buy.bind(up.id))
	btn.custom_minimum_size = Vector2(0, 48)
	action_col.add_child(btn)
	return row

func _buy(upgrade_id: String) -> void:
	if SaveManager.buy_upgrade(_vehicle_id, upgrade_id):
		AudioDirector.ui_confirm()
		UIKit.toast(self, Loc.t("toast_purchased"))
	else:
		AudioDirector.play("ui_back", -6.0)
		UIKit.toast(self, Loc.t("upgrade_insufficient"))
	_refresh()
