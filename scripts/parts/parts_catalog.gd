class_name PartsCatalog
extends RefCounted
## Builds the MUDRO 3.0 parts catalogue from each vehicle's real engine data.
##
## Nothing here is a flat "+10 % power" upgrade. Every part carries the numbers its
## own subsystem consumes: a turbo has a boost target, a spool speed and a heat
## load; injectors have a flow and a power ceiling; a radiator has a heat-rejection
## rating; springs have a rate; tyres have a radius, a compound and per-surface
## grip modifiers. EngineBuild and GarageModel turn those numbers into a car that
## behaves differently, and the dyno reports the result.

const S = PartDef.Slot

static func build_for(vehicles: Array[VehicleDef]) -> Array[PartDef]:
	var out: Array[PartDef] = []
	for v: VehicleDef in vehicles:
		out.append_array(engine_parts(v))
		out.append_array(driveline_parts(v))
		out.append_array(chassis_parts(v))
		out.append_array(tyre_parts(v))
		out.append_array(brake_parts(v))
		out.append_array(body_parts(v))
	return out

# ------------------------------------------------------------------ helpers ---

static func _p(id: String, slot: int, fa: String, en: String, df: String, de: String,
		cost: int, mass: float, params: Dictionary, v: VehicleDef, tier: int = 1) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.slot = slot
	p.name_fa = fa
	p.name_en = en
	p.desc_fa = df
	p.desc_en = de
	p.cost = cost
	p.mass_kg = mass
	p.params = params
	p.engine_family = v.engine_family if _engine_slot(slot) else ""
	p.fits_vehicles = PackedStringArray([v.id])
	p.tier = tier
	return p

static func _engine_slot(slot: int) -> bool:
	return slot <= S.THERMOSTAT

static func _budget(v: VehicleDef) -> int:
	return 240 + int(float(v.price) * 0.05)

# ------------------------------------------------------------------- engine ---

static func engine_parts(v: VehicleDef) -> Array[PartDef]:
	var f: String = v.id
	var b: int = _budget(v)
	var out: Array[PartDef] = []
	var boost: float = v.stock_boost_bar
	var comp: float = v.compression
	var redline: float = v.engine.redline_rpm
	var turbo: bool = v.aspiration.find("turbo") >= 0

	out.append(_p("%s_block_s" % f, S.BLOCK, "بلوک استاندارد", "Stock block",
		"بلوک کارخانه با تحمل فشار محدود.", "Factory block with a limited boost rating.",
		0, 0.0, {"displacement_mult": 1.0, "max_boost_bar": boost + 0.35}, v, 0))
	out.append(_p("%s_block_r" % f, S.BLOCK, "بلوک تقویت‌شده", "Reinforced block",
		"آستین‌های ضخیم‌تر و بست‌های قوی‌تر: فشار بیشتر و حجم کمی بیشتر.",
		"Thicker liners and stronger fasteners: more boost and a little more displacement.",
		b * 9, 18.0, {"displacement_mult": 1.02, "max_boost_bar": boost + 0.85}, v, 1))
	out.append(_p("%s_block_c" % f, S.BLOCK, "بلوک مسابقه", "Race block",
		"بلوک ریخته‌گری‌شده برای فشار بالا و دور بالا.", "Cast race block rated for high boost and rpm.",
		b * 18, 26.0, {"displacement_mult": 1.045, "max_boost_bar": boost + 1.45}, v, 2))

	out.append(_p("%s_pist_s" % f, S.PISTONS, "پیستون استاندارد", "Stock pistons",
		"پیستون ریختگی با نسبت تراکم کارخانه.", "Cast pistons at the factory compression ratio.",
		0, 0.0, {"compression": comp, "efficiency_mult": 1.0, "max_boost_bar": boost + 0.4}, v, 0))
	out.append(_p("%s_pist_f" % f, S.PISTONS, "پیستون فورج", "Forged pistons",
		"فورج با تحمل فشار و دمای بالاتر.", "Forged, rated for higher boost and temperature.",
		b * 7, 1.2, {"compression": comp - 0.3, "efficiency_mult": 1.01, "max_boost_bar": boost + 1.0}, v, 1))
	out.append(_p("%s_pist_c" % f, S.PISTONS, "پیستون مسابقه", "Race pistons",
		"کم‌تراکم برای بوست سنگین و بازده حرارتی بالاتر.", "Lower compression for big boost, higher thermal efficiency.",
		b * 14, 1.0, {"compression": comp - 0.7, "efficiency_mult": 1.03, "max_boost_bar": boost + 1.6}, v, 2))

	out.append(_p("%s_crank_s" % f, S.CRANKSHAFT, "میل‌لنگ استاندارد", "Stock crankshaft",
		"میل‌لنگ کارخانه با محدودیت دور.", "Factory crank with its stock rpm limit.",
		0, 0.0, {"stroke_mult": 1.0, "max_rpm": redline + 150.0}, v, 0))
	out.append(_p("%s_crank_stroker" % f, S.CRANKSHAFT, "میل‌لنگ کورس بلند", "Stroker crank",
		"کورس بلندتر: گشتاور بیشتر، سقف دور کمتر.", "Longer stroke: more torque, less rpm.",
		b * 11, 9.0, {"stroke_mult": 1.05, "max_rpm": redline - 250.0}, v, 1))
	out.append(_p("%s_crank_billet" % f, S.CRANKSHAFT, "میل‌لنگ بیله‌ت", "Billet crank",
		"ماشین‌کاری‌شده از یک قطعه، برای دور و گشتاور بالا.", "Machined from one billet for high rpm and torque.",
		b * 16, 6.0, {"stroke_mult": 1.0, "max_rpm": redline + 700.0}, v, 2))

	out.append(_p("%s_rod_s" % f, S.CONRODS, "شاتون استاندارد", "Stock rods",
		"شاتون کارخانه.", "Factory connecting rods.", 0, 0.0,
		{"max_rpm": redline + 120.0, "strength": 1.0}, v, 0))
	out.append(_p("%s_rod_f" % f, S.CONRODS, "شاتون فورج", "Forged rods",
		"سبک‌تر و مقاوم‌تر، دور مجاز بالاتر.", "Lighter and stronger, raising the safe rpm.",
		b * 6, 0.8, {"max_rpm": redline + 550.0, "strength": 1.15}, v, 1))

	out.append(_p("%s_cam_s" % f, S.CAMSHAFT, "میل‌سوپاپ استاندارد", "Stock camshaft",
		"پروفیل کارخانه: گشتاور پایین‌دور.", "Factory profile: low-rpm torque.",
		0, 0.0, {"flow_mult": 1.0, "rev_add": 0.0, "max_rpm": redline + 200.0}, v, 0))
	out.append(_p("%s_cam_mid" % f, S.CAMSHAFT, "میل‌سوپاپ میان‌دور", "Mid-range camshaft",
		"جریان بیشتر در دور میانی.", "More flow through the mid range.",
		b * 5, 0.0, {"flow_mult": 1.05, "rev_add": 250.0, "max_rpm": redline + 600.0}, v, 1))
	out.append(_p("%s_cam_race" % f, S.CAMSHAFT, "میل‌سوپاپ مسابقه", "Race camshaft",
		"پروفیل بالادور؛ گشتاور پایین‌دور کم می‌شود.", "Top-end profile; low-rpm torque suffers.",
		b * 10, 0.0, {"flow_mult": 1.11, "rev_add": 550.0, "max_rpm": redline + 1000.0}, v, 2))

	out.append(_p("%s_head_s" % f, S.HEAD, "سرسیلندر استاندارد", "Stock head",
		"کانال‌های کارخانه.", "Factory ports.", 0, 0.0,
		{"flow_mult": 1.0, "max_rpm": redline + 250.0}, v, 0))
	out.append(_p("%s_head_p" % f, S.HEAD, "سرسیلندر پورت‌شده", "Ported head",
		"کانال‌ها پولیش و بازتر شده‌اند.", "Ports opened and polished.",
		b * 8, -1.0, {"flow_mult": 1.07, "max_rpm": redline + 500.0}, v, 1))
	out.append(_p("%s_head_c" % f, S.HEAD, "سرسیلندر مسابقه", "Race head",
		"سوپاپ بزرگ‌تر و کانال کامل.", "Bigger valves and full race porting.",
		b * 15, -1.5, {"flow_mult": 1.15, "max_rpm": redline + 900.0}, v, 2))

	out.append(_p("%s_intake_s" % f, S.INTAKE, "منیفولد استاندارد", "Stock intake", "مسیر هوای کارخانه.",
		"Factory air path.", 0, 0.0, {"flow_mult": 1.0}, v, 0))
	out.append(_p("%s_intake_sport" % f, S.INTAKE, "منیفولد اسپرت", "Sport intake",
		"مسیر مستقیم‌تر و فیلتر کم‌مقاومت.", "Straighter path and a low-restriction filter.",
		b * 3, -0.5, {"flow_mult": 1.04}, v, 1))
	out.append(_p("%s_intake_race" % f, S.INTAKE, "منیفولد مسابقه", "Race intake",
		"حجم بالا برای دور بالا.", "High-volume plenum for high rpm.",
		b * 7, -1.0, {"flow_mult": 1.09}, v, 2))

	out.append(_p("%s_tb_s" % f, S.THROTTLE, "دریچه گاز استاندارد", "Stock throttle",
		"پاسخ خطی کارخانه.", "Factory linear response.", 0, 0.0,
		{"flow_mult": 1.0, "response": 1.0}, v, 0))
	out.append(_p("%s_tb_big" % f, S.THROTTLE, "دریچه گاز بزرگ", "Big-bore throttle",
		"قطر بیشتر و پاسخ تندتر.", "Larger bore and a sharper response.",
		b * 4, 0.2, {"flow_mult": 1.035, "response": 1.15}, v, 1))

	out.append(_p("%s_exh_s" % f, S.EXHAUST, "اگزوز استاندارد", "Stock exhaust",
		"اگزوز کارخانه با محدودیت جریان.", "Factory exhaust with its flow restriction.",
		0, 0.0, {"flow_mult": 1.0, "spool_mult": 1.0}, v, 0))
	out.append(_p("%s_exh_25" % f, S.EXHAUST, "اگزوز ۲.۵ اینچ", "2.5\" exhaust",
		"جریان بهتر و شروع سریع‌تر توربو.", "Better flow and earlier spool.",
		b * 4, -3.0, {"flow_mult": 1.05, "spool_mult": 0.94}, v, 1))
	out.append(_p("%s_exh_3" % f, S.EXHAUST, "اگزوز ۳ اینچ", "3\" exhaust",
		"سیستم کامل برای توان بالا.", "Full system for high power.",
		b * 8, -4.0, {"flow_mult": 1.10, "spool_mult": 0.90}, v, 2))

	out.append(_p("%s_ecu_s" % f, S.ECU, "ای‌سی‌یو استاندارد", "Stock ECU",
		"نقشه کارخانه: محدودیت بوست و دور.", "Factory map: stock boost and rev limits.",
		0, 0.0, {"boost_target_bar": boost, "rev_limit": redline, "fuel_map": 1.0,
			"throttle_response": 1.0}, v, 0))
	out.append(_p("%s_ecu_1" % f, S.ECU, "ای‌سی‌یو مرحله ۱", "Stage 1 ECU",
		"نقشه سوخت و هدف بوست کمی بالاتر.", "Slightly higher boost target and fuel map.",
		b * 6, 0.0, {"boost_target_bar": boost + 0.15, "rev_limit": redline + 150.0,
			"fuel_map": 1.025, "throttle_response": 1.08}, v, 1))
	out.append(_p("%s_ecu_2" % f, S.ECU, "ای‌سی‌یو مرحله ۲", "Stage 2 ECU",
		"نقشه تهاجمی؛ نیاز به سوخت و خنک‌کاری بهتر دارد.", "Aggressive map; demands better fuel and cooling.",
		b * 12, 0.0, {"boost_target_bar": boost + 0.38, "rev_limit": redline + 350.0,
			"fuel_map": 1.05, "throttle_response": 1.15}, v, 2))

	if turbo:
		out.append(_p("%s_turbo_s" % f, S.TURBO, "توربوشارژ استاندارد", "Stock turbo",
			"توربو کارخانه با پاسخ سریع.", "Factory turbo with a quick spool.",
			0, 0.0, {"boost_bar": boost, "spool_rpm": v.stock_spool_rpm,
				"efficiency": 0.72, "heat_mult": 1.0}, v, 0))
		out.append(_p("%s_turbo_hybrid" % f, S.TURBO, "توربو هایبرید", "Hybrid turbo",
			"چرخ کمپرسور بزرگ‌تر: بوست بیشتر با تأخیر کمی بیشتر.",
			"Larger compressor wheel: more boost, a little more lag.",
			b * 10, 3.0, {"boost_bar": boost + 0.25, "spool_rpm": v.stock_spool_rpm + 180.0,
				"efficiency": 0.74, "heat_mult": 1.15}, v, 1))
		out.append(_p("%s_turbo_big" % f, S.TURBO, "توربو بزرگ", "Big turbo",
			"بوست بالا، تأخیر محسوس و بار حرارتی زیاد.",
			"High boost, real lag and a heavy thermal load.",
			b * 20, 6.0, {"boost_bar": boost + 0.65, "spool_rpm": v.stock_spool_rpm + 550.0,
				"efficiency": 0.76, "heat_mult": 1.35}, v, 2))
	else:
		# A naturally aspirated engine still has a turbo slot in the workshop: its
		# factory fitment is "no turbo". Without this the slot has no stock part and
		# the garage cannot describe what the car left the factory with.
		out.append(_p("%s_turbo_none" % f, S.TURBO, "بدون توربو (تنفس طبیعی)",
			"Naturally aspirated (no turbo)",
			"موتور کارخانه تنفس طبیعی است و توربویی روی آن نصب نشده.",
			"The factory engine is naturally aspirated; no turbocharger is fitted.",
			0, 0.0, {"boost_bar": 0.0, "spool_rpm": 0.0, "efficiency": 0.0,
				"heat_mult": 1.0}, v, 0))
		out.append(_p("%s_turbo_kit" % f, S.TURBO, "کیت توربو", "Turbo kit",
			"نصب توربو روی موتور تنفس طبیعی با بوست کم.",
			"Low-boost turbo conversion for a naturally aspirated engine.",
			b * 16, 14.0, {"boost_bar": 0.45, "spool_rpm": 2600.0,
				"efficiency": 0.70, "heat_mult": 1.25}, v, 2))

	out.append(_p("%s_ic_s" % f, S.INTERCOOLER, "اینترکولر استاندارد", "Stock intercooler",
		"خنک‌کاری هوای فشرده در حد کارخانه.", "Factory charge cooling.",
		0, 0.0, {"charge_cool": 0.55 if turbo else 0.0, "pressure_drop": 0.06}, v, 0))
	out.append(_p("%s_ic_fmic" % f, S.INTERCOOLER, "اینترکولر بزرگ", "Front-mount intercooler",
		"هوای خنک‌تر یعنی هوای چگال‌تر و گشتاور بیشتر.", "Cooler charge means denser air and more torque.",
		b * 8, 7.0, {"charge_cool": 0.76, "pressure_drop": 0.04}, v, 1))
	out.append(_p("%s_ic_race" % f, S.INTERCOOLER, "اینترکولر مسابقه", "Race intercooler",
		"بازده خنک‌کاری بالا برای بوست سنگین.", "High cooling efficiency for heavy boost.",
		b * 15, 10.0, {"charge_cool": 0.88, "pressure_drop": 0.03}, v, 2))

	out.append(_p("%s_inj_s" % f, S.INJECTORS, "انژکتور استاندارد", "Stock injectors",
		"دبی کارخانه و سقف توان متناسب.", "Factory flow and its power ceiling.",
		0, 0.0, {"flow_cc": v.injector_flow_cc, "max_power_kw": v.injector_max_kw}, v, 0))
	out.append(_p("%s_inj_15" % f, S.INJECTORS, "انژکتور ۱۵٪ بیشتر", "Injectors +15%",
		"دبی بیشتر برای توان بالاتر.", "More flow to support higher power.",
		b * 7, 0.0, {"flow_cc": v.injector_flow_cc * 1.15, "max_power_kw": v.injector_max_kw * 1.18}, v, 1))
	out.append(_p("%s_inj_30" % f, S.INJECTORS, "انژکتور ۳۰٪ بیشتر", "Injectors +30%",
		"دبی بالا برای توربو بزرگ.", "High flow for a big turbo.",
		b * 14, 0.0, {"flow_cc": v.injector_flow_cc * 1.32, "max_power_kw": v.injector_max_kw * 1.42}, v, 2))

	out.append(_p("%s_pump_s" % f, S.FUEL_PUMP, "پمپ سوخت استاندارد", "Stock fuel pump",
		"پمپ کارخانه.", "Factory lift pump.", 0, 0.0,
		{"flow_lph": v.pump_lph, "max_power_kw": v.pump_max_kw}, v, 0))
	out.append(_p("%s_pump_hp" % f, S.FUEL_PUMP, "پمپ سوخت پرفشار", "High-flow pump",
		"دبی بالاتر و سقف توان بیشتر.", "Higher flow and a higher power ceiling.",
		b * 6, 0.0, {"flow_lph": v.pump_lph * 1.25, "max_power_kw": v.pump_max_kw * 1.22}, v, 1))
	out.append(_p("%s_pump_race" % f, S.FUEL_PUMP, "پمپ سوخت مسابقه", "Race pump",
		"برای سیستم سوخت‌رسانی کامل.", "For a full race fuel system.",
		b * 12, 1.0, {"flow_lph": v.pump_lph * 1.55, "max_power_kw": v.pump_max_kw * 1.5}, v, 2))

	out.append(_p("%s_rad_s" % f, S.RADIATOR, "رادیاتور استاندارد", "Stock radiator",
		"خنک‌کاری کارخانه.", "Factory cooling.", 0, 0.0,
		{"heat_reject_kw": v.radiator_kw, "capacity_l": v.coolant_l}, v, 0))
	out.append(_p("%s_rad_hd" % f, S.RADIATOR, "رادیاتور سنگین", "Heavy-duty radiator",
		"هسته ضخیم‌تر و ظرفیت بیشتر.", "Thicker core and more capacity.",
		b * 7, 5.0, {"heat_reject_kw": v.radiator_kw * 1.35, "capacity_l": v.coolant_l + 2.0}, v, 1))
	out.append(_p("%s_rad_race" % f, S.RADIATOR, "رادیاتور مسابقه", "Race radiator",
		"دفع حرارت بالا برای صعودهای طولانی.", "High heat rejection for long climbs.",
		b * 13, 7.0, {"heat_reject_kw": v.radiator_kw * 1.7, "capacity_l": v.coolant_l + 3.0}, v, 2))

	out.append(_p("%s_wp_s" % f, S.WATER_PUMP, "واترپمپ استاندارد", "Stock water pump",
		"گردش کارخانه.", "Factory circulation.", 0, 0.0, {"flow_mult": 1.0}, v, 0))
	out.append(_p("%s_wp_hf" % f, S.WATER_PUMP, "واترپمپ پرفلو", "High-flow water pump",
		"گردش سریع‌تر مایع خنک‌کننده.", "Faster coolant circulation.",
		b * 4, 0.5, {"flow_mult": 1.18}, v, 1))

	out.append(_p("%s_fan_s" % f, S.FAN, "پنکه استاندارد", "Stock fan",
		"پنکه مکانیکی کارخانه.", "Factory mechanical fan.", 0, 0.0, {"airflow_mult": 1.0}, v, 0))
	out.append(_p("%s_fan_twin" % f, S.FAN, "پنکه دوگانه برقی", "Twin electric fans",
		"هوای بیشتر در سرعت پایین.", "More airflow at low speed.",
		b * 5, 1.5, {"airflow_mult": 1.28}, v, 1))
	out.append(_p("%s_fan_race" % f, S.FAN, "پنکه مسابقه", "Race fan",
		"حداکثر جریان هوا.", "Maximum airflow.", b * 9, 2.0, {"airflow_mult": 1.45}, v, 2))

	out.append(_p("%s_thermo_s" % f, S.THERMOSTAT, "ترموستات استاندارد", "Stock thermostat",
		"باز شدن در ۸۸ درجه.", "Opens at 88 °C.", 0, 0.0, {"open_c": 88.0}, v, 0))
	out.append(_p("%s_thermo_low" % f, S.THERMOSTAT, "ترموستات کم‌دما", "Low-temp thermostat",
		"باز شدن در ۸۲ درجه: حاشیهٔ حرارتی بیشتر.", "Opens at 82 °C: more thermal headroom.",
		b * 3, 0.0, {"open_c": 82.0}, v, 1))
	out.append(_p("%s_thermo_race" % f, S.THERMOSTAT, "ترموستات مسابقه", "Race thermostat",
		"باز شدن در ۷۶ درجه.", "Opens at 76 °C.", b * 6, 0.0, {"open_c": 76.0}, v, 2))
	return out

# ---------------------------------------------------------------- driveline ---

static func driveline_parts(v: VehicleDef) -> Array[PartDef]:
	var f: String = v.id
	var b: int = _budget(v)
	var out: Array[PartDef] = []
	var stock: TransmissionProfile = v.transmission_options()[0] if not v.transmission_options().is_empty() else null
	var shift: float = stock.shift_time if stock != null else 0.3
	var kind: int = stock.kind if stock != null else TransmissionProfile.Kind.MANUAL_H
	# The rating must follow the engine the car actually has, not the flat legacy
	# curve: `engine.peak_torque()` is the old single-curve resource and sits far
	# below a modern turbodiesel. Sizing the stock clutch from it left the plates
	# slipping permanently at full throttle and made the factory gearbox look
	# under-rated for its own engine.
	var engine_torque: float = maxf(v.doc_torque_nm, v.engine.peak_torque())
	var torque_rating: float = maxf(engine_torque * 1.2, 300.0)
	# The bite point is a property of the car, not a constant: a heavy torquey
	# diesel takes up drive lower in the pedal travel and over a longer window than
	# a light petrol, and every fitment inherits that offset. Without this every
	# stock car in the game bit at exactly 0.62 and the pedal felt identical.
	var bite_base: float = clampf(0.74 - engine_torque / 2400.0, 0.52, 0.70)

	out.append(_p("%s_clutch_s" % f, S.CLUTCH, "کلاچ استاندارد", "Stock clutch",
		"کلاچ کارخانه با ظرفیت متناسب.", "Factory clutch at its rated capacity.",
		0, 0.0, {
			"capacity_nm": torque_rating, "bite_point": bite_base,
			"engagement_window": 0.38, "type": "organic"}, v, 0))
	out.append(_p("%s_clutch_hd" % f, S.CLUTCH, "کلاچ سنگین", "Heavy-duty clutch",
		"ظرفیت بیشتر برای گشتاور بالاتر.", "More capacity for higher torque.",
		b * 6, 1.5, {
			"capacity_nm": torque_rating * 1.45, "bite_point": bite_base - 0.06,
			"engagement_window": 0.28, "type": "paddle"}, v, 1))
	out.append(_p("%s_clutch_twin" % f, S.CLUTCH, "کلاچ دوقلو", "Twin-plate clutch",
		"ظرفیت مسابقه و تعویض سریع، درگیری تند.", "Race capacity and fast shifts, with a sharp bite.",
		b * 14, 2.5, {
			"capacity_nm": torque_rating * 2.1, "bite_point": bite_base - 0.14,
			"engagement_window": 0.22, "type": "twin"}, v, 2))

	out.append(_p("%s_gbox_s" % f, S.GEARBOX, "گیربکس استاندارد", "Stock gearbox",
		"نسبت‌های کارخانه.", "Factory ratios.", 0, 0.0,
		{"ratios": _arr(stock.ratios if stock != null else PackedFloat32Array([3.5, 2.1, 1.4, 1.0])),
			"final_drive": stock.final_drive if stock != null else 4.1,
			"shift_time": shift, "max_torque_nm": torque_rating, "kind": kind,
			"reverse_ratio": stock.reverse_ratio if stock != null else 3.4,
			"efficiency": stock.efficiency if stock != null else 0.9}, v, 0))
	out.append(_p("%s_gbox_close" % f, S.GEARBOX, "نسبت‌های نزدیک", "Close-ratio set",
		"نسبت‌های کوتاه‌تر: کشش بیشتر، سرعت نهایی کمتر.", "Shorter ratios: more pull, less top speed.",
		b * 9, 2.0, {"ratios": _scaled(stock.ratios if stock != null else PackedFloat32Array([3.5, 2.1, 1.4, 1.0]), 1.14),
			"final_drive": (stock.final_drive if stock != null else 4.1) * 1.06,
			"shift_time": shift * 0.82, "max_torque_nm": torque_rating * 1.35, "kind": kind,
			"reverse_ratio": stock.reverse_ratio if stock != null else 3.4,
			"efficiency": (stock.efficiency if stock != null else 0.9) + 0.01}, v, 1))
	out.append(_p("%s_gbox_auto" % f, S.GEARBOX, "گیربکس اتوماتیک", "Automatic gearbox",
		"مبدل گشتاور و تعویض خودکار، بدون پدال کلاچ.",
		"Torque converter and automatic shifting, with no clutch pedal.",
		b * 16, 16.0, _auto_params(v, stock, torque_rating), v, 2))
	out.append(_p("%s_gbox_race" % f, S.GEARBOX, "گیربکس مسابقه", "Race gearbox",
		"ترتیبی، تعویض سریع، تحمل گشتاور بالا.", "Sequential, fast shifts, high torque rating.",
		b * 20, 1.0, {"ratios": _scaled(stock.ratios if stock != null else PackedFloat32Array([3.5, 2.1, 1.4, 1.0]), 1.2),
			"final_drive": (stock.final_drive if stock != null else 4.1) * 1.1,
			"shift_time": 0.14, "max_torque_nm": torque_rating * 1.8,
			"kind": TransmissionProfile.Kind.MANUAL_SEQ,
			"reverse_ratio": stock.reverse_ratio if stock != null else 3.4,
			"efficiency": 0.93}, v, 2))

	out.append(_p("%s_tcase_s" % f, S.TRANSFER, "جعبه‌دنده کمکی استاندارد", "Stock transfer case",
		"حالت‌های کارخانه.", "Factory modes.", 0, 0.0,
		{"ids": _arr_s(v.transfer_ids), "ratios": _arr(v.transfer_ratios)}, v, 0))
	out.append(_p("%s_tcase_hd" % f, S.TRANSFER, "جعبه‌دنده کمکی سنگین", "Heavy-duty transfer case",
		"نسبت کمکی کوتاه‌تر و دوام بیشتر برای صعودهای سخت.",
		"Lower crawl ratio and more durability for hard climbs.",
		b * 8, 12.0, {"ids": _arr_s(v.transfer_ids), "ratios": _scaled(v.transfer_ratios, 1.18)}, v, 1))

	out.append(_p("%s_diff_open" % f, S.DIFFERENTIAL, "دیفرانسیل باز", "Open differential",
		"رفتار استاندارد و قابل پیش‌بینی.", "Standard, predictable behaviour.",
		0, 0.0, {"mode": "open", "grip_mult": 1.0}, v, 0))
	out.append(_p("%s_diff_lsd" % f, S.DIFFERENTIAL, "دیفرانسیل لغزش محدود", "Limited-slip differential",
		"تقسیم بهتر گشتاور بین دو چرخ.", "Better torque split across the axle.",
		b * 6, 3.0, {"mode": "lsd", "grip_mult": 1.07}, v, 1))
	out.append(_p("%s_diff_lock" % f, S.DIFFERENTIAL, "دیفرانسیل قفل", "Locking differential",
		"کشش حداکثری روی سنگ و گل.", "Maximum traction on rock and mud.",
		b * 11, 6.0, {"mode": "locked", "grip_mult": 1.14}, v, 2))
	return out

# ----------------------------------------------------------------- chassis ---

static func chassis_parts(v: VehicleDef) -> Array[PartDef]:
	var f: String = v.id
	var b: int = _budget(v)
	var out: Array[PartDef] = []

	out.append(_p("%s_spring_s" % f, S.SPRINGS, "فنر استاندارد", "Stock springs",
		"نرخ فنر کارخانه.", "Factory spring rate.", 0, 0.0,
		{"spring_mult": 1.0, "ride_mult": 1.0}, v, 0))
	out.append(_p("%s_spring_soft" % f, S.SPRINGS, "فنر نرم", "Soft springs",
		"سواری نرم‌تر، پیچش بدنه بیشتر.", "Softer ride, more body roll.",
		b * 4, -3.0, {"spring_mult": 0.88, "ride_mult": 0.98}, v, 1))
	out.append(_p("%s_spring_hd" % f, S.SPRINGS, "فنر سنگین", "Heavy-duty springs",
		"بار بیشتر و ارتفاع کمی بالاتر.", "Higher load rating and a little more height.",
		b * 6, 8.0, {"spring_mult": 1.14, "ride_mult": 1.02}, v, 1))
	out.append(_p("%s_spring_race" % f, S.SPRINGS, "فنر مسابقه", "Race springs",
		"سخت و کوتاه برای کنترل بدنه.", "Stiff and short for body control.",
		b * 11, 4.0, {"spring_mult": 1.3, "ride_mult": 0.96}, v, 2))

	out.append(_p("%s_damper_s" % f, S.DAMPERS, "کمک‌فنر استاندارد", "Stock dampers",
		"میرایی کارخانه.", "Factory damping.", 0, 0.0,
		{"compression_mult": 1.0, "rebound_mult": 1.0}, v, 0))
	out.append(_p("%s_damper_gas" % f, S.DAMPERS, "کمک‌فنر گازی", "Gas dampers",
		"کنترل بهتر روی دست‌انداز.", "Better control over bumps.",
		b * 6, 4.0, {"compression_mult": 1.15, "rebound_mult": 1.12}, v, 1))
	out.append(_p("%s_damper_race" % f, S.DAMPERS, "کمک‌فنر مسابقه", "Race dampers",
		"میرایی بالا برای فرود و صعود سخت.", "High damping for hard landings and climbs.",
		b * 15, 6.0, {"compression_mult": 1.38, "rebound_mult": 1.3}, v, 2))

	out.append(_p("%s_bump_s" % f, S.BUMP_STOPS, "بامپ‌استاپ استاندارد", "Stock bump stops",
		"پایان کورس کارخانه.", "Factory end stops.", 0, 0.0, {"rate_mult": 1.0}, v, 0))
	out.append(_p("%s_bump_prog" % f, S.BUMP_STOPS, "بامپ‌استاپ پیش‌رونده", "Progressive bump stops",
		"ضربهٔ آخر نرم‌تر جذب می‌شود.", "Softer final travel.", b * 3, 0.5, {"rate_mult": 1.3}, v, 1))

	out.append(_p("%s_arms_s" % f, S.ARMS, "بازوی تعلیق استاندارد", "Stock arms",
		"بازوهای کارخانه.", "Factory arms.", 0, 0.0,
		{"travel_mult": 1.0, "strength": 1.0}, v, 0))
	out.append(_p("%s_arms_hd" % f, S.ARMS, "بازوی تقویت‌شده", "Reinforced arms",
		"کورس کمی بیشتر و مقاومت بالاتر.", "Slightly more travel and more strength.",
		b * 6, 5.0, {"travel_mult": 1.06, "strength": 1.2}, v, 1))

	out.append(_p("%s_lift_0" % f, S.LIFT_KIT, "بدون کیت بلند", "No lift",
		"ارتفاع کارخانه.", "Factory ride height.", 0, 0.0,
		{"ride_add_m": 0.0, "com_add_m": 0.0, "travel_mult": 1.0,
			"max_tyre_radius_m": v.max_tyre_radius_m}, v, 0))
	out.append(_p("%s_lift_25" % f, S.LIFT_KIT, "کیت بلند ۲۵ میلی‌متر", "25 mm lift",
		"فضای بیشتر گلگیر، مرکز جرم کمی بالاتر.", "More arch clearance, a slightly higher centre of mass.",
		b * 7, 8.0, {"ride_add_m": 0.025, "com_add_m": 0.012, "travel_mult": 1.05,
			"max_tyre_radius_m": v.max_tyre_radius_m + 0.02}, v, 1))
	out.append(_p("%s_lift_50" % f, S.LIFT_KIT, "کیت بلند ۵۰ میلی‌متر", "50 mm lift",
		"برای تایر بزرگ‌تر؛ پایداری کمتر در سرعت.", "For bigger tyres; less stability at speed.",
		b * 12, 14.0, {"ride_add_m": 0.05, "com_add_m": 0.028, "travel_mult": 1.1,
			"max_tyre_radius_m": v.max_tyre_radius_m + 0.045}, v, 2))

	out.append(_p("%s_bush_s" % f, S.BUSHINGS, "بوش استاندارد", "Stock bushings",
		"نرم و بی‌صدا.", "Soft and quiet.", 0, 0.0, {"compliance": 1.0}, v, 0))
	out.append(_p("%s_bush_poly" % f, S.BUSHINGS, "بوش پلی‌اورتان", "Poly bushings",
		"دقت بیشتر محور، کمی خشک‌تر.", "More axle precision, a little harsher.",
		b * 4, 0.5, {"compliance": 0.75}, v, 1))
	return out

# -------------------------------------------------------------------- tyres ---

static func tyre_parts(v: VehicleDef) -> Array[PartDef]:
	var f: String = v.id
	var b: int = _budget(v)
	var r: float = v.tire_front.radius_m
	var w: float = v.tire_front.width_m
	var out: Array[PartDef] = []
	# id, fa, en, radius, width, mu_peak, mu_slide, rr, peak_slip, mass, bonus, cost
	var rows: Array = [
		["at", "آل‌ترین", "All-terrain", r, w, 0.96, 0.80, 0.030, 0.15,
			{"mud": 1.05, "gravel": 1.05, "hard_dirt": 1.02}, 0, 0],
		["mt", "گلی", "Mud-terrain", r + 0.01, w + 0.02, 1.02, 0.86, 0.034, 0.16,
			{"mud": 1.22, "wet_mud": 1.18, "hard_dirt": 0.97, "asphalt": 0.92}, b * 4, 1],
		["rock", "سنگی", "Rock-terrain", r + 0.005, w + 0.01, 0.99, 0.84, 0.032, 0.15,
			{"rock": 1.16, "scree": 1.12, "gravel": 1.04}, b * 4, 1],
		["highway", "جاده‌ای", "Highway-terrain", r - 0.005, w, 0.93, 0.72, 0.024, 0.13,
			{"asphalt": 1.12, "hard_dirt": 0.98, "mud": 0.85}, b * 3, 1],
		["snow", "برفی", "Snow-terrain", r, w - 0.01, 0.92, 0.70, 0.036, 0.14,
			{"snow": 1.28, "ice": 1.22, "asphalt": 0.94}, b * 5, 1],
		["mt_xl", "گلی بزرگ", "Oversize mud-terrain", r + 0.03, w + 0.035, 1.04, 0.88, 0.036, 0.17,
			{"mud": 1.26, "wet_mud": 1.22, "rock": 1.08}, b * 8, 2],
	]
	for row: Array in rows:
		var params: Dictionary = {
			"radius_m": float(row[3]), "width_m": float(row[4]),
			"mu_peak": float(row[5]), "mu_slide": float(row[6]),
			"rr": float(row[7]), "peak_slip": float(row[8]),
			"surface_bonus": row[9], "compound": String(row[0]),
			"pressure_bar": 2.1,
		}
		out.append(_p("%s_tyre_%s" % [f, String(row[0])], S.TYRES,
			String(row[1]), String(row[2]),
			"ترکیب %s با چسبندگی و مقاومت غلتشی خودش." % String(row[1]),
			"%s compound with its own grip curve and rolling resistance." % String(row[2]),
			int(row[10]), 0.0, params, v, int(row[11])))
	out.append(_p("%s_rim_s" % f, S.RIMS, "رینگ فولادی", "Steel wheels",
		"رینگ کارخانه؛ سنگین و مقاوم.", "Factory steel wheels: heavy and tough.",
		0, 0.0, {"mass_add": 0.0}, v, 0))
	out.append(_p("%s_rim_alloy" % f, S.RIMS, "رینگ آلومینیومی", "Alloy wheels",
		"سبک‌تر، جرم فنرنشده کمتر.", "Lighter, less unsprung mass.",
		b * 5, -4.0, {"mass_add": -4.0}, v, 1))
	return out

# ------------------------------------------------------------------- brakes ---

static func brake_parts(v: VehicleDef) -> Array[PartDef]:
	var f: String = v.id
	var b: int = _budget(v)
	var out: Array[PartDef] = []
	out.append(_p("%s_pad_s" % f, S.BRAKE_PADS, "لنت استاندارد", "Stock pads",
		"لنت کارخانه.", "Factory pads.", 0, 0.0, {"brake_mult": 1.0, "fade_c": 420.0}, v, 0))
	out.append(_p("%s_pad_ceramic" % f, S.BRAKE_PADS, "لنت سرامیکی", "Ceramic pads",
		"نیروی بیشتر و مقاومت به حرارت بالاتر.", "More force and better heat resistance.",
		b * 4, 0.0, {"brake_mult": 1.14, "fade_c": 560.0}, v, 1))
	out.append(_p("%s_pad_race" % f, S.BRAKE_PADS, "لنت مسابقه", "Race pads",
		"نیروی ترمز بالا برای سرازیری‌های تند.", "High braking force for steep descents.",
		b * 9, 0.0, {"brake_mult": 1.32, "fade_c": 700.0}, v, 2))
	out.append(_p("%s_disc_s" % f, S.BRAKE_DISCS, "دیسک استاندارد", "Stock discs",
		"دیسک کارخانه.", "Factory discs.", 0, 0.0, {"brake_mult": 1.0, "mass": 0.0}, v, 0))
	out.append(_p("%s_disc_slot" % f, S.BRAKE_DISCS, "دیسک شیاردار", "Slotted discs",
		"خنک‌کاری بهتر و نیروی بیشتر.", "Better cooling and more force.",
		b * 5, 2.0, {"brake_mult": 1.1, "mass": 2.0}, v, 1))
	out.append(_p("%s_disc_big" % f, S.BRAKE_DISCS, "دیسک بزرگ", "Big brake kit",
		"قطر بیشتر و اهرم ترمز قوی‌تر.", "Larger diameter and a stronger lever.",
		b * 10, 6.0, {"brake_mult": 1.22, "mass": 6.0}, v, 2))
	return out

# --------------------------------------------------------------------- body ---

static func body_parts(v: VehicleDef) -> Array[PartDef]:
	var f: String = v.id
	var b: int = _budget(v)
	var out: Array[PartDef] = []
	out.append(_p("%s_bumper_f_s" % f, S.BUMPER_FRONT, "سپر جلو استاندارد", "Stock front bumper",
		"سپر کارخانه.", "Factory bumper.", 0, 0.0,
		{"mass_kg": 0.0, "drag_mult": 1.0, "durability_mult": 1.0, "protection": 0.0}, v, 0))
	out.append(_p("%s_bumper_f_steel" % f, S.BUMPER_FRONT, "سپر فولادی جلو", "Steel front bar",
		"محافظت بیشتر در برخورد، جرم و مقاومت هوا بیشتر.",
		"More protection on impact, at the cost of mass and drag.",
		b * 6, 42.0, {"mass_kg": 42.0, "drag_mult": 1.04, "durability_mult": 1.2, "protection": 0.35}, v, 1))
	out.append(_p("%s_bumper_r_s" % f, S.BUMPER_REAR, "سپر عقب استاندارد", "Stock rear bumper",
		"سپر کارخانه.", "Factory bumper.", 0, 0.0,
		{"mass_kg": 0.0, "durability_mult": 1.0, "protection": 0.0}, v, 0))
	out.append(_p("%s_bumper_r_steel" % f, S.BUMPER_REAR, "سپر فولادی عقب", "Steel rear bar",
		"محافظت عقب و امکان بازیابی.", "Rear protection and a recovery point.",
		b * 5, 34.0, {"mass_kg": 34.0, "durability_mult": 1.15, "protection": 0.3}, v, 1))
	out.append(_p("%s_flare_s" % f, S.FENDER_FLARE, "بدون فلر", "No flares",
		"بدون تغییر.", "No change.", 0, 0.0, {"width_add_m": 0.0}, v, 0))
	out.append(_p("%s_flare_wide" % f, S.FENDER_FLARE, "فلر پهن", "Wide flares",
		"پوشش تایر پهن‌تر و ظاهر حرفه‌ای.", "Covers wider tyres and looks the part.",
		b * 3, 3.0, {"width_add_m": 0.03}, v, 1))
	out.append(_p("%s_hood_s" % f, S.HOOD, "کاپوت استاندارد", "Stock hood",
		"کاپوت کارخانه.", "Factory hood.", 0, 0.0, {"mass_kg": 0.0, "vent": 0.0}, v, 0))
	out.append(_p("%s_hood_vent" % f, S.HOOD, "کاپوت دریچه‌دار", "Vented hood",
		"خروج حرارت از محفظه موتور.", "Lets heat out of the engine bay.",
		b * 4, 1.0, {"mass_kg": 1.0, "vent": 0.08}, v, 1))
	out.append(_p("%s_rack_s" % f, S.ROOF_RACK, "بدون باربند", "No roof rack",
		"وزن کمتر.", "Less weight.", 0, 0.0, {"mass_kg": 0.0, "com_add_m": 0.0}, v, 0))
	out.append(_p("%s_rack" % f, S.ROOF_RACK, "باربند سقفی", "Roof rack",
		"فضای بار، مرکز جرم بالاتر.", "Cargo space, higher centre of mass.",
		b * 3, 28.0, {"mass_kg": 28.0, "com_add_m": 0.02}, v, 1))
	out.append(_p("%s_skid_s" % f, S.SKID_PLATE, "بدون پلاک محافظ", "No skid plate",
		"بدون محافظ زیرین.", "No underbody protection.", 0, 0.0,
		{"mass_kg": 0.0, "protection": 0.0}, v, 0))
	out.append(_p("%s_skid" % f, S.SKID_PLATE, "پلاک محافظ", "Skid plate",
		"محافظت از زیر موتور روی سنگ.", "Protects the sump on rock.",
		b * 4, 16.0, {"mass_kg": 16.0, "protection": 0.25}, v, 1))
	out.append(_p("%s_sliders_s" % f, S.SLIDERS, "بدون راک‌اسلایدر", "No sliders",
		"بدون محافظ جانبی.", "No side protection.", 0, 0.0, {"mass_kg": 0.0, "protection": 0.0}, v, 0))
	out.append(_p("%s_sliders" % f, S.SLIDERS, "راک‌اسلایدر", "Rock sliders",
		"محافظت از سیل و درها.", "Protects sills and doors.",
		b * 5, 24.0, {"mass_kg": 24.0, "protection": 0.3}, v, 1))
	out.append(_p("%s_cage_s" % f, S.ROLL_CAGE, "بدون قفس", "No cage",
		"کابین کارخانه.", "Factory cabin.", 0, 0.0, {"mass_kg": 0.0, "durability_mult": 1.0}, v, 0))
	out.append(_p("%s_cage" % f, S.ROLL_CAGE, "قفس ایمنی", "Roll cage",
		"دوام شاسی بیشتر، جرم بیشتر.", "Stronger chassis, more mass.",
		b * 9, 55.0, {"mass_kg": 55.0, "durability_mult": 1.3}, v, 2))
	out.append(_p("%s_winch_s" % f, S.WINCH, "بدون وینچ", "No winch",
		"بازیابی دستی.", "Manual recovery only.", 0, 0.0,
		{"mass_kg": 0.0, "force_n": 0.0, "rope_m": 0.0}, v, 0))
	out.append(_p("%s_winch" % f, S.WINCH, "وینچ ۹ تن", "9 t winch",
		"بازیابی واقعی روی شیب.", "Real recovery on a grade.",
		b * 7, 38.0, {"mass_kg": 38.0, "force_n": 9000.0 * 9.80665, "rope_m": 24.0}, v, 1))
	out.append(_p("%s_snorkel_s" % f, S.SNORKEL, "بدون اسنورکل", "No snorkel",
		"هوای موتور از ارتفاع پایین.", "Engine air from low down.", 0, 0.0,
		{"mass_kg": 0.0, "water_ford_m": 0.4}, v, 0))
	out.append(_p("%s_snorkel" % f, S.SNORKEL, "اسنورکل", "Snorkel",
		"عبور از آب عمیق‌تر.", "Deeper water crossings.",
		b * 4, 6.0, {"mass_kg": 6.0, "water_ford_m": 0.9}, v, 1))
	out.append(_p("%s_lights_s" % f, S.LIGHTS, "چراغ استاندارد", "Stock lights",
		"نور کارخانه.", "Factory lighting.", 0, 0.0, {"range_m": 40.0, "mass_kg": 0.0}, v, 0))
	out.append(_p("%s_lights_bar" % f, S.LIGHTS, "بار نوری", "Light bar",
		"روشنایی بیشتر در مه و شب.", "More light in fog and at night.",
		b * 4, 8.0, {"range_m": 90.0, "mass_kg": 8.0}, v, 1))
	return out

# ------------------------------------------------------------- array helpers ---

static func _arr(values: PackedFloat32Array) -> Array:
	var out: Array = []
	for v: float in values:
		out.append(v)
	return out

static func _arr_s(values: PackedStringArray) -> Array:
	var out: Array = []
	for v: String in values:
		out.append(v)
	return out

static func _scaled(values: PackedFloat32Array, mult: float) -> Array:
	var out: Array = []
	for v: float in values:
		out.append(v * mult)
	return out

# ------------------------------------------------- automatic conversions ---

## Ratios for the automatic conversion of a manual car.
##
## Where the car documents a factory automatic (the Hilux and the Land Cruiser
## both do), the conversion carries that gearbox's real ratios. Otherwise a torque
## converter multiplies torque at stall, so the automatic does not need the donor's
## deep first gear and four speeds are enough where the manual had five: an engine
## with torque to spare can afford a taller first, a small petrol keeps more of the
## depth it had. The top gear is left where the factory put it, so cruising rpm and
## top speed do not move.
static func _auto_params(v: VehicleDef, stock: TransmissionProfile, torque_rating: float) -> Dictionary:
	var factory: TransmissionProfile = _factory_automatic(v)
	if factory != null:
		return {
			"ratios": _arr(factory.ratios),
			"final_drive": factory.final_drive,
			"reverse_ratio": factory.reverse_ratio,
			"shift_time": factory.shift_time,
			"max_torque_nm": maxf(torque_rating * 1.25, factory.max_torque_nm),
			"kind": TransmissionProfile.Kind.AUTOMATIC,
			"efficiency": factory.efficiency,
		}
	return {
		"ratios": _arr(_auto_ratios(v, stock)),
		"final_drive": _auto_final(stock),
		"reverse_ratio": stock.reverse_ratio if stock != null else 3.4,
		"shift_time": 0.34,
		"max_torque_nm": torque_rating * 1.25,
		"kind": TransmissionProfile.Kind.AUTOMATIC,
		"efficiency": 0.86,
	}

static func _factory_automatic(v: VehicleDef) -> TransmissionProfile:
	for candidate: TransmissionProfile in v.transmission_options():
		if candidate.kind == TransmissionProfile.Kind.AUTOMATIC:
			return candidate
	return null

## Synthesised ratios for a car with no documented automatic: four speeds, a
## converter-friendly first and the donor's top gear kept as it was.
static func _auto_ratios(v: VehicleDef, stock: TransmissionProfile) -> PackedFloat32Array:
	var base: PackedFloat32Array = stock.ratios if stock != null \
		else PackedFloat32Array([3.5, 2.1, 1.4, 1.0])
	if base.size() < 3:
		return base
	var top: float = maxf(base[base.size() - 1], 1.0)
	var grunt: float = clampf(v.doc_torque_nm / 420.0, 0.4, 1.0)
	var first: float = maxf(base[0] * lerpf(0.94, 0.86, grunt), top * 1.08)
	var speeds: int = mini(4, base.size())
	var step: float = pow(first / top, 1.0 / float(speeds - 1))
	var out: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(speeds):
		out.append(top * pow(step, float(speeds - 1 - i)))
	return out

## The converter covers the launch, so the final drive can be a shade taller than
## the donor's: the same road speed costs fewer rpm and the box is not fighting a
## ratio it no longer needs.
static func _auto_final(stock: TransmissionProfile) -> float:
	var base: float = stock.final_drive if stock != null else 4.1
	return snappedf(base * 0.97, 0.01)
