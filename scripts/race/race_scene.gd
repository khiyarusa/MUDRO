extends Node2D
## The race: builds the world from data, drives the simulation from the shared input
## contract, and wires HUD, audio, camera, weather, winch and effects to real state.
##
## Nothing here writes a speed or a position into the vehicle. Gear changes go
## through VehicleBody.select_gear(), the winch through an external force, and the
## weather through grip/rolling multipliers.

const INTRO_TIME: float = 3.2

var stage: StageDef
var terrain: TerrainBuilder
var vehicle: VehicleBody
var camera: Camera2D
var backdrop: Backdrop
var effects: RaceEffects
var hud: RaceHUD
var controls: TouchControls
var weather: WeatherSystem
var winch: WinchSystem
var debug_overlay: DebugOverlay

var state: String = "intro"
var elapsed: float = 0.0
var countdown: float = INTRO_TIME
var checkpoint_index: int = 0
var top_speed: float = 0.0
var _shake: float = 0.0
var _autodrive: bool = false
var _auto_shift_cd: float = 0.0
var _log_slot: int = -1
var _spawn_log: int = 0
var _last_surface: String = ""

var engine_audio: AudioStreamPlayer
var engine_high: AudioStreamPlayer
var roll_dirt: AudioStreamPlayer
var roll_rock: AudioStreamPlayer
var roll_snow: AudioStreamPlayer
var skid_audio: AudioStreamPlayer
var ambience: AudioStreamPlayer
var winch_audio: AudioStreamPlayer
var _roll_cooldown: float = 0.0
var _input_state: VehicleInputState = VehicleInputState.new()
var _layout_editor: ControlLayoutEditor = null
var _turbo_audio: AudioStreamPlayer

func _ready() -> void:
	stage = GameSession.stage_def()
	if stage == null:
		if not Content.stages.is_empty():
			GameSession.start_stage(Content.stages[0].id, "career")
			stage = GameSession.stage_def()
	if stage == null:
		Router.goto("res://scenes/menus/main_menu.tscn")
		return
	_build_world()
	_build_audio()
	state = "intro"
	countdown = INTRO_TIME
	hud.set_time(0.0)
	hud.set_checkpoint(0, stage.checkpoints.size() + 1)
	GameSession.race_attempt += 1
	if OS.get_cmdline_args().has("--autodrive"):
		_autodrive = true
		Input.action_press("throttle")

func _build_world() -> void:
	var def: VehicleDef = GameSession.vehicle_def()

	terrain = TerrainBuilder.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(stage, Content.surfaces)

	weather = WeatherSystem.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(stage.environment, _weather_id(), SettingsService.quality)

	var tint := CanvasModulate.new()
	tint.color = _ambient_color() * weather.ambient_tint()
	add_child(tint)

	backdrop = Backdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(0.92, 0.92)
	camera.position_smoothing_enabled = false
	camera.limit_left = -600
	camera.limit_right = int(terrain.world_length + 900)
	camera.limit_top = -40000
	camera.limit_bottom = 40000
	add_child(camera)
	camera.make_current()
	backdrop.setup(stage.environment, camera)

	vehicle = VehicleBody.new()
	vehicle.name = "Vehicle"
	add_child(vehicle)
	vehicle.setup(def, Content.surfaces)
	vehicle.attach_surface_probe(terrain)
	vehicle.configure_driver(SettingsService.clutch != "manual")
	vehicle.global_transform = terrain.start_transform()
	vehicle.damage.reset()
	vehicle.controls_locked = true
	vehicle.impact.connect(_on_impact)
	vehicle.landed.connect(_on_landed)
	vehicle.gear_changed.connect(_on_gear_changed)
	vehicle.shift_rejected.connect(_on_shift_rejected)
	vehicle.engine_stalled.connect(_on_stalled)
	vehicle.transfer_changed.connect(_on_transfer_changed)
	vehicle.diff_changed.connect(_on_diff_changed)
	weather.apply_to(vehicle)
	if vehicle.gearbox.profile != null and vehicle.gearbox.profile.is_automatic():
		vehicle.gearbox.range_id = "D"
		vehicle.gearbox.reset(0)
		vehicle.gearbox.request_gear(1, true)
	else:
		vehicle.gearbox.reset(1)
	camera.global_position = vehicle.global_position + Vector2(200, -80)

	effects = RaceEffects.new()
	effects.name = "Effects"
	add_child(effects)
	effects.setup(vehicle, stage.environment, SettingsService.quality)

	if def.has_winch and def.active_winch:
		winch = WinchSystem.new()
		winch.name = "Winch"
		add_child(winch)
		winch.setup(vehicle, terrain, stage)

	hud = RaceHUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(vehicle, stage, GameSession.objective_text())
	hud.paused_changed.connect(func(_p: bool) -> void: _pause())
	hud.resume_pressed.connect(_resume)
	hud.restart_pressed.connect(_restart)
	hud.quit_pressed.connect(_quit_to_menu)
	hud.retry_pressed.connect(_restart)
	hud.continue_pressed.connect(_continue)
	hud.garage_pressed.connect(_open_garage)
	hud.transfer_pressed.connect(_cycle_transfer)
	hud.diff_pressed.connect(_cycle_diff)
	hud.winch_pressed.connect(_toggle_winch)
	hud.layout_pressed.connect(_open_layout_editor)
	hud.set_weather(weather.label())

	controls = TouchControls.new()
	controls.name = "Controls"
	# A CanvasLayer, not the world node: the race camera must never pan the pedals.
	var control_layer := CanvasLayer.new()
	control_layer.name = "ControlLayer"
	control_layer.layer = 25
	add_child(control_layer)
	control_layer.add_child(controls)
	controls.setup(vehicle.gearbox.profile, vehicle)
	controls.recover_pressed.connect(_recover)
	controls.start_pressed.connect(_restart_engine)
	controls.winch_pressed.connect(_toggle_winch)
	controls.gear_requested.connect(_request_gear)
	controls.range_requested.connect(_request_range)

	debug_overlay = DebugOverlay.new()
	add_child(debug_overlay)
	debug_overlay.bind_vehicle(vehicle)
	debug_overlay.visible = SettingsService.show_debug

func _weather_id() -> String:
	if stage.weather != "" and stage.weather != "auto":
		return stage.weather
	match stage.environment:
		"quarry":
			return "snow" if stage.id.ends_with("04") else "cloudy"
		"pine":
			return "fog" if stage.id.ends_with("03") else "cloudy"
		"black_ridge":
			return "fog"
		_:
			return "clear"

func _ambient_color() -> Color:
	match stage.environment:
		"pine":
			return Color(0.86, 0.93, 0.88)
		"quarry":
			return Color(0.88, 0.94, 1.02)
		"black_ridge":
			return Color(0.72, 0.73, 0.72)
		_:
			return Color(1.03, 0.98, 0.92)

func _build_audio() -> void:
	var vehicle_id: String = GameSession.vehicle_id
	var engine_name: String = "engine_ranger"
	var high_name: String = "engine_ranger_high"
	match vehicle_id:
		"rocky_buggy":
			engine_name = "engine_buggy"
			high_name = "engine_buggy_high"
		"dune_pickup":
			engine_name = "engine_pickup"
			high_name = "engine_pickup_high"
		"titan_offroad":
			engine_name = "engine_titan"
			high_name = "engine_titan_high"
	engine_audio = AudioDirector.make_loop(engine_name, "Engine", -9.0)
	if engine_audio != null:
		engine_audio.play()
	engine_high = AudioDirector.make_loop(high_name, "Engine", -60.0)
	if engine_high != null:
		engine_high.play()
	if vehicle != null and vehicle.definition != null and vehicle.definition.engine != null and vehicle.definition.engine.turbo_gain > 0.0:
		_turbo_audio = AudioDirector.make_loop("turbo_spool", "Engine", -60.0)
		if _turbo_audio != null:
			_turbo_audio.play()
	roll_dirt = AudioDirector.make_loop("tire_roll_dirt", "SFX", -80.0)
	roll_rock = AudioDirector.make_loop("tire_roll_rock", "SFX", -80.0)
	roll_snow = AudioDirector.make_loop("snow_crunch", "SFX", -80.0)
	for p: AudioStreamPlayer in [roll_dirt, roll_rock, roll_snow]:
		if p != null:
			p.play()
	skid_audio = AudioDirector.make_loop("skid", "SFX", -80.0)
	if skid_audio != null:
		skid_audio.play()
	if winch != null:
		winch_audio = AudioDirector.make_loop("winch_loop", "SFX", -60.0)
		if winch_audio != null:
			winch_audio.play()
	var ambience_name: String = String(Content.env_meta(stage.environment).get("ambience", "ambience_canyon"))
	if not AudioDirector.has(ambience_name):
		ambience_name = "ambience_quarry" if AudioDirector.has("ambience_quarry") else "ambience_canyon"
	ambience = AudioDirector.make_loop(ambience_name, "Ambience", -16.0)
	if ambience != null:
		ambience.play()
	if weather != null and weather.id == "rain":
		AudioDirector.make_loop("rain_loop", "Ambience", -22.0)
	elif weather != null and weather.id == "heavy_rain":
		AudioDirector.make_loop("rain_loop", "Ambience", -16.0)
	elif weather != null and weather.id == "snow":
		AudioDirector.make_loop("wind_loop", "Ambience", -24.0)

func _process(delta: float) -> void:
	if vehicle == null:
		return
	# A long first frame (shader compile, scene load) must not teleport the race
	# clock by several seconds.
	delta = minf(delta, 0.1)
	if OS.get_cmdline_args().has("--spawnlog") and _spawn_log < 40:
		_spawn_log += 1
		var tr: Dictionary = vehicle.telemetry
		print("[spawn] y=%.2f vy=%.2f rot=%.3f loadF=%.0f loadR=%.0f" % [
			-vehicle.global_position.y / Units.PPM, vehicle.linear_velocity.y, vehicle.rotation,
			float((tr.get("front", {}) as Dictionary).get("load", 0.0)),
			float((tr.get("rear", {}) as Dictionary).get("load", 0.0))])
	match state:
		"intro":
			_tick_intro(delta)
		"racing":
			elapsed += delta
			hud.set_time(elapsed)
			if _autodrive:
				_drive_auto(delta)
				_log_autodrive()
			else:
				_read_input()
			_check_progress()
		"paused", "finished":
			pass
	_update_camera(delta)
	_update_audio()
	_update_effects()
	_update_live_ui()

func _tick_intro(delta: float) -> void:
	countdown -= delta
	vehicle.controls_locked = true
	vehicle.set_inputs(0.0, 0.0, 0.0, 1.0)
	var shown: int = int(ceil(countdown - 0.2))
	if countdown > 0.25:
		var text: String = str(maxi(shown, 1))
		if hud.get_meta("last_count", "") != text:
			hud.set_meta("last_count", text)
			hud.show_countdown(text)
			AudioDirector.play("ui_click", -10.0, 1.1)
	else:
		hud.show_countdown(Loc.t("race_go"))
		if not hud.get_meta("go_played", false):
			hud.set_meta("go_played", true)
			AudioDirector.ui_confirm()
			vehicle.controls_locked = false
			state = "racing"
			var tw := create_tween()
			tw.tween_interval(0.6)
			tw.tween_callback(func() -> void: hud.hide_countdown())

func _read_input() -> void:
	if Input.is_action_just_pressed("pause"):
		_pause()
		return
	if Input.is_action_just_pressed("recover"):
		_recover()
	if Input.is_action_just_pressed("start_engine"):
		_restart_engine()
	if Input.is_action_just_pressed("gear_up"):
		_request_gear(vehicle.gearbox.gear + 1)
	if Input.is_action_just_pressed("gear_down"):
		_request_gear(vehicle.gearbox.gear - 1)
	if Input.is_action_just_pressed("transfer_toggle"):
		_cycle_transfer()
	if Input.is_action_just_pressed("diff_toggle"):
		_cycle_diff()
	if Input.is_action_just_pressed("winch_toggle"):
		_toggle_winch()
	if Input.is_action_just_pressed("debug_toggle"):
		SettingsService.show_debug = not SettingsService.show_debug
		SettingsService.save_settings()
		if debug_overlay != null:
			debug_overlay.visible = SettingsService.show_debug

	_input_state = controls.input_state() if controls != null else VehicleInputState.new()
	vehicle.set_input_state(_input_state)

func _drive_auto(delta: float) -> void:
	_auto_shift_cd -= delta
	vehicle.set_inputs(1.0, 0.0, 0.0, 1.0)
	if vehicle.engine == null:
		return
	var redline: float = vehicle.definition.engine.redline_rpm
	if _auto_shift_cd <= 0.0 and vehicle.engine.rpm > redline * 0.82 and vehicle.gearbox.gear < vehicle.gearbox.gear_count():
		vehicle.set_gear(vehicle.gearbox.gear + 1)
		_auto_shift_cd = 0.5

func _log_autodrive() -> void:
	var slot: int = int(elapsed * 2.0)
	if slot == _log_slot:
		return
	_log_slot = slot
	var t: Dictionary = vehicle.telemetry
	print("[drive] t=%.1f x=%.1f v=%.1f km/h rpm=%.0f gear=%d transfer=%s diff=%s slipR=%+.2f surf=%s" % [
		elapsed,
		vehicle.global_position.x / Units.PPM,
		float(t.get("speed_kmh", 0.0)),
		float(t.get("rpm", 0.0)),
		int(t.get("gear", 0)),
		String(t.get("transfer", "")),
		String(t.get("diff", "")),
		float((t.get("rear", {}) as Dictionary).get("slip", 0.0)),
		String((t.get("rear", {}) as Dictionary).get("surface", ""))])

## ------------------------------------------------------------- driver actions ---

func _request_gear(gear: int) -> void:
	if vehicle == null or state == "finished":
		return
	var accepted: bool = vehicle.select_gear(gear)
	if controls != null:
		controls.on_shift_result(accepted, vehicle.gearbox.reject_reason if not accepted else "")
	if accepted:
		hud.toast("%s %s" % [Loc.t("hud_gear"), vehicle.gearbox.gear_label()])
		SettingsService.vibrate(14)
	else:
		hud.toast(_reject_text(vehicle.gearbox.reject_reason))
		SettingsService.vibrate(45)

func _request_range(range_id: String) -> void:
	if vehicle == null or not vehicle.gearbox.profile.is_automatic():
		return
	var before: int = vehicle.gearbox.gear
	if vehicle.gearbox.set_range(range_id):
		if controls != null:
			controls.on_shift_result(true)
		if range_id == "P":
			hud.toast(Loc.t("range_park"))
		elif range_id == "R":
			hud.toast(Loc.t("range_reverse"))
			AudioDirector.play("gear_engage", -10.0, 0.9)
		elif range_id == "N":
			hud.toast(Loc.t("range_neutral"))
		else:
			hud.toast("%s %s" % [Loc.t("range_drive"), range_id])
		SettingsService.vibrate(18)
		if before == vehicle.gearbox.gear:
			controls.on_shift_result(true)

func _reject_text(reason: String) -> String:
	match reason:
		GearboxState.REJECT_CLUTCH:
			return Loc.t("gearbox_clutch_needed")
		GearboxState.REJECT_OVERREV:
			return Loc.t("gearbox_overrev")
		GearboxState.REJECT_REVERSE:
			return Loc.t("gearbox_reverse_blocked")
		GearboxState.REJECT_SHIFTING:
			return Loc.t("gearbox_shifting")
		_:
			return Loc.t("gearbox_refused")

func _cycle_transfer() -> void:
	if vehicle == null or not vehicle.definition.has_transfer_case():
		hud.toast(Loc.t("transfer_none"))
		return
	var mode: String = vehicle.cycle_transfer()
	hud.toast("%s %s" % [Loc.t("hud_transfer"), mode])
	AudioDirector.play("gear_engage", -12.0, 0.82)
	SettingsService.vibrate(16)

func _cycle_diff() -> void:
	if vehicle == null:
		return
	var mode: String = vehicle.cycle_diff()
	hud.toast("%s %s" % [Loc.t("hud_diff"), mode.to_upper()])
	AudioDirector.play("gear_engage", -13.0, 1.06)
	SettingsService.vibrate(14)

func _toggle_winch() -> void:
	if vehicle == null:
		return
	if winch == null:
		hud.toast(Loc.t("winch_unavailable"))
		return
	var result: String = winch.toggle()
	hud.toast(Loc.t(result))
	if winch.attached:
		AudioDirector.play("winch_strain", -8.0)
	else:
		AudioDirector.play("ui_back", -10.0)
	SettingsService.vibrate(16)

func _restart_engine() -> void:
	vehicle.restart_engine()
	AudioDirector.play("engine_start", -6.0)

func _on_shift_rejected(reason: String, _gear: int) -> void:
	if reason == GearboxState.REJECT_CLUTCH:
		AudioDirector.play("gear_grind", -6.0)
		SettingsService.vibrate(55)

func _on_transfer_changed(mode: String) -> void:
	AudioDirector.play("gear_engage", -11.0, 0.8)
	hud.toast("%s %s" % [Loc.t("hud_transfer"), mode])

func _on_diff_changed(mode: String) -> void:
	hud.toast("%s %s" % [Loc.t("hud_diff"), mode.to_upper()])

func _update_live_ui() -> void:
	if controls == null or vehicle == null:
		return
	var t: Dictionary = vehicle.telemetry
	if t.is_empty():
		return
	controls.update_live(vehicle.gearbox.gear, vehicle.gearbox.range_id,
		controls.clutch_pedal(), float(t.get("speed_kmh", 0.0)),
		SettingsService.clutch != "manual" or not vehicle.manual_clutch_enabled)
	# The starter is only a control when the engine is actually dead.
	if controls.widgets.has("start"):
		var start_widget: TouchWidget = controls.widgets["start"] as TouchWidget
		var stalled: bool = vehicle.engine != null and not vehicle.engine.running
		if start_widget.visible != stalled:
			start_widget.visible = stalled
			if not stalled:
				start_widget.reset()

func _check_progress() -> void:
	var x: float = vehicle.global_position.x
	while checkpoint_index < stage.checkpoints.size():
		var gate_x: float = stage.checkpoints[checkpoint_index] * Units.PPM
		if x >= gate_x:
			checkpoint_index += 1
			hud.set_checkpoint(checkpoint_index, stage.checkpoints.size() + 1)
			AudioDirector.play("checkpoint", -6.0)
			hud.toast("%s %d/%d" % [Loc.t("race_checkpoint"), checkpoint_index, stage.checkpoints.size() + 1])
			SettingsService.vibrate(18)
		else:
			break
	if x >= terrain.finish_x_px():
		_finish()
		return
	var ground_y: float = terrain.height_at_world(clampf(x, 0.0, stage.length_m * Units.PPM))
	if vehicle.global_position.y > ground_y + 1100.0:
		_recover()
	if vehicle.global_position.y > 20000.0:
		_recover()
	top_speed = maxf(top_speed, vehicle.speed_kmh())

func _update_camera(delta: float) -> void:
	if camera == null or vehicle == null:
		return
	var velocity: Vector2 = vehicle.linear_velocity
	var look_ahead: Vector2 = velocity * 0.45
	look_ahead.x = clampf(look_ahead.x, -180.0, 260.0)
	look_ahead.y = clampf(look_ahead.y, -120.0, 120.0)
	var target: Vector2 = vehicle.global_position + look_ahead + Vector2(0, -92)
	camera.global_position = camera.global_position.lerp(target, clampf(delta * 4.2, 0.0, 1.0))
	var speed: float = vehicle.speed_kmh()
	var target_zoom: float = lerpf(0.96, 0.76, clampf(speed / 70.0, 0.0, 1.0))
	camera.zoom = camera.zoom.lerp(Vector2(target_zoom, target_zoom), clampf(delta * 1.8, 0.0, 1.0))
	if SettingsService.shake > 0.001:
		_shake = maxf(0.0, _shake - delta * 2.6)
		var amp: float = _shake * 9.0 * SettingsService.shake
		camera.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	else:
		camera.offset = Vector2.ZERO

func _update_audio() -> void:
	var t: Dictionary = vehicle.telemetry
	if t.is_empty():
		return
	var rpm: float = float(t.get("rpm", 0.0))
	var throttle: float = float(t.get("throttle", 0.0))
	var redline: float = vehicle.definition.engine.redline_rpm
	if engine_audio != null:
		engine_audio.pitch_scale = AudioDirector.engine_pitch(rpm)
		var target_db: float = lerpf(-26.0, -7.0, clampf(rpm / redline, 0.0, 1.0)) + throttle * 3.0
		if not (vehicle.engine != null and vehicle.engine.running):
			target_db = -60.0
		engine_audio.volume_db = lerpf(engine_audio.volume_db, target_db, 0.15)
	if engine_high != null:
		var high_mix: float = clampf((rpm / redline - 0.55) / 0.45, 0.0, 1.0) * throttle
		var high_db: float = lerpf(-60.0, -14.0, high_mix) if (vehicle.engine != null and vehicle.engine.running) else -60.0
		engine_high.volume_db = lerpf(engine_high.volume_db, high_db, 0.12)
		engine_high.pitch_scale = clampf(0.8 + rpm / redline * 0.5, 0.6, 1.6)
	if _turbo_audio != null:
		var boost: float = vehicle.engine.boost if vehicle.engine != null else 0.0
		_turbo_audio.volume_db = lerpf(_turbo_audio.volume_db, lerpf(-60.0, -18.0, clampf(boost, 0.0, 1.0)), 0.2)
		_turbo_audio.pitch_scale = clampf(0.7 + boost * 0.7, 0.5, 1.8)
	var rear: WheelAxis = vehicle.axles[1] if vehicle.axles.size() > 1 else null
	var slip: float = absf(rear.slip_ratio) if rear != null else 0.0
	var speed: float = vehicle.speed_kmh()
	var surface: String = String((t.get("rear", {}) as Dictionary).get("surface", ""))
	_last_surface = surface
	var rolling: bool = rear != null and rear.in_contact and speed > 2.0
	var target_dirt: float = -80.0
	var target_rock: float = -80.0
	var target_snow: float = -80.0
	if rolling:
		var base_db: float = lerpf(-30.0, -17.0, clampf(speed / 50.0, 0.0, 1.0))
		match surface:
			"rock", "gravel", "asphalt":
				target_rock = base_db
			"snow", "ice":
				target_snow = base_db
			_:
				target_dirt = base_db
	_crossfade(roll_dirt, target_dirt, 0.10, 0.7 + speed / 90.0)
	_crossfade(roll_rock, target_rock, 0.10, 0.75 + speed / 80.0)
	_crossfade(roll_snow, target_snow, 0.10, 0.7 + speed / 100.0)
	if skid_audio != null:
		var skidding: bool = slip > 0.35 and rear != null and rear.in_contact
		var skid_db: float = lerpf(-26.0, -10.0, clampf((slip - 0.35) / 1.4, 0.0, 1.0)) if skidding else -80.0
		skid_audio.volume_db = lerpf(skid_audio.volume_db, skid_db, 0.18)
		skid_audio.pitch_scale = clampf(0.9 + slip * 0.25, 0.7, 1.6)
	if winch_audio != null:
		winch_audio.volume_db = lerpf(winch_audio.volume_db, -9.0 if (winch != null and winch.attached) else -60.0, 0.15)
		winch_audio.pitch_scale = 0.8 + clampf(winch.tension_kn() / 20.0, 0.0, 0.5) if winch != null else 1.0

func _crossfade(player: AudioStreamPlayer, target_db: float, rate: float, pitch: float) -> void:
	if player == null:
		return
	player.volume_db = lerpf(player.volume_db, target_db, rate)
	player.pitch_scale = clampf(pitch, 0.5, 2.0)

func _update_effects() -> void:
	if effects == null:
		return
	if vehicle.axles.size() > 1:
		var rear: WheelAxis = vehicle.axles[1]
		if rear.in_contact and absf(rear.slip_ratio) > 1.1 and absf(vehicle.forward_speed) > 3.0:
			_roll_cooldown -= get_process_delta_time()
			if _roll_cooldown <= 0.0:
				_roll_cooldown = 0.06
				effects.burst(rear.contact_point, _particle_kind(rear.surface))

func _particle_kind(surface: SurfaceProfile) -> String:
	if surface == null:
		return "dust"
	match surface.particle_kind:
		"mud":
			return "mud"
		"water":
			return "water"
		"snow":
			return "snow"
		_:
			return "rock" if surface.id == "rock" else "dust"

func _on_impact(strength: float, world_point: Vector2, kind: String) -> void:
	_shake = minf(1.4, _shake + strength)
	if strength > 0.25:
		SettingsService.vibrate(int(clampf(strength * 45.0, 18.0, 90.0)))
	if effects != null:
		effects.burst(world_point, "rock" if kind == "hard" else "dust")
	AudioDirector.play("impact_rock" if kind == "hard" else "impact_wood", lerpf(-16.0, -5.0, clampf(strength, 0.0, 1.0)), randf_range(0.9, 1.1))

func _on_landed(_axle: int, strength: float) -> void:
	_shake = minf(1.2, _shake + strength * 0.7)
	AudioDirector.play("land_thud", lerpf(-18.0, -6.0, clampf(strength, 0.0, 1.0)), randf_range(0.92, 1.06))
	if strength > 0.35:
		SettingsService.vibrate(40)

func _on_gear_changed(_gear: int) -> void:
	AudioDirector.play("shift", -9.0, randf_range(0.96, 1.05))

func _on_stalled() -> void:
	hud.toast(Loc.t("race_stalled_hint"))
	AudioDirector.play("engine_stall", -4.0)
	SettingsService.vibrate(60)

func _recover() -> void:
	if state != "racing" and state != "intro":
		return
	var x: float = 2.0
	if checkpoint_index > 0 and checkpoint_index <= stage.checkpoints.size():
		x = stage.checkpoints[checkpoint_index - 1]
	var y: float = terrain.height_at_world(x * Units.PPM)
	var ahead: float = terrain.height_at_world((x + 1.5) * Units.PPM)
	var angle: float = atan2(ahead - y, 1.5 * Units.PPM)
	var t := Transform2D(angle, Vector2(x * Units.PPM, y - 0.9 * Units.PPM))
	vehicle.reset_motion(t)
	vehicle.damage.apply_impact(0.08, 1, vehicle.definition.durability)
	if winch != null and winch.attached:
		winch.detach()
	circle_reset_fx()
	AudioDirector.play("ui_back", -8.0)

func circle_reset_fx() -> void:
	if effects != null:
		effects.burst(vehicle.global_position, "dust")

func _finish() -> void:
	if state == "finished":
		return
	state = "finished"
	vehicle.controls_locked = true
	vehicle.set_inputs(0.0, 1.0, 0.0, 1.0)
	if controls != null:
		controls.release_all()
	AudioDirector.play("finish", -3.0)
	for p: AudioStreamPlayer in [engine_audio, roll_dirt, roll_rock, roll_snow, skid_audio, winch_audio]:
		if p != null:
			p.volume_db = -80.0
	var result: Dictionary = GameSession.finish(elapsed, vehicle.damage.total_health(), top_speed)
	if int(result.get("medal", 0)) > 0:
		AudioDirector.play("medal", -5.0)
	hud.show_results(result)
	get_tree().paused = true

func _pause() -> void:
	if state != "racing":
		return
	state = "paused"
	if controls != null:
		controls.release_all()
	vehicle.set_input_state(VehicleInputState.new())
	get_tree().paused = true
	hud.show_pause(true)
	AudioDirector.ui_click()

func _resume() -> void:
	if state != "paused":
		return
	if _layout_editor != null:
		_layout_editor.queue_free()
		_layout_editor = null
	get_tree().paused = false
	state = "racing"
	vehicle.set_input_state(VehicleInputState.new())
	hud.show_pause(false)

func _open_layout_editor() -> void:
	if _layout_editor != null:
		return
	_layout_editor = ControlLayoutEditor.new()
	_layout_editor.name = "LayoutEditor"
	add_child(_layout_editor)
	_layout_editor.closed.connect(_on_layout_closed)

func _on_layout_closed() -> void:
	if _layout_editor != null:
		_layout_editor.queue_free()
		_layout_editor = null
	if controls != null:
		controls.rebuild()
	_resume()

func _restart() -> void:
	get_tree().paused = false
	GameSession.retry()
	Router.goto("res://scenes/race/race.tscn", 0.12)

func _continue() -> void:
	get_tree().paused = false
	var nxt: StageDef = GameSession.next_stage()
	if nxt != null and SaveManager.is_stage_unlocked(nxt.id):
		GameSession.start_stage(nxt.id, GameSession.mode)
		Router.goto("res://scenes/race/race.tscn", 0.14)
	else:
		Router.goto("res://scenes/menus/stage_select.tscn", 0.16)

func _open_garage() -> void:
	get_tree().paused = false
	Router.goto("res://scenes/garage/garage.tscn", 0.16)

func _quit_to_menu() -> void:
	get_tree().paused = false
	Router.goto("res://scenes/menus/main_menu.tscn", 0.16)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "racing":
		_pause()

func _exit_tree() -> void:
	get_tree().paused = false
