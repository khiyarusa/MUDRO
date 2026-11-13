class_name ClutchState
extends RefCounted
## Friction clutch between crank and gearbox input.
## Torque capacity limits how much the engine can load the driveline, so a
## downshift at speed cannot instantly multiply torque beyond the plates' grip.

var capacity: float = 420.0
var stiffness: float = 2.6
var engagement: float = 1.0
var manual_mode: bool = false
var pedal: float = 1.0
var slip_rpm: float = 0.0
var transmitted_torque: float = 0.0
var locked: bool = false

func reset() -> void:
	engagement = 1.0
	pedal = 1.0
	slip_rpm = 0.0
	transmitted_torque = 0.0

## pedal_norm: 1.0 = fully released (engaged), 0.0 = pressed to the floor (open).
func update(dt: float, pedal_norm: float, shift_active: bool, engine_rpm: float,
		driveline_rpm: float, throttle: float, speed_mps: float) -> void:
	if manual_mode:
		pedal = clampf(pedal_norm, 0.0, 1.0)
		var target: float = clampf((pedal - 0.18) / 0.55, 0.0, 1.0)
		engagement = move_toward(engagement, target, dt * 6.0)
	else:
		var target: float = 1.0
		if shift_active:
			target = 0.0
		elif engine_rpm < (1150.0 if throttle < 0.05 else 1000.0) and absf(speed_mps) < 0.6:
			# Idle creep: hold the clutch open so the engine cannot be lugged to death.
			target = 0.0
		elif engine_rpm < 1250.0:
			target = 0.55
		engagement = move_toward(engagement, target, dt * 3.5)
		pedal = engagement
	slip_rpm = engine_rpm - driveline_rpm

func compute_torque() -> float:
	transmitted_torque = clampf(slip_rpm * stiffness, -capacity, capacity) * engagement
	return transmitted_torque

func is_open() -> bool:
	return engagement < 0.06
