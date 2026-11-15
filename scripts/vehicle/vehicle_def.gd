class_name VehicleDef
extends Resource
## One real vehicle, described by the data its simulation actually needs.
##
## The engine, transmission, suspension and tyre blocks are the factory
## specification of a single documented model year and trim. The `spec` dictionary
## keeps the published figures (with their source reference) so
## docs/VEHICLE_SPEC_SOURCES.md and the in-game spec sheet can never drift away
## from the physics: a test rebuilds the stock engine from these numbers and
## compares it against the documented torque and power.

enum Drivetrain { FWD, RWD, AWD }

@export_group("Identity")
@export var id: String = "jimny_jb74"
@export var name_fa: String = ""
@export var name_en: String = ""
@export var class_fa: String = ""
@export var class_en: String = ""
@export_multiline var description_fa: String = ""
@export_multiline var description_en: String = ""
@export var manufacturer: String = ""
@export var model_year: int = 2020
@export var trim: String = ""
@export var price: int = 0
@export var unlock_track: String = ""

@export_group("Documented specification")
## Published figures and the reference used for them (see VEHICLE_SPEC_SOURCES.md).
@export var spec: Dictionary = {}
@export var tyre_size_label: String = ""
@export var suspension_arch: String = ""
@export var drivetrain_label: String = ""
@export var fuel_type: String = "diesel"
## Published power and torque of the documented variant. Tests compare the
## parts-derived engine against these figures.
@export var doc_power_kw: float = 0.0
@export var doc_torque_nm: float = 0.0
@export var doc_power_rpm: float = 0.0
@export var doc_torque_rpm: float = 0.0
## End of the published torque plateau, in rpm (e.g. "420 Nm @ 1400-3400 rpm" ->
## 3400). 0 means "not documented" and the engine model falls back to a generic
## plateau. Without this a high-torque diesel loses power long before its
## published power peak.
@export var engine_hold_rpm: float = 0.0

@export_group("Mass and geometry")
@export var mass_kg: float = 1100.0
@export var wheelbase_m: float = 2.25
@export var length_m: float = 3.65
@export var width_m: float = 1.65
@export var height_m: float = 1.70
@export var com_height_m: float = 0.42
@export var body_polygon_m: PackedVector2Array = PackedVector2Array()
@export var frontal_area_m2: float = 1.9
@export var drag_cd: float = 0.55
@export var inertia_scale: float = 1.0

@export_group("Drivetrain")
@export var drivetrain: Drivetrain = Drivetrain.AWD
@export var torque_split_front: float = 0.4
@export var brake_torque_front: float = 2000.0
@export var brake_torque_rear: float = 1400.0
@export var handbrake_torque: float = 2600.0
@export var clutch_capacity: float = 380.0
@export var clutch_stiffness: float = 2.6
## Pedal travel at which the plates are half engaged, from the fitted clutch part.
@export var clutch_bite_point: float = 0.62
## How fast a released pedal clamps the plates (engagement per second).
@export var clutch_clamp_rate: float = 5.5
## Slip energy the cover absorbs per unit of fade (kW·s).
@export var clutch_heat_capacity: float = 45.0
## Fraction of capacity lost at full heat.
@export var clutch_fade_limit: float = 0.30

@export_group("Engine data for the parts system")
@export var engine_family: String = "k15b"
@export var engine_code: String = "K15B"
@export var aspiration: String = "na"
@export var compression: float = 10.5
@export var displacement_cc: int = 1462
@export var cylinders: int = 4
@export var stock_boost_bar: float = 0.0
@export var stock_spool_rpm: float = 0.0
@export var injector_flow_cc: float = 220.0
@export var injector_max_kw: float = 90.0
@export var pump_lph: float = 90.0
@export var pump_max_kw: float = 95.0
@export var radiator_kw: float = 45.0
@export var coolant_l: float = 5.0
@export var max_tyre_radius_m: float = 0.36
## Calibrates the generic engine model to this engine's published torque.
@export var engine_torque_scale: float = 1.0

@export_group("Components")
@export var engine: EngineConfig
@export var gearbox: GearboxConfig
@export var tire_front: TireConfig
@export var tire_rear: TireConfig
@export var suspension: SuspensionConfig

@export_group("Transmission")
@export var transmissions: Array[TransmissionProfile] = []
@export var stock_transmission: String = ""
@export var transfer_ids: PackedStringArray = PackedStringArray()
@export var transfer_ratios: PackedFloat32Array = PackedFloat32Array()
@export var default_transfer: String = ""
@export var diff_modes: PackedStringArray = PackedStringArray(["open", "lsd"])
@export var default_diff: String = "open"

@export_group("Configuration")
@export var tire_options: Array[Dictionary] = []
@export var suspension_options: Array[Dictionary] = []

@export_group("Recovery")
@export var has_winch: bool = false
@export var winch_force_n: float = 18000.0
@export var winch_rope_m: float = 18.0
@export var winch_speed_mps: float = 1.4

@export_group("Damage")
@export var durability: float = 1.0
@export var impact_tolerance: float = 9.0

@export_group("Presentation")
@export var sprite_body: String = "res://assets/vehicles/jimny_jb74/body.svg"
@export var sprite_wheel: String = "res://assets/vehicles/jimny_jb74/wheel.svg"
@export var art_scale_px_per_m: float = 160.0
@export var accent_color: Color = Color(0.82, 0.58, 0.24)

## ---------------------------------------------------------------- runtime ---
## Fitted part per PartDef.Slot. Never authored: GarageModel fills this in from
## the player's save so the shared Content resource is never mutated.
var parts: Dictionary = {}
var part_conditions: Dictionary = {}
var engine_build: EngineBuild = null
var build_info: Dictionary = {}
var fitted_transmission: String = ""
var fitted_tires: String = ""
var fitted_suspension: String = ""
var active_transfer: String = ""
var active_diff: String = ""
var active_winch: bool = false
var ride_height_add_m: float = 0.0
var lift_com_add_m: float = 0.0
var extra_mass_kg: float = 0.0
var protection: float = 0.0
var water_ford_m: float = 0.4
var light_range_m: float = 40.0

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
	if engine_build != null:
		return engine_build.peak_power_kw
	return engine.peak_power_kw() if engine != null else 0.0

func peak_torque_nm() -> float:
	if engine_build != null:
		return engine_build.peak_torque_nm
	return engine.peak_torque() if engine != null else 0.0

func power_rpm() -> float:
	if engine_build != null:
		return engine_build.peak_power_rpm
	return engine.redline_rpm * 0.8 if engine != null else 0.0

func torque_rpm() -> float:
	if engine_build != null:
		return engine_build.peak_torque_rpm
	return engine.redline_rpm * 0.5 if engine != null else 0.0

func top_speed_kmh() -> float:
	if gearbox == null or engine == null:
		return 0.0
	return Units.px2kmh(gearbox.top_speed_mps(tire_rear.radius_m, engine.max_rpm) * Units.PPM)

func mass_per_hp() -> float:
	var hp: float = peak_power_kw() * 1.341
	return mass_kg / maxf(hp, 1.0)

func spec_value(key: String, fallback: Variant = null) -> Variant:
	return spec.get(key, fallback)

func duplicate_def() -> VehicleDef:
	return duplicate(true) as VehicleDef
