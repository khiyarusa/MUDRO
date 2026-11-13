class_name GarageModel
extends RefCounted
## Applies owned upgrades to a deep copy of a VehicleDef. Every modifier changes
## simulation data: torque curves, ratios, spring rates, grip, mass, brakes.

static func build(base: VehicleDef, owned: Array) -> VehicleDef:
	var def: VehicleDef = base.duplicate_def()
	if owned.is_empty():
		return def

	for upgrade_id: String in owned:
		var up: UpgradeDef = Content.upgrade_by_id(upgrade_id)
		if up == null:
			continue
		_apply(def, up)
	return def

static func _apply(def: VehicleDef, up: UpgradeDef) -> void:
	if up.torque_mult != 1.0 and def.engine != null:
		var curve: PackedFloat32Array = def.engine.curve_torque
		for i: int in range(curve.size()):
			curve[i] = curve[i] * up.torque_mult
		def.engine.curve_torque = curve
	if up.redline_add != 0.0 and def.engine != null:
		def.engine.redline_rpm += up.redline_add
		def.engine.max_rpm = maxf(def.engine.max_rpm, def.engine.redline_rpm + 200.0)
	if up.gear_ratio_mult != 1.0 and def.gearbox != null:
		var ratios: PackedFloat32Array = def.gearbox.ratios
		for i: int in range(ratios.size()):
			ratios[i] = ratios[i] * up.gear_ratio_mult
		def.gearbox.ratios = ratios
		def.gearbox.reverse_ratio *= up.gear_ratio_mult
	if up.final_drive_mult != 1.0 and def.gearbox != null:
		def.gearbox.final_drive *= up.final_drive_mult
	if up.shift_time_mult != 1.0 and def.gearbox != null:
		def.gearbox.shift_time = maxf(0.06, def.gearbox.shift_time * up.shift_time_mult)
	if up.grip_mult != 1.0:
		if def.tire_front != null:
			def.tire_front.mu_scale *= up.grip_mult
		if def.tire_rear != null:
			def.tire_rear.mu_scale *= up.grip_mult
	if up.spring_mult != 1.0 and def.suspension != null:
		def.suspension.spring_front *= up.spring_mult
		def.suspension.spring_rear *= up.spring_mult
	if up.damper_mult != 1.0 and def.suspension != null:
		def.suspension.damper_compression_front *= up.damper_mult
		def.suspension.damper_rebound_front *= up.damper_mult
		def.suspension.damper_compression_rear *= up.damper_mult
		def.suspension.damper_rebound_rear *= up.damper_mult
	if up.travel_mult != 1.0 and def.suspension != null:
		def.suspension.travel_m *= up.travel_mult
		def.suspension.droop_m *= lerpf(1.0, up.travel_mult, 0.5)
	if up.rolling_mult != 1.0:
		if def.tire_front != null:
			def.tire_front.rolling_resistance *= up.rolling_mult
		if def.tire_rear != null:
			def.tire_rear.rolling_resistance *= up.rolling_mult
	if up.brake_mult != 1.0:
		def.brake_torque_front *= up.brake_mult
		def.brake_torque_rear *= up.brake_mult
	if up.mass_add != 0.0:
		def.mass_kg = maxf(250.0, def.mass_kg + up.mass_add)
	if up.durability_mult != 1.0:
		def.durability *= up.durability_mult
	if up.clutch_mult != 1.0:
		def.clutch_capacity *= up.clutch_mult

static func owned_for(vehicle_id: String) -> Array:
	return SaveManager.vehicle_upgrades(vehicle_id)
