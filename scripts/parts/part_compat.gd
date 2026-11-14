class_name PartCompatibility
extends RefCounted
## Install rules for the parts system.
##
## A part is rejected only for a reason the player can act on, and the reason is
## returned as text in both languages. Soft penalties (a radiator that is marginal
## for the build, a fuel system that caps power) are warnings, not refusals: the
## car still drives, it just behaves like the badly-matched machine it is.

static func check(base: VehicleDef, cfg: Dictionary, part: PartDef) -> Dictionary:
	var reasons: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	if base == null or part == null:
		reasons.append(_r("قطعه نامعتبر است.", "Invalid part."))
		return {"ok": false, "reasons": reasons, "warnings": warnings}

	if not part.fits_vehicle(base.id, base.engine_family):
		reasons.append(_r(
			"این قطعه برای این خودرو یا این خانوادهٔ موتور ساخته نشده است.",
			"This part is not made for this vehicle or engine family."))

	var current: VehicleDef = GarageModel.build(base, cfg)
	var parts: Dictionary = current.parts.duplicate()

	match part.slot:
		PartDef.Slot.TYRES:
			var lift: PartDef = parts.get(PartDef.Slot.LIFT_KIT, null) as PartDef
			var allowed: float = base.max_tyre_radius_m if lift == null else lift.num("max_tyre_radius_m", base.max_tyre_radius_m)
			if part.num("radius_m", 0.0) > allowed + 0.001:
				reasons.append(_r(
					"این تایر به کیت بلند نیاز دارد؛ فضای گلگیر کافی نیست.",
					"This tyre needs a lift kit: there is not enough arch clearance."))
		PartDef.Slot.GEARBOX:
			var rating: float = part.num("max_torque_nm", 0.0)
			var torque: float = current.peak_torque_nm()
			if rating > 0.0 and rating < torque * 1.02:
				reasons.append(_r(
					"تحمل گشتاور گیربکس (%d نیوتون‌متر) از گشتاور موتور (%d) کمتر است." % [int(rating), int(torque)],
					"Gearbox torque rating (%d Nm) is below the engine torque (%d Nm)." % [int(rating), int(torque)]))
		PartDef.Slot.CLUTCH:
			var cap: float = part.num("capacity_nm", 0.0)
			if cap > 0.0 and cap < current.peak_torque_nm() * 1.02:
				reasons.append(_r(
					"ظرفیت کلاچ (%d نیوتون‌متر) برای این گشتاور کافی نیست." % int(cap),
					"Clutch capacity (%d Nm) cannot hold this torque." % int(cap)))
		PartDef.Slot.TURBO:
			var boost: float = part.num("boost_bar", 0.0)
			var block: PartDef = parts.get(PartDef.Slot.BLOCK, null) as PartDef
			var pistons: PartDef = parts.get(PartDef.Slot.PISTONS, null) as PartDef
			var block_limit: float = 99.0 if block == null else block.num("max_boost_bar", 99.0)
			var piston_limit: float = 99.0 if pistons == null else pistons.num("max_boost_bar", 99.0)
			var limit: float = minf(block_limit, piston_limit)
			if boost > limit + 0.001:
				reasons.append(_r(
					"بلوک و پیستون فعلی فشار %.2f بار را تحمل نمی‌کنند (سقف %.2f)." % [boost, limit],
					"The current block and pistons are not rated for %.2f bar (limit %.2f)." % [boost, limit]))
			var ic: PartDef = parts.get(PartDef.Slot.INTERCOOLER, null) as PartDef
			if ic == null or ic.num("charge_cool", 0.0) < 0.5:
				warnings.append(_r(
					"بدون اینترکولر کافی، هوای فشرده داغ می‌ماند و بخشی از بوست هدر می‌رود.",
					"Without enough charge cooling the intake air stays hot and part of the boost is wasted."))
		PartDef.Slot.INJECTORS, PartDef.Slot.FUEL_PUMP:
			warnings.append(_r(
				"قبل از نصب، سقف توان سیستم سوخت‌رسانی را با دینو بررسی کن.",
				"Check the fuel system ceiling on the dyno before you commit."))
		PartDef.Slot.RADIATOR:
			var heat: float = current.engine_build.heat_kw_full if current.engine_build != null else 0.0
			if part.num("heat_reject_kw", 0.0) < heat * 1.02:
				warnings.append(_r(
					"این رادیاتور برای توان فعلی مرزی است؛ در صعود طولانی دما بالا می‌رود.",
					"This radiator is marginal for the current power; temperature will climb on long ascents."))
		PartDef.Slot.SPRINGS, PartDef.Slot.DAMPERS:
			var lift2: PartDef = parts.get(PartDef.Slot.LIFT_KIT, null) as PartDef
			if lift2 != null and lift2.num("ride_add_m", 0.0) > 0.03:
				warnings.append(_r(
					"با کیت بلند، فنر و کمک‌فنر کوتاه‌تر کورس را محدود می‌کند.",
					"With a lift kit, short springs and dampers limit the available travel."))
		_:
			pass

	return {"ok": reasons.is_empty(), "reasons": reasons, "warnings": warnings}

## Every warning the current build carries, including the engine's own.
static func audit(base: VehicleDef, cfg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var built: VehicleDef = GarageModel.build(base, cfg)
	if built.engine_build != null:
		for w: Dictionary in built.engine_build.warnings:
			out.append(w)
	var gearbox: PartDef = built.parts.get(PartDef.Slot.GEARBOX, null) as PartDef
	if gearbox != null and gearbox.num("max_torque_nm", 0.0) < built.peak_torque_nm():
		out.append(_r("گیربکس در آستانهٔ تحمل گشتاور است.", "The gearbox is at its torque limit."))
	var clutch: PartDef = built.parts.get(PartDef.Slot.CLUTCH, null) as PartDef
	if clutch != null and clutch.num("capacity_nm", 0.0) < built.peak_torque_nm():
		out.append(_r("کلاچ در آستانهٔ ظرفیت است.", "The clutch is at its capacity limit."))
	return out

static func _r(fa: String, en: String) -> Dictionary:
	return {"fa": fa, "en": en}
