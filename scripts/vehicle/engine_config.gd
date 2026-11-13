class_name EngineConfig
extends Resource
## Data-driven internal combustion engine model.
##
## Torque is a real function of RPM (linear interpolation over authored samples),
## never a constant. Power is derived as P = T * omega, engine braking comes from
## friction + pumping losses, and the inertia lets the crank accelerate/decelerate
## independently of the wheels while the clutch slips.

@export var display_name: String = "Engine"
@export var idle_rpm: float = 800.0
@export var max_rpm: float = 6200.0
@export var redline_rpm: float = 5800.0
@export var stall_rpm: float = 420.0
@export var inertia: float = 0.18
@export var friction_torque: float = 14.0
@export var friction_rpm_factor: float = 0.0026
@export var engine_brake_factor: float = 0.62
@export var throttle_response: float = 7.5
@export var stall_enabled: bool = true
@export var curve_rpm: PackedFloat32Array = PackedFloat32Array([600.0, 1200.0, 2000.0, 3000.0, 4000.0, 5000.0, 6000.0, 6800.0])
@export var curve_torque: PackedFloat32Array = PackedFloat32Array([110.0, 160.0, 200.0, 236.0, 248.0, 232.0, 198.0, 120.0])
@export var turbo_gain: float = 0.0
@export var turbo_rpm: float = 3400.0
@export var turbo_width: float = 1500.0
@export var turbo_lag: float = 0.55

## Interpolated crank torque in Nm at a given RPM, clamped to the authored curve.
func torque_at(rpm: float) -> float:
	var n: int = mini(curve_rpm.size(), curve_torque.size())
	if n == 0:
		return 0.0
	if n == 1:
		return curve_torque[0]
	if rpm <= curve_rpm[0]:
		return curve_torque[0]
	if rpm >= curve_rpm[n - 1]:
		return curve_torque[n - 1]
	for i: int in range(n - 1):
		var r0: float = curve_rpm[i]
		var r1: float = curve_rpm[i + 1]
		if rpm >= r0 and rpm <= r1:
			var t: float = 0.0 if is_equal_approx(r1, r0) else (rpm - r0) / (r1 - r0)
			return lerpf(curve_torque[i], curve_torque[i + 1], t)
	return curve_torque[n - 1]

## Wide-open-throttle torque including turbo boost (0..1 spool value supplied by the caller).
func torque_at_wot(rpm: float, boost: float = 1.0) -> float:
	var base: float = torque_at(rpm)
	if turbo_gain <= 0.0:
		return base
	var band: float = clampf(1.0 - absf(rpm - turbo_rpm) / maxf(turbo_width, 1.0), 0.0, 1.0)
	return base * (1.0 + turbo_gain * band * clampf(boost, 0.0, 1.2))

func peak_torque() -> float:
	var best: float = 0.0
	for v: float in curve_torque:
		best = maxf(best, v)
	return best

func peak_power_kw() -> float:
	var best: float = 0.0
	var rpm: float = 600.0
	while rpm <= max_rpm:
		best = maxf(best, torque_at(rpm) * Units.omega_from_rpm(rpm) / 1000.0)
		rpm += 50.0
	return best

func usable_band() -> Vector2:
	return Vector2(idle_rpm, redline_rpm)

func friction_at(rpm: float, throttle: float) -> float:
	var load_relief: float = lerpf(1.0, 0.25, clampf(throttle, 0.0, 1.0))
	return (friction_torque + friction_rpm_factor * rpm) * load_relief

func engine_brake_at(rpm: float) -> float:
	return engine_brake_factor * (friction_torque + friction_rpm_factor * rpm) * 2.4
