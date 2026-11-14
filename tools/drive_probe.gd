extends Node2D
## Headless drivability probe: builds a track and a stock vehicle, applies full
## throttle with a simple shift policy, and reports how far the car actually got.
## Run:
##   godot --headless --path . res://tools/drive_probe.tscn -- <track_id> <vehicle_id> <seconds>

var track: TrackDef
var terrain: TerrainBuilder
var vehicle: VehicleBody
var _time: float = 0.0
var _limit: float = 24.0
var _last_report: float = 0.0
var _last_shift: float = 0.0

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var track_id: String = args[0] if args.size() > 0 else "zagros_03"
	var vehicle_id: String = args[1] if args.size() > 1 else "hilux_an120"
	_limit = float(args[2]) if args.size() > 2 else 24.0
	track = Content.track_by_id(track_id)
	if track == null:
		print("PROBE: unknown track ", track_id)
		get_tree().quit(2)
		return
	terrain = TerrainBuilder.new()
	add_child(terrain)
	terrain.build(track, Content.surfaces)
	var base: VehicleDef = Content.vehicle_by_id(vehicle_id)
	var def: VehicleDef = GarageModel.build(base, GarageModel.empty_config())
	vehicle = VehicleBody.new()
	add_child(vehicle)
	vehicle.setup(def, Content.surfaces)
	vehicle.attach_surface_probe(terrain)
	vehicle.global_transform = terrain.start_transform()
	var gb: TransmissionProfile = def.stock_transmission_profile()
	print("PROBE %s / %s | gears %d %s | mass %.0f | power %.0f kW | torque %.0f Nm | grade at 60 m %.1f" % [
		track_id, vehicle_id, gb.gear_count(), gb.name_en, def.mass_kg,
		def.peak_power_kw(), def.peak_torque_nm(), track.grade_deg_at(60.0)])

func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	_time += delta
	# set_inputs(throttle, brake, handbrake, clutch): the clutch argument is
	# engagement, so 1.0 keeps the plates closed and 0.0 is a pressed pedal.
	vehicle.set_inputs(1.0, 0.0, 0.0, 1.0)
	# Simple driver, with a shift cooldown. Without the cooldown the box oscillates
	# between two gears around the threshold, which keeps the auto-clutch open and
	# makes a healthy car look like it cannot pull away.
	var rpm: float = vehicle.engine.rpm
	var red: float = vehicle.engine.config.redline_rpm
	var speed: float = absf(vehicle.speed_kmh()) / 3.6
	if vehicle.gearbox.gear < 1:
		vehicle.gearbox.request_gear(1, true, true, speed)
		_last_shift = _time
	elif _time - _last_shift > 0.9 and not vehicle.gearbox.is_shifting():
		if rpm > red * 0.86 and vehicle.gearbox.gear < vehicle.gearbox.gear_count():
			vehicle.shift_up()
			_last_shift = _time
		elif rpm < red * 0.34 and vehicle.gearbox.gear > 1:
			vehicle.shift_down()
			_last_shift = _time
	if _time - _last_report >= 2.0:
		_last_report = _time
		var x_m: float = vehicle.global_position.x / Units.PPM
		print("t=%4.1f  x=%6.1f m  v=%5.1f km/h  gear=%s  rpm=%4.0f  coolant=%5.1f  slope=%5.1f°" % [
			_time, x_m, vehicle.speed_kmh(), vehicle.gearbox.gear_label(), rpm,
			vehicle.coolant_temp_c(), vehicle.grade_deg()])
	if _time >= _limit:
		var finish: float = terrain.finish_x_px() / Units.PPM
		var reached: float = vehicle.global_position.x / Units.PPM
		print("PROBE RESULT: reached %.1f of %.1f m (%.0f%%), time %.1f s" % [
			reached, finish, clampf(reached / maxf(finish, 1.0), 0.0, 1.0) * 100.0, _time])
		get_tree().quit(0 if reached > finish * 0.5 else 1)
