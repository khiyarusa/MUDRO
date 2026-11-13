class_name TireConfig
extends Resource
## Tyre properties. The longitudinal force model lives in wheel_axis.gd and is
## clamped by mu * normal load, so grip is always finite.

@export var display_name: String = "All-terrain"
@export var radius_m: float = 0.39
@export var width_m: float = 0.25
@export var wheel_mass_kg: float = 32.0
@export var mu_scale: float = 1.0
@export var rolling_resistance: float = 0.028
@export var peak_slip: float = 0.14
@export var slide_slip: float = 1.15
@export var slide_grip_fraction: float = 0.74
@export var low_speed_regularisation: float = 2.4
@export var inertia_multiplier: float = 1.9

func wheel_inertia() -> float:
	return 0.5 * wheel_mass_kg * radius_m * radius_m * inertia_multiplier

func grip(mu_surface: float) -> float:
	return maxf(0.02, mu_surface * mu_scale)
