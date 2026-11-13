class_name ControlLayoutEditor
extends CanvasLayer
## In-race control layout editor. It is an overlay, not a scene change: the race is
## paused underneath, the live control layer switches to edit mode, and every change
## is saved the moment the player closes the sheet.
##
## Dragging a control writes a normalized centre for (preset, control) into
## SettingsService.control_positions, so the layout survives a restart and does not
## depend on the current resolution.

signal closed

var _root: Control
var _controls: TouchControls
var _preview: TransmissionProfile
var _preset_row: HBoxContainer
var _size_label: Label
var _opacity_label: Label
var _margin_label: Label
var _sensitivity_label: Label

func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build()
	_build_controls()

func _build() -> void:
	_root = Control.new()
	_root.theme = UIKit.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.075, 0.085, 0.97), Color(0.95, 0.72, 0.34, 0.35)))
	_root.add_child(bar)

	var inner := UIKit.vbox(6)
	bar.add_child(inner)
	var title_row := UIKit.hbox(12)
	title_row.add_child(UIKit.title(Loc.t("layout_title"), 30))
	title_row.add_child(UIKit.spacer(0))
	var reset := UIKit.button(Loc.t("layout_reset"), false, "reset")
	reset.custom_minimum_size = Vector2(150, 46)
	reset.pressed.connect(_on_reset)
	title_row.add_child(reset)
	var done := UIKit.button(Loc.t("layout_done"), true, "check")
	done.custom_minimum_size = Vector2(150, 46)
	done.pressed.connect(_on_close)
	title_row.add_child(done)
	inner.add_child(title_row)
	inner.add_child(UIKit.caption(Loc.t("layout_hint")))

	var rows := UIKit.hbox(10)
	_preset_row = UIKit.hbox(6)
	rows.add_child(_preset_row)
	rows.add_child(UIKit.spacer(0))
	inner.add_child(rows)
	_rebuild_preset_row()

	var sliders := UIKit.hbox(10)
	sliders.add_child(_slider(Loc.t("settings_size"), "control_scale", inverse_lerp(0.8, 1.35, SettingsService.control_scale), "size"))
	sliders.add_child(_slider(Loc.t("settings_opacity"), "control_opacity", SettingsService.control_opacity, "opacity"))
	sliders.add_child(_slider(Loc.t("layout_margin"), "control_margin", SettingsService.control_margin / 48.0, "margin"))
	sliders.add_child(_slider(Loc.t("layout_sensitivity"), "slider_sensitivity", inverse_lerp(0.55, 1.8, SettingsService.slider_sensitivity), "sensitivity"))
	inner.add_child(sliders)

func _build_controls() -> void:
	_preview = TransmissionProfile.new()
	_preview.id = "preview_h"
	_preview.kind = TransmissionProfile.Kind.MANUAL_H
	_preview.ratios = PackedFloat32Array([3.9, 2.4, 1.7, 1.28, 1.0])
	_preview.requires_clutch = true
	_controls = TouchControls.new()
	_controls.name = "PreviewControls"
	_controls.preview_all = true
	add_child(_controls)
	move_child(_controls, 0)
	_controls.setup(_preview, null)
	_controls.set_edit_mode(true)

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _rebuild_preset_row() -> void:
	for child: Node in _preset_row.get_children():
		child.queue_free()
	var names: Array[String] = [Loc.t("layout_buttons"), Loc.t("layout_slider"), Loc.t("layout_pedals")]
	for i: int in range(TouchControls.PRESETS.size()):
		var preset: String = TouchControls.PRESETS[i]
		var b := UIKit.button(names[i], SettingsService.control_preset == preset)
		b.custom_minimum_size = Vector2(150, 46)
		b.pressed.connect(func() -> void:
			SettingsService.set_value("control_preset", preset)
			_rebuild_preset_row())
		_preset_row.add_child(b)
	var side := UIKit.button(Loc.t("layout_left") if not SettingsService.control_left_handed else Loc.t("layout_right"), false)
	side.custom_minimum_size = Vector2(150, 46)
	side.pressed.connect(func() -> void:
		SettingsService.set_value("control_left_handed", not SettingsService.control_left_handed)
		_rebuild_preset_row())
	_preset_row.add_child(side)

func _slider(label_text: String, key: String, normalized: float, tag: String) -> Control:
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIKit.hbox(6)
	var cap := UIKit.caption(label_text)
	head.add_child(cap)
	head.add_child(UIKit.spacer(0))
	var value_label := UIKit.value_label("%d%%" % int(normalized * 100.0), 15, UIKit.AMBER)
	head.add_child(value_label)
	col.add_child(head)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = clampf(normalized, 0.0, 1.0)
	slider.custom_minimum_size = Vector2(0, 26)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d%%" % int(v * 100.0)
		_apply_slider(key, v, tag))
	col.add_child(slider)
	match tag:
		"size":
			_size_label = value_label
		"opacity":
			_opacity_label = value_label
		"margin":
			_margin_label = value_label
		"sensitivity":
			_sensitivity_label = value_label
	return col

func _apply_slider(key: String, v: float, _tag: String) -> void:
	match key:
		"control_scale":
			SettingsService.control_scale = lerpf(0.8, 1.35, v)
		"control_opacity":
			SettingsService.control_opacity = v
		"control_margin":
			SettingsService.control_margin = v * 48.0
		"slider_sensitivity":
			SettingsService.slider_sensitivity = lerpf(0.55, 1.8, v)
	SettingsService.changed.emit()

func _process(_delta: float) -> void:
	if _root == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var bar: Control = _root.get_node_or_null("TopBar") as Control
	if bar != null:
		bar.position = Vector2(16, 12)
		bar.size = Vector2(view.x - 32, bar.get_combined_minimum_size().y)
	if _controls != null:
		_controls.size = view

func _on_reset() -> void:
	SettingsService.reset_control_layout()
	_controls.rebuild()
	_controls.set_edit_mode(true)
	UIKit.toast(self, Loc.t("toast_saved"))

func _on_close() -> void:
	SettingsService.save_settings()
	if _controls != null:
		_controls.set_edit_mode(false)
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_close()
		get_viewport().set_input_as_handled()
