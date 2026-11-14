class_name VehicleCatalog
extends RefCounted
## The MUDRO 3.0 vehicle roster: five real, documented off-roaders.
##
## Every number in this table comes from docs/VEHICLE_SPEC_SOURCES.md, which cites
## a factory document for one exact variant per vehicle. Nothing is mixed across
## trims or model years. `torque_scale` is the single calibration constant that
## makes the generic engine model reproduce the documented torque for that engine;
## the tests assert both peak torque and peak power against `doc_*`.

static func build_all() -> Array[VehicleDef]:
	var out: Array[VehicleDef] = []
	for row: Dictionary in DATA:
		out.append(_from_row(row))
	return out

const DATA: Array = [
	{
		"id": "jimny_jb74", "name_fa": "جیمنی", "name_en": "SUZUKI JIMNY 1.5",
		"class_fa": "شاسی‌بلند کوچک", "class_en": "Compact 4x4",
		"manufacturer": "Suzuki", "year": 2020,
		"trim": "1.5 GLX 3-door, 5-speed manual",
		"desc_fa": "سبک، کوتاه و بی‌ترس. با ۱۰۹۵ کیلوگرم جرم و محورهای صلب، در مسیرهای تنگ جنگلی و شیب‌های کوتاه عالی است؛ اما برای صعودهای طولانی قدرت کم می‌آورد.",
		"desc_en": "Light, short and fearless. At 1,095 kg on rigid axles it owns tight forest lines and short climbs, but long ascents expose its modest power.",
		"price": 0, "unlock": "",
		"drive": 2, "torque_split": 0.5,
		"drivetrain_label": "Part-time 4WD, 2H / 4H / 4L",
		"suspension_arch": "3-link rigid axle, coil springs, front and rear",
		"fuel": "petrol", "tyre": "195/80 R15", "tyre_r": 0.3465, "tyre_w": 0.195,
		"mass": 1095, "wb": 2.250, "len": 3.645, "wid": 1.645, "hgt": 1.725,
		"com": 0.44, "area": 1.72, "cd": 0.62, "inertia": 0.82,
		"brake_f": 1750.0, "brake_r": 1250.0, "handbrake": 2400.0,
		"clutch": 210.0, "clutch_k": 2.2, "durability": 0.86, "impact": 7.5,
		"max_tyre_r": 0.375, "accent": Color(0.84, 0.60, 0.24),
		"family": "k15b", "code": "K15B", "aspiration": "na", "comp": 10.5,
		"cc": 1462, "cyl": 4, "boost": 0.0, "spool": 0.0, "torque_scale": 1.074,
		"inj_cc": 200.0, "inj_kw": 86.0, "pump_lph": 85.0, "pump_kw": 90.0,
		"rad_kw": 44.0, "coolant": 5.0,
		"doc_power": 75.0, "doc_torque": 130.0, "doc_power_rpm": 6000.0, "doc_torque_rpm": 4000.0,
		"redline": 6000.0, "idle": 750.0, "engine_inertia": 0.10, "friction": 9.0,
		"springs": [21000.0, 20000.0], "dampers": [1500.0, 1900.0, 1450.0, 1800.0],
		"travel": [0.24, 0.22, 0.09], "bump": 62000.0,
		"transmissions": [
			{"id": "jimny_m5", "fa": "دستی پنج‌سرعته", "en": "5-speed manual",
				"kind": 0, "ratios": [4.425, 2.304, 1.674, 1.190, 1.000],
				"reverse": 5.151, "final": 4.090, "eff": 0.90, "shift": 0.28},
			{"id": "jimny_a4", "fa": "اتوماتیک چهارسرعته", "en": "4-speed automatic",
				"kind": 2, "ratios": [2.875, 1.568, 1.000, 0.697],
				"reverse": 2.300, "final": 4.300, "eff": 0.88, "shift": 0.42},
		],
		"stock": "jimny_m5", "transfer": ["2H", "4H", "4L"], "transfer_r": [1.0, 1.0, 2.002],
		"spec": {
			"engine": "K15B 1,462 cc inline-4, 16 valves, naturally aspirated, petrol",
			"power": "75 kW (102 PS) @ 6,000 rpm", "torque": "130 Nm @ 4,000 rpm",
			"gearbox": "5-speed manual", "ratios": [4.425, 2.304, 1.674, 1.190, 1.000],
			"reverse": 5.151, "final_drive": 4.090,
			"transfer": {"2H": 1.0, "4H": 1.0, "4L": 2.002},
			"kerb_mass_kg": 1095, "wheelbase_mm": 2250, "length_mm": 3645,
			"width_mm": 1645, "height_mm": 1725, "tyres": "195/80 R15",
			"fuel_tank_l": 40,
			"source": "Suzuki Jimny JB74 factory specification sheet (see docs/VEHICLE_SPEC_SOURCES.md)",
		},
	},
	{
		"id": "hilux_an120", "name_fa": "هایلوکس", "name_en": "TOYOTA HILUX 2.8 GD-6",
		"class_fa": "پیکاپ دوقلو", "class_en": "Double-cab pickup",
		"manufacturer": "Toyota", "year": 2021,
		"trim": "2.8 GD-6 double cab 4x4, 6-speed manual",
		"desc_fa": "کارگر همه‌کاره. ۴۲۰ نیوتون‌متر از ۲.۸ لیتر و شش دنده، آن را به انتخاب پیش‌فرض برای صعودهای متوسط و مسیرهای خاکی تبدیل می‌کند.",
		"desc_en": "The all-round workhorse. 420 Nm from 2.8 litres and six gears make it the default choice for medium climbs and dirt roads.",
		"price": 3200, "unlock": "zagros_03",
		"drive": 2, "torque_split": 0.42,
		"drivetrain_label": "Part-time 4WD, 2H / 4H / 4L",
		"suspension_arch": "Double wishbone front, leaf-spring rigid rear axle",
		"fuel": "diesel", "tyre": "265/60 R18", "tyre_r": 0.3876, "tyre_w": 0.265,
		"mass": 2120, "wb": 3.085, "len": 5.325, "wid": 1.855, "hgt": 1.815,
		"com": 0.62, "area": 2.92, "cd": 0.68, "inertia": 1.12,
		"brake_f": 3000.0, "brake_r": 1900.0, "handbrake": 3800.0,
		"clutch": 520.0, "clutch_k": 2.8, "durability": 1.05, "impact": 9.5,
		"max_tyre_r": 0.405, "accent": Color(0.48, 0.52, 0.34),
		"family": "1gd_ftv", "code": "1GD-FTV", "aspiration": "turbo_diesel", "comp": 15.6,
		"cc": 2755, "cyl": 4, "boost": 1.35, "spool": 1600.0, "torque_scale": 0.987,
		"inj_cc": 360.0, "inj_kw": 168.0, "pump_lph": 150.0, "pump_kw": 180.0,
		"rad_kw": 142.0, "coolant": 9.2,
		"doc_power": 150.0, "doc_torque": 420.0, "doc_power_rpm": 3400.0, "doc_torque_rpm": 1400.0,
		"hold_rpm": 3400.0,
		"redline": 4600.0, "idle": 700.0, "engine_inertia": 0.28, "friction": 22.0,
		"springs": [38000.0, 42000.0], "dampers": [3200.0, 3900.0, 3000.0, 3600.0],
		"travel": [0.26, 0.24, 0.10], "bump": 98000.0,
		"transmissions": [
			{"id": "hilux_m6", "fa": "دستی شش‌سرعته", "en": "6-speed manual",
				"kind": 0, "ratios": [4.784, 2.423, 1.443, 1.000, 0.826, 0.643],
				"reverse": 4.066, "final": 3.583, "eff": 0.90, "shift": 0.30},
			{"id": "hilux_a6", "fa": "اتوماتیک شش‌سرعته", "en": "6-speed automatic",
				"kind": 2, "ratios": [3.600, 2.090, 1.488, 1.000, 0.687, 0.580],
				"reverse": 3.732, "final": 3.909, "eff": 0.88, "shift": 0.40},
		],
		"stock": "hilux_m6", "transfer": ["2H", "4H", "4L"], "transfer_r": [1.0, 1.0, 2.566],
		"spec": {
			"engine": "1GD-FTV 2,755 cc inline-4, 16 valves, turbocharged common-rail diesel",
			"power": "150 kW (204 PS) @ 3,400 rpm", "torque": "420 Nm @ 1,400-3,400 rpm",
			"gearbox": "6-speed manual", "ratios": [4.784, 2.423, 1.443, 1.000, 0.826, 0.643],
			"reverse": 4.066, "final_drive": 3.583,
			"transfer": {"2H": 1.0, "4H": 1.0, "4L": 2.566},
			"kerb_mass_kg": 2120, "wheelbase_mm": 3085, "length_mm": 5325,
			"width_mm": 1855, "height_mm": 1815, "tyres": "265/60 R18",
			"fuel_tank_l": 80,
			"source": "Toyota Hilux AN120 2.8 GD-6 factory specification (see docs/VEHICLE_SPEC_SOURCES.md)",
		},
	},
	{
		"id": "patrol_y61", "name_fa": "پاترول", "name_en": "NISSAN PATROL Y61 3.0 Di",
		"class_fa": "شاسی‌بلند سفری", "class_en": "Full-size expedition 4x4",
		"manufacturer": "Nissan", "year": 2010,
		"trim": "3.0 Di ST wagon, 5-speed manual",
		"desc_fa": "سنگین، صلب و سخت‌جان. دو محور صلب با فنر مارپیچ یعنی کشش واقعی روی سنگ؛ ۳۸۰ نیوتون‌متر و ۲۴۷۸ کیلوگرم یعنی باید با دندهٔ درست رانده شود.",
		"desc_en": "Heavy, rigid and hard to kill. Coil-sprung live axles mean real traction on rock; 380 Nm and 2,478 kg mean it must be driven in the right gear.",
		"price": 6500, "unlock": "pine_02",
		"drive": 2, "torque_split": 0.5,
		"drivetrain_label": "Part-time 4WD, 2H / 4H / 4L",
		"suspension_arch": "3-link coil front, 5-link coil rear, live axles",
		"fuel": "diesel", "tyre": "275/65 R17", "tyre_r": 0.3947, "tyre_w": 0.275,
		"mass": 2478, "wb": 2.970, "len": 5.050, "wid": 1.940, "hgt": 1.855,
		"com": 0.72, "area": 3.30, "cd": 0.78, "inertia": 1.30,
		"brake_f": 3300.0, "brake_r": 2400.0, "handbrake": 4200.0,
		"clutch": 480.0, "clutch_k": 3.0, "durability": 1.22, "impact": 10.5,
		"max_tyre_r": 0.420, "accent": Color(0.30, 0.42, 0.36),
		"family": "zd30", "code": "ZD30DDTi", "aspiration": "turbo_diesel", "comp": 17.9,
		"cc": 2953, "cyl": 4, "boost": 1.0, "spool": 1800.0, "torque_scale": 0.939,
		"inj_cc": 300.0, "inj_kw": 140.0, "pump_lph": 130.0, "pump_kw": 150.0,
		"rad_kw": 122.0, "coolant": 9.8,
		"doc_power": 118.0, "doc_torque": 380.0, "doc_power_rpm": 3200.0, "doc_torque_rpm": 2000.0,
		"redline": 4600.0, "idle": 700.0, "engine_inertia": 0.30, "friction": 26.0,
		"springs": [46000.0, 50000.0], "dampers": [4200.0, 5000.0, 3800.0, 4600.0],
		"travel": [0.30, 0.26, 0.11], "bump": 120000.0,
		"transmissions": [
			{"id": "patrol_m5", "fa": "دستی پنج‌سرعته", "en": "5-speed manual",
				"kind": 0, "ratios": [4.556, 2.625, 1.591, 1.000, 0.837],
				"reverse": 4.246, "final": 4.111, "eff": 0.89, "shift": 0.34},
			{"id": "patrol_a5", "fa": "اتوماتیک پنج‌سرعته", "en": "5-speed automatic",
				"kind": 2, "ratios": [3.540, 2.264, 1.471, 1.000, 0.834],
				"reverse": 2.370, "final": 3.545, "eff": 0.87, "shift": 0.46},
		],
		"stock": "patrol_m5", "transfer": ["2H", "4H", "4L"], "transfer_r": [1.0, 1.0, 2.020],
		"spec": {
			"engine": "ZD30DDTi 2,953 cc inline-4, turbocharged direct-injection diesel",
			"power": "118 kW (160 PS) @ 3,200 rpm", "torque": "380 Nm @ 2,000 rpm",
			"gearbox": "5-speed manual", "ratios": [4.556, 2.625, 1.591, 1.000, 0.837],
			"reverse": 4.246, "final_drive": 4.111,
			"transfer": {"2H": 1.0, "4H": 1.0, "4L": 2.020},
			"kerb_mass_kg": 2478, "wheelbase_mm": 2970, "length_mm": 5050,
			"width_mm": 1940, "height_mm": 1855, "tyres": "275/65 R17",
			"fuel_tank_l": 125,
			"source": "Nissan Patrol Y61 3.0 Di factory specification (see docs/VEHICLE_SPEC_SOURCES.md)",
		},
	},
	{
		"id": "pajero_v80", "name_fa": "پاجرو", "name_en": "MITSUBISHI PAJERO 3.2 DiD",
		"class_fa": "شاسی‌بلند مسابقتی", "class_en": "Endurance SUV",
		"manufacturer": "Mitsubishi", "year": 2012,
		"trim": "3.2 DiD 5-door, 5-speed manual",
		"desc_fa": "تعادل بین راحتی و توان: ۳۵۸ نیوتون‌متر، تعلیق مستقل جلو و پنج دنده. در مسیرهای طولانی و سرازیری‌ها کم‌خسته است.",
		"desc_en": "Comfort and muscle in balance: 358 Nm, independent front suspension and five gears. Tireless on long descents.",
		"price": 8200, "unlock": "alpine_03",
		"drive": 2, "torque_split": 0.42,
		"drivetrain_label": "Super Select 4WD, 2H / 4H / 4HLc / 4LLc",
		"suspension_arch": "Double wishbone front, multi-link rear, independent",
		"fuel": "diesel", "tyre": "265/65 R17", "tyre_r": 0.3882, "tyre_w": 0.265,
		"mass": 2270, "wb": 2.780, "len": 4.900, "wid": 1.875, "hgt": 1.900,
		"com": 0.66, "area": 3.05, "cd": 0.72, "inertia": 1.24,
		"brake_f": 3300.0, "brake_r": 2400.0, "handbrake": 4000.0,
		"clutch": 620.0, "clutch_k": 3.2, "durability": 1.12, "impact": 10.0,
		"max_tyre_r": 0.415, "accent": Color(0.38, 0.46, 0.56),
		"family": "4m41", "code": "4M41", "aspiration": "turbo_diesel", "comp": 16.5,
		"cc": 3200, "cyl": 4, "boost": 1.20, "spool": 1700.0, "torque_scale": 0.761,
		"inj_cc": 330.0, "inj_kw": 148.0, "pump_lph": 140.0, "pump_kw": 160.0,
		"rad_kw": 125.0, "coolant": 10.5,
		"doc_power": 125.0, "doc_torque": 358.0, "doc_power_rpm": 3800.0, "doc_torque_rpm": 2000.0,
		"redline": 4200.0, "idle": 700.0, "engine_inertia": 0.30, "friction": 26.0,
		"springs": [42000.0, 46000.0], "dampers": [3600.0, 4300.0, 3300.0, 4000.0],
		"travel": [0.28, 0.25, 0.10], "bump": 105000.0,
		"transmissions": [
			{"id": "pajero_m5", "fa": "دستی پنج‌سرعته", "en": "5-speed manual",
				"kind": 0, "ratios": [4.234, 2.238, 1.398, 1.000, 0.760],
				"reverse": 3.553, "final": 4.100, "eff": 0.89, "shift": 0.34},
			{"id": "pajero_a5", "fa": "اتوماتیک پنج‌سرعته", "en": "5-speed automatic",
				"kind": 2, "ratios": [3.520, 2.042, 1.400, 1.000, 0.716],
				"reverse": 3.400, "final": 3.917, "eff": 0.88, "shift": 0.44},
		],
		"stock": "pajero_m5", "transfer": ["2H", "4H", "4HLc", "4LLc"],
		"transfer_r": [1.0, 1.0, 1.0, 1.900],
		"spec": {
			"engine": "4M41 3,200 cc inline-4, turbocharged common-rail diesel",
			"power": "125 kW (170 PS) @ 3,800 rpm", "torque": "358 Nm @ 2,000 rpm",
			"gearbox": "5-speed manual", "ratios": [4.234, 2.238, 1.398, 1.000, 0.760],
			"reverse": 3.553, "final_drive": 4.100,
			"transfer": {"2H": 1.0, "4H": 1.0, "4HLc": 1.0, "4LLc": 1.900},
			"kerb_mass_kg": 2270, "wheelbase_mm": 2780, "length_mm": 4900,
			"width_mm": 1875, "height_mm": 1900, "tyres": "265/65 R17",
			"fuel_tank_l": 88,
			"source": "Mitsubishi Pajero V80 3.2 DiD factory specification (see docs/VEHICLE_SPEC_SOURCES.md)",
		},
	},
	{
		"id": "lc79", "name_fa": "لندکروزر ۷۹", "name_en": "TOYOTA LAND CRUISER 79 4.2 D",
		"class_fa": "کامیون آف‌رود", "class_en": "Heavy-duty 4x4 pickup",
		"manufacturer": "Toyota", "year": 2026,
		"trim": "LC79 4.2 D double cab, 5-speed manual",
		"desc_fa": "آخرین مرحله: شش سیلندر ۴.۲ لیتری، محورهای صلب و ۱۳۰ لیتر سوخت. گشتاور از ۲۲۰۰ دور می‌آید و در شیب‌های بی‌رحمانه Black Ridge با دندهٔ کمکی برنده است.",
		"desc_en": "The endgame: a 4.2 litre straight-six, live axles and 130 litres of fuel. Torque arrives at 2,200 rpm and low range owns the brutal Black Ridge grades.",
		"price": 14000, "unlock": "black_ridge_02",
		"drive": 2, "torque_split": 0.5,
		"drivetrain_label": "Part-time 4WD, 2H / 4H / 4L",
		"suspension_arch": "Rigid axle coil front, rigid axle leaf rear",
		"fuel": "diesel", "tyre": "265/70 R16", "tyre_r": 0.3887, "tyre_w": 0.265,
		"mass": 2225, "wb": 3.180, "len": 5.235, "wid": 1.870, "hgt": 1.945,
		"com": 0.70, "area": 3.20, "cd": 0.80, "inertia": 1.28,
		"brake_f": 3100.0, "brake_r": 2200.0, "handbrake": 4400.0,
		"clutch": 520.0, "clutch_k": 3.2, "durability": 1.30, "impact": 11.0,
		"max_tyre_r": 0.430, "accent": Color(0.78, 0.70, 0.55),
		"family": "1hz", "code": "1HZ", "aspiration": "na_diesel", "comp": 22.4,
		"cc": 4164, "cyl": 6, "boost": 0.0, "spool": 0.0, "torque_scale": 0.827,
		"inj_cc": 420.0, "inj_kw": 108.0, "pump_lph": 120.0, "pump_kw": 116.0,
		"rad_kw": 92.0, "coolant": 13.4,
		"doc_power": 96.0, "doc_torque": 285.0, "doc_power_rpm": 3800.0, "doc_torque_rpm": 2200.0,
		"redline": 4200.0, "idle": 650.0, "engine_inertia": 0.34, "friction": 34.0,
		"springs": [50000.0, 56000.0], "dampers": [4600.0, 5400.0, 4200.0, 5000.0],
		"travel": [0.30, 0.27, 0.11], "bump": 135000.0,
		"transmissions": [
			{"id": "lc79_m5", "fa": "دستی پنج‌سرعته", "en": "5-speed manual",
				"kind": 0, "ratios": [4.313, 2.330, 1.436, 1.000, 0.838],
				"reverse": 4.220, "final": 4.100, "eff": 0.89, "shift": 0.32},
			{"id": "lc79_a6", "fa": "اتوماتیک شش‌سرعته", "en": "6-speed automatic",
				"kind": 2, "ratios": [3.600, 2.090, 1.488, 1.000, 0.687, 0.580],
				"reverse": 3.732, "final": 3.909, "eff": 0.87, "shift": 0.42},
		],
		"stock": "lc79_m5", "transfer": ["2H", "4H", "4L"], "transfer_r": [1.0, 1.0, 2.488],
		"spec": {
			"engine": "1HZ 4,164 cc inline-6, 12 valves, naturally aspirated diesel",
			"power": "96 kW (130 PS) @ 3,800 rpm", "torque": "285 Nm @ 2,200 rpm",
			"gearbox": "5-speed manual", "ratios": [4.313, 2.330, 1.436, 1.000, 0.838],
			"reverse": 4.220, "final_drive": 4.100,
			"transfer": {"2H": 1.0, "4H": 1.0, "4L": 2.488},
			"kerb_mass_kg": 2225, "wheelbase_mm": 3180, "length_mm": 5235,
			"width_mm": 1870, "height_mm": 1945, "tyres": "265/70 R16",
			"fuel_tank_l": 130,
			"source": "Toyota South Africa Land Cruiser 79 Double Cab specification sheet (see docs/VEHICLE_SPEC_SOURCES.md)",
		},
	},
]

# ------------------------------------------------------------------ builder ---

static func _from_row(row: Dictionary) -> VehicleDef:
	var v := VehicleDef.new()
	v.id = String(row["id"])
	v.name_fa = String(row["name_fa"])
	v.name_en = String(row["name_en"])
	v.class_fa = String(row["class_fa"])
	v.class_en = String(row["class_en"])
	v.description_fa = String(row["desc_fa"])
	v.description_en = String(row["desc_en"])
	v.manufacturer = String(row["manufacturer"])
	v.model_year = int(row["year"])
	v.trim = String(row["trim"])
	v.price = int(row["price"])
	v.unlock_track = String(row["unlock"])
	v.drivetrain = int(row["drive"])
	v.torque_split_front = float(row["torque_split"])
	v.drivetrain_label = String(row["drivetrain_label"])
	v.suspension_arch = String(row["suspension_arch"])
	v.fuel_type = String(row["fuel"])
	v.tyre_size_label = String(row["tyre"])

	v.mass_kg = float(row["mass"])
	v.wheelbase_m = float(row["wb"])
	v.length_m = float(row["len"])
	v.width_m = float(row["wid"])
	v.height_m = float(row["hgt"])
	v.com_height_m = float(row["com"])
	v.frontal_area_m2 = float(row["area"])
	v.drag_cd = float(row["cd"])
	v.inertia_scale = float(row["inertia"])
	v.brake_torque_front = float(row["brake_f"])
	v.brake_torque_rear = float(row["brake_r"])
	v.handbrake_torque = float(row["handbrake"])
	v.clutch_capacity = float(row["clutch"])
	v.clutch_stiffness = float(row["clutch_k"])
	v.durability = float(row["durability"])
	v.impact_tolerance = float(row["impact"])
	v.max_tyre_radius_m = float(row["max_tyre_r"])
	v.accent_color = row["accent"] as Color

	v.engine_family = String(row["family"])
	v.engine_code = String(row["code"])
	v.aspiration = String(row["aspiration"])
	v.compression = float(row["comp"])
	v.displacement_cc = int(row["cc"])
	v.cylinders = int(row["cyl"])
	v.stock_boost_bar = float(row["boost"])
	v.stock_spool_rpm = float(row["spool"])
	# Calibrate the generic engine model to this engine's documented torque, using
	# the stock air path (the stock exhaust costs 3 % flow in EngineBuild). This is
	# the only per-engine calibration constant in the whole simulation.
	var disp_l: float = float(row["cc"]) / 1000.0
	var boost0: float = float(row["boost"])
	var density0: float = 1.0
	if boost0 > 0.01:
		var charge0: float = 25.0 + (38.0 + 95.0 * boost0) * 0.45
		density0 = (1.0 + boost0 / 1.013) * (298.15 / (273.15 + charge0))
	var raw_torque: float = 92.0 * disp_l * density0 * 0.90 * 0.97
	v.engine_torque_scale = float(row["doc_torque"]) / maxf(raw_torque, 1.0)
	v.injector_max_kw = float(row["doc_power"]) * 1.06
	v.pump_max_kw = float(row["doc_power"]) * 1.10
	v.injector_flow_cc = float(row["inj_cc"])
	v.pump_lph = float(row["pump_lph"])
	v.radiator_kw = float(row["rad_kw"])
	v.coolant_l = float(row["coolant"])
	v.doc_power_kw = float(row["doc_power"])
	v.doc_torque_nm = float(row["doc_torque"])
	v.doc_power_rpm = float(row["doc_power_rpm"])
	v.doc_torque_rpm = float(row["doc_torque_rpm"])
	v.engine_hold_rpm = float(row.get("hold_rpm", 0.0))
	v.spec = row["spec"] as Dictionary

	var e := EngineConfig.new()
	e.display_name = v.engine_code
	e.idle_rpm = float(row["idle"])
	e.max_rpm = float(row["redline"])
	e.redline_rpm = float(row["redline"]) - 100.0
	e.stall_rpm = maxf(320.0, e.idle_rpm * 0.46)
	e.inertia = float(row["engine_inertia"])
	e.friction_torque = float(row["friction"])
	e.turbo_gain = 0.18 if v.aspiration.find("turbo") >= 0 else 0.0
	e.turbo_rpm = v.stock_spool_rpm
	e.turbo_width = 1800.0 if v.aspiration.find("turbo") >= 0 else 0.0
	v.engine = e

	var list: Array[TransmissionProfile] = []
	for raw: Variant in (row["transmissions"] as Array):
		var t := _trans(raw as Dictionary, float(row["doc_torque"]))
		list.append(t)
	v.transmissions = list
	v.stock_transmission = String(row["stock"])
	var stock: TransmissionProfile = v.stock_transmission_profile()
	if stock != null:
		var g := GearboxConfig.new()
		g.display_name = stock.name_en
		g.ratios = stock.ratios
		g.reverse_ratio = stock.reverse_ratio
		g.final_drive = stock.final_drive
		g.efficiency = stock.efficiency
		g.shift_time = stock.shift_time
		v.gearbox = g
	if stock != null and stock.kind == TransmissionProfile.Kind.AUTOMATIC:
		v.clutch_capacity = maxf(v.clutch_capacity, v.doc_torque_nm * 1.6)

	v.transfer_ids = _str_array(row["transfer"] as Array)
	v.transfer_ratios = _float_array(row["transfer_r"] as Array)
	v.default_transfer = v.transfer_ids[mini(1, v.transfer_ids.size() - 1)] if v.transfer_ids.size() > 1 else ""
	v.diff_modes = PackedStringArray(["open", "lsd", "locked"])
	v.default_diff = "open" if v.id == "jimny_jb74" or v.id == "lc79" else "lsd"

	var springs: Array = row["springs"] as Array
	var dampers: Array = row["dampers"] as Array
	var travel: Array = row["travel"] as Array
	v.suspension = _susp(float(travel[0]), float(travel[1]), float(travel[2]),
		float(springs[0]), float(springs[1]),
		float(dampers[0]), float(dampers[1]), float(dampers[2]), float(dampers[3]),
		float(row["bump"]))
	v.tire_front = _tire(float(row["tyre_r"]), float(row["tyre_w"]), _wheel_mass(v),
		0.98, 0.030, 0.15)
	v.tire_rear = v.tire_front

	v.has_winch = v.id != "jimny_jb74"
	v.winch_force_n = v.mass_kg * 7.5
	v.winch_rope_m = 22.0
	v.sprite_body = "res://assets/vehicles/%s/body.svg" % v.id
	v.sprite_wheel = "res://assets/vehicles/%s/wheel.svg" % v.id
	v.body_polygon_m = _hull(v.length_m, v.height_m)
	v.tire_options = [
		{"id": "at", "name_fa": "آل‌ترین", "name_en": "All-terrain", "mu_mult": 1.0, "rr_mult": 1.0},
		{"id": "mt", "name_fa": "گلی", "name_en": "Mud-terrain", "mu_mult": 1.06, "rr_mult": 1.10},
		{"id": "snow", "name_fa": "برفی", "name_en": "Snow", "mu_mult": 0.98, "rr_mult": 1.16},
	]
	v.suspension_options = [
		{"id": "stock", "name_fa": "استاندارد", "name_en": "Stock", "spring_mult": 1.0,
			"damper_mult": 1.0, "travel_mult": 1.0, "ride_mult": 1.0},
		{"id": "long", "name_fa": "کورس بلند", "name_en": "Long-travel", "spring_mult": 0.96,
			"damper_mult": 1.08, "travel_mult": 1.1, "ride_mult": 1.02},
	]
	return v

static func _trans(raw: Dictionary, doc_torque: float) -> TransmissionProfile:
	var t := TransmissionProfile.new()
	t.id = String(raw["id"])
	t.name_fa = String(raw["fa"])
	t.name_en = String(raw["en"])
	t.kind = int(raw["kind"])
	t.ratios = _float_array(raw["ratios"] as Array)
	t.reverse_ratio = float(raw["reverse"])
	t.final_drive = float(raw["final"])
	t.efficiency = float(raw["eff"])
	t.shift_time = float(raw["shift"])
	t.max_torque_nm = maxf(doc_torque * 1.25, 300.0)
	# A torque-converter automatic has no clutch pedal: the converter and its lock-up
	# replace it. Only the manual boxes (H-pattern and sequential with a pedal) ask
	# the player for a clutch.
	t.requires_clutch = t.kind != TransmissionProfile.Kind.MANUAL_SEQ \
		and t.kind != TransmissionProfile.Kind.AUTOMATIC
	if t.kind == TransmissionProfile.Kind.AUTOMATIC:
		t.clutch_type = "torque_converter"
		t.converter_stall_mult = 1.9
		t.converter_lock_rpm = 1400.0
		t.auto_upshift_fraction = 0.68
		t.auto_downshift_fraction = 0.30
		t.kickdown_rpm_fraction = 0.55
		t.ranges = PackedStringArray(["P", "R", "N", "D", "L"])
	return t

static func _susp(rest: float, travel: float, droop: float, sf: float, sr: float,
		dcf: float, drf: float, dcr: float, drr: float, bump: float) -> SuspensionConfig:
	var s := SuspensionConfig.new()
	s.rest_length_m = rest
	s.travel_m = travel
	s.droop_m = droop
	s.spring_front = sf
	s.spring_rear = sr
	s.damper_compression_front = dcf
	s.damper_rebound_front = drf
	s.damper_compression_rear = dcr
	s.damper_rebound_rear = drr
	s.bump_stop_rate = bump
	return s

static func _tire(radius: float, width: float, wheel_mass: float, mu: float, rr: float,
		peak_slip: float) -> TireConfig:
	var t := TireConfig.new()
	t.radius_m = radius
	t.width_m = width
	t.wheel_mass_kg = wheel_mass
	t.mu_scale = mu
	t.rolling_resistance = rr
	t.peak_slip = peak_slip
	t.pressure_bar = 2.1
	return t

static func _wheel_mass(v: VehicleDef) -> float:
	return clampf(v.mass_kg * 0.017, 16.0, 42.0)

static func _hull(length_m: float, height_m: float) -> PackedVector2Array:
	var half: float = length_m * 0.5
	var top: float = -height_m
	return PackedVector2Array([
		Vector2(-half, 0.06), Vector2(-half, -0.40), Vector2(-half + 0.34, top + 0.03),
		Vector2(-half * 0.35, top), Vector2(half * 0.40, top), Vector2(half - 0.26, top + 0.10),
		Vector2(half, -0.46), Vector2(half, 0.08), Vector2(half * 0.25, 0.11),
		Vector2(-half * 0.25, 0.11),
	])

static func _float_array(raw: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for v: Variant in raw:
		out.append(float(v))
	return out

static func _str_array(raw: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for v: Variant in raw:
		out.append(String(v))
	return out
