extends Node
## ContentDB (autoload "Content"): the single runtime source of game data.
##
## MUDRO 3.0 replaces the obstacle-stage catalogue with mountain tracks, and the
## flat upgrade list with a real parts catalogue. Everything is built from typed
## authoring tables at boot: surfaces, the five documented vehicles, every part,
## the five mountain regions and their fifteen tracks.

var surfaces: Dictionary = {}
var vehicles: Array[VehicleDef] = []
var tracks: Array[TrackDef] = []
var parts: Array[PartDef] = []
var regions: Array[Dictionary] = []

var _parts_by_id: Dictionary = {}
var _stock_by_vehicle: Dictionary = {}

func _ready() -> void:
	_build_surfaces()
	_build_vehicles()
	_build_parts()
	_build_regions()
	_build_tracks()

# ---------------------------------------------------------------- surfaces ---

func _build_surfaces() -> void:
	_add_surface("asphalt", "آسفالت", "Asphalt", 0.96, 0.82, 0.012, 0.05,
		Color(0.20, 0.21, 0.23), Color(0.09, 0.09, 0.10), "dust", "tire_roll_dirt", 0.25)
	_add_surface("hard_dirt", "خاک سفت", "Hard dirt", 0.86, 0.68, 0.032, 0.35,
		Color(0.47, 0.34, 0.22), Color(0.16, 0.11, 0.08), "dust", "tire_roll_dirt", 0.6)
	_add_surface("gravel", "ریگ", "Gravel", 0.74, 0.60, 0.042, 0.62,
		Color(0.52, 0.50, 0.46), Color(0.19, 0.18, 0.17), "dust", "tire_roll_gravel", 0.8)
	_add_surface("loose_sand", "شن روان", "Loose sand", 0.62, 0.48, 0.090, 0.38,
		Color(0.78, 0.62, 0.38), Color(0.42, 0.30, 0.16), "sand", "tire_roll_gravel", 0.05)
	_add_surface("mud", "گل", "Mud", 0.44, 0.31, 0.140, 0.18,
		Color(0.36, 0.25, 0.15), Color(0.14, 0.09, 0.05), "mud", "mud_loop", 0.06)
	_add_surface("wet_mud", "گل خیس", "Wet mud", 0.31, 0.22, 0.170, 0.12,
		Color(0.28, 0.22, 0.14), Color(0.10, 0.08, 0.05), "mud", "mud_loop", 0.08)
	_add_surface("rock", "صخره", "Rock", 0.93, 0.79, 0.028, 0.85,
		Color(0.44, 0.40, 0.36), Color(0.15, 0.14, 0.13), "dust", "tire_roll_gravel", 0.5)
	_add_surface("snow", "برف", "Snow", 0.39, 0.28, 0.070, 0.30,
		Color(0.88, 0.91, 0.95), Color(0.46, 0.53, 0.62), "snow", "tire_roll_dirt", 0.9)
	_add_surface("ice", "یخ", "Ice", 0.15, 0.09, 0.014, 0.05,
		Color(0.66, 0.80, 0.89), Color(0.28, 0.40, 0.50), "snow", "skid", 0.7)
	_add_surface("water", "آب", "Water", 0.22, 0.15, 0.260, 0.10,
		Color(0.25, 0.40, 0.42), Color(0.07, 0.14, 0.16), "water", "mud_loop", 0.0)
	_add_surface("ash", "خاکستر", "Ash", 0.58, 0.42, 0.105, 0.30,
		Color(0.36, 0.35, 0.33), Color(0.13, 0.13, 0.13), "dust", "tire_roll_gravel", 0.0)
	_add_surface("scree", "سنگ‌ریزه", "Scree", 0.66, 0.50, 0.075, 0.55,
		Color(0.32, 0.32, 0.31), Color(0.11, 0.11, 0.11), "dust", "tire_roll_rock", 0.0)
	_add_surface("steel", "عرشه فولادی", "Steel deck", 0.72, 0.58, 0.030, 0.18,
		Color(0.30, 0.31, 0.32), Color(0.12, 0.12, 0.13), "dust", "bridge_rumble", 0.0)

func _add_surface(id: String, fa: String, en: String, peak: float, slide: float,
		rr: float, sink: float, top: Color, deep: Color, particles: String,
		sound: String, liquid_grip: float) -> void:
	var s := SurfaceProfile.new()
	s.id = id
	s.name_fa = fa
	s.name_en = en
	s.grip_peak = peak
	s.grip_slide = slide
	s.rolling_resistance = rr
	s.sink_depth_m = sink
	s.bumpiness = sink if sink > 0.0 else 0.2
	s.color_top = top
	s.color_deep = deep
	s.particle_kind = particles
	s.sound_roll = sound
	s.liquid = liquid_grip < 0.0
	surfaces[id] = s

# ---------------------------------------------------------------- vehicles ---

func _build_vehicles() -> void:
	vehicles = VehicleCatalog.build_all()

func _build_parts() -> void:
	parts = PartsCatalog.build_for(vehicles)
	_parts_by_id.clear()
	_stock_by_vehicle.clear()
	for p: PartDef in parts:
		_parts_by_id[p.id] = p
		if p.tier == 0:
			if not _stock_by_vehicle.has(p.fits_vehicles[0]):
				_stock_by_vehicle[p.fits_vehicles[0]] = {}
			(_stock_by_vehicle[p.fits_vehicles[0]] as Dictionary)[p.slot] = p

func _build_regions() -> void:
	regions = []
	for entry: Dictionary in TrackCatalog.REGIONS:
		regions.append((entry as Dictionary).duplicate(true))

func _build_tracks() -> void:
	tracks = TrackCatalog.build_all()

# ------------------------------------------------------------------ lookup ---

func vehicle_by_id(id: String) -> VehicleDef:
	for v: VehicleDef in vehicles:
		if v.id == id:
			return v
	return null

func vehicle_index(id: String) -> int:
	for i: int in range(vehicles.size()):
		if vehicles[i].id == id:
			return i
	return -1

func track_by_id(id: String) -> TrackDef:
	for t: TrackDef in tracks:
		if t.id == id:
			return t
	return null

func tracks_for_region(region: String) -> Array[TrackDef]:
	var out: Array[TrackDef] = []
	for t: TrackDef in tracks:
		if t.region == region:
			out.append(t)
	return out

func region_meta(id: String) -> Dictionary:
	for r: Dictionary in regions:
		if String(r["id"]) == id:
			return r
	return {}

func first_track_of(region: String) -> TrackDef:
	var list: Array[TrackDef] = tracks_for_region(region)
	return list[0] if not list.is_empty() else null

func part_by_id(id: String) -> PartDef:
	return _parts_by_id.get(id, null) as PartDef

func parts_for_slot(vehicle_id: String, slot: int) -> Array[PartDef]:
	var out: Array[PartDef] = []
	for p: PartDef in parts:
		if p.slot == slot and p.fits_vehicles.has(vehicle_id):
			out.append(p)
	out.sort_custom(func(a: PartDef, b: PartDef) -> bool: return a.tier < b.tier)
	return out

func parts_for_category(vehicle_id: String, slots: Array) -> Array[PartDef]:
	var out: Array[PartDef] = []
	for p: PartDef in parts:
		if p.fits_vehicles.has(vehicle_id) and slots.has(p.slot):
			out.append(p)
	out.sort_custom(func(a: PartDef, b: PartDef) -> bool:
		if a.slot == b.slot:
			return a.tier < b.tier
		return int(a.slot) < int(b.slot))
	return out

func parts_for_vehicle(vehicle_id: String) -> Array[PartDef]:
	var out: Array[PartDef] = []
	for p: PartDef in parts:
		if p.fits_vehicles.has(vehicle_id):
			out.append(p)
	return out

func stock_part(vehicle_id: String, slot: int) -> PartDef:
	var table: Dictionary = _stock_by_vehicle.get(vehicle_id, {})
	return table.get(slot, null) as PartDef

func part_count() -> int:
	return parts.size()

## Slots grouped the way the workshop is laid out.
static func category_slots() -> Dictionary:
	return {
		"engine": [PartDef.Slot.BLOCK, PartDef.Slot.PISTONS, PartDef.Slot.CRANKSHAFT,
			PartDef.Slot.CONRODS, PartDef.Slot.CAMSHAFT, PartDef.Slot.HEAD,
			PartDef.Slot.INTAKE, PartDef.Slot.THROTTLE, PartDef.Slot.EXHAUST,
			PartDef.Slot.ECU, PartDef.Slot.TURBO, PartDef.Slot.INTERCOOLER,
			PartDef.Slot.INJECTORS, PartDef.Slot.FUEL_PUMP, PartDef.Slot.RADIATOR,
			PartDef.Slot.WATER_PUMP, PartDef.Slot.FAN, PartDef.Slot.THERMOSTAT],
		"transmission": [PartDef.Slot.CLUTCH, PartDef.Slot.GEARBOX,
			PartDef.Slot.TRANSFER, PartDef.Slot.DIFFERENTIAL],
		"suspension": [PartDef.Slot.SPRINGS, PartDef.Slot.DAMPERS, PartDef.Slot.BUSHINGS,
			PartDef.Slot.BUMP_STOPS, PartDef.Slot.ARMS, PartDef.Slot.LIFT_KIT],
		"tyres": [PartDef.Slot.TYRES, PartDef.Slot.RIMS],
		"brakes": [PartDef.Slot.BRAKE_PADS, PartDef.Slot.BRAKE_DISCS],
		"body": [PartDef.Slot.BUMPER_FRONT, PartDef.Slot.BUMPER_REAR, PartDef.Slot.FENDER_FLARE,
			PartDef.Slot.HOOD, PartDef.Slot.ROOF_RACK, PartDef.Slot.SKID_PLATE,
			PartDef.Slot.SLIDERS, PartDef.Slot.ROLL_CAGE, PartDef.Slot.WINCH,
			PartDef.Slot.SNORKEL, PartDef.Slot.LIGHTS],
	}
