class_name StageCatalog
extends RefCounted
## Authored stage layouts. Every stage has its own elevation keyframes, surface
## distribution, obstacle placement, checkpoints and medal times. Elevation is in
## metres, x along the stage, y up.

static func build_all(_surfaces: Dictionary) -> Array[StageDef]:
	var out: Array[StageDef] = []
	out.append(canyon_01())
	out.append(canyon_02())
	out.append(canyon_03())
	out.append(canyon_04())
	out.append(pine_01())
	out.append(pine_02())
	out.append(pine_03())
	out.append(pine_04())
	out.append(quarry_01())
	out.append(quarry_02())
	out.append(quarry_03())
	out.append(quarry_04())
	return out

static func _rock(x: float, s: float = 1.0, solid: bool = true) -> Dictionary:
	return {"kind": "rock_a" if int(x) % 2 == 0 else "rock_b", "x": x, "scale": s, "rot": -0.2, "solid": solid}

static func _boulder(x: float, s: float = 1.0) -> Dictionary:
	return {"kind": "rock_b", "x": x, "scale": s, "rot": 0.15, "solid": true}

static func _log(x: float, s: float = 1.0) -> Dictionary:
	return {"kind": "log", "x": x, "scale": s, "rot": 0.0, "solid": true, "y_offset": -0.15}

static func _stack(x: float) -> Dictionary:
	return {"kind": "tire_stack", "x": x, "scale": 0.9, "rot": 0.0, "solid": true}

static func _block(x: float, s: float = 1.0) -> Dictionary:
	return {"kind": "quarry_block", "x": x, "scale": s, "rot": 0.0, "solid": true}

static func _mk(id: String, env: String, fa: String, en: String, brief_fa: String, brief_en: String,
		diff: int, length_m: float, pts: Array, spans: Array, obstacles: Array,
		checkpoints: Array, gold: float, silver: float, bronze: float, seed_v: int) -> StageDef:
	var s := StageDef.new()
	s.id = id
	s.environment = env
	s.name_fa = fa
	s.name_en = en
	s.brief_fa = brief_fa
	s.brief_en = brief_en
	s.difficulty = diff
	s.length_m = length_m
	s.points = PackedVector2Array(pts)
	s.surface_spans.assign(spans)
	s.obstacles.assign(obstacles)
	s.checkpoints = PackedFloat32Array(checkpoints)
	s.medal_gold = gold
	s.medal_silver = silver
	s.medal_bronze = bronze
	s.seed_value = seed_v
	s.reward_credits = 260 + diff * 140
	s.reward_xp = 50 + diff * 25
	return s

static func canyon_01() -> StageDef:
	return _mk("canyon_01", "canyon", "گردنهٔ سرخ", "Red Pass",
		"یک مسیر خاکی باز برای یاد گرفتن دنده و گاز. چند سنگ و یک شیب متوسط.",
		"An open dirt trail for learning gears and throttle. A few rocks and one moderate climb.",
		1, 420.0,
		[Vector2(0, 0), Vector2(30, 0), Vector2(60, 3), Vector2(95, 9), Vector2(130, 12),
		Vector2(165, 9), Vector2(200, 14), Vector2(235, 22), Vector2(270, 26),
		Vector2(305, 22), Vector2(340, 28), Vector2(380, 34), Vector2(420, 36)],
		[{"from": 0.0, "to": 130.0, "surface": "hard_dirt"},
		{"from": 130.0, "to": 215.0, "surface": "gravel"},
		{"from": 215.0, "to": 320.0, "surface": "hard_dirt"},
		{"from": 320.0, "to": 420.0, "surface": "rock"}],
		[_rock(78.0, 0.8), _rock(150.0, 0.95), _log(168.0), _boulder(232.0, 1.05),
		_rock(296.0, 0.9), _stack(352.0), _rock(392.0, 0.85)],
		[135.0, 280.0], 58.0, 72.0, 92.0, 1101)

static func canyon_02() -> StageDef:
	return _mk("canyon_02", "canyon", "درهٔ خشک", "Dry Gulch",
		"شن روان در کف دره و موج‌های خاکی که ماشین را سبک می‌کنند.",
		"Loose sand on the valley floor and dirt whoops that unload the suspension.",
		2, 480.0,
		[Vector2(0, 0), Vector2(40, 0), Vector2(80, -3), Vector2(120, 4), Vector2(150, 16),
		Vector2(185, 18), Vector2(220, 12), Vector2(250, 8), Vector2(290, 20),
		Vector2(325, 24), Vector2(360, 18), Vector2(400, 30), Vector2(440, 36), Vector2(480, 40)],
		[{"from": 0.0, "to": 60.0, "surface": "hard_dirt"},
		{"from": 60.0, "to": 145.0, "surface": "loose_sand"},
		{"from": 145.0, "to": 240.0, "surface": "gravel"},
		{"from": 240.0, "to": 325.0, "surface": "loose_sand"},
		{"from": 325.0, "to": 480.0, "surface": "hard_dirt"}],
		[_rock(92.0, 0.8), _boulder(176.0, 1.1), _rock(258.0, 0.9), _stack(300.0),
		_log(332.0), _rock(388.0, 1.0), _boulder(432.0, 1.15)],
		[160.0, 320.0], 70.0, 86.0, 110.0, 1102)

static func canyon_03() -> StageDef:
	return _mk("canyon_03", "canyon", "پله‌های سنگی", "Boulder Staircase",
		"پله‌های صخره‌ای پشت سر هم؛ دنده یک و گاز کنترل‌شده.",
		"Rock step after rock step. First gear, measured throttle, no wheelspin.",
		3, 520.0,
		[Vector2(0, 0), Vector2(35, 0), Vector2(60, 4), Vector2(80, 10), Vector2(100, 10.5),
		Vector2(120, 18), Vector2(140, 18.5), Vector2(160, 26), Vector2(185, 27),
		Vector2(210, 36), Vector2(235, 37), Vector2(260, 44), Vector2(290, 45),
		Vector2(320, 52), Vector2(350, 53), Vector2(380, 60), Vector2(410, 61),
		Vector2(440, 66), Vector2(480, 70), Vector2(520, 72)],
		[{"from": 0.0, "to": 55.0, "surface": "hard_dirt"},
		{"from": 55.0, "to": 190.0, "surface": "rock"},
		{"from": 190.0, "to": 300.0, "surface": "gravel"},
		{"from": 300.0, "to": 420.0, "surface": "rock"},
		{"from": 420.0, "to": 520.0, "surface": "hard_dirt"}],
		[_rock(70.0, 0.9), _boulder(96.0, 1.2), _rock(150.0, 1.0), _block(205.0, 1.1),
		_rock(268.0, 0.85), _boulder(312.0, 1.15), _log(356.0), _rock(402.0, 1.0),
		_boulder(452.0, 1.25), _rock(498.0, 0.9)],
		[180.0, 360.0], 80.0, 98.0, 126.0, 1103)

static func canyon_04() -> StageDef:
	return _mk("canyon_04", "canyon", "لبهٔ دره", "Canyon Rim",
		"صعود طولانی به لبه، سپس تاج‌های تند و فرود پرسرعت.",
		"A long climb to the rim, then sharp crests and a fast descent.",
		4, 640.0,
		[Vector2(0, 0), Vector2(50, 2), Vector2(90, 10), Vector2(130, 22), Vector2(170, 34),
		Vector2(210, 44), Vector2(250, 52), Vector2(290, 58), Vector2(330, 60),
		Vector2(370, 56), Vector2(400, 50), Vector2(430, 52), Vector2(470, 62),
		Vector2(510, 70), Vector2(550, 74), Vector2(590, 78), Vector2(640, 82)],
		[{"from": 0.0, "to": 70.0, "surface": "hard_dirt"},
		{"from": 70.0, "to": 200.0, "surface": "gravel"},
		{"from": 200.0, "to": 330.0, "surface": "loose_sand"},
		{"from": 330.0, "to": 420.0, "surface": "rock"},
		{"from": 420.0, "to": 520.0, "surface": "hard_dirt"},
		{"from": 520.0, "to": 640.0, "surface": "gravel"}],
		[_rock(84.0, 0.9), _boulder(150.0, 1.15), _log(188.0), _rock(246.0, 1.0),
		_stack(300.0), _boulder(352.0, 1.2), _rock(412.0, 0.95), _log(448.0),
		_rock(492.0, 1.05), _boulder(556.0, 1.3), _rock(610.0, 0.9)],
		[220.0, 420.0], 104.0, 128.0, 160.0, 1104)

static func pine_01() -> StageDef:
	return _mk("pine_01", "pine", "مسیر خزه", "Moss Trail",
		"جنگل نمناک با گِل‌های کم‌عمق. شروع آرام برای شاسی‌بلند.",
		"Damp forest with shallow mud. A gentle introduction to the highlands.",
		1, 430.0,
		[Vector2(0, 0), Vector2(40, 1), Vector2(80, 5), Vector2(110, 4), Vector2(140, 9),
		Vector2(175, 12), Vector2(205, 10), Vector2(240, 16), Vector2(275, 20),
		Vector2(310, 18), Vector2(345, 24), Vector2(380, 27), Vector2(430, 30)],
		[{"from": 0.0, "to": 90.0, "surface": "hard_dirt"},
		{"from": 90.0, "to": 160.0, "surface": "mud"},
		{"from": 160.0, "to": 240.0, "surface": "hard_dirt"},
		{"from": 240.0, "to": 300.0, "surface": "wet_mud"},
		{"from": 300.0, "to": 430.0, "surface": "hard_dirt"}],
		[_rock(96.0, 0.7), _log(128.0), _stump_marker(190.0), _rock(232.0, 0.8),
		_log(262.0), _rock(330.0, 0.9), _boulder(392.0, 0.9)],
		[150.0, 300.0], 62.0, 76.0, 96.0, 1201)

static func _stump_marker(x: float) -> Dictionary:
	return {"kind": "stump", "x": x, "scale": 0.75, "rot": 0.0, "solid": true}

static func pine_02() -> StageDef:
	return _mk("pine_02", "pine", "مسیر تنه‌ها", "Log Run",
		"تنه‌های افتاده یکی پس از دیگری. عبور با سرعت اشتباه، تعلیق را می‌شکند.",
		"Fallen logs in sequence. Hit them fast and you will break the suspension.",
		2, 470.0,
		[Vector2(0, 0), Vector2(35, 0), Vector2(70, 6), Vector2(100, 12), Vector2(130, 10),
		Vector2(165, 16), Vector2(200, 22), Vector2(235, 20), Vector2(270, 26),
		Vector2(305, 18), Vector2(340, 22), Vector2(375, 28), Vector2(410, 26),
		Vector2(445, 32), Vector2(470, 34)],
		[{"from": 0.0, "to": 60.0, "surface": "hard_dirt"},
		{"from": 60.0, "to": 135.0, "surface": "wet_mud"},
		{"from": 135.0, "to": 215.0, "surface": "hard_dirt"},
		{"from": 215.0, "to": 285.0, "surface": "mud"},
		{"from": 285.0, "to": 370.0, "surface": "hard_dirt"},
		{"from": 370.0, "to": 470.0, "surface": "wet_mud"}],
		[_log(78.0, 1.1), _log(118.0), _rock(146.0, 0.9), _log(170.0, 1.2),
		_stump_marker(206.0), _log(238.0), _log(268.0, 1.15), _rock(300.0, 0.85),
		_log(338.0, 1.1), _log(392.0), _boulder(430.0, 1.0)],
		[160.0, 320.0], 72.0, 88.0, 112.0, 1202)

static func pine_03() -> StageDef:
	return _mk("pine_03", "pine", "شیب مه", "Fogline Climb",
		"صعود پیوسته و طولانی روی خاک خیس. دنده اشتباه یعنی توقف کامل.",
		"A long sustained climb on wet soil. The wrong gear means a dead stop.",
		4, 540.0,
		[Vector2(0, 0), Vector2(40, 3), Vector2(80, 12), Vector2(120, 26), Vector2(160, 40),
		Vector2(200, 54), Vector2(240, 66), Vector2(280, 76), Vector2(320, 86),
		Vector2(360, 94), Vector2(400, 100), Vector2(440, 104), Vector2(480, 110),
		Vector2(520, 116), Vector2(560, 120)],
		[{"from": 0.0, "to": 60.0, "surface": "hard_dirt"},
		{"from": 60.0, "to": 200.0, "surface": "wet_mud"},
		{"from": 200.0, "to": 320.0, "surface": "rock"},
		{"from": 320.0, "to": 440.0, "surface": "wet_mud"},
		{"from": 440.0, "to": 540.0, "surface": "hard_dirt"}],
		[_log(74.0), _rock(112.0, 0.9), _stump_marker(156.0), _rock(214.0, 1.0),
		_boulder(262.0, 1.1), _log(310.0), _rock(356.0, 0.95), _boulder(408.0, 1.2),
		_log(458.0), _rock(506.0, 1.0)],
		[180.0, 360.0], 96.0, 118.0, 148.0, 1203)

static func pine_04() -> StageDef:
	return _mk("pine_04", "pine", "ریزش چوب", "Timber Drop",
		"قله، سپس فرود تند و رودخانه. ترمز و دنده پایین را جدی بگیر.",
		"Summit, then a steep descent into a creek. Brakes and low gears matter.",
		5, 620.0,
		[Vector2(0, 0), Vector2(50, 2), Vector2(90, 10), Vector2(130, 22), Vector2(170, 30),
		Vector2(210, 34), Vector2(250, 32), Vector2(290, 38), Vector2(330, 46),
		Vector2(370, 44), Vector2(410, 36), Vector2(450, 24), Vector2(490, 12),
		Vector2(520, 4), Vector2(550, 2), Vector2(580, 6), Vector2(620, 10)],
		[{"from": 0.0, "to": 70.0, "surface": "hard_dirt"},
		{"from": 70.0, "to": 170.0, "surface": "wet_mud"},
		{"from": 170.0, "to": 260.0, "surface": "rock"},
		{"from": 260.0, "to": 360.0, "surface": "wet_mud"},
		{"from": 360.0, "to": 430.0, "surface": "gravel"},
		{"from": 430.0, "to": 510.0, "surface": "rock"},
		{"from": 510.0, "to": 560.0, "surface": "water"},
		{"from": 560.0, "to": 620.0, "surface": "mud"}],
		[_log(84.0), _rock(120.0, 1.0), _stump_marker(158.0), _log(196.0, 1.15),
		_boulder(236.0, 1.1), _log(284.0), _rock(344.0, 1.0), _boulder(388.0, 1.2),
		_rock(444.0, 1.1), _log(476.0), _rock(532.0, 1.0), _boulder(586.0, 1.1)],
		[200.0, 400.0], 108.0, 132.0, 168.0, 1204)

static func quarry_01() -> StageDef:
	return _mk("quarry_01", "quarry", "سکوی ریگ", "Gravel Shelf",
		"جاده‌های ریگی معدن با پیچ‌های ملایم و بلوک‌های سنگی.",
		"Quarry gravel roads, gentle switchbacks and cut stone blocks.",
		2, 460.0,
		[Vector2(0, 0), Vector2(40, 0), Vector2(80, 6), Vector2(120, 14), Vector2(160, 16),
		Vector2(200, 24), Vector2(240, 26), Vector2(280, 34), Vector2(320, 36),
		Vector2(360, 44), Vector2(400, 46), Vector2(460, 50)],
		[{"from": 0.0, "to": 90.0, "surface": "gravel"},
		{"from": 90.0, "to": 170.0, "surface": "rock"},
		{"from": 170.0, "to": 280.0, "surface": "gravel"},
		{"from": 280.0, "to": 380.0, "surface": "snow"},
		{"from": 380.0, "to": 460.0, "surface": "gravel"}],
		[_block(96.0), _rock(134.0, 0.9), _block(188.0, 1.1), _boulder(246.0, 1.0),
		_block(306.0), _rock(350.0, 1.0), _block(404.0, 1.15), _rock(442.0, 0.9)],
		[170.0, 330.0], 68.0, 84.0, 106.0, 1301)

static func quarry_02() -> StageDef:
	return _mk("quarry_02", "quarry", "برش یخ", "Ice Cut",
		"لکه‌های یخ روی شیب. چسبندگی تقریباً صفر است؛ نرم و پیوسته گاز بده.",
		"Ice patches on the grade. Grip nearly vanishes: be smooth, be gentle.",
		4, 500.0,
		[Vector2(0, 0), Vector2(45, 2), Vector2(85, 8), Vector2(125, 16), Vector2(165, 22),
		Vector2(205, 28), Vector2(245, 30), Vector2(285, 38), Vector2(325, 42),
		Vector2(365, 40), Vector2(405, 34), Vector2(445, 30), Vector2(500, 32)],
		[{"from": 0.0, "to": 95.0, "surface": "gravel"},
		{"from": 95.0, "to": 150.0, "surface": "ice"},
		{"from": 150.0, "to": 240.0, "surface": "snow"},
		{"from": 240.0, "to": 300.0, "surface": "ice"},
		{"from": 300.0, "to": 390.0, "surface": "gravel"},
		{"from": 390.0, "to": 500.0, "surface": "snow"}],
		[_rock(74.0, 0.9), _block(118.0), _snow_rock(172.0), _rock(214.0, 1.0),
		_block(268.0, 1.1), _boulder(330.0, 1.0), _snow_rock(376.0), _rock(424.0, 0.9),
		_block(470.0)],
		[180.0, 340.0], 88.0, 108.0, 136.0, 1302)

static func _snow_rock(x: float) -> Dictionary:
	return {"kind": "snow_rock", "x": x, "scale": 1.0, "rot": -0.1, "solid": true}

static func quarry_03() -> StageDef:
	return _mk("quarry_03", "quarry", "تراس‌های سنگی", "Stone Terraces",
		"تراس‌های بریده‌شده در سنگ. هر پله یک آزمون گشتاور و چسبندگی.",
		"Cut stone terraces. Each step is a test of torque and grip.",
		4, 560.0,
		[Vector2(0, 0), Vector2(40, 0), Vector2(70, 6), Vector2(90, 12), Vector2(110, 12.5),
		Vector2(140, 22), Vector2(160, 22.5), Vector2(190, 32), Vector2(215, 32.5),
		Vector2(245, 42), Vector2(275, 42.5), Vector2(305, 52), Vector2(335, 52.5),
		Vector2(365, 60), Vector2(395, 60.5), Vector2(425, 68), Vector2(465, 70),
		Vector2(505, 74), Vector2(560, 78)],
		[{"from": 0.0, "to": 60.0, "surface": "gravel"},
		{"from": 60.0, "to": 160.0, "surface": "rock"},
		{"from": 160.0, "to": 260.0, "surface": "snow"},
		{"from": 260.0, "to": 360.0, "surface": "rock"},
		{"from": 360.0, "to": 460.0, "surface": "snow"},
		{"from": 460.0, "to": 560.0, "surface": "gravel"}],
		[_block(84.0), _rock(126.0, 0.9), _block(178.0, 1.1), _snow_rock(228.0),
		_block(288.0), _rock(330.0, 1.0), _block(384.0, 1.15), _snow_rock(438.0),
		_block(492.0), _rock(534.0, 0.9)],
		[200.0, 390.0], 98.0, 120.0, 152.0, 1303)

static func quarry_04() -> StageDef:
	return _mk("quarry_04", "quarry", "بار قله", "Summit Haul",
		"صعود بی‌وقفهٔ ۱۴۰ متری روی برف و یخ. فقط برای سنگین‌وزن‌ها و رانندهٔ صبور.",
		"An unbroken 140 m climb over snow and ice. Heavy metal and patience only.",
		5, 720.0,
		[Vector2(0, 0), Vector2(50, 2), Vector2(90, 10), Vector2(130, 24), Vector2(170, 38),
		Vector2(210, 52), Vector2(250, 62), Vector2(290, 70), Vector2(330, 80),
		Vector2(370, 88), Vector2(410, 96), Vector2(450, 102), Vector2(490, 108),
		Vector2(530, 116), Vector2(570, 122), Vector2(610, 128), Vector2(650, 132),
		Vector2(690, 138), Vector2(720, 142)],
		[{"from": 0.0, "to": 80.0, "surface": "gravel"},
		{"from": 80.0, "to": 200.0, "surface": "snow"},
		{"from": 200.0, "to": 320.0, "surface": "rock"},
		{"from": 320.0, "to": 430.0, "surface": "ice"},
		{"from": 430.0, "to": 540.0, "surface": "snow"},
		{"from": 540.0, "to": 640.0, "surface": "ice"},
		{"from": 640.0, "to": 720.0, "surface": "snow"}],
		[_rock(96.0, 1.0), _block(140.0), _snow_rock(186.0), _rock(232.0, 1.1),
		_block(276.0, 1.1), _boulder(318.0, 1.15), _snow_rock(364.0), _block(412.0),
		_rock(456.0, 1.0), _snow_rock(502.0), _block(548.0, 1.2), _rock(596.0, 1.0),
		_snow_rock(648.0), _block(690.0)],
		[240.0, 480.0], 140.0, 172.0, 215.0, 1304)
