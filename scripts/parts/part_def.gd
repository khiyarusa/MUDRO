class_name PartDef
extends Resource
## One installable component. A part is data, not a multiplier: its `params`
## dictionary is consumed by EngineBuild, GarageModel or VehicleBody depending on
## the slot, so fitting a part changes the simulation in a way the dyno and the
## physics can both observe.

enum Slot {
	BLOCK, PISTONS, CRANKSHAFT, CONRODS, CAMSHAFT, HEAD,
	INTAKE, THROTTLE, EXHAUST, ECU, TURBO, INTERCOOLER,
	INJECTORS, FUEL_PUMP, RADIATOR, WATER_PUMP, FAN, THERMOSTAT,
	CLUTCH, GEARBOX, TRANSFER, DIFFERENTIAL,
	SPRINGS, DAMPERS, BUSHINGS, BUMP_STOPS, ARMS, LIFT_KIT,
	TYRES, BRAKE_PADS, BRAKE_DISCS,
	BUMPER_FRONT, BUMPER_REAR, FENDER_FLARE, HOOD, ROOF_RACK,
	SKID_PLATE, SLIDERS, ROLL_CAGE, WINCH, SNORKEL, LIGHTS, RIMS,
}

enum Condition { NEW, USED, WORN, DAMAGED, BROKEN }

const CONDITION_MULT: Dictionary = {
	Condition.NEW: 1.0,
	Condition.USED: 0.96,
	Condition.WORN: 0.90,
	Condition.DAMAGED: 0.74,
	Condition.BROKEN: 0.0,
}

const SLOT_NAMES_FA: Dictionary = {
	Slot.BLOCK: "بلوک موتور", Slot.PISTONS: "پیستون", Slot.CRANKSHAFT: "میل‌لنگ",
	Slot.CONRODS: "شاتون", Slot.CAMSHAFT: "میل‌سوپاپ", Slot.HEAD: "سرسیلندر",
	Slot.INTAKE: "منیفولد هوا", Slot.THROTTLE: "دریچه گاز", Slot.EXHAUST: "اگزوز",
	Slot.ECU: "ای‌سی‌یو", Slot.TURBO: "توربوشارژ", Slot.INTERCOOLER: "اینترکولر",
	Slot.INJECTORS: "انژکتور", Slot.FUEL_PUMP: "پمپ سوخت", Slot.RADIATOR: "رادیاتور",
	Slot.WATER_PUMP: "واترپمپ", Slot.FAN: "پنکه خنک‌کاری", Slot.THERMOSTAT: "ترموستات",
	Slot.CLUTCH: "کلاچ", Slot.GEARBOX: "گیربکس", Slot.TRANSFER: "جعبه‌دنده کمکی",
	Slot.DIFFERENTIAL: "دیفرانسیل", Slot.SPRINGS: "فنر", Slot.DAMPERS: "کمک‌فنر",
	Slot.BUSHINGS: "بوش", Slot.BUMP_STOPS: "بامپ‌استاپ", Slot.ARMS: "بازوی تعلیق",
	Slot.LIFT_KIT: "کیت بلند", Slot.TYRES: "تایر", Slot.BRAKE_PADS: "لنت ترمز",
	Slot.BRAKE_DISCS: "دیسک ترمز", Slot.BUMPER_FRONT: "سپر جلو", Slot.BUMPER_REAR: "سپر عقب",
	Slot.FENDER_FLARE: "فلر گلگیر", Slot.HOOD: "کاپوت", Slot.ROOF_RACK: "باربند",
	Slot.SKID_PLATE: "پلاک محافظ", Slot.SLIDERS: "راک‌اسلایدر", Slot.ROLL_CAGE: "قفس ایمنی",
	Slot.WINCH: "وینچ", Slot.SNORKEL: "اسنورکل", Slot.LIGHTS: "چراغ", Slot.RIMS: "رینگ",
}

const SLOT_NAMES_EN: Dictionary = {
	Slot.BLOCK: "Engine block", Slot.PISTONS: "Pistons", Slot.CRANKSHAFT: "Crankshaft",
	Slot.CONRODS: "Connecting rods", Slot.CAMSHAFT: "Camshaft", Slot.HEAD: "Cylinder head",
	Slot.INTAKE: "Intake", Slot.THROTTLE: "Throttle body", Slot.EXHAUST: "Exhaust",
	Slot.ECU: "ECU", Slot.TURBO: "Turbocharger", Slot.INTERCOOLER: "Intercooler",
	Slot.INJECTORS: "Fuel injectors", Slot.FUEL_PUMP: "Fuel pump", Slot.RADIATOR: "Radiator",
	Slot.WATER_PUMP: "Water pump", Slot.FAN: "Cooling fan", Slot.THERMOSTAT: "Thermostat",
	Slot.CLUTCH: "Clutch", Slot.GEARBOX: "Gearbox", Slot.TRANSFER: "Transfer case",
	Slot.DIFFERENTIAL: "Differential", Slot.SPRINGS: "Springs", Slot.DAMPERS: "Dampers",
	Slot.BUSHINGS: "Bushings", Slot.BUMP_STOPS: "Bump stops", Slot.ARMS: "Suspension arms",
	Slot.LIFT_KIT: "Lift kit", Slot.TYRES: "Tyres", Slot.BRAKE_PADS: "Brake pads",
	Slot.BRAKE_DISCS: "Brake discs", Slot.BUMPER_FRONT: "Front bumper", Slot.BUMPER_REAR: "Rear bumper",
	Slot.FENDER_FLARE: "Fender flares", Slot.HOOD: "Hood", Slot.ROOF_RACK: "Roof rack",
	Slot.SKID_PLATE: "Skid plate", Slot.SLIDERS: "Rock sliders", Slot.ROLL_CAGE: "Roll cage",
	Slot.WINCH: "Winch", Slot.SNORKEL: "Snorkel", Slot.LIGHTS: "Lights", Slot.RIMS: "Wheels",
}

@export var id: String = ""
@export var slot: Slot = Slot.BLOCK
@export var name_fa: String = ""
@export var name_en: String = ""
@export_multiline var desc_fa: String = ""
@export_multiline var desc_en: String = ""
@export var cost: int = 0
@export var mass_kg: float = 0.0
## Slot-specific numbers. See docs/TUNING_SYSTEM.md for the key list per slot.
@export var params: Dictionary = {}
## Empty means the part fits any vehicle; otherwise it is engine-family specific.
@export var engine_family: String = ""
## Empty means all vehicles; otherwise only these vehicle ids.
@export var fits_vehicles: PackedStringArray = PackedStringArray()
@export var tier: int = 1
@export var condition: Condition = Condition.NEW
@export var wear_rate: float = 0.0

func label(lang: String) -> String:
	return name_fa if lang == "fa" else name_en

func description(lang: String) -> String:
	return desc_fa if lang == "fa" else desc_en

func slot_label(lang: String) -> String:
	var table: Dictionary = SLOT_NAMES_FA if lang == "fa" else SLOT_NAMES_EN
	return String(table.get(slot, "—"))

func num(key: String, fallback: float = 0.0) -> float:
	return float(params.get(key, fallback))

func text(key: String, fallback: String = "") -> String:
	return String(params.get(key, fallback))

func floats(key: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var raw: Variant = params.get(key, [])
	if raw is Array:
		for v: Variant in (raw as Array):
			out.append(float(v))
	return out

func strings(key: String) -> PackedStringArray:
	var out := PackedStringArray()
	var raw: Variant = params.get(key, [])
	if raw is Array:
		for v: Variant in (raw as Array):
			out.append(String(v))
	return out

func condition_mult() -> float:
	return float(CONDITION_MULT.get(condition, 1.0))

func condition_label(lang: String) -> String:
	match condition:
		Condition.NEW:
			return "نو" if lang == "fa" else "New"
		Condition.USED:
			return "کارکرده" if lang == "fa" else "Used"
		Condition.WORN:
			return "فرسوده" if lang == "fa" else "Worn"
		Condition.DAMAGED:
			return "آسیب‌دیده" if lang == "fa" else "Damaged"
		_:
			return "خراب" if lang == "fa" else "Broken"

func fits_vehicle(vehicle_id: String, family: String) -> bool:
	if not fits_vehicles.is_empty() and not fits_vehicles.has(vehicle_id):
		return false
	if not engine_family.is_empty() and engine_family != family:
		return false
	return true

## Human-readable summary of the numbers that actually matter for this slot.
func effect_lines(lang: String, stock: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	match slot:
		Slot.TURBO:
			out.append(_line(lang, "boost", "فشار", "Boost", "%.2f bar" % num("boost_bar")))
			out.append(_line(lang, "spool", "شروع", "Spool", "%d rpm" % int(num("spool_rpm"))))
			out.append(_line(lang, "heat", "بار حرارتی", "Heat load", "%.2fx" % num("heat_mult", 1.0)))
		Slot.INJECTORS:
			out.append(_line(lang, "flow", "دبی", "Flow", "%d cc" % int(num("flow_cc"))))
			out.append(_line(lang, "limit", "سقف توان", "Power cap", "%d kW" % int(num("max_power_kw"))))
		Slot.FUEL_PUMP:
			out.append(_line(lang, "flow", "دبی", "Flow", "%d L/h" % int(num("flow_lph"))))
			out.append(_line(lang, "limit", "سقف توان", "Power cap", "%d kW" % int(num("max_power_kw"))))
		Slot.RADIATOR:
			out.append(_line(lang, "reject", "دفع حرارت", "Heat rejection", "%.0f kW" % num("heat_reject_kw")))
			out.append(_line(lang, "cap", "ظرفیت", "Capacity", "%.1f L" % num("capacity_l", 8.0)))
		Slot.ECU:
			out.append(_line(lang, "boost", "هدف بوست", "Boost target", "%.2f bar" % num("boost_target_bar")))
			out.append(_line(lang, "rev", "سقف دور", "Rev limit", "%d rpm" % int(num("rev_limit"))))
		Slot.CLUTCH:
			out.append(_line(lang, "cap", "ظرفیت", "Capacity", "%d Nm" % int(num("capacity_nm"))))
			out.append(_line(lang, "bite", "نقطه درگیری", "Bite point", "%.0f%%" % (num("bite_point", 0.62) * 100.0)))
		Slot.GEARBOX:
			out.append(_line(lang, "final", "نسبت نهایی", "Final drive", "%.2f" % num("final_drive")))
			out.append(_line(lang, "shift", "زمان تعویض", "Shift time", "%.2f s" % num("shift_time")))
			out.append(_line(lang, "torque", "تحمل گشتاور", "Torque rating", "%d Nm" % int(num("max_torque_nm"))))
		Slot.TYRES:
			out.append(_line(lang, "radius", "شعاع", "Radius", "%.3f m" % num("radius_m")))
			out.append(_line(lang, "grip", "چسبندگی", "Peak grip", "%.2f µ" % num("mu_peak")))
			out.append(_line(lang, "rr", "مقاومت غلتشی", "Rolling resistance", "%.3f" % num("rr")))
		Slot.SPRINGS:
			out.append(_line(lang, "spring", "سختی فنر", "Spring rate", "%.2fx" % num("spring_mult", 1.0)))
		Slot.DAMPERS:
			out.append(_line(lang, "comp", "میرایی تراکم", "Compression", "%.2fx" % num("compression_mult", 1.0)))
			out.append(_line(lang, "reb", "میرایی بازگشت", "Rebound", "%.2fx" % num("rebound_mult", 1.0)))
		Slot.BRAKE_PADS, Slot.BRAKE_DISCS:
			out.append(_line(lang, "brake", "نیروی ترمز", "Brake force", "%.2fx" % num("brake_mult", 1.0)))
		Slot.LIFT_KIT:
			out.append(_line(lang, "ride", "ارتفاع", "Ride height", "+%d mm" % int(num("ride_add_m") * 1000.0)))
			out.append(_line(lang, "travel", "کورس", "Travel", "%.2fx" % num("travel_mult", 1.0)))
		Slot.DIFFERENTIAL:
			out.append(_line(lang, "mode", "حالت", "Mode", text("mode", "lsd")))
			out.append(_line(lang, "grip", "کشش", "Traction", "%.2fx" % num("grip_mult", 1.0)))
		_:
			if mass_kg != 0.0:
				out.append(_line(lang, "mass", "جرم", "Mass", "%+.0f kg" % mass_kg))
			if num("flow_mult", 1.0) != 1.0:
				out.append(_line(lang, "flow", "جریان", "Flow", "%.2fx" % num("flow_mult")))
			if num("durability_mult", 1.0) != 1.0:
				out.append(_line(lang, "durability", "دوام", "Durability", "%.2fx" % num("durability_mult")))
	return out

func _line(_lang: String, _key: String, fa: String, en: String, value: String) -> String:
	var name: String = fa if _lang == "fa" else en
	return "%s: %s" % [name, value]
