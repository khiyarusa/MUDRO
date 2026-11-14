class_name ThermalState
extends RefCounted
## Engine cooling, in the smallest model that still produces real behaviour.
##
##     heat in   = 0.75 * crank power + idle loss        (kW)
##     heat out  = radiator_kW * airflow * pump * (T - ambient) / 60 K
##     dT/dt     = (heat in - heat out) / (coolant mass * 4180 J/kgK)
##
## Airflow rises with road speed and with the fan; the thermostat blocks flow
## below its opening temperature. A stock cooling package holds a stock engine at
## about 90 °C on a long climb. A big turbo on a stock radiator does not.

const RATED_DELTA_K: float = 60.0
const COOLANT_CP: float = 4180.0
const DERATE_START_C: float = 108.0
const DERATE_FULL_C: float = 124.0
const DAMAGE_START_C: float = 121.0

var coolant_temp_c: float = 88.0
var ambient_c: float = 22.0
var capacity_l: float = 9.0
var radiator_kw: float = 90.0
var pump_mult: float = 1.0
var fan_mult: float = 1.0
var thermostat_c: float = 88.0
var fan_on: bool = false
var heat_in_kw: float = 0.0
var heat_out_kw: float = 0.0
var damage_accum: float = 0.0
var warning: bool = false
var critical: bool = false

func setup(build: EngineBuild, ambient: float = 22.0) -> ThermalState:
	ambient_c = ambient
	capacity_l = maxf(build.coolant_l, 1.0)
	radiator_kw = maxf(build.radiator_kw, 5.0)
	pump_mult = clampf(build.pump_mult, 0.5, 2.0)
	fan_mult = clampf(build.fan_mult, 0.6, 2.0)
	thermostat_c = build.thermostat_c
	coolant_temp_c = ambient_c + 4.0
	return self

func reset(ambient: float = -999.0) -> void:
	if ambient > -900.0:
		ambient_c = ambient
	coolant_temp_c = ambient_c + 4.0
	damage_accum = 0.0
	warning = false
	critical = false

## `power_kw` is the current crank output. `speed_mps` is road speed.
func update(dt: float, power_kw: float, speed_mps: float, throttle: float = 0.0) -> void:
	heat_in_kw = maxf(power_kw, 0.0) * 0.75 + 5.5
	# Airflow: ram air plus the fan, which only matters at low speed.
	var ram: float = clampf(0.30 + absf(speed_mps) / 26.0, 0.30, 1.30)
	if coolant_temp_c > thermostat_c + 4.0:
		fan_on = true
	elif coolant_temp_c < thermostat_c - 3.0:
		fan_on = false
	var fan_air: float = (0.22 if fan_on else 0.0) * fan_mult
	var airflow: float = (ram + fan_air) * pump_mult
	var delta: float = coolant_temp_c - ambient_c
	var flow_open: float = 1.0
	if coolant_temp_c < thermostat_c:
		# Thermostat closed: only the bypass circuit moves heat.
		flow_open = clampf(0.10 + 0.90 * (coolant_temp_c - (thermostat_c - 8.0)) / 8.0, 0.08, 1.0)
	heat_out_kw = radiator_kw * airflow * flow_open * clampf(delta / RATED_DELTA_K, 0.0, 2.2)
	var mass_kg: float = capacity_l * 1.05
	var dT: float = (heat_in_kw - heat_out_kw) * 1000.0 / maxf(mass_kg * COOLANT_CP, 1.0)
	coolant_temp_c = clampf(coolant_temp_c + dT * dt, ambient_c - 5.0, 165.0)
	if coolant_temp_c > DAMAGE_START_C:
		damage_accum += (coolant_temp_c - DAMAGE_START_C) * 0.004 * dt
	warning = coolant_temp_c >= DERATE_START_C - 4.0
	critical = coolant_temp_c >= DAMAGE_START_C
	if throttle < 0.02 and absf(speed_mps) > 8.0:
		# Coasting downhill still cools; no extra heat is produced.
		pass

## Power multiplier: full output until the engine starts to heat-soak, then a
## controlled derate so an overheated engine loses pace instead of exploding.
func power_derate() -> float:
	if coolant_temp_c <= DERATE_START_C:
		return 1.0
	var t: float = clampf((coolant_temp_c - DERATE_START_C) / (DERATE_FULL_C - DERATE_START_C), 0.0, 1.0)
	return lerpf(1.0, 0.52, t)

func status_color() -> Color:
	if critical:
		return Color(0.88, 0.30, 0.24)
	if warning:
		return Color(0.92, 0.62, 0.24)
	return Color(0.62, 0.82, 0.70)

func describe(lang: String) -> String:
	var state: String = ""
	if critical:
		state = " بحرانی" if lang == "fa" else " CRITICAL"
	elif warning:
		state = " داغ" if lang == "fa" else " HOT"
	return "%d°C%s" % [int(coolant_temp_c), state]
