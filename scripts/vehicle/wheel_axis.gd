class_name WheelAxis
extends RefCounted
## One physical axle: suspension travel, wheel rotation and a slip-based tyre.
##
## The tyre never produces unlimited force:
##   F_long = mu(slip) * N * curve(slip)     with |F_long| <= mu * N
## The curve rises to a peak around 14% slip and falls to a sliding plateau,
## which is why wheelspin on ice or mud feels different from dry rock.

var axle_index: int = 0
var config: TireConfig
var omega: float = 0.0
var spin_angle: float = 0.0

var in_contact: bool = false
var compression: float = 0.0
var compression_velocity: float = 0.0
var normal_load: float = 0.0
var slip_ratio: float = 0.0
var tire_force: float = 0.0
var surface: SurfaceProfile
var contact_point: Vector2 = Vector2.ZERO
var contact_normal: Vector2 = Vector2.UP
var hub_local: Vector2 = Vector2.ZERO
var hub_world: Vector2 = Vector2.ZERO
var bottomed_out: bool = false
var spin_ratio: float = 1.0

func _init(index: int = 0, cfg: TireConfig = null) -> void:
	axle_index = index
	config = cfg

func reset() -> void:
	omega = 0.0
	spin_angle = 0.0
	in_contact = false
	compression = 0.0
	compression_velocity = 0.0
	normal_load = 0.0
	slip_ratio = 0.0
	tire_force = 0.0
	bottomed_out = false

func radius() -> float:
	return config.radius_m if config != null else 0.35

func inertia() -> float:
	return config.wheel_inertia() if config != null else 1.0

func surface_speed() -> float:
	return omega * radius()

func update_slip(ground_speed: float) -> void:
	if config == null:
		slip_ratio = 0.0
		return
	var reg: float = maxf(config.low_speed_regularisation, 0.1)
	var denom: float = maxf(absf(ground_speed), reg)
	slip_ratio = clampf((surface_speed() - ground_speed) / denom, -4.0, 4.0)
	spin_ratio = clampf(absf(surface_speed()) / maxf(absf(ground_speed), 1.2), 0.0, 6.0)

## Shape of the longitudinal force curve: rises linearly to the peak slip, then
## holds at 1.0. The surface supplies how much grip is lost once sliding.
func slip_shape() -> float:
	if config == null:
		return 0.0
	var s: float = absf(slip_ratio)
	return clampf(s / maxf(config.peak_slip, 0.001), 0.0, 1.0)

## Longitudinal tyre force in newtons. grip_peak/grip_slide are the surface
## coefficients; the force is always bounded by grip * normal load.
func compute_force(grip_peak: float, grip_slide: float = -1.0) -> float:
	if config == null:
		tire_force = 0.0
		return 0.0
	if grip_slide < 0.0:
		grip_slide = grip_peak
	var s: float = absf(slip_ratio)
	var over: float = clampf((s - config.peak_slip) / maxf(config.slide_slip - config.peak_slip, 0.001), 0.0, 1.0)
	var mu: float = lerpf(maxf(grip_peak, 0.0), maxf(grip_slide, 0.0), over) * config.mu_scale
	tire_force = mu * normal_load * slip_shape() * signf(slip_ratio)
	if s < 0.0005:
		tire_force = 0.0
	return tire_force

func integrate(dt: float, drive_torque: float, brake_torque: float) -> void:
	if config == null:
		return
	var reaction: float = tire_force * radius()
	var net: float = drive_torque - reaction
	var inertia: float = inertia()
	omega += net / inertia * dt
	omega = clampf(omega, -260.0, 260.0)
	if brake_torque > 0.0:
		var delta: float = brake_torque / inertia * dt
		if absf(omega) <= delta:
			omega = 0.0
		else:
			omega -= signf(omega) * delta
	spin_angle = wrapf(spin_angle + omega * dt, -TAU * 512.0, TAU * 512.0)

func contact_speed_kmh() -> float:
	return Units.px2kmh(surface_speed() * Units.PPM)
