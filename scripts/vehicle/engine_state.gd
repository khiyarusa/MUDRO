class_name EngineState
extends RefCounted
## Crank state: RPM, throttle, torque production, friction, engine braking, stall.

var config: EngineConfig
var rpm: float = 800.0
var running: bool = true
var throttle: float = 0.0
var throttle_target: float = 0.0
var boost: float = 1.0
var stall_cooldown: float = 0.0
var starter_timer: float = 0.0
var idle_assist: bool = true

func _init(cfg: EngineConfig = null) -> void:
	if cfg != null:
		config = cfg
		rpm = cfg.idle_rpm

func reset() -> void:
	rpm = config.idle_rpm if config != null else 800.0
	running = true
	throttle = 0.0
	throttle_target = 0.0
	boost = 1.0
	stall_cooldown = 0.0
	starter_timer = 0.0

func update(dt: float, target_throttle: float) -> void:
	throttle_target = clampf(target_throttle, 0.0, 1.0)
	if not running:
		throttle = 0.0
		return
	var rate: float = config.throttle_response if config != null else 7.0
	throttle = move_toward(throttle, throttle_target, rate * dt)
	if config != null and config.turbo_gain > 0.0:
		var rpm_band: float = clampf(1.0 - absf(rpm - config.turbo_rpm) / maxf(config.turbo_width, 1.0), 0.0, 1.0)
		var target_boost: float = rpm_band * throttle
		boost = move_toward(boost, target_boost, dt / maxf(config.turbo_lag, 0.05))
	if starter_timer > 0.0:
		starter_timer = maxf(0.0, starter_timer - dt)
	if stall_cooldown > 0.0:
		stall_cooldown = maxf(0.0, stall_cooldown - dt)

## Torque delivered at the crank, after the rev limiter, in Nm.
func output_torque() -> float:
	if not running or config == null:
		return 0.0
	var limited: float = throttle
	if rpm >= config.redline_rpm:
		limited = 0.0
	elif rpm > config.redline_rpm - 120.0:
		limited *= clampf((config.redline_rpm - rpm) / 120.0, 0.0, 1.0)
	var t: float = config.torque_at_wot(rpm, boost) * limited
	return maxf(0.0, t)

## ECU idle governor: keeps a running engine from dying when the throttle is shut.
func idle_torque() -> float:
	if not running or config == null:
		return 0.0
	if rpm >= config.idle_rpm:
		return 0.0
	return (config.idle_rpm - rpm) * 0.42

func friction_torque() -> float:
	if config == null:
		return 0.0
	return config.friction_at(rpm, throttle)

## Negative torque resisting rotation when the throttle is closed (engine braking).
func braking_torque() -> float:
	if config == null or not running:
		return 0.0
	return config.engine_brake_at(rpm) * (1.0 - throttle)

func integrate(dt: float, net_torque: float) -> void:
	if config == null:
		return
	var omega: float = Units.omega_from_rpm(rpm)
	# Rev limiter / overspeed governor: the driveline cannot keep pulling the crank
	# past the limiter, and engine braking resists over-revving.
	if rpm > config.redline_rpm:
		net_torque -= (rpm - config.redline_rpm) * 2.5
	omega += net_torque / maxf(config.inertia, 0.01) * dt
	rpm = Units.rpm_from_omega(omega)
	rpm = clampf(rpm, 0.0, config.redline_rpm * 1.02)
	if not running:
		rpm = maxf(0.0, rpm - 900.0 * dt)

func stall() -> void:
	if not running:
		return
	running = false
	rpm = 0.0
	stall_cooldown = 0.8

func start() -> void:
	running = true
	rpm = maxf(rpm, config.idle_rpm * 0.55 if config != null else 500.0)
	starter_timer = 0.55
	stall_cooldown = 0.0

func rpm_fraction() -> float:
	if config == null:
		return 0.0
	return clampf(rpm / maxf(config.redline_rpm, 1.0), 0.0, 1.1)

func in_redline() -> bool:
	return config != null and rpm >= config.redline_rpm * 0.94

func power_kw() -> float:
	if config == null:
		return 0.0
	return output_torque() * Units.omega_from_rpm(rpm) / 1000.0
