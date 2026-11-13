class_name ClutchState
extends RefCounted
## Friction clutch between crank and gearbox input.
##
## `pedal` is the player's pedal position: 0.0 = foot off (clutch engaged),
## 1.0 = pressed to the floor (clutch open). The gear interlock in the H-pattern
## box requires `pedal >= 0.98`, which is exactly what `is_fully_pressed()` reports.
##
## Torque capacity limits how much the engine can load the driveline, so a
## downshift at speed cannot instantly multiply torque beyond the plates' grip.

const FULLY_PRESSED: float = 0.98

var capacity: float = 420.0
var stiffness: float = 2.6
var engagement: float = 1.0
## 0 = released (engaged), 1 = fully pressed (open).
var pedal: float = 0.0
var manual_mode: bool = false
var slip_rpm: float = 0.0
var transmitted_torque: float = 0.0
var locked: bool = false
## How fast the player let the pedal out this frame (positive = releasing).
var release_rate: float = 0.0
## Set when the pedal is dumped: the driveline takes a shock and the engine can stall.
var dumped: bool = false
var bite_point: float = 0.62

var _prev_pedal: float = 0.0

func reset() -> void:
	engagement = 1.0
	pedal = 0.0
	slip_rpm = 0.0
	transmitted_torque = 0.0
	release_rate = 0.0
	dumped = false
	_prev_pedal = 0.0

func is_open() -> bool:
	return engagement < 0.06

func is_fully_pressed() -> bool:
	return pedal >= FULLY_PRESSED

## Target plate engagement for a pedal position. A real clutch has free play at
## the top of the travel and bites over a short window; this is that window.
func engagement_target(pedal_pos: float) -> float:
	var travel: float = 1.0 - clampf(pedal_pos, 0.0, 1.0)
	return clampf((travel - 0.14) / 0.56, 0.0, 1.0)

func update(dt: float, pedal_pressed: float, shift_active: bool, engine_rpm: float,
		driveline_rpm: float, throttle: float, speed_mps: float) -> void:
	var p: float = clampf(pedal_pressed, 0.0, 1.0)
	if manual_mode:
		release_rate = maxf(0.0, (_prev_pedal - p) / maxf(dt, 0.0001))
		pedal = p
		var target: float = engagement_target(p)
		# Pressing is fast (hydraulic), releasing is limited by the player's foot.
		var rate: float = 9.0 if target < engagement else 5.5
		engagement = move_toward(engagement, target, dt * rate)
		dumped = release_rate > 3.2 and engagement > 0.25 and engagement < 0.85
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
		pedal = 1.0 - engagement
		release_rate = 0.0
		dumped = false
	_prev_pedal = pedal
	slip_rpm = engine_rpm - driveline_rpm

func compute_torque() -> float:
	transmitted_torque = clampf(slip_rpm * stiffness, -capacity, capacity) * engagement
	return transmitted_torque

func describe() -> String:
	return "pedal %.2f engagement %.2f %s" % [pedal, engagement, "locked" if locked else "slipping"]
