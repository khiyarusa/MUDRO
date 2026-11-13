extends Control
## Career: the three regions, with real progress read from the save profile.

func _ready() -> void:
	UIKit.root(self)
	_build()

func _build() -> void:
	var bg := MenuBackground.new()
	add_child(bg)
	bg.setup("pine", false)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 16)
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
	titles.add_child(UIKit.title(Loc.t("career_title"), 46))
	titles.add_child(UIKit.caption(Loc.t("career_sub")))
	header.add_child(titles)
	header.add_child(UIKit.spacer(0))
	var chip := UIKit.panel(12, true)
	var chip_row := UIKit.hbox(8)
	chip_row.add_child(UIKit.icon("coin", 26, UIKit.GOLD))
	chip_row.add_child(UIKit.value_label(str(SaveManager.credits()), 20, UIKit.GOLD))
	chip.add_child(chip_row)
	header.add_child(chip)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(cards)

	for meta: Dictionary in Content.environments:
		cards.add_child(_env_card(meta))

func _env_card(meta: Dictionary) -> Control:
	var env_id: String = String(meta["id"])
	var list: Array[StageDef] = Content.stages_for(env_id)
	var done: int = 0
	var medals: int = 0
	for s: StageDef in list:
		if SaveManager.is_completed(s.id):
			done += 1
			medals += SaveManager.medal_of(s.id)

	var card := UIKit.panel(16)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var v := UIKit.vbox(10)
	card.add_child(v)

	var art := TextureRect.new()
	art.texture = _env_art(env_id)
	art.custom_minimum_size = Vector2(0, 150)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(1, 1, 1, 0.95)
	v.add_child(art)

	var name_label := UIKit.label(meta[("name_" + Loc.lang)], 28, meta["accent"] as Color, "black")
	v.add_child(name_label)
	var desc := UIKit.paragraph(meta[("desc_" + Loc.lang)], 17, UIKit.MUTED)
	desc.custom_minimum_size = Vector2(0, 52)
	v.add_child(desc)

	var bar := ProgressBar.new()
	bar.max_value = float(list.size())
	bar.value = float(done)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.add_theme_stylebox_override("background", _bar_style(Color(1, 1, 1, 0.12)))
	bar.add_theme_stylebox_override("fill", _bar_style(meta["accent"] as Color))
	v.add_child(bar)

	var info := UIKit.hbox(8)
	info.add_child(UIKit.caption("%d/%d" % [done, list.size()]))
	info.add_child(UIKit.spacer(0))
	info.add_child(UIKit.icon("medal_gold", 24, UIKit.GOLD))
	info.add_child(UIKit.label(str(medals), 18, UIKit.GOLD, "bold"))
	v.add_child(info)

	v.add_child(UIKit.spacer(6))
	var go := UIKit.button(Loc.t("choose_stage"), done > 0 or _env_unlocked(env_id), "map")
	go.pressed.connect(_open_env.bind(env_id))
	v.add_child(go)
	return card

func _env_unlocked(env_id: String) -> bool:
	if env_id == "canyon":
		return true
	var list: Array[StageDef] = Content.stages_for(env_id)
	if list.is_empty():
		return false
	return SaveManager.is_stage_unlocked(list[0].id)

func _env_art(env_id: String) -> Texture2D:
	var path: String = "res://assets/environments/%s/mid.svg" % env_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _bar_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(5)
	return sb

func _open_env(env_id: String) -> void:
	GameSession.mode = "career"
	GameSession.env_filter = env_id
	Router.goto("res://scenes/menus/stage_select.tscn")
