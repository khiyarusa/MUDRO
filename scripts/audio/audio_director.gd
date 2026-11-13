extends Node
## AudioDirector (autoload): bus setup, cached one-shots, looped engine and ambience.
## Every stream is optional — a missing file degrades silently instead of crashing.

const REFERENCE_RPM: float = 2200.0
const BUSES: Array[String] = ["Engine", "SFX", "Ambience"]

var _cache: Dictionary = {}

func _ready() -> void:
	for b: String in BUSES:
		_ensure_bus(b, "Master")
	SettingsService.changed.connect(_on_settings_changed)
	_on_settings_changed()

func _ensure_bus(bus_name: String, send_to: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send_to)

func _on_settings_changed() -> void:
	SettingsService.apply_audio()

func stream(audio_name: String) -> AudioStream:
	if _cache.has(audio_name):
		return _cache[audio_name] as AudioStream
	var path: String = "res://assets/audio/%s.wav" % audio_name
	var res: AudioStream = null
	if ResourceLoader.exists(path):
		res = load(path) as AudioStream
	_cache[audio_name] = res
	return res

func has(audio_name: String) -> bool:
	return stream(audio_name) != null

func play(audio_name: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> AudioStreamPlayer:
	var s: AudioStream = stream(audio_name)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.2, 4.0)
	p.bus = bus
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p

func make_loop(audio_name: String, bus: String = "Engine", volume_db: float = -6.0) -> AudioStreamPlayer:
	var s: AudioStream = stream(audio_name)
	if s == null:
		return null
	var dup: AudioStream = s.duplicate() as AudioStream
	if dup is AudioStreamWAV:
		var wav := dup as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = dup
	p.bus = bus
	p.volume_db = volume_db
	add_child(p)
	return p

func ui_click() -> void:
	play("ui_click", -8.0, randf_range(0.97, 1.04), "SFX")

func ui_confirm() -> void:
	play("ui_confirm", -6.0, 1.0, "SFX")

func ui_back() -> void:
	play("ui_back", -8.0, 1.0, "SFX")

func engine_pitch(rpm: float) -> float:
	return clampf(rpm / REFERENCE_RPM, 0.45, 3.4)

func surface_roll_sound(surface_id: String) -> String:
	if surface_id.begins_with("gravel") or surface_id == "rock":
		return "tire_roll_gravel"
	return "tire_roll_dirt"
