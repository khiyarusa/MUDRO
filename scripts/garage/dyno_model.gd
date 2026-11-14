class_name DynoModel
extends RefCounted
## A dyno pull computed from the very same EngineBuild the physics uses.
##
## No decorative numbers: every point is `engine.torque_at(rpm)` for the current
## build, converted through the selected gear, final drive and driveline
## efficiency. Compare a pull before and after fitting a part and the difference is
## the part.

const GEAR_EFFICIENCY_FALLBACK: float = 0.9

static func pull(engine: EngineBuild, ratio: float = 3.5, final_drive: float = 3.9,
		tire_radius_m: float = 0.38, efficiency: float = 0.9) -> Dictionary:
	var rpms := PackedFloat32Array()
	var torque := PackedFloat32Array()
	var power := PackedFloat32Array()
	var wheel_torque := PackedFloat32Array()
	var wheel_power := PackedFloat32Array()
	var boost := PackedFloat32Array()
	var gear_ratio: float = maxf(ratio * final_drive, 0.1)
	var start: float = maxf(engine.idle_rpm, 700.0)
	var step: float = 100.0
	var rpm: float = start
	while rpm <= engine.redline_rpm + 1.0:
		var t: float = engine.torque_at(rpm)
		var kw: float = engine.power_kw_at(rpm)
		rpms.append(rpm)
		torque.append(t)
		power.append(kw)
		wheel_torque.append(t * gear_ratio * maxf(efficiency, 0.5))
		wheel_power.append(kw * maxf(efficiency, 0.5))
		boost.append(engine.boost_bar if rpm > engine.peak_torque_rpm * 0.45 else engine.boost_bar * (rpm / maxf(engine.peak_torque_rpm * 0.45, 1.0)))
		rpm += step
	var peak_t: float = 0.0
	var peak_t_rpm: float = 0.0
	var peak_kw: float = 0.0
	var peak_kw_rpm: float = 0.0
	for i: int in range(rpms.size()):
		if torque[i] > peak_t:
			peak_t = torque[i]
			peak_t_rpm = rpms[i]
		if power[i] > peak_kw:
			peak_kw = power[i]
			peak_kw_rpm = rpms[i]
	return {
		"rpm": rpms,
		"torque": torque,
		"power": power,
		"wheel_torque": wheel_torque,
		"wheel_power": wheel_power,
		"boost": boost,
		"peak_torque_nm": peak_t,
		"peak_torque_rpm": peak_t_rpm,
		"peak_power_kw": peak_kw,
		"peak_power_rpm": peak_kw_rpm,
		"gear_ratio": gear_ratio,
		"redline_rpm": engine.redline_rpm,
	}

static func compare(before: Dictionary, after: Dictionary) -> Dictionary:
	var dt: float = float(after.get("peak_torque_nm", 0.0)) - float(before.get("peak_torque_nm", 0.0))
	var dp: float = float(after.get("peak_power_kw", 0.0)) - float(before.get("peak_power_kw", 0.0))
	var base_t: float = maxf(float(before.get("peak_torque_nm", 0.0)), 1.0)
	var base_p: float = maxf(float(before.get("peak_power_kw", 0.0)), 1.0)
	return {
		"torque_delta_nm": dt,
		"torque_delta_pct": dt / base_t * 100.0,
		"power_delta_kw": dp,
		"power_delta_pct": dp / base_p * 100.0,
		"redline_delta": int(after.get("redline_rpm", 0.0)) - int(before.get("redline_rpm", 0.0)),
	}

## Series for the on-screen chart, normalised to the given box size.
static func chart_points(values: PackedFloat32Array, origin: Vector2, size: Vector2,
		max_value: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	if values.is_empty():
		return out
	var top: float = max_value
	if top <= 0.0:
		for v: float in values:
			top = maxf(top, v)
	top = maxf(top, 1.0)
	for i: int in range(values.size()):
		var x: float = origin.x + size.x * float(i) / float(maxi(values.size() - 1, 1))
		var y: float = origin.y + size.y * (1.0 - clampf(values[i] / top, 0.0, 1.0))
		out.append(Vector2(x, y))
	return out
