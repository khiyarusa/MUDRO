extends Node
## SettingsService (autoload): persistent player settings, applied to audio,
## locale and rendering quality.

signal changed
signal language_changed(code: String)

const PATH: String = "user://settings.json"
const VERSION: int = 3

var master: float = 1.0
var engine: float = 0.95
var sfx: float = 0.9
var music: float = 0.55
var language: String = "fa"
var quality: int = 2
var haptics: bool = true
var shake: float = 1.0
var control_opacity: float = 0.82
var control_scale: float = 1.0
var control_preset: String = "buttons"
var control_left_handed: bool = false
var control_margin: float = 0.0
var slider_sensitivity: float = 1.0
var slider_release: float = 4.5
var touch_hit_margin: float = 0.18
var show_clutch: bool = true
var show_handbrake: bool = true
var show_winch: bool = true
var show_recover: bool = true
## Per-widget centre override from the layout editor, id -> [x, y] in 0..1.
var control_positions: Dictionary = {}
var transmission: String = "manual"
var clutch: String = "assist"
var show_debug: bool = false

func _ready() -> void:
	load_settings()
	Loc.set_lang(language)
	apply_all()

func _defaults() -> Dictionary:
	return {
		"version": VERSION,
		"master": 1.0, "engine": 0.95, "sfx": 0.9, "music": 0.55,
		"language": "fa", "quality": 2, "haptics": true, "shake": 1.0,
		"control_opacity": 0.82, "control_scale": 1.0,
		"control_preset": "buttons", "control_left_handed": false,
		"control_margin": 0.0, "slider_sensitivity": 1.0, "slider_release": 4.5,
		"touch_hit_margin": 0.18,
		"show_clutch": true, "show_handbrake": true, "show_winch": true, "show_recover": true,
		"control_positions": {},
		"transmission": "manual", "clutch": "assist", "show_debug": false,
	}

func load_settings() -> void:
	var d: Dictionary = _defaults()
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for k: String in (parsed as Dictionary).keys():
				d[k] = (parsed as Dictionary)[k]
	master = clampf(float(d.get("master", 1.0)), 0.0, 1.0)
	engine = clampf(float(d.get("engine", 0.95)), 0.0, 1.0)
	sfx = clampf(float(d.get("sfx", 0.9)), 0.0, 1.0)
	music = clampf(float(d.get("music", 0.55)), 0.0, 1.0)
	language = String(d.get("language", "fa"))
	if not Loc.SUPPORTED.has(language):
		language = "fa"
	quality = clampi(int(d.get("quality", 2)), 0, 2)
	haptics = bool(d.get("haptics", true))
	shake = clampf(float(d.get("shake", 1.0)), 0.0, 1.5)
	control_opacity = clampf(float(d.get("control_opacity", 0.82)), 0.25, 1.0)
	control_scale = clampf(float(d.get("control_scale", 1.0)), 0.8, 1.35)
	control_preset = String(d.get("control_preset", "buttons"))
	if not ["buttons", "slider", "pedals"].has(control_preset):
		control_preset = "buttons"
	control_left_handed = bool(d.get("control_left_handed", false))
	control_margin = clampf(float(d.get("control_margin", 0.0)), 0.0, 48.0)
	slider_sensitivity = clampf(float(d.get("slider_sensitivity", 1.0)), 0.55, 1.8)
	slider_release = clampf(float(d.get("slider_release", 4.5)), 1.0, 12.0)
	touch_hit_margin = clampf(float(d.get("touch_hit_margin", 0.18)), 0.0, 0.45)
	show_clutch = bool(d.get("show_clutch", true))
	show_handbrake = bool(d.get("show_handbrake", true))
	show_winch = bool(d.get("show_winch", true))
	show_recover = bool(d.get("show_recover", true))
	var positions: Variant = d.get("control_positions", {})
	control_positions = positions if positions is Dictionary else {}
	transmission = String(d.get("transmission", "manual"))
	clutch = String(d.get("clutch", "assist"))
	show_debug = bool(d.get("show_debug", false))

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"master": master, "engine": engine, "sfx": sfx, "music": music,
		"language": language, "quality": quality, "haptics": haptics, "shake": shake,
		"control_opacity": control_opacity, "control_scale": control_scale,
		"control_preset": control_preset, "control_left_handed": control_left_handed,
		"control_margin": control_margin, "slider_sensitivity": slider_sensitivity,
		"slider_release": slider_release, "touch_hit_margin": touch_hit_margin,
		"show_clutch": show_clutch, "show_handbrake": show_handbrake,
		"show_winch": show_winch, "show_recover": show_recover,
		"control_positions": control_positions,
		"transmission": transmission, "clutch": clutch, "show_debug": show_debug,
	}

func save_settings() -> void:
	var text: String = JSON.stringify(to_dict(), "\t")
	var tmp: String = PATH + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".bak"))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".bak"))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))

func apply_all() -> void:
	apply_audio()
	call_deferred("apply_render_quality")
	changed.emit()

func apply_audio() -> void:
	_set_bus("Master", master)
	_set_bus("Engine", engine)
	_set_bus("SFX", sfx)
	_set_bus("Ambience", music)
	_set_bus("Music", music)

func _set_bus(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))

func apply_render_quality() -> void:
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	match quality:
		0:
			vp.msaa_2d = Viewport.MSAA_DISABLED
		1:
			vp.msaa_2d = Viewport.MSAA_DISABLED
		_:
			vp.msaa_2d = Viewport.MSAA_DISABLED

func set_language(code: String) -> void:
	if language == code:
		return
	language = code
	Loc.set_lang(code)
	save_settings()
	language_changed.emit(code)
	changed.emit()

func set_value(key: String, value: Variant) -> void:
	match key:
		"master": master = clampf(float(value), 0.0, 1.0)
		"engine": engine = clampf(float(value), 0.0, 1.0)
		"sfx": sfx = clampf(float(value), 0.0, 1.0)
		"music": music = clampf(float(value), 0.0, 1.0)
		"quality": quality = clampi(int(value), 0, 2)
		"haptics": haptics = bool(value)
		"shake": shake = clampf(float(value), 0.0, 1.5)
		"control_opacity": control_opacity = clampf(float(value), 0.25, 1.0)
		"control_scale": control_scale = clampf(float(value), 0.8, 1.35)
		"control_preset":
			control_preset = String(value)
			control_positions = {}
		"control_left_handed": control_left_handed = bool(value)
		"control_margin": control_margin = clampf(float(value), 0.0, 48.0)
		"slider_sensitivity": slider_sensitivity = clampf(float(value), 0.55, 1.8)
		"slider_release": slider_release = clampf(float(value), 1.0, 12.0)
		"touch_hit_margin": touch_hit_margin = clampf(float(value), 0.0, 0.45)
		"show_clutch": show_clutch = bool(value)
		"show_handbrake": show_handbrake = bool(value)
		"show_winch": show_winch = bool(value)
		"show_recover": show_recover = bool(value)
		"control_positions":
			control_positions = value if value is Dictionary else {}
		"transmission": transmission = String(value)
		"clutch": clutch = String(value)
		"show_debug": show_debug = bool(value)
	save_settings()
	apply_all()

func reset_defaults() -> void:
	var d: Dictionary = _defaults()
	master = float(d["master"])
	engine = float(d["engine"])
	sfx = float(d["sfx"])
	music = float(d["music"])
	quality = int(d["quality"])
	haptics = bool(d["haptics"])
	shake = float(d["shake"])
	control_opacity = float(d["control_opacity"])
	control_scale = float(d["control_scale"])
	control_preset = String(d.get("control_preset", "buttons"))
	control_left_handed = bool(d.get("control_left_handed", false))
	control_margin = float(d.get("control_margin", 0.0))
	slider_sensitivity = float(d.get("slider_sensitivity", 1.0))
	slider_release = float(d.get("slider_release", 4.5))
	touch_hit_margin = float(d.get("touch_hit_margin", 0.18))
	show_clutch = bool(d.get("show_clutch", true))
	show_handbrake = bool(d.get("show_handbrake", true))
	show_winch = bool(d.get("show_winch", true))
	show_recover = bool(d.get("show_recover", true))
	control_positions = {}
	transmission = String(d["transmission"])
	clutch = String(d["clutch"])
	show_debug = bool(d["show_debug"])
	set_language(String(d["language"]))
	save_settings()
	apply_all()

func vibrate(ms: int = 22) -> void:
	if not haptics:
		return
	Input.vibrate_handheld(ms)

## Clears every layout override and returns the preset to its authored layout.
func reset_control_layout() -> void:
	control_positions = {}
	save_settings()
	changed.emit()

func set_control_position(id: String, normalized: Vector2) -> void:
	control_positions[id] = [clampf(normalized.x, 0.0, 1.0), clampf(normalized.y, 0.0, 1.0)]
	changed.emit()
