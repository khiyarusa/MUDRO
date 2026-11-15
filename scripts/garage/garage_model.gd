class_name GarageModel
extends RefCounted
## Turns a saved garage configuration into the exact VehicleDef the simulation
## drives. This is the only place where parts become physics.
##
## The authored `Content` resources are never mutated: every build starts from a
## deep copy, then the engine, gearbox, suspension, tyres, brakes, mass, centre of
## mass and aero are rebuilt from the fitted parts. `build_info` records what the
## build produced so the garage, the dyno and the tests all read the same numbers.

static func slot_key(slot: int) -> String:
	return str(slot)

static func empty_config() -> Dictionary:
	return {"parts": {}, "condition": {}, "presets": {}, "transfer": "", "diff": ""}

## Repairs a stored config: unknown part ids are dropped, every slot ends up with a
## legal part, conditions are clamped. A corrupt profile can never produce a car
## that cannot drive.
static func sanitize_config(base: VehicleDef, stored: Dictionary) -> Dictionary:
	var cfg: Dictionary = empty_config()
	if base == null:
		return cfg
	var raw_parts: Dictionary = stored.get("parts", {}) if stored.get("parts", {}) is Dictionary else {}
	var parts: Dictionary = {}
	for slot: int in all_slots():
		var wanted: String = String(raw_parts.get(str(slot), ""))
		var part: PartDef = null
		if not wanted.is_empty():
			part = Content.part_by_id(wanted)
		if part == null or part.slot != slot or not part.fits_vehicle(base.id, base.engine_family):
			part = Content.stock_part(base.id, slot)
		if part != null:
			parts[str(slot)] = part.id
	cfg["parts"] = parts
	var raw_cond: Dictionary = stored.get("condition", {}) if stored.get("condition", {}) is Dictionary else {}
	var cond: Dictionary = {}
	for pid: String in raw_cond.keys():
		cond[pid] = clampi(int(raw_cond[pid]), 0, 4)
	cfg["condition"] = cond
	cfg["transfer"] = String(stored.get("transfer", ""))
	cfg["diff"] = String(stored.get("diff", ""))
	var presets: Dictionary = stored.get("presets", {}) if stored.get("presets", {}) is Dictionary else {}
	cfg["presets"] = presets.duplicate(true)
	return cfg

static func all_slots() -> Array[int]:
	var out: Array[int] = []
	for slot: int in range(int(PartDef.Slot.BLOCK), int(PartDef.Slot.RIMS) + 1):
		out.append(slot)
	return out

static func resolve_parts(base: VehicleDef, cfg: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var stored: Dictionary = cfg.get("parts", {}) if cfg.get("parts", {}) is Dictionary else {}
	for slot: int in all_slots():
		var part: PartDef = null
		var wanted: String = String(stored.get(str(slot), ""))
		if not wanted.is_empty():
			part = Content.part_by_id(wanted)
		if part == null or part.slot != slot or not part.fits_vehicle(base.id, base.engine_family):
			part = Content.stock_part(base.id, slot)
		if part != null:
			out[slot] = part
	return out

static func part_at(base: VehicleDef, cfg: Dictionary, slot: int) -> PartDef:
	var stored: Dictionary = cfg.get("parts", {}) if cfg.get("parts", {}) is Dictionary else {}
	var wanted: String = String(stored.get(str(slot), ""))
	var part: PartDef = Content.part_by_id(wanted) if not wanted.is_empty() else null
	if part == null or part.slot != slot or not part.fits_vehicle(base.id, base.engine_family):
		return Content.stock_part(base.id, slot)
	return part

static func condition_of(cfg: Dictionary, part_id: String) -> int:
	var cond: Dictionary = cfg.get("condition", {}) if cfg.get("condition", {}) is Dictionary else {}
	return clampi(int(cond.get(part_id, 0)), 0, 4)

# --------------------------------------------------------------------- build ---

static func build(base: VehicleDef, config: Dictionary) -> VehicleDef:
	if base == null:
		return null
	var cfg: Dictionary = sanitize_config(base, config)
	var v: VehicleDef = base.duplicate_def()
	var parts: Dictionary = resolve_parts(base, cfg)
	v.parts = parts
	# Publish every fitted part's condition so downstream systems (clutch capacity,
	# tyre grip, radiator duty) read the wear the player sees in the workshop.
	var conditions_out: Dictionary = {}
	for slot_key: Variant in parts.keys():
		var fitted: PartDef = parts[slot_key] as PartDef
		if fitted != null:
			conditions_out[fitted.id] = condition_of(cfg, fitted.id)
	v.part_conditions = conditions_out
	var build: EngineBuild = EngineBuild.derive(_engine_spec(base), _engine_part_map(parts))
	build.heat_kw_full = build.coolant_heat_kw(build.peak_power_kw)
	v.engine_build = build
	v.engine = _engine_config(base, build, parts)

	var extra_mass: float = 0.0
	for slot: int in parts.keys():
		var p: PartDef = parts[slot] as PartDef
		if p != null:
			extra_mass += p.mass_kg
	v.extra_mass_kg = extra_mass
	v.mass_kg = maxf(base.mass_kg + extra_mass, base.mass_kg * 0.6)

	# --- transmission -------------------------------------------------------
	# Two ways to choose a gearbox and both must work: the workshop fits a part, and
	# the route briefing picks one of the car's documented transmissions. A non-stock
	# part is the more specific, more recent choice, so it wins; otherwise the
	# catalogue pick is honoured (it used to be written by the UI and never read, so
	# every factory automatic in the catalogue was dead data).
	var gbox: PartDef = parts.get(PartDef.Slot.GEARBOX, null) as PartDef
	var wanted_trans: String = String(cfg.get("transmission", ""))
	var catalogue: TransmissionProfile = null
	if not wanted_trans.is_empty():
		catalogue = base.transmission_by_id(wanted_trans)
	var profile: TransmissionProfile = null
	if gbox != null and gbox.tier > 0:
		profile = _profile_from_part(base, gbox)
	elif catalogue != null:
		profile = catalogue.duplicate_profile()
	elif gbox != null:
		profile = _profile_from_part(base, gbox)
	if profile != null:
		v.transmissions = [profile]
		v.stock_transmission = profile.id
		v.fitted_transmission = profile.id
		var g := GearboxConfig.new()
		g.display_name = profile.name_en
		g.ratios = profile.ratios
		g.reverse_ratio = profile.reverse_ratio
		g.final_drive = profile.final_drive
		g.efficiency = profile.efficiency
		g.shift_time = profile.shift_time
		v.gearbox = g
		v.clutch_capacity = profile.max_torque_nm * 1.05

	var clutch: PartDef = parts.get(PartDef.Slot.CLUTCH, null) as PartDef
	if clutch != null:
		v.clutch_capacity = clutch.num("capacity_nm", v.clutch_capacity)
		v.clutch_bite_point = clutch.num("bite_point", v.clutch_bite_point)
		if v.transmissions.size() > 0:
			v.transmissions[0].clutch_type = clutch.text("type", "single_plate")

	var tcase: PartDef = parts.get(PartDef.Slot.TRANSFER, null) as PartDef
	if tcase != null:
		var ids := tcase.strings("ids")
		if not ids.is_empty():
			v.transfer_ids = ids
			v.transfer_ratios = tcase.floats("ratios")
			if v.transfer_ids.size() > 1:
				v.default_transfer = v.transfer_ids[mini(1, v.transfer_ids.size() - 1)]
			else:
				v.default_transfer = v.transfer_ids[0]

	var diff: PartDef = parts.get(PartDef.Slot.DIFFERENTIAL, null) as PartDef
	if diff != null:
		var mode: String = diff.text("mode", "open")
		if not base.diff_modes.is_empty() and not base.diff_modes.has(mode):
			mode = base.diff_modes[0]
		v.default_diff = mode
		v.active_diff = String(cfg.get("diff", mode))
	var wanted_transfer: String = String(cfg.get("transfer", ""))
	if not wanted_transfer.is_empty() and v.transfer_ids.has(wanted_transfer):
		v.default_transfer = wanted_transfer

	# --- suspension ---------------------------------------------------------
	var susp: SuspensionConfig = (base.suspension.duplicate(true) as SuspensionConfig)
	var spring: PartDef = parts.get(PartDef.Slot.SPRINGS, null) as PartDef
	var damper: PartDef = parts.get(PartDef.Slot.DAMPERS, null) as PartDef
	var bump: PartDef = parts.get(PartDef.Slot.BUMP_STOPS, null) as PartDef
	var arms: PartDef = parts.get(PartDef.Slot.ARMS, null) as PartDef
	var lift: PartDef = parts.get(PartDef.Slot.LIFT_KIT, null) as PartDef
	if spring != null:
		var sm: float = spring.num("spring_mult", 1.0)
		susp.spring_front *= sm
		susp.spring_rear *= sm
		susp.rest_length_m *= spring.num("ride_mult", 1.0)
	if damper != null:
		susp.damper_compression_front *= damper.num("compression_mult", 1.0)
		susp.damper_compression_rear *= damper.num("compression_mult", 1.0)
		susp.damper_rebound_front *= damper.num("rebound_mult", 1.0)
		susp.damper_rebound_rear *= damper.num("rebound_mult", 1.0)
	if bump != null:
		susp.bump_stop_rate *= bump.num("rate_mult", 1.0)
	if arms != null:
		susp.travel_m *= arms.num("travel_mult", 1.0)
	if lift != null:
		susp.rest_length_m += lift.num("ride_add_m", 0.0)
		susp.travel_m *= lift.num("travel_mult", 1.0)
		v.ride_height_add_m = lift.num("ride_add_m", 0.0)
		v.lift_com_add_m = lift.num("com_add_m", 0.0)
	v.suspension = susp

	# --- tyres --------------------------------------------------------------
	var tyre: PartDef = parts.get(PartDef.Slot.TYRES, null) as PartDef
	if tyre != null:
		v.tire_front = _tire_from_part(tyre, base.tire_front)
		v.tire_rear = _tire_from_part(tyre, base.tire_rear)
		v.fitted_tires = tyre.id
		# A worn tyre is a real grip loss, not a label: condition is the same number
		# the repair shop shows, applied here to the contact model.
		var tyre_wear: float = float(PartDef.CONDITION_MULT.get(condition_of(cfg, tyre.id), 1.0))
		v.tire_front.mu_scale = base.tire_front.mu_scale * maxf(tyre_wear, 0.15)
		v.tire_rear.mu_scale = base.tire_rear.mu_scale * maxf(tyre_wear, 0.15)
		v.tire_front.rolling_resistance = lerpf(base.tire_front.rolling_resistance, 0.075, 1.0 - tyre_wear)
		v.tire_rear.rolling_resistance = lerpf(base.tire_rear.rolling_resistance, 0.075, 1.0 - tyre_wear)
	var rim: PartDef = parts.get(PartDef.Slot.RIMS, null) as PartDef
	if rim != null:
		var rim_mass: float = rim.num("mass_add", 0.0)
		v.tire_front.wheel_mass_kg = maxf(v.tire_front.wheel_mass_kg + rim_mass, 8.0)
		v.tire_rear.wheel_mass_kg = maxf(v.tire_rear.wheel_mass_kg + rim_mass, 8.0)

	# --- brakes -------------------------------------------------------------
	var pads: PartDef = parts.get(PartDef.Slot.BRAKE_PADS, null) as PartDef
	var discs: PartDef = parts.get(PartDef.Slot.BRAKE_DISCS, null) as PartDef
	var brake_mult: float = 1.0
	if pads != null:
		brake_mult *= pads.num("brake_mult", 1.0)
	if discs != null:
		brake_mult *= discs.num("brake_mult", 1.0)
	v.brake_torque_front = base.brake_torque_front * brake_mult
	v.brake_torque_rear = base.brake_torque_rear * brake_mult

	# --- body, protection and aero -----------------------------------------
	var drag_mult: float = 1.0
	var durability_mult: float = 1.0
	var protection: float = 0.0
	var com_add: float = 0.0
	for slot: int in [PartDef.Slot.BUMPER_FRONT, PartDef.Slot.BUMPER_REAR]:
		var p: PartDef = parts.get(slot, null) as PartDef
		if p != null:
			drag_mult *= p.num("drag_mult", 1.0)
			durability_mult *= p.num("durability_mult", 1.0)
			protection += p.num("protection", 0.0)
	var rack: PartDef = parts.get(PartDef.Slot.ROOF_RACK, null) as PartDef
	if rack != null:
		com_add += rack.num("com_add_m", 0.0)
	var cage: PartDef = parts.get(PartDef.Slot.ROLL_CAGE, null) as PartDef
	if cage != null:
		durability_mult *= cage.num("durability_mult", 1.0)
	var skid: PartDef = parts.get(PartDef.Slot.SKID_PLATE, null) as PartDef
	if skid != null:
		protection += skid.num("protection", 0.0)
	var sliders: PartDef = parts.get(PartDef.Slot.SLIDERS, null) as PartDef
	if sliders != null:
		protection += sliders.num("protection", 0.0)
	v.drag_cd = base.drag_cd * drag_mult
	v.durability = base.durability * durability_mult
	v.protection = protection
	v.com_height_m = base.com_height_m + v.lift_com_add_m + com_add
	v.frontal_area_m2 = base.frontal_area_m2 + (0.0 if rack == null else 0.08)

	var winch: PartDef = parts.get(PartDef.Slot.WINCH, null) as PartDef
	if winch != null and winch.num("force_n", 0.0) > 0.0:
		v.has_winch = true
		v.winch_force_n = winch.num("force_n")
		v.winch_rope_m = winch.num("rope_m", 20.0)
	else:
		v.has_winch = false
	var snorkel: PartDef = parts.get(PartDef.Slot.SNORKEL, null) as PartDef
	v.water_ford_m = 0.4 if snorkel == null else snorkel.num("water_ford_m", 0.4)
	var lights: PartDef = parts.get(PartDef.Slot.LIGHTS, null) as PartDef
	v.light_range_m = 40.0 if lights == null else lights.num("range_m", 40.0)
	v.active_winch = v.has_winch

	v.build_info = _build_info(base, v, build, parts, cfg)
	return v

static func _engine_spec(base: VehicleDef) -> Dictionary:
	return {
		"family": base.engine_family,
		"cylinders": base.cylinders,
		"aspiration": base.aspiration,
		"fuel": "petrol" if base.aspiration.begins_with("na") and base.fuel_type == "petrol" else "diesel",
		"displacement_l": float(base.displacement_cc) / 1000.0,
		"compression": base.compression,
		"redline_rpm": base.engine.redline_rpm,
		"idle_rpm": base.engine.idle_rpm,
		"torque_rpm": base.doc_torque_rpm,
		"hold_rpm": base.engine_hold_rpm,
		"inertia": base.engine.inertia,
		"friction": base.engine.friction_torque,
		"efficiency": 0.29 if base.aspiration == "na" else 0.35,
		"torque_scale": base.engine_torque_scale,
	}

static func _engine_part_map(parts: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for slot: int in range(int(PartDef.Slot.BLOCK), int(PartDef.Slot.THERMOSTAT) + 1):
		if parts.has(slot):
			out[slot] = parts[slot]
	return out

static func _engine_config(base: VehicleDef, build: EngineBuild, parts: Dictionary) -> EngineConfig:
	var e: EngineConfig = (base.engine.duplicate(true) as EngineConfig)
	e.display_name = base.engine_code
	e.idle_rpm = build.idle_rpm
	e.redline_rpm = build.redline_rpm - 100.0
	e.max_rpm = build.redline_rpm
	e.stall_rpm = maxf(320.0, build.idle_rpm * 0.46)
	e.inertia = build.inertia
	e.friction_torque = build.friction_torque
	var rpms := PackedFloat32Array()
	var torques := PackedFloat32Array()
	var points: int = 14
	for i: int in range(points):
		var rpm: float = build.idle_rpm + (build.redline_rpm - build.idle_rpm) * float(i) / float(points - 1)
		rpms.append(rpm)
		torques.append(maxf(build.torque_at(rpm), 1.0))
	e.curve_rpm = rpms
	e.curve_torque = torques
	var ecu: PartDef = parts.get(PartDef.Slot.ECU, null) as PartDef
	e.throttle_response = 7.5 * (1.0 if ecu == null else ecu.num("throttle_response", 1.0))
	e.turbo_gain = 0.0
	e.turbo_rpm = build.peak_torque_rpm
	e.turbo_width = 1500.0
	if build.boost_bar > 0.01:
		e.turbo_gain = clampf(build.boost_bar * 0.16, 0.05, 0.28)
		var turbo: PartDef = parts.get(PartDef.Slot.TURBO, null) as PartDef
		e.turbo_rpm = build.peak_torque_rpm * 0.62
		e.turbo_width = 1900.0 if turbo == null else clampf(build.peak_torque_rpm * 1.1, 900.0, 2600.0)
		# `build.torque_at()` already contains the turbo's steady-state boost. If the
		# engine model then multiplied it by (1 + turbo_gain) the car made 480 Nm
		# while the dyno reported 420. Divide the curve back to its naturally
		# aspirated shape here, so full boost reproduces the authored curve exactly
		# and the spool is a real deficit instead of a second helping of torque.
		for i: int in range(e.curve_torque.size()):
			var band: float = clampf(1.0 - absf(e.curve_rpm[i] - e.turbo_rpm) / maxf(e.turbo_width, 1.0), 0.0, 1.0)
			e.curve_torque[i] = e.curve_torque[i] / (1.0 + e.turbo_gain * band)
	return e

static func _profile_from_part(base: VehicleDef, part: PartDef) -> TransmissionProfile:
	var t := TransmissionProfile.new()
	t.id = part.id
	t.name_fa = part.name_fa
	t.name_en = part.name_en
	t.ratios = part.floats("ratios")
	if t.ratios.is_empty():
		t.ratios = base.gearbox.ratios if base.gearbox != null else PackedFloat32Array([3.5, 2.0, 1.4, 1.0])
	t.reverse_ratio = part.num("reverse_ratio", 3.6)
	t.final_drive = part.num("final_drive", 3.9)
	t.efficiency = part.num("efficiency", 0.9)
	t.shift_time = part.num("shift_time", 0.3)
	t.max_torque_nm = part.num("max_torque_nm", 500.0)
	t.kind = int(part.num("kind", TransmissionProfile.Kind.MANUAL_H))
	# Only an H-pattern box needs the pedal. A sequential dog box shifts on the
	# throttle, and an automatic has a converter: arming a clutch interlock (and a
	# stall the driver has no control to prevent) on either was the single worst
	# data bug in the 3.1 build — a converted car demanded a pedal it cannot show.
	t.requires_clutch = t.kind == TransmissionProfile.Kind.MANUAL_H
	t.ranges = PackedStringArray(["P", "R", "N", "D", "L"]) if t.kind == TransmissionProfile.Kind.AUTOMATIC else PackedStringArray()
	if t.kind == TransmissionProfile.Kind.AUTOMATIC:
		# Where the catalogue documents a factory automatic, the conversion carries
		# its real ratios, final drive and shift time instead of a generic set.
		for candidate: TransmissionProfile in base.transmission_options():
			if candidate.kind != TransmissionProfile.Kind.AUTOMATIC:
				continue
			if candidate.ratios.size() != t.ratios.size():
				continue
			t.ratios = candidate.ratios
			t.reverse_ratio = candidate.reverse_ratio
			t.final_drive = candidate.final_drive
			t.efficiency = candidate.efficiency
			t.shift_time = candidate.shift_time
			t.max_torque_nm = maxf(t.max_torque_nm, candidate.max_torque_nm)
			break
	if t.kind == TransmissionProfile.Kind.AUTOMATIC:
		t.clutch_type = "torque_converter"
		t.converter_stall_mult = 1.9
		t.converter_lock_rpm = 1400.0
		t.auto_upshift_fraction = 0.68
		t.auto_downshift_fraction = 0.30
		t.kickdown_rpm_fraction = 0.55
	return t

static func _tire_from_part(part: PartDef, fallback: TireConfig) -> TireConfig:
	var t: TireConfig = fallback.duplicate(true) as TireConfig
	t.radius_m = part.num("radius_m", fallback.radius_m)
	t.width_m = part.num("width_m", fallback.width_m)
	t.mu_scale = part.num("mu_peak", 1.0)
	t.rolling_resistance = part.num("rr", fallback.rolling_resistance)
	t.peak_slip = part.num("peak_slip", fallback.peak_slip)
	t.surface_bonus = (part.params.get("surface_bonus", {}) as Dictionary).duplicate(true)
	t.pressure_bar = part.num("pressure_bar", 2.1)
	t.compound = part.text("compound", "at")
	return t

static func _build_info(base: VehicleDef, v: VehicleDef, build: EngineBuild,
		parts: Dictionary, _cfg: Dictionary) -> Dictionary:
	var gearbox: PartDef = parts.get(PartDef.Slot.GEARBOX, null) as PartDef
	return {
		"vehicle": base.id,
		"power_kw": build.peak_power_kw,
		"power_hp": build.peak_power_kw * 1.341,
		"torque_nm": build.peak_torque_nm,
		"power_rpm": build.peak_power_rpm,
		"torque_rpm": build.peak_torque_rpm,
		"boost_bar": build.boost_bar,
		"redline_rpm": build.redline_rpm,
		"fuel_limit_kw": build.fuel_limit_kw,
		"radiator_kw": build.radiator_kw,
		"coolant_l": build.coolant_l,
		"flow_mult": build.flow_mult,
		"density_ratio": build.density_ratio,
		"charge_temp_c": build.charge_temp_c,
		"mass_kg": v.mass_kg,
		"extra_mass_kg": v.extra_mass_kg,
		"drag_cd": v.drag_cd,
		"ride_height_add_m": v.ride_height_add_m,
		"gearbox": gearbox.id if gearbox != null else "",
		"warnings": build.warnings.duplicate(true),
		"fuel_limited": build.fuel_limited,
		"cooling_marginal": build.cooling_marginal,
	}

static func stock_build(base: VehicleDef) -> VehicleDef:
	return build(base, empty_config())

## Fitted-part list for the garage UI, ordered by slot.
static func fitted_list(base: VehicleDef, cfg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: int in all_slots():
		var part: PartDef = part_at(base, cfg, slot)
		if part == null:
			continue
		out.append({
			"slot": slot,
			"part": part,
			"condition": condition_of(cfg, part.id),
			"is_stock": part.tier == 0,
		})
	return out
