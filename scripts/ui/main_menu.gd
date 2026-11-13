extends Control
## Main menu: real navigation to every mode, plus a continue shortcut.

func _ready() -> void:
	UIKit.root(self)
	_build()

func _build() -> void:
	var bg := MenuBackground.new()
	add_child(bg)
	bg.setup("canyon", true)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	# --- top bar: language, credits ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	outer.add_child(top)
	if Loc.is_rtl():
		top.add_child(UIKit.spacer(0))
	var lang_btn := UIKit.button(Loc.t("settings_language_fa") if Loc.lang == "en" else "EN", false, "language")
	lang_btn.custom_minimum_size = Vector2(110, 46)
	lang_btn.pressed.connect(_toggle_language)
	top.add_child(lang_btn)

	var chip := UIKit.panel(12, true)
	var chip_row := UIKit.hbox(8)
	chip_row.add_child(UIKit.icon("coin", 28, UIKit.GOLD))
	var credit_label := UIKit.value_label(str(SaveManager.credits()), 22, UIKit.GOLD)
	chip_row.add_child(credit_label)
	chip.add_child(chip_row)
	if Loc.is_rtl():
		top.add_child(chip)
		top.add_child(UIKit.spacer(0))
	else:
		top.add_child(UIKit.spacer(0))
		top.add_child(chip)

	# --- hero column ---
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(mid)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(470, 0)
	col.add_theme_constant_override("separation", 8)
	if Loc.is_rtl():
		mid.add_child(UIKit.spacer(0))
		mid.add_child(col)
	else:
		mid.add_child(col)
		mid.add_child(UIKit.spacer(0))

	var title := UIKit.title(Loc.t("app_title").to_upper(), 64)
	col.add_child(title)
	var sub := UIKit.label(Loc.t("app_subtitle"), 20, UIKit.GOLD, "bold")
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	sub.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)

	var next_stage := _next_playable()
	if next_stage != null:
		var cont := UIKit.button(Loc.t("menu_continue") + " · " + next_stage.label(Loc.lang), true, "play")
		cont.pressed.connect(_continue_career.bind(next_stage))
		col.add_child(cont)

	var career := UIKit.button(Loc.t("menu_career"), next_stage == null, "trophy")
	career.pressed.connect(func() -> void: Router.goto("res://scenes/menus/career.tscn"))
	col.add_child(career)

	var climb := UIKit.button(Loc.t("menu_hillclimb"), false, "suspension")
	climb.pressed.connect(_open_mode.bind("hillclimb"))
	col.add_child(climb)

	var trial := UIKit.button(Loc.t("menu_timetrial"), false, "clock")
	trial.pressed.connect(_open_mode.bind("timetrial"))
	col.add_child(trial)

	var technical := UIKit.button(Loc.t("menu_technical"), false, "wrench")
	technical.pressed.connect(_open_mode.bind("technical"))
	col.add_child(technical)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var garage := UIKit.button(Loc.t("menu_garage"), false, "garage")
	garage.pressed.connect(func() -> void: Router.goto("res://scenes/garage/garage.tscn"))
	row.add_child(garage)
	var settings := UIKit.button(Loc.t("menu_settings"), false, "settings")
	settings.pressed.connect(func() -> void: Router.goto("res://scenes/menus/settings.tscn"))
	row.add_child(settings)
	var credits := UIKit.button(Loc.t("menu_credits"), false, "info")
	credits.pressed.connect(func() -> void: Router.goto("res://scenes/menus/credits.tscn"))
	row.add_child(credits)

	# --- footer ---
	var footer := HBoxContainer.new()
	outer.add_child(footer)
	var prog := UIKit.caption("%s %d/%d  ·  %s %d" % [
		Loc.t("career_progress"), SaveManager.completed_count(), Content.stages.size(),
		Loc.t("career_total"), SaveManager.total_medals()])
	footer.add_child(prog)
	footer.add_child(UIKit.spacer(0))
	var ver := UIKit.caption("v1.0.0 · Godot 4.7.2")
	footer.add_child(ver)

func _next_playable() -> StageDef:
	var last_done: StageDef = null
	for s: StageDef in Content.stages:
		if SaveManager.is_completed(s.id):
			last_done = s
	if last_done == null:
		return Content.stages[0] if not Content.stages.is_empty() else null
	var nxt: StageDef = SaveManager.next_stage_after(last_done.id)
	return nxt

func _continue_career(stage: StageDef) -> void:
	if stage == null:
		return
	GameSession.start_stage(stage.id, "career")
	Router.goto("res://scenes/race/race.tscn")

func _open_mode(mode: String) -> void:
	GameSession.mode = mode
	Router.goto("res://scenes/menus/stage_select.tscn")

func _toggle_language() -> void:
	var code: String = "en" if Loc.lang == "fa" else "fa"
	SettingsService.set_language(code)
	Router.goto("res://scenes/menus/main_menu.tscn", 0.12)
