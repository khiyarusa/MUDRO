class_name UIKit
extends RefCounted
## Programmatic UI kit: one theme, RTL-aware layout helpers and a few composite
## widgets. Building screens in code keeps every screen functional and consistent
## instead of shipping decorative mock-ups.

const BG_DARK: Color = Color(0.043, 0.047, 0.055)
const PANEL: Color = Color(0.086, 0.094, 0.105, 0.94)
const PANEL_SOFT: Color = Color(0.129, 0.137, 0.149, 0.92)
const IVORY: Color = Color(0.957, 0.929, 0.882)
const MUTED: Color = Color(0.62, 0.63, 0.63)
const AMBER: Color = Color(0.93, 0.62, 0.24)
const TEAL: Color = Color(0.36, 0.72, 0.62)
const RED: Color = Color(0.85, 0.34, 0.28)
const GOLD: Color = Color(0.95, 0.75, 0.31)

static var _theme: Theme = null

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = Loc.font_regular()
	t.default_font_size = 21
	t.set_font("font", "Label", Loc.font_regular())
	t.set_font("font", "Button", Loc.font_bold())
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Button", IVORY)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(1, 0.92, 0.78))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.55))
	t.set_stylebox("normal", "Button", _sb(PANEL_SOFT, PANEL_SOFT.lightened(0.18), 2, 12))
	t.set_stylebox("hover", "Button", _sb(PANEL_SOFT.lightened(0.08), AMBER, 2, 12))
	t.set_stylebox("pressed", "Button", _sb(AMBER.darkened(0.55), AMBER, 3, 12))
	t.set_stylebox("disabled", "Button", _sb(Color(0.10, 0.10, 0.11, 0.7), Color(0.20, 0.20, 0.21), 1, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Label", IVORY)
	t.set_stylebox("panel", "PanelContainer", _sb(PANEL, Color(1, 1, 1, 0.06), 1, 14))
	_theme = t
	return t

static func _sb(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func root(host: Control) -> Control:
	host.theme = theme()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	return host

static func label(text: String, size: int = 21, color: Color = IVORY, weight: String = "regular") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var f: Font = Loc.font(weight)
	if f != null:
		l.add_theme_font_override("font", f)
	l.horizontal_alignment = Loc.text_align()
	l.text_direction = Loc.direction()
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

static func paragraph(text: String, size: int = 17, color: Color = MUTED, weight: String = "regular") -> Label:
	var l := label(text, size, color, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Numeric or Latin-only value: always laid out left-to-right so bidi cannot
## reorder "620 kg" into "kg 620".
static func value_label(text: String, size: int = 19, color: Color = IVORY, weight: String = "bold") -> Label:
	var l := label(text, size, color, weight)
	l.text_direction = Control.TEXT_DIRECTION_LTR
	return l

static func title(text: String, size: int = 52) -> Label:
	var l := label(text, size, IVORY, "black")
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l

static func caption(text: String, color: Color = MUTED) -> Label:
	return label(text, 17, color, "medium")

static func button(text: String, primary: bool = false, icon_path: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.text_direction = Loc.direction()
	if icon_path != "":
		var tex: Texture2D = load_icon(icon_path)
		if tex != null:
			b.icon = tex
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 34)
	if primary:
		b.add_theme_stylebox_override("normal", _sb(AMBER.darkened(0.35), AMBER, 2, 14))
		b.add_theme_stylebox_override("hover", _sb(AMBER.darkened(0.2), AMBER.lightened(0.2), 2, 14))
		b.add_theme_color_override("font_color", Color(0.12, 0.09, 0.05))
		b.add_theme_color_override("font_hover_color", Color(0.10, 0.08, 0.04))
	b.pressed.connect(func() -> void: AudioDirector.ui_click())
	return b

static func panel(padding: int = 18, soft: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb: StyleBoxFlat = _sb(PANEL_SOFT if soft else PANEL, Color(1, 1, 1, 0.07), 1, 16)
	sb.content_margin_left = padding
	sb.content_margin_right = padding
	sb.content_margin_top = padding
	sb.content_margin_bottom = padding
	p.add_theme_stylebox_override("panel", sb)
	return p

## Fixed-size HUD panel: a Panel (not a container) so content can never stretch it.
## Add children to get_child(0) (the padded margin).
static func hud_panel(padding: int = 12) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL, Color(1, 1, 1, 0.07), 1, 16))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", padding)
	margin.add_theme_constant_override("margin_right", padding)
	margin.add_theme_constant_override("margin_top", padding)
	margin.add_theme_constant_override("margin_bottom", padding)
	p.add_child(margin)
	return p

static func vbox(separation: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v

static func hbox(separation: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

static func spacer(min_height: int = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, min_height)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func load_icon(icon_name: String) -> Texture2D:
	var path: String = "res://assets/ui/icons/%s.svg" % icon_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

static func icon(icon_name: String, px: int = 40, color: Color = IVORY) -> TextureRect:
	var tr := TextureRect.new()
	var tex: Texture2D = load_icon(icon_name)
	tr.texture = tex
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = color
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

static func medal_icon(medal: int, px: int = 34) -> TextureRect:
	var names: Array[String] = ["medal_bronze", "medal_bronze", "medal_silver", "medal_gold"]
	return icon(names[clampi(medal, 0, 3)], px, IVORY if medal > 0 else MUTED)

static func medal_text(medal: int) -> String:
	match medal:
		3:
			return Loc.t("medal_short_gold")
		2:
			return Loc.t("medal_short_silver")
		1:
			return Loc.t("medal_short_bronze")
		_:
			return Loc.t("medal_short_none")

static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--.--"
	var m: int = int(seconds) / 60
	var s: int = int(seconds) % 60
	var cs: int = int((seconds - floor(seconds)) * 100.0)
	return "%02d:%02d.%02d" % [m, s, cs]

static func stat_row(label_text: String, value_text: String, accent: Color = IVORY) -> HBoxContainer:
	var row := hbox(8)
	var l := label(label_text, 18, MUTED, "medium")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := value_label(value_text, 19, accent)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(l)
	row.add_child(v)
	return row

static func divider() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(1, 1, 1, 0.09)
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func toast(host: Node, text: String) -> void:
	if host == null or text.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	host.add_child(layer)
	var wrap := MarginContainer.new()
	wrap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wrap.offset_top = 26
	wrap.offset_left = -260
	wrap.offset_right = 260
	layer.add_child(wrap)
	var p := panel(14)
	wrap.add_child(p)
	var l := label(text, 20, IVORY, "bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	wrap.modulate.a = 0.0
	var tw := host.create_tween()
	tw.tween_property(wrap, "modulate:a", 1.0, 0.18)
	tw.tween_interval(1.5)
	tw.tween_property(wrap, "modulate:a", 0.0, 0.35)
	tw.tween_callback(layer.queue_free)
