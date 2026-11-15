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
## Pedal travel over which the plates go from just touching to fully clamped. A
## paddle cover has a shorter, sharper window than an organic one; the fitted part
## can override it.
const DEFAULT_WINDOW: float = 0.36

var capacity: float = 420.0
var stiffness: float = 2.6
var engagement: float = 1.0
## 0 = released (engaged), 1 = fully pressed (open).
var pedal: float = 0.0
var manual_mode: bool = false
var slip_rpm: float = 0.0
var transmitted_torque: float = 0.0
var locked: bool = false
## Capacity multiplier from plate temperature. The body owns the thermal state; the
## clutch only needs the number so the torque model has one implementation.
var capacity_scale: float = 1.0
## How fast the player let the pedal out this frame (positive = releasing).
var release_rate: float = 0.0
## Set when the pedal is dumped: the driveline takes a shock and the engine can stall.
var dumped: bool = false
var bite_point: float = 0.62
var engagement_window: float = DEFAULT_WINDOW
## How fast a released pedal clamps the plates, in engagement per second. A heavy
## diesel cover with a big friction area takes longer to bite than a small petrol
## one, so this is vehicle data, not a constant. Pressing is always fast.
var clamp_rate: float = 5.5
## Slip energy the cover can absorb per unit of fade (kW·s). Bigger, heavier
## covers carry more before they go soft.
var heat_capacity: float = 45.0
## Fraction of capacity lost at full heat. A light cover fades harder.
var fade_limit: float = 0.30

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

## Target plate engagement for a pedal position. `bite_point` is the pedal travel
## at which the plates separate completely, so engagement falls to zero over the
## window below it. That is what gives each clutch a distinct feel: a paddle cover
## releases earlier and over a shorter travel than an organic one.
func engagement_target(pedal_pos: float) -> float:
	var p: float = clampf(pedal_pos, 0.0, 1.0)
	var bite: float = clampf(bite_point, 0.25, 0.85)
	var window: float = clampf(engagement_window, 0.16, 0.50)
	return clampf((bite - p) / window, 0.0, 1.0)

func update(dt: float, pedal_pressed: float, shift_active: bool, engine_rpm: float,
		driveline_rpm: float, throttle: float, speed_mps: float) -> void:
	var p: float = clampf(pedal_pressed, 0.0, 1.0)
	if manual_mode:
		release_rate = maxf(0.0, (_prev_pedal - p) / maxf(dt, 0.0001))
		pedal = p
		var target: float = engagement_target(p)
		# Pressing is fast (hydraulic), releasing is limited by the cover, which is
		# the one number that makes a Patrol feel heavier than a Jimny.
		var rate: float = 9.0 if target < engagement else clampf(clamp_rate, 1.5, 12.0)
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
		# The pedal still works in an automatic-clutch car: pressing it opens the
		# plates further than the controller wanted. It can only ever disengage more,
		# never force the plates shut, so the governor keeps the engine alive.
		target = minf(target, engagement_target(p))
		engagement = move_toward(engagement, target, dt * 3.5)
		pedal = 1.0 - engagement
		release_rate = 0.0
		dumped = false
	_prev_pedal = pedal
	slip_rpm = engine_rpm - driveline_rpm

## Torque the plates can carry right now at this pedal position. Both the lock-up
## test and the slip clamp read this, so there is exactly one clutch law in the
## project and the tests cannot certify a formula the car does not use.
func capacity_now() -> float:
	return capacity * clampf(capacity_scale, 0.0, 1.0) * clampf(engagement, 0.0, 1.0)

func compute_torque() -> float:
	transmitted_torque = clampf(slip_rpm * stiffness, -capacity_now(), capacity_now())
	return transmitted_torque

func describe() -> String:
	return "pedal %.2f engagement %.2f %s" % [pedal, engagement, "locked" if locked else "slipping"]
