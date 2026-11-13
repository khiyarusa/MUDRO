class_name GearboxState
extends RefCounted
## Gear selection, shift interruption, and an optional automatic mode.
## Gear 0 = neutral, 1..N = forward, -1 = reverse.

var config: GearboxConfig
var gear: int = 0
var shift_timer: float = 0.0
var time_in_gear: float = 0.0
var auto_mode: bool = false
var last_shift_dir: int = 0

func _init(cfg: GearboxConfig = null) -> void:
	config = cfg

func reset(initial_gear: int = 0) -> void:
	gear = initial_gear
	shift_timer = 0.0
	time_in_gear = 0.0
	last_shift_dir = 0

func gear_count() -> int:
	return config.gear_count() if config != null else 0

func is_shifting() -> bool:
	return shift_timer > 0.0

## Ratio actually transmitting torque right now (0 while the box is between gears).
func effective_ratio() -> float:
	if config == null or is_shifting():
		return 0.0
	return config.ratio_for(gear)

func total_ratio() -> float:
	return effective_ratio() * (config.final_drive if config != null else 1.0)

## Returns true when the requested gear was accepted.
func request_gear(target: int, force: bool = false) -> bool:
	if config == null:
		return false
	var clamped: int = clampi(target, -1, config.gear_count())
	if clamped == gear:
		return false
	if is_shifting() and not force:
		return false
	last_shift_dir = signi(clamped - gear)
	gear = clamped
	shift_timer = config.shift_time
	time_in_gear = 0.0
	return true

func shift_up() -> bool:
	return request_gear(gear + 1)

func shift_down() -> bool:
	return request_gear(gear - 1)

func update(dt: float) -> void:
	shift_timer = maxf(0.0, shift_timer - dt)
	time_in_gear += dt

## Automatic mode: choose gears from engine RPM with hysteresis and a hold time.
func auto_update(dt: float, rpm: float, throttle: float, speed_mps: float) -> void:
	update(dt)
	if config == null or not auto_mode or is_shifting():
		return
	if time_in_gear < 0.45:
		return
	if gear == 0:
		if absf(speed_mps) > 0.4:
			request_gear(1 if speed_mps > 0.0 else -1, true)
		elif throttle > 0.15:
			request_gear(1, true)
		return
	if gear == -1:
		if throttle > 0.2 and speed_mps > -0.3:
			request_gear(1, true)
		return
	var up_rpm: float = config.auto_upshift_fraction * (config_upshift_reference())
	var down_rpm: float = config.auto_downshift_fraction * (config_upshift_reference())
	if rpm > up_rpm and gear < config.gear_count():
		# Do not chase a spinning wheel up the box: real automatics wait for road speed.
		if speed_mps > 2.2:
			request_gear(gear + 1, true)
	elif rpm < down_rpm and gear > 1:
		if speed_mps > 0.4 or throttle > 0.5:
			request_gear(gear - 1, true)

## The gearbox config does not know the engine, so the caller injects the reference RPM.
var engine_redline: float = 6000.0

func config_upshift_reference() -> float:
	return engine_redline

func describe() -> String:
	if config == null:
		return "N"
	if gear == 0:
		return "N"
	if gear == -1:
		return "R"
	return str(gear)
