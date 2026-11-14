extends Node
## MUDRO 3.0 screenshot harness.
##
## Runs the real game, instantiates the real scenes and saves what the renderer
## produced. No mock-ups. Run windowed (not headless):
##   godot --path . --resolution 1280x720 res://tools/capture_v3.tscn
##
## The user's own profile is snapshotted before the run and restored afterwards,
## so producing documentation never rewrites a player's save.

const OUT_DIR := "res://docs/screenshots/v3.0"
const PROFILE := "user://profile.json"
const PROFILE_BAK := "user://profile.json.capture-backup"

var _current: Node = null
var _saved: int = 0
var _had_profile: bool = false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_snapshot_profile()
	await get_tree().process_frame
	_prepare_profile()
	await _wait(4)

	# --- main and navigation -------------------------------------------------
	await _shot_ui("res://scenes/menus/main_menu.tscn", "01_main_menu", 26)
	await _shot_ui("res://scenes/menus/career.tscn", "02_career", 18)
	GameSession.region_filter = "zagros"
	GameSession.env_filter = "zagros"
	# One selection screen per region: each carries that region's track previews, so
	# the screenshots cover every mountain area rather than only the first one.
	for i: int in range(Content.regions.size()):
		var region_id: String = String((Content.regions[i] as Dictionary)["id"])
		GameSession.region_filter = region_id
		GameSession.env_filter = region_id
		await _shot_ui("res://scenes/menus/stage_select.tscn",
			"%02d_map_%s" % [3 + i, region_id], 20)
	await _shot_ui("res://scenes/menus/radio.tscn", "08_radio", 16)
	await _shot_ui("res://scenes/menus/settings.tscn", "09_settings", 16)
	await _shot_ui("res://scenes/menus/credits.tscn", "62_credits", 16)

	# --- vehicles: one garage page per vehicle -------------------------------
	var ids: Array[String] = ["jimny_jb74", "hilux_an120", "patrol_y61", "pajero_v80", "lc79"]
	for i: int in range(ids.size()):
		GameSession.vehicle_id = ids[i]
		SaveManager.select_vehicle(ids[i])
		await _shot_ui("res://scenes/garage/garage.tscn", "%02d_garage_%s" % [10 + i, ids[i]], 18)

	# --- tuning labs ---------------------------------------------------------
	GameSession.vehicle_id = "hilux_an120"
	SaveManager.select_vehicle("hilux_an120")
	for entry: Array in [["engine", "20_engine_lab"], ["transmission", "21_transmission_lab"],
			["suspension", "22_suspension_lab"], ["tyres", "23_tire_shop"],
			["brakes", "24_brakes_lab"], ["body", "25_body_lab"]]:
		await _shot_lab(String(entry[0]), String(entry[1]))
	await _shot_ui("res://scenes/garage/dyno.tscn", "26_dyno", 26)
	await _shot_ui("res://scenes/garage/repair.tscn", "27_repair", 16)
	await _shot_ui("res://scenes/garage/setup.tscn", "28_setup_presets", 16)

	# --- route briefing ------------------------------------------------------
	GameSession.start_stage("alpine_02", "hillclimb")
	await _shot_ui("res://scenes/menus/route_briefing.tscn", "30_route_briefing", 20)

	# --- gameplay across regions and surfaces -------------------------------
	await _shot_race("zagros_01", 40.0, "40_race_start", 0.0, 0.0, false)
	await _shot_race("zagros_03", 300.0, "41_uphill_dirt", 0.0, 6.0, true)
	await _shot_race("alpine_03", 700.0, "42_downhill_asphalt", 0.0, 4.0, false)
	await _shot_race("zagros_02", 760.0, "43_gravel", 0.0, 7.0, true)
	await _shot_race("pine_01", 300.0, "44_mud", 0.0, 6.0, true)
	await _shot_race("glacier_01", 380.0, "45_snow", 0.0, 6.0, true)
	await _shot_race("black_ridge_03", 500.0, "46_weather_fog", 0.0, 6.0, true)
	await _shot_race("black_ridge_02", 420.0, "47_dashboard", 0.0, 5.0, false)
	SettingsService.show_debug = true
	await _shot_race("zagros_02", 500.0, "48_telemetry", 0.0, 5.0, true)
	SettingsService.show_debug = false

	# --- controls ------------------------------------------------------------
	await _shot_controls("50_controls_buttons", "buttons", false)
	await _shot_controls("51_controls_slider", "slider", false)
	await _shot_controls("52_controls_pedals", "pedals", true)
	await _shot_manual_clutch("53_manual_clutch")
	await _shot_gear_panel("54_gear_selector")
	await _shot_layout_editor("55_layout_editor")

	# --- end screens ---------------------------------------------------------
	await _shot_results("60_race_results")
	await _shot_pause("61_pause")

	_restore_profile()
	print("CAPTURE COMPLETE: %d screenshots" % _saved)
	get_tree().quit(0)

# ------------------------------------------------------------------ profile ---

func _snapshot_profile() -> void:
	_had_profile = FileAccess.file_exists(PROFILE)
	if not _had_profile:
		return
	var src: FileAccess = FileAccess.open(PROFILE, FileAccess.READ)
	var dst: FileAccess = FileAccess.open(PROFILE_BAK, FileAccess.WRITE)
	if src != null and dst != null:
		dst.store_buffer(src.get_buffer(src.get_length()))
		dst.close()
		src.close()

func _restore_profile() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	if _had_profile and FileAccess.file_exists(PROFILE_BAK):
		var src: FileAccess = FileAccess.open(PROFILE_BAK, FileAccess.READ)
		var dst: FileAccess = FileAccess.open(PROFILE, FileAccess.WRITE)
		if src != null and dst != null:
			dst.store_buffer(src.get_buffer(src.get_length()))
			dst.close()
			src.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_BAK))

func _prepare_profile() -> void:
	# A populated but disposable profile: every vehicle owned, some records, some
	# parts fitted, so the screenshots show real content instead of empty lists.
	SaveManager.data["credits"] = 48500
	SaveManager.data["xp"] = 3120
	var owned: Array = []
	for v: VehicleDef in Content.vehicles:
		owned.append(v.id)
	SaveManager.data["owned_vehicles"] = owned
	var records: Dictionary = {}
	var plan: Array = [
		["zagros_01", 58.4, 3], ["zagros_02", 74.2, 2], ["zagros_03", 121.7, 2],
		["alpine_01", 79.9, 3], ["alpine_02", 158.0, 2], ["pine_01", 71.0, 2],
		["pine_02", 92.4, 1], ["black_ridge_01", 116.0, 1],
	]
	for row: Array in plan:
		records[String(row[0])] = {
			"best_time": float(row[1]), "medal": int(row[2]), "attempts": 4,
			"completed": true,
			"by_vehicle": {"hilux_an120": {"best_time": float(row[1]) + 1.4, "medal": int(row[2])}},
		}
	SaveManager.data["records"] = records
	# Fit a believable tuned Hilux.
	var cfg: Dictionary = GarageModel.empty_config()
	cfg["parts"] = {
		str(int(PartDef.Slot.TURBO)): "hilux_an120_turbo_hybrid",
		str(int(PartDef.Slot.ECU)): "hilux_an120_ecu_1",
		str(int(PartDef.Slot.INTERCOOLER)): "hilux_an120_ic_fmic",
		str(int(PartDef.Slot.RADIATOR)): "hilux_an120_rad_hd",
		str(int(PartDef.Slot.EXHAUST)): "hilux_an120_exh_25",
		str(int(PartDef.Slot.TYRES)): "hilux_an120_tyre_mt",
		str(int(PartDef.Slot.DAMPERS)): "hilux_an120_damper_gas",
		str(int(PartDef.Slot.BUMPER_FRONT)): "hilux_an120_bumper_f_steel",
		str(int(PartDef.Slot.WINCH)): "hilux_an120_winch",
		str(int(PartDef.Slot.DIFFERENTIAL)): "hilux_an120_diff_lsd",
	}
	SaveManager.data["garage"] = {"hilux_an120": {"parts": cfg["parts"], "owned": cfg["parts"].values(), "condition": {}, "presets": {}}}
	SaveManager.data["selected_vehicle"] = "hilux_an120"
	GameSession.vehicle_id = "hilux_an120"
	SaveManager.save_profile()

# ------------------------------------------------------------------- shots ----

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

func _shot_lab(category: String, name: String) -> void:
	await _clear()
	var packed: PackedScene = load("res://scenes/garage/tuning_lab.tscn") as PackedScene
	if packed == null:
		print("MISSING SCENE tuning_lab")
		return
	_current = packed.instantiate()
	if "category" in _current:
		_current.set("category", category)
	add_child(_current)
	await _wait(20)
	_save(name)

func _shot_race(track_id: String, x_m: float, name: String, _unused: float,
		throttle_seconds: float, drive: bool) -> void:
	await _clear()
	GameSession.start_stage(track_id, "rally")
	GameSession.vehicle_id = "hilux_an120"
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	_current = packed.instantiate()
	add_child(_current)
	await _wait(8)
	_current.set("countdown", 0.0)
	_current.set("state", "racing")
	var veh: VehicleBody = _current.get("vehicle") as VehicleBody
	var terrain: TerrainBuilder = _current.get("terrain") as TerrainBuilder
	if veh != null and terrain != null and x_m > 0.0:
		var x_px: float = x_m * Units.PPM
		var y: float = terrain.height_at_world(x_px)
		veh.global_transform = Transform2D(0.0, Vector2(x_px, y - 0.55 * Units.PPM))
		veh.linear_velocity = Vector2(9.0 * Units.PPM, 0.0)
		if _current.get("camera") != null:
			(_current.get("camera") as Camera2D).global_position = veh.global_position + Vector2(220, -90)
	await _wait(6)
	if drive:
		Input.action_press("throttle")
		var end_ms: int = Time.get_ticks_msec() + int(maxf(throttle_seconds, 0.6) * 1000.0)
		while Time.get_ticks_msec() < end_ms:
			await get_tree().process_frame
		Input.action_release("throttle")
	else:
		await _wait(10)
	_save(name)

func _shot_controls(name: String, preset: String, left_handed: bool) -> void:
	await _clear()
	SettingsService.control_preset = preset
	SettingsService.control_left_handed = left_handed
	GameSession.start_stage("zagros_02", "rally")
	GameSession.vehicle_id = "hilux_an120"
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	_current = packed.instantiate()
	add_child(_current)
	await _wait(18)
	_current.set("countdown", 0.0)
	_current.set("state", "racing")
	await _wait(10)
	_save(name)
	SettingsService.control_preset = "buttons"
	SettingsService.control_left_handed = false

func _shot_manual_clutch(name: String) -> void:
	await _clear()
	SettingsService.clutch = "manual"
	GameSession.start_stage("pine_02", "rally")
	GameSession.vehicle_id = "lc79"
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	_current = packed.instantiate()
	add_child(_current)
	await _wait(18)
	_current.set("countdown", 0.0)
	_current.set("state", "racing")
	Input.action_press("clutch")
	await _wait(12)
	_save(name)
	Input.action_release("clutch")
	SettingsService.clutch = "assist"

func _shot_gear_panel(name: String) -> void:
	await _clear()
	GameSession.start_stage("black_ridge_02", "rally")
	GameSession.vehicle_id = "patrol_y61"
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	_current = packed.instantiate()
	add_child(_current)
	await _wait(18)
	_current.set("countdown", 0.0)
	_current.set("state", "racing")
	var controls: Node = _current.get("controls") as Node
	if controls != null and controls.has_method("open_panel"):
		controls.call("open_panel")
	await _wait(16)
	_save(name)

func _shot_layout_editor(name: String) -> void:
	await _clear()
	GameSession.start_stage("zagros_01", "rally")
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	_current = packed.instantiate()
	add_child(_current)
	await _wait(16)
	_current.set("state", "paused")
	if _current.has_method("_open_layout_editor"):
		_current.call("_open_layout_editor")
	await _wait(16)
	_save(name)

func _shot_results(name: String) -> void:
	await _clear()
	GameSession.start_stage("alpine_02", "hillclimb")
	GameSession.vehicle_id = "hilux_an120"
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	_current = packed.instantiate()
	add_child(_current)
	await _wait(14)
	_current.set("countdown", 0.0)
	_current.set("state", "racing")
	_current.set("elapsed", 151.42)
	var veh: VehicleBody = _current.get("vehicle") as VehicleBody
	if veh != null:
		var terrain: TerrainBuilder = _current.get("terrain") as TerrainBuilder
		var x_px: float = terrain.finish_x_px() - 8.0 * Units.PPM
		veh.global_transform = Transform2D(0.0, Vector2(x_px, terrain.height_at_world(x_px) - 0.5 * Units.PPM))
	await _wait(8)
	if _current.has_method("_finish"):
		_current.call("_finish")
	await _wait(24)
	_save(name)
	get_tree().paused = false

func _shot_pause(name: String) -> void:
	await _clear()
	get_tree().paused = false
	GameSession.start_stage("pine_03", "endurance")
	GameSession.vehicle_id = "pajero_v80"
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	_current = packed.instantiate()
	add_child(_current)
	await _wait(16)
	_current.set("countdown", 0.0)
	_current.set("state", "racing")
	await _wait(10)
	if _current.has_method("_pause"):
		_current.call("_pause")
	await _wait(18)
	ViewportScreenshot.shot(get_viewport(), OUT_DIR, name)
	_saved += 1
	get_tree().paused = false

func _wait(frames: int) -> void:
	for i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _save(name: String) -> void:
	# Several shots jump the scene straight to "racing"; the intro countdown that
	# was already on screen would otherwise stay painted over the scene.
	var race_hud: Node = _current.get("hud") if _current != null else null
	if race_hud != null and race_hud.has_method("hide_countdown"):
		race_hud.call("hide_countdown")
	var ok: bool = ViewportScreenshot.shot(get_viewport(), OUT_DIR, name)
	if ok:
		_saved += 1
