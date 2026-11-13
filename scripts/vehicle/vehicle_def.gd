class_name VehicleDef
extends Resource
## Complete data definition of a vehicle. Everything the simulation needs is here,
## so the four machines behave differently for mechanical reasons, not cosmetic ones.

enum Drivetrain { FWD, RWD, AWD }

@export_group("Identity")
@export var id: String = "ranger_4x4"
@export var name_fa: String = "رنجر"
@export var name_en: String = "RANGER 4X4"
@export var class_fa: String = "شاسی‌بلند"
@export var class_en: String = "Expedition 4x4"
@export_multiline var description_fa: String = ""
@export_multiline var description_en: String = ""
@export var price: int = 0
@export var unlock_stage: String = ""

@export_group("Mass and geometry")
@export var mass_kg: float = 1180.0
@export var wheelbase_m: float = 2.7
@export var length_m: float = 4.3
@export var height_m: float = 1.95
@export var com_height_m: float = 0.30
@export var body_polygon_m: PackedVector2Array = PackedVector2Array()
@export var frontal_area_m2: float = 2.3
@export var drag_cd: float = 0.62
@export var inertia_scale: float = 1.0

@export_group("Drivetrain")
@export var drivetrain: Drivetrain = Drivetrain.AWD
@export var torque_split_front: float = 0.42
@export var brake_torque_front: float = 2100.0
@export var brake_torque_rear: float = 1500.0
@export var handbrake_torque: float = 3200.0
@export var clutch_capacity: float = 420.0
@export var clutch_stiffness: float = 2.6

@export_group("Components")
@export var engine: EngineConfig
@export var gearbox: GearboxConfig
@export var tire_front: TireConfig
@export var tire_rear: TireConfig
@export var suspension: SuspensionConfig

@export_group("Transmission 2.0")
## Every transmission this vehicle can legally be built with. The first entry is
## the stock box; the player may only choose from this list.
@export var transmissions: Array[TransmissionProfile] = []
@export var stock_transmission: String = ""
## Transfer case positions the vehicle actually has (empty = single-speed).
@export var transfer_ids: PackedStringArray = PackedStringArray()
@export var transfer_ratios: PackedFloat32Array = PackedFloat32Array()
## Position the vehicle starts a run in when the player has no saved choice.
## For an off-road game that is 4H, not 2H: 2H is a road mode, not a trail mode.
@export var default_transfer: String = ""
## Differential options: "open", "lsd", "locked".
@export var diff_modes: PackedStringArray = PackedStringArray(["open", "lsd"])
@export var default_diff: String = "open"

@export_group("Configuration")
## Tyre sets the player may fit. Each: {id, name_fa, name_en, mu_mult, rr_mult}.
@export var tire_options: Array[Dictionary] = []
## Suspension setups. Each: {id, name_fa, name_en, spring_mult, damper_mult, travel_mult, ride_mult}.
@export var suspension_options: Array[Dictionary] = []

@export_group("Recovery")
@export var has_winch: bool = false
@export var winch_force_n: float = 18000.0
@export var winch_rope_m: float = 18.0
@export var winch_speed_mps: float = 1.4

## Runtime configuration chosen in the garage (applied by GarageModel on the copy).
## `fitted_transmission` overrides `stock_transmission` for this run without
## pretending the car was born with that box.
var fitted_transmission: String = ""
var fitted_tires: String = ""
var fitted_suspension: String = ""
var active_transfer: String = ""
var active_diff: String = ""
var active_winch: bool = false

@export_group("Damage")
@export var durability: float = 1.0
@export var impact_tolerance: float = 9.0

@export_group("Presentation")
@export var sprite_body: String = "res://assets/vehicles/ranger_4x4/body.svg"
@export var sprite_wheel: String = "res://assets/vehicles/ranger_4x4/wheel.svg"
@export var art_scale_px_per_m: float = 160.0
@export var accent_color: Color = Color(0.86, 0.55, 0.22)

func is_axle_driven(axle: int) -> bool:
	match drivetrain:
		Drivetrain.FWD:
			return axle == 0
		Drivetrain.RWD:
			return axle == 1
		_:
			return true

func axle_torque_share(axle: int, transfer_front: bool = true) -> float:
	if not is_axle_driven(axle):
		return 0.0
	if axle == 0 and not transfer_front:
		return 0.0
	if drivetrain != Drivetrain.AWD:
		return 1.0
	return torque_split_front if axle == 0 else 1.0 - torque_split_front

func transmission_by_id(id: String) -> TransmissionProfile:
	for t: TransmissionProfile in transmissions:
		if t.id == id:
			return t
	return null

func stock_transmission_profile() -> TransmissionProfile:
	if not transmissions.is_empty():
		var wanted: String = fitted_transmission if not fitted_transmission.is_empty() else stock_transmission
		var chosen: TransmissionProfile = transmission_by_id(wanted)
		return chosen if chosen != null else transmissions[0]
	if gearbox != null:
		return gearbox.to_profile()
	return null

func fitted_transmission_profile() -> TransmissionProfile:
	return stock_transmission_profile()

func transmission_options() -> Array[TransmissionProfile]:
	var out: Array[TransmissionProfile] = []
	for t: TransmissionProfile in transmissions:
		out.append(t)
	if out.is_empty() and gearbox != null:
		out.append(gearbox.to_profile())
	return out

func has_transfer_case() -> bool:
	return transfer_ids.size() > 1

func tire_option_by_id(id: String) -> Dictionary:
	for o: Dictionary in tire_options:
		if String(o.get("id", "")) == id:
			return o
	return {}

func suspension_option_by_id(id: String) -> Dictionary:
	for o: Dictionary in suspension_options:
		if String(o.get("id", "")) == id:
			return o
	return {}

func tire_for(axle: int) -> TireConfig:
	return tire_front if axle == 0 else tire_rear

func label(lang: String) -> String:
	return name_fa if lang == "fa" else name_en

func class_label(lang: String) -> String:
	return class_fa if lang == "fa" else class_en

func description(lang: String) -> String:
	return description_fa if lang == "fa" else description_en

func peak_power_kw() -> float:
	return engine.peak_power_kw() if engine != null else 0.0

func top_speed_kmh() -> float:
	if gearbox == null or engine == null:
		return 0.0
	return Units.px2kmh(gearbox.top_speed_mps(tire_rear.radius_m, engine.max_rpm) * Units.PPM)

func mass_per_hp() -> float:
	var hp: float = peak_power_kw() * 1.341
	return mass_kg / maxf(hp, 1.0)

func duplicate_def() -> VehicleDef:
	return duplicate(true) as VehicleDef
