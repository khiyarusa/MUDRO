class_name GearboxConfig
extends Resource
## Manual / automatic gearbox with real ratios, shift interruption and a final drive.

@export var display_name: String = "5-speed manual"
@export var ratios: PackedFloat32Array = PackedFloat32Array([3.9, 2.4, 1.7, 1.28, 1.0])
@export var reverse_ratio: float = 3.6
@export var final_drive: float = 4.1
@export var efficiency: float = 0.9
@export var shift_time: float = 0.22
@export var auto_upshift_fraction: float = 0.86
@export var auto_downshift_fraction: float = 0.34
@export var launch_rpm: float = 1400.0

func gear_count() -> int:
	return ratios.size()

func ratio_for(gear: int) -> float:
	if gear > 0 and gear <= ratios.size():
		return ratios[gear - 1]
	if gear == -1:
		return -reverse_ratio
	return 0.0

func total_ratio(gear: int) -> float:
	return ratio_for(gear) * final_drive

## Wheel torque in Nm for a crank torque and selected gear (before clutch slip).
func wheel_torque(crank_torque: float, gear: int) -> float:
	return crank_torque * total_ratio(gear) * efficiency

## Theoretical top speed in m/s for a wheel radius.
func top_speed_mps(wheel_radius_m: float, max_rpm: float) -> float:
	var top_gear: int = ratios.size()
	var ratio: float = total_ratio(top_gear)
	if ratio <= 0.0:
		return 0.0
	return Units.omega_from_rpm(max_rpm) * wheel_radius_m / ratio

func describe() -> String:
	var parts: PackedStringArray = []
	for r: float in ratios:
		parts.append("%.2f" % r)
	return "%d-speed [%s] final %.2f" % [ratios.size(), ", ".join(parts), final_drive]
