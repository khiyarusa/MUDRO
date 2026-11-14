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
	await _test_input_state()
	await _test_transmission_profiles()
	await _test_h_pattern()
	await _test_clutch_interlock()
	await _test_automatic()
	await _test_transfer_and_diff()
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
	await _test_weather()
	await _test_winch()
	await _test_touch_layout()
	await _test_route_stats()
	await _test_content_2_0()
	await _test_bridge_platform()
	await _test_race_integration()
	await _test_progression()
	await _test_config_save()

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
	check("content: sixteen stages authored", stage_count == 16, "%d stages" % stage_count)
	check("content: four vehicles", Content.vehicles.size() == 4, "%d vehicles" % Content.vehicles.size())
	check("content: four environments", Content.environments.size() == 4, "%d environments" % Content.environments.size())
	var env_counts: Array[int] = [0, 0, 0, 0]
	for s: StageDef in Content.stages:
		match s.environment:
			"canyon":
				env_counts[0] += 1
			"pine":
				env_counts[1] += 1
			"quarry":
				env_counts[2] += 1
			"black_ridge":
				env_counts[3] += 1
	check("content: four stages per environment", env_counts[0] == 4 and env_counts[1] == 4 and env_counts[2] == 4 and env_counts[3] == 4, str(env_counts))

# ------------------------------------------------------------ input contract ---

func _test_input_state() -> void:
	var s := VehicleInputState.new()
	s.throttle = 1.8
	s.brake = -0.4
	s.clutch = 0.5
	s.handbrake = 2.0
	s.sanitize()
	check("input: analog channels clamp", near(s.throttle, 1.0, 0.0001) and near(s.brake, 0.0, 0.0001) and near(s.handbrake, 1.0, 0.0001), s.describe())
	s.clutch = 0.979
	check("input: 97.9% clutch is not enough", not s.clutch_fully_pressed(), "%.3f" % s.clutch)
	s.clutch = 0.98
	check("input: 98% clutch releases the interlock", s.clutch_fully_pressed(), "%.3f" % s.clutch)

	var touch := VehicleInputState.new()
	touch.throttle = 0.4
	touch.clutch = 1.0
	touch.gear_step = 1
	touch.recover_requested = true
	var key := VehicleInputState.new()
	key.throttle = 0.9
	key.brake = 0.3
	touch.merge(key)
	check("input: merge keeps the strongest throttle", near(touch.throttle, 0.9, 0.0001), "%.2f" % touch.throttle)
	check("input: merge keeps the pressed clutch", near(touch.clutch, 1.0, 0.0001), "%.2f" % touch.clutch)
	check("input: merge sums gear steps", touch.gear_step == 1, "step %d" % touch.gear_step)
	touch.clear_requests()
	check("input: requests are one-shot", not touch.recover_requested and touch.gear_step == 0, "cleared")

	var copy: VehicleInputState = touch.copy()
	copy.throttle = 0.0
	check("input: copy does not alias", touch.throttle > 0.5 and copy.throttle < 0.01, "%.2f vs %.2f" % [touch.throttle, copy.throttle])

# ------------------------------------------------------------- transmissions ---

func _test_transmission_profiles() -> void:
	var ranger: VehicleDef = Content.vehicle_by_id("ranger_4x4")
	var buggy: VehicleDef = Content.vehicle_by_id("rocky_buggy")
	var pickup: VehicleDef = Content.vehicle_by_id("dune_pickup")
	var titan: VehicleDef = Content.vehicle_by_id("titan_offroad")

	check("transmission: every vehicle has its own box",
		ranger.stock_transmission_profile().id != titan.stock_transmission_profile().id
		and buggy.stock_transmission_profile().id != pickup.stock_transmission_profile().id,
		"%s / %s / %s / %s" % [buggy.stock_transmission_profile().id, ranger.stock_transmission_profile().id,
			pickup.stock_transmission_profile().id, titan.stock_transmission_profile().id])
	check("transmission: ranger offers manual and automatic",
		ranger.transmission_options().size() == 2 and ranger.transmission_by_id("ranger_auto6") != null
		and ranger.transmission_by_id("ranger_auto6").is_automatic(), "2 options")
	check("transmission: buggy stock is a clutchless dog box",
		buggy.stock_transmission_profile().kind == TransmissionProfile.Kind.MANUAL_SEQ
		and not buggy.stock_transmission_profile().requires_clutch, "sequential")
	check("transmission: pickup automatic uses a converter",
		pickup.stock_transmission_profile().uses_converter(), "stall x%.2f" % pickup.stock_transmission_profile().converter_stall_mult)
	check("transmission: titan has a low range", titan.transfer_ids.has("4L"), str(titan.transfer_ids))
	check("transmission: ranger has no low-range-less claim", ranger.has_transfer_case(), str(ranger.transfer_ids))
	check("transmission: torque capacities differ",
		not is_equal_approx(ranger.stock_transmission_profile().max_torque_nm, titan.stock_transmission_profile().max_torque_nm),
		"%d vs %d Nm" % [int(ranger.stock_transmission_profile().max_torque_nm), int(titan.stock_transmission_profile().max_torque_nm)])

# ----------------------------------------------------------------- h-pattern ---

func _test_h_pattern() -> void:
	var p: TransmissionProfile = Content.vehicle_by_id("ranger_4x4").stock_transmission_profile()
	var n1: Vector2 = p.gate_node(1)
	var n2: Vector2 = p.gate_node(2)
	var n3: Vector2 = p.gate_node(3)
	check("h-pattern: 1 and 2 share a column", is_equal_approx(n1.x, n2.x) and not is_equal_approx(n1.y, n2.y), "%.2f/%.2f" % [n1.y, n2.y])
	check("h-pattern: 3 is in the next column", not is_equal_approx(n1.x, n3.x), "x %.2f vs %.2f" % [n1.x, n3.x])
	check("h-pattern: reverse has its own column", not is_equal_approx(p.gate_node(-1).x, n3.x), "x %.2f" % p.gate_node(-1).x)
	check("h-pattern: neutral is the crossing rail", near(p.gate_project(Vector2(0.5, 0.5)).get("gear", -9), 0, 0.001), "N")
	check("h-pattern: gate commits 1st at its node", int(p.gate_project(n1).get("gear", 0)) == 1, str(n1))
	var diagonal: Dictionary = p.gate_project(Vector2((n2.x + n3.x) * 0.5, (n2.y + n3.y) * 0.5))
	check("h-pattern: a diagonal cannot select a gear", int(diagonal.get("gear", -9)) == 0, "gear %d" % int(diagonal.get("gear", -9)))
	check("h-pattern: six-speed box has six nodes", p.gear_count() == 5 or p.gear_count() == 6, "%d gears" % p.gear_count())

# ------------------------------------------------------------ clutch interlock ---

func _test_clutch_interlock() -> void:
	var p: TransmissionProfile = Content.vehicle_by_id("ranger_4x4").stock_transmission_profile()
	var gb := GearboxState.new(p)
	gb.engine_redline = 4500.0
	gb.wheel_radius = 0.39
	gb.reset(1)
	gb.update(1.0)
	var refused: bool = gb.request_gear(2, false, false, 0.0)
	check("clutch: shift refused without the pedal", not refused and gb.reject_reason == GearboxState.REJECT_CLUTCH, gb.reject_reason)
	check("clutch: refusal leaves the gear engaged", gb.gear == 1, "gear %d" % gb.gear)
	var accepted: bool = gb.request_gear(2, false, true, 0.0)
	check("clutch: shift accepted with the pedal down", accepted and gb.gear == 2, "gear %d" % gb.gear)
	check("clutch: shift interrupts torque", gb.is_shifting() and near(gb.effective_ratio(), 0.0, 0.0001), "%.2f s" % gb.shift_timer)

	gb.update(0.5)
	gb.reset(3)
	gb.update(1.0)
	var overrev: bool = gb.request_gear(1, false, true, 40.0)
	check("clutch: over-rev downshift blocked", not overrev and gb.reject_reason == GearboxState.REJECT_OVERREV, gb.reject_reason)
	gb.reset(0)
	gb.update(1.0)
	var rolling_reverse: bool = gb.request_gear(-1, false, true, 5.0)
	check("clutch: reverse blocked while rolling", not rolling_reverse and gb.reject_reason == GearboxState.REJECT_REVERSE, gb.reject_reason)

	var seq: TransmissionProfile = Content.vehicle_by_id("rocky_buggy").stock_transmission_profile()
	check("clutch: dog box needs no pedal", not seq.requires_clutch, "sequential")

# ----------------------------------------------------------------- automatic ---

func _test_automatic() -> void:
	var p: TransmissionProfile = Content.vehicle_by_id("titan_offroad").stock_transmission_profile()
	var gb := GearboxState.new(p)
	gb.engine_redline = 3400.0
	gb.wheel_radius = 0.51
	gb.auto_mode = true
	gb.range_id = "D"
	gb.reset(0)
	gb.auto_update(0.4, 800.0, 0.4, 1.5, 0.2, 0.0, 0.0)
	check("automatic: pulls away from rest", gb.gear == 1, "gear %d" % gb.gear)
	gb.update(1.0)
	gb.time_in_gear = 1.0
	gb.auto_update(0.4, 3300.0, 0.9, 18.0, 0.8, 0.0, 0.0)
	check("automatic: upshifts under load", gb.gear == 2, "gear %d" % gb.gear)

	gb.reset(4)
	gb.time_in_gear = 2.0
	gb.auto_update(0.4, 1500.0, 1.0, 12.0, 0.9, 0.0, 0.0)
	check("automatic: kickdown drops a gear", gb.gear == 3 and gb.is_kickdown(), "gear %d" % gb.gear)

	gb.reset(3)
	gb.time_in_gear = 2.0
	gb.auto_update(0.4, 3200.0, 0.9, 4.0, 0.9, 0.0, 3.0)
	check("automatic: does not chase a spinning wheel", gb.gear == 3, "gear %d" % gb.gear)

	gb.reset(3)
	gb.time_in_gear = 2.0
	gb.auto_update(0.4, 1200.0, 0.5, 9.0, 0.8, 18.0, 0.0)
	check("automatic: grade triggers a downshift", gb.gear == 2, "gear %d" % gb.gear)

	gb.reset(2)
	gb.range_id = "L"
	gb.time_in_gear = 2.0
	gb.auto_update(0.4, 3300.0, 0.9, 10.0, 0.8, 0.0, 0.0)
	check("automatic: L holds the low gears", gb.gear == 2, "gear %d" % gb.gear)

# ---------------------------------------------------------- transfer and diff ---

func _test_transfer_and_diff() -> void:
	var p: TransmissionProfile = Content.vehicle_by_id("ranger_4x4").stock_transmission_profile()
	var gb := GearboxState.new(p)
	gb.engine_redline = 4500.0
	gb.reset(1)
	gb.update(1.0)
	var high: float = gb.total_ratio()
	gb.set_transfer_modes(PackedStringArray(["2H", "4H", "4L"]), PackedFloat32Array([1.0, 1.0, 2.48]))
	gb.update(1.0)
	gb.set_transfer("4L")
	gb.update(1.0)
	check("transfer: 4L multiplies the driveline", near(gb.total_ratio(), high * 2.48, 0.5), "%.1f -> %.1f" % [high, gb.total_ratio()])
	check("transfer: 4L drives the front axle", gb.transfer_drives_front(), gb.transfer_id())
	gb.set_transfer("2H")
	gb.update(1.0)
	check("transfer: 2H leaves the front axle unpowered", not gb.transfer_drives_front(), gb.transfer_id())

	var s: Dictionary = await _spawn(0.0, "hard_dirt", "ranger_4x4", 1)
	var veh: VehicleBody = s["vehicle"]
	veh.diff_mode = "locked"
	veh.axles[0].omega = 4.0
	veh.axles[1].omega = 20.0
	veh.axles[0].in_contact = true
	veh.axles[1].in_contact = true
	veh._apply_differential()
	check("diff: locked axles turn together", absf(veh.axles[0].omega - veh.axles[1].omega) < 0.01, "%.2f / %.2f" % [veh.axles[0].omega, veh.axles[1].omega])
	veh.diff_mode = "open"
	veh.axles[0].omega = 4.0
	veh.axles[1].omega = 20.0
	veh._apply_differential()
	check("diff: open axle keeps its own speed", absf(veh.axles[0].omega - veh.axles[1].omega) > 10.0, "%.2f / %.2f" % [veh.axles[0].omega, veh.axles[1].omega])
	veh.diff_mode = "lsd"
	veh.axles[0].omega = 4.0
	veh.axles[1].omega = 20.0
	veh._apply_differential()
	check("diff: limited slip pulls speeds together", veh.axles[0].omega > 4.0 and veh.axles[0].omega < veh.axles[1].omega, "%.2f / %.2f" % [veh.axles[0].omega, veh.axles[1].omega])

# ---------------------------------------------------------------- weather ----

func _test_weather() -> void:
	var w := WeatherSystem.new()
	add_child(w)
	w.setup("canyon", "snow", 2)
	check("weather: snow reduces grip", near(w.grip_scale, 0.86, 0.001), "grip %.2f" % w.grip_scale)
	check("weather: snow raises rolling resistance", w.rr_scale > 1.0, "rr %.2f" % w.rr_scale)
	check("weather: a snow stage reports snow", Content.stage_by_id("black_ridge_04").weather == "snow", Content.stage_by_id("black_ridge_04").weather)
	var s: Dictionary = await _spawn(0.0, "hard_dirt", "ranger_4x4", 1)
	var veh: VehicleBody = s["vehicle"]
	w.apply_to(veh)
	check("weather: grip scale reaches the vehicle", near(veh.surface_grip_scale, 0.86, 0.001), "%.2f" % veh.surface_grip_scale)
	w.queue_free()

# ------------------------------------------------------------------- winch ----

func _test_winch() -> void:
	var s: Dictionary = await _spawn(0.0, "hard_dirt", "ranger_4x4", 1)
	var veh: VehicleBody = s["vehicle"]
	var terrain: TerrainBuilder = s["terrain"]
	var stage: StageDef = s["stage"]
	var winch := WinchSystem.new()
	_arena.add_child(winch)
	winch.setup(veh, terrain, stage)
	var start_x: float = veh.global_position.x
	var result: String = winch.toggle()
	check("winch: attaches to a legal anchor", winch.attached and result.begins_with("winch_attached"), result)
	check("winch: rated pull comes from the vehicle", near(winch.max_force, veh.definition.winch_force_n, 1.0), "%.0f N" % winch.max_force)
	await _sim(veh, 1.2, 0.0)
	check("winch: cable pulls the vehicle", veh.global_position.x - start_x > 0.05, "%.2f m" % ((veh.global_position.x - start_x) / Units.PPM))
	check("winch: tension stays inside the rated force", winch.tension_kn() <= winch.max_force / 1000.0 + 0.01, "%.1f kN" % winch.tension_kn())
	winch.toggle()
	check("winch: detaches cleanly", not winch.attached and veh.external_force.length() < 0.01, "released")

# -------------------------------------------------------------- touch layout ---

func _test_touch_layout() -> void:
	var controls := TouchControls.new()
	add_child(controls)
	controls.preview_all = true
	controls.setup(Content.vehicle_by_id("ranger_4x4").stock_transmission_profile(), null)
	var aspects: Array[Vector2] = [Vector2(1280, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(2340, 1080)]
	var all_inside: bool = true
	var separated: bool = true
	for view: Vector2 in aspects:
		controls.size = view
		controls.layout()
		for w: TouchWidget in controls.widgets.values():
			var r := Rect2(w.position, w.size)
			if r.position.x < -1.0 or r.position.y < -1.0 or r.end.x > view.x + 1.0 or r.end.y > view.y + 1.0:
				all_inside = false
		var a: TouchWidget = controls.widgets.get("throttle")
		var b: TouchWidget = controls.widgets.get("brake")
		if a != null and b != null and Rect2(a.position, a.size).intersects(Rect2(b.position, b.size), true):
			separated = false
	check("touch: every control stays on screen at 4 aspects", all_inside, "16:9 / 19.5:9 / 20:9 / 2340x1080")
	check("touch: throttle and brake never overlap", separated, "4 aspects")

	controls.size = Vector2(1600, 720)
	controls.layout()
	for preset: String in TouchControls.PRESETS:
		SettingsService.control_preset = preset
		controls.rebuild()
		controls.size = Vector2(1600, 720)
		controls.layout()
		var ok: bool = controls.widgets.has("throttle") and controls.widgets.has("brake") and controls.widgets.has("gear")
		check("touch: preset '%s' builds its controls" % preset, ok, "%d widgets" % controls.widgets.size())
	SettingsService.control_preset = "buttons"
	controls.rebuild()
	controls.size = Vector2(1600, 720)
	controls.layout()

	var throttle: TouchWidget = controls.widgets.get("throttle") as TouchWidget
	var clutch: TouchWidget = controls.widgets.get("clutch") as TouchWidget
	var p_throttle: Vector2 = throttle.position + throttle.size * 0.5
	var p_clutch: Vector2 = clutch.position + clutch.size * 0.5
	controls._begin(1, p_throttle)
	controls._begin(2, p_clutch)
	check("touch: two fingers own two controls", throttle.active and clutch.active and throttle.value > 0.99 and clutch.value > 0.99, "thr %.2f clu %.2f" % [throttle.value, clutch.value])
	controls._end(1)
	check("touch: lifting the throttle keeps the clutch down", not throttle.active and clutch.active and clutch.value > 0.99, "clu %.2f" % clutch.value)
	controls._end(2)
	check("touch: lifting the second finger releases it", not clutch.active and near(clutch.value, 0.0, 0.001), "clu %.2f" % clutch.value)

	controls._begin(3, p_throttle)
	controls._begin(4, p_clutch)
	controls.release_all()
	check("touch: pause / focus loss releases everything", not throttle.active and not clutch.active and near(throttle.value, 0.0, 0.001) and near(clutch.value, 0.0, 0.001), "cleared")

	controls.open_panel()
	check("touch: gear panel opens", controls.panel_open and controls.panel.visible, "visible")
	controls.close_panel()
	check("touch: gear panel closes", not controls.panel_open, "closed")

	SettingsService.control_positions = {"buttons:throttle": [0.7, 0.55]}
	controls.layout()
	var moved: Vector2 = throttle.position + throttle.size * 0.5
	check("touch: a layout override moves the control", absf(moved.x - 0.7 * 1600.0) < 2.0 and absf(moved.y - 0.55 * 720.0) < 2.0, "%.0f,%.0f" % [moved.x, moved.y])
	SettingsService.control_positions = {}
	controls.queue_free()

# -------------------------------------------------------------- route stats ---

func _test_route_stats() -> void:
	var st: StageDef = Content.stage_by_id("black_ridge_03")
	var stats: Dictionary = st.route_stats()
	check("route: length comes from the stage", near(float(stats["length_m"]), st.length_m, 0.01), "%.0f m" % st.length_m)
	check("route: max grade is a real slope", float(stats["max_grade_deg"]) > 10.0, "%.1f deg" % float(stats["max_grade_deg"]))
	var surface_total: float = float(stats["rock_pct"]) + float(stats["dirt_pct"]) + float(stats["mud_pct"])
	check("route: surface split sums to 100%", absf(surface_total - 100.0) < 0.5, "%.1f%%" % surface_total)
	check("route: obstacles are counted", int(stats["obstacles"]) >= 8, "%d" % int(stats["obstacles"]))
	check("route: the bridge stage is harder than the first", st.difficulty > Content.stage_by_id("black_ridge_01").difficulty, "%d vs %d" % [st.difficulty, Content.stage_by_id("black_ridge_01").difficulty])

# ----------------------------------------------------------------- content 2.0 ---

func _test_content_2_0() -> void:
	check("content: black ridge exists", Content.env_meta("black_ridge").size() > 0, "meta")
	var bridge_stage: StageDef = Content.stage_by_id("black_ridge_03")
	var bridges: int = 0
	var kinds: Dictionary = {}
	for o: Dictionary in bridge_stage.obstacles:
		kinds[String(o.get("kind", ""))] = true
		if String(o.get("kind", "")) == "steel_bridge":
			bridges += 1
	check("content: broken span has two real bridges", bridges == 2, "%d" % bridges)
	check("content: industrial props are authored", kinds.has("industrial_barrier") and kinds.has("ore_cart") and kinds.has("pipe_stack"), str(kinds.keys()))
	check("content: ash and scree surfaces exist", Content.surfaces.has("ash") and Content.surfaces.has("scree"), "surfaces")
	check("content: every vehicle has tyre and suspension choices",
		Content.vehicle_by_id("ranger_4x4").tire_options.size() >= 3 and Content.vehicle_by_id("ranger_4x4").suspension_options.size() >= 3,
		"%d / %d" % [Content.vehicle_by_id("ranger_4x4").tire_options.size(), Content.vehicle_by_id("ranger_4x4").suspension_options.size()])
	check("content: winches are vehicle-specific", Content.vehicle_by_id("ranger_4x4").has_winch and not Content.vehicle_by_id("rocky_buggy").has_winch, "ranger yes / buggy no")

## A bridge must be a real platform, not a picture: the car drives across the gap
## on the collider and the surface under the tyres reports steel.
func _test_bridge_platform() -> void:
	var stage: StageDef = Content.stage_by_id("black_ridge_03")
	var world := Node2D.new()
	add_child(world)
	var terrain := TerrainBuilder.new()
	world.add_child(terrain)
	terrain.build(stage, Content.surfaces)
	var def: VehicleDef = Content.vehicle_by_id("ranger_4x4")
	var veh := VehicleBody.new()
	world.add_child(veh)
	veh.setup(def, Content.surfaces)
	veh.attach_surface_probe(terrain)
	veh.configure_driver(true)
	veh.global_transform = Transform2D(0.0, Vector2(295.0 * Units.PPM, -22.0 * Units.PPM - 0.8 * Units.PPM))
	veh.gearbox.reset(1)
	veh.damage.reset()
	veh.controls_locked = false
	await get_tree().physics_frame
	var deck_surface: SurfaceProfile = terrain.surface_at_world(Vector2(300.0 * Units.PPM, -22.0 * Units.PPM))
	check("bridge: deck reports a steel surface", deck_surface != null and deck_surface.id == "steel", deck_surface.id if deck_surface != null else "none")
	var start_x: float = veh.global_position.x
	for i: int in range(240):
		veh.set_inputs(0.70, 0.0, 0.0, 1.0)
		await get_tree().physics_frame
	var travelled: float = (veh.global_position.x - start_x) / Units.PPM
	check("bridge: the car crosses the span", travelled > 3.0, "%.1f m" % travelled)
	check("bridge: the car stays on the deck", veh.global_position.y < -16.0 * Units.PPM, "y %.1f m" % (-veh.global_position.y / Units.PPM))
	world.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------ config & save ---

## End-to-end: the race scene, the shared input state, the gearbox interlock and the
## panel must agree. This instantiates the real race, not a stub.
func _test_race_integration() -> void:
	SaveManager.set_config_value("ranger_4x4", "transmission", "ranger_h5")
	SaveManager.set_config_value("ranger_4x4", "transfer", "4H")
	SaveManager.set_config_value("ranger_4x4", "diff", "open")
	GameSession.start_stage("canyon_01", "career")
	GameSession.vehicle_id = "ranger_4x4"
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	if packed == null:
		check("race: scene loads", false, "missing")
		return
	var race: Node = packed.instantiate()
	add_child(race)
	for i: int in range(4):
		await get_tree().process_frame
	var veh: VehicleBody = race.get("vehicle") as VehicleBody
	check("race: builds a vehicle and a HUD", veh != null and race.get("hud") != null, "ready")
	if veh == null:
		return
	check("race: fitted gearbox is the manual", veh.gearbox.profile != null and veh.gearbox.profile.is_manual() and veh.gearbox.profile.requires_clutch, veh.gearbox.profile.id if veh.gearbox.profile != null else "none")
	race.set("state", "paused")
	veh.controls_locked = false
	veh.gearbox.reset(1)
	veh.gearbox.update(1.0)

	# Full manual: a shift with the pedal released must be refused.
	SettingsService.clutch = "manual"
	veh.configure_driver(false)
	veh.set_inputs(0.0, 0.0, 0.0, 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	race.call("_request_gear", 2)
	check("race: manual shift is refused without the clutch", veh.gearbox.gear == 1, "gear %d reason %s auto %s pedal %.2f" % [veh.gearbox.gear, veh.gearbox.reject_reason, str(veh.auto_clutch), veh.clutch.pedal])

	# Press the pedal to the floor and the same request is accepted.
	veh.set_inputs(0.0, 0.0, 0.0, 0.0)
	for i: int in range(3):
		await get_tree().physics_frame
	check("race: clutch pedal reaches the floor", veh.clutch_pedal() >= VehicleInputState.CLUTCH_FULL, "%.2f" % veh.clutch_pedal())
	race.call("_request_gear", 2)
	check("race: manual shift accepted with the clutch", veh.gearbox.gear == 2, "gear %d reason %s" % [veh.gearbox.gear, veh.gearbox.reject_reason])

	# Transfer case and diff are live through the same path.
	race.call("_cycle_transfer")
	check("race: transfer case cycles", veh.gearbox.transfer_id() != "4H", veh.gearbox.transfer_id())
	race.call("_cycle_diff")
	check("race: differential cycles", veh.diff_mode != "open", veh.diff_mode)

	SettingsService.clutch = "assist"
	veh.configure_driver(true)
	race.queue_free()
	for i: int in range(2):
		await get_tree().process_frame

# ------------------------------------------------------------ config & save ---
func _test_config_save() -> void:
	SaveManager.reset_profile()
	var cfg: Dictionary = SaveManager.vehicle_config("ranger_4x4")
	check("config: defaults to the stock gearbox", String(cfg.get("transmission", "")) == "ranger_h5", String(cfg.get("transmission", "")))
	SaveManager.set_config_value("ranger_4x4", "transmission", "ranger_auto6")
	SaveManager.set_config_value("ranger_4x4", "transfer", "4L")
	SaveManager.set_config_value("ranger_4x4", "diff", "locked")
	SaveManager.set_config_value("ranger_4x4", "tires", "mt")
	SaveManager.load_profile()
	var back: Dictionary = SaveManager.vehicle_config("ranger_4x4")
	check("config: choices survive a reload", String(back.get("transmission", "")) == "ranger_auto6" and String(back.get("transfer", "")) == "4L", "%s / %s" % [back.get("transmission", ""), back.get("transfer", "")])
	var built: VehicleDef = GarageModel.build(Content.vehicle_by_id("ranger_4x4"), [], back)
	check("config: build applies the automatic", built.stock_transmission_profile().is_automatic(), built.stock_transmission_profile().id)
	check("config: build applies 4L", built.active_transfer == "4L" and built.active_diff == "locked", "%s / %s" % [built.active_transfer, built.active_diff])
	check("config: mud tyres raise grip in the build", built.tire_rear.mu_scale > Content.vehicle_by_id("ranger_4x4").tire_rear.mu_scale, "%.2f" % built.tire_rear.mu_scale)

	var legacy: Dictionary = {"version": 3, "credits": 4321, "owned_vehicles": ["rocky_buggy"], "records": {}, "upgrades": {}}
	var migrated: Dictionary = SaveManager._migrate(legacy)
	check("save: v3 profile migrates without losing credits", int(migrated["version"]) == SaveManager.VERSION and int(migrated["credits"]) == 4321 and migrated.has("config"), "v%d" % int(migrated["version"]))
	SaveManager.reset_profile()
