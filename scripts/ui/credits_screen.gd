extends Control
## About & licenses: honest attribution for every asset and engine used.

const BODY_FA: String = """MUDRO — فیزیک آفرود

موتور بازی: Godot Engine 4.7.2 Stable (مجوز MIT)
زبان: GDScript با تایپ ایستا
بستر: اندروید، افقی، آفلاین

هنر:
تمام تصاویر ماشین‌ها، محیط‌ها و آیکون‌ها به‌صورت برداری (SVG) و اختصاصی برای این پروژه با دست ساخته شده‌اند. هیچ تصویر، مدل سه‌بعدی یا بستهٔ آمادهٔ شخص ثالثی استفاده نشده است. مجوز: اثر اصلی پروژه، قابل استفادهٔ آزاد (CC0).

صدا:
تمام افکت‌ها، حلقهٔ موتور و محیط با سنتز عددی در اسکریپت tools/asset_processing/gen_audio.gd تولید شده‌اند. هیچ نمونهٔ صوتی دانلودشده یا نمونهٔ بازی‌های تجاری استفاده نشده است.

قلم:
Vazirmatn — ساختهٔ صابر راستی‌کردار — مجوز SIL Open Font License 1.1
https://github.com/rastikerdar/vazirmatn

منابع مهندسی:
مدل‌سازی تعلیق و تایر بر پایهٔ روابط استاندارد دینامیک خودرو (فنر-دمپر، منحنی لغزش تایر، مقاومت شیب و غلتش) پیاده‌سازی شده و با تست‌های خودکار سنجیده می‌شود.

بدون لوگو یا نشان تجاری خودروسازان. تمام نام‌های ماشین خیالی هستند."""

const BODY_EN: String = """MUDRO — OFFROAD PHYSICS

Engine: Godot Engine 4.7.2 Stable (MIT license)
Language: statically typed GDScript
Platform: Android, landscape, offline

Art:
Every vehicle, environment layer and UI icon is hand-authored vector art created specifically for this project. No third-party models, textures or asset packs are used. License: original work of this project, dedicated CC0.

Audio:
Every effect, engine loop and ambience is synthesised numerically by tools/asset_processing/gen_audio.gd. No downloaded samples and no audio ripped from commercial games.

Typeface:
Vazirmatn by Saber Rastikerdar — SIL Open Font License 1.1
https://github.com/rastikerdar/vazirmatn

Engineering references:
Suspension and tyre behaviour follow standard vehicle-dynamics relationships (spring-damper, tyre slip curve, grade and rolling resistance) and are covered by automated tests.

No manufacturer logos or branding. All vehicle names are fictional."""

func _ready() -> void:
	UIKit.root(self)
	var bg := ColorRect.new()
	bg.color = UIKit.BG_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 42)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	col.add_child(header)
	var back := UIKit.button(Loc.t("back"), false, "arrow_right" if Loc.is_rtl() else "arrow_left")
	back.custom_minimum_size = Vector2(150, 54)
	back.pressed.connect(func() -> void: Router.goto("res://scenes/menus/main_menu.tscn"))
	header.add_child(back)
	header.add_child(UIKit.title(Loc.t("credits_title"), 40))
	header.add_child(UIKit.spacer(0))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var text := UIKit.paragraph(BODY_FA if Loc.lang == "fa" else BODY_EN, 18, UIKit.IVORY)
	text.custom_minimum_size = Vector2(0, 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text)
