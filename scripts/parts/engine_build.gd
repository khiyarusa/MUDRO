class_name EngineBuild
extends RefCounted
## Derives a complete, physically-consistent engine from the fitted parts.
##
## The model is deliberately simple but *causal*: air flow sets how much fuel can
## be burned, boost and charge temperature set air density, the fuel system caps
## power, and the rev limit is the lowest limit any internal part can survive.
## Fitting a bigger turbo therefore does nothing until the injectors, pump and
## intercooler can support it — which is the whole point of a tuning system.
##
##     density  = (1 + boost / 1.013) * 298.15 / (273.15 + charge_temp)
##     torque   = k * displacement * density * volumetric_efficiency * fuel_map
##     power    = torque * rpm * TAU / 60
##
## The constant k is calibrated once against the stock Land Cruiser 1VD-FTV
## (4.5 L, 1.1 bar, 430 Nm) so every other engine follows from its own data.

const TORQUE_K: float = 92.0
const AMBIENT_C: float = 25.0
const AFR_STOICH: float = 14.5

var family: String = ""
var displacement_l: float = 2.8
var cylinders: int = 4
var aspiration: String = "turbo_diesel"
var fuel: String = "diesel"

var flow_mult: float = 1.0
var boost_bar: float = 0.0
var charge_temp_c: float = 30.0
var density_ratio: float = 1.0
var volumetric_efficiency: float = 0.9

var peak_torque_nm: float = 0.0
var peak_torque_rpm: float = 2000.0
var peak_power_kw: float = 0.0
var peak_power_rpm: float = 3800.0
var redline_rpm: float = 4500.0
var idle_rpm: float = 750.0
var inertia: float = 0.3
var friction_torque: float = 20.0

var fuel_limit_kw: float = 999.0
var fuel_limited: bool = false
var block_limited: bool = false
var cooling_marginal: bool = false

var efficiency: float = 0.35
var heat_kw_full: float = 0.0
var radiator_kw: float = 60.0
var coolant_l: float = 8.0
var fan_mult: float = 1.0
var pump_mult: float = 1.0
var thermostat_c: float = 88.0

var mass_kg: float = 0.0
var warnings: Array[Dictionary] = []
## Normalised rpm at which the torque curve peaks (set from the documented torque
## rpm, so the curve's shape matches the real engine).
var peak_frac: float = 0.52
## Normalised rpm at which the torque plateau ends and the curve starts to fall.
## Real engines publish their torque as a band (e.g. "420 Nm @ 1400-3400 rpm"); the
## plateau must hold that band, otherwise a 420 Nm engine appears to lose power
## long before its published power peak.
var plateau_frac: float = 0.84

func redline_for_shape() -> float:
	return redline_rpm if redline_rpm > 500.0 else 4500.0

func torque_at(rpm: float) -> float:
	if rpm <= 0.0:
		return 0.0
	var x: float = clampf(rpm / maxf(redline_rpm, 500.0), 0.02, 1.05)
	# Real engines hold a torque plateau after the peak and only fall away near the
	# limiter. A plain curve would make a 420 Nm diesel feel like a 300 Nm one at
	# 3,000 rpm, which is neither realistic nor fun.
	var shape: float = 0.0
	var x_peak: float = clampf(peak_frac, 0.22, 0.88)
	var plateau_end: float = clampf(maxf(plateau_frac, x_peak), x_peak, 0.97)
	if plateau_end <= x_peak:
		plateau_end = minf(x_peak + 0.32, 0.96)
	if x < x_peak:
		var t: float = clampf(x / maxf(x_peak, 0.01), 0.0, 1.0)
		shape = 0.58 + 0.42 * pow(t, 0.65)
	elif x <= plateau_end:
		var t2: float = (x - x_peak) / maxf(plateau_end - x_peak, 0.01)
		shape = 1.0 - 0.04 * t2
	else:
		var t3: float = clampf((x - plateau_end) / maxf(1.02 - plateau_end, 0.02), 0.0, 1.2)
		shape = 0.96 - 0.86 * pow(t3, 1.5)
	shape = maxf(shape, 0.08)
	var spool: float = 1.0
	if aspiration.find("turbo") >= 0:
		var sp: float = maxf(peak_torque_rpm * 0.55, 900.0)
		spool = clampf(0.55 + 0.45 * (rpm - sp * 0.45) / maxf(sp * 0.55, 1.0), 0.52, 1.0)
	var torque: float = peak_torque_nm * shape * spool
	var power_cap_nm: float = fuel_limit_kw * 1000.0 / maxf(rpm * TAU / 60.0, 1.0)
	return minf(torque, power_cap_nm)

func power_kw_at(rpm: float) -> float:
	return torque_at(rpm) * rpm * TAU / 60.0 / 1000.0

func max_torque() -> float:
	var best: float = 0.0
	var rpm: float = idle_rpm
	while rpm <= redline_rpm:
		best = maxf(best, torque_at(rpm))
		rpm += 50.0
	return best

## Coolant heat load at a given output power, in kW. Roughly three quarters of the
## crank power ends up in the coolant on a sustained pull.
func coolant_heat_kw(power_kw: float) -> float:
	return maxf(power_kw, 0.0) * 0.75 + 6.0

func peak_boost_bar() -> float:
	return boost_bar

func summary() -> Dictionary:
	return {
		"displacement_l": displacement_l,
		"cylinders": cylinders,
		"aspiration": aspiration,
		"boost_bar": boost_bar,
		"peak_torque_nm": peak_torque_nm,
		"peak_power_kw": peak_power_kw,
		"redline_rpm": redline_rpm,
		"fuel_limit_kw": fuel_limit_kw,
		"radiator_kw": radiator_kw,
		"fuel_limited": fuel_limited,
		"block_limited": block_limited,
	}

# ---------------------------------------------------------------- derivation ---

## `spec` is the engine data of the vehicle, `parts` maps PartDef.Slot -> PartDef.
static func derive(spec: Dictionary, parts: Dictionary) -> EngineBuild:
	var b := EngineBuild.new()
	b.family = String(spec.get("family", ""))
	b.cylinders = int(spec.get("cylinders", 4))
	b.aspiration = String(spec.get("aspiration", "turbo_diesel"))
	b.fuel = String(spec.get("fuel", "diesel"))
	b.idle_rpm = float(spec.get("idle_rpm", 750.0))

	var stock_disp: float = float(spec.get("displacement_l", 2.8))
	var compression: float = float(spec.get("compression", 16.0))
	var base_efficiency: float = float(spec.get("efficiency", 0.35))

	var block: PartDef = _part(parts, PartDef.Slot.BLOCK)
	var crank: PartDef = _part(parts, PartDef.Slot.CRANKSHAFT)
	var pistons: PartDef = _part(parts, PartDef.Slot.PISTONS)
	var rods: PartDef = _part(parts, PartDef.Slot.CONRODS)
	var cam: PartDef = _part(parts, PartDef.Slot.CAMSHAFT)
	var head: PartDef = _part(parts, PartDef.Slot.HEAD)
	var intake: PartDef = _part(parts, PartDef.Slot.INTAKE)
	var throttle: PartDef = _part(parts, PartDef.Slot.THROTTLE)
	var exhaust: PartDef = _part(parts, PartDef.Slot.EXHAUST)
	var ecu: PartDef = _part(parts, PartDef.Slot.ECU)
	var turbo: PartDef = _part(parts, PartDef.Slot.TURBO)
	var intercooler: PartDef = _part(parts, PartDef.Slot.INTERCOOLER)
	var injectors: PartDef = _part(parts, PartDef.Slot.INJECTORS)
	var pump: PartDef = _part(parts, PartDef.Slot.FUEL_PUMP)
	var radiator: PartDef = _part(parts, PartDef.Slot.RADIATOR)
	var water_pump: PartDef = _part(parts, PartDef.Slot.WATER_PUMP)
	var fan: PartDef = _part(parts, PartDef.Slot.FAN)
	var thermostat: PartDef = _part(parts, PartDef.Slot.THERMOSTAT)

	b.displacement_l = stock_disp * (1.0 if block == null else block.num("displacement_mult", 1.0))
	b.displacement_l *= (1.0 if crank == null else crank.num("stroke_mult", 1.0))
	compression = (1.0 if pistons == null else pistons.num("compression", compression))
	base_efficiency = (1.0 if pistons == null else pistons.num("efficiency_mult", 1.0)) * base_efficiency

	var flow_head: float = 1.0 if head == null else head.num("flow_mult", 1.0)
	var flow_intake: float = 1.0 if intake == null else intake.num("flow_mult", 1.0)
	var flow_throttle: float = 1.0 if throttle == null else throttle.num("flow_mult", 1.0)
	var flow_exhaust: float = 1.0 if exhaust == null else exhaust.num("flow_mult", 1.0)
	var flow_cam: float = 1.0 if cam == null else cam.num("flow_mult", 1.0)
	b.flow_mult = minf(minf(flow_head, flow_intake), minf(flow_throttle, flow_exhaust * 0.97)) * flow_cam

	# Boost: the turbo can only make what the ECU asks for, and the block and
	# pistons can only survive what they were rated for. The lowest limit wins.
	var turbo_boost: float = 0.0 if turbo == null else turbo.num("boost_bar", 0.0)
	var ecu_target: float = turbo_boost if ecu == null else ecu.num("boost_target_bar", turbo_boost)
	var block_limit: float = 99.0 if block == null else block.num("max_boost_bar", 99.0)
	var piston_limit: float = 99.0 if pistons == null else pistons.num("max_boost_bar", 99.0)
	b.boost_bar = minf(minf(turbo_boost, ecu_target), minf(block_limit, piston_limit))
	if turbo_boost > 0.0 and b.boost_bar < turbo_boost - 0.001:
		b.block_limited = b.boost_bar >= minf(block_limit, piston_limit) - 0.001
		b.warnings.append(_warn(
			"فشار توربو به سقف تحمل بلوک/پیستون محدود شد.",
			"Boost is limited by the block/piston rating.",
			2))

	# Charge temperature: compressor heats the air, the intercooler removes a
	# fraction of that heat. No intercooler means hot, thin air and less torque.
	var compressor_rise_c: float = 38.0 + 95.0 * b.boost_bar
	var cooling: float = 0.0 if intercooler == null else clampf(intercooler.num("charge_cool", 0.0), 0.0, 0.92)
	b.charge_temp_c = AMBIENT_C + compressor_rise_c * (1.0 - cooling)
	b.density_ratio = (1.0 + b.boost_bar / 1.013) * (298.15 / (273.15 + b.charge_temp_c))
	if b.aspiration.begins_with("na"):
		b.density_ratio = 0.99
		b.charge_temp_c = AMBIENT_C + 6.0

	b.volumetric_efficiency = clampf(0.90 * b.flow_mult, 0.55, 1.32)
	var fuel_map: float = 1.0 if ecu == null else ecu.num("fuel_map", 1.0)
	b.efficiency = clampf(base_efficiency, 0.24, 0.44)

	b.peak_torque_nm = TORQUE_K * b.displacement_l * b.density_ratio * b.volumetric_efficiency * fuel_map
	b.peak_torque_nm *= float(spec.get("torque_scale", 1.0))
	# A diesel's torque peak sits low, a petrol engine's higher.
	var torque_frac: float = 0.52 if b.fuel == "diesel" else 0.66
	var base_redline: float = float(spec.get("redline_rpm", 4500.0))
	b.redline_rpm = base_redline
	if cam != null:
		b.redline_rpm = minf(b.redline_rpm + cam.num("rev_add", 0.0), cam.num("max_rpm", 99999.0))
	if head != null:
		b.redline_rpm = minf(b.redline_rpm, head.num("max_rpm", 99999.0))
	if crank != null:
		b.redline_rpm = minf(b.redline_rpm, crank.num("max_rpm", 99999.0))
	if pistons != null:
		b.redline_rpm = minf(b.redline_rpm, pistons.num("max_rpm", 99999.0))
	# Rods are the part that actually decides how many rpm the bottom end survives,
	# so a forged set has to raise the limit or fitting it would be decoration.
	if rods != null:
		b.redline_rpm = minf(b.redline_rpm, rods.num("max_rpm", 99999.0))
	if ecu != null:
		b.redline_rpm = minf(b.redline_rpm, ecu.num("rev_limit", 99999.0))
	b.redline_rpm = maxf(b.redline_rpm, 2200.0)
	b.peak_torque_rpm = b.redline_rpm * clampf(torque_frac, 0.25, 0.85)
	var wanted_torque_rpm: float = float(spec.get("torque_rpm", 0.0))
	if wanted_torque_rpm > 0.0:
		b.peak_torque_rpm = clampf(wanted_torque_rpm, b.idle_rpm * 1.5, b.redline_rpm * 0.92)
	b.peak_frac = clampf(b.peak_torque_rpm / b.redline_rpm, 0.22, 0.88)
	# Plateau end: the documented torque band when the data carries one, otherwise a
	# generic 0.32 of the rev range past the peak.
	var hold_rpm: float = float(spec.get("hold_rpm", 0.0))
	if hold_rpm > 0.0:
		b.plateau_frac = clampf(hold_rpm / maxf(b.redline_rpm, 1.0), b.peak_frac, 0.96)
	else:
		b.plateau_frac = minf(b.peak_frac + 0.32, 0.96)

	# Fuel system: the injectors and the pump can only deliver so much power. The
	# engine is torque-limited below the curve once it runs out of fuel.
	var inj_kw: float = 999.0 if injectors == null else injectors.num("max_power_kw", 999.0)
	var pump_kw: float = 999.0 if pump == null else pump.num("max_power_kw", 999.0)
	b.fuel_limit_kw = minf(inj_kw, pump_kw)

	# Thermal package.
	b.radiator_kw = 60.0 if radiator == null else radiator.num("heat_reject_kw", 60.0)
	b.coolant_l = 8.0 if radiator == null else radiator.num("capacity_l", 8.0)
	b.pump_mult = 1.0 if water_pump == null else water_pump.num("flow_mult", 1.0)
	b.fan_mult = 1.0 if fan == null else fan.num("airflow_mult", 1.0)
	b.thermostat_c = 88.0 if thermostat == null else thermostat.num("open_c", 88.0)

	# Sweep the real curve to find the power peak and whether fuel is the limit.
	var best_power: float = 0.0
	var best_rpm: float = b.redline_rpm * 0.7
	var rpm: float = b.idle_rpm
	var raw_peak: float = b.peak_torque_nm
	while rpm <= b.redline_rpm:
		var torque: float = b.torque_at(rpm)
		var power: float = torque * rpm * TAU / 60.0 / 1000.0
		if power > best_power:
			best_power = power
			best_rpm = rpm
		rpm += 25.0
	b.peak_power_kw = best_power
	b.peak_power_rpm = best_rpm
	var curve_peak: float = b.max_torque()
	if curve_peak < raw_peak * 0.985:
		b.fuel_limited = true
		b.warnings.append(_warn(
			"سیستم سوخت‌رسانی سقف توان را محدود می‌کند.",
			"The fuel system is capping power.",
			2))
	b.peak_torque_nm = curve_peak

	b.heat_kw_full = b.coolant_heat_kw(b.peak_power_kw)
	if b.heat_kw_full > b.radiator_kw * 1.05:
		b.cooling_marginal = true
		b.warnings.append(_warn(
			"رادیاتور برای این توان کافی نیست؛ در صعود طولانی دما بالا می‌رود.",
			"Radiator is undersized for this power; temperature will climb on long ascents.",
			3))

	b.inertia = float(spec.get("inertia", 0.3)) * clampf(b.displacement_l / maxf(stock_disp, 0.1), 0.7, 1.6)
	b.friction_torque = float(spec.get("friction", 20.0)) * (b.displacement_l / maxf(stock_disp, 0.1))

	b.mass_kg = 0.0
	for key: int in parts.keys():
		var p: PartDef = parts[key] as PartDef
		if p != null:
			b.mass_kg += p.mass_kg
	return b

static func _part(parts: Dictionary, slot: int) -> PartDef:
	return parts.get(slot, null) as PartDef

static func _warn(fa: String, en: String, severity: int) -> Dictionary:
	return {"fa": fa, "en": en, "severity": severity}
