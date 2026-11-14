class_name TrackCatalog
extends RefCounted
## The authored MUDRO 3.0 mountain tracks.
##
## Fifteen tracks across five regions. Every track is a list of slope segments
## (length in metres, entry slope, exit slope) plus surface sections. Because the
## slope is authored per segment and continuous at the joints, there is no random
## terrain, no staircase, no hidden gap and — by design — no obstacle whatsoever
## on the racing line. A track's character comes from its grade, its crests, its
## length and its surface, exactly as a real mountain road would.
##
## Region palette:
##   zagros       dry limestone highlands, warm dirt, long rolling climbs
##   alpine       paved mountain pass, cold air, fog, sustained gradients
##   pine         wet forest valley, mud and low grip between the trees
##   black_ridge  dark igneous mining roads, rough stone, the hardest grades
##   glacier      snow and ice, exposed ridges, almost no grip

const REGIONS: Array = [
	{
		"id": "zagros", "name_fa": "ارتفاعات زاگرس", "name_en": "ZAGROS HIGHLANDS",
		"desc_fa": "کوه‌های خشک و آهکی، جاده‌های خاکی و دشت‌های بلند. گرم، روشن و خوانا؛ بهترین جا برای یاد گرفتن ریتم کوهستان.",
		"desc_en": "Dry limestone mountains, dirt roads and high plains. Warm, open and readable — the right place to learn a mountain rhythm.",
		"accent": Color(0.82, 0.55, 0.30), "surface_hint": "hard_dirt", "ambience": "ambience_canyon",
	},
	{
		"id": "alpine", "name_fa": "گردنهٔ آلپ", "name_en": "ALPINE PASS",
		"desc_fa": "ارتفاع زیاد، هوای سرد، آسفالت کوهستانی و برف در قله. صعودهای طولانی که قدرت و خنک‌کاری را می‌سنجند.",
		"desc_en": "Altitude, cold air, paved mountain road and snow on the summit. Long climbs that test power and cooling.",
		"accent": Color(0.60, 0.72, 0.84), "surface_hint": "asphalt", "ambience": "ambience_quarry",
	},
	{
		"id": "pine", "name_fa": "درهٔ کاج", "name_en": "PINE VALLEY",
		"desc_fa": "جنگل انبوه، زمین خیس و نور میان درختان. چسبندگی مدام عوض می‌شود و خط رانندگی اهمیت پیدا می‌کند.",
		"desc_en": "Dense forest, wet ground and light between the trunks. Grip changes constantly, so the driving line matters.",
		"accent": Color(0.44, 0.64, 0.48), "surface_hint": "wet_mud", "ambience": "ambience_pine",
	},
	{
		"id": "black_ridge", "name_fa": "یال سیاه", "name_en": "BLACK RIDGE",
		"desc_fa": "سنگ آذرین تیره، جاده‌های معدنی و شیب‌های بی‌رحم. سخت‌ترین زمین بازی، بدون هیچ بهانه‌ای.",
		"desc_en": "Dark igneous rock, mining roads and merciless grades. The hardest ground in the game, with no excuses.",
		"accent": Color(0.74, 0.56, 0.28), "surface_hint": "scree", "ambience": "ambience_canyon",
	},
	{
		"id": "glacier", "name_fa": "جادهٔ یخچال", "name_en": "GLACIER ROAD",
		"desc_fa": "برف، یخ و باد. چسبندگی تقریباً وجود ندارد؛ نرمیِ راننده بیشتر از قدرت موتور کار می‌کند.",
		"desc_en": "Snow, ice and wind. Grip barely exists; smooth hands matter more than engine power.",
		"accent": Color(0.72, 0.82, 0.90), "surface_hint": "snow", "ambience": "ambience_quarry",
	},
]

const TRACKS: Array = [
	# ------------------------------------------------------------------ zagros ---
	{
		"id": "zagros_01", "region": "zagros", "diff": 1,
		"name_fa": "گردنهٔ بلوط", "name_en": "Oak Pass",
		"brief_fa": "یک جادهٔ خاکی باز با دو صعود ملایم و یک تاج کوتاه. برای شناخت دنده و گاز مناسب است.",
		"brief_en": "An open dirt road with two gentle climbs and one short crest. The place to learn gears and throttle.",
		"segs": [[90, 0.00, 0.03], [130, 0.03, 0.09], [70, 0.09, 0.10], [60, 0.10, 0.02],
			[110, 0.02, -0.04], [120, -0.04, 0.00], [100, 0.00, 0.11], [80, 0.11, 0.05],
			[90, 0.05, 0.13], [70, 0.13, 0.06]],
		"surfaces": [[0, 180, "hard_dirt"], [180, 330, "gravel"], [330, 520, "hard_dirt"],
			[520, 700, "rock"], [700, 920, "hard_dirt"]],
		"cp": [0.36, 0.68], "weather": "clear", "tod": "morning", "ref": 22.0, "seed": 3101,
	},
	{
		"id": "zagros_02", "region": "zagros", "diff": 2,
		"name_fa": "دشت سنگ‌آهک", "name_en": "Limestone Shelf",
		"brief_fa": "دشت بلند و پرسرعت، بعد یک دیوار آهکی و پیچ‌های خشک. سرعت را قبل از شیب جمع کن.",
		"brief_en": "A fast high plain, then a limestone wall and dry switchbacks. Bank your speed before the grade.",
		"segs": [[150, 0.00, -0.02], [120, -0.02, 0.01], [80, 0.01, 0.17], [70, 0.17, 0.19],
			[60, 0.19, 0.08], [100, 0.08, 0.02], [90, 0.02, -0.07], [130, -0.07, -0.02],
			[110, -0.02, 0.06], [90, 0.06, 0.14], [80, 0.14, 0.04]],
		"surfaces": [[0, 210, "hard_dirt"], [210, 400, "rock"], [400, 560, "gravel"],
			[560, 760, "hard_dirt"], [760, 1080, "gravel"]],
		"cp": [0.32, 0.64], "weather": "clear", "tod": "afternoon", "ref": 24.0, "seed": 3102,
	},
	{
		"id": "zagros_03", "region": "zagros", "diff": 3,
		"name_fa": "شیب زاگرس", "name_en": "Zagros Grade",
		"brief_fa": "صعود پیوسته روی سنگریزه با یک قلهٔ کوتاه و فرود تند. گشتاور پایین‌دور تعیین‌کننده است.",
		"brief_en": "A sustained scree climb, a short summit and a fast descent. Low-rpm torque decides it.",
		"segs": [[70, 0.00, 0.06], [90, 0.06, 0.15], [110, 0.15, 0.21], [90, 0.21, 0.18],
			[80, 0.18, 0.10], [70, 0.10, 0.03], [60, 0.03, -0.05], [110, -0.05, -0.12],
			[130, -0.12, -0.04], [90, -0.04, 0.08], [80, 0.08, 0.16], [80, 0.16, 0.07]],
		"surfaces": [[0, 160, "hard_dirt"], [160, 430, "scree"], [430, 560, "rock"],
			[560, 760, "gravel"], [760, 1020, "hard_dirt"], [1020, 1150, "scree"]],
		"cp": [0.30, 0.62], "weather": "clear", "tod": "afternoon", "ref": 21.0, "seed": 3103,
	},
	# ------------------------------------------------------------------ alpine ---
	{
		"id": "alpine_01", "region": "alpine", "diff": 3,
		"name_fa": "گردنهٔ آلپ", "name_en": "Alpine Pass",
		"brief_fa": "آسفالت سرد و تمیز، پیچ‌های بلند و یک صعود یکنواخت. تایر جاده‌ای اینجا بهترین انتخاب است.",
		"brief_en": "Cold, clean asphalt, long bends and one unbroken climb. Highway tyres are the right call here.",
		"segs": [[120, 0.00, 0.04], [140, 0.04, 0.12], [100, 0.12, 0.16], [90, 0.16, 0.14],
			[110, 0.14, 0.06], [80, 0.06, 0.01], [120, 0.01, -0.08], [140, -0.08, -0.10],
			[110, -0.10, -0.02], [90, -0.02, 0.05], [100, 0.05, 0.13], [60, 0.13, 0.09]],
		"surfaces": [[0, 200, "asphalt"], [200, 420, "asphalt"], [420, 500, "rock"],
			[500, 700, "asphalt"], [700, 900, "hard_dirt"], [900, 1180, "asphalt"]],
		"cp": [0.34, 0.66], "weather": "cloudy", "tod": "morning", "ref": 26.0, "seed": 3201,
	},
	{
		"id": "alpine_02", "region": "alpine", "diff": 4,
		"name_fa": "قلهٔ مه", "name_en": "Fog Summit",
		"brief_fa": "مه غلیظ روی شیب‌های سنگی و برف پایانی. دمای موتور در این صعود بالا می‌رود؛ خنک‌کاری را جدی بگیر.",
		"brief_en": "Thick fog on rock grades and snow at the top. Engine temperature climbs hard here — respect the cooling system.",
		"segs": [[90, 0.00, 0.05], [100, 0.05, 0.13], [120, 0.13, 0.19], [100, 0.19, 0.22],
			[90, 0.22, 0.20], [80, 0.20, 0.12], [70, 0.12, 0.04], [90, 0.04, 0.10],
			[110, 0.10, 0.17], [100, 0.17, 0.11], [80, 0.11, 0.02], [90, 0.02, -0.06],
			[100, -0.06, 0.00]],
		"surfaces": [[0, 180, "asphalt"], [180, 420, "rock"], [420, 620, "snow"],
			[620, 820, "rock"], [820, 1000, "snow"], [1000, 1200, "asphalt"]],
		"cp": [0.28, 0.58, 0.82], "weather": "fog", "tod": "afternoon", "ref": 22.0, "seed": 3202,
	},
	{
		"id": "alpine_03", "region": "alpine", "diff": 4,
		"name_fa": "سرازیری شمالی", "name_en": "North Face Descent",
		"brief_fa": "قله را رد کن و ۴۰۰ متر سرازیری را مدیریت کن. ترمز، دندهٔ پایین و سردی هوا سه ابزار تو هستند.",
		"brief_en": "Clear the summit, then manage 400 metres of descent. Brakes, a low gear and cold air are your three tools.",
		"segs": [[70, 0.00, 0.09], [80, 0.09, 0.16], [90, 0.16, 0.20], [70, 0.20, 0.12],
			[60, 0.12, 0.03], [80, 0.03, -0.06], [110, -0.06, -0.15], [120, -0.15, -0.19],
			[110, -0.19, -0.14], [100, -0.14, -0.08], [120, -0.08, -0.02], [90, -0.02, 0.04],
			[80, 0.04, 0.09]],
		"surfaces": [[0, 160, "asphalt"], [160, 380, "rock"], [380, 520, "snow"],
			[520, 780, "asphalt"], [780, 1000, "rock"], [1000, 1260, "asphalt"]],
		"cp": [0.30, 0.60, 0.84], "weather": "wind", "tod": "afternoon", "ref": 24.0, "seed": 3203,
	},
	# -------------------------------------------------------------------- pine ---
	{
		"id": "pine_01", "region": "pine", "diff": 2,
		"name_fa": "درهٔ کاج", "name_en": "Pine Valley",
		"brief_fa": "جنگل نمناک با گل کم‌عمق و ریشه‌های خیس. مسیر آرام است، ولی چسبندگی مدام عوض می‌شود.",
		"brief_en": "Damp forest, shallow mud and wet roots. A calm track, but the grip keeps changing under you.",
		"segs": [[100, 0.00, 0.02], [110, 0.02, 0.07], [90, 0.07, 0.04], [120, 0.04, 0.10],
			[100, 0.10, 0.05], [80, 0.05, -0.03], [120, -0.03, 0.01], [110, 0.01, 0.08],
			[90, 0.08, 0.12], [80, 0.12, 0.04]],
		"surfaces": [[0, 200, "hard_dirt"], [200, 380, "mud"], [380, 560, "hard_dirt"],
			[560, 780, "wet_mud"], [780, 960, "hard_dirt"]],
		"cp": [0.35, 0.7], "weather": "rain", "tod": "afternoon", "ref": 20.0, "seed": 3301,
	},
	{
		"id": "pine_02", "region": "pine", "diff": 3,
		"name_fa": "خط خزه", "name_en": "Moss Line",
		"brief_fa": "پیچ‌های تنگ جنگلی و شیب‌های کوتاه پشت سر هم. گاز کنترل‌شده بهتر از گاز زیاد است.",
		"brief_en": "Tight forest bends and short climbs in sequence. Measured throttle beats a heavy right foot.",
		"segs": [[80, 0.00, 0.04], [90, 0.04, 0.11], [70, 0.11, 0.03], [100, 0.03, 0.09],
			[80, 0.09, 0.14], [70, 0.14, 0.05], [90, 0.05, -0.04], [110, -0.04, 0.02],
			[100, 0.02, 0.10], [90, 0.10, 0.16], [80, 0.16, 0.06], [70, 0.06, -0.02]],
		"surfaces": [[0, 170, "hard_dirt"], [170, 350, "wet_mud"], [350, 520, "mud"],
			[520, 700, "hard_dirt"], [700, 900, "wet_mud"], [900, 1080, "hard_dirt"]],
		"cp": [0.33, 0.66], "weather": "rain", "tod": "morning", "ref": 19.0, "seed": 3302,
	},
	{
		"id": "pine_03", "region": "pine", "diff": 4,
		"name_fa": "نهر سرد", "name_en": "Cold Creek",
		"brief_fa": "قله، سپس فرود تند به نهر و گل عمیق. ترمز و دندهٔ پایین را قبل از لبه انتخاب کن.",
		"brief_en": "Summit, then a steep drop into a creek and deep mud. Choose brakes and low gear before the lip.",
		"segs": [[80, 0.00, 0.06], [90, 0.06, 0.15], [100, 0.15, 0.19], [80, 0.19, 0.10],
			[70, 0.10, 0.02], [90, 0.02, -0.09], [100, -0.09, -0.16], [110, -0.16, -0.11],
			[120, -0.11, -0.03], [110, -0.03, 0.05], [100, 0.05, 0.11], [90, 0.11, 0.03],
			[80, 0.03, -0.02]],
		"surfaces": [[0, 180, "hard_dirt"], [180, 400, "wet_mud"], [400, 560, "mud"],
			[560, 740, "water"], [740, 940, "wet_mud"], [940, 1120, "hard_dirt"],
			[1120, 1220, "mud"]],
		"cp": [0.30, 0.62, 0.85], "weather": "rain", "tod": "afternoon", "ref": 18.0, "seed": 3303,
	},
	# -------------------------------------------------------------- black ridge ---
	{
		"id": "black_ridge_01", "region": "black_ridge", "diff": 4,
		"name_fa": "دروازهٔ سیاه", "name_en": "Black Gate",
		"brief_fa": "دهانهٔ معدن متروکه: خاکستر نرم، سنگ سیاه و شیب‌های کوتاه تند. دوام تعلیق مهم است.",
		"brief_en": "The mouth of an abandoned mine: soft ash, black stone and short violent grades. Suspension durability matters.",
		"segs": [[90, 0.00, 0.05], [100, 0.05, 0.14], [80, 0.14, 0.09], [90, 0.09, 0.18],
			[70, 0.18, 0.06], [100, 0.06, -0.05], [120, -0.05, 0.02], [100, 0.02, 0.12],
			[90, 0.12, 0.20], [80, 0.20, 0.08], [90, 0.08, 0.03], [80, 0.03, -0.04]],
		"surfaces": [[0, 200, "ash"], [200, 380, "scree"], [380, 560, "rock"],
			[560, 760, "ash"], [760, 940, "rock"], [940, 1080, "scree"]],
		"cp": [0.32, 0.64], "weather": "fog", "tod": "evening", "ref": 19.0, "seed": 3401,
	},
	{
		"id": "black_ridge_02", "region": "black_ridge", "diff": 5,
		"name_fa": "جادهٔ حمل", "name_en": "Haul Road",
		"brief_fa": "صعود بی‌وقفهٔ معدنی روی سنگ‌ریزه. فقط ماشین سنگین با دندهٔ درست بالا می‌رود.",
		"brief_en": "An unbroken mining climb over scree. Only a heavy machine in the right gear gets up.",
		"segs": [[70, 0.00, 0.07], [90, 0.07, 0.16], [110, 0.16, 0.21], [100, 0.21, 0.19],
			[90, 0.19, 0.22], [80, 0.22, 0.15], [90, 0.15, 0.09], [100, 0.09, 0.14],
			[110, 0.14, 0.20], [100, 0.20, 0.12], [80, 0.12, 0.03], [90, 0.03, -0.05],
			[110, -0.05, 0.00]],
		"surfaces": [[0, 190, "ash"], [190, 430, "scree"], [430, 620, "rock"],
			[620, 820, "scree"], [820, 1000, "ash"], [1000, 1150, "rock"]],
		"cp": [0.27, 0.56, 0.81], "weather": "cloudy", "tod": "afternoon", "ref": 17.0, "seed": 3402,
	},
	{
		"id": "black_ridge_03", "region": "black_ridge", "diff": 6,
		"name_fa": "قلهٔ خاکستر", "name_en": "Ash Summit",
		"brief_fa": "آخرین صعود: شیب طولانی، سنگ شکسته و باد. اشتباه در انتخاب دنده یعنی از دست دادن کل مسیر.",
		"brief_en": "The final climb: a long grade, broken stone and wind. One wrong gear choice costs the whole run.",
		"segs": [[70, 0.00, 0.08], [80, 0.08, 0.17], [100, 0.17, 0.23], [90, 0.23, 0.21],
			[80, 0.21, 0.24], [90, 0.24, 0.19], [80, 0.19, 0.12], [100, 0.12, 0.18],
			[110, 0.18, 0.22], [90, 0.22, 0.14], [100, 0.14, 0.06], [90, 0.06, 0.11],
			[80, 0.11, 0.16], [90, 0.16, 0.05], [70, 0.05, -0.03]],
		"surfaces": [[0, 180, "ash"], [180, 400, "scree"], [400, 600, "rock"],
			[600, 800, "ash"], [800, 1000, "scree"], [1000, 1200, "rock"],
			[1200, 1320, "ash"]],
		"cp": [0.25, 0.52, 0.78], "weather": "wind", "tod": "evening", "ref": 16.0, "seed": 3403,
	},
	# ----------------------------------------------------------------- glacier ---
	{
		"id": "glacier_01", "region": "glacier", "diff": 5,
		"name_fa": "جادهٔ یخچال", "name_en": "Glacier Road",
		"brief_fa": "برف فشرده روی شیب طولانی. تایر برفی و گاز نرم؛ هر حرکت تند، کشش را از بین می‌برد.",
		"brief_en": "Packed snow on a long grade. Snow tyres and a soft foot; any sharp input kills what grip you have.",
		"segs": [[90, 0.00, 0.04], [110, 0.04, 0.11], [120, 0.11, 0.16], [100, 0.16, 0.14],
			[90, 0.14, 0.09], [100, 0.09, 0.13], [110, 0.13, 0.18], [100, 0.18, 0.10],
			[90, 0.10, 0.02], [100, 0.02, -0.08], [110, -0.08, -0.04], [90, -0.04, 0.03],
			[80, 0.03, 0.08]],
		"surfaces": [[0, 200, "snow"], [200, 420, "ice"], [420, 560, "snow"],
			[560, 760, "ice"], [760, 960, "snow"], [960, 1100, "ice"]],
		"cp": [0.30, 0.60, 0.84], "weather": "snow", "tod": "morning", "ref": 17.0, "seed": 3501,
	},
	{
		"id": "glacier_02", "region": "glacier", "diff": 6,
		"name_fa": "باد قطبی", "name_en": "Polar Wind",
		"brief_fa": "یال باز و باد جانبی. مسیر باریک است، چسبندگی کم و شیب مدام تغییر می‌کند.",
		"brief_en": "An exposed ridge with crosswind. The line is narrow, the grip is low and the grade never settles.",
		"segs": [[80, 0.00, 0.06], [90, 0.06, 0.15], [100, 0.15, 0.20], [80, 0.20, 0.08],
			[70, 0.08, 0.13], [90, 0.13, 0.19], [100, 0.19, 0.11], [80, 0.11, 0.04],
			[90, 0.04, 0.14], [100, 0.14, 0.21], [90, 0.21, 0.10], [80, 0.10, 0.01],
			[100, 0.01, -0.07], [90, -0.07, 0.02]],
		"surfaces": [[0, 180, "snow"], [180, 360, "ice"], [360, 520, "snow"],
			[520, 700, "ice"], [700, 900, "snow"], [900, 1100, "ice"],
			[1100, 1240, "snow"]],
		"cp": [0.26, 0.55, 0.80], "weather": "wind", "tod": "afternoon", "ref": 16.0, "seed": 3502,
	},
	{
		"id": "glacier_03", "region": "glacier", "diff": 6,
		"name_fa": "یخچال بزرگ", "name_en": "Great Glacier",
		"brief_fa": "طولانی‌ترین صعود بازی روی یخ. قدرت، خنک‌کاری و صبر را هم‌زمان می‌خواهد.",
		"brief_en": "The longest climb in the game, on ice. It asks for power, cooling and patience at once.",
		"segs": [[90, 0.00, 0.05], [100, 0.05, 0.13], [120, 0.13, 0.18], [110, 0.18, 0.16],
			[100, 0.16, 0.20], [110, 0.20, 0.17], [100, 0.17, 0.11], [110, 0.11, 0.15],
			[120, 0.15, 0.19], [100, 0.19, 0.12], [90, 0.12, 0.05], [100, 0.05, 0.10],
			[110, 0.10, 0.14], [100, 0.14, 0.06], [90, 0.06, -0.02], [80, -0.02, 0.03]],
		"surfaces": [[0, 220, "snow"], [220, 460, "ice"], [460, 640, "snow"],
			[640, 880, "ice"], [880, 1080, "snow"], [1080, 1260, "ice"],
			[1260, 1440, "snow"]],
		"cp": [0.24, 0.50, 0.76], "weather": "snow", "tod": "morning", "ref": 15.0, "seed": 3503,
	},
]

static func build_all() -> Array[TrackDef]:
	var out: Array[TrackDef] = []
	for entry: Dictionary in TRACKS:
		out.append(_from_entry(entry))
	return out

static func region_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r: Dictionary in REGIONS:
		out.append(String(r["id"]))
	return out

static func region_meta(id: String) -> Dictionary:
	for r: Dictionary in REGIONS:
		if String(r["id"]) == id:
			return r
	return {}

## Ordered index of a track inside its region (1-based) — used for unlock chains.
static func ordinal_in_region(track_id: String) -> int:
	var wanted: String = ""
	for entry: Dictionary in TRACKS:
		if String(entry["id"]) == track_id:
			wanted = String(entry["region"])
			break
	if wanted.is_empty():
		return 0
	var n: int = 0
	for entry: Dictionary in TRACKS:
		if String(entry["region"]) == wanted:
			n += 1
			if String(entry["id"]) == track_id:
				return n
	return 0

static func _from_entry(entry: Dictionary) -> TrackDef:
	var t := TrackDef.new()
	t.id = String(entry["id"])
	t.region = String(entry["region"])
	t.name_fa = String(entry["name_fa"])
	t.name_en = String(entry["name_en"])
	t.brief_fa = String(entry["brief_fa"])
	t.brief_en = String(entry["brief_en"])
	t.difficulty = int(entry.get("diff", 1))
	t.weather = String(entry.get("weather", "clear"))
	t.time_of_day = String(entry.get("tod", "afternoon"))
	t.reference_speed_mps = float(entry.get("ref", 20.0))
	t.decor_seed = int(entry.get("seed", 1337))
	t.decor_density = float(entry.get("density", 1.0))

	var segs: Array[Dictionary] = []
	for raw: Variant in (entry["segs"] as Array):
		var triple: Array = raw as Array
		segs.append({
			"len": float(triple[0]),
			"s_in": float(triple[1]),
			"s_out": float(triple[2]),
		})
	t.profile_segments = segs

	var sections: Array[Dictionary] = []
	for raw: Variant in (entry["surfaces"] as Array):
		var row: Array = raw as Array
		sections.append({
			"from": float(row[0]),
			"to": float(row[1]),
			"surface": String(row[2]),
		})
	t.surface_sections = sections
	# Authored ranges are absolute metres; close any gap or overrun against the
	# real profile length before anything reads the sections.
	t.normalize_surfaces()

	# Checkpoints are authored as fractions of the profile, then resolved once the
	# real length is known. That keeps them strictly ordered and inside the road
	# even when a segment length is tuned later.
	var length: float = t.length_m()
	var cps := PackedFloat32Array()
	for raw: Variant in (entry["cp"] as Array):
		cps.append(roundf(length * float(raw)))
	t.checkpoints = cps

	var pace: float = t.model_time_s()
	t.medal_gold = roundf(pace * 1.08 * 10.0) / 10.0
	t.medal_silver = roundf(pace * 1.22 * 10.0) / 10.0
	t.medal_bronze = roundf(pace * 1.42 * 10.0) / 10.0
	t.reward_credits = 260 + t.difficulty * 130
	t.reward_xp = 45 + t.difficulty * 22
	t.modes = _modes_for(t)
	return t

## A track's legal race modes follow its shape: a sustained climb is a hill climb,
## a long descent is a downhill stage. Every track can still be free-driven or used
## as a test bed.
static func _modes_for(t: TrackDef) -> PackedStringArray:
	var out := PackedStringArray(["rally", "timeattack", "freedrive", "test"])
	var p: TrackProfile = t.profile()
	var net: float = p.net_elevation_m()
	var worst: float = p.max_grade_deg()
	if net > 45.0 and worst > 11.0:
		out.append("hillclimb")
		out.append("sprint")
	if net < -35.0:
		out.append("downhill")
	if t.length_m() > 1100.0:
		out.append("endurance")
	return out
