class_name GarageModel
extends RefCounted
## Applies owned upgrades and the chosen driveline configuration to a deep copy of
## a VehicleDef. Every modifier changes simulation data: torque curves, ratios,
## spring rates, grip, mass, brakes, transfer case, differential.
##
## The garage never edits the shared Content resources, so a bad configuration can
## not leak into the next race.

static func build(base: VehicleDef, owned: Array, config: Dictionary = {}) -> VehicleDef:
	var def: VehicleDef = base.duplicate_def()
	for upgrade_id: String in owned:
		var up: UpgradeDef = Content.upgrade_by_id(upgrade_id)
		if up == null:
			continue
		_apply_upgrade(def, up)
	_apply_config(def, config)
	return def

## Defaults for a vehicle that the player has never configured.
static func default_config(def: VehicleDef) -> Dictionary:
	if def == null:
		return {}
	var trans: TransmissionProfile = def.stock_transmission_profile()
	return {
		"transmission": trans.id if trans != null else "",
		"transfer": def.default_transfer if def.default_transfer != "" else (def.transfer_ids[0] if def.transfer_ids.size() > 0 else ""),
		"diff": def.default_diff,
		"tires": String((def.tire_options[0] as Dictionary).get("id", "")) if def.tire_options.size() > 0 else "",
		"suspension": String((def.suspension_options[0] as Dictionary).get("id", "")) if def.suspension_options.size() > 0 else "",
		"winch": def.has_winch,
	}

## Merge a stored config with the vehicle's legal defaults and drop anything the
## vehicle does not actually offer.
static func sanitize_config(def: VehicleDef, config: Dictionary) -> Dictionary:
	var out: Dictionary = default_config(def)
	if def == null:
		return out
	for key: String in config.keys():
		out[key] = config[key]
	if def.transmission_by_id(String(out.get("transmission", ""))) == null:
		out["transmission"] = default_config(def)["transmission"]
	if not def.transfer_ids.has(String(out.get("transfer", ""))):
		out["transfer"] = out["transfer"] if def.transfer_ids.size() == 0 else def.transfer_ids[0]
	if not def.diff_modes.has(String(out.get("diff", ""))):
		out["diff"] = def.default_diff
	if not def.tire_option_by_id(String(out.get("tires", ""))).is_empty():
		pass
	elif def.tire_options.size() > 0:
		out["tires"] = String((def.tire_options[0] as Dictionary).get("id", ""))
	if def.suspension_option_by_id(String(out.get("suspension", ""))).is_empty() and def.suspension_options.size() > 0:
		out["suspension"] = String((def.suspension_options[0] as Dictionary).get("id", ""))
	out["winch"] = bool(out.get("winch", def.has_winch)) and def.has_winch
	return out

static func _apply_config(def: VehicleDef, config: Dictionary) -> void:
	if config.is_empty():
		return
	var cfg: Dictionary = sanitize_config(def, config)
	def.fitted_transmission = String(cfg.get("transmission", ""))
	def.active_transfer = String(cfg.get("transfer", ""))
	def.active_diff = String(cfg.get("diff", ""))
	def.fitted_tires = String(cfg.get("tires", ""))
	def.fitted_suspension = String(cfg.get("suspension", ""))
	def.active_winch = bool(cfg.get("winch", def.has_winch))

	var tire: Dictionary = def.tire_option_by_id(def.fitted_tires)
	if not tire.is_empty():
		var mu: float = float(tire.get("mu_mult", 1.0))
		var rr: float = float(tire.get("rr_mult", 1.0))
		if def.tire_front != null:
			def.tire_front.mu_scale *= mu
			def.tire_front.rolling_resistance *= rr
		if def.tire_rear != null:
			def.tire_rear.mu_scale *= mu
			def.tire_rear.rolling_resistance *= rr

	var susp: Dictionary = def.suspension_option_by_id(def.fitted_suspension)
	if not susp.is_empty() and def.suspension != null:
		def.suspension.spring_front *= float(susp.get("spring_mult", 1.0))
		def.suspension.spring_rear *= float(susp.get("spring_mult", 1.0))
		def.suspension.damper_compression_front *= float(susp.get("damper_mult", 1.0))
		def.suspension.damper_rebound_front *= float(susp.get("damper_mult", 1.0))
		def.suspension.damper_compression_rear *= float(susp.get("damper_mult", 1.0))
		def.suspension.damper_rebound_rear *= float(susp.get("damper_mult", 1.0))
		def.suspension.travel_m *= float(susp.get("travel_mult", 1.0))
		def.suspension.rest_length_m *= float(susp.get("ride_mult", 1.0))
		if def.suspension.rest_length_m > def.suspension.travel_m + 0.05:
			def.suspension.travel_m = def.suspension.rest_length_m

static func _apply_upgrade(def: VehicleDef, up: UpgradeDef) -> void:
	if up.torque_mult != 1.0 and def.engine != null:
		var curve: PackedFloat32Array = def.engine.curve_torque
		for i: int in range(curve.size()):
			curve[i] = curve[i] * up.torque_mult
		def.engine.curve_torque = curve
	if up.redline_add != 0.0 and def.engine != null:
		def.engine.redline_rpm += up.redline_add
		def.engine.max_rpm = maxf(def.engine.max_rpm, def.engine.redline_rpm + 200.0)
	if up.gear_ratio_mult != 1.0:
		for t: TransmissionProfile in def.transmissions:
			for i: int in range(t.ratios.size()):
				t.ratios[i] = t.ratios[i] * up.gear_ratio_mult
			t.reverse_ratio *= up.gear_ratio_mult
		if def.gearbox != null:
			var ratios: PackedFloat32Array = def.gearbox.ratios
			for i: int in range(ratios.size()):
				ratios[i] = ratios[i] * up.gear_ratio_mult
			def.gearbox.ratios = ratios
			def.gearbox.reverse_ratio *= up.gear_ratio_mult
	if up.final_drive_mult != 1.0:
		for t: TransmissionProfile in def.transmissions:
			t.final_drive *= up.final_drive_mult
		if def.gearbox != null:
			def.gearbox.final_drive *= up.final_drive_mult
	if up.shift_time_mult != 1.0:
		for t: TransmissionProfile in def.transmissions:
			t.shift_time = maxf(0.06, t.shift_time * up.shift_time_mult)
		if def.gearbox != null:
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
