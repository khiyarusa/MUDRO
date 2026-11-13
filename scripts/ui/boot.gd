extends Control
## Boot: splash, then the main menu.

var _time: float = 0.0
var _done: bool = false

func _ready() -> void:
	UIKit.root(self)
	var bg := ColorRect.new()
	bg.color = UIKit.BG_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.custom_minimum_size = Vector2(520, 260)
	center.position = Vector2(380, 210)
	center.add_theme_constant_override("separation", 6)
	add_child(center)

	var emblem := UIKit.icon("", 132, UIKit.IVORY)
	var emblem_path: String = "res://assets/ui/emblem.svg"
	if ResourceLoader.exists(emblem_path):
		emblem.texture = load(emblem_path) as Texture2D
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(emblem)

	var title := UIKit.title(Loc.t("app_title").to_upper(), 74)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	var sub := UIKit.label(Loc.t("app_subtitle"), 24, UIKit.AMBER, "medium")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.10)
	bar_bg.custom_minimum_size = Vector2(320, 3)
	bar_bg.position = Vector2(480, 560)
	add_child(bar_bg)
	var bar := ColorRect.new()
	bar.color = UIKit.AMBER
	bar.custom_minimum_size = Vector2(0, 3)
	bar.position = bar_bg.position
	add_child(bar)
	var tw := create_tween()
	tw.tween_property(bar, "custom_minimum_size:x", 320.0, 0.9)

func _process(delta: float) -> void:
	_time += delta
	if _time > 1.15 and not _done:
		_done = true
		Router.goto("res://scenes/menus/main_menu.tscn")
