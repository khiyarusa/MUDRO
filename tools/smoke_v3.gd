extends Node
## Developer smoke probe for the 3.0 data spine. Run with:
##   godot --headless --path . res://tools/smoke_v3.tscn
## Prints the derived build for every vehicle and a few track statistics, then
## quits with code 1 if anything is obviously broken.

func _ready() -> void:
	var failures: int = 0
	print("=== MUDRO 3.0 smoke ===")
	print("vehicles=%d tracks=%d parts=%d regions=%d" % [
		Content.vehicles.size(), Content.tracks.size(), Content.part_count(), Content.regions.size()])

	for v: VehicleDef in Content.vehicles:
		var built: VehicleDef = GarageModel.build(v, GarageModel.empty_config())
		var b: EngineBuild = built.engine_build
		print("%-12s doc %3.0f kW / %3.0f Nm -> built %3.1f kW @%4.0f / %3.1f Nm @%4.0f | mass %4.0f | boost %.2f | rad %.0f kW | parts %d" % [
			v.id, v.doc_power_kw, v.doc_torque_nm, built.peak_power_kw(), built.power_rpm(),
			built.peak_torque_nm(), built.torque_rpm(), built.mass_kg, b.boost_bar, b.radiator_kw,
			built.parts.size()])
		if absf(built.peak_torque_nm() - v.doc_torque_nm) > v.doc_torque_nm * 0.05:
			print("  FAIL torque out of tolerance")
			failures += 1
		# A factory sheet is allowed to be internally inconsistent: 150 kW at 3,000 rpm
		# implies 477 Nm, while the same sheet lists 420 Nm. Compare against the
		# physically implied figure when the two disagree.
		var implied_kw: float = v.doc_torque_nm * v.doc_power_rpm * TAU / 60.0 / 1000.0
		var expected_kw: float = minf(v.doc_power_kw, implied_kw * 1.05)
		if absf(built.peak_power_kw() - expected_kw) > expected_kw * 0.12:
			print("  FAIL power out of tolerance (built %.1f, expected %.1f)" % [built.peak_power_kw(), expected_kw])
			failures += 1

	for t: TrackDef in Content.tracks:
		var s: Dictionary = t.stats()
		print("%-16s %4.0f m  +%4.0f  -%4.0f  max %4.1f°  avg %5.1f°  cp %d  model %5.1f s  med %.1f/%.1f/%.1f" % [
			t.id, s["length_m"], s["elevation_gain_m"], s["elevation_descent_m"],
			s["max_grade_deg"], s["avg_grade_deg"], int(s["checkpoints"]),
			s["model_time_s"], t.medal_gold, t.medal_silver, t.medal_bronze])
		if not t.is_valid_layout():
			print("  FAIL invalid layout")
			failures += 1
		if float(s["max_grade_deg"]) > 30.0:
			print("  FAIL grade too steep")
			failures += 1

	# Tuned build comparison on the Hilux: a bigger turbo needs ECU headroom, and
	# then the fuel system becomes the limit until injectors and pump are upgraded.
	var hilux: VehicleDef = Content.vehicle_by_id("hilux_an120")
	var base_cfg: Dictionary = GarageModel.empty_config()
	var turbo_cfg: Dictionary = base_cfg.duplicate(true)
	turbo_cfg["parts"] = {
		str(int(PartDef.Slot.TURBO)): "hilux_an120_turbo_big",
		str(int(PartDef.Slot.ECU)): "hilux_an120_ecu_2",
		str(int(PartDef.Slot.INTERCOOLER)): "hilux_an120_ic_race",
	}
	var fuel_cfg: Dictionary = turbo_cfg.duplicate(true)
	fuel_cfg["parts"][str(int(PartDef.Slot.INJECTORS))] = "hilux_an120_inj_30"
	fuel_cfg["parts"][str(int(PartDef.Slot.FUEL_PUMP))] = "hilux_an120_pump_race"
	var stock_build: VehicleDef = GarageModel.build(hilux, base_cfg)
	var turbo_build: VehicleDef = GarageModel.build(hilux, turbo_cfg)
	var fuel_build: VehicleDef = GarageModel.build(hilux, fuel_cfg)
	print("turbo only  : %.0f kW / %.0f Nm  fuel_limited=%s" % [turbo_build.peak_power_kw(), turbo_build.peak_torque_nm(), str(turbo_build.engine_build.fuel_limited)])
	print("turbo + fuel: %.0f kW / %.0f Nm  fuel_limited=%s" % [fuel_build.peak_power_kw(), fuel_build.peak_torque_nm(), str(fuel_build.engine_build.fuel_limited)])
	if fuel_build.peak_power_kw() <= turbo_build.peak_power_kw():
		print("  FAIL fuel system did not unlock power")
		failures += 1

	# Thermal: sustained full-power climb, stock radiator vs race radiator.
	var hot_cfg: Dictionary = fuel_cfg.duplicate(true)
	hot_cfg["parts"][str(int(PartDef.Slot.RADIATOR))] = "hilux_an120_rad_s"
	var hot: VehicleDef = GarageModel.build(hilux, hot_cfg)
	var cold_cfg: Dictionary = fuel_cfg.duplicate(true)
	cold_cfg["parts"][str(int(PartDef.Slot.RADIATOR))] = "hilux_an120_rad_race"
	var cold: VehicleDef = GarageModel.build(hilux, cold_cfg)
	var t_hot: float = _climb_temp(hot.engine_build, 180.0)
	var t_cold: float = _climb_temp(cold.engine_build, 180.0)
	print("climb 180 s at full power: stock radiator %.1f °C, race radiator %.1f °C" % [t_hot, t_cold])
	if t_hot <= t_cold:
		print("  FAIL radiator comparison")
		failures += 1

	# Dyno sanity.
	var pull: Dictionary = DynoModel.pull(stock_build.engine_build, 1.443, 3.583, 0.3876, 0.9)
	print("dyno stock hilux: peak %.0f kW @ %.0f, %.0f Nm @ %.0f, points %d" % [
		pull["peak_power_kw"], pull["peak_power_rpm"], pull["peak_torque_nm"], pull["peak_torque_rpm"],
		(pull["rpm"] as PackedFloat32Array).size()])

	# Save migration on an in-memory legacy profile.
	var legacy: Dictionary = {
		"version": 4, "credits": 1234, "xp": 90, "selected_vehicle": "ranger_4x4",
		"owned_vehicles": ["rocky_buggy", "ranger_4x4"],
		"records": {"canyon_01": {"best_time": 61.5, "medal": 2, "attempts": 3, "completed": true}},
		"upgrades": {"ranger_4x4": ["engine_1", "gearbox_1"]},
		"config": {"ranger_4x4": {"transfer": "4H", "diff": "lsd"}},
	}
	var migrated: Dictionary = SaveManager._migrate(legacy, 4)
	print("migrated: credits=%d selected=%s owned=%s records=%s parts=%s" % [
		int(migrated["credits"]), String(migrated["selected_vehicle"]),
		str(migrated["owned_vehicles"]), str((migrated["records"] as Dictionary).keys()),
		str((migrated["garage"]["hilux_an120"] as Dictionary)["owned"])])
	if int(migrated["credits"]) != 1234:
		print("  FAIL credits lost")
		failures += 1

	print("=== smoke %s ===" % ("FAILED" if failures > 0 else "OK"))
	get_tree().quit(1 if failures > 0 else 0)

func _climb_temp(build: EngineBuild, seconds: float) -> float:
	var thermal := ThermalState.new()
	thermal.setup(build, 28.0)
	var dt: float = 0.1
	var t: float = 0.0
	while t < seconds:
		var power: float = build.peak_power_kw * thermal.power_derate()
		thermal.update(dt, power, 6.0, 1.0)
		t += dt
	return thermal.coolant_temp_c
