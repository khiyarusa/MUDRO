extends Node
## ContentDB (autoload "Content"): the single runtime source of game data.
## Surfaces, vehicles, upgrades and stages are all Resource instances built from
## the typed authoring tables below. tools/export_resource_defs.gd writes them to
## resources/*.tres so they can also be inspected inside the Godot editor.

var surfaces: Dictionary = {}
var vehicles: Array[VehicleDef] = []
var stages: Array[StageDef] = []
var environments: Array[Dictionary] = []
var upgrades: Array[UpgradeDef] = []

func _ready() -> void:
	_build_surfaces()
	_build_vehicles()
	_build_upgrades()
	_build_environments()
	_build_stages()

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
	vehicles.clear()

	# 1. ROCKY BUGGY — light, short, huge travel, high-revving, RWD.
	var buggy := VehicleDef.new()
	buggy.id = "rocky_buggy"
	buggy.name_fa = "باگی راکی"
	buggy.name_en = "ROCKY BUGGY"
	buggy.class_fa = "باگی سبک"
	buggy.class_en = "Light tube-frame buggy"
	buggy.description_fa = "سبک و چابک با فاصله محوری کوتاه و تعلیق بلند. در پرش و مسیرهای فنی بی‌رقیب است، اما گشتاور کمتری برای شیب‌های طولانی دارد."
	buggy.description_en = "Light and eager, short wheelbase and long travel. Untouchable over jumps and technical lines, but short on torque for long climbs."
	buggy.price = 0
	buggy.mass_kg = 620.0
	buggy.wheelbase_m = 2.05
	buggy.length_m = 3.0
	buggy.height_m = 1.45
	buggy.com_height_m = 0.30
	buggy.frontal_area_m2 = 1.7
	buggy.drag_cd = 0.72
	buggy.inertia_scale = 0.92
	buggy.drivetrain = VehicleDef.Drivetrain.RWD
	buggy.torque_split_front = 0.0
	buggy.brake_torque_front = 1400.0
	buggy.brake_torque_rear = 1150.0
	buggy.handbrake_torque = 2400.0
	buggy.clutch_capacity = 260.0
	buggy.clutch_stiffness = 2.1
	buggy.durability = 0.82
	buggy.impact_tolerance = 7.5
	buggy.sprite_body = "res://assets/vehicles/rocky_buggy/body.svg"
	buggy.sprite_wheel = "res://assets/vehicles/rocky_buggy/wheel.svg"
	buggy.accent_color = Color(0.85, 0.36, 0.18)
	buggy.body_polygon_m = PackedVector2Array([
		Vector2(-1.45, 0.02), Vector2(-1.42, -0.48), Vector2(-0.92, -0.66),
		Vector2(-0.42, -1.10), Vector2(0.30, -1.13), Vector2(0.78, -0.74),
		Vector2(1.34, -0.60), Vector2(1.46, -0.22), Vector2(1.42, 0.08),
		Vector2(0.60, 0.12), Vector2(-0.60, 0.12),
	])
	buggy.engine = _engine("1.6L four", 850.0, 7000.0, 6600.0, 0.115, 9.0,
		PackedFloat32Array([800, 1500, 2500, 3500, 4500, 5500, 6500, 7000]),
		PackedFloat32Array([95, 132, 160, 175, 178, 166, 138, 92]))
	buggy.gearbox = _gearbox(PackedFloat32Array([3.9, 2.45, 1.75, 1.30, 1.00]), 3.4, 4.3, 0.90, 0.16)
	buggy.tire_front = _tire(0.33, 0.22, 16.0, 1.02, 0.030, 0.15)
	buggy.tire_rear = _tire(0.34, 0.26, 18.0, 1.05, 0.032, 0.15)
	buggy.suspension = _susp(0.30, 0.30, 0.12, 21000.0, 19000.0, 1500.0, 1900.0, 1400.0, 1800.0, 70000.0)
	vehicles.append(buggy)

	# 2. RANGER 4X4 — balanced expedition SUV, AWD, torquey diesel.
	var ranger := VehicleDef.new()
	ranger.id = "ranger_4x4"
	ranger.name_fa = "رنجر ۴×۴"
	ranger.name_en = "RANGER 4X4"
	ranger.class_fa = "شاسی‌بلند سفر"
	ranger.class_en = "Expedition 4x4"
	ranger.description_fa = "متعادل‌ترین انتخاب. چهار چرخ محرک، گشتاور خوب در دور پایین و تعلیق قابل اعتماد. هر مسیری را می‌شود با آن شروع کرد."
	ranger.description_en = "The balanced choice. All-wheel drive, strong low-range torque and dependable suspension. Every trail is approachable."
	ranger.price = 2500
	ranger.unlock_stage = "canyon_02"
	ranger.mass_kg = 1180.0
	ranger.wheelbase_m = 2.70
	ranger.length_m = 4.30
	ranger.height_m = 1.95
	ranger.com_height_m = 0.30
	ranger.frontal_area_m2 = 2.5
	ranger.drag_cd = 0.66
	ranger.drivetrain = VehicleDef.Drivetrain.AWD
	ranger.torque_split_front = 0.42
	ranger.brake_torque_front = 2200.0
	ranger.brake_torque_rear = 1600.0
	ranger.handbrake_torque = 3200.0
	ranger.clutch_capacity = 460.0
	ranger.clutch_stiffness = 2.5
	ranger.durability = 1.0
	ranger.impact_tolerance = 9.0
	ranger.sprite_body = "res://assets/vehicles/ranger_4x4/body.svg"
	ranger.sprite_wheel = "res://assets/vehicles/ranger_4x4/wheel.svg"
	ranger.accent_color = Color(0.30, 0.52, 0.40)
	ranger.body_polygon_m = PackedVector2Array([
		Vector2(-2.15, 0.02), Vector2(-2.15, -0.92), Vector2(-1.42, -1.02),
		Vector2(-0.62, -1.60), Vector2(0.68, -1.63), Vector2(1.24, -1.12),
		Vector2(2.08, -0.98), Vector2(2.15, -0.36), Vector2(2.08, 0.06),
		Vector2(0.50, 0.10), Vector2(-0.50, 0.10), Vector2(-2.10, 0.06),
	])
	ranger.engine = _engine("2.8L turbodiesel", 760.0, 4800.0, 4500.0, 0.26, 20.0,
		PackedFloat32Array([700, 1200, 1800, 2400, 3000, 3600, 4200, 4800]),
		PackedFloat32Array([170, 240, 285, 292, 278, 252, 212, 148]))
	ranger.engine.turbo_gain = 0.14
	ranger.engine.turbo_rpm = 2200.0
	ranger.engine.turbo_width = 1500.0
	ranger.gearbox = _gearbox(PackedFloat32Array([4.20, 2.40, 1.55, 1.15, 0.85]), 4.0, 3.9, 0.89, 0.24)
	ranger.tire_front = _tire(0.39, 0.25, 28.0, 1.00, 0.028, 0.14)
	ranger.tire_rear = _tire(0.39, 0.25, 28.0, 1.00, 0.028, 0.14)
	ranger.suspension = _susp(0.26, 0.22, 0.09, 36000.0, 33000.0, 3000.0, 3800.0, 2800.0, 3500.0, 95000.0)
	vehicles.append(ranger)

	# 3. DUNE PICKUP — heavy, long, big V8 torque, RWD.
	var pickup := VehicleDef.new()
	pickup.id = "dune_pickup"
	pickup.name_fa = "پیکاپ دوون"
	pickup.name_en = "DUNE PICKUP"
	pickup.class_fa = "پیکاپ سنگین"
	pickup.class_en = "Heavy desert pickup"
	pickup.description_fa = "موتور بزرگ، شتاب خشن و بار زیاد روی محور عقب. در شن و سربالایی قدرت دارد اما در پیچ‌ها و پرش‌ها سنگین است."
	pickup.description_en = "Big engine, brutal acceleration and weight over the rear axle. Strong in sand and climbs, heavy over crests and landings."
	pickup.price = 7000
	pickup.unlock_stage = "pine_01"
	pickup.mass_kg = 1650.0
	pickup.wheelbase_m = 3.20
	pickup.length_m = 5.10
	pickup.height_m = 1.95
	pickup.com_height_m = 0.32
	pickup.frontal_area_m2 = 3.0
	pickup.drag_cd = 0.70
	pickup.inertia_scale = 1.08
	pickup.drivetrain = VehicleDef.Drivetrain.RWD
	pickup.torque_split_front = 0.0
	pickup.brake_torque_front = 2800.0
	pickup.brake_torque_rear = 2000.0
	pickup.handbrake_torque = 4200.0
	pickup.clutch_capacity = 620.0
	pickup.clutch_stiffness = 2.8
	pickup.durability = 1.08
	pickup.impact_tolerance = 10.0
	pickup.sprite_body = "res://assets/vehicles/dune_pickup/body.svg"
	pickup.sprite_wheel = "res://assets/vehicles/dune_pickup/wheel.svg"
	pickup.accent_color = Color(0.78, 0.62, 0.26)
	pickup.body_polygon_m = PackedVector2Array([
		Vector2(-2.55, 0.02), Vector2(-2.50, -1.02), Vector2(-1.02, -1.08),
		Vector2(-0.56, -1.60), Vector2(0.54, -1.62), Vector2(0.94, -1.06),
		Vector2(2.50, -1.02), Vector2(2.55, -0.46), Vector2(2.48, 0.06),
		Vector2(0.60, 0.10), Vector2(-0.60, 0.10), Vector2(-2.50, 0.06),
	])
	pickup.engine = _engine("5.3L V8", 700.0, 6000.0, 5600.0, 0.34, 24.0,
		PackedFloat32Array([700, 1200, 2000, 3000, 4000, 4800, 5600, 6000]),
		PackedFloat32Array([300, 380, 442, 470, 466, 428, 356, 246]))
	pickup.gearbox = _gearbox(PackedFloat32Array([3.40, 2.15, 1.55, 1.20, 1.00, 0.82]), 3.2, 3.55, 0.90, 0.22)
	pickup.tire_front = _tire(0.43, 0.29, 36.0, 0.98, 0.030, 0.14)
	pickup.tire_rear = _tire(0.43, 0.31, 38.0, 0.99, 0.032, 0.14)
	pickup.suspension = _susp(0.24, 0.24, 0.10, 42000.0, 38000.0, 3300.0, 4200.0, 3100.0, 3900.0, 105000.0)
	vehicles.append(pickup)

	# 4. TITAN OFFROAD — heaviest, enormous low-rpm torque, AWD, slow.
	var titan := VehicleDef.new()
	titan.id = "titan_offroad"
	titan.name_fa = "تایتان آف‌رود"
	titan.name_en = "TITAN OFFROAD"
	titan.class_fa = "کامیون سنگین"
	titan.class_en = "Heavy expedition truck"
	titan.description_fa = "سنگین‌ترین ماشین با گشتاور عظیم در دور پایین و تعلیق فوق‌سنگین. در شیب‌های تند برنده است، اما کند و کم‌چابک."
	titan.description_en = "The heaviest machine: immense low-rpm torque and heavy-duty suspension. It owns steep grades and hates being hurried."
	titan.price = 14000
	titan.unlock_stage = "quarry_01"
	titan.mass_kg = 2350.0
	titan.wheelbase_m = 3.55
	titan.length_m = 5.80
	titan.height_m = 2.25
	titan.com_height_m = 0.38
	titan.frontal_area_m2 = 4.1
	titan.drag_cd = 0.86
	titan.inertia_scale = 1.22
	titan.drivetrain = VehicleDef.Drivetrain.AWD
	titan.torque_split_front = 0.46
	titan.brake_torque_front = 4200.0
	titan.brake_torque_rear = 3200.0
	titan.handbrake_torque = 6000.0
	titan.clutch_capacity = 980.0
	titan.clutch_stiffness = 3.4
	titan.durability = 1.35
	titan.impact_tolerance = 11.0
	titan.sprite_body = "res://assets/vehicles/titan_offroad/body.svg"
	titan.sprite_wheel = "res://assets/vehicles/titan_offroad/wheel.svg"
	titan.accent_color = Color(0.62, 0.34, 0.22)
	titan.body_polygon_m = PackedVector2Array([
		Vector2(-2.88, 0.04), Vector2(-2.84, -1.10), Vector2(-2.18, -1.22),
		Vector2(-2.00, -1.92), Vector2(-0.42, -1.98), Vector2(0.58, -1.88),
		Vector2(1.00, -1.18), Vector2(2.82, -1.08), Vector2(2.88, -0.48),
		Vector2(2.80, 0.10), Vector2(0.60, 0.14), Vector2(-0.60, 0.14),
		Vector2(-2.84, 0.06),
	])
	titan.engine = _engine("6.0L diesel", 640.0, 3400.0, 3100.0, 0.52, 32.0,
		PackedFloat32Array([600, 900, 1400, 1800, 2400, 3000, 3400]),
		PackedFloat32Array([520, 650, 720, 726, 676, 556, 372]))
	titan.gearbox = _gearbox(PackedFloat32Array([6.00, 3.30, 2.05, 1.40, 1.00, 0.78]), 5.8, 5.2, 0.87, 0.34)
	titan.tire_front = _tire(0.51, 0.33, 54.0, 1.00, 0.032, 0.13)
	titan.tire_rear = _tire(0.51, 0.35, 58.0, 1.02, 0.033, 0.13)
	titan.suspension = _susp(0.30, 0.26, 0.10, 62000.0, 68000.0, 5200.0, 6400.0, 5600.0, 6800.0, 150000.0)
	vehicles.append(titan)

func _engine(name: String, idle: float, max_rpm: float, redline: float, inertia: float,
		friction: float, rpms: PackedFloat32Array, torques: PackedFloat32Array) -> EngineConfig:
	var e := EngineConfig.new()
	e.display_name = name
	e.idle_rpm = idle
	e.max_rpm = max_rpm
	e.redline_rpm = redline
	e.stall_rpm = maxf(380.0, idle * 0.48)
	e.inertia = inertia
	e.friction_torque = friction
	e.curve_rpm = rpms
	e.curve_torque = torques
	return e

func _gearbox(ratios: PackedFloat32Array, reverse: float, final: float, eff: float, shift: float) -> GearboxConfig:
	var g := GearboxConfig.new()
	g.ratios = ratios
	g.reverse_ratio = reverse
	g.final_drive = final
	g.efficiency = eff
	g.shift_time = shift
	return g

func _tire(radius: float, width: float, wheel_mass: float, mu: float, rr: float, peak_slip: float) -> TireConfig:
	var t := TireConfig.new()
	t.radius_m = radius
	t.width_m = width
	t.wheel_mass_kg = wheel_mass
	t.mu_scale = mu
	t.rolling_resistance = rr
	t.peak_slip = peak_slip
	return t

func _susp(rest: float, travel: float, droop: float, sf: float, sr: float,
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

# ---------------------------------------------------------------- upgrades ---

func _build_upgrades() -> void:
	upgrades.clear()
	# ENGINE: real torque multiplier + a small redline increase.
	_add_upgrade("engine_1", UpgradeDef.Category.ENGINE, 1, "فیلتر و اگزوز", "Intake & exhaust",
		"جریان هوا بهتر، گشتاور کل ۸٪ بیشتر.", "Better breathing, +8% torque everywhere.", 500, 1.08, 0.0, 150.0)
	_add_upgrade("engine_2", UpgradeDef.Category.ENGINE, 2, "کامپیوتر موتور", "Engine management",
		"نقشه سوخت بازنویسی شده: ۱۸٪ گشتاور و ۳۰۰ دور بیشتر.", "Retuned fuel map: +18% torque, +300 rpm.", 1400, 1.18, 0.0, 300.0)
	_add_upgrade("engine_3", UpgradeDef.Category.ENGINE, 3, "توربوشارژ", "Turbocharger",
		"گشتاور ۳۲٪ و سقف دور بالاتر، با تأخیر توربو.", "Turbo: +32% torque and a higher limiter, with lag.", 3200, 1.32, 0.0, 400.0)
	# GEARBOX: shorter final drive for climbing, faster shifts.
	_add_upgrade("gearbox_1", UpgradeDef.Category.GEARBOX, 1, "کلاچ تقویت‌شده", "Reinforced clutch",
		"ظرفیت کلاچ بیشتر، تعویض ۱۵٪ سریع‌تر.", "More clutch capacity, 15% faster shifts.", 550, 0.0, 0.0, 0.0, 1.0, 1.0, 0.85)
	_add_upgrade("gearbox_2", UpgradeDef.Category.GEARBOX, 2, "نسبت‌های کوتاه", "Close-ratio set",
		"نسبت‌ها ۱۲٪ کوتاه‌تر: کشش بیشتر، سرعت کمتر.", "12% shorter ratios: more pull, less top speed.", 1600, 0.0, 0.0, 0.0, 1.12, 1.18, 1.0)
	_add_upgrade("gearbox_3", UpgradeDef.Category.GEARBOX, 3, "گیربکس مسابقه", "Race gearbox",
		"تعویض خیلی سریع و نسبت نهایی بهینه برای شیب.", "Very fast shifts and a climb-biased final drive.", 3600, 0.0, 0.0, 0.0, 1.18, 1.26, 0.65)
	# DIFFERENTIAL: traction split and lock.
	_add_upgrade("diff_1", UpgradeDef.Category.DIFFERENTIAL, 1, "دیفرانسیل لغزش محدود", "Limited slip",
		"تقسیم گشتاور بهتر، چسبندگی ۵٪ بیشتر.", "Better torque split, +5% effective grip.", 700, 1.05)
	_add_upgrade("diff_2", UpgradeDef.Category.DIFFERENTIAL, 2, "قفل کامل", "Full locker",
		"هر دو محور قفل: ۱۰٪ چسبندگی بیشتر.", "Locked axles: +10% effective grip.", 1900, 1.10)
	_add_upgrade("diff_3", UpgradeDef.Category.DIFFERENTIAL, 3, "دیفرانسیل فعال", "Active diff",
		"توزیع هوشمند گشتاور: ۱۶٪ چسبندگی بیشتر.", "Active torque vectoring: +16% effective grip.", 3800, 1.16)
	# SUSPENSION
	_add_upgrade("susp_1", UpgradeDef.Category.SUSPENSION, 1, "کمک‌فنر گازی", "Gas dampers",
		"میرایی ۱۵٪ بهتر و ۵٪ فنر نرم‌تر.", "15% better damping, 5% softer springs.", 600, 0.95, 1.15, 1.0)
	_add_upgrade("susp_2", UpgradeDef.Category.SUSPENSION, 2, "کیت بلند", "Long-travel kit",
		"۱۰٪ کورس بیشتر، فنر و میرایی تقویت‌شده.", "10% more travel, stronger springs and damping.", 1800, 1.12, 1.28, 1.10)
	_add_upgrade("susp_3", UpgradeDef.Category.SUSPENSION, 3, "تعلیق مسابقه‌ای", "Race suspension",
		"کورس ۲۰٪ بیشتر و کنترل کامل روی دست‌اندازها.", "20% more travel and full control over bumps.", 3900, 1.22, 1.45, 1.20)
	# TIRES
	_add_upgrade("tires_1", UpgradeDef.Category.TIRES, 1, "لاستیک آفرود", "All-terrain tyres",
		"چسبندگی ۷٪ بیشتر، مقاومت غلتشی کمی کمتر.", "+7% grip, slightly lower rolling resistance.", 650, 1.07, 0.95)
	_add_upgrade("tires_2", UpgradeDef.Category.TIRES, 2, "لاستیک گلی", "Mud-terrain tyres",
		"چسبندگی ۱۵٪ بیشتر روی گل و سنگ.", "+15% grip on mud and rock.", 1700, 1.15, 0.92)
	_add_upgrade("tires_3", UpgradeDef.Category.TIRES, 3, "لاستیک مسابقه", "Competition tyres",
		"چسبندگی ۲۴٪ بیشتر با لاستیک نرم‌تر.", "+24% grip from a softer compound.", 3500, 1.24, 0.90)
	# BRAKES
	_add_upgrade("brakes_1", UpgradeDef.Category.BRAKES, 1, "لنت سرامیکی", "Ceramic pads",
		"نیروی ترمز ۱۲٪ بیشتر.", "+12% braking force.", 450, 1.12)
	_add_upgrade("brakes_2", UpgradeDef.Category.BRAKES, 2, "دیسک بزرگ", "Big brake kit",
		"نیروی ترمز ۲۵٪ بیشتر.", "+25% braking force.", 1300, 1.25)
	_add_upgrade("brakes_3", UpgradeDef.Category.BRAKES, 3, "ترمز مسابقه", "Rally brakes",
		"نیروی ترمز ۴۰٪ بیشتر و خنک‌کاری بهتر.", "+40% braking force and better cooling.", 3000, 1.40)
	# CHASSIS
	_add_upgrade("chassis_1", UpgradeDef.Category.CHASSIS, 1, "قفس تقویتی", "Roll cage",
		"دوام ۲۰٪ بیشتر، ۳۰ کیلوگرم سنگین‌تر.", "+20% durability, +30 kg.", 800, 1.20, 30.0)
	_add_upgrade("chassis_2", UpgradeDef.Category.CHASSIS, 2, "ورق فولادی", "Steel plating",
		"دوام ۴۵٪ بیشتر، ۷۰ کیلوگرم سنگین‌تر.", "+45% durability, +70 kg.", 2100, 1.45, 70.0)
	_add_upgrade("chassis_3", UpgradeDef.Category.CHASSIS, 3, "شاسی مسابقه", "Rally chassis",
		"دوام ۷۵٪ بیشتر و پیچش بدنه کمتر.", "+75% durability, less body flex.", 4200, 1.75, 45.0)

func _add_upgrade(id: String, cat: UpgradeDef.Category, tier: int, fa: String, en: String,
		desc_fa: String, desc_en: String, cost: int, grip_or_torque: float = 1.0,
		extra_a: float = 0.0, extra_b: float = 0.0, ratio_mult: float = 1.0,
		final_mult: float = 1.0, shift_mult: float = 1.0) -> void:
	var u := UpgradeDef.new()
	u.id = id
	u.category = cat
	u.tier = tier
	u.name_fa = fa
	u.name_en = en
	u.desc_fa = desc_fa
	u.desc_en = desc_en
	u.cost = cost
	match cat:
		UpgradeDef.Category.ENGINE:
			u.torque_mult = grip_or_torque
			u.redline_add = extra_b
		UpgradeDef.Category.GEARBOX:
			u.gear_ratio_mult = ratio_mult
			u.final_drive_mult = final_mult
			u.shift_time_mult = shift_mult
		UpgradeDef.Category.DIFFERENTIAL:
			u.grip_mult = grip_or_torque
		UpgradeDef.Category.SUSPENSION:
			u.spring_mult = grip_or_torque
			u.damper_mult = extra_a
			u.travel_mult = extra_b if extra_b > 0.0 else 1.0
			if u.travel_mult <= 0.0:
				u.travel_mult = 1.0
		UpgradeDef.Category.TIRES:
			u.grip_mult = grip_or_torque
			u.rolling_mult = extra_a
		UpgradeDef.Category.BRAKES:
			u.brake_mult = grip_or_torque
		UpgradeDef.Category.CHASSIS:
			u.durability_mult = grip_or_torque
			u.mass_add = extra_a
	upgrades.append(u)

func _build_environments() -> void:
	environments = [
		{
			"id": "canyon", "name_fa": "درهٔ خشک", "name_en": "DRY CANYON",
			"desc_fa": "صخره‌های سرخ، شن و گردنه‌های تند.",
			"desc_en": "Red rock, sand and steep passes.",
			"accent": Color(0.86, 0.45, 0.24), "ambience": "ambience_canyon",
			"sky_top": Color(0.55, 0.44, 0.36), "sky_bottom": Color(0.95, 0.78, 0.58),
		},
		{
			"id": "pine", "name_fa": "ارتفاعات کاج", "name_en": "PINE HIGHLANDS",
			"desc_fa": "جنگل خیس، گل و تنه‌های افتاده.",
			"desc_en": "Wet forest, mud and fallen timber.",
			"accent": Color(0.42, 0.62, 0.48), "ambience": "ambience_pine",
			"sky_top": Color(0.42, 0.48, 0.50), "sky_bottom": Color(0.74, 0.79, 0.78),
		},
		{
			"id": "quarry", "name_fa": "معدن آلپی", "name_en": "ALPINE QUARRY",
			"desc_fa": "برف، یخ و شیب‌های سنگی سرد.",
			"desc_en": "Snow, ice and cold stone grades.",
			"accent": Color(0.58, 0.72, 0.86), "ambience": "ambience_quarry",
			"sky_top": Color(0.34, 0.46, 0.58), "sky_bottom": Color(0.82, 0.88, 0.93),
		},
	]

func _build_stages() -> void:
	stages = StageCatalog.build_all(surfaces)

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

func stage_by_id(id: String) -> StageDef:
	for s: StageDef in stages:
		if s.id == id:
			return s
	return null

func stages_for(env: String) -> Array[StageDef]:
	var out: Array[StageDef] = []
	for s: StageDef in stages:
		if s.environment == env:
			out.append(s)
	return out

func env_meta(id: String) -> Dictionary:
	for e: Dictionary in environments:
		if String(e["id"]) == id:
			return e
	return {}

func upgrade_by_id(id: String) -> UpgradeDef:
	for u: UpgradeDef in upgrades:
		if u.id == id:
			return u
	return null

func upgrades_for(category: int) -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for u: UpgradeDef in upgrades:
		if u.category == category:
			out.append(u)
	return out

func first_stage_of(env: String) -> StageDef:
	var list: Array[StageDef] = stages_for(env)
	return list[0] if not list.is_empty() else null
