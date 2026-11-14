extends Control
## Stage select: mode-aware list with lock state, records and rewards.

const FEATURED_CLIMB: Array[String] = ["pine_03", "quarry_04", "canyon_04", "quarry_03"]
const FEATURED_TECHNICAL: Array[String] = ["canyon_03", "pine_02", "quarry_03", "pine_04"]

func _ready() -> void:
	UIKit.root(self)
	_build()

func _stages() -> Array[StageDef]:
	var mode: String = GameSession.mode
	if not GameSession.env_filter.is_empty():
		var list: Array[StageDef] = Content.stages_for(GameSession.env_filter)
		return list
	match mode:
		"hillclimb":
			return _pick(FEATURED_CLIMB)
		"technical":
			return _pick(FEATURED_TECHNICAL)
		_:
			return Content.stages

func _pick(ids: Array[String]) -> Array[StageDef]:
	var out: Array[StageDef] = []
	for id: String in ids:
		var s: StageDef = Content.stage_by_id(id)
		if s != null:
			out.append(s)
	return out

func _build() -> void:
	var mode: String = GameSession.mode
	var env_id: String = GameSession.env_filter
	if env_id.is_empty():
		env_id = "pine"
	var bg := MenuBackground.new()
	add_child(bg)
	bg.setup(env_id, false)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
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
	back.pressed.connect(func() -> void: Router.goto("res://scenes/menus/career.tscn" if mode == "career" else "res://scenes/menus/main_menu.tscn"))
	header.add_child(back)

	var heading := UIKit.vbox(0)
	var mode_title := Loc.t("mode_%s" % mode)
	if not env_id.is_empty() and mode == "career":
		var meta: Dictionary = Content.env_meta(env_id)
		if not meta.is_empty():
			mode_title += " · " + String(meta["name_" + Loc.lang])
	heading.add_child(UIKit.title(mode_title, 40))
	var objective := UIKit.caption(GameSession.objective_text())
	heading.add_child(objective)
	header.add_child(heading)
	header.add_child(UIKit.spacer(0))

	var chip := UIKit.panel(12, true)
	var chip_row := UIKit.hbox(8)
	chip_row.add_child(UIKit.icon("coin", 26, UIKit.GOLD))
	chip_row.add_child(UIKit.value_label(str(SaveManager.credits()), 20, UIKit.GOLD))
	chip.add_child(chip_row)
	header.add_child(chip)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var stages: Array[StageDef] = _stages()
	for i: int in range(stages.size()):
		grid.add_child(_stage_card(stages[i], i + 1))

func _stage_card(stage: StageDef, number: int) -> Control:
	var unlocked: bool = SaveManager.is_stage_unlocked(stage.id)
	var medal: int = SaveManager.medal_of(stage.id)
	var best: float = SaveManager.best_time(stage.id)

	var card := UIKit.panel(14)
	card.custom_minimum_size = Vector2(370, 196)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not unlocked:
		card.modulate = Color(0.72, 0.72, 0.75, 0.85)

	var v := UIKit.vbox(6)
	card.add_child(v)

	var top := UIKit.hbox(8)
	v.add_child(top)
	var badge := UIKit.label("%02d" % number, 26, UIKit.AMBER if unlocked else UIKit.MUTED, "black")
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(badge)
	var name_label := UIKit.label(stage.label(Loc.lang), 23, UIKit.IVORY, "bold")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(name_label)
	if not unlocked:
		top.add_child(UIKit.icon("lock", 26, UIKit.MUTED))
	else:
		top.add_child(UIKit.medal_icon(medal, 28))

	var brief := UIKit.paragraph(stage.brief(Loc.lang), 16, UIKit.MUTED)
	brief.custom_minimum_size = Vector2(0, 44)
	v.add_child(brief)

	var info := UIKit.hbox(8)
	var dots := ""
	for d: int in range(5):
		dots += "●" if d < stage.difficulty else "○"
	var diff := UIKit.label(dots, 15, UIKit.AMBER, "bold")
	diff.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(diff)
	info.add_child(UIKit.spacer(0))
	var time_text: String = UIKit.format_time(best) if best > 0.0 else Loc.t("stage_no_record")
	info.add_child(UIKit.caption(time_text))
	v.add_child(info)

	var bottom := UIKit.hbox(8)
	var reward := UIKit.hbox(6)
	reward.add_child(UIKit.icon("coin", 20, UIKit.GOLD))
	reward.add_child(UIKit.label(str(stage.reward_credits), 17, UIKit.GOLD, "medium"))
	bottom.add_child(reward)
	bottom.add_child(UIKit.spacer(0))
	if unlocked:
		var play := UIKit.button(Loc.t("stage_play"), true, "play")
		play.custom_minimum_size = Vector2(128, 48)
		play.pressed.connect(_start.bind(stage))
		bottom.add_child(play)
	else:
		var hint := UIKit.caption(Loc.t("stage_locked"))
		bottom.add_child(hint)
	v.add_child(bottom)
	return card

func _start(stage: StageDef) -> void:
	GameSession.start_stage(stage.id, GameSession.mode)
	AudioDirector.ui_confirm()
	Router.goto("res://scenes/menus/route_briefing.tscn")
