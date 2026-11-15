extends Node
## MUDRO 3.1 screenshot harness for the driver-experience release.
##
## Runs the real game, instantiates the real scenes and saves what the renderer
## produced. No mock-ups, no headless capture:
##   godot --path . --resolution 1280x720 res://tools/capture_v31.tscn
##
## The player profile is snapshotted before the run and restored afterwards, so
## producing documentation never rewrites a save.

const OUT_DIR := "res://docs/screenshots/next-major-update"
const PROFILE := "user://profile.json"
const PROFILE_BAK := "user://profile.json.capture-backup"

var _current: Node = null
var _saved: int = 0
var _had_profile: bool = false
var _drawn: bool = false
var _draw_timeouts: int = 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# The renderer stops emitting frames when the window is covered, and a screenshot
	# taken then is the previous state. Keep the window in front for the whole run.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		DisplayServer.window_move_to_foreground()
	# A documentation run must never eat the machine: if a shot stalls, stop and
	# report what was captured instead of sitting on a dead window.
	var watchdog := Timer.new()
	watchdog.name = "Watchdog"
	watchdog.wait_time = 480.0
	watchdog.one_shot = true
	watchdog.timeout.connect(func() -> void:
		print("CAPTURE WATCHDOG: %d screenshots, stopping" % _saved)
		get_tree().quit(2))
	add_child(watchdog)
	watchdog.start()
	_snapshot_profile()
	await get_tree().process_frame
	_prepare_profile()
	await _wait(4)

	# --- menus and workshop --------------------------------------------------
	await _shot_ui("res://scenes/menus/main_menu.tscn", "01_main_menu", 26)
	await _shot_ui("res://scenes/menus/settings.tscn", "02_settings_controls", 18)
	await _shot_ui("res://scenes/garage/garage.tscn", "03_garage_hilux", 20)
	await _shot_ui("res://scenes/garage/tuning_lab.tscn", "04_transmission_lab", 20)
	await _shot_ui("res://scenes/garage/tuning_lab.tscn", "05_tyre_shop", 20, "tyres")
	await _shot_ui("res://scenes/garage/dyno.tscn", "06_dyno", 26)
	await _shot_ui("res://scenes/garage/repair.tscn", "07_repair", 16)

	# --- the control layout, state by state ----------------------------------
	await _shot_controls("10_drive_layout_idle", 0.0, false)
	await _shot_controls("11_clutch_fully_pressed", 1.0, false)
	await _shot_controls("12_clutch_at_bite_point", -1.0, false)
	await _shot_gear_panel("13_h_pattern_neutral", 0, false)
	await _shot_gear_panel("14_h_pattern_first", 1, false)
	await _shot_gear_panel("15_h_pattern_fourth", 4, false)
	await _shot_auto_selector("16_automatic_selector")
	await _shot_stall("17_engine_stalled", false)
	await _shot_stall("18_engine_restarted", true)

	# --- driving -------------------------------------------------------------
	await _shot_launch("20_launch_neutral", 0.0)
	await _shot_launch("21_launch_pulling_away", 3.2)
	await _shot_race("zagros_03", 260.0, "22_uphill_climb", 3.0, 2, 14.0)
	await _shot_race("alpine_03", 690.0, "23_descent", 3.0, 4, 16.0)
	await _shot_race("pine_01", 300.0, "24_mud_section", 3.0)
	await _shot_race("glacier_01", 380.0, "25_snow_road", 3.0)
	await _shot_race("black_ridge_01", 320.0, "26_black_ridge", 3.0)
	await _shot_race("glacier_02", 250.0, "27_glacier_road", 3.0)

	# --- navigation and the workshop's other bays ----------------------------
	await _shot_ui("res://scenes/menus/career.tscn", "30_career", 18)
	await _shot_stage_select("31_track_selection")
	await _shot_briefing("32_route_briefing")
	await _shot_garage_each()
	await _shot_ui("res://scenes/garage/tuning_lab.tscn", "45_engine_lab", 20, "engine")
	await _shot_ui("res://scenes/garage/tuning_lab.tscn", "46_suspension_lab", 20, "suspension")
	await _shot_ui("res://scenes/garage/tuning_lab.tscn", "47_ecu_lab", 20, "ecu")
	await _shot_ui("res://scenes/garage/tuning_lab.tscn", "48_brakes_lab", 20, "brakes")
	await _shot_controls_preset("50_controls_buttons", "buttons")
	await _shot_controls_preset("51_controls_slider", "slider")
	await _shot_controls_preset("52_controls_pedals", "pedals")
	await _shot_results("60_race_results")
	await _shot_pause("61_pause")

	_restore_profile()
	print("CAPTURE COMPLETE: %d screenshots" % _saved)
	if _draw_timeouts > 0:
		print("CAPTURE: %d frame waits timed out; frames were forced instead" % _draw_timeouts)
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
	SaveManager.data["credits"] = 68500
	SaveManager.data["xp"] = 4120
	var owned: Array = []
	for v: VehicleDef in Content.vehicles:
		owned.append(v.id)
	SaveManager.data["owned_vehicles"] = owned
	SaveManager.data["records"] = {
		"zagros_01": {"best_time": 58.4, "medal": 3, "attempts": 4, "completed": true},
		"alpine_02": {"best_time": 158.0, "medal": 2, "attempts": 2, "completed": true},
	}
	var cfg: Dictionary = GarageModel.empty_config()
	cfg["parts"] = {
		str(int(PartDef.Slot.TURBO)): "hilux_an120_turbo_hybrid",
		str(int(PartDef.Slot.ECU)): "hilux_an120_ecu_1",
		str(int(PartDef.Slot.INTERCOOLER)): "hilux_an120_ic_fmic",
		str(int(PartDef.Slot.TYRES)): "hilux_an120_tyre_mt",
		str(int(PartDef.Slot.DAMPERS)): "hilux_an120_damper_gas",
	}
	SaveManager.data["garage"] = {"hilux_an120": {
		"parts": cfg["parts"], "owned": (cfg["parts"] as Dictionary).values(),
		"condition": {}, "presets": {},
	}}
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

func _shot_ui(path: String, name: String, frames: int, category: String = "") -> void:
	await _clear()
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("MISSING SCENE ", path)
		return
	_current = packed.instantiate()
	if not category.is_empty() and "category" in _current:
		_current.set("category", category)
	add_child(_current)
	await _wait(frames)
	_save(name)

## A live race with the controls visible, and the clutch rail held at `pedal`
## (0 = released, 1 = floor, -1 = this car's bite point).
func _shot_controls(name: String, pedal: float, drive: bool) -> void:
	var race: Node = await _open_race("zagros_02", "hilux_an120")
	if race == null:
		return
	var veh: VehicleBody = race.get("vehicle") as VehicleBody
	var controls: TouchControls = race.get("controls") as TouchControls
	if veh != null and controls != null:
		# -1 means "this car's bite point": the shot has to show the real pedal
		# position where the plates start to grip, not a default rail height.
		var target: float = pedal
		if pedal < 0.0:
			target = veh.clutch.bite_point
		_hold_clutch(controls, clampf(target, 0.0, 1.0))
	await _wait(10)
	if drive:
		Input.action_press("throttle")
		await _wait(20)
		Input.action_release("throttle")
	_save(name)

func _hold_clutch(controls: TouchControls, pedal: float) -> void:
	var widget: TouchWidget = controls.widgets.get("clutch", null) as TouchWidget
	if widget == null:
		return
	widget.finger_id = 90
	widget.active = true
	widget.set_value(pedal)
	if controls.panel != null:
		controls.panel.clutch_pedal = pedal

func _shot_gear_panel(name: String, gear: int, _unused: bool) -> void:
	var race: Node = await _open_race("black_ridge_02", "patrol_y61")
	if race == null:
		return
	var controls: TouchControls = race.get("controls") as TouchControls
	var veh: VehicleBody = race.get("vehicle") as VehicleBody
	if controls == null or veh == null:
		return
	_hold_clutch(controls, 1.0)
	# Force the gear so the shot shows the lever latched in a real gate position.
	if gear != 0:
		veh.set_gear(gear)
		veh.gearbox.update(1.0)
	controls.update_live(veh.gearbox.gear, veh.gearbox.range_id, 1.0, 0.0, false)
	if controls.panel != null:
		controls.panel.confirm_shift(veh.gearbox.gear)
	controls.open_panel()
	await _wait(26)
	_save(name)

## The automatic is a workshop conversion. Fit the automatic gearbox in the profile
## and let the race build read it back, which is the same path a player takes.
func _shot_auto_selector(name: String) -> void:
	var target: String = "hilux_an120"
	var part_id: String = "%s_gbox_auto" % target
	if Content.part_by_id(part_id) == null:
		print("NO AUTOMATIC GEARBOX PART")
		return
	_fit_part(target, PartDef.Slot.GEARBOX, part_id)
	var race: Node = await _open_race("zagros_01", target)
	if race == null:
		return
	var controls: TouchControls = race.get("controls") as TouchControls
	var veh: VehicleBody = race.get("vehicle") as VehicleBody
	if controls == null or veh == null:
		return
	if not veh.gearbox.auto_mode:
		print("AUTOMATIC NOT ACTIVE")
		return
	veh.gearbox.set_range("D")
	controls.update_live(veh.gearbox.gear, veh.gearbox.range_id, 0.0, 0.0, true)
	controls.open_panel()
	await _wait(26)
	_save(name)
	# Hand the Hilux back its manual box: the shots that follow this one are about a
	# clutch pedal, and a converted car has none.
	_fit_part(target, PartDef.Slot.GEARBOX, "%s_gbox_s" % target)

func _fit_part(vehicle_id: String, slot: int, part_id: String) -> void:
	var entry: Dictionary = SaveManager.garage_entry(vehicle_id)
	var parts: Dictionary = (entry.get("parts", {}) as Dictionary).duplicate()
	parts[str(slot)] = part_id
	SaveManager.set_config_value(vehicle_id, "parts", parts)
	var owned: Array = SaveManager.owned_parts(vehicle_id)
	if not owned.has(part_id):
		owned.append(part_id)
	SaveManager.data["garage"][vehicle_id]["owned"] = owned
	SaveManager.save_profile()

func _shot_stage_select(name: String) -> void:
	GameSession.region_filter = "zagros"
	await _shot_ui("res://scenes/menus/stage_select.tscn", name, 20)

func _shot_briefing(name: String) -> void:
	await _clear()
	GameSession.start_stage("zagros_02", "hill_climb")
	GameSession.vehicle_id = "hilux_an120"
	var packed: PackedScene = load("res://scenes/menus/route_briefing.tscn") as PackedScene
	if packed == null:
		print("MISSING SCENE route_briefing")
		return
	_current = packed.instantiate()
	add_child(_current)
	await _wait(22)
	_save(name)

## Every owned car in the garage, so the vehicle collection is documented honestly.
func _shot_garage_each() -> void:
	var index: int = 40
	for v: VehicleDef in Content.vehicles:
		SaveManager.data["selected_vehicle"] = v.id
		GameSession.vehicle_id = v.id
		var name: String = "%d_garage_%s" % [index, v.id]
		await _shot_ui("res://scenes/garage/garage.tscn", name, 20)
		index += 1

func _shot_controls_preset(name: String, preset: String) -> void:
	var race: Node = await _open_race("zagros_02", "hilux_an120")
	if race == null:
		return
	SettingsService.set_value("control_preset", preset)
	await _wait(14)
	_save(name)
	SettingsService.set_value("control_preset", "drive")

func _shot_results(name: String) -> void:
	var race: Node = await _open_race("zagros_01", "hilux_an120")
	if race == null:
		return
	race.set("elapsed", 71.4)
	race.set("top_speed", 22.5)
	await _wait(6)
	race.call("_finish")
	await _wait(24)
	_save(name)
	get_tree().paused = false

func _shot_pause(name: String) -> void:
	var race: Node = await _open_race("alpine_02", "patrol_y61")
	if race == null:
		return
	await _wait(10)
	race.call("_pause")
	await _wait(18)
	_save(name)
	get_tree().paused = false

func _shot_stall(name: String, restart: bool) -> void:
	var race: Node = await _open_race("pine_02", "lc79")
	if race == null:
		return
	var veh: VehicleBody = race.get("vehicle") as VehicleBody
	var controls: TouchControls = race.get("controls") as TouchControls
	if veh == null:
		return
	veh.gearbox.reset(1)
	veh.engine.stall()
	veh.engine_running = false
	veh.engine.stall_cooldown = 0.0
	if race.has_method("_on_stalled") and not restart:
		race.call("_on_stalled")
	if restart and controls != null:
		_hold_clutch(controls, 1.0)
		await _wait(4)
		veh.restart_engine()
	await _wait(14)
	_save(name)

func _shot_launch(name: String, seconds: float) -> void:
	var race: Node = await _open_race("zagros_01", "hilux_an120")
	if race == null:
		return
	var controls: TouchControls = race.get("controls") as TouchControls
	var veh: VehicleBody = race.get("vehicle") as VehicleBody
	if controls != null:
		_hold_clutch(controls, 1.0)
	await _wait(6)
	if seconds <= 0.0 or controls == null or veh == null:
		await _wait(8)
		_save(name)
		return
	# A real launch: pedal to the floor, first gear through the interlock, then feed
	# the clutch out over a second with throttle on. The shot has to show the car
	# moving, not a car sitting in neutral with the throttle buried.
	if not veh.select_gear(1, false):
		print("LAUNCH: first gear refused (%s)" % veh.gearbox.reject_reason)
	await _wait(4)
	Input.action_press("throttle")
	var start: int = Time.get_ticks_msec()
	# 1.6 s of shot time, but the pedal is fed out over 2.4 s of driving: a 1 s dump
	# behind a 2.8 diesel is a stall, which is the physics doing its job, not a
	# screenshot. The car should be rolling when the shutter opens.
	var ramp_s: float = maxf(seconds, 1.4) * 1.5
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		var t: float = float(Time.get_ticks_msec() - start) / 1000.0
		_hold_clutch(controls, clampf(1.0 - t / ramp_s, 0.0, 1.0))
		await get_tree().process_frame
	Input.action_release("throttle")
	# Let it roll on with the throttle still on: lifting off at walking pace with the
	# plates half home lugs the engine, and the shot would show a stall instead of a
	# launch.
	await _wait(12)
	Input.action_release("throttle")
	_save(name)

func _shot_race(track_id: String, x_m: float, name: String, seconds: float, gear: int = 3, speed_mps: float = 9.0) -> void:
	var race: Node = await _open_race(track_id, "hilux_an120")
	if race == null:
		return
	var veh: VehicleBody = race.get("vehicle") as VehicleBody
	var terrain: TerrainBuilder = race.get("terrain") as TerrainBuilder
	if veh != null and terrain != null:
		var x_px: float = x_m * Units.PPM
		var y: float = terrain.height_at_world(x_px)
		veh.global_transform = Transform2D(0.0, Vector2(x_px, y - 1.9 * Units.PPM))
		veh.linear_velocity = Vector2(speed_mps * Units.PPM, 0.0)
		veh.gearbox.reset(gear)
		var camera_start: Camera2D = race.get("camera") as Camera2D
		if camera_start != null:
			camera_start.global_position = veh.global_position + Vector2(220, -90)
		# A car dropped from 0.55 m hangs in the air with its wheels spinning: the
		# suspension needs a moment of real contact before the throttle means anything.
		await _wait(12)
		var camera: Camera2D = race.get("camera") as Camera2D
		if camera != null:
			camera.global_position = veh.global_position + Vector2(220, -90)
	await _wait(8)
	if seconds > 0.0:
		Input.action_press("throttle")
		var end_ms: int = Time.get_ticks_msec() + int(seconds * 1000.0)
		while Time.get_ticks_msec() < end_ms:
			await get_tree().process_frame
		Input.action_release("throttle")
	await _wait(4)
	_save(name)

func _open_race(track_id: String, vehicle_id: String) -> Node:
	await _clear()
	get_tree().paused = false
	SettingsService.control_preset = "drive"
	SettingsService.control_left_handed = false
	GameSession.start_stage(track_id, "rally")
	GameSession.vehicle_id = vehicle_id
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	if packed == null:
		return null
	_current = packed.instantiate()
	add_child(_current)
	await _wait(16)
	_current.set("countdown", 0.0)
	_current.set("state", "racing")
	var veh: VehicleBody = _current.get("vehicle") as VehicleBody
	if veh != null:
		# The countdown is what unlocks the controls. Skipping it and leaving the car
		# locked was why the first "launch" shots showed a dead car on the line.
		veh.controls_locked = false
	var hud: Node = _current.get("hud")
	if hud != null and hud.has_method("hide_countdown"):
		hud.call("hide_countdown")
	await _wait(6)
	return _current

func _wait(frames: int) -> void:
	for i: int in range(frames):
		await get_tree().process_frame
	# The screenshot must come from a frame the renderer actually finished. This
	# machine's driver stops emitting `frame_post_draw` while the window is covered,
	# so the wait is bounded and the frame is forced instead of blocking the run.
	_drawn = false
	if RenderingServer.frame_post_draw.connect(_on_frame_drawn, CONNECT_ONE_SHOT) == OK:
		var deadline: int = Time.get_ticks_msec() + 250
		while not _drawn and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if not _drawn:
			RenderingServer.frame_post_draw.disconnect(_on_frame_drawn)
			_draw_timeouts += 1
	RenderingServer.force_draw(false, 0.0)

func _on_frame_drawn() -> void:
	_drawn = true

func _save(name: String) -> void:
	var race_hud: Node = _current.get("hud") if _current != null else null
	if race_hud != null and race_hud.has_method("hide_countdown"):
		race_hud.call("hide_countdown")
	if ViewportScreenshot.shot(get_viewport(), OUT_DIR, name):
		_saved += 1
