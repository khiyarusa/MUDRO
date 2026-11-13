class_name Units
extends RefCounted
## Single source of truth for the pixel <-> metre conversion used by MUDRO.
##
## Every physical quantity inside the simulation is expressed in SI units.
## Only at the boundary (applying forces to a RigidBody2D, reading positions)
## do we convert to Godot's pixel space:
##   length  : px   = m   * PPM
##   force   : px   = N   * PPM          (F = m * a, mass stays in kg)
##   torque  : px   = Nm  * PPM^2        (torque = force * length)
##   inertia : px   = kg*m^2 * PPM^2
##   gravity : px/s^2 = 9.80665 * PPM    (project.godot: 627.62)

const PPM: float = 64.0
const GRAVITY: float = 9.80665
const AIR_DENSITY: float = 1.225

static func m2px(value_m: float) -> float:
	return value_m * PPM

static func px2m(value_px: float) -> float:
	return value_px / PPM

static func n2px(newton: float) -> float:
	return newton * PPM

static func nm2px(newton_metre: float) -> float:
	return newton_metre * PPM * PPM

static func px2kmh(value_px: float) -> float:
	return (value_px / PPM) * 3.6

static func kmh2mps(kmh: float) -> float:
	return kmh / 3.6

static func rpm_from_omega(omega_rad_s: float) -> float:
	return omega_rad_s * 60.0 / TAU

static func omega_from_rpm(rpm: float) -> float:
	return rpm * TAU / 60.0

static func lerp_smooth(a: float, b: float, t: float) -> float:
	var tc: float = clampf(t, 0.0, 1.0)
	return lerpf(a, b, tc * tc * (3.0 - 2.0 * tc))
