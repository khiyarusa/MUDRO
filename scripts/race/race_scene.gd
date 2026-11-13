extends Node2D
## The race: builds the world from data, drives the simulation, times the run and
## wires the HUD, audio, camera and effects to real vehicle state.

const INTRO_TIME: float = 3.2

var stage: StageDef
var terrain: TerrainBuilder
var vehicle: VehicleBody
var camera: Camera2D
var backdrop: Backdrop
var effects: RaceEffects
var hud: RaceHUD
var debug_overlay: DebugOverlay

var state: String = "intro"
var elapsed: float = 0.0
var countdown: float = INTRO_TIME
var checkpoint_index: int = 0
var top_speed: float = 0.0
var _shake: float = 0.0
var _last_gear: int = 1

var engine_audio: AudioStreamPlayer
var roll_audio: AudioStreamPlayer
var skid_audio: AudioStreamPlayer
var ambience: AudioStreamPlayer
var _roll_cooldown: float = 0.0
var _autodrive: bool = false
var _auto_shift_cd: float = 0.0
var _log_slot: int = -1
var _spawn_log: int = 0

func _ready() -> void:
	stage = GameSession.stage_def()
	if stage == null:
		# Dev convenience: running race.tscn directly boots the first stage.
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

	var tint := CanvasModulate.new()
	tint.color = _ambient_color()
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
	vehicle.auto_clutch = SettingsService.clutch != "manual"
	vehicle.manual_clutch_enabled = SettingsService.clutch == "manual"
	vehicle.auto_transmission = SettingsService.transmission == "auto"
	add_child(vehicle)
	vehicle.setup(def, Content.surfaces)
	vehicle.attach_surface_probe(terrain)
	vehicle.auto_transmission = SettingsService.transmission == "auto"
	vehicle.gearbox.auto_mode = vehicle.auto_transmission
	vehicle.global_transform = terrain.start_transform()
	vehicle.gearbox.reset(0 if vehicle.auto_transmission else 1)
	vehicle.damage.reset()
	vehicle.controls_locked = true
	vehicle.impact.connect(_on_impact)
	vehicle.landed.connect(_on_landed)
	vehicle.gear_changed.connect(_on_gear_changed)
	vehicle.engine_stalled.connect(_on_stalled)
	camera.global_position = vehicle.global_position + Vector2(200, -80)

	effects = RaceEffects.new()
	effects.name = "Effects"
	add_child(effects)
	effects.setup(vehicle, stage.environment)

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

	debug_overlay = DebugOverlay.new()
	add_child(debug_overlay)
	debug_overlay.bind_vehicle(vehicle)
	debug_overlay.visible = SettingsService.show_debug

func _ambient_color() -> Color:
	match stage.environment:
		"pine":
			return Color(0.86, 0.93, 0.88)
		"quarry":
			return Color(0.88, 0.94, 1.02)
		_:
			return Color(1.03, 0.98, 0.92)

func _build_audio() -> void:
	var vehicle_id: String = GameSession.vehicle_id
	var engine_name: String = "engine_ranger"
	match vehicle_id:
		"rocky_buggy":
			engine_name = "engine_buggy"
		"dune_pickup":
			engine_name = "engine_pickup"
		"titan_offroad":
			engine_name = "engine_titan"
	engine_audio = AudioDirector.make_loop(engine_name, "Engine", -9.0)
	if engine_audio != null:
		engine_audio.play()
	roll_audio = AudioDirector.make_loop("tire_roll_dirt", "SFX", -80.0)
	if roll_audio != null:
		roll_audio.play()
	skid_audio = AudioDirector.make_loop("skid", "SFX", -80.0)
	if skid_audio != null:
		skid_audio.play()
	ambience = AudioDirector.make_loop(String(Content.env_meta(stage.environment).get("ambience", "ambience_canyon")), "Ambience", -16.0)
	if ambience != null:
		ambience.play()

func _process(delta: float) -> void:
	if vehicle == null:
		return
	if OS.get_cmdline_args().has("--spawnlog") and _spawn_log < 40:
		_spawn_log += 1
		var tr: Dictionary = vehicle.telemetry
		var fr: Dictionary = tr.get("front", {})
		var rr: Dictionary = tr.get("rear", {})
		print("[spawn] y=%.2f vy=%.2f rot=%.3f cF=%s cR=%s compF=%.3f compR=%.3f loadF=%.0f loadR=%.0f" % [
			-vehicle.global_position.y / Units.PPM,
			vehicle.linear_velocity.y,
			vehicle.rotation,
			str(fr.get("contact", false)), str(rr.get("contact", false)),
			float(fr.get("compression", 0.0)), float(rr.get("compression", 0.0)),
			float(fr.get("load", 0.0)), float(rr.get("load", 0.0))])
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
	var throttle: float = InputRouter.throttle()
	var brake: float = InputRouter.brake()
	var handbrake: float = InputRouter.handbrake()
	var clutch: float = InputRouter.clutch()
	vehicle.set_inputs(throttle, brake, handbrake, clutch)

	if Input.is_action_just_pressed("gear_up"):
		vehicle.shift_up()
		AudioDirector.play("shift", -7.0)
	if Input.is_action_just_pressed("gear_down"):
		vehicle.shift_down()
		AudioDirector.play("shift", -8.0)
	if Input.is_action_just_pressed("recover"):
		_recover()
	if Input.is_action_just_pressed("start_engine"):
		vehicle.restart_engine()
		AudioDirector.play("engine_start", -6.0)
	if Input.is_action_just_pressed("debug_toggle"):
		SettingsService.show_debug = not SettingsService.show_debug
		SettingsService.save_settings()
		if debug_overlay != null:
			debug_overlay.visible = SettingsService.show_debug

func _drive_auto(delta: float) -> void:
	_auto_shift_cd -= delta
	vehicle.set_inputs(1.0, 0.0, 0.0, 1.0)
	if vehicle.engine == null:
		return
	var redline: float = vehicle.definition.engine.redline_rpm
	if _auto_shift_cd <= 0.0 and vehicle.engine.rpm > redline * 0.82 and vehicle.gearbox.gear < vehicle.gearbox.gear_count():
		vehicle.shift_up()
		_auto_shift_cd = 0.5

func _log_autodrive() -> void:
	var slot: int = int(elapsed * 2.0)
	if slot == _log_slot:
		return
	_log_slot = slot
	var t: Dictionary = vehicle.telemetry
	print("[drive] t=%.1f x=%.1f y=%.1f v=%.1f km/h rpm=%.0f gear=%d slipR=%+.2f loadR=%.0f surf=%s" % [
		elapsed,
		vehicle.global_position.x / Units.PPM,
		-vehicle.global_position.y / Units.PPM,
		float(t.get("speed_kmh", 0.0)),
		float(t.get("rpm", 0.0)),
		int(t.get("gear", 0)),
		float((t.get("rear", {}) as Dictionary).get("slip", 0.0)),
		float((t.get("rear", {}) as Dictionary).get("load", 0.0)),
		String((t.get("rear", {}) as Dictionary).get("surface", ""))])

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
	if vehicle.damage.is_disabled() and vehicle.engine != null and not vehicle.engine.running:
		pass

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
	if engine_audio != null:
		engine_audio.pitch_scale = AudioDirector.engine_pitch(rpm)
		var target_db: float = lerpf(-26.0, -7.0, clampf(rpm / 5200.0, 0.0, 1.0)) + throttle * 3.0
		if not (vehicle.engine != null and vehicle.engine.running):
			target_db = -60.0
		engine_audio.volume_db = lerpf(engine_audio.volume_db, target_db, 0.15)
	var rear: WheelAxis = vehicle.axles[1] if vehicle.axles.size() > 1 else null
	var slip: float = absf(rear.slip_ratio) if rear != null else 0.0
	var speed: float = vehicle.speed_kmh()
	if roll_audio != null:
		var rolling: bool = rear != null and rear.in_contact and speed > 2.0
		var roll_db: float = -80.0
		if rolling:
			roll_db = lerpf(-30.0, -16.0, clampf(speed / 50.0, 0.0, 1.0))
		roll_audio.volume_db = lerpf(roll_audio.volume_db, roll_db, 0.12)
		roll_audio.pitch_scale = clampf(0.7 + speed / 90.0, 0.6, 1.8)
	if skid_audio != null:
		var skidding: bool = slip > 0.35 and rear != null and rear.in_contact
		var skid_db: float = -80.0
		if skidding:
			skid_db = lerpf(-26.0, -10.0, clampf((slip - 0.35) / 1.4, 0.0, 1.0))
		skid_audio.volume_db = lerpf(skid_audio.volume_db, skid_db, 0.18)
		skid_audio.pitch_scale = clampf(0.9 + slip * 0.25, 0.7, 1.6)

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
	AudioDirector.play("shift", -7.0, randf_range(0.96, 1.05))

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
	AudioDirector.play("finish", -3.0)
	if engine_audio != null:
		engine_audio.volume_db = -60.0
	if roll_audio != null:
		roll_audio.volume_db = -80.0
	if skid_audio != null:
		skid_audio.volume_db = -80.0
	var result: Dictionary = GameSession.finish(elapsed, vehicle.damage.total_health(), top_speed)
	var medal: int = int(result.get("medal", 0))
	if medal > 0:
		AudioDirector.play("medal", -5.0)
	hud.show_results(result)
	get_tree().paused = true

func _pause() -> void:
	if state != "racing":
		return
	state = "paused"
	get_tree().paused = true
	hud.show_pause(true)
	AudioDirector.ui_click()

func _resume() -> void:
	if state != "paused":
		return
	get_tree().paused = false
	state = "racing"
	hud.show_pause(false)

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

func _exit_tree() -> void:
	get_tree().paused = false
