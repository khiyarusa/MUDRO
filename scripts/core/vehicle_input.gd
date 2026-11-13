class_name VehicleInputState
extends RefCounted
## The one input contract every source writes into and the simulation reads from.
##
## Keyboard, touch buttons, analog sliders, analog pedals and a gamepad all end up
## here, so `VehicleBody` can never tell which device produced a command. Nothing
## in the physics layer reads UI nodes, and no UI node writes to the rigid body.
##
## Units and conventions
##   throttle / brake / handbrake : 0.0 .. 1.0  (0 = released, 1 = fully applied)
##   clutch                       : 0.0 .. 1.0  (0 = pedal released / engaged,
##                                               1 = pedal fully pressed / open)
##   requested_gear               : -1 reverse, 0 neutral, 1..N forward
##   *_requested                  : one-shot commands, consumed by the race layer

const CLUTCH_FULL: float = 0.98

var throttle: float = 0.0
var brake: float = 0.0
var clutch: float = 0.0
var handbrake: float = 0.0

var requested_gear: int = 0
var gear_selection_requested: bool = false
var gear_step: int = 0
var engine_start_requested: bool = false
var recover_requested: bool = false
var winch_requested: bool = false
var transfer_requested: bool = false
var diff_requested: bool = false

## Diagnostic only: which source last wrote a non-zero value.
var source: String = "none"

func _init() -> void:
	reset()

## Zero everything, including the one-shot requests. Used on pause, focus loss and
## when a race ends, so no pedal can stay stuck down across a state change.
func reset() -> void:
	throttle = 0.0
	brake = 0.0
	clutch = 0.0
	handbrake = 0.0
	requested_gear = 0
	gear_selection_requested = false
	gear_step = 0
	engine_start_requested = false
	recover_requested = false
	winch_requested = false
	transfer_requested = false
	diff_requested = false
	source = "none"

## Clamp every analog channel into its legal range. Boolean fields are untouched.
func sanitize() -> void:
	throttle = clampf(throttle, 0.0, 1.0)
	brake = clampf(brake, 0.0, 1.0)
	clutch = clampf(clutch, 0.0, 1.0)
	handbrake = clampf(handbrake, 0.0, 1.0)

func clear_requests() -> void:
	gear_selection_requested = false
	gear_step = 0
	engine_start_requested = false
	recover_requested = false
	winch_requested = false
	transfer_requested = false
	diff_requested = false

func copy() -> VehicleInputState:
	var out := VehicleInputState.new()
	out.throttle = throttle
	out.brake = brake
	out.clutch = clutch
	out.handbrake = handbrake
	out.requested_gear = requested_gear
	out.gear_selection_requested = gear_selection_requested
	out.gear_step = gear_step
	out.engine_start_requested = engine_start_requested
	out.recover_requested = recover_requested
	out.winch_requested = winch_requested
	out.transfer_requested = transfer_requested
	out.diff_requested = diff_requested
	out.source = source
	return out

## Overlay another source on top of this one, taking the strongest value per
## channel. Touch and keyboard can therefore both contribute without one of them
## silently erasing the other.
func merge(other: VehicleInputState) -> void:
	throttle = maxf(throttle, other.throttle)
	brake = maxf(brake, other.brake)
	clutch = maxf(clutch, other.clutch)
	handbrake = maxf(handbrake, other.handbrake)
	if other.gear_selection_requested:
		requested_gear = other.requested_gear
		gear_selection_requested = true
	gear_step += other.gear_step
	engine_start_requested = engine_start_requested or other.engine_start_requested
	recover_requested = recover_requested or other.recover_requested
	winch_requested = winch_requested or other.winch_requested
	transfer_requested = transfer_requested or other.transfer_requested
	diff_requested = diff_requested or other.diff_requested
	if other.source != "none":
		source = other.source

func clutch_fully_pressed() -> bool:
	return clutch >= CLUTCH_FULL

## True when nothing is being asked of the car. Useful for diagnostics and tests.
func is_idle() -> bool:
	return is_zero_approx(throttle) and is_zero_approx(brake) and is_zero_approx(handbrake) \
		and is_zero_approx(clutch) and gear_step == 0 and not gear_selection_requested

func describe() -> String:
	return "thr %.2f brk %.2f clu %.2f hbk %.2f gear %d" % [throttle, brake, clutch, handbrake, requested_gear]
