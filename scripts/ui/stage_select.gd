extends Control
## Track select: the five mountain regions, the routes inside the chosen region
## and one detail panel with the real elevation profile.
##
## A route is unlocked when the previous route in Content.tracks order has been
## completed (SaveManager.is_track_unlocked). The race-mode selector is global: a
## route that does not support the chosen mode is marked and cannot be started.

const MARGIN: int = 28
const LIST_WIDTH: int = 500

## Region -> menu art folder. Regions are game data; the art folders are not, so
## the mapping lives here instead of inside the catalogue.
const REGION_ART: Dictionary = {
	"zagros": "canyon",
	"alpine": "quarry",
	"pine": "pine",
	"black_ridge": "black_ridge",
	"glacier": "quarry",
}

var _region_id: String = ""
var _mode: String = "rally"
var _selected_id: String = ""
var _cards: Dictionary = {}
var _tabs: Dictionary = {}
var _mode_buttons: Dictionary = {}
var _list_box: VBoxContainer
var _detail_box: VBoxContainer
var _continue_btn: Button
var _detail_note: Label


## ---------------------------------------------------------------- elevation ---
## The profile is drawn, not faked: elevation_graph() is the authored road.
class ElevationGraph extends Control:
	var points: PackedVector2Array = PackedVector2Array()
	var marks: PackedFloat32Array = PackedFloat32Array()
	var total_m: float = 0.0
	var accent: Color = Color(0.93, 0.62, 0.24)

	func setup(data: PackedVector2Array, checkpoint_x: PackedFloat32Array, length_m: float, color: Color) -> void:
		points = data
		marks = checkpoint_x
		total_m = maxf(length_m, 1.0)
		accent = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		var size_now: Vector2 = size
		if size_now.x < 8.0 or size_now.y < 8.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size_now), Color(1, 1, 1, 0.035), true)
		if points.size() < 2:
			return
		var min_y: float = points[0].y
		var max_y: float = points[0].y
		for p: Vector2 in points:
			min_y = minf(min_y, p.y)
			max_y = maxf(max_y, p.y)
		var span: float = maxf(max_y - min_y, 1.0)
		var pad_top: float = 13.0
		var pad_bottom: float = 17.0
		var plot_h: float = maxf(size_now.y - pad_top - pad_bottom, 4.0)
		# Horizontal grid: a reading aid, not decoration.
		for i: int in range(3):
			var gy: float = pad_top + plot_h * float(i) / 2.0
			draw_line(Vector2(0, gy), Vector2(size_now.x, gy), Color(1, 1, 1, 0.06), 1.0)
		var line := PackedVector2Array()
		for p: Vector2 in points:
			var px: float = clampf(p.x / total_m, 0.0, 1.0) * size_now.x
			var py: float = pad_top + (1.0 - (p.y - min_y) / span) * plot_h
			line.append(Vector2(px, py))
		var area := PackedVector2Array(line)
		area.append(Vector2(size_now.x, size_now.y - pad_bottom))
		area.append(Vector2(0.0, size_now.y - pad_bottom))
		draw_colored_polygon(area, Color(accent.r, accent.g, accent.b, 0.20))
		draw_polyline(line, accent, 2.0, true)
		for x_m: float in marks:
			var mx: float = clampf(x_m / total_m, 0.0, 1.0) * size_now.x
			draw_line(Vector2(mx, pad_top), Vector2(mx, size_now.y - pad_bottom), Color(1, 1, 1, 0.22), 1.0)
		var font: Font = Loc.font_medium()
		if font == null:
			return
		var base_y: float = size_now.y - 4.0
		draw_string(font, Vector2(4.0, base_y), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))
		draw_string(font, Vector2(size_now.x - 58.0, base_y), "%d m" % int(total_m), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))
		draw_string(font, Vector2(4.0, 11.0), "%d m" % int(max_y), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))


func _ready() -> void:
	UIKit.root(self)
	_mode = GameSession.mode
	_region_id = _pick_region()
	GameSession.region_filter = _region_id
	_build()
	_refresh_list()
	_refresh_detail()


func _pick_region() -> String:
	if not Content.regions.is_empty():
		for r: Dictionary in Content.regions:
			if String(r["id"]) == GameSession.region_filter:
				return String(r["id"])
		for r: Dictionary in Content.regions:
			for t: TrackDef in Content.tracks_for_region(String(r["id"])):
				if SaveManager.is_track_unlocked(t.id) and not SaveManager.is_completed(t.id):
					return String(r["id"])
		return String(Content.regions[0]["id"])
	return ""


## ----------------------------------------------------------------- layout ----

func _build() -> void:
	var bg := MenuBackground.new()
	add_child(bg)
	bg.setup(String(REGION_ART.get(_region_id, "canyon")), false)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.04, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)

	root_box.add_child(_header())
	root_box.add_child(_region_tabs())
	root_box.add_child(_mode_row())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(body)
	body.add_child(_list_panel())
	body.add_child(_detail_panel())


func _header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var back := UIKit.button(Loc.t("back"), false, "arrow_right" if Loc.is_rtl() else "arrow_left")
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: Router.goto("res://scenes/menus/main_menu.tscn"))
	header.add_child(back)

	var titles := UIKit.vbox(0)
	titles.add_child(UIKit.title(Loc.t("nav_tracks_title"), 26))
	titles.add_child(UIKit.caption(Loc.t("nav_tracks_sub")))
	header.add_child(titles)
	header.add_child(UIKit.spacer(0))

	var chip := UIKit.panel(10, true)
	var chip_row := UIKit.hbox(8)
	chip_row.add_child(UIKit.icon("coin", 24, UIKit.GOLD))
	chip_row.add_child(UIKit.value_label(str(SaveManager.credits()), 19, UIKit.GOLD))
	chip.add_child(chip_row)
	header.add_child(chip)
	return header


func _region_tabs() -> Control:
	var row := HBoxContainer.new()
	row.name = "RegionTabs"
	row.add_theme_constant_override("separation", 8)
	for meta: Dictionary in Content.regions:
		var rid: String = String(meta["id"])
		var accent: Color = meta.get("accent", UIKit.AMBER) as Color
		var tab := _rich_button(62)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_region.bind(rid))
		var box: VBoxContainer = tab.get_meta("box") as VBoxContainer
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(UIKit.label(String(meta["name_" + Loc.lang]), 16, UIKit.IVORY, "bold"))
		var stats: Dictionary = _region_progress(rid)
		var caption := UIKit.hbox(5)
		caption.alignment = BoxContainer.ALIGNMENT_CENTER
		caption.add_child(UIKit.value_label(Loc.t("nav_region_tab_progress", {
			"done": int(stats["done"]), "total": int(stats["total"])}), 13, accent))
		caption.add_child(UIKit.icon("medal_gold", 13, accent))
		caption.add_child(UIKit.value_label(str(int(stats["medals"])), 13, accent))
		box.add_child(caption)
		_tabs[rid] = tab
		row.add_child(tab)
	_paint_tabs()
	return row


func _mode_row() -> Control:
	var wrap := UIKit.panel(8, true)
	var row := UIKit.hbox(10)
	wrap.add_child(row)
	var caption := UIKit.label(Loc.t("nav_mode_title"), 14, UIKit.MUTED, "medium")
	caption.custom_minimum_size = Vector2(104, 0)
	caption.tooltip_text = Loc.t("nav_mode_hint")
	row.add_child(caption)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(grid)
	for mode: String in GameSession.MODES:
		var b := UIKit.button(Loc.t("mode_" + mode))
		b.custom_minimum_size = Vector2(0, 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_set_mode.bind(mode))
		_mode_buttons[mode] = b
		_style_mode_button(b, mode == _mode)
		grid.add_child(b)
	return wrap


func _list_panel() -> Control:
	var panel := UIKit.panel(10)
	panel.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	var v := UIKit.vbox(6)
	panel.add_child(v)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_list_box = UIKit.vbox(8)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)
	return panel


func _detail_panel() -> Control:
	var panel := UIKit.panel(12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var outer := UIKit.vbox(6)
	panel.add_child(outer)
	_detail_box = UIKit.vbox(4)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_detail_box)

	_detail_note = UIKit.caption("")
	_detail_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_detail_note)
	_continue_btn = UIKit.button(Loc.t("nav_continue_briefing"), true, "play")
	_continue_btn.custom_minimum_size = Vector2(0, 50)
	_continue_btn.pressed.connect(_continue_to_briefing)
	outer.add_child(_continue_btn)
	return panel


## ------------------------------------------------------------------ regions ---

func _select_region(region_id: String) -> void:
	if region_id == _region_id:
		return
	_region_id = region_id
	GameSession.region_filter = region_id
	_selected_id = ""
	_refresh_list()
	_refresh_detail()
	_paint_tabs()
	AudioDirector.ui_click()


func _region_progress(region_id: String) -> Dictionary:
	var done: int = 0
	var medals: int = 0
	var tracks: Array[TrackDef] = Content.tracks_for_region(region_id)
	for t: TrackDef in tracks:
		if SaveManager.is_completed(t.id):
			done += 1
			medals += SaveManager.medal_of(t.id)
	return {"done": done, "total": tracks.size(), "medals": medals}


func _paint_tabs() -> void:
	for rid: String in _tabs.keys():
		var tab: Button = _tabs[rid] as Button
		var meta: Dictionary = Content.region_meta(rid)
		var accent: Color = meta.get("accent", UIKit.AMBER) as Color
		var selected: bool = rid == _region_id
		tab.add_theme_stylebox_override("normal", _tab_style(accent, selected, false))
		tab.add_theme_stylebox_override("hover", _tab_style(accent, selected, true))
		tab.add_theme_stylebox_override("pressed", _tab_style(accent, selected, true))


func _tab_style(accent: Color, selected: bool, hovered: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.20) if selected else UIKit.PANEL_SOFT
	if hovered and not selected:
		sb.bg_color = UIKit.PANEL_SOFT.lightened(0.06)
	sb.border_color = accent if selected else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


## --------------------------------------------------------------------- list ---

func _refresh_list() -> void:
	for c: Node in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	_cards.clear()
	var tracks: Array[TrackDef] = Content.tracks_for_region(_region_id)
	if tracks.is_empty():
		_list_box.add_child(UIKit.caption(Loc.t("nav_detail_empty")))
		return
	if _selected_id.is_empty():
		_selected_id = _default_track_id(tracks)
	for i: int in range(tracks.size()):
		var card := _track_card(tracks[i], i + 1)
		_cards[tracks[i].id] = card
		_list_box.add_child(card)
	_paint_cards()


func _default_track_id(tracks: Array[TrackDef]) -> String:
	for t: TrackDef in tracks:
		if SaveManager.is_track_unlocked(t.id) and not SaveManager.is_completed(t.id):
			return t.id
	for t: TrackDef in tracks:
		if SaveManager.is_track_unlocked(t.id):
			return t.id
	return tracks[0].id


func _track_card(track: TrackDef, number: int) -> Button:
	var unlocked: bool = SaveManager.is_track_unlocked(track.id)
	var legal: bool = track.supports_mode(_mode)
	var medal: int = SaveManager.medal_of(track.id)
	var meta: Dictionary = Content.region_meta(track.region)
	var accent: Color = meta.get("accent", UIKit.AMBER) as Color

	var card := _rich_button(112)
	card.pressed.connect(_select_track.bind(track.id))
	var box: VBoxContainer = card.get_meta("box") as VBoxContainer
	box.add_theme_constant_override("separation", 2)

	var top := UIKit.hbox(8)
	var badge := UIKit.label("%02d" % number, 21, accent, "black")
	badge.custom_minimum_size = Vector2(32, 0)
	top.add_child(badge)
	var name_label := UIKit.label(track.label(Loc.lang), 20, UIKit.IVORY if unlocked else UIKit.MUTED, "bold")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(name_label)
	if not legal:
		top.add_child(UIKit.label(Loc.t("nav_mode_blocked_short"), 12, UIKit.RED, "bold"))
	if medal > 0:
		top.add_child(UIKit.medal_icon(medal, 22))
	if not unlocked:
		top.add_child(UIKit.icon("lock", 18, UIKit.MUTED))
	elif SaveManager.is_completed(track.id):
		top.add_child(UIKit.icon("check", 16, UIKit.TEAL))
	box.add_child(top)

	var stats: Dictionary = track.stats()
	var dots := ""
	for d: int in range(6):
		dots += "●" if d < track.difficulty else "○"
	var facts := UIKit.hbox(6)
	facts.add_child(UIKit.label(dots, 12, UIKit.AMBER, "bold"))
	var surface: SurfaceProfile = Content.surfaces.get(String(stats.get("dominant_surface", "hard_dirt")), null) as SurfaceProfile
	var surface_name: String = ""
	if surface != null:
		surface_name = surface.name_fa if Loc.lang == "fa" else surface.name_en
	var length_text := "%.0f m" % float(stats.get("length_m", 0.0))
	var facts_label := UIKit.label(length_text, 13, UIKit.MUTED)
	facts.add_child(facts_label)
	facts.add_child(UIKit.value_label("· +%d m" % int(stats.get("elevation_gain_m", 0.0)), 13, UIKit.MUTED))
	facts.add_child(UIKit.label("· " + surface_name, 13, UIKit.MUTED))
	box.add_child(facts)

	var medals := UIKit.hbox(10)
	medals.add_child(_medal_chip(3, track.medal_gold))
	medals.add_child(_medal_chip(2, track.medal_silver))
	medals.add_child(_medal_chip(1, track.medal_bronze))
	box.add_child(medals)

	var best := UIKit.hbox(8)
	var best_time: float = SaveManager.best_time(track.id)
	best.add_child(UIKit.label(Loc.t("nav_best_time"), 13, UIKit.MUTED, "medium"))
	best.add_child(UIKit.value_label(UIKit.format_time(best_time) if best_time > 0.0 else Loc.t("stage_no_record"),
		14, UIKit.AMBER if best_time > 0.0 else UIKit.MUTED))
	best.add_child(UIKit.spacer(0))
	if not unlocked:
		best.add_child(UIKit.label(Loc.t("stage_locked"), 12, UIKit.MUTED, "medium"))
	box.add_child(best)
	return card


func _medal_chip(medal: int, seconds: float) -> Control:
	var row := UIKit.hbox(4)
	row.add_child(UIKit.medal_icon(medal, 15))
	var color: Color = UIKit.GOLD if medal == 3 else (Color(0.80, 0.82, 0.85) if medal == 2 else Color(0.78, 0.56, 0.36))
	row.add_child(UIKit.value_label(UIKit.format_time(seconds), 13, color))
	return row


func _previous_track(track: TrackDef) -> TrackDef:
	var index: int = SaveManager.track_index(track.id)
	if index > 0:
		return Content.tracks[index - 1]
	return null


func _paint_cards() -> void:
	var meta: Dictionary = Content.region_meta(_region_id)
	var accent: Color = meta.get("accent", UIKit.AMBER) as Color
	for id: String in _cards.keys():
		var card: Button = _cards[id] as Button
		var track: TrackDef = Content.track_by_id(id)
		if track == null:
			continue
		var unlocked: bool = SaveManager.is_track_unlocked(id)
		var legal: bool = track.supports_mode(_mode)
		var selected: bool = id == _selected_id
		card.add_theme_stylebox_override("normal", _card_style(accent, selected, false, legal))
		card.add_theme_stylebox_override("hover", _card_style(accent, selected, true, legal))
		card.add_theme_stylebox_override("pressed", _card_style(accent, true, true, legal))
		card.modulate = Color(1, 1, 1, 1.0) if unlocked else Color(0.72, 0.72, 0.75, 0.85)


func _card_style(accent: Color, selected: bool, hovered: bool, legal: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.PANEL_SOFT.darkened(0.10)
	if selected:
		sb.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	elif hovered:
		sb.bg_color = UIKit.PANEL_SOFT.lightened(0.05)
	sb.border_color = accent if selected else Color(1, 1, 1, 0.07)
	if not legal:
		sb.border_color = Color(0.85, 0.34, 0.28, 0.55)
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb


func _select_track(track_id: String) -> void:
	if track_id == _selected_id:
		return
	_selected_id = track_id
	_paint_cards()
	_refresh_detail()
	AudioDirector.ui_click()


## ------------------------------------------------------------------- detail ---

func _refresh_detail() -> void:
	for c: Node in _detail_box.get_children():
		_detail_box.remove_child(c)
		c.queue_free()
	var track: TrackDef = Content.track_by_id(_selected_id)
	if track == null:
		_detail_box.add_child(UIKit.caption(Loc.t("nav_detail_empty")))
		_update_continue()
		return
	var meta: Dictionary = Content.region_meta(track.region)
	var accent: Color = meta.get("accent", UIKit.AMBER) as Color
	var stats: Dictionary = track.stats()

	# --- title ---
	var head := UIKit.hbox(8)
	var title := UIKit.label(track.label(Loc.lang), 24, UIKit.IVORY, "black")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.label("%s · %s %d" % [
		String(meta.get("name_" + Loc.lang, "")), Loc.t("stage_difficulty"), track.difficulty], 13, UIKit.MUTED))
	head.add_child(UIKit.medal_icon(SaveManager.medal_of(track.id), 24))
	_detail_box.add_child(head)

	# --- brief + elevation profile ---
	var mid := UIKit.hbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var brief_col := UIKit.vbox(2)
	brief_col.custom_minimum_size = Vector2(240, 0)
	brief_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_col.add_child(UIKit.label(Loc.t("nav_profile_title"), 12, UIKit.MUTED, "medium"))
	var brief := UIKit.paragraph(track.brief(Loc.lang), 14, UIKit.IVORY)
	brief.custom_minimum_size = Vector2(0, 52)
	brief_col.add_child(brief)
	mid.add_child(brief_col)
	var graph_col := UIKit.vbox(2)
	graph_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var graph_head := UIKit.hbox(6)
	graph_head.add_child(UIKit.label(Loc.t("nav_elevation"), 12, UIKit.MUTED, "medium"))
	graph_head.add_child(UIKit.spacer(0))
	graph_head.add_child(UIKit.value_label("%.0f m · +%d m" % [
		float(stats.get("length_m", 0.0)), int(stats.get("elevation_gain_m", 0.0))], 12, accent))
	graph_col.add_child(graph_head)
	var graph := ElevationGraph.new()
	graph.custom_minimum_size = Vector2(220, 72)
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.setup(track.elevation_graph(110), track.checkpoints, float(stats.get("length_m", 0.0)), accent)
	graph_col.add_child(graph)
	mid.add_child(graph_col)
	_detail_box.add_child(mid)

	# --- measured route data ---
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var net_m: float = float(stats.get("net_elevation_m", 0.0))
	grid.add_child(_stat_cell(Loc.t("nav_length"), "%d m" % int(stats.get("length_m", 0.0))))
	grid.add_child(_stat_cell(Loc.t("nav_ascent"), "+%d m" % int(stats.get("elevation_gain_m", 0.0)), UIKit.TEAL))
	grid.add_child(_stat_cell(Loc.t("nav_descent"), "-%d m" % int(stats.get("elevation_descent_m", 0.0)), UIKit.AMBER))
	grid.add_child(_stat_cell(Loc.t("nav_net_gain"), "%s%d m" % ["+" if net_m >= 0.0 else "-", int(absf(net_m))]))
	grid.add_child(_stat_cell(Loc.t("nav_max_grade"), "%.1f°" % float(stats.get("max_grade_deg", 0.0)), UIKit.AMBER))
	grid.add_child(_stat_cell(Loc.t("nav_checkpoints"), str(track.checkpoints.size() + 1)))
	_detail_box.add_child(grid)

	# --- surface mix: one stacked bar, named by its dominant surface ---
	var pct: Dictionary = stats.get("surface_pct", {}) as Dictionary
	var mix := UIKit.vbox(3)
	var mix_head := UIKit.hbox(6)
	mix_head.add_child(UIKit.label(Loc.t("nav_surface_mix"), 12, UIKit.MUTED, "medium"))
	mix_head.add_child(UIKit.spacer(0))
	var dominant: SurfaceProfile = Content.surfaces.get(String(stats.get("dominant_surface", "hard_dirt")), null) as SurfaceProfile
	if dominant != null:
		mix_head.add_child(UIKit.label(dominant.name_fa if Loc.lang == "fa" else dominant.name_en, 12, accent, "bold"))
	mix.add_child(mix_head)
	mix.add_child(_surface_bar(pct))
	_detail_box.add_child(mix)

	# --- medal targets + records, one line each ---
	var medal_row := UIKit.hbox(10)
	medal_row.add_child(UIKit.label(Loc.t("nav_medal_times"), 12, UIKit.MUTED, "medium"))
	medal_row.add_child(_medal_target(3, track.medal_gold))
	medal_row.add_child(_medal_target(2, track.medal_silver))
	medal_row.add_child(_medal_target(1, track.medal_bronze))
	medal_row.add_child(UIKit.spacer(0))
	var reward := UIKit.hbox(4)
	reward.add_child(UIKit.icon("coin", 15, UIKit.GOLD))
	reward.add_child(UIKit.value_label(str(track.reward_credits), 13, UIKit.GOLD))
	reward.add_child(UIKit.label("%s %d" % [Loc.t("nav_results_xp"), track.reward_xp], 12, UIKit.MUTED))
	medal_row.add_child(reward)
	_detail_box.add_child(medal_row)

	var records := UIKit.hbox(6)
	records.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var best_time: float = SaveManager.best_time(track.id)
	var vehicle_id: String = SaveManager.selected_vehicle()
	var vehicle_best: float = SaveManager.best_time_for(track.id, vehicle_id)
	records.add_child(_stat_cell(Loc.t("nav_best_time"), UIKit.format_time(best_time), UIKit.AMBER if best_time > 0.0 else UIKit.MUTED))
	records.add_child(_stat_cell(Loc.t("nav_vehicle_best"), UIKit.format_time(vehicle_best), UIKit.IVORY if vehicle_best > 0.0 else UIKit.MUTED))
	records.add_child(_stat_cell(Loc.t("nav_attempts"), str(SaveManager.attempts_of(track.id))))
	_detail_box.add_child(records)

	_update_continue()


func _stat_cell(label_text: String, value_text: String, color: Color = UIKit.IVORY) -> Control:
	var cell := UIKit.vbox(0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UIKit.label(label_text, 11, UIKit.MUTED, "medium")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	cell.add_child(l)
	cell.add_child(UIKit.value_label(value_text, 15, color))
	return cell


func _medal_target(medal: int, seconds: float) -> Control:
	var cell := UIKit.hbox(5)
	cell.add_child(UIKit.medal_icon(medal, 15))
	var color: Color = UIKit.GOLD if medal == 3 else (Color(0.80, 0.82, 0.85) if medal == 2 else Color(0.78, 0.56, 0.36))
	cell.add_child(UIKit.value_label(UIKit.format_time(seconds), 14, color))
	return cell


func _surface_color(surface_id: String) -> Color:
	var s: SurfaceProfile = Content.surfaces.get(surface_id, null) as SurfaceProfile
	if s == null:
		return UIKit.MUTED
	return s.color_top.lightened(0.12)


func _sorted_surfaces(pct: Dictionary) -> Array:
	var keys: Array = pct.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return float(pct[a]) > float(pct[b]))
	return keys


func _surface_bar(pct: Dictionary) -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	bar.custom_minimum_size = Vector2(0, 8)
	var keys: Array = _sorted_surfaces(pct)
	for key: Variant in keys:
		var value: float = float(pct[key])
		if value < 1.0:
			continue
		var seg := ColorRect.new()
		seg.color = _surface_color(String(key))
		seg.custom_minimum_size = Vector2(3, 8)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = maxf(value, 1.0)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(seg)
	return bar


func _update_continue() -> void:
	if _continue_btn == null:
		return
	var track: TrackDef = Content.track_by_id(_selected_id)
	var reason: String = ""
	if track == null:
		reason = Loc.t("nav_detail_empty")
	elif not SaveManager.is_track_unlocked(track.id):
		var prev: TrackDef = _previous_track(track)
		reason = Loc.t("nav_locked_hint", {"track": prev.label(Loc.lang) if prev != null else "—"})
	elif not track.supports_mode(_mode):
		reason = Loc.t("nav_mode_blocked", {"mode": Loc.t("mode_" + _mode)})
	_continue_btn.disabled = not reason.is_empty()
	_detail_note.text = reason
	_detail_note.add_theme_color_override("font_color", UIKit.RED if not reason.is_empty() else UIKit.MUTED)


## --------------------------------------------------------------------- mode ---

func _set_mode(mode: String) -> void:
	if mode == _mode:
		return
	_mode = mode
	GameSession.mode = mode
	for key: String in _mode_buttons.keys():
		_style_mode_button(_mode_buttons[key] as Button, key == mode)
	_paint_cards()
	_update_continue()
	AudioDirector.ui_click()


func _style_mode_button(b: Button, selected: bool) -> void:
	if selected:
		var sb := _tab_style(UIKit.AMBER, true, false)
		sb.bg_color = UIKit.AMBER.darkened(0.12)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("disabled", sb)
		b.add_theme_color_override("font_color", Color(0.12, 0.09, 0.05))
		b.add_theme_color_override("font_hover_color", Color(0.10, 0.08, 0.04))
	else:
		b.add_theme_stylebox_override("normal", _tab_style(UIKit.MUTED, false, false))
		b.add_theme_stylebox_override("hover", _tab_style(UIKit.MUTED, false, true))
		b.add_theme_stylebox_override("pressed", _tab_style(UIKit.MUTED, false, true))
		b.add_theme_color_override("font_color", UIKit.IVORY)


func _continue_to_briefing() -> void:
	var track: TrackDef = Content.track_by_id(_selected_id)
	if track == null or _continue_btn.disabled:
		return
	GameSession.start_stage(track.id, _mode)
	AudioDirector.ui_confirm()
	Router.goto("res://scenes/menus/route_briefing.tscn")


## -------------------------------------------------------------------- misc ---

## A Button that hosts real layout children. Button text stays empty so the
## children are the only thing drawn; every child ignores the mouse.
func _rich_button(height: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.text = ""
	b.text_direction = Loc.direction()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 7)
	b.add_child(margin)
	var box := UIKit.vbox(2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	b.set_meta("box", box)
	b.pressed.connect(func() -> void: AudioDirector.ui_click())
	return b
