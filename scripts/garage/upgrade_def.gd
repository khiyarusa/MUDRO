class_name UpgradeDef
extends Resource
## A garage upgrade that mutates real simulation data (torque curves, ratios,
## spring rates, grip, mass, braking). No cosmetic-only statistics.

enum Category { ENGINE, GEARBOX, DIFFERENTIAL, SUSPENSION, TIRES, BRAKES, CHASSIS }

@export var id: String = "engine_1"
@export var category: Category = Category.ENGINE
@export var tier: int = 1
@export var name_fa: String = ""
@export var name_en: String = ""
@export var desc_fa: String = ""
@export var desc_en: String = ""
@export var cost: int = 400
## Multiplicative / additive modifiers consumed by GarageModel.apply_upgrade().
@export var torque_mult: float = 1.0
@export var torque_curve_bias: float = 0.0
@export var redline_add: float = 0.0
@export var gear_ratio_mult: float = 1.0
@export var final_drive_mult: float = 1.0
@export var shift_time_mult: float = 1.0
@export var spring_mult: float = 1.0
@export var damper_mult: float = 1.0
@export var travel_mult: float = 1.0
@export var grip_mult: float = 1.0
@export var rolling_mult: float = 1.0
@export var brake_mult: float = 1.0
@export var mass_add: float = 0.0
@export var durability_mult: float = 1.0
@export var clutch_mult: float = 1.0

func label(lang: String) -> String:
	return name_fa if lang == "fa" else name_en

func description(lang: String) -> String:
	return desc_fa if lang == "fa" else desc_en

func icon_name() -> String:
	match category:
		Category.ENGINE:
			return "engine"
		Category.GEARBOX:
			return "gearbox"
		Category.DIFFERENTIAL:
			return "differential"
		Category.SUSPENSION:
			return "suspension"
		Category.TIRES:
			return "tire"
		Category.BRAKES:
			return "brake_disc"
		_:
			return "chassis"

static func category_name(cat: int, lang: String) -> String:
	var fa: Array[String] = ["موتور", "گیربکس", "دیفرانسیل", "تعلیق", "لاستیک", "ترمز", "شاسی"]
	var en: Array[String] = ["Engine", "Gearbox", "Differential", "Suspension", "Tyres", "Brakes", "Chassis"]
	var idx: int = clampi(cat, 0, 6)
	return fa[idx] if lang == "fa" else en[idx]

static func category_icon(cat: int) -> String:
	var icons: Array[String] = ["engine", "gearbox", "differential", "suspension", "tire", "brake_disc", "chassis"]
	return icons[clampi(cat, 0, 6)]

## Human-readable list of the real values this upgrade changes.
func effects_summary(lang: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var pct := func(v: float) -> String:
		return "%+d%%" % int(round((v - 1.0) * 100.0))
	if torque_mult != 1.0:
		parts.append(("گشتاور " if lang == "fa" else "torque ") + pct.call(torque_mult))
	if redline_add != 0.0:
		parts.append(("سقف دور " if lang == "fa" else "redline ") + "+%d" % int(redline_add))
	if gear_ratio_mult != 1.0:
		parts.append(("نسبت دنده " if lang == "fa" else "ratios ") + pct.call(gear_ratio_mult))
	if final_drive_mult != 1.0:
		parts.append(("نسبت نهایی " if lang == "fa" else "final drive ") + pct.call(final_drive_mult))
	if shift_time_mult != 1.0:
		parts.append(("زمان تعویض " if lang == "fa" else "shift time ") + pct.call(shift_time_mult))
	if grip_mult != 1.0:
		parts.append(("چسبندگی " if lang == "fa" else "grip ") + pct.call(grip_mult))
	if spring_mult != 1.0:
		parts.append(("سختی فنر " if lang == "fa" else "spring rate ") + pct.call(spring_mult))
	if damper_mult != 1.0:
		parts.append(("میرایی " if lang == "fa" else "damping ") + pct.call(damper_mult))
	if travel_mult != 1.0:
		parts.append(("کورس " if lang == "fa" else "travel ") + pct.call(travel_mult))
	if rolling_mult != 1.0:
		parts.append(("مقاومت غلتشی " if lang == "fa" else "rolling drag ") + pct.call(rolling_mult))
	if brake_mult != 1.0:
		parts.append(("ترمز " if lang == "fa" else "braking ") + pct.call(brake_mult))
	if mass_add != 0.0:
		parts.append(("وزن " if lang == "fa" else "mass ") + "%+d kg" % int(mass_add))
	if durability_mult != 1.0:
		parts.append(("دوام " if lang == "fa" else "durability ") + pct.call(durability_mult))
	return " · ".join(parts)
