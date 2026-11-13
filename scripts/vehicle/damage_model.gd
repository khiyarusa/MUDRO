class_name DamageModel
extends RefCounted
## Gameplay damage, separate from the visual dirt/deformation overlay.
## Damaged parts change real simulation values: torque, damping, grip.

var chassis: float = 1.0
var engine_health: float = 1.0
var suspension: PackedFloat32Array = PackedFloat32Array([1.0, 1.0])
var tires: PackedFloat32Array = PackedFloat32Array([1.0, 1.0])
var impact_count: int = 0
var worst_impact: float = 0.0

func reset() -> void:
	chassis = 1.0
	engine_health = 1.0
	suspension = PackedFloat32Array([1.0, 1.0])
	tires = PackedFloat32Array([1.0, 1.0])
	impact_count = 0
	worst_impact = 0.0

## severity: 0..1 where 1 is a stage-ending hit.
func apply_impact(severity: float, axle: int, durability: float = 1.0) -> void:
	var s: float = clampf(severity, 0.0, 1.5)
	if s < 0.02:
		return
	impact_count += 1
	worst_impact = maxf(worst_impact, s)
	var resistance: float = maxf(0.25, durability)
	var dmg: float = s / resistance
	chassis = maxf(0.0, chassis - dmg * 0.22)
	engine_health = maxf(0.0, engine_health - dmg * 0.16)
	var idx: int = clampi(axle, 0, 1)
	suspension[idx] = maxf(0.05, suspension[idx] - dmg * 0.26)
	tires[idx] = maxf(0.08, tires[idx] - dmg * 0.18)

func apply_wear(amount: float) -> void:
	tires[0] = maxf(0.1, tires[0] - amount)
	tires[1] = maxf(0.1, tires[1] - amount * 0.9)

func torque_multiplier() -> float:
	return 0.35 + 0.65 * clampf(engine_health, 0.0, 1.0)

func damping_multiplier(axle: int) -> float:
	var idx: int = clampi(axle, 0, 1)
	return 0.42 + 0.58 * clampf(suspension[idx], 0.0, 1.0)

func grip_multiplier(axle: int) -> float:
	var idx: int = clampi(axle, 0, 1)
	return 0.48 + 0.52 * clampf(tires[idx], 0.0, 1.0)

func total_health() -> float:
	return clampf((chassis * 0.4 + engine_health * 0.25 + (suspension[0] + suspension[1]) * 0.125 + (tires[0] + tires[1]) * 0.025), 0.0, 1.0)

func is_disabled() -> bool:
	return engine_health <= 0.02

func repair() -> void:
	reset()

func summary() -> Dictionary:
	return {
		"chassis": chassis,
		"engine": engine_health,
		"suspension_front": suspension[0],
		"suspension_rear": suspension[1],
		"tire_front": tires[0],
		"tire_rear": tires[1],
	}
