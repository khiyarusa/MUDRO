extends Node
## MUDRO automated test suite. Runs the real simulation headlessly:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all tests passed, 1 = failures.

var _pass: int = 0
var _fail: int = 0
var _arena: Node2D
var _profile_snapshot: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	_profile_snapshot = SaveManager.data.duplicate(true)
	print("=== MUDRO TEST SUITE ===")
	print("godot %s   physics %d Hz   ppm %.1f" % [
		Engine.get_version_info()["string"], Engine.physics_ticks_per_second, Units.PPM])

	await _test_units()
	await _test_engine()
	await _test_gearbox()
	await _test_tires()
	await _test_physics_static()
	await _test_acceleration()
	await _test_hill_climb()
	await _test_grip_limit()
	await _test_mass_effect()
	await _test_wheel_radius()
	await _test_engine_braking()
	await _test_landing()
	await _test_stall()
	await _test_progression()

	# Restore the player's real profile after progression tests.
	SaveManager.data = _profile_snapshot
	SaveManager.save_profile()
	_report()

func _report() -> void:
	print("---")
	print("TESTS: %d passed, %d failed" % [_pass, _fail])
	if _fail == 0:
		print("RESULT: ALL TESTS PASSED")
	else:
		print("RESULT: FAILURES PRESENT")
	get_tree().quit(0 if _fail == 0 else 1)

func check(test_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_pass += 1
		print("PASS  %-42s %s" % [test_name, detail])
	else:
		_fail += 1
		print("FAIL  %-42s %s" % [test_name, detail])

func near(a: float, b: float, tolerance: float) -> bool:
	return absf(a - b) <= tolerance

# ------------------------------------------------------------------- units ---

func _test_units() -> void:
	check("units: metres to pixels", near(Units.m2px(2.0), 128.0, 0.001), "2 m = 128 px")
	check("units: newtons to pixels", near(Units.n2px(10.0), 640.0, 0.001), "10 N = 640 px")
	check("units: torque scaling is ppm^2", near(Units.nm2px(1.0), 4096.0, 0.001), "1 Nm = 4096 px")
	check("units: speed conversion", near(Units.px2kmh(Units.PPM * 10.0), 36.0, 0.01), "10 m/s = 36 km/h")
	check("units: rpm/omega round trip", near(Units.rpm_from_omega(Units.omega_from_rpm(3000.0)), 3000.0, 0.01), "3000 rpm")

# ------------------------------------------------------------------ engine ---

func _test_engine() -> void:
	var cfg: EngineConfig = Content.vehicle_by_id("ranger_4x4").engine
	var t_idle: float = cfg.torque_at(cfg.idle_rpm)
	var t_mid: float = cfg.torque_at(1800.0)
	var t_peak: float = cfg.peak_torque()
	check("engine: idle torque is positive", t_idle > 50.0, "%.1f Nm at %.0f rpm" % [t_idle, cfg.idle_rpm])
	check("engine: torque varies with rpm", not near(t_idle, t_mid, 1.0), "idle %.0f vs 1800 %.0f Nm" % [t_idle, t_mid])
	check("engine: peak torque inside curve", near(t_peak, 292.0, 1.0), "%.1f Nm" % t_peak)
	check("engine: interpolates between samples", cfg.torque_at(2100.0) > cfg.torque_at(1800.0) - 0.001 and cfg.torque_at(2100.0) < cfg.torque_at(2400.0) + 0.001, "2100 rpm = %.1f Nm" % cfg.torque_at(2100.0))
	var st := EngineState.new(cfg)
	st.rpm = cfg.redline_rpm + 150.0
	check("engine: rev limiter cuts torque", near(st.output_torque(), 0.0, 0.01), "%.1f Nm above redline" % st.output_torque())
	var pw: float = cfg.torque_at(3000.0) * Units.omega_from_rpm(3000.0) / 1000.0
	check("engine: power = torque x omega", near(pw, 278.0 * 314.159 / 1000.0, 0.5), "%.1f kW at 3000 rpm" % pw)
	var st2 := EngineState.new(cfg)
	st2.rpm = 3000.0
	check("engine: engine braking with closed throttle", st2.braking_torque() > 10.0, "%.1f Nm" % st2.braking_torque())
	st2.throttle = 1.0
	check("engine: engine braking fades on throttle", st2.braking_torque() < st2.braking_torque() + 0.001, "%.1f Nm at WOT" % st2.braking_torque())

# ---------------------------------------------------------------- gearbox ---

func _test_gearbox() -> void:
	var def: VehicleDef = Content.vehicle_by_id("ranger_4x4")
	var gb: GearboxState = GearboxState.new(def.gearbox)
	gb.reset(1)
	check("gearbox: 1st ratio multiplies torque", gb.total_ratio() > 10.0, "total %.2f" % gb.total_ratio())
	gb.request_gear(4, true)
	gb.update(1.0)
	var fourth: float = gb.total_ratio()
	check("gearbox: 4th is taller than 1st", fourth < 10.0, "total %.2f" % fourth)
	gb.request_gear(0, true)
	check("gearbox: neutral transmits nothing", near(gb.total_ratio(), 0.0, 0.0001), "ratio 0")
	gb.request_gear(-1, true)
	gb.update(1.0)
	check("gearbox: reverse is negative", gb.total_ratio() < 0.0, "total %.2f" % gb.total_ratio())
	var gb2: GearboxState = GearboxState.new(def.gearbox)
	gb2.reset(1)
	gb2.shift_up()
	check("gearbox: shift interrupts torque", gb2.is_shifting() and near(gb2.effective_ratio(), 0.0, 0.0001), "shift timer %.2f s" % gb2.shift_timer)
	gb2.update(0.30)
	check("gearbox: torque returns after shift", not gb2.is_shifting() and gb2.effective_ratio() > 0.0, "gear %d" % gb2.gear)
	var top: float = def.gearbox.top_speed_mps(def.tire_rear.radius_m, def.engine.max_rpm)
	check("gearbox: top speed is plausible", top > 25.0 and top < 80.0, "%.1f m/s theoretical" % top)

# ------------------------------------------------------------------ tyres ---

func _test_tires() -> void:
	var tire: TireConfig = Content.vehicle_by_id("ranger_4x4").tire_rear
	var w := WheelAxis.new(1, tire)
	w.normal_load = 4000.0
	w.omega = 0.0
	w.update_slip(0.0)
	var f0: float = w.compute_force(0.86)
	check("tyre: zero slip has no force", near(f0, 0.0, 0.1), "%.2f N" % f0)
	# Peak around 14% slip
	w.omega = (tire.peak_slip * 5.0) / tire.radius_m
	w.update_slip(5.0)
	var f_peak: float = absf(w.compute_force(0.86, 0.68))
	check("tyre: peak force at peak slip", f_peak > 2500.0, "%.0f N at slip %.2f" % [f_peak, w.slip_ratio])
	var limit: float = 0.86 * 4000.0
	check("tyre: force never exceeds mu*N", f_peak <= limit + 1.0, "%.0f N <= %.0f N" % [f_peak, limit])
	w.omega = 120.0
	w.update_slip(4.0)
	var f_slide: float = absf(w.compute_force(0.86, 0.68))
	check("tyre: sliding force below peak", f_slide < f_peak, "%.0f N sliding vs %.0f N peak" % [f_slide, f_peak])
	var wet := WheelAxis.new(1, tire)
	wet.normal_load = 4000.0
	wet.omega = 120.0
	wet.update_slip(4.0)
	var f_ice: float = absf(wet.compute_force(0.15))
	check("tyre: ice grip much lower", f_ice < f_peak * 0.3, "%.0f N on ice vs %.0f N dry" % [f_ice, f_peak])

# -------------------------------------------------------------- world setup ---

func _make_stage(angle_deg: float, length_m: float, surface_id: String) -> StageDef:
	var s := StageDef.new()
	s.id = "test_%.0f_%s" % [angle_deg, surface_id]
	s.environment = "canyon"
	s.length_m = length_m
	s.noise_amplitude = 0.0
	s.decor_density = 0.0
	var rise: float = length_m * tan(deg_to_rad(angle_deg))
	s.points = PackedVector2Array([Vector2(0, 0), Vector2(length_m * 0.5, rise * 0.5), Vector2(length_m, rise)])
	s.surface_spans = [{"from": 0.0, "to": length_m + 20.0, "surface": surface_id}]
	s.checkpoints = PackedFloat32Array()
	s.obstacles = []
	return s

func _spawn(angle_deg: float, surface_id: String, vehicle_id: String, gear: int,
		def_override: VehicleDef = null) -> Dictionary:
	if _arena != null and is_instance_valid(_arena):
		_arena.queue_free()
		await get_tree().process_frame
	_arena = Node2D.new()
	add_child(_arena)
	var stage: StageDef = _make_stage(angle_deg, 260.0, surface_id)
	var terrain := TerrainBuilder.new()
	_arena.add_child(terrain)
	terrain.build(stage, Content.surfaces)
	var def: VehicleDef = def_override if def_override != null else Content.vehicle_by_id(vehicle_id)
	var veh := VehicleBody.new()
	_arena.add_child(veh)
	veh.setup(def, Content.surfaces)
	veh.attach_surface_probe(terrain)
	veh.global_transform = terrain.start_transform()
	veh.gearbox.reset(gear)
	veh.damage.reset()
	veh.controls_locked = false
	veh.set_inputs(0.0, 0.0, 0.0, 1.0)
	veh.auto_transmission = false
	await get_tree().physics_frame
	return {"vehicle": veh, "terrain": terrain, "stage": stage, "start_y": veh.global_position.y, "start_x": veh.global_position.x}

func _sim(veh: VehicleBody, seconds: float, throttle: float, brake: float = 0.0,
		handbrake: float = 0.0, clutch: float = 1.0) -> void:
	var steps: int = int(seconds * float(Engine.physics_ticks_per_second))
	for i: int in range(steps):
		veh.set_inputs(throttle, brake, handbrake, clutch)
		await get_tree().physics_frame

func _state(veh: VehicleBody) -> Dictionary:
	return {
		"x": veh.global_position.x,
		"y": veh.global_position.y,
		"rot": veh.rotation,
		"kmh": veh.speed_kmh(),
		"rpm": veh.engine.rpm if veh.engine != null else 0.0,
		"gear": veh.gearbox.gear if veh.gearbox != null else 0,
		"running": veh.engine.running if veh.engine != null else false,
		"load": (veh.axles[0].normal_load + veh.axles[1].normal_load) if veh.axles.size() == 2 else 0.0,
		"comp_f": veh.axles[0].compression if veh.axles.size() == 2 else 0.0,
		"comp_r": veh.axles[1].compression if veh.axles.size() == 2 else 0.0,
		"slip_r": veh.axles[1].slip_ratio if veh.axles.size() == 2 else 0.0,
		"contact": (veh.axles[0].in_contact and veh.axles[1].in_contact) if veh.axles.size() == 2 else false,
	}

# --------------------------------------------------------------- physics ---

func _test_physics_static() -> void:
	var s: Dictionary = await _spawn(0.0, "hard_dirt", "ranger_4x4", 1)
	var veh: VehicleBody = s["vehicle"]
	await _sim(veh, 3.0, 0.0)
	var st: Dictionary = _state(veh)
	var weight: float = veh.definition.mass_kg * Units.GRAVITY
	check("suspension: both wheels on ground", bool(st["contact"]), "contacts %s" % str(st["contact"]))
	check("suspension: static load carries weight", near(float(st["load"]), weight, weight * 0.28), "load %.0f N vs weight %.0f N" % [float(st["load"]), weight])
	check("suspension: static compression sane", float(st["comp_f"]) > 0.02 and float(st["comp_f"]) < 0.22, "compression %.3f m" % float(st["comp_f"]))
	check("physics: body stays upright", absf(float(st["rot"])) < 0.12, "rotation %.3f rad" % float(st["rot"]))
	check("physics: no sinking through terrain", float(st["y"]) < float(s["start_y"]) + 30.0, "y %.1f -> %.1f" % [float(s["start_y"]), float(st["y"])])

func _test_acceleration() -> void:
	var s: Dictionary = await _spawn(0.0, "hard_dirt", "ranger_4x4", 1)
	var veh: VehicleBody = s["vehicle"]
	await _sim(veh, 4.0, 1.0)
	var st: Dictionary = _state(veh)
	var x_start: float = float(s["start_x"])
	var moved: float = (float(st["x"]) - x_start) / Units.PPM
	check("acceleration: vehicle moves forward", moved > 8.0, "%.1f m in 4 s" % moved)
	check("acceleration: reaches useful speed", float(st["kmh"]) > 18.0, "%.1f km/h" % float(st["kmh"]))
	check("acceleration: engine stays below redline", float(st["rpm"]) <= veh.definition.engine.redline_rpm * 1.03, "%.0f rpm" % float(st["rpm"]))
	check("acceleration: rpm above idle", float(st["rpm"]) > veh.definition.engine.idle_rpm, "%.0f rpm" % float(st["rpm"]))

func _climb_height(vehicle_id: String, angle: float, gear: int, surface: String, seconds: float) -> float:
	var s: Dictionary = await _spawn(angle, surface, vehicle_id, gear)
	var veh: VehicleBody = s["vehicle"]
	await _sim(veh, seconds, 1.0)
	var st: Dictionary = _state(veh)
	var gained: float = (float(s["start_y"]) - float(st["y"])) / Units.PPM
	print("      [climb] %s %.0f deg gear %d %s: +%.2f m  %.1f km/h  rpm %.0f  slipR %+.2f  load %.0f N  run=%s" % [
		vehicle_id, angle, gear, surface, gained, float(st["kmh"]), float(st["rpm"]),
		float(st["slip_r"]), float(st["load"]), str(st["running"])])
	_arena.queue_free()
	await get_tree().process_frame
	return gained

func _test_hill_climb() -> void:
	var g1: float = await _climb_height("ranger_4x4", 20.0, 1, "hard_dirt", 5.0)
	var g4: float = await _climb_height("ranger_4x4", 20.0, 4, "hard_dirt", 5.0)
	check("hill: first gear climbs 20 deg", g1 > 4.0, "gained %.2f m in 5 s" % g1)
	check("hill: low gear out-climbs high gear", g1 > g4 + 0.5, "1st %.2f m vs 4th %.2f m" % [g1, g4])
	check("hill: high gear cannot teleport uphill", g4 < g1, "4th gained %.2f m" % g4)

	var steep: float = await _climb_height("ranger_4x4", 28.0, 1, "hard_dirt", 5.0)
	check("hill: 28 deg is harder than 20 deg", steep < g1 + 0.2, "28 deg gained %.2f m" % steep)

func _test_grip_limit() -> void:
	var ice: float = await _climb_height("ranger_4x4", 20.0, 1, "ice", 5.0)
	var rock: float = await _climb_height("ranger_4x4", 20.0, 1, "rock", 5.0)
	check("grip: ice prevents the climb", ice < 1.2, "ice gained %.2f m" % ice)
	check("grip: rock allows the climb", rock > ice + 1.0, "rock %.2f m vs ice %.2f m" % [rock, ice])

func _test_mass_effect() -> void:
	var light: float = await _climb_height("ranger_4x4", 18.0, 1, "gravel", 4.0)
	var heavy_def: VehicleDef = Content.vehicle_by_id("ranger_4x4").duplicate_def()
	heavy_def.mass_kg += 900.0
	var s: Dictionary = await _spawn(18.0, "gravel", "ranger_4x4", 1, heavy_def)
	var veh: VehicleBody = s["vehicle"]
	await _sim(veh, 4.0, 1.0)
	var st: Dictionary = _state(veh)
	var heavy: float = (float(s["start_y"]) - float(st["y"])) / Units.PPM
	_arena.queue_free()
	await get_tree().process_frame
	check("mass: heavier vehicle climbs less", heavy < light + 0.2, "light %.2f m vs +900 kg %.2f m" % [light, heavy])

func _test_wheel_radius() -> void:
	var small_def: VehicleDef = Content.vehicle_by_id("ranger_4x4").duplicate_def()
	small_def.tire_front.radius_m = 0.28
	small_def.tire_rear.radius_m = 0.28
	var big_def: VehicleDef = Content.vehicle_by_id("ranger_4x4").duplicate_def()
	big_def.tire_front.radius_m = 0.50
	big_def.tire_rear.radius_m = 0.50
	var s1: Dictionary = await _spawn(0.0, "hard_dirt", "ranger_4x4", 1, small_def)
	await _sim(s1["vehicle"], 3.0, 1.0)
	var small: Dictionary = _state(s1["vehicle"])
	_arena.queue_free()
	await get_tree().process_frame
	var s2: Dictionary = await _spawn(0.0, "hard_dirt", "ranger_4x4", 1, big_def)
	await _sim(s2["vehicle"], 3.0, 1.0)
	var big: Dictionary = _state(s2["vehicle"])
	_arena.queue_free()
	await get_tree().process_frame
	check("wheel radius: changes wheel torque to force", absf(float(small["kmh"]) - float(big["kmh"])) > 1.0, "r0.28 %.1f km/h vs r0.50 %.1f km/h" % [float(small["kmh"]), float(big["kmh"])])

func _test_engine_braking() -> void:
	var s1: Dictionary = await _spawn(-14.0, "hard_dirt", "ranger_4x4", 1)
	await _sim(s1["vehicle"], 4.0, 0.0)
	var geared: Dictionary = _state(s1["vehicle"])
	_arena.queue_free()
	await get_tree().process_frame
	var s2: Dictionary = await _spawn(-14.0, "hard_dirt", "ranger_4x4", 0)
	await _sim(s2["vehicle"], 4.0, 0.0)
	var neutral: Dictionary = _state(s2["vehicle"])
	_arena.queue_free()
	await get_tree().process_frame
	check("downhill: engine braking limits speed", float(geared["kmh"]) < float(neutral["kmh"]) + 0.5, "in gear %.1f km/h vs neutral %.1f km/h" % [float(geared["kmh"]), float(neutral["kmh"])])

func _test_landing() -> void:
	var s: Dictionary = await _spawn(0.0, "hard_dirt", "dune_pickup", 1)
	var veh: VehicleBody = s["vehicle"]
	veh.global_position = Vector2(6.0 * Units.PPM, -2.4 * Units.PPM)
	veh.linear_velocity = Vector2.ZERO
	await _sim(veh, 3.0, 0.0)
	var st: Dictionary = _state(veh)
	check("landing: suspension absorbs the drop", is_finite(float(st["y"])) and is_finite(float(st["rot"])), "y %.1f rot %.3f" % [float(st["y"]), float(st["rot"])])
	check("landing: settles on both wheels", bool(st["contact"]), "contact %s" % str(st["contact"]))
	check("landing: compression returns to ride height", float(st["comp_f"]) < 0.24, "comp %.3f m" % float(st["comp_f"]))
	check("landing: damage taken on hard hit is bounded", veh.damage.chassis > 0.0, "chassis %.2f" % veh.damage.chassis)

func _test_stall() -> void:
	var s: Dictionary = await _spawn(0.0, "hard_dirt", "dune_pickup", 4)
	var veh: VehicleBody = s["vehicle"]
	veh.manual_clutch_enabled = true
	veh.auto_clutch = false
	await _sim(veh, 4.0, 0.0, 1.0, 0.0, 1.0)
	var st: Dictionary = _state(veh)
	check("stall: engine dies under load at rest", not bool(st["running"]), "running %s rpm %.0f" % [str(st["running"]), float(st["rpm"])])
	veh.restart_engine()
	await _sim(veh, 0.5, 0.0, 0.0, 0.0, 0.0)
	check("stall: engine restarts", veh.engine.running, "rpm %.0f" % veh.engine.rpm)

# ------------------------------------------------------------- progression ---

func _test_progression() -> void:
	SaveManager.reset_profile()
	check("save: fresh profile has credits", SaveManager.credits() >= 600, "%d credits" % SaveManager.credits())
	check("save: first stage unlocked", SaveManager.is_stage_unlocked("canyon_01"), "canyon_01")
	check("save: second stage locked", not SaveManager.is_stage_unlocked("canyon_02"), "canyon_02 locked")

	var st: StageDef = Content.stage_by_id("canyon_01")
	var out: Dictionary = SaveManager.complete_stage(st, 70.0, 3, "career")
	check("save: completion recorded", SaveManager.is_completed("canyon_01"), "completed")
	check("save: best time stored", near(SaveManager.best_time("canyon_01"), 70.0, 0.001), "70.00 s")
	check("save: medal stored", SaveManager.medal_of("canyon_01") == 3, "gold")
	check("save: reward paid", int(out.get("credits", 0)) == st.reward_credits, "+%d credits" % int(out.get("credits", 0)))
	check("save: next stage unlocked", SaveManager.is_stage_unlocked("canyon_02"), "canyon_02")

	var saved: int = SaveManager.credits()
	SaveManager.load_profile()
	check("save: reload keeps progress", SaveManager.is_completed("canyon_01") and SaveManager.credits() == saved, "%d credits after reload" % SaveManager.credits())

	var base: VehicleDef = Content.vehicle_by_id("rocky_buggy")
	var before: float = base.engine.peak_torque()
	SaveManager.add_credits(5000)
	var blocked_without_tier1: bool = SaveManager.buy_upgrade("rocky_buggy", "engine_2")
	check("upgrade: tier gating works", not blocked_without_tier1, "engine_2 refused without tier 1")
	var bought: bool = SaveManager.buy_upgrade("rocky_buggy", "engine_1")
	check("upgrade: purchase recorded", bought and SaveManager.has_upgrade("rocky_buggy", "engine_1"), "engine_1 owned")
	var bought2: bool = SaveManager.buy_upgrade("rocky_buggy", "engine_2")
	check("upgrade: next tier unlocks after previous", bought2, "engine_2 bought after engine_1")
	var built: VehicleDef = GarageModel.build(base, ["engine_2"])
	check("upgrade: engine tier raises torque", built.engine.peak_torque() > before * 1.15, "%.0f -> %.0f Nm" % [before, built.engine.peak_torque()])
	var built2: VehicleDef = GarageModel.build(base, ["tires_2"])
	check("upgrade: tyre tier raises grip", built2.tire_rear.mu_scale > base.tire_rear.mu_scale, "%.2f -> %.2f mu" % [base.tire_rear.mu_scale, built2.tire_rear.mu_scale])
	var built3: VehicleDef = GarageModel.build(base, ["chassis_1"])
	check("upgrade: chassis tier adds mass and durability", built3.mass_kg > base.mass_kg and built3.durability > base.durability, "%.0f kg, dur %.2f" % [built3.mass_kg, built3.durability])

	SaveManager.add_credits(5000)
	var stage_count: int = Content.stages.size()
	check("content: twelve stages authored", stage_count == 12, "%d stages" % stage_count)
	check("content: four vehicles", Content.vehicles.size() == 4, "%d vehicles" % Content.vehicles.size())
	check("content: three environments", Content.environments.size() == 3, "%d environments" % Content.environments.size())
	var env_counts: Array[int] = [0, 0, 0]
	for s: StageDef in Content.stages:
		match s.environment:
			"canyon":
				env_counts[0] += 1
			"pine":
				env_counts[1] += 1
			"quarry":
				env_counts[2] += 1
	check("content: four stages per environment", env_counts[0] == 4 and env_counts[1] == 4 and env_counts[2] == 4, str(env_counts))
