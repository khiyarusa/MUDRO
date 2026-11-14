extends Control
## Dyno: a real pull computed by DynoModel from the EngineBuild the physics uses,
## drawn as torque and power curves, with a stock overlay for comparison.
##
## There are no invented numbers here. Both pulls run through the fitted
## gearbox's third gear, its final drive, the tyre radius and its efficiency, and
## the stock pull is GarageModel.build(base, GarageModel.empty_config()).

const GARAGE_SCENE: String = "res://scenes/garage/garage.tscn"

var _vehicle_id: String = ""
var _base: VehicleDef = null
var _pull: Dictionary = {}
var _stock: Dictionary = {}
var _compare_data: Dictionary = {}
var _show_stock: bool = false
var _gear: int = 3
var _gear_ratio: float = 1.0
var _final_drive: float = 3.9
var _efficiency: float = 0.9
var _radius: float = 0.38
var _credits_label: Label
var _stats_box: VBoxContainer
var _chart: DynoChart

## Two y axes (torque in amber, power in teal) over a shared rpm axis. Stock
## overlays are thin and muted so the current build always reads first.
class DynoChart extends Control:
	var series: Array[Dictionary] = []
	var rpm_min: float = 700.0
	var rpm_max: float = 6000.0
	var torque_max: float = 1.0
	var power_max: float = 1.0
	var has_data: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func set_data(p_rpm_min: float, p_rpm_max: float, p_torque_max: float,
			p_power_max: float, p_series: Array[Dictionary]) -> void:
		rpm_min = p_rpm_min
		rpm_max = maxf(p_rpm_max, p_rpm_min + 100.0)
		torque_max = maxf(p_torque_max, 1.0)
		power_max = maxf(p_power_max, 1.0)
		series = p_series
		has_data = not series.is_empty()
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w < 120.0 or h < 100.0:
			return
		var font: Font = Loc.font_medium()
		if font == null:
			return
		var left: float = 60.0
		var right: float = 60.0
		var top: float = 42.0
		var bottom: float = 46.0
		var plot := Rect2(left, top, maxf(w - left - right, 40.0), maxf(h - top - bottom, 40.0))
		draw_rect(plot, Color(1, 1, 1, 0.04), true)

		var fs: int = 12
		# Horizontal grid: torque on the left axis, power on the right axis.
		for i: int in range(5):
			var t: float = float(i) / 4.0
			var y: float = plot.position.y + plot.size.y * t
			draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(1, 1, 1, 0.08), 1.0)
			var torque_label: String = "%d" % int(round(torque_max * (1.0 - t)))
			var power_label: String = "%d" % int(round(power_max * (1.0 - t)))
			var tw: float = font.get_string_size(torque_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2(plot.position.x - 8.0 - tw, y + 4.0), torque_label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.AMBER)
			draw_string(font, Vector2(plot.end.x + 8.0, y + 4.0), power_label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.TEAL)

		# Vertical grid and rpm ticks every 1000.
		var step: int = 1000
		var first: int = int(ceil(rpm_min / float(step))) * step
		var rpm: int = first
		while float(rpm) <= rpm_max:
			var x: float = plot.position.x + plot.size.x * (float(rpm) - rpm_min) / (rpm_max - rpm_min)
			draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(1, 1, 1, 0.06), 1.0)
			var rpm_label: String = "%d" % rpm
			var lw: float = font.get_string_size(rpm_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2(x - lw * 0.5, plot.end.y + 16.0), rpm_label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.MUTED)
			rpm += step

		# Axis captions.
		draw_string(font, Vector2(plot.position.x, plot.position.y - 14.0),
			Loc.t("garage_dyno_axis_torque"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.AMBER)
		var pw: float = font.get_string_size(Loc.t("garage_dyno_axis_power"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(plot.end.x - pw, plot.position.y - 14.0),
			Loc.t("garage_dyno_axis_power"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEAL)
		var rw: float = font.get_string_size(Loc.t("garage_dyno_axis_rpm"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(plot.position.x + (plot.size.x - rw) * 0.5, plot.end.y + 34.0),
			Loc.t("garage_dyno_axis_rpm"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIKit.MUTED)

		if not has_data:
			draw_string(font, Vector2(plot.position.x, plot.position.y + plot.size.y * 0.5),
				Loc.t("garage_dyno_no_pull"), HORIZONTAL_ALIGNMENT_CENTER, plot.size.x, 15, UIKit.MUTED)
			return

		for entry: Dictionary in series:
			var rpms: PackedFloat32Array = entry.get("rpm", PackedFloat32Array())
			var values: PackedFloat32Array = entry.get("values", PackedFloat32Array())
			var color: Color = entry.get("color", UIKit.IVORY)
			var width: float = float(entry.get("width", 2.0))
			var axis: String = String(entry.get("axis", "torque"))
			if rpms.is_empty() or values.is_empty():
				continue
			var axis_top: float = torque_max if axis == "torque" else power_max
			var points := PackedVector2Array()
			var peak_value: float = 0.0
			var peak_point := Vector2.ZERO
			for i: int in range(rpms.size()):
				var px: float = plot.position.x + plot.size.x * clampf(
					(rpms[i] - rpm_min) / (rpm_max - rpm_min), 0.0, 1.0)
				var py: float = plot.end.y - plot.size.y * clampf(values[i] / axis_top, 0.0, 1.0)
				points.append(Vector2(px, py))
				if values[i] > peak_value:
					peak_value = values[i]
					peak_point = Vector2(px, py)
			if points.size() >= 2:
				draw_polyline(points, color, width, true)
			if peak_value > 0.0:
				draw_circle(peak_point, 3.6, color)

func _ready() -> void:
	UIKit.root(self)
	_resolve_vehicle()
	_build()
	_refresh_all()
	_run_pull()

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
	titles.add_child(UIKit.title(Loc.t("garage_dyno_title"), 32))
	titles.add_child(UIKit.caption((_base.label(Loc.lang) + " · " + Loc.t("garage_dyno_sub")) if _base != null else ""))
	header.add_child(titles)
	header.add_child(_push())
	header.add_child(_credit_chip())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(body)

	var chart_panel := UIKit.panel(10)
	chart_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(chart_panel)
	var chart_col := UIKit.vbox(4)
	chart_panel.add_child(chart_col)
	var legend := UIKit.hbox(14)
	legend.add_child(_legend(UIKit.AMBER, Loc.t("garage_dyno_legend_build") + " · " + Loc.t("garage_dyno_axis_torque")))
	legend.add_child(_legend(UIKit.TEAL, Loc.t("garage_dyno_legend_build") + " · " + Loc.t("garage_dyno_axis_power")))
	legend.add_child(_legend(Color(0.62, 0.63, 0.63), Loc.t("garage_dyno_legend_stock")))
	legend.add_child(_push())
	chart_col.add_child(legend)
	_chart = DynoChart.new()
	_chart.custom_minimum_size = Vector2(0, 260)
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_col.add_child(_chart)
	chart_col.add_child(UIKit.caption(Loc.t("garage_dyno_gearing_note")))

	var side_panel := UIKit.panel(12)
	side_panel.custom_minimum_size = Vector2(304, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(side_panel)
	var side_col := UIKit.vbox(8)
	side_panel.add_child(side_col)
	var run_btn := UIKit.button(Loc.t("garage_dyno_run"), true, "rpm")
	run_btn.custom_minimum_size = Vector2(0, 50)
	run_btn.pressed.connect(_run_pull)
	side_col.add_child(run_btn)
	var compare_btn := UIKit.button(Loc.t("garage_dyno_compare"), false, "speed")
	compare_btn.custom_minimum_size = Vector2(0, 50)
	compare_btn.pressed.connect(_compare_with_stock)
	side_col.add_child(compare_btn)
	side_col.add_child(UIKit.divider())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_col.add_child(scroll)
	_stats_box = UIKit.vbox(4)
	_stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stats_box)

func _credit_chip() -> Control:
	var chip := UIKit.panel(10, true)
	var row := UIKit.hbox(8)
	row.add_child(UIKit.icon("coin", 24, UIKit.GOLD))
	_credits_label = UIKit.value_label(str(SaveManager.credits()), 19, UIKit.GOLD)
	row.add_child(_credits_label)
	chip.add_child(row)
	return chip

func _legend(color: Color, text: String) -> Control:
	var row := UIKit.hbox(6)
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(12, 12)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	row.add_child(UIKit.caption(text))
	return row

# --------------------------------------------------------------------- pulls ---

func _run_pull() -> void:
	if _base == null:
		return
	var built: VehicleDef = GarageModel.build(_base, SaveManager.vehicle_config(_vehicle_id))
	if built == null or built.engine_build == null:
		UIKit.toast(self, Loc.t("garage_dyno_need_engine"))
		return
	var profile: TransmissionProfile = built.fitted_transmission_profile()
	var gear_count: int = profile.gear_count() if profile != null else 1
	_gear = clampi(3, 1, maxi(gear_count, 1))
	_gear_ratio = profile.ratio_for(_gear) if profile != null else 1.0
	_final_drive = profile.final_drive if profile != null else 3.9
	_efficiency = profile.efficiency if profile != null else 0.9
	_radius = built.tire_rear.radius_m
	_pull = DynoModel.pull(built.engine_build, _gear_ratio, _final_drive, _radius, _efficiency)
	if _show_stock:
		_stock = _stock_pull()
		_compare_data = DynoModel.compare(_stock, _pull) if not _stock.is_empty() else {}
	AudioDirector.ui_click()
	_refresh_all()

func _stock_pull() -> Dictionary:
	if _base == null:
		return {}
	var stock: VehicleDef = GarageModel.build(_base, GarageModel.empty_config())
	if stock == null or stock.engine_build == null:
		return {}
	return DynoModel.pull(stock.engine_build, _gear_ratio, _final_drive, _radius, _efficiency)

func _compare_with_stock() -> void:
	if _pull.is_empty():
		_run_pull()
	if _pull.is_empty():
		return
	_stock = _stock_pull()
	if _stock.is_empty():
		return
	_compare_data = DynoModel.compare(_stock, _pull)
	_show_stock = true
	AudioDirector.ui_confirm()
	_refresh_all()

# ------------------------------------------------------------------- refresh ---

func _refresh_all() -> void:
	if _credits_label != null:
		_credits_label.text = str(SaveManager.credits())
	_refresh_stats()
	_refresh_chart()

func _refresh_stats() -> void:
	_clear(_stats_box)
	if _pull.is_empty():
		_stats_box.add_child(UIKit.paragraph(Loc.t("garage_dyno_no_pull"), 15, UIKit.MUTED))
		return
	var peak_torque: float = float(_pull.get("peak_torque_nm", 0.0))
	var peak_torque_rpm: float = float(_pull.get("peak_torque_rpm", 0.0))
	var peak_power: float = float(_pull.get("peak_power_kw", 0.0))
	var peak_power_rpm: float = float(_pull.get("peak_power_rpm", 0.0))
	var rpms: PackedFloat32Array = _pull.get("rpm", PackedFloat32Array())
	_stats_box.add_child(UIKit.stat_row(Loc.t("garage_dyno_peak_torque"),
		"%d Nm @ %s rpm" % [int(peak_torque), _thousands(int(peak_torque_rpm))], UIKit.AMBER))
	_stats_box.add_child(UIKit.stat_row(Loc.t("garage_dyno_peak_power"),
		"%d kW · %d hp @ %s rpm" % [int(peak_power), int(peak_power * 1.341),
		_thousands(int(peak_power_rpm))], UIKit.TEAL))
	_stats_box.add_child(UIKit.divider())
	_stats_box.add_child(UIKit.stat_row(Loc.t("garage_dyno_gear"), str(_gear)))
	_stats_box.add_child(UIKit.stat_row(Loc.t("garage_dyno_ratio"), "%.2f" % (_gear_ratio * _final_drive)))
	_stats_box.add_child(UIKit.stat_row(Loc.t("garage_dyno_redline"),
		"%s rpm" % _thousands(int(_pull.get("redline_rpm", 0.0)))))
	if not rpms.is_empty():
		_stats_box.add_child(UIKit.stat_row(Loc.t("garage_dyno_idle"),
			"%s rpm" % _thousands(int(rpms[0]))))

	_stats_box.add_child(UIKit.divider())
	_stats_box.add_child(UIKit.caption(Loc.t("garage_dyno_delta")))
	if _compare_data.is_empty():
		_stats_box.add_child(UIKit.paragraph(Loc.t("garage_dyno_no_compare"), 14, UIKit.MUTED))
		return
	if not _stock.is_empty():
		_stats_box.add_child(UIKit.stat_row(Loc.t("garage_dyno_legend_stock"),
			"%d Nm · %d kW" % [int(_stock.get("peak_torque_nm", 0.0)),
			int(_stock.get("peak_power_kw", 0.0))]))
	var dt: float = float(_compare_data.get("torque_delta_nm", 0.0))
	var dp: float = float(_compare_data.get("power_delta_kw", 0.0))
	var dt_pct: float = float(_compare_data.get("torque_delta_pct", 0.0))
	var dp_pct: float = float(_compare_data.get("power_delta_pct", 0.0))
	var dr: int = int(_compare_data.get("redline_delta", 0))
	_stats_box.add_child(UIKit.stat_row(Loc.t("garage_dyno_delta_torque"),
		"%+d Nm · %+.1f%%" % [int(dt), dt_pct], _delta_color(dt)))
	_stats_box.add_child(UIKit.stat_row(Loc.t("garage_dyno_delta_power"),
		"%+d kW · %+.1f%%" % [int(dp), dp_pct], _delta_color(dp)))
	_stats_box.add_child(UIKit.stat_row(Loc.t("garage_dyno_redline"),
		"%+d rpm" % dr, _delta_color(float(dr))))

func _refresh_chart() -> void:
	if _chart == null:
		return
	var series: Array[Dictionary] = []
	var rpm_min: float = 700.0
	var rpm_max: float = 6000.0
	var torque_max: float = 0.0
	var power_max: float = 0.0
	if not _pull.is_empty():
		var rpms: PackedFloat32Array = _pull.get("rpm", PackedFloat32Array())
		if not rpms.is_empty():
			rpm_min = rpms[0]
			rpm_max = rpms[rpms.size() - 1]
		series.append({
			"rpm": rpms,
			"values": _pull.get("torque", PackedFloat32Array()),
			"color": UIKit.AMBER, "width": 2.4, "axis": "torque",
		})
		series.append({
			"rpm": rpms,
			"values": _pull.get("power", PackedFloat32Array()),
			"color": UIKit.TEAL, "width": 2.4, "axis": "power",
		})
		torque_max = maxf(torque_max, float(_pull.get("peak_torque_nm", 0.0)))
		power_max = maxf(power_max, float(_pull.get("peak_power_kw", 0.0)))
	if _show_stock and not _stock.is_empty():
		var stock_rpms: PackedFloat32Array = _stock.get("rpm", PackedFloat32Array())
		series.append({
			"rpm": stock_rpms,
			"values": _stock.get("torque", PackedFloat32Array()),
			"color": Color(0.62, 0.63, 0.63), "width": 1.5, "axis": "torque",
		})
		series.append({
			"rpm": stock_rpms,
			"values": _stock.get("power", PackedFloat32Array()),
			"color": Color(0.62, 0.63, 0.63), "width": 1.5, "axis": "power",
		})
		torque_max = maxf(torque_max, float(_stock.get("peak_torque_nm", 0.0)))
		power_max = maxf(power_max, float(_stock.get("peak_power_kw", 0.0)))
	_chart.set_data(rpm_min, rpm_max, torque_max * 1.12, power_max * 1.12, series)

# -------------------------------------------------------------------- helpers ---

func _delta_color(value: float) -> Color:
	if value > 0.0:
		return UIKit.TEAL
	if value < 0.0:
		return UIKit.RED
	return UIKit.MUTED

func _push() -> Control:
	var c := UIKit.spacer(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

func _thousands(value: int) -> String:
	var raw: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i: int in range(raw.length() - 1, -1, -1):
		out = raw[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out

func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
