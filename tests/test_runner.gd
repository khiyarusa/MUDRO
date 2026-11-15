extends Node
## MUDRO 3.0 headless test suite.
##
##   godot --headless --path . res://tests/test_runner.tscn
##
## Prints exactly one PASS/FAIL line per assertion and a final
## `TESTS: <passed>/<total> passed` line, then exits with 0 (nothing failed) or
## 1 (at least one failure).
##
## Coverage:
##   A  authored track profiles: C1 continuity, no steps, length, grade,
##      checkpoints, finish, surface coverage, layout validity, stats
##   B  terrain builder in a real SceneTree: no obstacle/decor colliders
##   C  the five documented vehicles and their stock engine build
##   D  the parts catalogue and the causality of tuning
##   E  the thermal model under a sustained climb
##   F  the dyno
##   G  the gearbox / clutch interlocks
##   H  the v4 -> v5 save migration
##   I  mobile/UI data contracts
##   J  radio content packs and their licence gates
##   K  weather profiles and wind
##   L  3.1 driver experience: default control layout, three-finger multi-touch,
##      the clutch interlock, per-vehicle clutch data, and stalls on real physics

const DOC_VEHICLE_IDS: Array[String] = [
	"jimny_jb74", "hilux_an120", "patrol_y61", "pajero_v80", "lc79",
]
const TRACK_MODES: Array[String] = [
	"rally", "hill_climb", "downhill", "sprint", "time_attack", "endurance",
	"free_drive", "test",
]

const SAMPLE_STEP_M: float = 0.35
const MAX_STEP_RISE_M: float = 0.5
const C1_EPS_M: float = 0.05
const C1_TOLERANCE: float = 0.01
const MIN_TRACK_LENGTH_M: float = 300.0
const MAX_GRADE_DEG: float = 30.0

var _pass: int = 0
var _fail: int = 0

# ------------------------------------------------------------------ harness ---

func _ready() -> void:
	await get_tree().process_frame
	print("=== MUDRO 3.0 TEST SUITE ===")
	print("godot %s   physics %d Hz   ppm %.1f" % [
		Engine.get_version_info()["string"], Engine.physics_ticks_per_second, Units.PPM,
	])
	_test_a_track_quality()
	await _test_b_terrain()
	_test_c_vehicles()
	_test_d_parts_and_tuning()
	_test_e_thermal()
	_test_f_dyno()
	_test_g_transmission()
	_test_h_save_migration()
	_test_i_data_contracts()
	await _test_j_radio()
	_test_k_weather()
	await _test_l_driver31()
	_report()

func _report() -> void:
	var total: int = _pass + _fail
	print("---")
	print("TESTS: %d/%d passed" % [_pass, total])
	get_tree().quit(0 if _fail == 0 else 1)

func _section(title: String) -> void:
	print("")
	print("=== %s ===" % title)

func _check(assertion: String, ok: bool, detail: String = "") -> void:
	var tag: String = "PASS" if ok else "FAIL"
	var suffix: String = "" if detail.is_empty() else "  |  " + detail
	print("%s  %-66s%s" % [tag, assertion, suffix])
	if ok:
		_pass += 1
	else:
		_fail += 1

func _f(value: float, digits: int = 2) -> String:
	return String.num(value, digits)

func _join(items: Array[String]) -> String:
	var out: String = ""
	for i: int in range(items.size()):
		if i > 0:
			out += ", "
		out += items[i]
	return out

func _slot_name(slot: int) -> String:
	return String(PartDef.SLOT_NAMES_EN.get(slot, "slot %d" % slot))

func _fit(pairs: Dictionary) -> Dictionary:
	var cfg: Dictionary = GarageModel.empty_config()
	var parts: Dictionary = {}
	for key: Variant in pairs.keys():
		parts[str(int(key))] = String(pairs[key])
	cfg["parts"] = parts
	return cfg

# ------------------------------------------------------- A. track profiles ---

func _test_a_track_quality() -> void:
	_section("A. Track quality (authored profiles)")
	_check("A. catalogue has 15 tracks", Content.tracks.size() == 15,
		"%d tracks" % Content.tracks.size())

	for track: TrackDef in Content.tracks:
		var tag: String = "A[%s]" % track.id
		var profile: TrackProfile = track.profile()
		var length_m: float = track.length_m()

		# C1: the slope must be identical on both sides of every knot.
		var worst_step: float = 0.0
		var worst_step_x: float = 0.0
		for knot: Vector2 in profile.knots():
			var before: float = profile.slope_at(knot.x - C1_EPS_M)
			var after: float = profile.slope_at(knot.x + C1_EPS_M)
			var delta: float = absf(after - before)
			if delta > worst_step:
				worst_step = delta
				worst_step_x = knot.x
		_check("%s C1-continuous profile" % tag, worst_step < C1_TOLERANCE,
			"worst slope step %s at %s m" % [_f(worst_step, 5), _f(worst_step_x, 1)])

		# No vertical step: a 0.35 m sample may never climb half a metre.
		var max_rise: float = 0.0
		var max_rise_x: float = 0.0
		var x: float = 0.0
		while x + SAMPLE_STEP_M <= length_m:
			var rise: float = absf(track.elevation_at(x + SAMPLE_STEP_M) - track.elevation_at(x))
			if rise > max_rise:
				max_rise = rise
				max_rise_x = x
			x += SAMPLE_STEP_M
		_check("%s no vertical step" % tag, max_rise < MAX_STEP_RISE_M,
			"max %s m per 0.35 m at %s m" % [_f(max_rise, 4), _f(max_rise_x, 1)])

		_check("%s longer than 300 m" % tag, length_m > MIN_TRACK_LENGTH_M,
			"%s m" % _f(length_m, 1))

		var stats: Dictionary = track.stats()
		var max_grade: float = float(stats["max_grade_deg"])
		_check("%s max grade <= 30 deg" % tag, max_grade <= MAX_GRADE_DEG,
			"%s deg" % _f(max_grade, 2))

		# Checkpoints: strictly increasing and inside the drivable road.
		var ordered: bool = true
		var order_detail: String = "no checkpoints"
		var last_cp: float = -100000.0
		for cp: float in track.checkpoints:
			if cp <= last_cp:
				ordered = false
				order_detail = "%s m after %s m" % [_f(cp, 1), _f(last_cp, 1)]
			last_cp = cp
		if track.checkpoints.size() > 1:
			order_detail = "%d checkpoints, %s m .. %s m" % [
				track.checkpoints.size(), _f(track.checkpoints[0], 1), _f(last_cp, 1),
			]
		_check("%s checkpoints strictly increasing" % tag, ordered, order_detail)

		var inside: bool = true
		var inside_detail: String = ""
		var lo: float = track.start_x_m() + 5.0
		var hi: float = track.finish_x_m() - 5.0
		for cp: float in track.checkpoints:
			if cp < lo or cp > hi:
				inside = false
				inside_detail = "%s m outside [%s, %s]" % [_f(cp, 1), _f(lo, 1), _f(hi, 1)]
		if inside_detail.is_empty():
			inside_detail = "window [%s, %s] m" % [_f(lo, 1), _f(hi, 1)]
		_check("%s checkpoints inside the road" % tag, inside, inside_detail)

		_check("%s finish reachable" % tag, track.finish_x_m() < length_m,
			"finish %s m of %s m" % [_f(track.finish_x_m(), 1), _f(length_m, 1)])

		# Surface sections must tile [0, length] exactly: no gap, no overlap.
		var covered: bool = true
		var cover_detail: String = ""
		var cursor: float = 0.0
		for section: Dictionary in track.surface_sections:
			var from_x: float = float(section.get("from", 0.0))
			var to_x: float = float(section.get("to", 0.0))
			if absf(from_x - cursor) > 0.01:
				covered = false
				cover_detail = "section starts at %s m, previous ended at %s m" % [
					_f(from_x, 1), _f(cursor, 1),
				]
				break
			if to_x <= from_x:
				covered = false
				cover_detail = "empty/negative section %s..%s" % [_f(from_x, 1), _f(to_x, 1)]
				break
			cursor = to_x
		if covered and absf(cursor - length_m) > 0.01:
			covered = false
			cover_detail = "surfaces end at %s m, track is %s m" % [
				_f(cursor, 1), _f(length_m, 1),
			]
		if cover_detail.is_empty():
			cover_detail = "%d sections 0..%s m" % [track.surface_sections.size(), _f(cursor, 1)]
		_check("%s surfaces cover the whole length" % tag, covered, cover_detail)

		_check("%s is_valid_layout()" % tag, track.is_valid_layout(),
			"%d segments, %s m" % [track.profile_segments.size(), _f(length_m, 1)])

		var gain: float = float(stats["elevation_gain_m"])
		_check("%s stats() elevation gain > 0" % tag, gain > 0.0,
			"+%s m, -%s m, net %s m" % [
				_f(gain, 1), _f(float(stats["elevation_descent_m"]), 1),
				_f(float(stats["net_elevation_m"]), 1),
			])

		var distribution: Dictionary = track.surface_distribution()
		var sum_pct: float = 0.0
		for sid: String in distribution.keys():
			sum_pct += float(distribution[sid])
		_check("%s surface distribution sums to 100%%" % tag,
			absf(sum_pct - 100.0) <= 0.5, "%s %% over %d surfaces" % [
				_f(sum_pct, 2), distribution.size(),
			])

# ------------------------------------------------ B. the "no obstacles" rule ---

func _collect_shapes(node: Node, out: Array[CollisionShape2D]) -> void:
	for child: Node in node.get_children():
		if child is CollisionShape2D:
			out.append(child as CollisionShape2D)
		_collect_shapes(child, out)

func _sprite_with_collider(node: Node, offenders: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is Sprite2D:
			var shapes: Array[CollisionShape2D] = []
			_collect_shapes(child, shapes)
			if not shapes.is_empty():
				offenders.append("%s(%d)" % [child.name, shapes.size()])
		_sprite_with_collider(child, offenders)

func _test_b_terrain() -> void:
	_section("B. No standalone physical obstacles (TerrainBuilder in a SceneTree)")
	var track: TrackDef = Content.track_by_id("zagros_01")
	_check("B. representative track available", track != null, "zagros_01")

	# scripts/race/race_scene.gd instantiates TerrainBuilder by its global class
	# name, so the name must resolve to the 3.0 track builder in scripts/terrain.
	# (A leftover 2.0 StageDef builder in scripts/stages used to shadow it.)
	var global_script: Variant = TerrainBuilder
	var global_script_path: String = ""
	if global_script is Script:
		global_script_path = (global_script as Script).resource_path
	_check("B. global TerrainBuilder resolves to the track builder",
		global_script_path == "res://scripts/terrain/terrain_builder.gd", global_script_path)

	var terrain_script: Script = load("res://scripts/terrain/terrain_builder.gd")
	var compiles: bool = terrain_script != null and terrain_script.can_instantiate()
	_check("B. track terrain builder compiles", compiles,
		"res://scripts/terrain/terrain_builder.gd did not load" if terrain_script == null
		else "load() returned a script that cannot be instantiated (parse error)")
	if not compiles:
		# The builder cannot run, so none of its runtime contracts can be proven.
		# Every blocked assertion is reported as a failure, never as a pass.
		var blocked: String = "blocked: scripts/terrain/terrain_builder.gd does not compile"
		_check("B. obstacle_collider_count() == 0", false, blocked)
		_check("B. decor_collider_count() == 0", false, blocked)
		_check("B. terrain has decoration to draw", false, blocked)
		_check("B. three StaticBody2D: road + two end walls", false, blocked)
		_check("B. exactly one road StaticBody2D", false, blocked)
		_check("B. other bodies are the two end walls", false, blocked)
		_check("B. decorative sprites carry no CollisionShape2D", false, blocked)
		_check("B. physical CollisionShape2D count is exactly 3", false, blocked)
		_check("B. every non-physical shape is a gate trigger", false, blocked)
		return
	var terrain: Variant = terrain_script.new()
	terrain.name = "TestTerrain"
	add_child(terrain)
	terrain.build(track, Content.surfaces)
	await get_tree().process_frame

	_check("B. obstacle_collider_count() == 0", terrain.obstacle_collider_count() == 0,
		"%d" % terrain.obstacle_collider_count())
	_check("B. decor_collider_count() == 0", terrain.decor_collider_count() == 0,
		"%d" % terrain.decor_collider_count())
	_check("B. terrain has decoration to draw", terrain.decor_count() > 0,
		"%d decor sprites" % terrain.decor_count())

	# Every StaticBody2D is either the single road body or one of the two end walls.
	var bodies: Array[StaticBody2D] = []
	for child: Node in terrain.get_children():
		if child is StaticBody2D:
			bodies.append(child as StaticBody2D)
	var road_bodies: int = 0
	var wall_bodies: int = 0
	var stray_bodies: Array[String] = []
	for body: StaticBody2D in bodies:
		if body.name == "TrackBody" and body.get_child_count() == 1:
			road_bodies += 1
			continue
		# An end wall: one rectangle shape, placed outside the racing surface.
		var ok_wall: bool = body.get_child_count() == 1
		var wall_detail: String = ""
		for shape_child: Node in body.get_children():
			if shape_child is CollisionShape2D:
				var cs := shape_child as CollisionShape2D
				if not (cs.shape is RectangleShape2D):
					ok_wall = false
					wall_detail = "shape is %s" % cs.shape
					continue
				var rect := cs.shape as RectangleShape2D
				var wall_x_m: float = cs.position.x / Units.PPM
				var near_start: bool = absf(wall_x_m + 6.0) < 0.01
				var near_finish: bool = absf(wall_x_m - (track.length_m() + 6.0)) < 0.01
				if not (near_start or near_finish):
					ok_wall = false
					wall_detail = "wall at %s m" % _f(wall_x_m, 1)
				if rect.size.y < 10.0 * Units.PPM:
					ok_wall = false
					wall_detail = "wall only %s m tall" % _f(rect.size.y / Units.PPM, 1)
		if ok_wall:
			wall_bodies += 1
		else:
			stray_bodies.append("%s %s" % [body.name, wall_detail])
	_check("B. three StaticBody2D: road + two end walls", bodies.size() == 3,
		"%d bodies" % bodies.size())
	_check("B. exactly one road StaticBody2D", road_bodies == 1, "%d" % road_bodies)
	_check("B. other bodies are the two end walls", wall_bodies == 2 and stray_bodies.is_empty(),
		"%d walls; unexpected: %s" % [wall_bodies, _join(stray_bodies)])

	var offenders: Array[String] = []
	_sprite_with_collider(terrain, offenders)
	_check("B. decorative sprites carry no CollisionShape2D", offenders.is_empty(),
		"%d offending sprites: %s" % [offenders.size(), _join(offenders)])

	# Physical shapes: the road line plus the two wall rectangles. Gate shapes are
	# Area2D triggers, so they are counted separately and must stay non-physical.
	var shapes: Array[CollisionShape2D] = []
	_collect_shapes(terrain, shapes)
	var body_shapes: int = 0
	var gate_shapes: int = 0
	var stray_shapes: Array[String] = []
	for shape: CollisionShape2D in shapes:
		var parent: Node = shape.get_parent()
		if parent is StaticBody2D or parent is RigidBody2D or parent is CharacterBody2D:
			body_shapes += 1
		elif parent is Area2D:
			gate_shapes += 1
		else:
			stray_shapes.append("%s/%s" % [parent.name, shape.name])
	_check("B. physical CollisionShape2D count is exactly 3", body_shapes == 3,
		"%d physical, %d gate Area2D triggers, %d total" % [
			body_shapes, gate_shapes, shapes.size(),
		])
	_check("B. every non-physical shape is a gate trigger", stray_shapes.is_empty()
		and gate_shapes == track.checkpoints.size() + 1,
		"%d gate shapes for %d checkpoints + finish; stray: %s" % [
			gate_shapes, track.checkpoints.size(), _join(stray_shapes),
		])

	terrain.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------- C. vehicle data ---

func _test_c_vehicles() -> void:
	_section("C. Vehicle data")
	_check("C. five documented vehicles", Content.vehicles.size() == DOC_VEHICLE_IDS.size(),
		"%d vehicles" % Content.vehicles.size())

	for id: String in DOC_VEHICLE_IDS:
		var found: VehicleDef = Content.vehicle_by_id(id)
		_check("C[%s] documented vehicle exists" % id, found != null,
			"-" if found == null else found.name_en)

	for vehicle: VehicleDef in Content.vehicles:
		var tag: String = "C[%s]" % vehicle.id
		_check("%s engine_code" % tag, not vehicle.engine_code.is_empty(), vehicle.engine_code)
		_check("%s displacement_cc" % tag, vehicle.displacement_cc > 0,
			"%d cc" % vehicle.displacement_cc)
		_check("%s gearbox ratios" % tag,
			vehicle.gearbox != null and vehicle.gearbox.ratios.size() >= 4,
			"no gearbox" if vehicle.gearbox == null else "%d ratios" % vehicle.gearbox.ratios.size())
		_check("%s transfer ratios" % tag, vehicle.transfer_ratios.size() >= 2,
			"%d ratios %s" % [vehicle.transfer_ratios.size(), str(vehicle.transfer_ids)])
		_check("%s tyre size label" % tag, not vehicle.tyre_size_label.is_empty(),
			vehicle.tyre_size_label)
		_check("%s documented power/torque" % tag,
			vehicle.doc_power_kw > 0.0 and vehicle.doc_torque_nm > 0.0,
			"%s kW / %s Nm" % [_f(vehicle.doc_power_kw, 1), _f(vehicle.doc_torque_nm, 1)])

		var stock: VehicleDef = GarageModel.stock_build(vehicle)
		var made_torque: float = stock.peak_torque_nm()
		var made_power: float = stock.peak_power_kw()
		var torque_error: float = absf(made_torque - vehicle.doc_torque_nm) / vehicle.doc_torque_nm
		var power_error: float = absf(made_power - vehicle.doc_power_kw) / vehicle.doc_power_kw
		_check("%s stock torque within 8%% of doc" % tag, torque_error <= 0.08,
			"built %s Nm vs doc %s Nm (%s%%)" % [
				_f(made_torque, 1), _f(vehicle.doc_torque_nm, 1), _f(torque_error * 100.0, 2),
			])
		_check("%s stock power within 12%% of doc" % tag, power_error <= 0.12,
			"built %s kW vs doc %s kW (%s%%)" % [
				_f(made_power, 1), _f(vehicle.doc_power_kw, 1), _f(power_error * 100.0, 2),
			])

		var kerb: float = float(vehicle.spec.get("kerb_mass_kg", -1.0))
		_check("%s base mass is the documented kerb mass" % tag,
			kerb > 0.0 and absf(vehicle.mass_kg - kerb) < 0.5,
			"mass %s kg, spec kerb %s kg" % [_f(vehicle.mass_kg, 1), _f(kerb, 1)])

	var mass_clash: String = ""
	var wb_clash: String = ""
	for i: int in range(Content.vehicles.size()):
		for j: int in range(i + 1, Content.vehicles.size()):
			var a: VehicleDef = Content.vehicles[i]
			var b: VehicleDef = Content.vehicles[j]
			if absf(a.mass_kg - b.mass_kg) < 1.0:
				mass_clash = "%s and %s both %s kg" % [a.id, b.id, _f(a.mass_kg, 0)]
			if absf(a.wheelbase_m - b.wheelbase_m) < 0.01:
				wb_clash = "%s and %s both %s m" % [a.id, b.id, _f(a.wheelbase_m, 3)]
	_check("C. no two vehicles share a mass", mass_clash.is_empty(), mass_clash)
	_check("C. no two vehicles share a wheelbase", wb_clash.is_empty(), wb_clash)

# ----------------------------------------------------- D. parts and tuning ---

func _sim_climb(build: EngineBuild, seconds: float, speed_mps: float) -> Dictionary:
	var thermal: ThermalState = ThermalState.new().setup(build, 22.0)
	var dt: float = 0.05
	var steps: int = int(round(seconds / dt))
	for i: int in range(steps):
		thermal.update(dt, build.peak_power_kw, speed_mps, 1.0)
	return {
		"temp_c": thermal.coolant_temp_c,
		"derate": thermal.power_derate(),
		"heat_in_kw": thermal.heat_in_kw,
		"heat_out_kw": thermal.heat_out_kw,
	}

func _test_d_parts_and_tuning() -> void:
	_section("D. Parts and tuning")
	_check("D. part catalogue holds more than 200 parts", Content.part_count() > 200,
		"%d parts" % Content.part_count())

	for vehicle: VehicleDef in Content.vehicles:
		var missing: Array[String] = []
		for slot: int in GarageModel.all_slots():
			if Content.stock_part(vehicle.id, slot) == null:
				missing.append(_slot_name(slot))
		_check("D[%s] stock part for every slot" % vehicle.id, missing.is_empty(),
			"%d slot(s) without a stock part: %s" % [missing.size(), _join(missing)])

	var hilux: VehicleDef = Content.vehicle_by_id("hilux_an120")
	var stock: VehicleDef = GarageModel.stock_build(hilux)
	# A turbo can only make what the ECU asks for, so the ECU tune is held constant
	# on both sides of the fuel comparison: the only variable is the injector set.
	var turbo_diesels: Array[String] = ["hilux_an120", "patrol_y61", "pajero_v80"]
	for vid: String in turbo_diesels:
		var base: VehicleDef = Content.vehicle_by_id(vid)
		var base_stock: VehicleDef = GarageModel.stock_build(base)
		var blown: VehicleDef = GarageModel.build(base, _fit({
			PartDef.Slot.TURBO: "%s_turbo_hybrid" % vid,
			PartDef.Slot.ECU: "%s_ecu_2" % vid,
		}))
		var fuelled: VehicleDef = GarageModel.build(base, _fit({
			PartDef.Slot.TURBO: "%s_turbo_hybrid" % vid,
			PartDef.Slot.ECU: "%s_ecu_2" % vid,
			PartDef.Slot.INJECTORS: "%s_inj_30" % vid,
		}))
		_check("D[%s] hybrid turbo raises peak torque" % vid,
			blown.peak_torque_nm() > base_stock.peak_torque_nm() + 1.0,
			"%s Nm -> %s Nm" % [
				_f(base_stock.peak_torque_nm(), 1), _f(blown.peak_torque_nm(), 1),
			])
		_check("D[%s] +30%% injectors let the turbo make more power" % vid,
			fuelled.peak_power_kw() > blown.peak_power_kw() + 0.5,
			"%s kW -> %s kW (stock %s kW)" % [
				_f(blown.peak_power_kw(), 1), _f(fuelled.peak_power_kw(), 1),
				_f(base_stock.peak_power_kw(), 1),
			])

	var ic_stock: VehicleDef = GarageModel.build(hilux, _fit({
		PartDef.Slot.TURBO: "hilux_an120_turbo_big",
		PartDef.Slot.ECU: "hilux_an120_ecu_2",
		PartDef.Slot.BLOCK: "hilux_an120_block_c",
		PartDef.Slot.PISTONS: "hilux_an120_pist_c",
	}))
	var ic_big: VehicleDef = GarageModel.build(hilux, _fit({
		PartDef.Slot.TURBO: "hilux_an120_turbo_big",
		PartDef.Slot.ECU: "hilux_an120_ecu_2",
		PartDef.Slot.BLOCK: "hilux_an120_block_c",
		PartDef.Slot.PISTONS: "hilux_an120_pist_c",
		PartDef.Slot.INTERCOOLER: "hilux_an120_ic_fmic",
	}))
	_check("D. bigger intercooler lowers charge temperature",
		ic_big.engine_build.charge_temp_c < ic_stock.engine_build.charge_temp_c - 1.0,
		"%s C -> %s C" % [
			_f(ic_stock.engine_build.charge_temp_c, 1),
			_f(ic_big.engine_build.charge_temp_c, 1),
		])

	var rad_stock: VehicleDef = GarageModel.build(hilux, _fit({
		PartDef.Slot.TURBO: "hilux_an120_turbo_big",
		PartDef.Slot.ECU: "hilux_an120_ecu_2",
		PartDef.Slot.BLOCK: "hilux_an120_block_c",
		PartDef.Slot.PISTONS: "hilux_an120_pist_c",
		PartDef.Slot.INJECTORS: "hilux_an120_inj_30",
		PartDef.Slot.FUEL_PUMP: "hilux_an120_pump_race",
		PartDef.Slot.INTERCOOLER: "hilux_an120_ic_race",
	}))
	var rad_big: VehicleDef = GarageModel.build(hilux, _fit({
		PartDef.Slot.TURBO: "hilux_an120_turbo_big",
		PartDef.Slot.ECU: "hilux_an120_ecu_2",
		PartDef.Slot.BLOCK: "hilux_an120_block_c",
		PartDef.Slot.PISTONS: "hilux_an120_pist_c",
		PartDef.Slot.INJECTORS: "hilux_an120_inj_30",
		PartDef.Slot.FUEL_PUMP: "hilux_an120_pump_race",
		PartDef.Slot.INTERCOOLER: "hilux_an120_ic_race",
		PartDef.Slot.RADIATOR: "hilux_an120_rad_race",
	}))
	var climb_small: Dictionary = _sim_climb(rad_stock.engine_build, 120.0, 6.0)
	var climb_large: Dictionary = _sim_climb(rad_big.engine_build, 120.0, 6.0)
	_check("D. bigger radiator lowers the 120 s climb temperature",
		float(climb_large["temp_c"]) < float(climb_small["temp_c"]) - 1.0,
		"%s C -> %s C" % [
			_f(float(climb_small["temp_c"]), 1), _f(float(climb_large["temp_c"]), 1),
		])

	# Shorter final drive: more wheel torque in first, less top speed.
	var base_profile: TransmissionProfile = hilux.transmission_by_id("hilux_m6")
	var short_profile: TransmissionProfile = base_profile.duplicate_profile()
	short_profile.final_drive = base_profile.final_drive * 1.15
	var crank_torque: float = stock.peak_torque_nm()
	var wheel_stock: float = crank_torque * base_profile.total_ratio(1, 1.0) * base_profile.efficiency
	var wheel_short: float = crank_torque * short_profile.total_ratio(1, 1.0) * short_profile.efficiency
	_check("D. shorter final drive raises 1st-gear wheel torque", wheel_short > wheel_stock * 1.10,
		"%s Nm -> %s Nm" % [_f(wheel_stock, 0), _f(wheel_short, 0)])
	var radius: float = stock.tire_rear.radius_m
	var max_rpm: float = stock.engine.max_rpm
	_check("D. shorter final drive lowers top speed",
		short_profile.top_speed_mps(radius, max_rpm) < base_profile.top_speed_mps(radius, max_rpm) * 0.95,
		"%s m/s -> %s m/s" % [
			_f(base_profile.top_speed_mps(radius, max_rpm), 2),
			_f(short_profile.top_speed_mps(radius, max_rpm), 2),
		])

	# Larger tyre radius changes gearing for the same rpm.
	var big_tyre: VehicleDef = GarageModel.build(hilux, _fit({
		PartDef.Slot.TYRES: "hilux_an120_tyre_mt_xl",
	}))
	_check("D. oversize tyre has a larger radius",
		big_tyre.tire_rear.radius_m > stock.tire_rear.radius_m + 0.01,
		"%s m -> %s m" % [
			_f(stock.tire_rear.radius_m, 4), _f(big_tyre.tire_rear.radius_m, 4),
		])
	var top_stock: float = base_profile.top_speed_mps(stock.tire_rear.radius_m, max_rpm)
	var top_big: float = base_profile.top_speed_mps(big_tyre.tire_rear.radius_m, max_rpm)
	_check("D. larger tyre radius raises top speed at the same rpm", top_big > top_stock * 1.02,
		"%s m/s -> %s m/s" % [_f(top_stock, 2), _f(top_big, 2)])

	# Compatibility: an under-rated gearbox must be refused.
	var weak_box := PartDef.new()
	weak_box.id = "test_underrated_gearbox"
	weak_box.slot = PartDef.Slot.GEARBOX
	weak_box.name_en = "Test under-rated gearbox"
	weak_box.fits_vehicles = PackedStringArray([hilux.id])
	weak_box.params = {
		"ratios": [3.2, 2.0, 1.4, 1.0], "final_drive": 3.5, "shift_time": 0.3,
		"max_torque_nm": stock.peak_torque_nm() * 0.5,
	}
	var box_verdict: Dictionary = PartCompatibility.check(hilux, GarageModel.empty_config(), weak_box)
	_check("D. compatibility rejects an under-rated gearbox",
		not bool(box_verdict["ok"]) and not (box_verdict["reasons"] as Array).is_empty(),
		"%s" % str(box_verdict["reasons"]))

	# Compatibility: an oversize tyre needs a lift kit.
	var oversize: PartDef = Content.part_by_id("hilux_an120_tyre_mt_xl")
	var no_lift_verdict: Dictionary = PartCompatibility.check(
		hilux, GarageModel.empty_config(), oversize)
	var lift_verdict: Dictionary = PartCompatibility.check(
		hilux, _fit({PartDef.Slot.LIFT_KIT: "hilux_an120_lift_50"}), oversize)
	_check("D. compatibility rejects a tyre that needs a lift kit",
		not bool(no_lift_verdict["ok"]), str(no_lift_verdict["reasons"]))
	_check("D. the same tyre is accepted with a 50 mm lift kit",
		bool(lift_verdict["ok"]), str(lift_verdict["reasons"]))

	# Ownership: installing a part the player has not bought must fail. The real
	# profile is swapped out for the duration of the call and restored untouched;
	# nothing is written to disk.
	var real_data: Dictionary = SaveManager.data.duplicate(true)
	SaveManager.data = {
		"version": 5, "credits": 5000, "xp": 0,
		"selected_vehicle": "jimny_jb74", "owned_vehicles": ["jimny_jb74"],
		"records": {}, "play_time_s": 0.0, "distance_m": 0.0,
		"garage": {"jimny_jb74": {"parts": {}, "owned": [], "condition": {}, "presets": {}}},
	}
	var install: Dictionary = SaveManager.install_part("jimny_jb74", "jimny_jb74_turbo_kit")
	var owned_after: bool = SaveManager.is_part_owned("jimny_jb74", "jimny_jb74_turbo_kit")
	SaveManager.data = real_data
	var refusal: String = ""
	if not (install.get("reasons", []) as Array).is_empty():
		var first: Variant = (install["reasons"] as Array)[0]
		if first is Dictionary:
			refusal = String((first as Dictionary).get("en", ""))
	_check("D. installing a part that is not owned fails",
		not bool(install["ok"]) and not owned_after and refusal.contains("purchased"),
		"ok=%s owned=%s reason=%s" % [str(install["ok"]), str(owned_after), refusal])

# ------------------------------------------------------------- E. thermal ---

func _test_e_thermal() -> void:
	_section("E. Thermal model")
	var hilux: VehicleDef = Content.vehicle_by_id("hilux_an120")
	var stock: VehicleDef = GarageModel.stock_build(hilux)
	var big_turbo: VehicleDef = GarageModel.build(hilux, _fit({
		PartDef.Slot.TURBO: "hilux_an120_turbo_big",
		PartDef.Slot.ECU: "hilux_an120_ecu_2",
		PartDef.Slot.BLOCK: "hilux_an120_block_c",
		PartDef.Slot.PISTONS: "hilux_an120_pist_c",
		PartDef.Slot.INJECTORS: "hilux_an120_inj_30",
		PartDef.Slot.FUEL_PUMP: "hilux_an120_pump_race",
		PartDef.Slot.INTERCOOLER: "hilux_an120_ic_race",
	}))
	_check("E. big-turbo build makes more power than stock",
		big_turbo.peak_power_kw() > stock.peak_power_kw() + 5.0,
		"%s kW -> %s kW" % [_f(stock.peak_power_kw(), 1), _f(big_turbo.peak_power_kw(), 1)])

	# A sustained full-power climb in low range: 3 m/s keeps ram-air small, so the
	# radiator, not the road speed, decides the coolant temperature.
	var stock_climb: Dictionary = _sim_climb(stock.engine_build, 120.0, 3.0)
	var turbo_climb: Dictionary = _sim_climb(big_turbo.engine_build, 120.0, 3.0)
	_check("E. big-turbo build runs hotter than stock on the same radiator",
		float(turbo_climb["temp_c"]) > float(stock_climb["temp_c"]) + 1.0,
		"stock %s C (heat %s/%s kW), turbo %s C (heat %s/%s kW)" % [
			_f(float(stock_climb["temp_c"]), 1),
			_f(float(stock_climb["heat_in_kw"]), 1), _f(float(stock_climb["heat_out_kw"]), 1),
			_f(float(turbo_climb["temp_c"]), 1),
			_f(float(turbo_climb["heat_in_kw"]), 1), _f(float(turbo_climb["heat_out_kw"]), 1),
		])

	var thermal: ThermalState = ThermalState.new().setup(stock.engine_build, 22.0)
	thermal.coolant_temp_c = ThermalState.DERATE_START_C + 1.0
	var above_threshold: float = thermal.power_derate()
	thermal.coolant_temp_c = 120.0
	var at_120: float = thermal.power_derate()
	thermal.coolant_temp_c = ThermalState.DERATE_START_C - 1.0
	var below_threshold: float = thermal.power_derate()
	_check("E. power_derate() == 1.0 below the derate threshold", is_equal_approx(below_threshold, 1.0),
		"%s at %s C" % [_f(below_threshold, 3), _f(ThermalState.DERATE_START_C - 1.0, 0)])
	_check("E. power_derate() < 1.0 above the derate threshold", above_threshold < 1.0,
		"%s at %s C" % [_f(above_threshold, 3), _f(ThermalState.DERATE_START_C + 1.0, 0)])
	_check("E. power_derate() stays above 0.5 at 120 C", at_120 > 0.5 and at_120 < 1.0,
		"%s at 120 C" % _f(at_120, 3))

# ---------------------------------------------------------------- F. dyno ---

func _test_f_dyno() -> void:
	_section("F. Dyno")
	var hilux: VehicleDef = Content.vehicle_by_id("hilux_an120")
	var stock: VehicleDef = GarageModel.stock_build(hilux)
	var tuned: VehicleDef = GarageModel.build(hilux, _fit({
		PartDef.Slot.TURBO: "hilux_an120_turbo_big",
		PartDef.Slot.BLOCK: "hilux_an120_block_c",
		PartDef.Slot.PISTONS: "hilux_an120_pist_c",
		PartDef.Slot.INJECTORS: "hilux_an120_inj_30",
		PartDef.Slot.FUEL_PUMP: "hilux_an120_pump_race",
		PartDef.Slot.INTERCOOLER: "hilux_an120_ic_fmic",
	}))
	var ratio: float = 2.423
	var final_drive: float = 3.583
	var efficiency: float = 0.90
	var stock_pull: Dictionary = DynoModel.pull(
		stock.engine_build, ratio, final_drive, stock.tire_rear.radius_m, efficiency)
	var tuned_pull: Dictionary = DynoModel.pull(
		tuned.engine_build, ratio, final_drive, tuned.tire_rear.radius_m, efficiency)

	var rpm_series: PackedFloat32Array = stock_pull["rpm"] as PackedFloat32Array
	var torque_series: PackedFloat32Array = stock_pull["torque"] as PackedFloat32Array
	var power_series: PackedFloat32Array = stock_pull["power"] as PackedFloat32Array
	var wheel_series: PackedFloat32Array = stock_pull["wheel_torque"] as PackedFloat32Array
	_check("F. pull() returns equal-length series",
		rpm_series.size() == torque_series.size() and torque_series.size() == power_series.size()
		and power_series.size() == wheel_series.size() and rpm_series.size() > 10,
		"%d/%d/%d/%d samples" % [
			rpm_series.size(), torque_series.size(), power_series.size(), wheel_series.size(),
		])

	var peak_torque: float = float(stock_pull["peak_torque_nm"])
	var peak_power: float = float(stock_pull["peak_power_kw"])
	var torque_error: float = absf(peak_torque - stock.engine_build.peak_torque_nm) \
		/ stock.engine_build.peak_torque_nm
	var power_error: float = absf(peak_power - stock.engine_build.peak_power_kw) \
		/ stock.engine_build.peak_power_kw
	_check("F. dyno peak torque matches the engine build within 2%%", torque_error <= 0.02,
		"%s Nm vs %s Nm (%s%%)" % [
			_f(peak_torque, 1), _f(stock.engine_build.peak_torque_nm, 1),
			_f(torque_error * 100.0, 2),
		])
	_check("F. dyno peak power matches the engine build within 2%%", power_error <= 0.02,
		"%s kW vs %s kW (%s%%)" % [
			_f(peak_power, 1), _f(stock.engine_build.peak_power_kw, 1),
			_f(power_error * 100.0, 2),
		])

	# Spot check three samples: wheel torque = crank torque * gear * final * eff.
	var wheel_ok: bool = true
	var wheel_detail: String = ""
	var checks: Array[int] = [3, rpm_series.size() / 2, rpm_series.size() - 2]
	for index: int in checks:
		if index < 0 or index >= wheel_series.size():
			continue
		var expected: float = torque_series[index] * ratio * final_drive * efficiency
		var actual: float = wheel_series[index]
		if absf(actual - expected) > expected * 0.005:
			wheel_ok = false
			wheel_detail = "sample %d: %s vs %s" % [index, _f(actual, 1), _f(expected, 1)]
	if wheel_detail.is_empty():
		wheel_detail = "3 samples of %d agree to 0.5%%" % wheel_series.size()
	_check("F. wheel torque = crank torque * ratio * efficiency", wheel_ok, wheel_detail)

	var comparison: Dictionary = DynoModel.compare(stock_pull, tuned_pull)
	_check("F. stock vs tuned comparison reports more power",
		float(comparison["power_delta_kw"]) > 1.0 and float(comparison["torque_delta_nm"]) > 0.0,
		"+%s kW (+%s%%), +%s Nm (+%s%%)" % [
			_f(float(comparison["power_delta_kw"]), 1),
			_f(float(comparison["power_delta_pct"]), 1),
			_f(float(comparison["torque_delta_nm"]), 1),
			_f(float(comparison["torque_delta_pct"]), 1),
		])

# -------------------------------------------------------- G. transmission ---

func _test_g_transmission() -> void:
	_section("G. Transmission")
	var jimny: VehicleDef = Content.vehicle_by_id("jimny_jb74")
	var hilux: VehicleDef = Content.vehicle_by_id("hilux_an120")
	var manual: TransmissionProfile = jimny.transmission_by_id("jimny_m5")

	var h_box := GearboxState.new()
	h_box.setup(manual)
	h_box.engine_redline = 6000.0
	h_box.wheel_radius = jimny.tire_rear.radius_m
	h_box.reset(1)
	var reverse_reason: String = h_box.can_engage(-1, 5.0, true)
	var reverse_worked: bool = h_box.request_gear(-1, false, true, 5.0)
	_check("G. H-pattern 5-speed refuses reverse while moving forward",
		reverse_reason == GearboxState.REJECT_REVERSE and not reverse_worked
		and h_box.gear == 1,
		"reason '%s', gear %d" % [reverse_reason, h_box.gear])

	# Sequential box (the race gearbox part) shifts up and down without a clutch.
	var seq_built: VehicleDef = GarageModel.build(hilux, _fit({
		PartDef.Slot.GEARBOX: "hilux_an120_gbox_race",
	}))
	var sequential: TransmissionProfile = seq_built.transmissions[0]
	_check("G. race gearbox is a clutchless sequential box",
		sequential.kind == TransmissionProfile.Kind.MANUAL_SEQ and not sequential.requires_clutch,
		"kind %d, requires_clutch %s" % [int(sequential.kind), str(sequential.requires_clutch)])
	var seq_box := GearboxState.new()
	seq_box.setup(sequential)
	seq_box.engine_redline = 4500.0
	seq_box.wheel_radius = hilux.tire_rear.radius_m
	seq_box.reset(1)
	var up: bool = seq_box.shift_up(true, 0.0)
	seq_box.update(0.5)
	var up_gear: int = seq_box.gear
	var down: bool = seq_box.shift_down(true, 0.0)
	_check("G. sequential box shifts up then down",
		up and up_gear == 2 and down and seq_box.gear == 1,
		"1 -> %d -> %d" % [up_gear, seq_box.gear])

	var auto_profile: TransmissionProfile = hilux.transmission_by_id("hilux_a6")
	var auto_box := GearboxState.new()
	auto_box.setup(auto_profile)
	auto_box.engine_redline = 4500.0
	auto_box.wheel_radius = hilux.tire_rear.radius_m
	_check("G. automatic profile is recognised as automatic", auto_box.auto_mode, "auto_mode")

	auto_box.set_range("P")
	var p_locked: bool = auto_box.parking_lock() and auto_box.gear == 0
	var p_refused: bool = not auto_box.request_gear(1, true)
	_check("G. automatic P locks the driveline", p_locked and p_refused,
		"range %s gear %d" % [auto_box.range_id, auto_box.gear])

	# reset() restores the default range, so it must run before set_range().
	auto_box.reset(0)
	auto_box.set_range("N")
	for i: int in range(30):
		auto_box.auto_update(0.1, 5200.0, 0.9, 0.0)
	_check("G. automatic N revs free without engaging a gear", auto_box.gear == 0,
		"range %s gear %d" % [auto_box.range_id, auto_box.gear])

	auto_box.set_range("R")
	_check("G. automatic R selects reverse", auto_box.gear == -1,
		"range %s gear %d" % [auto_box.range_id, auto_box.gear])

	auto_box.reset(1)
	auto_box.set_range("D")
	var upshifted: bool = false
	for i: int in range(80):
		auto_box.auto_update(0.1, 3600.0, 0.5, 10.0, 0.2, 0.0, 0.0)
		if auto_box.gear >= 2:
			upshifted = true
			break
	_check("G. automatic D upshifts under load", upshifted,
		"range %s gear %d" % [auto_box.range_id, auto_box.gear])

	auto_box.reset(1)
	auto_box.set_range("L")
	for i: int in range(80):
		auto_box.auto_update(0.1, 4200.0, 0.7, 14.0, 0.2, 0.0, 0.0)
	_check("G. automatic L caps the gearbox at two gears", auto_box.gear <= 2,
		"range %s gear %d (top %d)" % [auto_box.range_id, auto_box.gear, auto_box.range_top_gear()])

	var clutch_box := GearboxState.new()
	clutch_box.setup(manual)
	clutch_box.reset(1)
	var refused: bool = not clutch_box.request_gear(2, false, false, 0.0)
	var refused_reason: String = clutch_box.reject_reason
	var gear_after_refusal: int = clutch_box.gear
	var accepted: bool = clutch_box.request_gear(2, false, true, 0.0)
	_check("G. manual shift without clutch is refused",
		refused and refused_reason == GearboxState.REJECT_CLUTCH and gear_after_refusal == 1,
		"reason '%s', gear %d" % [refused_reason, gear_after_refusal])
	_check("G. the same manual shift is accepted with the clutch pressed",
		accepted and clutch_box.gear == 2, "gear %d" % clutch_box.gear)

	var clutch := ClutchState.new()
	clutch.capacity = 420.0
	clutch.stiffness = 2.6
	clutch.manual_mode = true
	var fully_pressed: float = clutch.engagement_target(1.0)
	var fully_released: float = clutch.engagement_target(0.0)
	var bite: float = clutch.engagement_target(0.5)
	_check("G. clutch pedal fully pressed = open", fully_pressed < 0.01,
		"engagement %s" % _f(fully_pressed, 3))
	_check("G. clutch pedal released = closed", fully_released > 0.99,
		"engagement %s" % _f(fully_released, 3))
	_check("G. clutch bite point is partial engagement", bite > 0.2 and bite < 0.8,
		"engagement %s at half pedal" % _f(bite, 3))
	clutch.engagement = bite
	clutch.slip_rpm = 60.0
	var transmitted: float = clutch.compute_torque()
	_check("G. clutch at the bite point transmits partial torque",
		transmitted > 1.0 and transmitted < clutch.capacity * 0.99,
		"%s Nm of %s Nm capacity" % [_f(transmitted, 1), _f(clutch.capacity, 0)])

# ---------------------------------------------------- H. save migration ---

func _test_h_save_migration() -> void:
	_section("H. Save migration (v4 -> v5, in memory only)")
	var legacy: Dictionary = {
		"version": 4,
		"credits": 1234,
		"xp": 500,
		"selected_vehicle": "ranger_4x4",
		"owned_vehicles": ["rocky_buggy", "ranger_4x4"],
		"records": {
			"canyon_01": {"best_time": 123.4, "medal": 2, "attempts": 3, "completed": true},
			"canyon_02": {"best_time": 98.7, "medal": 1, "attempts": 1, "completed": true},
		},
		"upgrades": {
			"ranger_4x4": ["engine_1", "gearbox_1", "tires_1", "legacy_unknown_upgrade"],
		},
		"config": {"ranger_4x4": {"transfer": "4L", "diff": "lsd"}},
	}
	var migrated: Dictionary = SaveManager._migrate(legacy, 4)
	_check("H. credits preserved", int(migrated.get("credits", -1)) == 1234,
		"%d" % int(migrated.get("credits", -1)))
	_check("H. schema raised to v5 and origin recorded",
		int(migrated.get("version", -1)) == SaveManager.VERSION
		and int(migrated.get("migrated_from", -1)) == 4,
		"version %d, migrated_from %d" % [
			int(migrated.get("version", -1)), int(migrated.get("migrated_from", -1)),
		])

	var owned: Array = migrated.get("owned_vehicles", []) as Array
	var owned_detail: String = ""
	for raw: Variant in owned:
		owned_detail += String(raw) + " "
	_check("H. owned vehicles mapped to the 3.0 roster",
		owned.size() == 2 and owned.has("jimny_jb74") and owned.has("hilux_an120"),
		owned_detail.strip_edges())
	_check("H. selected vehicle mapped", String(migrated.get("selected_vehicle", "")) == "hilux_an120",
		String(migrated.get("selected_vehicle", "")))

	var records: Dictionary = migrated.get("records", {}) as Dictionary
	var canyon_a: Dictionary = records.get("zagros_01", {}) as Dictionary
	var canyon_b: Dictionary = records.get("zagros_02", {}) as Dictionary
	_check("H. canyon_01 record mapped to zagros_01 with its best time",
		absf(float(canyon_a.get("best_time", -1.0)) - 123.4) < 0.001
		and bool(canyon_a.get("completed", false)) and int(canyon_a.get("medal", 0)) == 2,
		"best %s s, medal %d" % [
			_f(float(canyon_a.get("best_time", -1.0)), 1), int(canyon_a.get("medal", 0)),
		])
	_check("H. canyon_02 record mapped to zagros_02 with its best time",
		absf(float(canyon_b.get("best_time", -1.0)) - 98.7) < 0.001
		and int(canyon_b.get("attempts", 0)) == 1,
		"best %s s, attempts %d" % [
			_f(float(canyon_b.get("best_time", -1.0)), 1), int(canyon_b.get("attempts", 0)),
		])
	_check("H. legacy 'upgrades' block consumed",
		not migrated.has("upgrades") and not migrated.has("config"),
		"keys left: %s" % str(migrated.keys()))

	var garage: Dictionary = migrated.get("garage", {}) as Dictionary
	var hilux_entry: Dictionary = garage.get("hilux_an120", {}) as Dictionary
	var owned_parts: Array = hilux_entry.get("owned", []) as Array
	var part_set: Array[String] = []
	for raw: Variant in owned_parts:
		part_set.append(String(raw))
	var parts_map: Dictionary = hilux_entry.get("parts", {}) as Dictionary
	var expected_parts: Array[String] = [
		"hilux_an120_intake_sport", "hilux_an120_clutch_hd", "hilux_an120_tyre_at",
	]
	var all_present: bool = true
	for wanted: String in expected_parts:
		if not part_set.has(wanted):
			all_present = false
	_check("H. garage entry keeps every migrated purchase", all_present,
		"%d owned: %s" % [part_set.size(), _join(part_set)])
	_check("H. migrated purchases are also fitted in the garage entry",
		parts_map.has(str(int(PartDef.Slot.INTAKE)))
		and parts_map.has(str(int(PartDef.Slot.CLUTCH)))
		and parts_map.has(str(int(PartDef.Slot.TYRES)))
		and garage.has("jimny_jb74"),
		"parts keys %s, garage %s" % [str(parts_map.keys()), str(garage.keys())])

# -------------------------------------------------- I. data contracts ---

func _test_i_data_contracts() -> void:
	_section("I. Mobile/UI data contracts")
	for track: TrackDef in Content.tracks:
		var tag: String = "I[%s]" % track.id
		var supported: Array[String] = []
		for mode: String in TRACK_MODES:
			if track.supports_mode(mode):
				supported.append(mode)
		_check("%s supports at least one mode" % tag, not supported.is_empty(),
			"%d modes, %s" % [supported.size(), _join(supported)])

		var ordered: bool = track.medal_gold > 0.0 \
			and track.medal_gold < track.medal_silver \
			and track.medal_silver < track.medal_bronze
		_check("%s medal times ordered gold < silver < bronze" % tag, ordered,
			"%s < %s < %s s" % [
				_f(track.medal_gold, 1), _f(track.medal_silver, 1), _f(track.medal_bronze, 1),
			])

	for vehicle: VehicleDef in Content.vehicles:
		var tag: String = "I[%s]" % vehicle.id
		_check("%s tyre radius positive" % tag,
			vehicle.tire_front.radius_m > 0.0 and vehicle.tire_rear.radius_m > 0.0,
			"%s / %s m" % [
				_f(vehicle.tire_front.radius_m, 4), _f(vehicle.tire_rear.radius_m, 4),
			])
		var finals: Array[String] = []
		var bad: Array[String] = []
		for transmission: TransmissionProfile in vehicle.transmission_options():
			finals.append("%s=%.3f" % [transmission.id, transmission.final_drive])
			if transmission.final_drive < 2.5 or transmission.final_drive > 5.5:
				bad.append("%s %.3f" % [transmission.id, transmission.final_drive])
		_check("%s final drives within 2.5..5.5" % tag, bad.is_empty(),
			_join(finals))


# ------------------------------------------------------------- J. MUDRO radio ---

## Builds a throwaway pack in user:// and checks the load gates of
## docs/RADIO_CONTENT_POLICY.md §6.4. A pack is a unit of provenance: one bad
## track rejects the whole folder, and the message must name the gate.
func _test_j_radio() -> void:
	_section("J. Radio content packs (policy gates)")
	var model := RadioModel.new()
	model.scan()
	_check("J. built-in station ships audio", model.playable_count() >= 4,
		"%d built-in tracks" % model.playable_count())
	var builtin: Dictionary = model.select(1)
	_check("J. built-in track is bucket A with an own-work licence",
		String(builtin.get("bucket", "")) == "A" and String(builtin.get("license_id", "")) == "OWN-WORK",
		"%s / %s" % [builtin.get("bucket", ""), builtin.get("license_id", "")])
	var path: String = String(builtin.get("path", ""))
	_check("J. built-in track file exists", ResourceLoader.exists(path), path)

	var root: String = "user://_test_radio"
	_clean_dir(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))

	# --- happy path -------------------------------------------------------
	var pack_dir: String = root.path_join("demo_pack")
	_write_pack(pack_dir, "demo_pack", {
		"file": "tracks/a.wav",
		"source_bucket": "C",
		"license_id": "CC-BY-4.0",
		"evidence_path": "evidence/deed.txt",
		"attribution_text": "\"A\" by Someone — CC BY 4.0 — edited",
	})
	var good: RadioPack = RadioPack.load_pack(pack_dir)
	_check("J. a complete pack loads", good.ok(), good.reject_reason)
	_check("J. a loaded pack exposes its tracks", good.track_count() == 1,
		"%d tracks" % good.track_count())

	# --- one failing track rejects the pack -------------------------------
	var bad_dir: String = root.path_join("bad_provenance")
	_write_pack(bad_dir, "bad_provenance", {
		"file": "tracks/a.wav",
		"source_bucket": "C",
		"license_id": "",
		"evidence_path": "evidence/deed.txt",
		"attribution_text": "x",
	})
	var bad: RadioPack = RadioPack.load_pack(bad_dir)
	_check("J. a track without a licence rejects the pack", not bad.ok() and bad.reject_gate == 5,
		"gate %d: %s" % [bad.reject_gate, bad.reject_reason])

	# --- escaping the pack root ------------------------------------------
	var esc_dir: String = root.path_join("escaping")
	_write_pack(esc_dir, "escaping", {
		"file": "../outside.wav",
		"source_bucket": "A",
		"license_id": "OWN-WORK",
		"evidence_path": "evidence/deed.txt",
		"attribution_text": "",
	}, false)
	var esc: RadioPack = RadioPack.load_pack(esc_dir)
	_check("J. a path that escapes the pack is refused", not esc.ok() and esc.reject_gate == 6,
		"gate %d: %s" % [esc.reject_gate, esc.reject_reason])

	# --- identity ---------------------------------------------------------
	var id_dir: String = root.path_join("right_folder")
	_write_pack(id_dir, "wrong_id", {
		"file": "tracks/a.wav",
		"source_bucket": "A",
		"license_id": "OWN-WORK",
		"evidence_path": "evidence/deed.txt",
		"attribution_text": "",
	})
	var ident: RadioPack = RadioPack.load_pack(id_dir)
	_check("J. pack_id must match the folder name", not ident.ok() and ident.reject_gate == 3,
		"gate %d: %s" % [ident.reject_gate, ident.reject_reason])

	# --- attribution completeness for licensed material -------------------
	var attr_dir: String = root.path_join("no_credit")
	_write_pack(attr_dir, "no_credit", {
		"file": "tracks/a.wav",
		"source_bucket": "C",
		"license_id": "CC-BY-4.0",
		"evidence_path": "evidence/deed.txt",
		"attribution_text": "",
	})
	var attr: RadioPack = RadioPack.load_pack(attr_dir)
	_check("J. CC BY content without attribution is refused", not attr.ok() and attr.reject_gate == 7,
		"gate %d: %s" % [attr.reject_gate, attr.reject_reason])

	# --- a pack never reaches into res:// ---------------------------------
	_check("J. packs are only read from user://", RadioModel.PACK_ROOT == "user://radio_packs",
		RadioModel.PACK_ROOT)
	_clean_dir(root)

func _write_pack(dir_path: String, pack_id: String, track: Dictionary,
		create_file: bool = true) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path.path_join("tracks")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path.path_join("evidence")))
	var evidence: String = dir_path.path_join("evidence/deed.txt")
	if not FileAccess.file_exists(evidence):
		var f: FileAccess = FileAccess.open(evidence, FileAccess.WRITE)
		if f != null:
			f.store_string("test evidence\n")
			f.close()
	if create_file:
		var audio: FileAccess = FileAccess.open(dir_path.path_join("tracks/a.wav"), FileAccess.WRITE)
		if audio != null:
			audio.store_buffer(PackedByteArray())
			audio.close()
	var manifest: Dictionary = {
		"schema_version": 1,
		"pack_id": pack_id,
		"display_name": "Test Pack",
		"author": "test",
		"license_file": "LICENSE.txt",
		"tracks": [{
			"id": "a",
			"file": String(track["file"]),
			"title": "A",
			"artist": "Someone",
			"rights_holder": "Someone",
			"source_bucket": String(track["source_bucket"]),
			"license_id": String(track["license_id"]),
			"license_url": "https://creativecommons.org/licenses/by/4.0/",
			"evidence_path": String(track["evidence_path"]),
			"attribution_text": String(track["attribution_text"]),
			"edited": true,
			"duration_s": 1.0,
			"sha256": "",
			"loop": false,
		}],
	}
	var mf: FileAccess = FileAccess.open(dir_path.path_join("manifest.json"), FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify(manifest, "\t"))
		mf.close()

func _clean_dir(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var child: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_clean_dir(child)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = dir.get_next()
	dir.list_dir_end()


# ----------------------------------------------------------------- K. weather ---

## Every track must name a weather profile the game actually has. A typo used to
## resolve silently to "clear", which meant three tracks advertised wind or a storm
## and drove in perfect calm.
func _test_k_weather() -> void:
	_section("K. Weather profiles")
	var known: Array = WeatherSystem.PROFILES.keys()
	var bad: Array[String] = []
	var seen: Dictionary = {}
	for track: TrackDef in Content.tracks:
		seen[track.weather] = true
		if not known.has(track.weather):
			bad.append("%s:%s" % [track.id, track.weather])
	_check("K. every track names a real weather profile", bad.is_empty(),
		"%d unknown %s" % [bad.size(), _join(bad)])
	_check("K. the region set actually ships more than clear weather", seen.size() >= 4,
		"%d distinct profiles used" % seen.size())

	var wind: Dictionary = WeatherSystem.PROFILES["wind"] as Dictionary
	_check("K. wind profile has a physical strength", float(wind.get("wind", 0.0)) > 0.0,
		"wind=%.2f grip=%.2f" % [float(wind.get("wind", 0.0)), float(wind.get("grip", 1.0))])

	# A steady gust on a stationary car must still be a force, and a taller car must
	# be pushed harder than a smaller one on the same track.
	var body: VehicleBody = VehicleBody.new()
	var tall: VehicleDef = Content.vehicle_by_id("lc79")
	var small: VehicleDef = Content.vehicle_by_id("jimny_jb74")
	body.setup(GarageModel.build(tall, GarageModel.empty_config()), Content.surfaces)
	body.apply_wind(1.0)
	var tall_force: float = absf(body.wind_force_n(1.0))
	body.setup(GarageModel.build(small, GarageModel.empty_config()), Content.surfaces)
	body.apply_wind(1.0)
	var small_force: float = absf(body.wind_force_n(1.0))
	_check("K. wind pushes a stationary car", tall_force > 0.0, "%.0f N" % tall_force)
	_check("K. a taller car catches more wind", tall_force > small_force,
		"lc79 %.0f N vs jimny %.0f N" % [tall_force, small_force])
	body.free()

# ------------------------------------------- L. 3.1 driver experience ---
## Everything in this section is behavioural. No assertion asks "does the node
## exist": the control layer is driven with synthetic finger indices, the gearbox
## is asked to reject a shift, and the stall tests let a real RigidBody2D rest on a
## real floor for a real second of physics.

func _test_l_driver31() -> void:
	_test_l0_compile()
	await _test_l1_default_layout()
	await _test_l2_multitouch()
	_test_l3_clutch_interlock()
	_test_l4_clutch_data()
	await _test_l5_stall()
	await _test_l6_modes_and_interlocks()

# --- L0: nothing ships broken ------------------------------------------------

func _collect_scripts(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_scripts(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

## A script that does not compile is not a missing feature, it is a broken build.
## The 3.0 suite proved the terrain builder compiled but never checked the rest of
## the project, which is how a syntax error in the lever panel shipped.
func _test_l0_compile() -> void:
	_section("L0. Every gameplay script compiles")
	var paths: Array[String] = []
	_collect_scripts("res://scripts", paths)
	_check("L0. the script tree was found", paths.size() > 40, "%d scripts" % paths.size())
	var broken: Array[String] = []
	for path: String in paths:
		var script: Script = load(path) as Script
		if script == null or not script.can_instantiate():
			broken.append(path.replace("res://scripts/", ""))
	_check("L0. every script under scripts/ compiles", broken.is_empty(),
		"%d broken: %s" % [broken.size(), _join(broken)])

# --- L1: the mandated arrangement ---------------------------------------------

func _test_l1_default_layout() -> void:
	_section("L1. Default control layout (clutch left, throttle + brake right)")
	_check("L1. the shipped default preset is the driver layout",
		SettingsService.DEFAULT_PRESET == "drive",
		"default '%s'" % SettingsService.DEFAULT_PRESET)
	_check("L1. the saved default preset is the driver layout",
		String(SettingsService._defaults().get("control_preset", "")) == "drive",
		"%s" % String(SettingsService._defaults().get("control_preset", "")))

	var previous_preset: String = SettingsService.control_preset
	SettingsService.control_preset = "drive"
	var def: VehicleDef = Content.vehicle_by_id("hilux_an120")
	var profile: TransmissionProfile = def.transmission_by_id("hilux_m6")
	var controls := TouchControls.new()
	controls.name = "L1Controls"
	add_child(controls)
	controls.setup(profile, null)
	await get_tree().process_frame

	var view: Vector2 = controls._view()
	_check("L1. a clutch control exists in a manual car",
		controls.widgets.has("clutch"), "widgets %d" % controls.widgets.size())
	var clutch: TouchWidget = controls.widgets.get("clutch", null) as TouchWidget
	var throttle: TouchWidget = controls.widgets.get("throttle", null) as TouchWidget
	var brake: TouchWidget = controls.widgets.get("brake", null) as TouchWidget
	_check("L1. throttle and brake both exist", throttle != null and brake != null, "")

	if clutch != null and throttle != null and brake != null:
		var clutch_cx: float = clutch.position.x + clutch.size.x * 0.5
		var throttle_cx: float = throttle.position.x + throttle.size.x * 0.5
		var brake_cx: float = brake.position.x + brake.size.x * 0.5
		var third: float = view.x / 3.0
		_check("L1. the clutch sits on the left third",
			clutch_cx < third, "clutch x=%s of %s" % [_f(clutch_cx, 0), _f(view.x, 0)])
		_check("L1. the throttle sits on the right third",
			throttle_cx > view.x - third, "throttle x=%s" % _f(throttle_cx, 0))
		_check("L1. the brake sits on the right third",
			brake_cx > view.x - third, "brake x=%s" % _f(brake_cx, 0))
		_check("L1. the throttle is the larger pedal",
			throttle.size.x * throttle.size.y > brake.size.x * brake.size.y * 1.25,
			"throttle %sx%s vs brake %sx%s" % [
				_f(throttle.size.x, 0), _f(throttle.size.y, 0),
				_f(brake.size.x, 0), _f(brake.size.y, 0)])

		# "LEFT: CLUTCH" means the left third holds the clutch and no driving control.
		var intruders: Array[String] = []
		for id: String in controls.widgets.keys():
			if id == "clutch" or id == "recover" or id == "winch" or id == "start":
				continue
			var w: TouchWidget = controls.widgets[id] as TouchWidget
			var cx: float = w.position.x + w.size.x * 0.5
			if cx < third:
				intruders.append(id)
		_check("L1. no driving control is on the clutch side",
			intruders.is_empty(), _join(intruders))

		var as_slider: TouchSlider = clutch as TouchSlider
		_check("L1. the clutch is an analog slider",
			as_slider != null, "type %s" % clutch.get_class())
		if as_slider != null:
			_check("L1. the clutch rail is tall and slim",
				as_slider.size.y > as_slider.size.x * 2.5,
				"%s x %s" % [_f(as_slider.size.x, 0), _f(as_slider.size.y, 0)])
			_check("L1. the clutch travels downward to the floor",
				as_slider.value_at_bottom, "value_at_bottom=%s" % str(as_slider.value_at_bottom))
			_check("L1. the clutch paints a real bite window",
				as_slider.bite_band.y > as_slider.bite_band.x and as_slider.bite_band.y <= 1.0,
				"bite %.2f..%.2f" % [as_slider.bite_band.x, as_slider.bite_band.y])
			# A pedal that jumps to a random rail position on touch cannot be
			# modulated: it either dumps the clutch or stalls the engine.
			_check("L1. the clutch is not an absolute-position slider",
				as_slider.mode == TouchSlider.Mode.PEDAL, "mode %d" % int(as_slider.mode))

	# An automatic car has no clutch pedal to show.
	var auto_profile: TransmissionProfile = def.transmission_by_id("hilux_a6")
	var auto_controls := TouchControls.new()
	add_child(auto_controls)
	auto_controls.setup(auto_profile, null)
	await get_tree().process_frame
	_check("L1. an automatic car shows no clutch pedal",
		not auto_controls.widgets.has("clutch"),
		"%d widgets" % auto_controls.widgets.size())
	auto_controls.queue_free()
	controls.queue_free()
	SettingsService.control_preset = previous_preset
	await get_tree().process_frame

# --- L2: real multi-touch -----------------------------------------------------

func _test_l2_multitouch() -> void:
	_section("L2. Three independent fingers: clutch + lever + throttle")
	var previous_preset: String = SettingsService.control_preset
	SettingsService.control_preset = "drive"
	var def: VehicleDef = Content.vehicle_by_id("jimny_jb74")
	var profile: TransmissionProfile = def.transmission_by_id("jimny_m5")
	var controls := TouchControls.new()
	add_child(controls)
	controls.setup(profile, null)
	var log_ref: Dictionary = {"gears": []}
	controls.gear_requested.connect(func(g: int) -> void: (log_ref["gears"] as Array).append(g))
	await get_tree().process_frame

	var clutch: TouchWidget = controls.widgets.get("clutch", null) as TouchWidget
	var throttle: TouchWidget = controls.widgets.get("throttle", null) as TouchWidget
	var gear_button: TouchWidget = controls.widgets.get("gear", null) as TouchWidget
	_check("L2. the layer built a clutch, a throttle and a lever button",
		clutch != null and throttle != null and gear_button != null, "")
	if clutch == null or throttle == null or gear_button == null:
		controls.queue_free()
		SettingsService.control_preset = previous_preset
		return

	# Finger 0: press the clutch rail. A clutch rail must press to the floor.
	var clutch_centre: Vector2 = clutch.position + clutch.size * 0.5
	controls._begin(0, clutch_centre)
	_check("L2. touching the clutch presses it to the floor",
		is_equal_approx(clutch.value, 1.0), "value %s" % _f(clutch.value, 2))

	# Finger 1: open the lever panel with the clutch still held.
	controls._begin(1, gear_button.position + gear_button.size * 0.5)
	controls._end(1)
	# The panel slides in over ~0.2 s; read its final position, not its start.
	await get_tree().create_timer(0.30).timeout
	_check("L2. the lever panel opens over a held clutch",
		controls.panel_open and controls.panel != null and controls.panel.visible,
		"open=%s panel=%s visible=%s" % [str(controls.panel_open), str(controls.panel != null),
			str(controls.panel.visible if controls.panel != null else false)])
	_check("L2. the clutch keeps its value when the panel opens",
		is_equal_approx(clutch.value, 1.0), "value %s" % _f(clutch.value, 2))

	var panel: GearPanel = controls.panel
	_check("L2. the panel knows the clutch is down",
		panel._clutch_ready(), "pedal %.2f assist %s" % [panel.clutch_pedal, str(panel.auto_clutch)])
	# Finger 1 again: drag the lever into first gear.
	var node_px: Vector2 = panel._to_px(profile.gate_node(1))
	controls._begin(1, panel.position + node_px)
	await get_tree().process_frame
	_check("L2. the lever engages a gear with the clutch down",
		(log_ref["gears"] as Array).has(1), "requested %s" % str(log_ref["gears"]))
	_check("L2. the clutch is untouched by the lever finger",
		is_equal_approx(clutch.value, 1.0), "value %s" % _f(clutch.value, 2))
	controls._end(1)

	# Finger 2: throttle, while the clutch is still held.
	controls._begin(2, throttle.position + Vector2(throttle.size.x * 0.5, throttle.size.y * 0.12))
	var state: VehicleInputState = controls.input_state()
	_check("L2. clutch and throttle are held at the same time",
		state.clutch > 0.95 and state.throttle > 0.5,
		"clutch %.2f throttle %.2f" % [state.clutch, state.throttle])

	# Lifting the throttle finger must not lift the clutch finger.
	controls._end(2)
	_check("L2. releasing the throttle leaves the clutch pressed",
		is_equal_approx(clutch.value, 1.0) and not throttle.active,
		"clutch %.2f throttle active=%s" % [clutch.value, str(throttle.active)])
	for i: int in range(20):
		throttle._process(0.08)
	_check("L2. the released throttle returns to zero", throttle.value < 0.05,
		"throttle %.2f after 1.6 s" % throttle.value)

	# Lifting the clutch finger lets the pedal out: value must fall, not snap.
	controls._end(0)
	clutch._process(0.05)
	var after: float = clutch.value
	_check("L2. releasing the clutch pedal releases it progressively",
		after > 0.0 and after < 1.0, "value %s after 50 ms" % _f(after, 2))

	# A cancelled touch or a pause must not leave a pedal stuck down.
	controls._begin(3, clutch_centre)
	controls.release_all()
	_check("L2. pause / focus loss clears every finger",
		controls._fingers.is_empty(), "fingers %d" % controls._fingers.size())

	# A second finger landing on a control another finger already owns must not steal
	# it: lifting either finger would otherwise drop the pedal under the other one.
	var throttle_point: Vector2 = throttle.position + throttle.size * 0.5
	controls._begin(4, throttle_point)
	var owner_before: int = throttle.finger_id
	var stolen: bool = controls._begin(5, throttle_point)
	_check("L2. a second finger cannot steal a held control",
		not stolen and throttle.finger_id == owner_before,
		"owner %d -> %d, second begin %s" % [owner_before, throttle.finger_id, str(stolen)])
	controls._end(4)
	controls.release_all()
	controls.queue_free()
	SettingsService.control_preset = previous_preset
	await get_tree().process_frame

# --- L3: the manual shift interlock ------------------------------------------

func _test_l3_clutch_interlock() -> void:
	_section("L3. Manual shifts require the clutch")
	var def: VehicleDef = GarageModel.build(Content.vehicle_by_id("hilux_an120"), GarageModel.empty_config())
	var body := VehicleBody.new()
	body.setup(def, Content.surfaces)
	body.configure_driver(false)
	_check("L3. realistic manual exposes a manual clutch",
		body.manual_clutch_enabled and not body.auto_clutch,
		"manual %s assist %s" % [str(body.manual_clutch_enabled), str(body.auto_clutch)])
	body.set_gear(1)
	body.gearbox.update(1.0)

	# Pedal out (clutch engaged): the box must refuse to move.
	body.set_inputs(0.0, 0.0, 0.0, 1.0)
	var refused: bool = not body.select_gear(2)
	_check("L3. a shift with the pedal out is refused",
		refused and body.gearbox.gear == 1 and body.gearbox.reject_reason == GearboxState.REJECT_CLUTCH,
		"reason '%s' gear %d" % [body.gearbox.reject_reason, body.gearbox.gear])

	# Pedal to the floor: the same shift is accepted.
	body.set_inputs(0.0, 0.0, 0.0, 0.0)
	_check("L3. the pedal reads as fully pressed at the floor",
		body.clutch_pedal() >= ClutchState.FULLY_PRESSED,
		"pedal command %s" % _f(body.clutch_pedal(), 3))
	var accepted: bool = body.select_gear(2)
	_check("L3. the same shift is accepted with the clutch down",
		accepted and body.gearbox.gear == 2, "gear %d" % body.gearbox.gear)

	# 0.97 of pedal travel must NOT be enough: the published rule is 0.98.
	body.gearbox.update(1.0)
	body.set_inputs(0.0, 0.0, 0.0, 0.03)
	var nearly: bool = not body.select_gear(3)
	_check("L3. 97 % pedal is not enough to shift", nearly,
		"pedal %s, reason '%s'" % [_f(body.clutch_pedal(), 3), body.gearbox.reject_reason])

	# Gear choice has to change wheel torque, not just the HUD number.
	body.gearbox.update(1.0)
	body.set_inputs(0.0, 0.0, 0.0, 0.0)
	body.select_gear(1)
	body.gearbox.update(1.0)
	var first_torque: float = absf(body.gearbox.wheel_torque(200.0))
	body.select_gear(4)
	body.gearbox.update(1.0)
	var fourth_torque: float = absf(body.gearbox.wheel_torque(200.0))
	_check("L3. first gear multiplies torque harder than fourth",
		first_torque > fourth_torque * 1.5,
		"1st %.0f Nm vs 4th %.0f Nm at the wheel" % [first_torque, fourth_torque])

	# From neutral the driveline spins the internal pedal to "pressed" on its own.
	# The interlock must read the player's command, not that derived state.
	var neutral := VehicleBody.new()
	neutral.setup(def, Content.surfaces)
	neutral.configure_driver(false)
	neutral.gearbox.reset(0)
	neutral.clutch.engagement = 0.0
	neutral.clutch.pedal = 1.0 - neutral.clutch.engagement
	neutral.set_inputs(0.0, 0.0, 0.0, 1.0)
	_check("L3. the neutral clutch state looks pressed even with the pedal out",
		neutral.clutch.is_fully_pressed(), "pedal %.2f" % neutral.clutch.pedal)
	var neutral_shift: bool = not neutral.select_gear(1)
	_check("L3. neutral does not hand out a free shift",
		neutral_shift and neutral.gearbox.gear == 0,
		"gear %d, reason '%s'" % [neutral.gearbox.gear, neutral.gearbox.reject_reason])
	neutral.set_inputs(0.0, 0.0, 0.0, 0.0)
	_check("L3. the same shift works with the pedal down", neutral.select_gear(1),
		"gear %d" % neutral.gearbox.gear)
	neutral.free()

	# Assisted manual lets the box accept the shift without the pedal, by design.
	var assisted := VehicleBody.new()
	assisted.setup(def, Content.surfaces)
	assisted.configure_driver(true)
	assisted.set_gear(1)
	assisted.gearbox.update(1.0)
	assisted.set_inputs(0.0, 0.0, 0.0, 1.0)
	var assisted_shift: bool = assisted.select_gear(2)
	_check("L3. assisted manual shifts without the pedal",
		assisted_shift, "gear %d" % assisted.gearbox.gear)

	# Reverse is still protected at speed even with the clutch down.
	assisted.gearbox.update(1.0)
	var reverse_ok: bool = assisted.gearbox.can_engage(-1, 0.0, true) == GearboxState.REJECT_NONE
	var reverse_fast: String = assisted.gearbox.can_engage(-1, 8.0, true)
	_check("L3. reverse needs a standstill",
		reverse_ok and reverse_fast == GearboxState.REJECT_REVERSE, "at 8 m/s: '%s'" % reverse_fast)

	# A 5-speed H gate must be the real 3-column pattern, with R beside 5.
	var jimny: VehicleDef = Content.vehicle_by_id("jimny_jb74")
	var five: TransmissionProfile = jimny.transmission_by_id("jimny_m5")
	var columns: int = five.gate_column_count()
	var fifth: Vector2 = five.gate_node(5)
	var reverse: Vector2 = five.gate_node(-1)
	_check("L3. a 5-speed gate has three columns", columns == 3, "%d columns" % columns)
	_check("L3. 5th and reverse share the last column",
		is_equal_approx(fifth.x, reverse.x) and fifth.y < 0.5 and reverse.y > 0.5,
		"5th %s, R %s" % [str(fifth), str(reverse)])
	var straight: Dictionary = five.gate_project(Vector2(fifth.x, 0.30))
	_check("L3. the lever reaches 5th along its own gate",
		int(straight.get("gear", -1)) == 5, "gear %d" % int(straight.get("gear", -1)))
	var diagonal: Dictionary = five.gate_project(Vector2(0.5, 0.5))
	_check("L3. the centre of the plate is neutral",
		int(diagonal.get("gear", -1)) == 0, "gear %d" % int(diagonal.get("gear", -1)))
	var illegal: Dictionary = five.gate_project(Vector2(five.gate_x(0) + 0.02, 0.5))
	_check("L3. a position on the neutral rail engages no gear",
		int(illegal.get("gear", -1)) == 0, "gear %d" % int(illegal.get("gear", -1)))

	var six: TransmissionProfile = Content.vehicle_by_id("hilux_an120").transmission_by_id("hilux_m6")
	_check("L3. a 6-speed gate needs its own reverse column",
		six.gate_column_count() == 4, "%d columns" % six.gate_column_count())

	body.free()
	assisted.free()

# --- L4: per-vehicle clutch data ---------------------------------------------

func _test_l4_clutch_data() -> void:
	_section("L4. Each vehicle's clutch behaves differently")
	var bites: Array[float] = []
	var capacities: Array[float] = []
	for id: String in DOC_VEHICLE_IDS:
		var def: VehicleDef = GarageModel.build(Content.vehicle_by_id(id), GarageModel.empty_config())
		var body := VehicleBody.new()
		body.setup(def, Content.surfaces)
		bites.append(body.clutch.bite_point)
		capacities.append(body.clutch_capacity_base)
		body.free()

	var distinct_caps: bool = true
	for i: int in range(capacities.size()):
		for j: int in range(i):
			if absf(capacities[i] - capacities[j]) < 1.0:
				distinct_caps = false
	_check("L4. every vehicle has a clutch capacity", capacities.size() == 5, "%d" % capacities.size())
	_check("L4. clutch capacities differ between vehicles", distinct_caps, "%s" % str(capacities))
	_check("L4. stock bite points are in a drivable window",
		bites.size() == 5 and bites.min() > 0.30 and bites.max() < 0.85, "%s" % str(bites))

	# Fitting a twin-plate moves the bite point and raises the rating.
	var stock: VehicleDef = GarageModel.build(Content.vehicle_by_id("hilux_an120"), GarageModel.empty_config())
	var stock_body := VehicleBody.new()
	stock_body.setup(stock, Content.surfaces)
	var stock_cap: float = stock_body.clutch_capacity_base
	var stock_bite: float = stock_body.clutch.bite_point
	stock_body.free()

	var twin: VehicleDef = GarageModel.build(Content.vehicle_by_id("hilux_an120"),
		_fit({PartDef.Slot.CLUTCH: "hilux_an120_clutch_twin"}))
	var twin_body := VehicleBody.new()
	twin_body.setup(twin, Content.surfaces)
	_check("L4. a twin-plate clutch raises the torque rating",
		twin_body.clutch_capacity_base > stock_cap * 1.3,
		"%s vs %s Nm" % [_f(twin_body.clutch_capacity_base, 0), _f(stock_cap, 0)])
	_check("L4. a twin-plate clutch bites lower",
		twin_body.clutch.bite_point < stock_bite,
		"%.2f vs %.2f" % [twin_body.clutch.bite_point, stock_bite])

	# A damaged clutch cannot hold the same torque: condition is read, not printed.
	var worn: VehicleDef = GarageModel.build(Content.vehicle_by_id("hilux_an120"), GarageModel.empty_config())
	var conditions: Dictionary = {}
	for slot: Variant in worn.parts.keys():
		var part: PartDef = worn.parts[slot] as PartDef
		if part != null and part.slot == PartDef.Slot.CLUTCH:
			conditions[part.id] = PartDef.Condition.DAMAGED
	worn.part_conditions = conditions
	var worn_body := VehicleBody.new()
	worn_body.setup(worn, Content.surfaces)
	_check("L4. a damaged clutch holds less torque",
		worn_body.clutch_capacity_base < stock_cap * 0.85,
		"%s vs %s Nm" % [_f(worn_body.clutch_capacity_base, 0), _f(stock_cap, 0)])
	worn_body.free()

	# Thermal fade: a hot clutch is weaker, but never useless.
	twin_body.clutch_heat = 0.0
	var cold: float = twin_body.clutch_fade()
	twin_body.clutch_heat = 1.0
	var hot: float = twin_body.clutch_fade()
	_check("L4. a cold clutch does not fade", is_equal_approx(cold, 1.0), "%.2f" % cold)
	_check("L4. a hot clutch loses capacity but still bites",
		hot > 0.6 and hot < cold, "%.2f vs %.2f" % [hot, cold])
	twin_body.free()

# --- L5: the stall, on real physics ------------------------------------------

## An infinite floor the vehicle can actually rest on.
func _flat_floor() -> StaticBody2D:
	var floor_body := StaticBody2D.new()
	floor_body.name = "L5Floor"
	floor_body.collision_layer = 2
	floor_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var plane := WorldBoundaryShape2D.new()
	plane.normal = Vector2(0, -1)
	plane.distance = 0.0
	shape.shape = plane
	floor_body.add_child(shape)
	add_child(floor_body)
	return floor_body

func _spawn_on_floor(def: VehicleDef, gear: int) -> VehicleBody:
	var body := VehicleBody.new()
	body.name = "L5Vehicle"
	add_child(body)
	body.setup(def, Content.surfaces)
	body.configure_driver(false)
	body.global_transform = Transform2D(0.0, Vector2(0.0, -0.9 * Units.PPM))
	body.set_gear(gear)
	body.set_input_state(_clutch_state(1.0, 0.0))
	return body

## `pedal` 1.0 = clutch on the floor, 0.0 = released.
func _clutch_state(pedal: float, throttle: float) -> VehicleInputState:
	var s := VehicleInputState.new()
	s.clutch = pedal
	s.throttle = throttle
	return s

## Advance the real physics loop for `seconds`, calling `tick` with the elapsed time.
func _run_physics(seconds: float, tick: Callable) -> void:
	var elapsed: float = 0.0
	var wall_start: int = Time.get_ticks_msec()
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)
		tick.call(elapsed)
		if Time.get_ticks_msec() - wall_start > 25000:
			return

func _test_l5_stall() -> void:
	_section("L5. Stalls come from the driveline (real RigidBody2D on a floor)")
	var def: VehicleDef = GarageModel.build(Content.vehicle_by_id("hilux_an120"), GarageModel.empty_config())
	_flat_floor()

	# --- Scenario 2: dump the clutch at idle in first gear.
	var held := _clutch_state(1.0, 0.0)
	var dumped: VehicleBody = _spawn_on_floor(def, 1)
	await _run_physics(0.5, func(_t: float) -> void: dumped.set_input_state(held))
	var idle_rpm: float = dumped.engine.rpm
	_check("L5. the engine idles with the clutch held", idle_rpm > 500.0 and dumped.engine.running,
		"%.0f rpm" % idle_rpm)

	var dump_result: Dictionary = {"stalled": false, "at": 0.0, "drive": 0.0}
	var released := _clutch_state(0.0, 0.0)
	await _run_physics(1.2, func(t: float) -> void:
		dumped.set_input_state(released)
		if not dumped.engine.running:
			if not bool(dump_result["stalled"]):
				dump_result["stalled"] = true
				dump_result["at"] = t)
	_check("L5. dumping the clutch at idle stalls the engine", bool(dump_result["stalled"]),
		"running=%s rpm=%.0f" % [str(dumped.engine.running), dumped.engine.rpm])
	_check("L5. the stall is immediate, not a slow death",
		bool(dump_result["stalled"]) and float(dump_result["at"]) < 0.7,
		"stalled after %s s" % _f(float(dump_result["at"]), 2))
	_check("L5. a stalled engine has no torque",
		not dumped.engine.running and is_zero_approx(dumped.engine.output_torque()),
		"torque %.1f Nm" % dumped.engine.output_torque())
	_check("L5. a stalled engine does not drive the car",
		absf(dumped.forward_speed) < 2.0,
		"%s m/s after the stall" % _f(dumped.forward_speed, 2))

	# --- Restart is conditional.
	var refused_restart: bool = not dumped.restart_engine()
	_check("L5. restarting in gear with the pedal out is refused",
		refused_restart and not dumped.engine.running, "running=%s" % str(dumped.engine.running))
	await _run_physics(0.12, func(_t: float) -> void: dumped.set_input_state(held))
	var started: bool = dumped.restart_engine()
	await _run_physics(0.4, func(_t: float) -> void: dumped.set_input_state(held))
	_check("L5. the engine restarts with the clutch pressed",
		started and dumped.engine.running, "running=%s rpm=%.0f" % [
			str(dumped.engine.running), dumped.engine.rpm])
	dumped.queue_free()
	await get_tree().process_frame

	# --- Scenario 1: a proper launch with a progressive pedal.
	var launched: VehicleBody = _spawn_on_floor(def, 1)
	await _run_physics(0.5, func(_t: float) -> void: launched.set_input_state(held))
	var launch_result: Dictionary = {"failed": false, "heat": 0.0}
	await _run_physics(2.2, func(t: float) -> void:
		# Pedal out over 1.1 s: the driver feeds it rather than dropping it.
		launched.set_input_state(_clutch_state(1.0 - clampf(t / 1.1, 0.0, 1.0), 0.55))
		launch_result["heat"] = maxf(float(launch_result["heat"]), launched.clutch_heat)
		if not launched.engine.running:
			launch_result["failed"] = true)
	_check("L5. a progressive launch does not stall",
		not bool(launch_result["failed"]) and launched.engine.running,
		"running=%s rpm=%.0f" % [str(launched.engine.running), launched.engine.rpm])
	_check("L5. the car actually moves off the line",
		launched.forward_speed > 0.8, "%s m/s" % _f(launched.forward_speed, 2))
	_check("L5. slipping the clutch puts heat into it", float(launch_result["heat"]) > 0.0,
		"peak fade %.3f" % float(launch_result["heat"]))
	launched.queue_free()
	await get_tree().process_frame

	# --- Scenario 3: pulling away in a high gear with no throttle.
	var bogged: VehicleBody = _spawn_on_floor(def, 4)
	await _run_physics(0.5, func(_t: float) -> void: bogged.set_input_state(held))
	var high_result: Dictionary = {"stalled": false}
	await _run_physics(1.4, func(t: float) -> void:
		bogged.set_input_state(_clutch_state(1.0 - clampf(t / 0.45, 0.0, 1.0), 0.0))
		if not bogged.engine.running:
			high_result["stalled"] = true)
	_check("L5. pulling away in 4th at idle stalls", bool(high_result["stalled"]),
		"running=%s rpm=%.0f" % [str(bogged.engine.running), bogged.engine.rpm])
	bogged.queue_free()
	await get_tree().process_frame

# --- L6: modes, interlocks and the defects this pass closed -------------------

## Every check in this section exists because the 3.1 build got it wrong and the
## suite could not see it: an automatic that demanded a clutch, an assisted car that
## stalled, reverse that ignored the pedal, a parking pawl at 80 km/h, a rail painted
## with a constant, and a lever that lost its finger to a palm.
func _test_l6_modes_and_interlocks() -> void:
	_section("L6. Modes, interlocks and the bugs they replaced")
	var hilux_base: VehicleDef = Content.vehicle_by_id("hilux_an120")

	# --- an automatic conversion is a real automatic -------------------------
	var auto_def: VehicleDef = GarageModel.build(hilux_base,
		_fit({PartDef.Slot.GEARBOX: "hilux_an120_gbox_auto"}))
	var auto_profile: TransmissionProfile = auto_def.transmissions[0]
	_check("L6. the automatic conversion builds an automatic profile",
		auto_profile.is_automatic() and not auto_profile.requires_clutch,
		"kind %d, requires_clutch %s" % [int(auto_profile.kind), str(auto_profile.requires_clutch)])
	var factory: TransmissionProfile = hilux_base.transmission_by_id("hilux_a6")
	_check("L6. the conversion carries the documented automatic ratios",
		factory != null and auto_profile.ratios == factory.ratios,
		"%s vs %s" % [str(auto_profile.ratios), str(factory.ratios if factory != null else PackedFloat32Array())])

	_flat_floor()
	var auto_body := VehicleBody.new()
	auto_body.name = "L6Auto"
	add_child(auto_body)
	auto_body.setup(auto_def, Content.surfaces)
	auto_body.configure_driver(false)
	auto_body.global_transform = Transform2D(0.0, Vector2(0.0, -0.9 * Units.PPM))
	_check("L6. an automatic needs no clutch pedal",
		not auto_body.manual_clutch_enabled and not auto_body.clutch.manual_mode,
		"manual=%s mode=%s" % [str(auto_body.manual_clutch_enabled), str(auto_body.clutch.manual_mode)])

	var auto_controls := TouchControls.new()
	add_child(auto_controls)
	auto_controls.setup(auto_profile, auto_body)
	await get_tree().process_frame
	_check("L6. an automatic car is given no clutch control",
		not auto_controls.widgets.has("clutch"),
		"widgets %s" % str(auto_controls.widgets.keys()))
	auto_controls.queue_free()

	# --- D at rest must not drive off ---------------------------------------
	auto_body.gearbox.set_range("D")
	await _run_physics(2.0, func(_t: float) -> void: pass)
	_check("L6. an automatic sits still in D at idle",
		absf(auto_body.forward_speed) < 0.6 and auto_body.engine.running,
		"speed %s m/s, running %s" % [_f(absf(auto_body.forward_speed), 2), str(auto_body.engine.running)])

	# --- the parking pawl cannot engage at speed ----------------------------
	auto_body.gearbox.vehicle_speed = 12.0
	var parked: bool = auto_body.gearbox.set_range("P")
	_check("L6. the parking pawl refuses while rolling",
		not parked and auto_body.gearbox.range_id == "D",
		"range %s refused=%s" % [auto_body.gearbox.range_id, str(not parked)])
	auto_body.queue_free()

	# --- every engine holds its own idle in neutral -------------------------
	# The idle governor is the only thing between a bogged engine and a stall, so it
	# must be strong enough to hold idle and no stronger than the engine's own torque.
	var idle_report: Array[String] = []
	var idle_ok: bool = true
	for id: String in ["jimny_jb74", "lc79"]:
		var idle_def: VehicleDef = GarageModel.build(Content.vehicle_by_id(id), GarageModel.empty_config())
		var idler: VehicleBody = _spawn_on_floor(idle_def, 0)
		idler.set_input_state(_clutch_state(0.0, 0.0))
		await _run_physics(2.5, func(_t: float) -> void: pass)
		var idle_target: float = idle_def.engine.idle_rpm
		var good: bool = idler.engine.running and idler.engine.rpm > idle_target * 0.55
		idle_report.append("%s %.0f/%.0f" % [id, idler.engine.rpm, idle_target])
		idle_ok = idle_ok and good
		idler.queue_free()
	_check("L6. every engine holds idle in neutral", idle_ok, _join(idle_report))

	# --- assisted manual: the clutch is the car's job -----------------------
	var assist_def: VehicleDef = GarageModel.build(Content.vehicle_by_id("jimny_jb74"), GarageModel.empty_config())
	var assist: VehicleBody = _spawn_on_floor(assist_def, 1)
	assist.configure_driver(true)
	assist.set_input_state(_clutch_state(0.0, 0.0))
	await _run_physics(2.0, func(_t: float) -> void: pass)
	_check("L6. an assisted car does not stall on a dumped clutch",
		assist.engine.running and assist.engine.rpm > 250.0,
		"running %s rpm %.0f" % [str(assist.engine.running), assist.engine.rpm])
	assist.queue_free()

	# --- reverse obeys the same pedal gate as every other gear --------------
	var manual_def: VehicleDef = GarageModel.build(Content.vehicle_by_id("jimny_jb74"), GarageModel.empty_config())
	var manual: VehicleBody = _spawn_on_floor(manual_def, 0)
	manual.set_input_state(_clutch_state(0.0, 0.0))
	var reverse_ok: bool = manual.select_gear(-1, false)
	_check("L6. reverse is refused with the pedal out",
		not reverse_ok and manual.gearbox.gear == 0
			and manual.gearbox.reject_reason == GearboxState.REJECT_CLUTCH,
		"gear %d reason '%s'" % [manual.gearbox.gear, manual.gearbox.reject_reason])

	# --- a pedal above the bite point transmits nothing ---------------------
	var creep: VehicleBody = _spawn_on_floor(manual_def, 1)
	var bite: float = creep.clutch.bite_point
	creep.set_input_state(_clutch_state(clampf(bite + 0.03, 0.0, 0.97), 0.0))
	await _run_physics(1.5, func(_t: float) -> void: pass)
	_check("L6. holding the pedal above the bite point cannot stall or move the car",
		creep.engine.running and absf(creep.forward_speed) < 0.4,
		"running %s speed %s m/s" % [str(creep.engine.running), _f(absf(creep.forward_speed), 2)])
	creep.queue_free()
	manual.queue_free()

	# --- the cover is the car's, not a constant ----------------------------
	var clamps: Array[float] = []
	var fades: Array[float] = []
	var heats: Array[float] = []
	for id: String in DOC_VEHICLE_IDS:
		var d: VehicleDef = Content.vehicle_by_id(id)
		clamps.append(d.clutch_clamp_rate)
		fades.append(d.clutch_fade_limit)
		heats.append(d.clutch_heat_capacity)
	_check("L6. every car clamps its clutch at its own rate",
		clamps.size() == 5 and clamps.max() - clamps.min() > 1.0,
		"%s" % str(clamps))
	_check("L6. every car fades and absorbs heat differently",
		fades.max() - fades.min() > 0.05 and heats.max() - heats.min() > 2.0,
		"fade %s heat %s" % [str(fades), str(heats)])

	# --- the rail paints the fitted window, not a constant ------------------
	var twin_def: VehicleDef = GarageModel.build(hilux_base,
		_fit({PartDef.Slot.CLUTCH: "hilux_an120_clutch_twin"}))
	var twin_body := VehicleBody.new()
	add_child(twin_body)
	twin_body.setup(twin_def, Content.surfaces)
	var twin_controls := TouchControls.new()
	add_child(twin_controls)
	twin_controls.setup(twin_def.transmissions[0], twin_body)
	await get_tree().process_frame
	var twin_slider: TouchSlider = twin_controls.widgets.get("clutch", null) as TouchSlider
	var band: float = 0.0
	if twin_slider != null:
		band = twin_slider.bite_band.y - twin_slider.bite_band.x
	_check("L6. the rail paints the fitted engagement window",
		twin_slider != null and absf(band - twin_body.clutch.engagement_window) < 0.02,
		"band %.2f vs window %.2f" % [band, twin_body.clutch.engagement_window])

	# --- a second finger cannot steal the lever ----------------------------
	twin_controls.open_panel()
	await get_tree().process_frame
	var lever: GearPanel = twin_controls.panel
	if lever != null and lever.profile != null:
		var grab: Vector2 = lever.size * 0.5 + Vector2(0.0, lever.size.y * 0.16)
		lever.press_at(grab, 0)
		var held_by_zero: bool = lever.is_dragging() and int(lever.get("_finger")) == 0
		lever.press_at(grab + Vector2(8.0, 8.0), 1)
		lever.release_finger(1)
		_check("L6. a second finger cannot steal the lever",
			held_by_zero and lever.is_dragging() and int(lever.get("_finger")) == 0,
			"dragging %s finger %d" % [str(lever.is_dragging()), int(lever.get("_finger"))])
		lever.release_finger(0)
		_check("L6. the owning finger can still release the lever",
			not lever.is_dragging(), "dragging %s" % str(lever.is_dragging()))
	else:
		_check("L6. the lever panel exists for a manual car", false, "panel missing")

	twin_controls.queue_free()
	twin_body.queue_free()
	await get_tree().process_frame
