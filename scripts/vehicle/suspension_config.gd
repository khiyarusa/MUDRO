class_name SuspensionConfig
extends Resource
## Two independent axle suspensions (front / rear). Simplified spring-damper with
## separate compression and rebound damping, droop, and a progressive bump stop.
##
## F = k * compression + c * compression_velocity  (N, compression in metres)

@export var rest_length_m: float = 0.26
@export var travel_m: float = 0.24
@export var droop_m: float = 0.10
@export var spring_front: float = 34000.0
@export var spring_rear: float = 30000.0
@export var damper_compression_front: float = 2400.0
@export var damper_rebound_front: float = 3200.0
@export var damper_compression_rear: float = 2200.0
@export var damper_rebound_rear: float = 3000.0
@export var bump_stop_rate: float = 90000.0
@export var bump_stop_progress: float = 2.0
@export var anti_roll: float = 0.08

func spring_at(axle: int) -> float:
	return spring_front if axle == 0 else spring_rear

func damper_at(axle: int, compression_velocity: float) -> float:
	if axle == 0:
		return damper_compression_front if compression_velocity >= 0.0 else damper_rebound_front
	return damper_compression_rear if compression_velocity >= 0.0 else damper_rebound_rear
