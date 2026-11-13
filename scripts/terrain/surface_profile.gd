class_name SurfaceProfile
extends Resource
## A terrain material as a physics + presentation profile.
## Grip is a real coefficient used by the tyre model: F_max ~= mu * F_normal.

@export var id: String = "hard_dirt"
@export var name_fa: String = "خاک سفت"
@export var name_en: String = "Hard dirt"
@export var grip_peak: float = 0.86
@export var grip_slide: float = 0.68
@export var rolling_resistance: float = 0.035
@export var sink_depth_m: float = 0.0
@export var bumpiness: float = 0.35
@export var liquid: bool = false
@export var dust_amount: float = 0.5
@export var color_top: Color = Color(0.45, 0.33, 0.22)
@export var color_deep: Color = Color(0.18, 0.13, 0.10)
@export var particle_kind: String = "dust"
@export var sound_roll: String = "tire_roll_dirt"
@export var sound_slip: String = "skid"

func grip_for_slip(slip: float) -> float:
	var t: float = clampf(absf(slip) / 1.2, 0.0, 1.0)
	return lerpf(grip_peak, grip_slide, t)

func label(lang: String) -> String:
	return name_fa if lang == "fa" else name_en
