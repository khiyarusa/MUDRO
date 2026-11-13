class_name DebugOverlay
extends CanvasLayer
## Development-only physics readout (F3). Shows the real values the simulation is
## using, which is how the hill-climb behaviour was verified.

var vehicle: VehicleBody
var _label: Label
var _panel: PanelContainer

func bind_vehicle(v: VehicleBody) -> void:
	vehicle = v
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 110)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.03, 0.72)
	sb.border_color = Color(0.4, 0.9, 0.7, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.85))
	_label.text_direction = Control.TEXT_DIRECTION_LTR
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_panel.add_child(_label)

func _process(_delta: float) -> void:
	if not visible or vehicle == null or vehicle.telemetry.is_empty() or _label == null:
		return
	var t: Dictionary = vehicle.telemetry
	var front: Dictionary = t.get("front", {})
	var rear: Dictionary = t.get("rear", {})
	var def: VehicleDef = vehicle.definition
	var torque: float = float(t.get("engine_torque", 0.0))
	var total_ratio: float = float(t.get("total_ratio", 0.0))
	var eff: float = def.gearbox.efficiency
	var wheel_torque: float = torque * total_ratio * eff
	var radius: float = def.tire_rear.radius_m
	var tractive: float = wheel_torque / maxf(radius, 0.05)
	var normal: Vector2 = vehicle.axles[0].contact_normal
	var slope_angle: float = acos(clampf(normal.dot(Vector2.UP), -1.0, 1.0))
	var grade_force: float = def.mass_kg * Units.GRAVITY * sin(slope_angle)
	var load_front: float = float(front.get("load", 0.0))
	var load_rear: float = float(rear.get("load", 0.0))
	var speed: float = float(t.get("speed_kmh", 0.0))
	var drag: float = 0.5 * Units.AIR_DENSITY * def.drag_cd * def.frontal_area_m2 * pow(speed / 3.6, 2.0)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("MUDRO PHYSICS  —  %s" % def.id)
	lines.append("mass %.0f kg   speed %.1f km/h   gear %s" % [def.mass_kg, speed, str(t.get("gear", 0))])
	lines.append("rpm %.0f   crank torque %.1f Nm   boost %.2f" % [float(t.get("rpm", 0.0)), torque, vehicle.engine.boost if vehicle.engine != null else 0.0])
	lines.append("gear ratio %.3f x final %.2f = %.3f" % [float(t.get("gear_ratio", 0.0)), def.gearbox.final_drive, total_ratio])
	lines.append("wheel torque %.0f Nm   tractive %.0f N" % [wheel_torque, tractive])
	lines.append("grade %.1f deg (%.0f%%)   F_grade %.0f N" % [rad_to_deg(slope_angle), tan(slope_angle) * 100.0, grade_force])
	lines.append("drag %.0f N   clutch %.2f   airtime %.2f s" % [drag, float(t.get("clutch", 0.0)), float(t.get("airtime", 0.0))])
	lines.append("front  N %.0f  slip %+.2f  F %+.0f  comp %.3f m  %s" % [load_front, float(front.get("slip", 0.0)), float(front.get("force", 0.0)), float(front.get("compression", 0.0)), String(front.get("surface", ""))])
	lines.append("rear   N %.0f  slip %+.2f  F %+.0f  comp %.3f m  %s" % [load_rear, float(rear.get("slip", 0.0)), float(rear.get("force", 0.0)), float(rear.get("compression", 0.0)), String(rear.get("surface", ""))])
	lines.append("grip mu %.2f   omega F %.1f R %.1f rad/s" % [def.tire_rear.mu_scale, vehicle.axles[0].omega, vehicle.axles[1].omega])
	lines.append("integrity %.2f   engine %s   F3 hide" % [float(t.get("damage", 1.0)), "RUN" if bool(t.get("engine_running", false)) else "STALL"])
	_label.text = "\n".join(lines)
