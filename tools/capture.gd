extends Node
## Screenshot harness: instantiates each screen, renders it for real and writes
## PNGs to local-builds/screenshots for visual review.
## Run (windowed, not headless):
##   godot --path . --resolution 1280x720 res://tools/capture.tscn

const OUT_DIR := "res://local-builds/screenshots"
var _current: Node = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await get_tree().process_frame

	await _shot_ui("res://scenes/menus/main_menu.tscn", "01_main_menu", 24)
	GameSession.mode = "career"
	GameSession.env_filter = ""
	await _shot_ui("res://scenes/menus/career.tscn", "02_career", 16)
	GameSession.env_filter = "canyon"
	await _shot_ui("res://scenes/menus/stage_select.tscn", "03_stage_select", 16)
	await _shot_ui("res://scenes/garage/garage.tscn", "04_garage", 16)
	GameSession.vehicle_id = "ranger_4x4"
	await _shot_ui("res://scenes/garage/upgrades.tscn", "05_upgrades", 16)
	await _shot_ui("res://scenes/menus/settings.tscn", "06_settings", 16)
	await _shot_ui("res://scenes/menus/credits.tscn", "07_credits", 16)

	GameSession.start_stage("canyon_01", "career")
	await _shot_race("08_race_intro", 2.4, false)
	await _shot_race("09_race_driving", 4.2, true)
	SettingsService.show_debug = true
	await _shot_race("10_race_debug", 3.0, false)
	SettingsService.show_debug = false

	GameSession.start_stage("pine_02", "career")
	await _shot_race("11_pine_race", 4.0, true)
	GameSession.start_stage("quarry_04", "career")
	await _shot_race("12_quarry_race", 4.0, true)
	print("CAPTURE COMPLETE")
	get_tree().quit(0)

func _clear() -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_current = null

func _shot_ui(path: String, name: String, frames: int) -> void:
	await _clear()
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("MISSING SCENE ", path)
		return
	_current = packed.instantiate()
	add_child(_current)
	await _wait(frames)
	_save(name)

func _shot_race(name: String, seconds: float, throttle: bool) -> void:
	await _clear()
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	_current = packed.instantiate()
	add_child(_current)
	await _wait(6)
	if throttle:
		Input.action_press("throttle")
	var end_ms: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_ms:
		await get_tree().process_frame
	_save(name)
	if throttle:
		Input.action_release("throttle")

func _wait(frames: int) -> void:
	for i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _save(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		print("NO IMAGE ", name)
		return
	var path: String = OUT_DIR.path_join(name + ".png")
	var err: int = img.save_png(path)
	print("SHOT %s -> %s (err %d, %dx%d)" % [name, path, err, img.get_width(), img.get_height()])
